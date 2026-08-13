import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';

import '../helpers/fake_sync_server.dart';
import '../helpers/sync_fixtures.dart';

/// Le double lui-même : ce qu'il sert, ce qu'il enregistre, et où il s'insère.
///
/// Aucun réseau — `flutter test` répond 400 à tout accès réel. Le double se
/// substitue au transport de `Dio`, si bien que la requête traverse les
/// intercepteurs de production et s'arrête juste avant la socket.
void main() {
  late FakeSyncServer server;
  late Dio dio;

  setUp(() {
    server = FakeSyncServer();
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3333'))
      ..interceptors.add(unwrapEnvelopeInterceptor)
      ..httpClientAdapter = server;
  });

  group('GET /sync — le manifeste', () {
    test('rend les dix-neuf collections du registre, enveloppe déballée',
        () async {
      server.serveManifest(manifestNominal());

      final res = await dio.get<dynamic>('/sync');
      final data = res.data as Map;

      expect(data['scope_version'], 4);
      expect((data['collections'] as List).length, 19);
      expect(
        (data['collections'] as List)
            .map((c) => (c as Map)['key'])
            .toList(growable: false),
        kSyncCollections.keys.toList(growable: false),
      );
    });

    test('la `scope_version` progresse d\'un appel à l\'autre', () async {
      server.serveManifests(manifestScopeVersionProgression());

      final first = (await dio.get<dynamic>('/sync')).data as Map;
      final second = (await dio.get<dynamic>('/sync')).data as Map;
      final third = (await dio.get<dynamic>('/sync')).data as Map;

      expect(first['scope_version'], 4);
      expect(second['scope_version'], 5);
      expect(third['scope_version'], 5);
      // Seul le deuxième réclame un resync : les droits viennent de changer.
      expect(_resyncKeys(first), isEmpty);
      expect(_resyncKeys(second), isNotEmpty);
      expect(_resyncKeys(third), isEmpty);
    });

    test('les curseurs envoyés par le client sont enregistrés', () async {
      server.serveManifest(manifestNominal());

      await dio.get<dynamic>(
        '/sync',
        queryParameters: {
          'cursors[teachings]': teachingsCursorPage1,
          'scope_version': 4,
        },
      );

      expect(server.manifestRequests, hasLength(1));
      expect(
        server.lastRequest.queryParameters['cursors[teachings]'],
        teachingsCursorPage1,
      );
      expect(server.lastRequest.queryParameters['scope_version'], 4);
    });
  });

  group('GET /sync/{collection} — le tirage', () {
    test('sert les pages dans l\'ordre, la dernière se répète', () async {
      server.servePages('teachings', teachingsPagesAtLimitOne());

      final first = (await dio.get<dynamic>('/sync/teachings')).data as Map;
      final second = (await dio.get<dynamic>('/sync/teachings')).data as Map;
      final third = (await dio.get<dynamic>('/sync/teachings')).data as Map;
      final again = (await dio.get<dynamic>('/sync/teachings')).data as Map;

      expect(first['has_more'], isTrue);
      expect(second['has_more'], isTrue);
      expect(third['has_more'], isFalse);
      // Un serveur ne cesse pas d'exister parce qu'on lui redemande la même
      // chose : la dernière page se rejoue à l'identique.
      expect(again['next_cursor'], third['next_cursor']);
      expect(server.requestsFor('teachings'), hasLength(4));
    });

    test('`since` et `limit` partent sur le fil et sont enregistrés', () async {
      server.serveCollection('teachings', emptyPageFromZero());

      await dio.get<dynamic>(
        '/sync/teachings',
        queryParameters: {'since': teachingsCursorPage1, 'limit': 1},
      );

      expect(server.lastRequest.method, 'GET');
      expect(server.lastRequest.uri.path, '/sync/teachings');
      expect(server.lastRequest.queryParameters, {
        'since': teachingsCursorPage1,
        'limit': 1,
      });
    });

    test('une clé non enregistrée répond 404, corps hors enveloppe', () async {
      server.serveCollection('teachings', emptyPageFromZero());

      final error = await _errorOf(
        () => dio.get<dynamic>('/sync/$kUnregisteredCollection'),
      );

      expect(error.response?.statusCode, 404);
      final body = error.response?.data as Map;
      expect(body['code'], kCollectionNotFoundCode);
      // Hors enveloppe : pas de `data` à déballer sur un corps d'erreur.
      expect(body.containsKey('data'), isFalse);
    });

    test('une coupure de transport lève sans aucune réponse', () async {
      server
        ..serveCollection(
          'teachings',
          deltaPage(
            items: const [fullTeachingPayload],
            nextCursor: teachingsCursorPage1,
            hasMore: true,
          ),
        )
        ..cutConnectionOn('teachings');

      final page = (await dio.get<dynamic>('/sync/teachings')).data as Map;
      expect((page['items'] as List), hasLength(1));

      final error = await _errorOf(() => dio.get<dynamic>('/sync/teachings'));

      expect(error.type, DioExceptionType.connectionError);
      expect(error.response, isNull);
    });

    test('une route hors du protocole de synchro est refusée', () async {
      final error = await _errorOf(() => dio.get<dynamic>('/events'));

      expect(error.toString(), contains('FakeSyncServer'));
    });
  });

  group('Insertion dans le vrai client', () {
    test('la requête traverse les intercepteurs d\'ApiClient', () async {
      FlutterSecureStorage.setMockInitialValues(
          {'auth_token': 'jeton-de-test'});
      server.serveManifest(manifestNominal());
      final api = ApiClient.instance;
      api.dio.httpClientAdapter = server;

      final res = await api.dio.get<dynamic>('/sync');

      // Le Bearer a bien été injecté par l'intercepteur d'auth…
      expect(
          server.lastRequest.headers['Authorization'], 'Bearer jeton-de-test');
      // …et l'enveloppe `data` déballée par le sien, comme en production.
      expect((res.data as Map)['scope_version'], 4);
    });
  });
}

/// Les clés de collection qu'un manifeste marque `full_resync_required`.
List<String> _resyncKeys(Map<dynamic, dynamic> manifest) =>
    (manifest['collections'] as List)
        .cast<Map<String, dynamic>>()
        .where((c) => c['full_resync_required'] as bool)
        .map((c) => c['key'] as String)
        .toList(growable: false);

/// Exécute [call] et rend la [DioException] attendue.
Future<DioException> _errorOf(Future<void> Function() call) async {
  try {
    await call();
  } on DioException catch (e) {
    return e;
  }
  fail('la requête aurait dû échouer');
}
