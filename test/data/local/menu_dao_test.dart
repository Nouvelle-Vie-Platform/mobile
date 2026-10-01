/// **Les règles de lecture d'un menu, jugées au niveau du magasin** (#82).
///
/// C'est **ici** que se vérifient le masquage, la fenêtre de publication, la
/// résolution des destinations, la résolution des slugs, l'arbre des sous-entrées
/// et « pas de contenu, pas de section ». L'écran, lui, ne répond que de « quel
/// onglet est actif, et que montre-t-il » — et c'est
/// `test/screens/media_library_screen_test.dart` qui l'interroge là-dessus.
///
/// **On écrit par le moteur, jamais par un insert nu** : `sync.applyPage` est le
/// seul chemin par lequel une ligne entre dans ce magasin en production, et un
/// test qui s'en écarterait vérifierait un état que la synchronisation ne produit
/// pas.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/repositories/store_menu_repository.dart';
import 'package:maison_du_miracle/models/menu_entry_view.dart';

import 'local_database_fixtures.dart';

void main() {
  late AppDatabase db;
  late SyncDao sync;
  late StoreMenuRepository menu;

  setUp(() {
    db = openTestDatabase();
    sync = db.syncDao;
    menu = StoreMenuRepository(db.menuDao);
  });

  tearDown(() => db.close());

  Future<void> putMenu(List<MenuEntriesCompanion> rows) =>
      sync.applyPage(sync.menuEntriesCollection, upserts: rows, cursor: 'm-1');

  Future<void> putTypes(List<TeachingTypesCompanion> rows) => sync.applyPage(
        sync.teachingTypesCollection,
        upserts: rows,
        cursor: 'tt-1',
      );

  Future<void> putTeachings(List<TeachingsCompanion> rows) => sync.applyPage(
        sync.teachingsCollection,
        upserts: rows,
        cursor: 't-1',
      );

  Future<void> putGatheringTypes(List<GatheringTypesCompanion> rows) =>
      sync.applyPage(
        sync.gatheringTypesCollection,
        upserts: rows,
        cursor: 'gt-1',
      );

  Future<void> putGatherings(List<GatheringsCompanion> rows) => sync.applyPage(
        sync.gatheringsCollection,
        upserts: rows,
        cursor: 'g-1',
      );

  /// L'horloge est **injectée** : la fenêtre de publication est la seule règle de
  /// ce fichier qu'on ne peut pas éprouver sans mentir sur l'heure.
  Future<List<MenuEntryView>> read(
    MenuSurface surface, {
    DateTime? at,
    String locale = 'fr',
  }) =>
      menu
          .menu(
            surface,
            locale: locale,
            now: () => at ?? DateTime.utc(2026, 6, 1, 12),
          )
          .first;

  /// Un catalogue garni : une rubrique, un enseignement dedans.
  Future<void> seedCatalogue() async {
    await putTypes([
      teachingTypeRow(1, label: {'fr': 'Prières'}, slug: 'prieres'),
      teachingTypeRow(2, label: {'fr': 'Dimanche'}, slug: 'dimanche'),
    ]);
    await putTeachings([
      teachingRow('t-1', title: 'Prier sans cesse', teachingTypeId: 1),
      teachingRow('t-2', title: 'Le pain du jour', teachingTypeId: 2),
    ]);
  }

  group('Le masquage et l\'ordre', () {
    test('les entrées sortent dans l\'ordre du rang de la surface', () async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1, label: {'fr': 'Prières'}, mediaPosition: 3),
        menuEntryRow(2, label: {'fr': 'Tout'}, mediaPosition: 1),
        menuEntryRow(3, label: {'fr': 'Dimanche'}, mediaPosition: 2),
      ]);

      final entries = await read(MenuSurface.mediaLibrary);

      // ⚠️ On vérifie l'**ordre entre deux entrées**, jamais une valeur de rang :
      // `SaveMenu` renumérote `1..n` par surface à chaque enregistrement.
      expect(entries.map((e) => e.label), ['Tout', 'Dimanche', 'Prières']);
    });

    test('les deux surfaces ont deux ordres indépendants', () async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1,
            label: {'fr': 'A'},
            mediaPosition: 1,
            homeVisible: true,
            homePosition: 2),
        menuEntryRow(2,
            label: {'fr': 'B'},
            mediaPosition: 2,
            homeVisible: true,
            homePosition: 1),
      ]);

      expect(
        (await read(MenuSurface.mediaLibrary)).map((e) => e.label),
        ['A', 'B'],
      );
      // Le rang de l'accueil n'est pas celui de la médiathèque, et le défaire
      // était l'objet de la tranche serveur : « une colonne de pied qui ne
      // reprendrait pas l'ordre de la barre du haut » n'est plus une anomalie.
      expect(
        (await read(MenuSurface.home)).map((e) => e.label),
        ['B', 'A'],
      );
    });

    test('une entrée éteinte sur la surface ne paraît pas, et reste en magasin',
        () async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1, label: {'fr': 'Visible'}),
        menuEntryRow(2, label: {'fr': 'Éteinte'}, mediaVisible: false),
      ]);

      expect(
        (await read(MenuSurface.mediaLibrary)).map((e) => e.label),
        ['Visible'],
      );
      // La ligne n'a pas quitté le magasin : c'est **le décochage lui-même** qui
      // voyage, et c'est la seule forme sous laquelle il puisse voyager — la
      // collection n'a pas de tombstone.
      expect(await db.select(db.menuEntries).get(), hasLength(2));
    });
  });

  group('La fenêtre de publication', () {
    test('elle s\'évalue à l\'heure courante, pas à l\'écriture', () async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(
          1,
          label: {'fr': 'Avent'},
          publishedFrom: DateTime.utc(2026, 12, 1),
          publishedUntil: DateTime.utc(2026, 12, 25),
        ),
      ]);

      // Avant la borne basse : rien.
      expect(
        await read(MenuSurface.mediaLibrary, at: DateTime.utc(2026, 11, 30)),
        isEmpty,
      );
      // Dedans : l'entrée paraît.
      expect(
        (await read(MenuSurface.mediaLibrary, at: DateTime.utc(2026, 12, 10)))
            .map((e) => e.label),
        ['Avent'],
      );
      // Après la borne haute : elle s'efface. Et c'est **la même ligne** qui a
      // produit les trois réponses : rien n'a été réécrit, seule l'heure a bougé.
      expect(
        await read(MenuSurface.mediaLibrary, at: DateTime.utc(2026, 12, 26)),
        isEmpty,
      );
    });

    test('les deux bornes sont des **instants**, pas des jours', () async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(
          1,
          label: {'fr': 'Veillée'},
          publishedFrom: DateTime.utc(2026, 6, 1, 20),
        ),
      ]);

      // Le même jour, deux heures différentes, deux réponses différentes. Si le
      // client comparait des jours — comme il le fait pour `seasons` —, les deux
      // seraient identiques, et l'entrée paraîtrait depuis le matin.
      expect(
        await read(MenuSurface.mediaLibrary, at: DateTime.utc(2026, 6, 1, 19)),
        isEmpty,
      );
      expect(
        await read(MenuSurface.mediaLibrary, at: DateTime.utc(2026, 6, 1, 21)),
        hasLength(1),
      );
    });

    test('les deux bornes sont indépendantes', () async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1,
            label: {'fr': 'Depuis'},
            mediaPosition: 1,
            publishedFrom: DateTime.utc(2026, 1, 1)),
        menuEntryRow(2,
            label: {'fr': 'Jusqu\'à'},
            mediaPosition: 2,
            publishedUntil: DateTime.utc(2027, 1, 1)),
      ]);

      expect(
        (await read(MenuSurface.mediaLibrary)).map((e) => e.label),
        ['Depuis', 'Jusqu\'à'],
      );
    });
  });

  group('La destination', () {
    test('un type inconnu fait disparaître l\'entrée, sans repli', () async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1, label: {'fr': 'Tout'}, mediaPosition: 1),
        // Un portail plus récent que ce binaire : « Faire un don » par un type
        // que personne ici ne connaît.
        menuEntryRow(2,
            label: {'fr': 'Faire un don'},
            mediaPosition: 2,
            destinationKind: 'paiement',
            destinationFamily: null),
      ]);

      final entries = await read(MenuSurface.mediaLibrary);

      // Elle disparaît, et surtout : elle ne s'est **pas** repliée sur le
      // catalogue. Une entrée « Faire un don » qui ouvrirait la liste des prêches
      // est pire qu'une entrée absente (décision 13 du cadrage).
      expect(entries.map((e) => e.label), ['Tout']);
      expect(
        entries.single.destination,
        const MenuCatalogue(family: MenuContentFamily.teaching),
      );
    });

    test('les destinations sans écran ici disparaissent toutes', () async {
      await seedCatalogue();
      await putMenu([
        // `theme` : aucune collection de séries n'est répliquée sur ce client.
        menuEntryRow(1,
            label: {'fr': 'Un thème'},
            destinationKind: 'theme',
            destinationFamily: null),
        // `intervenant` : il n'existe pas d'écran d'intervenant.
        menuEntryRow(2,
            label: {'fr': 'Un intervenant'},
            destinationKind: 'intervenant',
            destinationFamily: null),
        // Une page du site autre que la médiathèque.
        menuEntryRow(3,
            label: {'fr': 'Contact'},
            destinationKind: 'page',
            destinationPage: 'contact',
            destinationFamily: null),
        // Un `externe` sans adresse : rien à ouvrir.
        menuEntryRow(4,
            label: {'fr': 'Vide'},
            destinationKind: 'externe',
            destinationFamily: null),
      ]);

      expect(await read(MenuSurface.mediaLibrary), isEmpty);
    });

    test('`page: mediatheque` est le catalogue entier, famille enseignement',
        () async {
      await seedCatalogue();
      await putMenu([
        // L'entrée **indélébile** telle que `menu_seed.ts` la sème.
        menuEntryRow(1,
            label: null,
            labelKey: 'public.nav.mediatheque',
            destinationKind: 'page',
            destinationPage: 'mediatheque',
            destinationFamily: null),
      ]);

      final entry = (await read(MenuSurface.mediaLibrary)).single;

      // `label = null` ne veut pas dire « pas de libellé » : la clé du dépôt
      // traverse, et c'est la couche de présentation qui tranche.
      expect(entry.label, isEmpty);
      expect(entry.labelKey, 'public.nav.mediatheque');
      expect(
        entry.destination,
        const MenuCatalogue(family: MenuContentFamily.teaching),
      );
      // Les deux enseignements du magasin, aucune borne posée.
      expect(entry.itemCount, 2);
    });

    test('un lien externe paraît, et son contenu est son adresse', () async {
      await putMenu([
        menuEntryRow(1,
            label: {'fr': 'YouTube'},
            destinationKind: 'externe',
            destinationFamily: null,
            destinationUrl: 'https://youtube.com/@nouvellevie'),
      ]);

      final entry = (await read(MenuSurface.mediaLibrary)).single;

      expect(entry.destination,
          const MenuExternalLink('https://youtube.com/@nouvellevie'));
      // Le magasin est **vide de contenu**, et l'entrée paraît quand même :
      // « pas de contenu, pas de section » est une règle écrite pour les listes,
      // et la retourner contre le seul type qui n'en est pas une l'effacerait
      // toujours.
      expect(entry.itemCount, 1);
    });
  });

  group('Les slugs, et « pas de contenu, pas de section »', () {
    test('un slug connu et garni résout l\'identifiant de sa rubrique',
        () async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1, label: {'fr': 'Prières'}, destinationRubric: 'prieres'),
      ]);

      final entry = (await read(MenuSurface.mediaLibrary)).single;

      expect(
        entry.destination,
        const MenuCatalogue(
          family: MenuContentFamily.teaching,
          rubricId: 1,
          rubricSlug: 'prieres',
        ),
      );
      expect(entry.itemCount, 1);
    });

    test('un slug que le magasin ne connaît pas fait disparaître l\'entrée',
        () async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1, label: {'fr': 'Tout'}, mediaPosition: 1),
        menuEntryRow(2,
            label: {'fr': 'Jeunesse'},
            mediaPosition: 2,
            destinationRubric: 'jeunesse'),
      ]);

      // Ce n'est pas le catalogue entier qui s'affiche sous « Jeunesse » : c'est
      // l'entrée qui s'efface. Le repli permissif serait un onglet qui mentirait
      // sans que personne puisse le savoir.
      expect(
        (await read(MenuSurface.mediaLibrary)).map((e) => e.label),
        ['Tout'],
      );
    });

    test('une rubrique connue mais vide ne fait pas de section', () async {
      await putTypes([
        teachingTypeRow(1, label: {'fr': 'Prières'}, slug: 'prieres'),
        teachingTypeRow(2, label: {'fr': 'Jeunesse'}, slug: 'jeunesse'),
      ]);
      await putTeachings([teachingRow('t-1', teachingTypeId: 1)]);
      await putMenu([
        menuEntryRow(1,
            label: {'fr': 'Prières'},
            mediaPosition: 1,
            destinationRubric: 'prieres'),
        menuEntryRow(2,
            label: {'fr': 'Jeunesse'},
            mediaPosition: 2,
            destinationRubric: 'jeunesse'),
      ]);

      expect(
        (await read(MenuSurface.mediaLibrary)).map((e) => e.label),
        ['Prières'],
      );
    });

    test('un contenu qui arrive fait paraître l\'onglet qui l\'attendait',
        () async {
      await putTypes([
        teachingTypeRow(1, label: {'fr': 'Jeunesse'}, slug: 'jeunesse'),
      ]);
      await putMenu([
        menuEntryRow(1,
            label: {'fr': 'Jeunesse'}, destinationRubric: 'jeunesse'),
      ]);
      expect(await read(MenuSurface.mediaLibrary), isEmpty);

      await putTeachings([teachingRow('t-1', teachingTypeId: 1)]);

      // Le flux est réactif aux cinq tables : l'onglet paraît sans que personne
      // relance la lecture du menu.
      expect(await read(MenuSurface.mediaLibrary), hasLength(1));
    });

    test('une entrée qui exige une branche ne paraît pas', () async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1, label: {'fr': 'Tout'}, mediaPosition: 1),
        menuEntryRow(2,
            label: {'fr': 'Aného'},
            mediaPosition: 2,
            destinationBranch: 'aneho'),
      ]);

      // `BranchTransformer` ne sert **aucun slug** au flux delta : la copie locale
      // de `branches` n'en porte pas, et il n'y a rien à quoi comparer. Mieux vaut
      // une entrée absente qu'un onglet « Aného » montrant tout le catalogue.
      expect(
        (await read(MenuSurface.mediaLibrary)).map((e) => e.label),
        ['Tout'],
      );
    });

    test('la recherche figée de l\'entrée borne son contenu', () async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1,
            label: {'fr': 'Le pain'},
            mediaPosition: 1,
            destinationSearch: 'pain'),
        menuEntryRow(2,
            label: {'fr': 'Introuvable'},
            mediaPosition: 2,
            destinationSearch: 'zzz'),
      ]);

      final entries = await read(MenuSurface.mediaLibrary);

      // La première trouve son enseignement ; la seconde n'en trouve aucun et
      // s'efface — une recherche figée fait partie de la destination.
      expect(entries.map((e) => e.label), ['Le pain']);
      expect(entries.single.itemCount, 1);
    });
  });

  group('Les deux familles', () {
    test('un catalogue de rassemblement compte sur l\'autre collection',
        () async {
      await seedCatalogue();
      await putGatheringTypes([
        gatheringTypeRow(1, label: {'fr': 'Concerts'}, slug: 'concerts'),
      ]);
      await putGatherings([
        gatheringRow('g-1', title: 'Concert de louange', teachingTypeId: 1),
      ]);
      await putMenu([
        menuEntryRow(1,
            label: {'fr': 'Concerts'},
            destinationFamily: 'gathering',
            destinationRubric: 'concerts'),
      ]);

      final entry = (await read(MenuSurface.mediaLibrary)).single;

      expect(
        entry.destination,
        const MenuCatalogue(
          family: MenuContentFamily.gathering,
          rubricId: 1,
          rubricSlug: 'concerts',
        ),
      );
      // Le rassemblement, et **pas** les deux enseignements : c'est la famille de
      // la destination qui dit quelle collection lire.
      expect(entry.itemCount, 1);
    });

    test('un slug homonyme se résout dans le référentiel de sa famille',
        () async {
      // Les deux référentiels sont deux collections, et rien ne garantit que
      // leurs slugs soient disjoints. C'est le cas qu'on corrigerait de travers.
      await putTypes([
        teachingTypeRow(7, label: {'fr': 'Dimanche'}, slug: 'dimanche'),
      ]);
      await putGatheringTypes([
        gatheringTypeRow(9, label: {'fr': 'Dimanche'}, slug: 'dimanche'),
      ]);
      await putTeachings([teachingRow('t-1', teachingTypeId: 7)]);
      await putGatherings([gatheringRow('g-1', teachingTypeId: 9)]);
      await putMenu([
        menuEntryRow(1,
            label: {'fr': 'Messages'},
            mediaPosition: 1,
            destinationRubric: 'dimanche'),
        menuEntryRow(2,
            label: {'fr': 'Rassemblements'},
            mediaPosition: 2,
            destinationFamily: 'gathering',
            destinationRubric: 'dimanche'),
      ]);

      final entries = await read(MenuSurface.mediaLibrary);

      expect((entries[0].destination as MenuCatalogue).rubricId, 7);
      expect((entries[1].destination as MenuCatalogue).rubricId, 9);
    });

    test('une famille inconnue fait disparaître l\'entrée', () async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1,
            label: {'fr': 'Podcasts'}, destinationFamily: 'podcast'),
      ]);

      // Pas de repli sur l'autre famille : un concert rendu dans l'écran d'un
      // message serait pire qu'une entrée absente.
      expect(await read(MenuSurface.mediaLibrary), isEmpty);
    });
  });

  group('Les sous-entrées', () {
    test('une sous-entrée se range sous son parent, dans son ordre', () async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1, label: {'fr': 'Tout'}, mediaPosition: 1),
        menuEntryRow(3,
            label: {'fr': 'Dimanche'},
            parentId: 1,
            mediaPosition: 2,
            destinationRubric: 'dimanche'),
        menuEntryRow(2,
            label: {'fr': 'Prières'},
            parentId: 1,
            mediaPosition: 1,
            destinationRubric: 'prieres'),
      ]);

      final entries = await read(MenuSurface.mediaLibrary);

      // Un seul onglet, deux puces : l'arbre est à un niveau, et les enfants
      // n'apparaissent jamais à la racine.
      expect(entries, hasLength(1));
      expect(
          entries.single.children.map((c) => c.label), ['Prières', 'Dimanche']);
    });

    test('une sous-entrée orpheline est ignorée, et ne remonte pas', () async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1, label: {'fr': 'Tout'}, mediaPosition: 1),
        // Le parent n'est pas (encore) en magasin : les collections arrivent
        // séparément, et `parentId` est un entier nu sans contrainte.
        menuEntryRow(2,
            label: {'fr': 'Orpheline'},
            parentId: 404,
            mediaPosition: 2,
            destinationRubric: 'prieres'),
      ]);

      final entries = await read(MenuSurface.mediaLibrary);

      // Elle ne remonte **pas** à la racine : la faire remonter mettrait dans la
      // barre une entrée que personne n'y a mise.
      expect(entries.map((e) => e.label), ['Tout']);
      expect(entries.single.children, isEmpty);
    });

    test('un parent sans contenu survit si une puce en a', () async {
      await putTypes([
        teachingTypeRow(1, label: {'fr': 'Prières'}, slug: 'prieres'),
        teachingTypeRow(2, label: {'fr': 'Jeunesse'}, slug: 'jeunesse'),
      ]);
      await putTeachings([teachingRow('t-1', teachingTypeId: 1)]);
      await putMenu([
        // Le parent vise une rubrique vide…
        menuEntryRow(1,
            label: {'fr': 'Jeunesse'},
            mediaPosition: 1,
            destinationRubric: 'jeunesse'),
        // …mais sa puce a quelque chose à montrer.
        menuEntryRow(2,
            label: {'fr': 'Prières'},
            parentId: 1,
            mediaPosition: 1,
            destinationRubric: 'prieres'),
      ]);

      final entries = await read(MenuSurface.mediaLibrary);

      // L'onglet existe **pour ses puces** : le retirer cacherait un contenu que
      // le portail a rendu atteignable.
      expect(entries, hasLength(1));
      expect(entries.single.itemCount, 0);
      expect(entries.single.children.map((c) => c.label), ['Prières']);
    });

    test('un parent et une puce tous deux vides s\'effacent ensemble',
        () async {
      await putTypes([
        teachingTypeRow(2, label: {'fr': 'Jeunesse'}, slug: 'jeunesse'),
      ]);
      await putMenu([
        menuEntryRow(1,
            label: {'fr': 'Jeunesse'},
            mediaPosition: 1,
            destinationRubric: 'jeunesse'),
        menuEntryRow(2,
            label: {'fr': 'Ados'},
            parentId: 1,
            mediaPosition: 1,
            destinationRubric: 'jeunesse'),
      ]);

      expect(await read(MenuSurface.mediaLibrary), isEmpty);
    });
  });

  group('Ce que chaque surface porte', () {
    test('le gabarit n\'est servi qu\'à l\'accueil', () async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1,
            label: {'fr': 'Prières'},
            destinationRubric: 'prieres',
            homeVisible: true,
            homeLayout: 'hero'),
      ]);

      // À l'accueil, le gabarit décide du dessin.
      expect((await read(MenuSurface.home)).single.layout, 'hero');
      // Sur la barre d'onglets, il n'a aucun sens : le servir laisserait croire
      // qu'une barre d'onglets a des formes.
      expect((await read(MenuSurface.mediaLibrary)).single.layout, isNull);
    });

    test('le libellé se replie dans la langue demandée, et par `pick` seul',
        () async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1, label: {'fr': 'Prières', 'en': 'Prayers'}),
      ]);

      expect((await read(MenuSurface.mediaLibrary, locale: 'en')).single.label,
          'Prayers');
      // L'éwé n'est pas rempli : le repli `ee → fr` est celui de `pick`, et il
      // est le même des deux côtés du fil.
      expect((await read(MenuSurface.mediaLibrary, locale: 'ee')).single.label,
          'Prières');
    });

    test('le lot éditorial de la page voyage replié', () async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(
          1,
          label: {'fr': 'Prières'},
          pageTitle: {'fr': 'Moments de prière'},
          pageDescription: {'fr': 'Prier ensemble, chaque semaine.'},
        ),
      ]);

      final entry = (await read(MenuSurface.mediaLibrary)).single;
      expect(entry.pageTitle, 'Moments de prière');
      expect(entry.pageDescription, 'Prier ensemble, chaque semaine.');
    });

    test('un magasin sans menu rend une liste vide, pas une erreur', () async {
      await seedCatalogue();

      // L'état d'une application dont le premier cycle n'a rien ramené, et celui
      // d'un serveur en retard d'une version. Les deux surfaces en tirent leur
      // propre conséquence, et c'est écrit chez elles.
      expect(await read(MenuSurface.mediaLibrary), isEmpty);
      expect(await read(MenuSurface.home), isEmpty);
    });
  });
}
