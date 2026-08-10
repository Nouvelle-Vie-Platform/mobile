import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/repositories/gathering_repository.dart';
import 'package:maison_du_miracle/data/repositories/store_gathering_repository.dart';
import 'package:maison_du_miracle/models/gathering_view.dart';
import 'package:maison_du_miracle/models/models.dart';

import 'local/local_database_fixtures.dart';

/// Le repository de rassemblements, **sur le vrai magasin** (base en mémoire)
/// et sur son double.
///
/// Les quatre règles de présentation ne sont pas réimplémentées côté
/// rassemblements — elles vivent dans `models/content_view.dart`, partagées avec
/// la médiathèque. Ce fichier vérifie donc deux choses : que la traduction des
/// **lignes** en modèle de lecture est juste (la forme des valeurs : couleur
/// hexadécimale, jour de calendrier), et que les **deux implémentations donnent
/// le même résultat** — un double qui appliquerait d'autres règles laisserait
/// les bugs invisibles pendant tout le développement.
void main() {
  late AppDatabase db;
  late SyncDao sync;
  late StoreGatheringRepository repository;

  setUp(() {
    db = openTestDatabase();
    sync = db.syncDao;
    repository = StoreGatheringRepository(db.gatheringDao);
  });

  tearDown(() => db.close());

  group('Le magasin, traduit en modèle de lecture', () {
    test('la cascade de couleur se termine à la lecture', () async {
      await sync.applyPage(
        sync.gatheringTypesCollection,
        upserts: [
          gatheringTypeRow(2,
              label: const {'fr': 'Concerts'}, color: '#1FA971'),
        ],
        cursor: 'c1',
      );
      await sync.applyPage(
        sync.gatheringsCollection,
        upserts: [
          gatheringRow('g-propre', teachingTypeId: 2, color: '#3B5BD0'),
          gatheringRow('g-herite', teachingTypeId: 2),
          gatheringRow('g-orphelin'),
        ],
        cursor: 'c1',
      );

      final views = await _byId(repository);

      expect(views['g-propre']!.color, 0xFF3B5BD0);
      expect(views['g-herite']!.color, 0xFF1FA971);
      // Ni couleur propre, ni rubrique : le bleu de marque.
      expect(views['g-orphelin']!.color, kBrandFallbackColor);
    });

    test('une couleur illisible ne fait pas disparaître le rassemblement',
        () async {
      await sync.applyPage(
        sync.gatheringsCollection,
        upserts: [gatheringRow('g-1', color: 'bleu marine')],
        cursor: 'c1',
      );

      final views = await _byId(repository);
      expect(views['g-1']!.color, kBrandFallbackColor);
    });

    test('le libellé de rubrique se replie dans la langue demandée', () async {
      await sync.applyPage(
        sync.gatheringTypesCollection,
        upserts: [
          gatheringTypeRow(
            1,
            label: const {'fr': 'Concerts', 'ee': 'Hadzidziwo'},
          ),
        ],
        cursor: 'c1',
      );
      await sync.applyPage(
        sync.gatheringsCollection,
        upserts: [gatheringRow('g-1', teachingTypeId: 1)],
        cursor: 'c1',
      );

      expect(
        (await repository.gatheringById('g-1', locale: 'ee').first)!.typeLabel,
        'Hadzidziwo',
      );
      // Langue inconnue : `pick` replie sur le français, et nulle part ailleurs.
      expect(
        (await repository.gatheringById('g-1', locale: 'es').first)!.typeLabel,
        'Concerts',
      );
    });

    test('l\'absence d\'intervenant traverse, sans nom inventé', () async {
      await sync.applyPage(
        sync.gatheringsCollection,
        upserts: [gatheringRow('g-1', contributorId: 42)],
        cursor: 'c1',
      );

      final view = await repository.gatheringById('g-1', locale: 'fr').first;
      expect(view!.authorName, isNull);
    });

    test('le jour d\'enregistrement reste un jour, ancré en UTC', () async {
      await sync.applyPage(
        sync.gatheringsCollection,
        upserts: [gatheringRow('g-1', recordedAt: '2026-05-02')],
        cursor: 'c1',
      );

      final view = await repository.gatheringById('g-1', locale: 'fr').first;
      expect(view!.recordedAt, DateTime.utc(2026, 5, 2));
    });

    test('un identifiant qui ne résout rien rend `null`, pas une erreur',
        () async {
      expect(
        await repository.gatheringById('inconnu', locale: 'fr').first,
        isNull,
      );
    });
  });

  group('Le flux réémet quand la synchronisation écrit', () {
    test('une rétractation retire le rassemblement de l\'écran ouvert',
        () async {
      await sync.applyPage(
        sync.gatheringsCollection,
        upserts: [gatheringRow('g-1')],
        cursor: 'c1',
      );

      final stream = repository.gatheringById('g-1', locale: 'fr');
      final seen = <GatheringView?>[];
      final subscription = stream.listen(seen.add);
      addTearDown(subscription.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(seen.last, isNotNull);

      // C'est **le point** du `Stream` : un `Future` aurait livré une
      // photographie prise au moment du clic, et l'écran aurait continué de
      // montrer un contenu que le serveur a retiré.
      await sync.applyPage(
        sync.gatheringsCollection,
        deletedIds: const ['g-1'],
        cursor: 'c2',
      );
      await Future<void>.delayed(Duration.zero);

      expect(seen.last, isNull);
    });
  });

  group('Le double en mémoire applique les mêmes règles', () {
    test('cascade, repli de langue et absence d\'intervenant à l\'identique',
        () async {
      final double = InMemoryGatheringRepository(
        types: const [
          TeachingType(
            id: 1,
            slug: 'concerts',
            label: {'fr': 'Concerts', 'ee': 'Hadzidziwo'},
            color: 0xFF1FA971,
          ),
        ],
        gatherings: [
          Teaching(
            id: 'g-herite',
            title: 'Nuit de gloire',
            author: '',
            recordedAt: DateTime.utc(2026, 5, 2),
            publishedAt: DateTime.utc(2026, 5, 3),
            teachingTypeId: 1,
          ),
        ],
      );

      await sync.applyPage(
        sync.gatheringTypesCollection,
        upserts: [
          gatheringTypeRow(
            1,
            slug: 'concerts',
            label: const {'fr': 'Concerts', 'ee': 'Hadzidziwo'},
            color: '#1FA971',
          ),
        ],
        cursor: 'c1',
      );
      await sync.applyPage(
        sync.gatheringsCollection,
        upserts: [
          gatheringRow(
            'g-herite',
            title: 'Nuit de gloire',
            teachingTypeId: 1,
            publishedAt: DateTime.utc(2026, 5, 3),
            recordedAt: '2026-05-02',
          ),
        ],
        cursor: 'c1',
      );

      final fromStore =
          (await repository.latestGatherings(locale: 'ee').first).single;
      final fromDouble =
          (await double.latestGatherings(locale: 'ee').first).single;

      expect(fromDouble.color, fromStore.color);
      expect(fromDouble.typeLabel, fromStore.typeLabel);
      // Un auteur vide **est** une absence, des deux côtés.
      expect(fromDouble.authorName, isNull);
      expect(fromStore.authorName, isNull);
      expect(fromDouble.recordedAt, fromStore.recordedAt);
    });

    test('« pas de rassemblement, pas de section », des deux côtés', () async {
      final double = InMemoryGatheringRepository(
        types: const [
          TeachingType(id: 1, slug: 'concerts', label: {'fr': 'Concerts'}),
          TeachingType(id: 2, slug: 'vides', label: {'fr': 'Vides'}),
        ],
        gatherings: [
          Teaching(
            id: 'g-1',
            title: 'Nuit de gloire',
            author: 'Chorale',
            recordedAt: DateTime.utc(2026, 5, 2),
            publishedAt: DateTime.utc(2026, 5, 3),
            teachingTypeId: 1,
          ),
        ],
      );

      await sync.applyPage(
        sync.gatheringTypesCollection,
        upserts: [
          gatheringTypeRow(1, label: const {'fr': 'Concerts'}),
          gatheringTypeRow(2, label: const {'fr': 'Vides'}),
        ],
        cursor: 'c1',
      );
      await sync.applyPage(
        sync.gatheringsCollection,
        upserts: [gatheringRow('g-1', teachingTypeId: 1)],
        cursor: 'c1',
      );

      final fromStore = await repository.homeSections(locale: 'fr').first;
      final fromDouble = await double.homeSections(locale: 'fr').first;

      expect(fromStore.map((s) => s.teachingTypeId), [1]);
      expect(fromDouble.map((s) => s.teachingTypeId), [1]);
      expect(fromStore.single.itemCount, fromDouble.single.itemCount);
    });

    test(
        'le double par défaut sert les fixtures de rassemblement, pas celles '
        'de la médiathèque', () async {
      final gatherings = await InMemoryGatheringRepository()
          .latestGatherings(locale: 'fr')
          .first;

      expect(gatherings, isNotEmpty);
      expect(
        gatherings.map((g) => g.title),
        everyElement(isNot(contains('Dieu a le dernier mot'))),
      );
    });
  });
}

Future<Map<String, GatheringView>> _byId(GatheringRepository repository) async {
  final views = await repository.latestGatherings(locale: 'fr').first;
  return {for (final view in views) view.id: view};
}
