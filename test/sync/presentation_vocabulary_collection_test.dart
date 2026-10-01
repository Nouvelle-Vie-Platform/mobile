/// **La collection `presentation_vocabulary`, de bout en bout** (#81).
///
/// Ce que ce fichier vérifie n'est pas l'affichage — c'est le voyage : qu'un mot
/// réglé au portail arrive, qu'il arrive **avant** les listes qu'il intitule, et
/// qu'un serveur qui ne la connaît pas encore ne coûte rien.
///
/// Les DAO s'écrivent ici par le **moteur**, jamais par un insert nu : c'est la
/// seule façon de prouver que la forme servie par le serveur traverse réellement
/// `sync_rows.dart` et le magasin.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/network/api_client.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/sync/branch_filter.dart';
import 'package:maison_du_miracle/data/sync/sync_api.dart';
import 'package:maison_du_miracle/data/sync/sync_engine.dart';
import 'package:maison_du_miracle/data/sync/synced_collection.dart';
import 'package:maison_du_miracle/models/vocabulary.dart';

import '../data/local/local_database_fixtures.dart';
import '../helpers/fake_sync_server.dart';
import '../helpers/sync_fixtures.dart';

void main() {
  late FakeSyncServer server;
  late Dio dio;
  late AppDatabase db;
  late SyncDao dao;

  setUp(() {
    server = FakeSyncServer();
    dio = Dio(BaseOptions(baseUrl: 'https://eenv.brainsial.com'))
      ..interceptors.add(unwrapEnvelopeInterceptor)
      ..httpClientAdapter = server;
    db = openTestDatabase();
    dao = db.syncDao;
  });

  tearDown(() => db.close());

  /// Le manifeste de la seule collection qui nous intéresse, `partition:
  /// 'reference'` — un mot n'appartient à aucune branche.
  Map<String, Object?> vocabularyManifest() => {
        'scope_version': 1,
        'collections': [
          manifestEntry(
            SyncCollectionKey.presentationVocabulary,
            partition: 'reference',
            currentCursor: presentationVocabularyCursor,
            hasChanges: true,
            fromZero: true,
          ),
        ],
      };

  SyncEngine engine({
    List<String>? only,
    Future<int?> Function()? branchId,
  }) =>
      SyncEngine(
        api: SyncApi(dio: dio),
        dao: dao,
        collections: syncedCollections()
            .where((c) =>
                only?.contains(c.key) ??
                c.key == SyncCollectionKey.presentationVocabulary)
            .toList(growable: false),
        branchId: branchId,
      );

  group('Le registre', () {
    test('la collection est là, rangée avant tout contenu', () {
      final keys = syncedCollections().map((c) => c.key).toList();

      expect(keys, contains(SyncCollectionKey.presentationVocabulary));
      // Un mot doit être arrivé **avant la liste qu'il intitule** : une section
      // tirée d'abord s'afficherait sous le mot du dépôt, puis changerait de
      // titre sous les yeux du fidèle au cycle suivant.
      for (final content in [
        SyncCollectionKey.teachings,
        SyncCollectionKey.gatherings,
        SyncCollectionKey.announcements,
      ]) {
        expect(
          keys.indexOf(SyncCollectionKey.presentationVocabulary),
          lessThan(keys.indexOf(content)),
          reason: '« $content » ne doit jamais précéder le vocabulaire',
        );
      }
    });

    test('elle n\'est pas filtrée par la préférence de branche', () {
      expect(
        kBranchScopedCollections,
        isNot(contains(SyncCollectionKey.presentationVocabulary)),
      );
      expect(
        isBranchScoped(SyncCollectionKey.presentationVocabulary),
        isFalse,
      );
    });
  });

  group('Le tirage', () {
    setUp(() {
      server
        ..serveManifest(vocabularyManifest())
        ..serveCollection(
          'presentation_vocabulary',
          presentationVocabularyPage(),
        );
    });

    test('les quatre lignes entrent au magasin, avec leur curseur', () async {
      final report = await engine().synchronize();

      expect(report.pulled, [SyncCollectionKey.presentationVocabulary]);

      final rows = await db.select(db.presentationVocabulary).get();
      expect(
        rows.map((r) => r.id),
        unorderedEquals([
          'sectionLatestTeachings',
          'teaching',
          'filterTeachings',
          'downloadsEmptyMessage',
        ]),
      );
      expect(
        await dao.cursorFor(SyncCollectionKey.presentationVocabulary),
        presentationVocabularyCursor,
      );
    });

    test('l\'identifiant est la clé du catalogue, une chaîne', () async {
      await engine().synchronize();

      // Le point qui coupe tout s'il est pris pour un `SERIAL` : ce référentiel
      // est le premier du registre dont la PK est textuelle, et `referenceId`
      // lèverait sur chaque ligne — donc sur la page entière, donc sur le cycle.
      final row = (await db.select(db.presentationVocabulary).get())
          .firstWhere((r) => r.id == 'sectionLatestTeachings');
      expect(row.kind, 'label');
      expect(row.label, {
        'fr': 'Derniers messages',
        'en': 'Latest messages',
      });
      expect(row.singular, isNull);
      expect(row.plural, isNull);
      // Le jeton d'écriture est posé par le magasin, pas par le serveur.
      expect(row.syncStamp, greaterThan(0));
    });

    test('un terme porte ses deux formes, et aucune n\'est calculée', () async {
      await engine().synchronize();

      final row = (await db.select(db.presentationVocabulary).get())
          .firstWhere((r) => r.id == 'teaching');
      expect(row.kind, 'term');
      expect(row.singular, {'fr': 'message', 'en': 'message'});
      expect(row.plural, {'fr': 'messages', 'en': 'messages'});
      expect(row.label, isNull);
    });

    test('la non-décision voyage, et c\'est son rôle', () async {
      await engine().synchronize();

      // Le serveur n'efface **jamais** la ligne : il y écrit `null`. C'est ce
      // `null` qui apprend au téléphone de revenir à son `.arb` ; une suppression
      // ne voyagerait pas, et l'appareil garderait pour toujours un mot que le
      // portail ne montre plus.
      final row = (await db.select(db.presentationVocabulary).get())
          .firstWhere((r) => r.id == 'filterTeachings');
      expect(row.label, isNull);
    });

    test('aucun `branch_id` ne part, même avec une préférence posée', () async {
      await engine(branchId: () async => 3).synchronize();

      expect(
        server
            .requestsFor('presentation_vocabulary')
            .last
            .queryParameters['branch_id'],
        isNull,
      );
    });
  });

  group('Un serveur en retard d\'une version', () {
    test('le 404 saute la collection et ne coupe rien', () async {
      // `FakeSyncServer` répond **404** à une collection jamais scriptée, comme
      // le registre serveur le fait d'une clé non enregistrée. Le vocabulaire est
      // sauté, `teaching_types` — rangée après lui — est tirée quand même, et le
      // magasin reste sur ses `.arb` : rien ne se dégrade.
      server
        ..serveManifest(manifestFromZero())
        ..serveCollection('teaching_types', teachingTypesPage());

      final report = await engine(only: [
        SyncCollectionKey.presentationVocabulary,
        SyncCollectionKey.teachingTypes,
      ]).synchronize();

      expect(
          report.skipped, contains(SyncCollectionKey.presentationVocabulary));
      expect(report.pulled, contains(SyncCollectionKey.teachingTypes));
      expect(await db.select(db.presentationVocabulary).get(), isEmpty);
      expect(await db.select(db.teachingTypes).get(), isNotEmpty);
      // Rien de posé : la prochaine fois, la collection repart de zéro.
      expect(
        await dao.cursorFor(SyncCollectionKey.presentationVocabulary),
        isNull,
      );
    });
  });

  group('Le DAO', () {
    test('range les lignes d\'après `kind`, et laisse tomber les vides',
        () async {
      server
        ..serveManifest(vocabularyManifest())
        ..serveCollection(
          'presentation_vocabulary',
          presentationVocabularyPage(),
        );
      await engine().synchronize();

      final overrides = await db.vocabularyDao.readOverrides();

      expect(overrides.labels.keys, contains('sectionLatestTeachings'));
      expect(overrides.terms.keys, ['teaching']);
      // Une ligne remise à `null` n'est **pas** une surcharge : elle dit « garde
      // le mot du dépôt », et la laisser entrer obligerait la résolution à la
      // distinguer d'une vraie.
      expect(overrides.labels.keys, isNot(contains('filterTeachings')));
      // Une carte **vide**, elle, entre — le magasin stocke ce que le serveur
      // envoie —, et c'est la résolution qui refuse d'en faire une chaîne vide.
      expect(
          overrides.labels['downloadsEmptyMessage'], {'fr': '   ', 'en': ''});
    });

    test('un magasin jamais synchronisé ne surcharge rien', () async {
      // L'état de départ **légitime** : le `.arb` compilé fait foi partout.
      final overrides = await db.vocabularyDao.readOverrides();
      expect(overrides.isEmpty, isTrue);
      expect(overrides, VocabularyOverrides.empty);
    });
  });
}
