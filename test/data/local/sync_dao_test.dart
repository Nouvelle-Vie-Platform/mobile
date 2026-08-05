// `isNull` / `isNotNull` existent des deux côtés — ici on veut les matchers.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';

import 'local_database_fixtures.dart';

/// Panne provoquée : ce qu'une coupure réseau ou une mort de processus fait au
/// milieu d'une transaction.
class _Coupure implements Exception {
  const _Coupure();
}

void main() {
  late AppDatabase db;
  late SyncDao dao;

  setUp(() {
    db = openTestDatabase();
    dao = db.syncDao;
  });

  tearDown(() => db.close());

  Future<List<int>> branchIds() async =>
      (await db.select(db.branches).get()).map((row) => row.id).toList()
        ..sort();

  Future<List<String>> teachingIds() async =>
      (await db.select(db.teachings).get()).map((row) => row.id).toList()
        ..sort();

  group('Appliquer une page', () {
    test('valide les lignes et le curseur ensemble', () async {
      await dao.applyPage(
        dao.branchesCollection,
        upserts: [branchRow(1, 'Lomé'), branchRow(2, 'Kara')],
        cursor: 'curseur-1',
      );

      expect(await branchIds(), [1, 2]);
      expect(await dao.cursorFor(SyncCollectionKey.branches), 'curseur-1');
    });

    test(
      "une coupure entre les lignes et le curseur ne valide **ni l'un ni "
      "l'autre**",
      () async {
        await dao.applyPage(
          dao.branchesCollection,
          upserts: [branchRow(1, 'Lomé')],
          cursor: 'curseur-1',
        );

        dao.crashBetweenRowsAndCursor = () async => throw const _Coupure();

        await expectLater(
          dao.applyPage(
            dao.branchesCollection,
            upserts: [branchRow(2, 'Kara')],
            cursor: 'curseur-2',
          ),
          throwsA(isA<_Coupure>()),
        );

        // Sans cette garantie, le curseur serait passé devant une ligne jamais
        // appliquée : un trou que le keyset ne repasserait plus jamais.
        expect(await branchIds(), [1]);
        expect(await dao.cursorFor(SyncCollectionKey.branches), 'curseur-1');
      },
    );

    test('une ligne déjà connue est remplacée, pas dupliquée', () async {
      await dao.applyPage(
        dao.branchesCollection,
        upserts: [branchRow(1, 'Lomé')],
        cursor: 'c1',
      );
      await dao.applyPage(
        dao.branchesCollection,
        upserts: [branchRow(1, 'Lomé (rénovée)')],
        cursor: 'c2',
      );

      final rows = await db.select(db.branches).get();
      expect(rows, hasLength(1));
      expect(rows.single.name, 'Lomé (rénovée)');
    });

    test('une rétractation fait quitter la ligne du magasin', () async {
      await dao.applyPage(
        dao.teachingsCollection,
        upserts: [teachingRow('t-1'), teachingRow('t-2')],
        cursor: 'c1',
      );

      await dao.applyPage(
        dao.teachingsCollection,
        deletedIds: const ['t-1'],
        cursor: 'c2',
      );

      expect(await teachingIds(), ['t-2']);
      expect(await dao.cursorFor(SyncCollectionKey.teachings), 'c2');
    });

    test('le curseur nul rendu par le serveur est stocké tel quel', () async {
      await dao.applyPage(dao.branchesCollection, cursor: null);

      expect(await dao.cursorFor(SyncCollectionKey.branches), isNull);
      expect(await dao.allCursors(), isEmpty);
    });

    test('chaque collection a son propre curseur', () async {
      await dao.applyPage(dao.branchesCollection, cursor: 'b1');
      await dao.applyPage(dao.contributorsCollection, cursor: 'c1');

      expect(await dao.allCursors(), {
        SyncCollectionKey.branches: 'b1',
        SyncCollectionKey.contributors: 'c1',
      });
    });
  });

  group('Resynchronisation — un remplacement, jamais une destruction', () {
    setUp(() async {
      await dao.applyPage(
        dao.branchesCollection,
        upserts: [
          branchRow(1, 'Lomé'),
          branchRow(2, 'Kara'),
          branchRow(3, 'Atakpamé'),
        ],
        cursor: 'curseur-ancien',
      );
    });

    test('le magasin ne se vide jamais pendant le re-tirage', () async {
      await dao.beginResync(SyncCollectionKey.branches);

      // Première page du re-tirage : rien n'a été effacé, et l'ancien contenu
      // continue de peindre les écrans.
      await dao.applyResyncPage(
        dao.branchesCollection,
        upserts: [branchRow(1, 'Lomé (à jour)')],
      );

      expect(await branchIds(), [1, 2, 3]);
      // Le curseur n'a surtout pas bougé : une coupure ici doit faire
      // recommencer le cycle, pas le reprendre au milieu.
      expect(await dao.cursorFor(SyncCollectionKey.branches), 'curseur-ancien');
    });

    test('la transaction finale supprime ce que le cycle n\'a pas revu',
        () async {
      await dao.beginResync(SyncCollectionKey.branches);
      await dao.applyResyncPage(
        dao.branchesCollection,
        upserts: [branchRow(1, 'Lomé (à jour)')],
      );
      await dao.applyResyncPage(
        dao.branchesCollection,
        upserts: [branchRow(4, 'Sokodé')],
      );

      final swept = await dao.finishResync(
        dao.branchesCollection,
        cursor: 'curseur-neuf',
      );

      expect(swept, 2, reason: 'Kara et Atakpamé n\'ont pas été revues');
      expect(await branchIds(), [1, 4]);
      expect(await dao.cursorFor(SyncCollectionKey.branches), 'curseur-neuf');
      expect(await dao.resyncToken(SyncCollectionKey.branches), isNull);
    });

    test('une coupure en plein cycle ne détruit rien et laisse le jeton',
        () async {
      await dao.beginResync(SyncCollectionKey.branches);
      await dao.applyResyncPage(
        dao.branchesCollection,
        upserts: [branchRow(1, 'Lomé (à jour)')],
      );

      // … et le réseau tombe. Rien de plus n'arrive.
      expect(await branchIds(), [1, 2, 3]);
      expect(await dao.resyncToken(SyncCollectionKey.branches), isNotNull);
    });

    test('le cycle suivant repart de zéro et referme le trou', () async {
      await dao.beginResync(SyncCollectionKey.branches);
      await dao.applyResyncPage(
        dao.branchesCollection,
        upserts: [branchRow(1, 'Lomé (à jour)')],
      );

      // Coupure : le cycle recommence entièrement.
      await dao.beginResync(SyncCollectionKey.branches);
      await dao.applyResyncPage(
        dao.branchesCollection,
        upserts: [branchRow(1, 'Lomé (à jour)'), branchRow(2, 'Kara')],
      );
      await dao.finishResync(dao.branchesCollection, cursor: 'curseur-neuf');

      expect(await branchIds(), [1, 2]);
    });

    test('fermer un cycle qui n\'a jamais été ouvert lève', () async {
      await expectLater(
        dao.finishResync(dao.branchesCollection, cursor: 'peu importe'),
        throwsA(isA<StateError>()),
      );
      expect(await branchIds(), [1, 2, 3]);
    });

    test('le jeton est posable dans la transaction qui l\'apprend', () async {
      // Le moteur apprend `full_resync: true` en appliquant une page : les deux
      // doivent tenir dans la même transaction.
      await db.transaction(() async {
        await dao.applyPage(
          dao.branchesCollection,
          upserts: [branchRow(5, 'Dapaong')],
          cursor: 'c-appris',
        );
        await dao.beginResync(SyncCollectionKey.branches);
      });

      expect(await dao.resyncToken(SyncCollectionKey.branches), isNotNull);
      expect(await dao.cursorFor(SyncCollectionKey.branches), 'c-appris');
    });

    test('la transaction finale ne valide rien à moitié', () async {
      await dao.beginResync(SyncCollectionKey.branches);
      await dao.applyResyncPage(
        dao.branchesCollection,
        upserts: [branchRow(1, 'Lomé')],
      );

      // Le balayage, le curseur et la levée du jeton voyagent ensemble : si
      // quoi que ce soit échoue après eux, aucun des trois n'a eu lieu.
      await expectLater(
        db.transaction(() async {
          await dao.finishResync(dao.branchesCollection,
              cursor: 'curseur-neuf');
          throw const _Coupure();
        }),
        throwsA(isA<_Coupure>()),
      );

      expect(await branchIds(), [1, 2, 3]);
      expect(await dao.cursorFor(SyncCollectionKey.branches), 'curseur-ancien');
      expect(await dao.resyncToken(SyncCollectionKey.branches), isNotNull);
    });

    test('une rétractation reçue en plein cycle est honorée', () async {
      await dao.applyPage(
        dao.teachingsCollection,
        upserts: [teachingRow('t-1'), teachingRow('t-2')],
        cursor: 'c1',
      );

      await dao.beginResync(SyncCollectionKey.teachings);
      await dao.applyResyncPage(
        dao.teachingsCollection,
        upserts: [teachingRow('t-1')],
        deletedIds: const ['t-2'],
      );

      // Retirée tout de suite, sans attendre le balayage : une rétractation
      // est un ordre du serveur, pas une déduction du cycle.
      expect(await teachingIds(), ['t-1']);

      await dao.finishResync(dao.teachingsCollection, cursor: 'c2');
      expect(await teachingIds(), ['t-1']);
    });

    test('une collection resynchronisée n\'en balaie pas une autre', () async {
      await dao.applyPage(
        dao.contributorsCollection,
        upserts: [contributorRow(1, 'Pasteur Kossi')],
        cursor: 'c1',
      );

      await dao.beginResync(SyncCollectionKey.branches);
      await dao.applyResyncPage(
        dao.branchesCollection,
        upserts: [branchRow(1, 'Lomé')],
      );
      await dao.finishResync(dao.branchesCollection, cursor: 'c-neuf');

      expect(await db.select(db.contributors).get(), hasLength(1));
      expect(await dao.cursorFor(SyncCollectionKey.contributors), 'c1');
    });
  });

  group('État global', () {
    test('la scope_version n\'est pas rangée avec les curseurs', () {
      // Structurel, et volontairement : rangée par collection, elle serait
      // validée collection par collection, et une coupure entre deux
      // collections éteindrait à jamais un resync qui n'a pas eu lieu.
      expect(
        db.syncCursors.columnsByName.keys,
        unorderedEquals(['collection', 'cursor', 'synced_at']),
      );
      expect(db.syncState.columnsByName.keys, contains('scope_version'));
    });

    test('appliquer une page ne touche jamais la version de périmètre',
        () async {
      await dao.writeScopeVersion(3);

      await dao.applyPage(
        dao.teachingsCollection,
        upserts: [teachingRow('t-1')],
        cursor: 'c1',
      );
      await dao.beginResync(SyncCollectionKey.teachings);
      await dao.finishResync(dao.teachingsCollection, cursor: 'c2');

      expect(await dao.readScopeVersion(), 3);
    });

    test('la version de périmètre part de null et se relit telle qu\'écrite',
        () async {
      // Ce test ne couvre **que** l'emplacement. La discipline d'ADR-0027 —
      // retenir la version en mémoire pendant tout le cycle et ne la persister
      // qu'après que chaque collection marquée a purgé et re-tiré jusqu'à
      // `has_more: false` — appartient au moteur de synchronisation (#29), qui
      // n'existe pas encore. Le magasin ne peut qu'offrir un emplacement qui ne
      // se valide avec rien d'autre ; il ne peut pas forcer l'ordre des appels.
      expect(await dao.readScopeVersion(), isNull);
      await dao.writeScopeVersion(7);
      expect(await dao.readScopeVersion(), 7);
    });

    test('l\'état global tient sur une seule ligne', () async {
      await expectLater(
        db.into(db.syncState).insert(
              const SyncStateCompanion(id: Value(2)),
            ),
        throwsA(anything),
      );
      expect(await db.select(db.syncState).get(), hasLength(1));
    });
  });

  group('Aucune clé étrangère entre collections', () {
    // Vérifié contre le **DDL réellement créé**, et non contre la déclaration
    // Dart : SQLite n'applique les clés étrangères que si `PRAGMA
    // foreign_keys` est actif, donc une contrainte déclarée mais inerte
    // passerait inaperçue dans un test de comportement — jusqu'au jour où
    // quelqu'un activerait le pragma, et où une page parfaitement valide
    // échouerait tout entière parce que son intervenant n'est pas encore
    // arrivé.
    for (final table in const [
      'branches',
      'teaching_types',
      'contributors',
      'teachings',
    ]) {
      test('« $table » n\'en déclare aucune', () async {
        final rows =
            await db.customSelect('PRAGMA foreign_key_list($table)').get();
        expect(
          rows,
          isEmpty,
          reason: 'Les collections se resynchronisent séparément : une '
              'contrainte ferait échouer l\'application d\'une page valide.',
        );
      });
    }

    test('un enseignement s\'écrit sans que ses cibles existent', () async {
      // Le pendant comportemental : `contributorId` et `teachingTypeId` sont
      // des entiers nus, ils ne désignent rien qui doive exister.
      await dao.applyPage(
        dao.teachingsCollection,
        upserts: [teachingRow('t-1', contributorId: 404, teachingTypeId: 404)],
        cursor: 'c1',
      );
      expect(await teachingIds(), ['t-1']);
    });
  });
}
