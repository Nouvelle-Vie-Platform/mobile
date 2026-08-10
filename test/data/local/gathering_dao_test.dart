// Les lectures du magasin, côté **rassemblements**.
//
// Ce fichier ne réinvente aucune règle : ce sont celles de
// `mediatheque_dao_test.dart`, rejouées sur l'autre famille — jointures
// tolérantes, cascade de couleur terminée à la lecture, « pas de rassemblement,
// pas de section ». Ce qu'il vérifie **en plus**, et qui n'existait pas avant
// #34, c'est la **cloison** : les deux familles arrivent par deux canaux, se
// rangent dans deux tables, et ne se voient jamais.

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/gathering_dao.dart';
import 'package:maison_du_miracle/data/local/mediatheque_dao.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';

import 'local_database_fixtures.dart';

void main() {
  late AppDatabase db;
  late SyncDao sync;
  late GatheringDao dao;

  setUp(() {
    db = openTestDatabase();
    sync = db.syncDao;
    dao = db.gatheringDao;
  });

  tearDown(() => db.close());

  group('Magasin vide au premier lancement', () {
    test('les deux tables naissent vides et ne se plaignent pas', () async {
      // Un magasin vide est la réponse **normale** d'un premier lancement, pas
      // une erreur : la synchronisation ne l'a pas encore rempli.
      expect(await dao.latestGatherings().get(), isEmpty);
      expect(await dao.homeSections().get(), isEmpty);
      expect(await dao.gatheringById('inconnu').getSingleOrNull(), isNull);
    });
  });

  group('Jointures tolérantes', () {
    test('un rassemblement sans rubrique s\'affiche quand même', () async {
      await sync.applyPage(
        sync.gatheringsCollection,
        upserts: [gatheringRow('g-1', teachingTypeId: 7, contributorId: 12)],
        cursor: 'c1',
      );

      final rows = await dao.latestGatherings().get();

      // Une jointure stricte l'aurait fait disparaître de l'écran : on aurait
      // perdu le contenu au lieu d'une ligne de texte.
      expect(rows, hasLength(1));
      expect(rows.single.gathering.id, 'g-1');
      expect(rows.single.type, isNull);
      expect(rows.single.contributor, isNull);
      expect(rows.single.color, isNull);
    });

    test('un rassemblement sans rubrique du tout reste lisible', () async {
      await sync.applyPage(
        sync.gatheringsCollection,
        upserts: [gatheringRow('g-1')],
        cursor: 'c1',
      );

      final row = await dao.gatheringById('g-1').getSingleOrNull();
      expect(row, isNotNull);
      expect(row!.type, isNull);
    });

    test('l\'intervenant paraît dès que sa collection l\'a livré', () async {
      // `contributors` est **commune aux deux familles** : c'est le même
      // référentiel, et il n'a pas été dédoublé.
      await sync.applyPage(
        sync.gatheringsCollection,
        upserts: [gatheringRow('g-1', contributorId: 12)],
        cursor: 'c1',
      );
      await sync.applyPage(
        sync.contributorsCollection,
        upserts: [contributorRow(12, 'Chorale Nouvelle Vie')],
        cursor: 'c1',
      );

      final rows = await dao.latestGatherings().get();
      expect(rows.single.contributor?.name, 'Chorale Nouvelle Vie');
    });
  });

  group('La cascade de couleur se termine à la lecture', () {
    setUp(() async {
      await sync.applyPage(
        sync.gatheringTypesCollection,
        upserts: [
          gatheringTypeRow(2,
              label: const {'fr': 'Concerts'}, color: '#0F6E5C'),
        ],
        cursor: 'c1',
      );
    });

    test('la couleur de la ligne l\'emporte', () async {
      await sync.applyPage(
        sync.gatheringsCollection,
        upserts: [gatheringRow('g-1', teachingTypeId: 2, color: '#FF0000')],
        cursor: 'c1',
      );

      expect((await dao.gatheringById('g-1').getSingle()).color, '#FF0000');
    });

    test('une couleur nulle hérite de la rubrique', () async {
      await sync.applyPage(
        sync.gatheringsCollection,
        upserts: [gatheringRow('g-1', teachingTypeId: 2)],
        cursor: 'c1',
      );

      expect((await dao.gatheringById('g-1').getSingle()).color, '#0F6E5C');
    });

    test('changer la couleur de la rubrique change celle des rassemblements',
        () async {
      await sync.applyPage(
        sync.gatheringsCollection,
        upserts: [gatheringRow('g-1', teachingTypeId: 2)],
        cursor: 'c1',
      );
      await sync.applyPage(
        sync.gatheringTypesCollection,
        upserts: [
          gatheringTypeRow(2,
              label: const {'fr': 'Concerts'}, color: '#00FF00'),
        ],
        cursor: 'c2',
      );

      expect((await dao.gatheringById('g-1').getSingle()).color, '#00FF00');
    });
  });

  group('Une rétractation retire un rassemblement', () {
    test('la ligne quitte le magasin, et n\'en laisse aucune trace', () async {
      await sync.applyPage(
        sync.gatheringsCollection,
        upserts: [gatheringRow('g-1'), gatheringRow('g-2')],
        cursor: 'c1',
      );
      expect(await dao.latestGatherings().get(), hasLength(2));

      // La forme du fil est `{ id, deletedAt }` (ADR-0025) : le tri
      // « rétractation ou ligne » est fait en amont par le moteur, le magasin ne
      // reçoit qu'un identifiant à retirer.
      await sync.applyPage(
        sync.gatheringsCollection,
        deletedIds: const ['g-1'],
        cursor: 'c2',
      );

      final rows = await dao.latestGatherings().get();
      expect(rows.map((r) => r.gathering.id), ['g-2']);
      // Le retrait est un retrait : garder le titre d'un contenu dépublié
      // annulerait le geste.
      expect(await dao.gatheringById('g-1').getSingleOrNull(), isNull);
    });

    test('la rétractation du dernier rassemblement vide la section', () async {
      await sync.applyPage(
        sync.gatheringTypesCollection,
        upserts: [
          gatheringTypeRow(1, label: const {'fr': 'Concerts'})
        ],
        cursor: 'c1',
      );
      await sync.applyPage(
        sync.gatheringsCollection,
        upserts: [gatheringRow('g-1', teachingTypeId: 1)],
        cursor: 'c1',
      );
      expect(await dao.homeSections().get(), hasLength(1));

      await sync.applyPage(
        sync.gatheringsCollection,
        deletedIds: const ['g-1'],
        cursor: 'c2',
      );

      expect(await dao.homeSections().get(), isEmpty);
    });
  });

  group('Pas de rassemblement, pas de section', () {
    test('une rubrique sans rassemblement local ne sort pas', () async {
      await sync.applyPage(
        sync.gatheringTypesCollection,
        upserts: [
          gatheringTypeRow(1, label: const {'fr': 'Concerts'}, position: 0),
          gatheringTypeRow(2, label: const {'fr': 'Conventions'}, position: 1),
        ],
        cursor: 'c1',
      );
      await sync.applyPage(
        sync.gatheringsCollection,
        upserts: [gatheringRow('g-1', teachingTypeId: 1)],
        cursor: 'c1',
      );

      final sections = await dao.homeSections().get();
      expect(sections.map((s) => s.type.id), [1]);
      expect(sections.single.gatheringCount, 1);
    });

    test('une rubrique masquée ne sort pas, même remplie', () async {
      await sync.applyPage(
        sync.gatheringTypesCollection,
        upserts: [
          gatheringTypeRow(
            1,
            label: const {'fr': 'Archives'},
            visibleOnHome: false,
          ),
        ],
        cursor: 'c1',
      );
      await sync.applyPage(
        sync.gatheringsCollection,
        upserts: [gatheringRow('g-1', teachingTypeId: 1)],
        cursor: 'c1',
      );

      expect(await dao.homeSections().get(), isEmpty);
      // Mais ses rassemblements restent lisibles ailleurs.
      expect(await dao.gatheringsOfType(1).get(), hasLength(1));
    });

    test('les sections sortent dans l\'ordre voulu par le serveur', () async {
      await sync.applyPage(
        sync.gatheringTypesCollection,
        upserts: [
          gatheringTypeRow(1, label: const {'fr': 'Troisième'}, position: 30),
          gatheringTypeRow(2, label: const {'fr': 'Première'}, position: 10),
          gatheringTypeRow(3, label: const {'fr': 'Deuxième'}, position: 20),
        ],
        cursor: 'c1',
      );
      await sync.applyPage(
        sync.gatheringsCollection,
        upserts: [
          gatheringRow('a', teachingTypeId: 1),
          gatheringRow('b', teachingTypeId: 2),
          gatheringRow('c', teachingTypeId: 3),
          gatheringRow('d', teachingTypeId: 3),
        ],
        cursor: 'c1',
      );

      final sections = await dao.homeSections().get();
      expect(sections.map((s) => s.type.id), [2, 3, 1]);
      expect(sections.map((s) => s.gatheringCount), [1, 2, 1]);
    });
  });

  group('Les derniers rassemblements sortent du plus récent au plus ancien',
      () {
    test('le tri porte sur `publishedAt`, comme la médiathèque', () async {
      // **Le même tri, et c'est une décision** : `publishedAt` date la mise à
      // disposition, l'ordre éditorial. Trier sur `recordedAt` — la date du
      // concert — rangerait le catalogue par date d'évènement, ce qui est le
      // travail du calendrier (`events`), pas d'une médiathèque.
      await sync.applyPage(
        sync.gatheringsCollection,
        upserts: [
          gatheringRow('vieux', publishedAt: DateTime.utc(2026, 1, 1)),
          gatheringRow('recent', publishedAt: DateTime.utc(2026, 4, 1)),
          gatheringRow('sans-date'),
        ],
        cursor: 'c1',
      );

      final rows = await dao.latestGatherings(limit: 2).get();
      expect(rows.map((r) => r.gathering.id), ['recent', 'vieux']);
    });
  });

  group('La cloison entre les deux familles', () {
    late MediathequeDao mediatheque;

    setUp(() async {
      mediatheque = db.mediathequeDao;
      // Deux rubriques du **même identifiant** dans les deux référentiels : le
      // cas qui fait tomber toute confusion de tables. Rien ne l'interdit — ce
      // sont deux collections, et les identifiants d'un référentiel de famille
      // n'ont aucune raison d'être disjoints de l'autre.
      await sync.applyPage(
        sync.teachingTypesCollection,
        upserts: [
          teachingTypeRow(1, label: const {'fr': 'Dimanche'})
        ],
        cursor: 'c1',
      );
      await sync.applyPage(
        sync.gatheringTypesCollection,
        upserts: [
          gatheringTypeRow(1, label: const {'fr': 'Concerts'})
        ],
        cursor: 'c1',
      );
      await sync.applyPage(
        sync.teachingsCollection,
        upserts: [teachingRow('t-1', teachingTypeId: 1)],
        cursor: 'c1',
      );
      await sync.applyPage(
        sync.gatheringsCollection,
        upserts: [gatheringRow('g-1', teachingTypeId: 1)],
        cursor: 'c1',
      );
    });

    test('un rassemblement n\'apparaît jamais dans la médiathèque', () async {
      final teachings = await mediatheque.latestTeachings().get();
      expect(teachings.map((r) => r.teaching.id), ['t-1']);
      expect(await mediatheque.teachingById('g-1').getSingleOrNull(), isNull);
      expect(
        (await mediatheque.teachingsOfType(1).get()).map((r) => r.teaching.id),
        ['t-1'],
      );
    });

    test('un enseignement n\'apparaît jamais chez les rassemblements',
        () async {
      final gatherings = await dao.latestGatherings().get();
      expect(gatherings.map((r) => r.gathering.id), ['g-1']);
      expect(await dao.gatheringById('t-1').getSingleOrNull(), isNull);
      expect(
        (await dao.gatheringsOfType(1).get()).map((r) => r.gathering.id),
        ['g-1'],
      );
    });

    test('chaque section joint sa propre rubrique, jamais celle de l\'autre',
        () async {
      // Même `id` de rubrique de part et d'autre : c'est la **table jointe**
      // qui décide, jamais l'identifiant.
      final teachingSections = await mediatheque.homeSections().get();
      final gatheringSections = await dao.homeSections().get();

      expect(teachingSections.single.type.label['fr'], 'Dimanche');
      expect(gatheringSections.single.type.label['fr'], 'Concerts');
    });

    test('une rétractation de rassemblement ne touche pas la médiathèque',
        () async {
      await sync.applyPage(
        sync.gatheringsCollection,
        deletedIds: const ['g-1'],
        cursor: 'c2',
      );

      expect(await dao.latestGatherings().get(), isEmpty);
      expect(await mediatheque.latestTeachings().get(), hasLength(1));
    });
  });
}
