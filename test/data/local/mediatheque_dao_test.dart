import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/mediatheque_dao.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/utils/i18n_text.dart';

import 'local_database_fixtures.dart';

void main() {
  late AppDatabase db;
  late SyncDao sync;
  late MediathequeDao dao;

  setUp(() {
    db = openTestDatabase();
    sync = db.syncDao;
    dao = db.mediathequeDao;
  });

  tearDown(() => db.close());

  group('Jointures tolérantes', () {
    test('un enseignement dont l\'intervenant manque s\'affiche quand même',
        () async {
      await sync.applyPage(
        sync.teachingsCollection,
        upserts: [teachingRow('t-1', contributorId: 12, teachingTypeId: 2)],
        cursor: 'c1',
      );

      final rows = await dao.latestTeachings().get();

      // Une jointure stricte l'aurait fait disparaître de l'écran : on aurait
      // perdu le contenu au lieu d'une ligne de texte.
      expect(rows, hasLength(1));
      expect(rows.single.teaching.id, 't-1');
      expect(rows.single.contributor, isNull);
      expect(rows.single.type, isNull);
    });

    test('l\'intervenant paraît dès que sa collection l\'a livré', () async {
      await sync.applyPage(
        sync.teachingsCollection,
        upserts: [teachingRow('t-1', contributorId: 12)],
        cursor: 'c1',
      );
      await sync.applyPage(
        sync.contributorsCollection,
        upserts: [contributorRow(12, 'Pasteur Kossi')],
        cursor: 'c1',
      );

      final rows = await dao.latestTeachings().get();
      expect(rows.single.contributor?.name, 'Pasteur Kossi');
    });

    test('un enseignement sans rubrique du tout reste lisible', () async {
      await sync.applyPage(
        sync.teachingsCollection,
        upserts: [teachingRow('t-1')],
        cursor: 'c1',
      );

      final row = await dao.teachingById('t-1').getSingleOrNull();
      expect(row, isNotNull);
      expect(row!.type, isNull);
      expect(row.color, isNull);
    });
  });

  group('La cascade de couleur se termine à la lecture', () {
    setUp(() async {
      await sync.applyPage(
        sync.teachingTypesCollection,
        upserts: [
          teachingTypeRow(2, label: const {'fr': 'Dimanche'}, color: '#223B8C'),
        ],
        cursor: 'c1',
      );
    });

    test('la couleur de la ligne l\'emporte', () async {
      await sync.applyPage(
        sync.teachingsCollection,
        upserts: [teachingRow('t-1', teachingTypeId: 2, color: '#FF0000')],
        cursor: 'c1',
      );

      expect((await dao.teachingById('t-1').getSingle()).color, '#FF0000');
    });

    test('une couleur nulle hérite de la rubrique', () async {
      await sync.applyPage(
        sync.teachingsCollection,
        upserts: [teachingRow('t-1', teachingTypeId: 2)],
        cursor: 'c1',
      );

      expect((await dao.teachingById('t-1').getSingle()).color, '#223B8C');
    });

    test('changer la couleur de la rubrique change celle des enseignements',
        () async {
      await sync.applyPage(
        sync.teachingsCollection,
        upserts: [teachingRow('t-1', teachingTypeId: 2)],
        cursor: 'c1',
      );

      // Une seule ligne traverse le réseau — pas tout le catalogue.
      await sync.applyPage(
        sync.teachingTypesCollection,
        upserts: [
          teachingTypeRow(2, label: const {'fr': 'Dimanche'}, color: '#00FF00'),
        ],
        cursor: 'c2',
      );

      expect((await dao.teachingById('t-1').getSingle()).color, '#00FF00');
    });
  });

  group('Pas d\'enseignement, pas de section', () {
    test('une rubrique sans enseignement local ne sort pas', () async {
      await sync.applyPage(
        sync.teachingTypesCollection,
        upserts: [
          teachingTypeRow(1, label: const {'fr': 'Dimanche'}, position: 0),
          teachingTypeRow(2, label: const {'fr': 'Étude'}, position: 1),
        ],
        cursor: 'c1',
      );
      await sync.applyPage(
        sync.teachingsCollection,
        upserts: [teachingRow('t-1', teachingTypeId: 1)],
        cursor: 'c1',
      );

      final sections = await dao.homeSections().get();

      expect(sections.map((s) => s.type.id), [1]);
      expect(sections.single.teachingCount, 1);
    });

    test(
      'une rubrique supprimée côté serveur disparaît d\'elle-même quand ses '
      'enseignements ont été reclassés',
      () async {
        await sync.applyPage(
          sync.teachingTypesCollection,
          upserts: [
            teachingTypeRow(1, label: const {'fr': 'Dimanche'}),
            teachingTypeRow(9, label: const {'fr': 'Rubrique retirée'}),
          ],
          cursor: 'c1',
        );
        await sync.applyPage(
          sync.teachingsCollection,
          upserts: [teachingRow('t-1', teachingTypeId: 9)],
          cursor: 'c1',
        );
        expect((await dao.homeSections().get()).map((s) => s.type.id), [9]);

        // L'administrateur reclasse — ce mouvement-là voyage —, puis supprime
        // la rubrique **durement, sans tombstone** : rien n'annonce le retrait,
        // la ligne locale reste. Elle cesse pourtant d'être une section.
        await sync.applyPage(
          sync.teachingsCollection,
          upserts: [teachingRow('t-1', teachingTypeId: 1)],
          cursor: 'c2',
        );

        expect((await dao.homeSections().get()).map((s) => s.type.id), [1]);
        // La ligne fantôme est toujours en base : c'est la lecture qui la
        // neutralise, aucune suppression locale inventée.
        expect(await db.select(db.teachingTypes).get(), hasLength(2));
      },
    );

    test('une rubrique masquée ne sort pas, même remplie', () async {
      await sync.applyPage(
        sync.teachingTypesCollection,
        upserts: [
          teachingTypeRow(
            1,
            label: const {'fr': 'Archives'},
            visibleOnHome: false,
          ),
        ],
        cursor: 'c1',
      );
      await sync.applyPage(
        sync.teachingsCollection,
        upserts: [teachingRow('t-1', teachingTypeId: 1)],
        cursor: 'c1',
      );

      expect(await dao.homeSections().get(), isEmpty);
      // Mais ses enseignements restent lisibles ailleurs.
      expect(await dao.teachingsOfType(1).get(), hasLength(1));
    });

    test('les sections sortent dans l\'ordre voulu par le serveur', () async {
      await sync.applyPage(
        sync.teachingTypesCollection,
        upserts: [
          teachingTypeRow(1, label: const {'fr': 'Troisième'}, position: 30),
          teachingTypeRow(2, label: const {'fr': 'Première'}, position: 10),
          teachingTypeRow(3, label: const {'fr': 'Deuxième'}, position: 20),
        ],
        cursor: 'c1',
      );
      await sync.applyPage(
        sync.teachingsCollection,
        upserts: [
          teachingRow('a', teachingTypeId: 1),
          teachingRow('b', teachingTypeId: 2),
          teachingRow('c', teachingTypeId: 3),
          teachingRow('d', teachingTypeId: 3),
        ],
        cursor: 'c1',
      );

      final sections = await dao.homeSections().get();
      expect(sections.map((s) => s.type.id), [2, 3, 1]);
      expect(sections.map((s) => s.teachingCount), [1, 2, 1]);
    });
  });

  group('Le magasin stocke ce que le serveur envoie', () {
    test('le libellé est conservé en carte de traduction entière', () async {
      await sync.applyPage(
        sync.teachingTypesCollection,
        upserts: [
          teachingTypeRow(
            1,
            label: const {'fr': 'Dimanche', 'en': 'Sunday', 'ee': 'Kɔsiɖa'},
          ),
        ],
        cursor: 'c1',
      );

      final row = await (db.select(db.teachingTypes)).getSingle();
      expect(row.label, {
        'fr': 'Dimanche',
        'en': 'Sunday',
        'ee': 'Kɔsiɖa',
      });

      // Le choix de la langue reste écrit à un seul endroit : `pick`.
      expect(pick(row.label, 'ee'), 'Kɔsiɖa');
      expect(pick(row.label, 'es'), 'Dimanche');
    });

    test('la date d\'enregistrement reste un jour, jamais un instant',
        () async {
      await sync.applyPage(
        sync.teachingsCollection,
        upserts: [teachingRow('t-1', recordedAt: '2026-04-12')],
        cursor: 'c1',
      );

      final row = await (db.select(db.teachings)).getSingle();
      expect(row.recordedAt, '2026-04-12');
    });

    test('les derniers enseignements sortent du plus récent au plus ancien',
        () async {
      await sync.applyPage(
        sync.teachingsCollection,
        upserts: [
          teachingRow('vieux', publishedAt: DateTime.utc(2026, 1, 1)),
          teachingRow('recent', publishedAt: DateTime.utc(2026, 4, 1)),
          teachingRow('sans-date'),
        ],
        cursor: 'c1',
      );

      final rows = await dao.latestTeachings(limit: 2).get();
      expect(rows.map((r) => r.teaching.id), ['recent', 'vieux']);
    });
  });
}
