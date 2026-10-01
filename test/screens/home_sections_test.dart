import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/repositories/calendar_repository.dart';
import 'package:maison_du_miracle/data/repositories/gathering_repository.dart';
import 'package:maison_du_miracle/data/repositories/store_mediatheque_repository.dart';
import 'package:maison_du_miracle/data/repositories/store_menu_repository.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/screens/home_screen.dart';
import 'package:maison_du_miracle/state/calendar_providers.dart';
import 'package:maison_du_miracle/widgets/cards/content_cover.dart';
import 'package:maison_du_miracle/widgets/content_absence.dart';
import 'package:maison_du_miracle/widgets/home/home_section_layout.dart';
import 'package:maison_du_miracle/widgets/home/home_content_cards.dart';
import 'package:maison_du_miracle/widgets/home/home_menu_section.dart';
import 'package:maison_du_miracle/widgets/home/home_teaching_section.dart';
import 'package:maison_du_miracle/widgets/section_header.dart';

import '../data/local/local_database_fixtures.dart';
import '../helpers/pump_screen.dart';

/// **L'accueil composé depuis le référentiel des rubriques** (#32).
///
/// Tout se joue sur le **vrai magasin**, en mémoire : ce qui est vérifié ici
/// n'est pas qu'un écran sait afficher une liste, c'est que la chaîne entière —
/// lignes répliquées → `homeSections()` → modèle de lecture → écran — laisse le
/// serveur décider de l'accueil. Un double de repository aurait pu répondre
/// n'importe quoi et les deux règles les plus importantes (« pas
/// d'enseignement, pas de section » et la disparition d'une rubrique supprimée
/// côté serveur) ne se seraient jamais exercées.
///
/// L'agenda est neutralisé : la section « À venir » n'est pas le sujet, et son
/// repository par défaut peuplerait l'écran de cartes sans rapport.
class _EmptyCalendarRepository implements CalendarRepository {
  @override
  Future<EventWindow> events({
    required DateTime from,
    DateTime? to,
    int? branchId,
    int? limit,
  }) async =>
      EventWindow.empty;
}

