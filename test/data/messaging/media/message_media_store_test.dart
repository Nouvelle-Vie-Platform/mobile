/// **Le magasin durable et la règle « le disque avant le réseau »** (T1, #223).
///
/// Le test qui porte la tranche est le dernier : `download` ne doit **pas**
/// toucher au réseau quand le fichier est déjà là. Il le prouve en comptant
/// les requêtes d'URL présignée sur un adaptateur Dio substitué — zéro, et non
/// « pas d'erreur ».
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/messaging/media/group_media_urls.dart';
import 'package:maison_du_miracle/data/messaging/media/message_media_store.dart';

/// Compte les requêtes et répond un `302` vers l'origine, comme la route
/// `GET /groups/:id/messages/:mid/media`.
class _CountingApi implements HttpClientAdapter {
  final List<String> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${options.path}?${options.queryParameters}');
    return ResponseBody.fromString(
      '',
      302,
      headers: {
        HttpHeaders.locationHeader: ['https://origine.test/objet'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Écrit un fichier là où on le lui demande, et compte les téléchargements.
class _CountingOrigin implements HttpClientAdapter {
  int downloads = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    downloads++;
    return ResponseBody.fromString('des octets', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('magasin_media_');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  MessageMediaStore storeOf() => MessageMediaStore(root: () async => root);

  group('MessageMediaStore', () {
    test('un dossier par message, une entrée par variante', () async {
      final store = storeOf();
      final file =
          await store.pathFor(messageId: 'm-1', fileName: 'budget.pdf');
      final thumb = await store.pathFor(
          messageId: 'm-1', fileName: 'clip.mp4', thumbnail: true);

      expect(file, '${root.path}/message_media/m-1/budget.pdf');
      expect(thumb, '${root.path}/message_media/m-1/thumb_clip.mp4');
    });

    test(
        'le même message rend toujours le même chemin — la clé est son '
        'identité', () async {
      final a =
          await storeOf().pathFor(messageId: 'm-1', fileName: 'budget.pdf');
      final b =
          await storeOf().pathFor(messageId: 'm-1', fileName: 'budget.pdf');
      expect(a, b);
    });

    test('deux messages, le même nom de document : pas d\'écrasement',
        () async {
      final store = storeOf();
      expect(
        await store.pathFor(messageId: 'm-1', fileName: 'notes.pdf'),
        isNot(await store.pathFor(messageId: 'm-2', fileName: 'notes.pdf')),
      );
    });

    test('un nom qui remonterait hors du magasin est neutralisé', () async {
      final path = await storeOf()
          .pathFor(messageId: 'm-1', fileName: '../../coffre.txt');
      expect(path, '${root.path}/message_media/m-1/.._.._coffre.txt');
    });

    test('il ne touche au disque qu\'à la demande', () async {
      final store = storeOf();
      final path =
          await store.pathFor(messageId: 'm-1', fileName: 'budget.pdf');
      expect(await Directory('${root.path}/message_media').exists(), isFalse,
          reason: 'un magasin vide n\'a pas besoin d\'exister');

      await store.prepare(path);
      expect(await File(path).parent.exists(), isTrue);
    });
  });

  group('adopt — le fichier envoyé entre au magasin (T2, #224)', () {
    late Directory outbox;

    setUp(() {
      outbox = Directory.systemTemp.createTempSync('outbox_');
    });

    tearDown(() {
      if (outbox.existsSync()) outbox.deleteSync(recursive: true);
    });

    File sourceFile(String name, String contents) =>
        File('${outbox.path}/$name')..writeAsStringSync(contents);

    test('un déplacement, pas une copie : la source ne reste pas', () async {
      final source = sourceFile('c-1-src.m4a', 'des octets');

      final path =
          await storeOf().adopt(messageId: 'm-1', sourcePath: source.path);

      expect(path, '${root.path}/message_media/m-1/c-1-src.m4a');
      expect(File(path!).readAsStringSync(), 'des octets',
          reason: 'les octets sont arrivés entiers');
      expect(source.existsSync(), isFalse,
          reason: 'la source est déplacée, pas recopiée');
    });

    test('un nom donné prime : le document garde le sien', () async {
      final path = await storeOf().adopt(
        messageId: 'm-1',
        sourcePath: sourceFile('c-1-src.pdf', 'pdf').path,
        fileName: 'budget 2026.pdf',
      );
      expect(path, '${root.path}/message_media/m-1/budget 2026.pdf');
    });

    test('la vignette prend la variante du magasin', () async {
      final path = await storeOf().adopt(
        messageId: 'm-1',
        sourcePath: sourceFile('c-1-thumb.jpg', 'jpg').path,
        thumbnail: true,
      );
      expect(path, '${root.path}/message_media/m-1/thumb_c-1-thumb.jpg');
    });

    test('une source disparue rend `null`, sans rien créer', () async {
      final store = storeOf();
      expect(
        await store.adopt(
            messageId: 'm-1', sourcePath: '${outbox.path}/jamais.m4a'),
        isNull,
      );
      expect(Directory('${root.path}/message_media').existsSync(), isFalse);
    });

    test('un fichier déjà au magasin est rendu tel quel — idempotent',
        () async {
      final store = storeOf();
      final first = await store.adopt(
          messageId: 'm-1', sourcePath: sourceFile('c-1.jpg', 'jpg').path);

      final second = await store.adopt(messageId: 'm-1', sourcePath: first!);

      expect(second, first);
      expect(File(first).readAsStringSync(), 'jpg',
          reason: 'se renommer sur soi-même ne doit pas vider le fichier');
    });
  });

  group('download — le disque avant le réseau', () {
    late _CountingApi api;
    late _CountingOrigin origin;
    late HttpGroupMediaUrls urls;

    setUp(() {
      api = _CountingApi();
      origin = _CountingOrigin();
      urls = HttpGroupMediaUrls(
        api: Dio(BaseOptions(baseUrl: 'https://api.test'))
          ..httpClientAdapter = api,
        storeClient: Dio()..httpClientAdapter = origin,
        store: storeOf(),
      );
    });

    test('absent : une requête d\'URL, un téléchargement, un fichier',
        () async {
      final path = await urls.download(
          groupId: 'g-1', messageId: 'm-1', fileName: 'budget.pdf');

      expect(path, '${root.path}/message_media/m-1/budget.pdf');
      expect(await File(path!).exists(), isTrue);
      expect(api.calls, hasLength(1));
      expect(origin.downloads, 1);
      expect(await File('$path.part').exists(), isFalse,
          reason: 'le fichier partiel est renommé, pas laissé derrière');
    });

    test('déjà là : AUCUNE requête, et le chemin tout de suite', () async {
      // Première ouverture : le fichier descend.
      await urls.download(
          groupId: 'g-1', messageId: 'm-1', fileName: 'budget.pdf');
      api.calls.clear();
      origin.downloads = 0;

      // Un magasin neuf, pour qu'aucun cache en mémoire ne porte la réponse :
      // c'est bien le **disque** qui répond.
      final relu = HttpGroupMediaUrls(
        api: Dio(BaseOptions(baseUrl: 'https://api.test'))
          ..httpClientAdapter = api,
        storeClient: Dio()..httpClientAdapter = origin,
        store: storeOf(),
      );
      final path = await relu.download(
          groupId: 'g-1', messageId: 'm-1', fileName: 'budget.pdf');

      expect(path, '${root.path}/message_media/m-1/budget.pdf');
      expect(api.calls, isEmpty,
          reason: 'l\'URL présignée ne doit pas être demandée');
      expect(origin.downloads, 0);
    });

    test('la vignette est une variante à part', () async {
      await urls.download(
          groupId: 'g-1', messageId: 'm-1', fileName: 'clip.mp4');
      api.calls.clear();

      final thumb = await urls.download(
          groupId: 'g-1',
          messageId: 'm-1',
          fileName: 'clip.mp4',
          thumbnail: true);

      expect(thumb, '${root.path}/message_media/m-1/thumb_clip.mp4');
      expect(api.calls.single, contains('variant'));
    });
  });
}
