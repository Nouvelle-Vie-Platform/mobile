import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/repositories/mediatheque_repository.dart';
import 'package:maison_du_miracle/data/repositories/store_mediatheque_repository.dart';
import 'package:maison_du_miracle/models/mediatheque_view.dart';
import 'package:maison_du_miracle/models/models.dart';

import 'local/local_database_fixtures.dart';

/// Le repository de médiathèque, **sur le vrai magasin** (base en mémoire) et
/// sur son double.
///
/// Deux choses s'y vérifient, et la seconde compte autant que la première :
/// que la traduction des lignes en modèle de lecture soit juste, et que les
/// **deux implémentations donnent le même résultat**. Un double qui
/// appliquerait d'autres règles laisserait les bugs de cascade et de repli
/// invisibles en mode maquette — c'est-à-dire pendant tout le développement.
void main() {
  late AppDatabase db;
  late SyncDao sync;
  late StoreMediathequeRepository repository;

  setUp(() {
    db = openTestDatabase();
    sync = db.syncDao;
    repository = StoreMediathequeRepository(db.mediathequeDao);
  });

  tearDown(() => db.close());

  group('Le magasin, traduit en modèle de lecture', () {
    test('la cascade de couleur se termine à la lecture', () async {
      await sync.applyPage(
        sync.teachingTypesCollection,
        upserts: [
          teachingTypeRow(2, label: const {'fr': 'Étude'}, color: '#1FA971'),
        ],
        cursor: 'c1',
      );
      await sync.applyPage(
        sync.teachingsCollection,
        upserts: [
          teachingRow('t-propre', teachingTypeId: 2, color: '#3B5BD0'),
          teachingRow('t-herite', teachingTypeId: 2),
          teachingRow('t-orphelin'),
        ],
        cursor: 'c1',
      );

      final views = await _byId(repository);

      expect(views['t-propre']!.color, 0xFF3B5BD0);
      expect(views['t-herite']!.color, 0xFF1FA971);
      // Ni couleur propre, ni rubrique : le bleu de marque.
      expect(views['t-orphelin']!.color, kBrandFallbackColor);
    });

    test('une couleur illisible ne fait pas disparaître l\'enseignement',
        () async {
      // Une faute de frappe dans le portail est un défaut d'habillage, pas une
      // raison de perdre un contenu. La cascade continue simplement.
      await sync.applyPage(
        sync.teachingsCollection,
        upserts: [teachingRow('t-1', color: 'bleu marine')],
        cursor: 'c1',
      );

      final view = await repository.teachingById('t-1', locale: 'fr').first;
      expect(view, isNotNull);
      expect(view!.color, kBrandFallbackColor);
    });

    test('le libellé de rubrique est replié dans la langue demandée', () async {
      await sync.applyPage(
        sync.teachingTypesCollection,
        upserts: [
          teachingTypeRow(
            2,
            label: const {'fr': 'Études bibliques', 'en': 'Bible studies'},
          ),
        ],
        cursor: 'c1',
      );
      await sync.applyPage(
        sync.teachingsCollection,
        upserts: [teachingRow('t-1', teachingTypeId: 2)],
        cursor: 'c1',
      );

      final fr = await repository.teachingById('t-1', locale: 'fr').first;
      final en = await repository.teachingById('t-1', locale: 'en').first;
      // L'éwé manque : repli sur le français, décidé par `pick` et lui seul.
      final ee = await repository.teachingById('t-1', locale: 'ee').first;

      expect(fr!.typeLabel, 'Études bibliques');
      expect(en!.typeLabel, 'Bible studies');
      expect(ee!.typeLabel, 'Études bibliques');
    });

    test('les URL relatives du serveur ressortent absolues', () async {
      await sync.applyPage(
        sync.teachingsCollection,
        upserts: [teachingRow('t-1')],
        cursor: 'c1',
      );
      await db.customStatement(
        "UPDATE teachings SET image_landscape_url = '/uploads/t/a.jpg' "
        "WHERE id = 't-1'",
      );

      final view = await repository.teachingById('t-1', locale: 'fr').first;
      expect(view!.imageLandscapeUrl, 'http://localhost:3333/uploads/t/a.jpg');
    });

    test('un intervenant absent ne devient pas un nom inventé', () async {
      await sync.applyPage(
        sync.teachingsCollection,
        upserts: [teachingRow('t-1', contributorId: 12)],
        cursor: 'c1',
      );

      var view = await repository.teachingById('t-1', locale: 'fr').first;
      expect(view!.authorName, isNull, reason: 'pas d\'« Auteur inconnu »');
      expect(view.title, isNotEmpty,
          reason: 'le contenu s\'affiche quand même');

      // Le cycle suivant livre l'intervenant : la ligne paraît d'elle-même.
      await sync.applyPage(
        sync.contributorsCollection,
        upserts: [contributorRow(12, 'Pasteur Kossi')],
        cursor: 'c1',
      );
      view = await repository.teachingById('t-1', locale: 'fr').first;
      expect(view!.authorName, 'Pasteur Kossi');
    });

    test('le jour d\'enregistrement reste ancré en UTC', () async {
      // Lu en heure locale, un téléphone à l'est du serveur afficherait
      // « samedi 11 » un enseignement du dimanche 12.
      await sync.applyPage(
        sync.teachingsCollection,
        upserts: [teachingRow('t-1', recordedAt: '2026-04-12')],
        cursor: 'c1',
      );

      final view = await repository.teachingById('t-1', locale: 'fr').first;
      expect(view!.recordedAt, DateTime.utc(2026, 4, 12));
      expect(view.recordedAt!.isUtc, isTrue);
    });

    test('un identifiant qui ne résout rien rend `null`, sans lever', () async {
      final view = await repository.teachingById('inconnu', locale: 'fr').first;
      expect(view, isNull);
    });
  });

  group('Le flux suit le magasin', () {
    test('une rétractation retire le contenu du flux ouvert', () async {
      await sync.applyPage(
        sync.teachingsCollection,
        upserts: [teachingRow('t-1')],
        cursor: 'c1',
      );

      final seen = <TeachingView?>[];
      final subscription =
          repository.teachingById('t-1', locale: 'fr').listen(seen.add);
      await pumpEventQueue();

      // Ce que produit `{ id, deletedAt }` dans le flux delta (ADR-0025).
      await sync.applyPage(
        sync.teachingsCollection,
        deletedIds: const ['t-1'],
        cursor: 'c2',
      );
      await pumpEventQueue();
      await subscription.cancel();

      // C'est **tout** l'intérêt du `Stream` : un `Future` aurait livré une
      // photographie prise au moment du clic, et l'écran ouvert continuerait
      // d'afficher — lecteur compris — un contenu que le serveur a retiré.
      expect(seen.first, isNotNull);
      expect(seen.last, isNull);
    });
  });

  group('Sections de l\'accueil', () {
    test('pas d\'enseignement, pas de section', () async {
      await sync.applyPage(
        sync.teachingTypesCollection,
        upserts: [
          teachingTypeRow(1, label: const {'fr': 'Dimanche'}, position: 1),
          teachingTypeRow(2, label: const {'fr': 'Vide'}, position: 2),
          teachingTypeRow(
            3,
            label: const {'fr': 'Masquée'},
            position: 3,
            visibleOnHome: false,
          ),
        ],
        cursor: 'c1',
      );
      await sync.applyPage(
        sync.teachingsCollection,
        upserts: [
          teachingRow('t-1', teachingTypeId: 1),
          teachingRow('t-2', teachingTypeId: 3),
        ],
        cursor: 'c1',
      );

      final sections = await repository.homeSections(locale: 'fr').first;

      expect(sections.map((s) => s.teachingTypeId), [1]);
      expect(sections.single.label, 'Dimanche');
      expect(sections.single.teachingCount, 1);
    });
  });

  group('Le double en mémoire applique les mêmes règles', () {
    final types = [
      const TeachingType(
        id: 1,
        slug: 'dimanche',
        label: {'fr': 'Messages du dimanche', 'en': 'Sunday messages'},
        color: 0xFF223B8C,
        position: 1,
        layout: 'hero',
      ),
    ];

    test('cascade, repli de langue et absence d\'auteur, à l\'identique',
        () async {
      final inMemory = InMemoryMediathequeRepository(
        types: types,
        teachings: [
          Teaching(
            id: 't-herite',
            title: 'Hérite de sa rubrique',
            author: '',
            teachingTypeId: 1,
            recordedAt: DateTime.utc(2026, 4, 12),
            publishedAt: DateTime.utc(2026, 4, 12, 8),
          ),
        ],
      );

      final view = await inMemory.teachingById('t-herite', locale: 'en').first;

      expect(view!.color, 0xFF223B8C, reason: 'couleur héritée de la rubrique');
      expect(view.typeLabel, 'Sunday messages', reason: 'replié par `pick`');
      expect(view.authorName, isNull, reason: 'un auteur vide reste absent');
    });

    test('« pas d\'enseignement, pas de section » vaut aussi hors backend',
        () async {
      final empty = InMemoryMediathequeRepository(
        types: types,
        teachings: const [],
      );

      expect(await empty.homeSections(locale: 'fr').first, isEmpty);
    });
  });
}

Future<Map<String, TeachingView>> _byId(
  MediathequeRepository repository,
) async {
  final views = await repository.latestTeachings(locale: 'fr').first;
  return {for (final view in views) view.id: view};
}
