/// **La médiathèque, et ses onglets qui filtrent** (#82).
///
/// **Couture neuve** : cet écran n'avait aucun test à lui. Il n'apparaissait
/// qu'en montage à blanc (`main_tabs_test.dart`) et comme support de tests
/// d'autre chose (`sync_triggers_test.dart`, `guest_guard_test.dart`,
/// `cold_start_test.dart`) — **aucune assertion sur un filtre, une rubrique, un
/// tri ou un contenu affiché**. C'est précisément l'écran que cette tranche
/// refait.
///
/// Tout se joue sur le **vrai magasin**, en mémoire : ce qui est vérifié n'est
/// pas qu'un écran sait afficher une liste, c'est que la chaîne entière — lignes
/// répliquées → menu résolu → liste filtrée → écran — laisse le portail décider
/// de la barre d'onglets. Un double de repository aurait pu répondre n'importe
/// quoi, et les deux règles qui comptent — « un onglet filtre vraiment » et « une
/// destination inconnue disparaît sans repli » — ne se seraient jamais exercées.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/external_link_launcher.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/repositories/store_gathering_repository.dart';
import 'package:maison_du_miracle/data/repositories/store_mediatheque_repository.dart';
import 'package:maison_du_miracle/data/repositories/store_menu_repository.dart';
import 'package:maison_du_miracle/screens/media_library_screen.dart';
import 'package:maison_du_miracle/state/menu_providers.dart';
import 'package:maison_du_miracle/widgets/app_empty_state.dart';

import '../data/local/local_database_fixtures.dart';
import '../helpers/pump_screen.dart';

/// `testWidgets`, **plus le démontage explicite de l'arbre dans le corps du
/// test** — le patron de `home_sections_test.dart`, et pour la même raison :
/// fermer le dernier abonné d'un flux Drift planifie une minuterie à zéro, que
/// le démontage de fin de test (un `pump()` sans durée) ne laisse jamais partir.
void mediaTest(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      // `finally`, et c'est ce qui distingue ce patron de celui de
      // `home_sections_test.dart` : sans lui, un test qui **échoue** laisse la
      // minuterie derrière lui et le harnais attend dix minutes avant de rendre
      // la main. Un échec doit coûter trois secondes, pas dix minutes — sinon on
      // n'ose plus lancer la suite.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    }
  });
}

