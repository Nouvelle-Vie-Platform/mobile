/// **Le fond est descendu une fois, puis lu sur le disque.**
///
/// C'est l'exigence, et c'est aussi ce qu'aucun autre test ne surveillerait :
/// un magasin qui re-téléchargerait à chaque ouverture marcherait
/// parfaitement — il coûterait seulement, sur un forfait prépayé, plus que
/// l'enseignement qu'il habille.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/backgrounds/season_background_store.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('fonds_de_saison');
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  /// Un magasin dont on compte les descentes, et dont on choisit l'issue.
  ({FileSeasonBackgroundStore store, List<String> fetched}) make({
    bool fails = false,
  }) {
    final fetched = <String>[];
    final store = FileSeasonBackgroundStore(
      root: () async => root,
      fetch: (url, destination) async {
        fetched.add(url);
        if (fails) throw const SocketException('pas de réseau');
        await File(destination).writeAsBytes([0x52, 0x49, 0x46, 0x46]);
      },
    );
    return (store: store, fetched: fetched);
  }

  const url =
      'https://exemple.test/uploads/backgrounds/seasons/noel-1920w.webp';
  const autre =
      'https://exemple.test/uploads/backgrounds/seasons/careme-1920w.webp';

  test('la première fois descend, les suivantes lisent le disque', () async {
    final (:store, :fetched) = make();

    final first = await store.ensureLocal(url);
    final second = await store.ensureLocal(url);
    final third = await store.ensureLocal(url);

    expect(first, isNotNull);
    expect(first!.existsSync(), isTrue);
    // Le même fichier, et **une seule** descente pour trois ouvertures.
    expect(second!.path, first.path);
    expect(third!.path, first.path);
    expect(fetched, [url]);
  });

  test('changer de saison descend le nouveau fond et efface l\'ancien',
      () async {
    final (:store, :fetched) = make();

    final noel = await store.ensureLocal(url);
    final careme = await store.ensureLocal(autre);

    expect(fetched, [url, autre]);
    expect(careme!.path, isNot(noel!.path));
    // L'ancien ne reste pas : un fond plein écran par saison passée finirait
    // par peser plus que le cache lui-même.
    expect(noel.existsSync(), isFalse);
    expect(careme.existsSync(), isTrue);
  });

  test('une descente qui échoue ne rend rien, et ne laisse rien', () async {
    final (:store, :fetched) = make(fails: true);

    // Elle ne **lève** pas : un décor n'est pas une donnée, et un lecteur qui
    // rougirait pour un fond serait un lecteur qui refuse de jouer un prêche
    // parce qu'il est dans un tunnel.
    expect(await store.ensureLocal(url), isNull);
    expect(fetched, [url]);

    // Et surtout : pas de fichier **tronqué** laissé derrière. Un fichier
    // partiel serait trouvé « déjà là » à l'ouverture suivante, et le fond
    // serait cassé pour toute la saison.
    final directory = Directory('${root.path}/season_backgrounds');
    final leftovers = directory.existsSync()
        ? directory.listSync().whereType<File>().toList()
        : <File>[];
    expect(leftovers.where((f) => !f.path.endsWith('.partial')), isEmpty);
  });

  test('une adresse vide ou blanche ne déclenche rien', () async {
    final (:store, :fetched) = make();

    expect(await store.ensureLocal(null), isNull);
    expect(await store.ensureLocal(''), isNull);
    expect(await store.ensureLocal('   '), isNull);
    expect(fetched, isEmpty);
  });

  test('le nom local ne dépend pas du lancement', () async {
    // `String.hashCode` n'est stable ni entre deux lancements ni entre deux
    // versions du SDK. S'en servir donnerait un cache qui ne sert jamais — et
    // rien ne le dirait, puisque le fond s'afficherait à chaque fois.
    final first = make();
    final firstFile = await first.store.ensureLocal(url);

    final second = make();
    final secondFile = await second.store.ensureLocal(url);

    expect(secondFile!.path, firstFile!.path);
    // Le second magasin a trouvé le fichier du premier : aucune descente.
    expect(second.fetched, isEmpty);
  });

  group('Ce que lit le démarrage', () {
    test('rien n\'a été descendu → rien', () async {
      final (:store, fetched: _) = make();
      expect(await store.cachedFile(), isNull);
    });

    test('le fond descendu se retrouve **sans son adresse**', () async {
      final (:store, fetched: _) = make();
      final descendu = await store.ensureLocal(url);

      // C'est tout l'intérêt : `main()` lit ce fichier avant le premier frame,
      // sans ouvrir la base et sans savoir quelle saison court. Le dossier ne
      // contient qu'un fichier — la purge s'en charge.
      final startup = await store.cachedFile();
      expect(startup!.path, descendu!.path);
    });

    test('un `.partial` n\'est jamais rendu', () async {
      final (:store, fetched: _) = make();
      // Une descente interrompue laisse ce fichier-là. Le rendre afficherait
      // une image tronquée — et la figerait à l'écran de démarrage de **tous**
      // les lancements suivants, puisque le démarrage ne descend rien.
      final directory = Directory('${root.path}/season_backgrounds');
      await directory.create(recursive: true);
      await File('${directory.path}/abcdef12.webp.partial')
          .writeAsBytes([0x52]);

      expect(await store.cachedFile(), isNull);
    });
  });

  test('le dossier est celui qu\'on lui donne, et nommé', () async {
    final (:store, fetched: _) = make();
    final file = await store.ensureLocal(url);

    expect(file!.path, startsWith('${root.path}/season_backgrounds/'));
    // L'extension suit celle de l'adresse : elle ne sert qu'à qui inspecte le
    // dossier, le décodeur de Flutter lisant les octets.
    expect(file.path, endsWith('.webp'));
  });
}