/// `testWidgets`, **plus le démontage explicite de l'arbre dans le corps du
/// test**.
///
/// Fermer le dernier abonné d'un flux Drift planifie une minuterie à zéro
/// (`StreamQueryStore.markAsClosed`). `flutter_test` démonte bien l'arbre en
/// fin de test, mais avec un `pump()` sans durée : l'horloge factice n'avance
/// pas, la minuterie ne part jamais, et l'invariant « aucune minuterie en
/// attente » fait échouer un test par ailleurs vert.
void homeTest(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

void main() {
  late AppDatabase db;
  late SyncDao sync;

  setUp(() {
    db = openTestDatabase();
    sync = db.syncDao;
  });

  tearDown(() => db.close());

  /// Écrit des rubriques dans le magasin **telles que le serveur les envoie** :
  /// entières, masquées comprises. `visibleOnHome` ne se filtre jamais à
  /// l'écriture — c'est ce drapeau qui apprend au client qu'une rubrique a
  /// quitté l'accueil, et le filtrer ici ferait disparaître l'information au
  /// lieu de la propager.
  Future<void> putTypes(List<TeachingTypesCompanion> rows) =>
      sync.applyPage(sync.teachingTypesCollection,
          upserts: rows, cursor: 'types-1');

  Future<void> putTeachings(
    List<TeachingsCompanion> rows, {
    String cursor = 'teachings-1',
  }) =>
      sync.applyPage(sync.teachingsCollection, upserts: rows, cursor: cursor);

  /// Écrit un menu **tel que le serveur l'envoie** : entrées éteintes comprises.
  /// La visibilité par surface est une colonne, pas un périmètre de livraison.
  Future<void> putMenu(
    List<MenuEntriesCompanion> rows, {
    String cursor = 'menu-1',
  }) =>
      sync.applyPage(sync.menuEntriesCollection, upserts: rows, cursor: cursor);

  /// Monte l'accueil branché sur le magasin de ce test.
  ///
  /// Écran haut : les listes de l'app sont paresseuses, et une section jamais
  /// construite ne prouve rien — ni sa présence, ni son absence.
  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpScreen(
      tester,
      const Scaffold(body: HomeScreen()),
      database: db,
      mediatheque: StoreMediathequeRepository(db.mediathequeDao),
      // Le menu vient du **même** magasin : c'est lui qui décide désormais, et un
      // double en mémoire rendrait un menu vide, donc ne prouverait que le repli.
      menu: StoreMenuRepository(db.menuDao),
      // Les rassemblements sont **vides** ici : ce fichier vérifie les
      // rubriques d'enseignement, et le double par défaut y ajouterait ses
      // propres sections — donc des cartes qu'aucune assertion ne vise.
      gatherings:
          InMemoryGatheringRepository(gatherings: const [], types: const []),
      overrides: [
        calendarRepositoryProvider.overrideWithValue(_EmptyCalendarRepository())
      ],
    );
  }

  /// Position verticale du titre d'une section, pour comparer des ordres.
  double topOf(WidgetTester tester, String label) =>
      tester.getTopLeft(find.text(label.toUpperCase())).dy;

  /// Cadrage demandé par la carte de type [card] au visuel qu'elle dessine.
  CoverOrientation orientationIn(WidgetTester tester, Type card) => tester
      .widget<ContentCover>(
        find
            .descendant(
              of: find.byType(card),
              matching: find.byType(ContentCover),
            )
            .first,
      )
      .orientation;

  group('L\'ordre des sections appartient au serveur', () {
    homeTest('les rubriques sortent dans l\'ordre de `position`',
        (tester) async {
      await putTypes([
        teachingTypeRow(1,
            label: {'fr': 'Prière'}, slug: 'priere', position: 3),
        teachingTypeRow(2,
            label: {'fr': 'Dimanche'}, slug: 'dimanche', position: 1),
        teachingTypeRow(3, label: {'fr': 'Étude'}, slug: 'etude', position: 2),
      ]);
      await putTeachings([
        teachingRow('t-1', title: 'Prier sans cesse', teachingTypeId: 1),
        teachingRow('t-2', title: 'Le pain du jour', teachingTypeId: 2),
        teachingRow('t-3', title: 'Lire les Actes', teachingTypeId: 3),
      ]);

      await pumpHome(tester);

      // L'ordre du référentiel, pas celui des identifiants ni de l'alphabet.
      expect(topOf(tester, 'Dimanche'), lessThan(topOf(tester, 'Étude')));
      expect(topOf(tester, 'Étude'), lessThan(topOf(tester, 'Prière')));
    });

    homeTest('le libellé et la teinte de la rubrique habillent sa section',
        (tester) async {
      await putTypes([
        teachingTypeRow(7,
            label: {'fr': 'Louange', 'en': 'Praise'},
            slug: 'louange',
            color: '#B5341F'),
      ]);
      await putTeachings([teachingRow('t-1', teachingTypeId: 7)]);

      await pumpHome(tester);

      // Le titre est le libellé du serveur, replié par le modèle de lecture —
      // aucun libellé d'application n'est écrit en dur pour une rubrique.
      final header = tester.widget<SectionHeader>(
        find.ancestor(
          of: find.text('LOUANGE'),
          matching: find.byType(SectionHeader),
        ),
      );
      expect(header.title, 'Louange');
      expect(header.accent, const Color(0xFFB5341F));
    });
  });

  group('Les trois mises en page', () {
    homeTest('`hero` rend de grandes cartes paysage', (tester) async {
      await putTypes([
        teachingTypeRow(1,
            label: {'fr': 'À la une'}, slug: 'une', layout: 'hero'),
      ]);
      await putTeachings([teachingRow('t-1', teachingTypeId: 1)]);

      await pumpHome(tester);

      expect(find.byType(HomeHeroCard), findsOneWidget);
      expect(
        tester.getSize(find.byType(HomeHeroCard).first),
        kHeroCoverSize,
      );
      // Le **cadrage paysage**, et pas seulement une boîte large : c'est parce
      // que les deux ratios sont opposés que le serveur sert deux URL d'image
      // par enseignement. Demander le portrait ici perdrait le sujet dans un
      // `BoxFit.cover` de 320 × 188.
      expect(orientationIn(tester, HomeHeroCard), CoverOrientation.landscape);
    });

    homeTest('`carousel` rend des vignettes portrait', (tester) async {
      await putTypes([
        teachingTypeRow(1,
            label: {'fr': 'Dimanche'}, slug: 'dim', layout: 'carousel'),
      ]);
      await putTeachings([teachingRow('t-1', teachingTypeId: 1)]);

      await pumpHome(tester);

      // Deux cartes : la rubrique **et** « Derniers enseignements », qui est
      // un tri et emprunte la même étagère.
      final cards = find.descendant(
        of: find.byType(HomeTeachingSection),
        matching: find.byType(HomeCarouselCard),
      );
      expect(cards, findsOneWidget);
      expect(
        tester.getSize(cards.first).height,
        kCarouselCoverSize.height,
      );
      // Le cadrage **portrait**, l'exact opposé de `hero` : c'est la seconde
      // des deux URL d'image que le serveur sert.
      expect(
        orientationIn(tester, HomeCarouselCard),
        CoverOrientation.portrait,
      );
      expect(find.byType(HomeHeroCard), findsNothing);
    });

    homeTest('`list` rend des lignes verticales', (tester) async {
      await putTypes([
        teachingTypeRow(1,
            label: {'fr': 'Enseignements'}, slug: 'ens', layout: 'list'),
      ]);
      await putTeachings([
        teachingRow('t-1', title: 'Première', teachingTypeId: 1),
        teachingRow('t-2', title: 'Deuxième', teachingTypeId: 1),
      ]);

      await pumpHome(tester);

      expect(find.byType(HomeListRow), findsNWidgets(2));
      // Verticales : la seconde ligne est **sous** la première, pas à côté.
      final first = tester.getTopLeft(find.byType(HomeListRow).at(0));
      final second = tester.getTopLeft(find.byType(HomeListRow).at(1));
      expect(second.dy, greaterThan(first.dy));
      expect(second.dx, first.dx);
      // La liste n'introduit pas un troisième recadrage : elle réutilise le
      // portrait, en plus petit. Il n'y a que deux images.
      expect(orientationIn(tester, HomeListRow), CoverOrientation.portrait);
    });

    homeTest('une mise en page inconnue se replie au lieu de disparaître',
        (tester) async {
      // Le portail a servi une forme que ce binaire ne connaît pas : c'est un
      // référentiel plus récent que l'app, pas une erreur. La rubrique reste.
      await putTypes([
        teachingTypeRow(1,
            label: {'fr': 'Mosaïque'}, slug: 'mosaique', layout: 'mosaic'),
      ]);
      await putTeachings([teachingRow('t-1', teachingTypeId: 1)]);

      await pumpHome(tester);

      expect(find.text('MOSAÏQUE'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(HomeTeachingSection),
          matching: find.byType(HomeCarouselCard),
        ),
        findsOneWidget,
      );
    });

    homeTest('une section `list` est plafonnée', (tester) async {
      await putTypes([
        teachingTypeRow(1,
            label: {'fr': 'Archives'}, slug: 'archives', layout: 'list'),
      ]);
      await putTeachings([
        for (var i = 0; i < kHomeSectionListLimit + 3; i++)
          teachingRow('t-$i', title: 'Message $i', teachingTypeId: 1),
      ]);

      await pumpHome(tester);

      expect(find.byType(HomeListRow), findsNWidgets(kHomeSectionListLimit));
    });
  });

  group('Ce qui n\'est pas à l\'accueil', () {
    homeTest('une rubrique masquée n\'y paraît pas, même remplie',
        (tester) async {
      await putTypes([
        teachingTypeRow(1,
            label: {'fr': 'Visible'}, slug: 'visible', position: 1),
        teachingTypeRow(2,
            label: {'fr': 'Masquée'},
            slug: 'masquee',
            position: 2,
            visibleOnHome: false),
      ]);
      await putTeachings([
        teachingRow('t-1', title: 'Au grand jour', teachingTypeId: 1),
        teachingRow('t-2', title: 'En coulisses', teachingTypeId: 2),
      ]);

      await pumpHome(tester);

      expect(find.text('VISIBLE'), findsOneWidget);
      expect(find.text('MASQUÉE'), findsNothing);
      // La rubrique masquée n'a pas quitté le magasin pour autant : ses
      // enseignements restent lisibles, et « Derniers enseignements » les
      // montre. Filtrer à l'écriture les aurait perdus avec elle.
      expect(find.text('En coulisses'), findsOneWidget);
    });

    homeTest('une rubrique sans enseignement local ne se rend pas',
        (tester) async {
      await putTypes([
        teachingTypeRow(1, label: {'fr': 'Remplie'}, slug: 'remplie'),
        // Rubrique fraîchement créée côté serveur, pas encore garnie.
        teachingTypeRow(2, label: {'fr': 'Toute neuve'}, slug: 'neuve'),
      ]);
      await putTeachings([teachingRow('t-1', teachingTypeId: 1)]);

      await pumpHome(tester);

      expect(find.text('REMPLIE'), findsOneWidget);
      expect(find.text('TOUTE NEUVE'), findsNothing);
    });

    homeTest(
        'une rubrique supprimée côté serveur disparaît d\'elle-même une fois '
        'ses enseignements reclassés', (tester) async {
      await putTypes([
        teachingTypeRow(1, label: {'fr': 'Reprise'}, slug: 'reprise'),
        teachingTypeRow(2, label: {'fr': 'Abandonnée'}, slug: 'abandonnee'),
      ]);
      await putTeachings([
        teachingRow('t-1', title: 'Le dernier mot', teachingTypeId: 2),
      ]);

      await pumpHome(tester);
      expect(find.text('ABANDONNÉE'), findsOneWidget);

      // Le serveur refuse de supprimer une rubrique encore référencée : le
      // reclassement voyage donc **avant** la suppression. Celle-ci, elle, ne
      // voyage jamais — `teaching_types` se supprime durement et sans
      // tombstone, la ligne cesse simplement de paraître dans le flux et le
      // téléphone qui l'avait téléchargée la garde pour toujours.
      await putTeachings(
        [teachingRow('t-1', title: 'Le dernier mot', teachingTypeId: 1)],
        cursor: 'teachings-2',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Aucun message de retrait n'est arrivé, et pourtant la section a
      // disparu : c'est « pas d'enseignement, pas de section » qui l'a retirée.
      // Sans elle, l'accueil garderait une section fantôme définitivement vide.
      expect(find.text('ABANDONNÉE'), findsNothing);
      expect(find.text('REPRISE'), findsOneWidget);
      expect(find.text('Le dernier mot'), findsWidgets);
    });
  });

  group('L\'accueil migré aux menus (#82) — la coexistence bornée', () {
    /// Deux rubriques garnies, dont **une seule** visible à l'accueil : c'est
    /// l'état d'un parc avant cette tranche, et le point de départ des deux
    /// régimes.
    Future<void> seedRubrics() async {
      await putTypes([
        teachingTypeRow(1,
            label: {'fr': 'Intercession'}, slug: 'prieres', position: 1),
        teachingTypeRow(2,
            label: {'fr': 'Culte'},
            slug: 'dimanche',
            position: 2,
            visibleOnHome: false),
      ]);
      await putTeachings([
        teachingRow('t-1', title: 'Prier sans cesse', teachingTypeId: 1),
        teachingRow('t-2', title: 'Le pain du jour', teachingTypeId: 2),
      ]);
    }

    homeTest('sans entrée allumée à l\'accueil, les rubriques font foi',
        (tester) async {
      await seedRubrics();
      // Le menu existe, mais **aucune** de ses entrées n'est visible à l'accueil :
      // c'est exactement l'état livré par la graine du portail
      // (`home_visible: false` sur les sept entrées reprises), et `mobile_home`
      // n'est pas une surface gardée. Un appareil qui monte de version avant que
      // le portail n'ait rien réglé ne doit pas perdre son accueil.
      await putMenu([
        menuEntryRow(1,
            label: {'fr': 'Messages'}, destinationRubric: 'dimanche'),
      ]);

      await pumpHome(tester);

      expect(find.byType(HomeTeachingSection), findsOneWidget);
      expect(find.text('INTERCESSION'), findsOneWidget);
      expect(find.byType(HomeMenuSection), findsNothing);
    });

    homeTest('une entrée allumée fait taire les rubriques', (tester) async {
      await seedRubrics();
      await putMenu([
        menuEntryRow(1,
            label: {'fr': 'Messages du dimanche'},
            destinationRubric: 'dimanche',
            homeVisible: true,
            homePosition: 1),
      ]);

      await pumpHome(tester);

      // Le menu fait foi, et **les rubriques se taisent**. Les rendre toutes les
      // deux montrerait la même rubrique deux fois, sous deux titres réglés à
      // deux endroits — la divergence que la décision 12 du cadrage interdit.
      expect(find.byType(HomeMenuSection), findsOneWidget);
      expect(find.text('MESSAGES DU DIMANCHE'), findsOneWidget);
      expect(find.byType(HomeTeachingSection), findsNothing);
      expect(find.text('INTERCESSION'), findsNothing);
      // Et la section du menu montre bien **sa** rubrique, celle que l'ancien
      // mécanisme avait pourtant masquée de l'accueil : c'est le portail qui
      // décide désormais, et il décide ailleurs.
      expect(find.text('Le pain du jour'), findsWidgets);
    });

    homeTest('le gabarit de l\'entrée décide du dessin', (tester) async {
      await seedRubrics();
      await putMenu([
        menuEntryRow(1,
            label: {'fr': 'À la une'},
            destinationRubric: 'prieres',
            homeVisible: true,
            homeLayout: 'hero'),
      ]);

      await pumpHome(tester);

      expect(find.byType(HomeHeroCard), findsOneWidget);
      expect(
        tester.getSize(find.byType(HomeHeroCard).first),
        kHeroCoverSize,
      );
    });

    homeTest('un gabarit inconnu se replie, l\'entrée reste', (tester) async {
      await seedRubrics();
      await putMenu([
        menuEntryRow(1,
            label: {'fr': 'Mosaïque'},
            destinationRubric: 'prieres',
            homeVisible: true,
            homeLayout: 'mosaic'),
      ]);

      await pumpHome(tester);

      // Le portail est plus récent que ce binaire : la section **reste**, sous le
      // repli. C'est la doctrine de `HomeSectionLayout.of`, et elle ne change pas
      // parce que la source a changé.
      expect(find.text('MOSAÏQUE'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(HomeMenuSection),
          matching: find.byType(HomeCarouselCard),
        ),
        findsOneWidget,
      );
    });

    homeTest('une entrée dont la destination ne ramène rien ne paraît pas',
        (tester) async {
      await seedRubrics();
      await putTypes([
        teachingTypeRow(1,
            label: {'fr': 'Intercession'}, slug: 'prieres', position: 1),
        teachingTypeRow(3, label: {'fr': 'Jeunesse'}, slug: 'jeunesse'),
      ]);
      await putMenu([
        menuEntryRow(1,
            label: {'fr': 'Garnie'},
            homePosition: 1,
            destinationRubric: 'prieres',
            homeVisible: true),
        menuEntryRow(2,
            label: {'fr': 'Vide'},
            homePosition: 2,
            destinationRubric: 'jeunesse',
            homeVisible: true),
      ]);

      await pumpHome(tester);

      // « Pas de contenu, pas de section » : c'est la seule chose qui retire une
      // entrée supprimée au portail, la collection n'ayant pas de tombstone.
      expect(find.text('GARNIE'), findsOneWidget);
      expect(find.text('VIDE'), findsNothing);
    });

    homeTest('« Dernières publications » survit aux deux régimes',
        (tester) async {
      await seedRubrics();
      await putMenu([
        menuEntryRow(1,
            label: {'fr': 'Messages'},
            destinationRubric: 'dimanche',
            homeVisible: true),
      ]);

      await pumpHome(tester);

      // Ce n'est pas une rubrique mais un **tri** : il n'a jamais dépendu de
      // `visible_on_home`, aucune entrée de menu ne le décrit, et il reste donc
      // des deux côtés de la bascule. C'est aussi le seul endroit qui continue
      // d'écarter les cultes entiers.
      expect(find.text('DERNIÈRES PUBLICATIONS'), findsOneWidget);
    });
  });

  group('Magasin vide', () {
    homeTest('le premier lancement se dit « pas encore synchronisé »',
        (tester) async {
      await pumpHome(tester);

      // Ni un chargement, ni une erreur, ni une liste vide : le magasin a
      // répondu, et il n'a **rien encore reçu**.
      final absence =
          tester.widget<ContentAbsenceView>(find.byType(ContentAbsenceView));
      expect(absence.absence, ContentAbsence.notSynced);
      expect(find.byType(HomeTeachingSection), findsNothing);
      // À la racine de la navigation, il n'y a rien à dépiler : le bouton de
      // retour d'une absence n'aurait rien à faire, et un bouton inerte se lit
      // comme une panne.
      expect(find.byKey(ContentAbsenceView.backKey), findsNothing);
    });

    homeTest('une rubrique garnie chasse l\'absence', (tester) async {
      await putTypes([
        teachingTypeRow(1, label: {'fr': 'Dimanche'}, slug: 'dimanche'),
      ]);
      await putTeachings([teachingRow('t-1', teachingTypeId: 1)]);

      await pumpHome(tester);

      expect(find.byType(ContentAbsenceView), findsNothing);
      expect(find.byType(HomeTeachingSection), findsOneWidget);
    });
  });

  group('Le « Voir tout » d\'une rubrique (#82)', () {
    /// Un routeur minimal : l'accueil, et une médiathèque **factice** qui ne fait
    /// qu'afficher le paramètre reçu. On vérifie ici ce qu'`un slug qui voyage`
    /// veut dire ; que la médiathèque en fasse un filtre est prouvé dans
    /// `media_library_screen_test.dart`.
    GoRouter seeAllRouter() => GoRouter(
          initialLocation: '/home',
          routes: [
            GoRoute(
              name: AppRoute.home,
              path: '/home',
              builder: (_, __) => const Scaffold(body: HomeScreen()),
            ),
            GoRoute(
              name: AppRoute.media,
              path: '/media',
              builder: (_, state) => Scaffold(
                body: Center(
                  child: Text(
                    'RUBRIQUE=${state.uri.queryParameters['rubrique']}',
                  ),
                ),
              ),
            ),
          ],
        );

    testWidgets('il emporte le slug de la rubrique, pas rien', (tester) async {
      tester.view.physicalSize = const Size(900, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await putTypes([
        teachingTypeRow(1, label: {'fr': 'Intercession'}, slug: 'prieres'),
      ]);
      await putTeachings([teachingRow('t-1', teachingTypeId: 1)]);

      final router = seeAllRouter();
      addTearDown(router.dispose);
      await pumpRouter(
        tester,
        router,
        database: db,
        mediatheque: StoreMediathequeRepository(db.mediathequeDao),
        gatherings:
            InMemoryGatheringRepository(gatherings: const [], types: const []),
        overrides: [
          calendarRepositoryProvider
              .overrideWithValue(_EmptyCalendarRepository()),
        ],
      );

      await tester.tap(find.text('Voir tout').last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // **Le bug réparé.** Le « Voir tout » poussait `/media` nu, donc la
      // médiathèque **non filtrée** : appuyer sur « Voir tout » de « Prières »
      // affichait tout le catalogue. Le slug part désormais avec, et c'est le
      // slug — non l'identifiant — parce qu'il survit au renommage du libellé et
      // qu'un lien partagé saurait le transporter.
      expect(find.text('RUBRIQUE=prieres'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  });
}
