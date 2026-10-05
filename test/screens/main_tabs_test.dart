import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/repositories/calendar_repository.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/models/vocabulary.dart';
import 'package:maison_du_miracle/screens/home_shell.dart';
import 'package:maison_du_miracle/screens/groups_screen.dart';
import 'package:maison_du_miracle/screens/home_screen.dart';
import 'package:maison_du_miracle/screens/media_library_screen.dart';
import 'package:maison_du_miracle/screens/profile_screen.dart';
import 'package:maison_du_miracle/state/calendar_providers.dart';
import 'package:maison_du_miracle/widgets/app_bottom_nav.dart';
import 'package:maison_du_miracle/widgets/home_tab.dart';

import '../helpers/pump_screen.dart';

void main() {
  group('Onglets principaux (smoke)', () {
    testWidgets('HomeScreen se monte avec les données', (tester) async {
      // Agenda forcé sur le double en mémoire : sans cet override, la section
      // « À venir » partirait sur `HttpCalendarRepository` et ouvrirait une
      // socket, à laquelle `flutter test` répond 400.
      await pumpScreen(
        tester,
        const Scaffold(body: HomeScreen()),
        overrides: [
          calendarRepositoryProvider
              .overrideWithValue(InMemoryCalendarRepository()),
        ],
      );
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.textContaining('Bonjour'), findsOneWidget);
    });

    testWidgets('MediaLibraryScreen se monte', (tester) async {
      await pumpScreen(tester, const Scaffold(body: MediaLibraryScreen()));
      expect(find.byType(MediaLibraryScreen), findsOneWidget);
      expect(find.text('Médiathèque'), findsOneWidget);
    });

    testWidgets('GroupsScreen (Échanges) se monte', (tester) async {
      // ⚠️ **Il se monte sur un magasin vide** (#96) : le hub ne lit plus
      // `SampleData` mais `EchangesRepository`, dont `pumpScreen` pose un double
      // vide par défaut. C'est l'état du premier lancement, et le monter ainsi est
      // ce qui prouve qu'un magasin qui n'a rien reçu ne fait pas rougir l'écran.
      await pumpScreen(tester, const Scaffold(body: GroupsScreen()));
      expect(find.byType(GroupsScreen), findsOneWidget);
      // Le hub porte le titre « Échanges » dans son bandeau ; les onglets
      // pilules (« Inbox »…) ont disparu.
      expect(find.text('Échanges'), findsWidgets);
      expect(find.text('Inbox'), findsNothing);
      // La pile d'avatars décorative est partie avec le fictif : « Estelle »,
      // « David » et « Sarah » n'existaient pas, et la pastille « 5+ » ne comptait
      // rien (décision 10 du cadrage).
      expect(find.text('5+'), findsNothing);
    });

    testWidgets('ProfileScreen se monte', (tester) async {
      await pumpScreen(tester, const Scaffold(body: ProfileScreen()));
      expect(find.byType(ProfileScreen), findsOneWidget);
      // Le réglage d'apparence a quitté la liste : il vit derrière l'icône de
      // l'en-tête, qui ouvre une feuille. On vérifie donc le bouton, pas un
      // libellé de liste qui n'existe plus.
      expect(find.byKey(ProfileScreen.themeButtonKey), findsOneWidget);
    });
  });

  group('La barre du bas', () {
    /// Un libellé **de la barre**, et de nulle part ailleurs : le tiroir porte
    /// aussi « Accueil », et le hub des conversations porte « Échanges » dans
    /// son bandeau — or l'`IndexedStack` construit ses quatre onglets, donc ce
    /// bandeau existe dans l'arbre même lorsqu'il n'est pas peint.
    Finder navTab(String label) => find.descendant(
          of: find.byType(AppBottomNav),
          matching: find.text(label),
        );

    Future<void> pumpShell(
      WidgetTester tester, {
      VocabularyOverrides? vocabulary,
    }) =>
        pumpScreen(
          tester,
          const HomeShell(),
          vocabulary: vocabulary,
          overrides: [
            calendarRepositoryProvider
                .overrideWithValue(InMemoryCalendarRepository()),
          ],
        );

    testWidgets('Accueil · Annonces · ⊕ · Échanges · Profil', (tester) async {
      await pumpShell(tester);

      final labels = [
        for (final tab in HomeTab.values)
          AppBottomNav.itemFor(
            tester.element(find.byType(AppBottomNav)),
            tab,
          ).label,
      ];
      final fr = AppLocalizationsFr();
      expect(labels, [
        fr.navHome,
        fr.navAnnouncements,
        fr.navGroups,
        fr.navProfile,
      ]);

      // Et c'est bien cet ordre-là qui est peint, de gauche à droite.
      final xs = [for (final l in labels) tester.getCenter(navTab(l)).dx];
      expect(xs, orderedEquals(<double>[...xs]..sort()));
    });

    group('Le nom de l\'onglet des annonces vient du portail (#132)', () {
      testWidgets('le mot réglé au portail recouvre « Annonces »',
          (tester) async {
        // Un mot de test quelconque : le libellé de façade réel se règle au
        // portail, il n'est écrit nulle part dans ce dépôt.
        await pumpShell(
          tester,
          vocabulary: const VocabularyOverrides(labels: {
            'navAnnouncements': {'fr': 'Étincelles', 'en': 'Embers'},
          }),
        );

        expect(navTab('Étincelles'), findsOneWidget);
        expect(navTab(AppLocalizationsFr().navAnnouncements), findsNothing);
        expect(
          AppBottomNav.itemFor(
            tester.element(find.byType(AppBottomNav)),
            HomeTab.announcements,
          ).label,
          'Étincelles',
        );
      });

      testWidgets('sans surcharge, l\'onglet garde le mot du dépôt',
          (tester) async {
        // Aucun cycle passé (aucun réseau) : c'est le `.arb` qui parle.
        await pumpShell(tester);
        expect(navTab(AppLocalizationsFr().navAnnouncements), findsOneWidget);
      });

      testWidgets('une surcharge vide ne vide pas l\'onglet', (tester) async {
        await pumpShell(
          tester,
          vocabulary: const VocabularyOverrides(labels: {
            'navAnnouncements': {'fr': '   '},
          }),
        );
        expect(navTab(AppLocalizationsFr().navAnnouncements), findsOneWidget);
      });
    });

    testWidgets('l\'encoche du bouton central tombe entre deux moitiés égales',
        (tester) async {
      await pumpShell(tester);

      final width = tester.getSize(find.byType(AppBottomNav)).width;
      final middle = width / 2;
      final fr = AppLocalizationsFr();
      final xs = [
        for (final l in [
          fr.navHome,
          fr.navAnnouncements,
          fr.navGroups,
          fr.navProfile,
        ])
          tester.getCenter(navTab(l)).dx,
      ];

      // Deux onglets de chaque côté du creux, et le creux au milieu. C'est ce
      // que `take(half)` / `skip(half)` promet, et ce qu'un nombre impair
      // d'onglets casserait — d'où les quatre onglets, dont aucun ne se masque.
      expect((xs[1] + xs[2]) / 2, closeTo(middle, 0.5));
      expect(middle - xs[0], closeTo(xs[3] - middle, 0.5));

      // Le FAB est docké au centre : l'encoche et lui se regardent.
      expect(tester.getCenter(find.byType(FloatingActionButton)).dx,
          closeTo(middle, 0.5));
    });
  });
}