void main() {
  late AppDatabase db;
  late SyncDao sync;
  late RecordingExternalLinkLauncher launcher;

  setUp(() {
    db = openTestDatabase();
    sync = db.syncDao;
    launcher = RecordingExternalLinkLauncher();
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

  /// Deux rubriques, un contenu dans chacune, et un titre reconnaissable par
  /// rubrique : c'est ce qui permet de dire « deux onglets ne montrent pas la
  /// même liste » autrement que par un compte.
  Future<void> seedCatalogue() async {
    await putTypes([
      // ⚠️ Le libellé de la **rubrique** ne doit pas être celui de l'entrée de
      // menu : il s'affiche aussi sur chaque ligne du catalogue (`typeLabel`), et
      // un finder sur le texte en trouverait deux. Ce n'est pas un artifice de
      // test — une entrée porte un libellé **libre**, réglé au portail, qui n'a
      // aucune raison de répéter le nom de la rubrique qu'elle vise.
      teachingTypeRow(1, label: {'fr': 'Intercession'}, slug: 'prieres'),
      teachingTypeRow(2, label: {'fr': 'Culte'}, slug: 'dimanche'),
    ]);
    await putTeachings([
      teachingRow('t-1', title: 'Prier sans cesse', teachingTypeId: 1),
      teachingRow('t-2', title: 'Le pain du jour', teachingTypeId: 2),
    ]);
  }

  Future<void> pumpMedia(WidgetTester tester, {String? rubric}) async {
    // Écran haut : les listes de l'app sont paresseuses, et une ligne jamais
    // construite ne prouve rien — ni sa présence, ni son absence.
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpScreen(
      tester,
      MediaLibraryScreen(initialRubric: rubric),
      // Le **même** magasin que celui où le test écrit : `pumpScreen` en pose un
      // sinon, et deux `AppDatabase` sur deux connexions distinctes laisseraient
      // l'écran lire une base vide — Drift avertit d'ailleurs du doublon.
      database: db,
      mediatheque: StoreMediathequeRepository(db.mediathequeDao),
      gatherings: StoreGatheringRepository(db.gatheringDao),
      menu: StoreMenuRepository(db.menuDao),
      overrides: [
        externalLinkLauncherProvider.overrideWithValue(launcher),
      ],
    );
  }

  group('Les onglets filtrent pour de vrai', () {
    mediaTest('deux onglets différents ne montrent pas la même liste',
        (tester) async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1,
            label: {'fr': 'Prières'},
            mediaPosition: 1,
            destinationRubric: 'prieres'),
        menuEntryRow(2,
            label: {'fr': 'Dimanche'},
            mediaPosition: 2,
            destinationRubric: 'dimanche'),
      ]);

      await pumpMedia(tester);

      // Le premier onglet est actif : sa rubrique, et **rien d'autre**.
      expect(find.text('Prier sans cesse'), findsOneWidget);
      expect(find.text('Le pain du jour'), findsNothing);

      await tester.tap(find.text('Dimanche'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Changer d'onglet change la liste. Avant cette tranche, `_tab` ne servait
      // qu'à déplacer un soulignement, et les deux onglets montraient
      // exactement la même chose.
      expect(find.text('Le pain du jour'), findsOneWidget);
      expect(find.text('Prier sans cesse'), findsNothing);
    });

    mediaTest('l\'ordre des onglets est celui du portail', (tester) async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1,
            label: {'fr': 'Prières'},
            mediaPosition: 2,
            destinationRubric: 'prieres'),
        menuEntryRow(2,
            label: {'fr': 'Dimanche'},
            mediaPosition: 1,
            destinationRubric: 'dimanche'),
      ]);

      await pumpMedia(tester);

      // L'ordre du rang, pas celui des identifiants — et on compare **deux
      // positions**, jamais une valeur de rang.
      expect(
        tester.getTopLeft(find.text('Dimanche')).dx,
        lessThan(tester.getTopLeft(find.text('Prières')).dx),
      );
      // Et c'est le premier du rang qui est actif à l'ouverture.
      expect(find.text('Le pain du jour'), findsOneWidget);
    });

    mediaTest('il ne reste **qu\'une** liste du catalogue', (tester) async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1, label: {'fr': 'Tout'}, destinationFamily: 'teaching'),
      ]);

      await pumpMedia(tester);

      // **Le mensonge retiré.** Les trois sections — carrousel phare,
      // « Dernières publications », « Recommandés pour vous » — affichaient le
      // même tableau, entier, trois fois, dans le même ordre : chaque titre
      // apparaissait donc **trois fois** à l'écran. Il n'y a plus qu'une liste,
      // donc qu'une occurrence.
      expect(find.text('Prier sans cesse'), findsOneWidget);
      expect(find.text('Le pain du jour'), findsOneWidget);
    });

    mediaTest('une sous-entrée resserre la liste de son onglet',
        (tester) async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1, label: {'fr': 'Tout'}, mediaPosition: 1),
        menuEntryRow(2,
            label: {'fr': 'Prières'},
            parentId: 1,
            mediaPosition: 1,
            destinationRubric: 'prieres'),
      ]);

      await pumpMedia(tester);

      // L'onglet montre d'abord **sa** destination — le catalogue entier.
      expect(find.text('Prier sans cesse'), findsOneWidget);
      expect(find.text('Le pain du jour'), findsOneWidget);

      await tester.tap(find.text('Prières'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // La puce resserre, elle ne remplace pas l'onglet.
      expect(find.text('Prier sans cesse'), findsOneWidget);
      expect(find.text('Le pain du jour'), findsNothing);
    });
  });

  group('Une destination que ce binaire ne sait pas rendre', () {
    mediaTest('disparaît en silence, et ne replie sur rien', (tester) async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1,
            label: {'fr': 'Prières'},
            mediaPosition: 1,
            destinationRubric: 'prieres'),
        // Un portail plus récent que ce binaire.
        menuEntryRow(2,
            label: {'fr': 'Faire un don'},
            mediaPosition: 2,
            destinationKind: 'paiement',
            destinationFamily: null),
      ]);

      await pumpMedia(tester);

      // L'onglet n'existe pas…
      expect(find.text('Faire un don'), findsNothing);
      // …et il ne s'est **pas** replié sur la liste des prêches : celle qui
      // s'affiche est celle de l'onglet qui reste, « Prières ».
      expect(find.text('Prières'), findsOneWidget);
      expect(find.text('Prier sans cesse'), findsOneWidget);
      expect(find.text('Le pain du jour'), findsNothing);
    });

    mediaTest('une entrée sans libellé affichable ne paraît pas',
        (tester) async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1,
            label: null,
            labelKey: 'public.nav.mediatheque',
            mediaPosition: 1,
            destinationKind: 'page',
            destinationPage: 'mediatheque',
            destinationFamily: null),
        // Une clé du portail que ce binaire ne sait pas traduire : il n'y a aucun
        // libellé à afficher, et « public.nav.dons » ressemblerait à une fuite de
        // code plutôt qu'à un réglage.
        menuEntryRow(2,
            label: null,
            labelKey: 'public.nav.dons',
            mediaPosition: 2,
            destinationRubric: 'prieres'),
      ]);

      await pumpMedia(tester);

      // Le libellé du dépôt de l'entrée indélébile : « Tout ».
      expect(find.text('Tout'), findsOneWidget);
      expect(find.text('public.nav.dons'), findsNothing);
      expect(find.text('Prières'), findsNothing);
    });
  });

  group('Le lien externe', () {
    mediaTest('ouvre le navigateur et ne devient pas l\'onglet actif',
        (tester) async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1,
            label: {'fr': 'Prières'},
            mediaPosition: 1,
            destinationRubric: 'prieres'),
        menuEntryRow(2,
            label: {'fr': 'YouTube'},
            mediaPosition: 2,
            destinationKind: 'externe',
            destinationFamily: null,
            destinationUrl: 'https://youtube.com/@nouvellevie'),
      ]);

      await pumpMedia(tester);

      await tester.tap(find.text('YouTube'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(launcher.opened, ['https://youtube.com/@nouvellevie']);
      // La liste n'a pas bougé : il n'y a pas de liste dont un lien externe
      // serait le filtre, et la souligner laisserait un écran qui ne change pas.
      expect(find.text('Prier sans cesse'), findsOneWidget);
    });
  });

  group('La loupe', () {
    mediaTest('elle filtre la liste de l\'onglet actif', (tester) async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1,
            label: {'fr': 'Tout'},
            destinationFamily: 'teaching',
            filterSearch: true),
      ]);

      await pumpMedia(tester);
      expect(find.text('Prier sans cesse'), findsOneWidget);
      expect(find.text('Le pain du jour'), findsOneWidget);

      await tester.tap(find.byKey(MediaLibraryScreen.searchButtonKey));
      await tester.pump();
      await tester.enterText(
        find.byKey(MediaLibraryScreen.searchFieldKey),
        'pain',
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // La loupe était un `onPressed: () {}`, et `mediaSearchHint` vivait dans
      // l'ARB sans appelant.
      expect(find.text('Le pain du jour'), findsOneWidget);
      expect(find.text('Prier sans cesse'), findsNothing);
    });

    mediaTest('refermer la loupe rend la liste entière', (tester) async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1,
            label: {'fr': 'Tout'},
            destinationFamily: 'teaching',
            filterSearch: true),
      ]);

      await pumpMedia(tester);
      await tester.tap(find.byKey(MediaLibraryScreen.searchButtonKey));
      await tester.pump();
      await tester.enterText(
        find.byKey(MediaLibraryScreen.searchFieldKey),
        'pain',
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Prier sans cesse'), findsNothing);

      await tester.tap(find.byKey(MediaLibraryScreen.searchButtonKey));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Laisser un filtre actif derrière un champ qu'on ne voit plus est le genre
      // de liste tronquée qu'on prend pour un catalogue vide.
      expect(find.text('Prier sans cesse'), findsOneWidget);
      expect(find.text('Le pain du jour'), findsOneWidget);
    });

    mediaTest('elle n\'existe pas quand l\'entrée ne l\'offre pas',
        (tester) async {
      await seedCatalogue();
      await putMenu([
        // `filter_search` décoché au portail : la case était servie depuis la
        // tranche précédente et n'avait aucun lecteur. Elle en a un désormais.
        menuEntryRow(1,
            label: {'fr': 'Tout'},
            destinationFamily: 'teaching',
            filterSearch: false),
      ]);

      await pumpMedia(tester);

      // **Absence, pas grisage** : une icône inerte reste une promesse que
      // personne ne tient — c'est exactement ce qu'était `onPressed: () {}`.
      expect(find.byKey(MediaLibraryScreen.searchButtonKey), findsNothing);
    });

    mediaTest('une recherche sans résultat est un vide, pas une panne',
        (tester) async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1,
            label: {'fr': 'Tout'},
            destinationFamily: 'teaching',
            filterSearch: true),
      ]);

      await pumpMedia(tester);
      await tester.tap(find.byKey(MediaLibraryScreen.searchButtonKey));
      await tester.pump();
      await tester.enterText(
        find.byKey(MediaLibraryScreen.searchFieldKey),
        'zzzz',
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Neutre et sans bouton : il n'y a rien à réessayer.
      expect(find.byType(AppEmptyState), findsOneWidget);
    });
  });

  group('Le « Voir tout » d\'une rubrique d\'accueil', () {
    mediaTest('arrive sur la liste de cette rubrique, et pas sur le catalogue',
        (tester) async {
      await seedCatalogue();
      // Aucune entrée de menu ne désigne « Prières » : le « Voir tout » doit
      // filtrer **quand même**. C'est le bug que la tranche répare —
      // `teachingsOfTypeProvider` existait et n'était branché nulle part.
      await putMenu([
        menuEntryRow(1, label: {'fr': 'Tout'}, destinationFamily: 'teaching'),
      ]);

      await pumpMedia(tester, rubric: 'prieres');

      expect(find.text('Prier sans cesse'), findsOneWidget);
      expect(find.text('Le pain du jour'), findsNothing);
    });

    mediaTest('un slug inconnu ne ramène rien, jamais tout le catalogue',
        (tester) async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1, label: {'fr': 'Tout'}, destinationFamily: 'teaching'),
      ]);

      await pumpMedia(tester, rubric: 'jeunesse');

      // La doctrine du site public devant un `?rubrique=` inconnu : rien, jamais
      // « tout le catalogue ».
      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.text('Prier sans cesse'), findsNothing);
      expect(find.text('Le pain du jour'), findsNothing);
    });

    mediaTest('il allume l\'onglet qui désigne cette rubrique, s\'il existe',
        (tester) async {
      await seedCatalogue();
      await putMenu([
        menuEntryRow(1,
            label: {'fr': 'Dimanche'},
            mediaPosition: 1,
            destinationRubric: 'dimanche'),
        menuEntryRow(2,
            label: {'fr': 'Prières'},
            mediaPosition: 2,
            destinationRubric: 'prieres'),
      ]);

      await pumpMedia(tester, rubric: 'prieres');

      // L'onglet demandé l'emporte sur le premier du rang : on arrive **là** où
      // le geste pointait.
      expect(find.text('Prier sans cesse'), findsOneWidget);
      expect(find.text('Le pain du jour'), findsNothing);
    });
  });

  group('Sans menu', () {
    mediaTest('pas de barre d\'onglets, et le catalogue entier',
        (tester) async {
      await seedCatalogue();

      await pumpMedia(tester);

      // L'état d'une application dont le premier cycle n'a rien ramené, et celui
      // d'un serveur en retard d'une version. L'écran montre tout — c'est ce que
      // l'ancienne barre prétendait faire avec son onglet « Tout », et la seule
      // réponse qui ne cache aucun contenu.
      expect(find.text('Prier sans cesse'), findsOneWidget);
      expect(find.text('Le pain du jour'), findsOneWidget);
      // Une barre vide se lirait comme une panne.
      expect(find.text('Tout'), findsNothing);
      // Et sans entrée active, aucune entrée n'offre la recherche : pas de loupe.
      expect(find.byKey(MediaLibraryScreen.searchButtonKey), findsNothing);
    });

    mediaTest('un magasin vide se dit vide, et reste tirable', (tester) async {
      await pumpMedia(tester);

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  });
}
