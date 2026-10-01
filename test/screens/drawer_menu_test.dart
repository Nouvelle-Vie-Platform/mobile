import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:maison_du_miracle/data/repositories/calendar_repository.dart';
import 'package:maison_du_miracle/l10n/app_localizations_fr.dart';
import 'package:maison_du_miracle/screens/announcements_screen.dart';
import 'package:maison_du_miracle/screens/home_screen.dart';
import 'package:maison_du_miracle/screens/home_shell.dart';
import 'package:maison_du_miracle/state/calendar_providers.dart';
import 'package:maison_du_miracle/widgets/app_bottom_nav.dart';
import 'package:maison_du_miracle/widgets/app_drawer_menu.dart';
import 'package:maison_du_miracle/widgets/home_tab.dart';

import '../helpers/pump_screen.dart';

/// Monte la coquille entière — c'est **elle** qui porte le tiroir, et non la
/// route `/home` : c'est ce qui garde l'onglet courant en `State` local.
///
/// L'agenda est forcé sur son double en mémoire, sans quoi la section « À
/// venir » de l'accueil ouvrirait une socket, à laquelle `flutter test` répond
/// 400.
Future<void> _pumpShell(WidgetTester tester) => pumpScreen(
      tester,
      const HomeShell(),
      overrides: [
        calendarRepositoryProvider
            .overrideWithValue(InMemoryCalendarRepository()),
      ],
    );

ZoomDrawerState _drawer(WidgetTester tester) =>
    tester.state<ZoomDrawerState>(find.byType(ZoomDrawer));

/// Les libellés attendus, **lus dans les traductions** et non recopiés.
final _fr = AppLocalizationsFr();

/// **L'écran que la coquille affiche**, et non le numéro qu'elle porte.
///
/// C'est toute la différence que ce chantier installe. Ce test attendait
/// autrefois « l'onglet 0 » : il serait resté vert le jour où l'onglet 0 cesse
/// d'être l'accueil, c'est-à-dire exactement le jour où le tiroir se met à
/// ouvrir le mauvais écran. Désormais il nomme l'écran, et c'est le type qui
/// porte la correspondance.
Widget _screen(WidgetTester tester) {
  final stack = tester.widget<IndexedStack>(find.byKey(HomeShell.tabsKey));
  expect(stack.index, isNotNull,
      reason: 'la coquille n\'affiche aucun onglet du tout');
  return stack.children[stack.index!];
}

/// Un libellé **de la barre du bas**, et de nulle part ailleurs : le tiroir
/// porte aussi « Accueil ».
Finder _navTab(String label) => find.descendant(
      of: find.byType(AppBottomNav),
      matching: find.text(label),
    );

/// Ouvre le menu par l'icône et laisse l'animation d'ouverture se terminer.
Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(HomeScreen.menuButtonKey));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('Menu latéral de l\'accueil', () {
    testWidgets('l\'icône ouvre le menu, qui rend ses quatre entrées',
        (tester) async {
      await _pumpShell(tester);

      // L'icône était décorative depuis l'origine : le tiroir doit partir fermé.
      expect(_drawer(tester).isOpen(), isFalse);

      await _openMenu(tester);

      expect(_drawer(tester).isOpen(), isTrue);
      expect(find.byKey(AppDrawerMenu.homeKey), findsOneWidget);
      expect(find.byKey(AppDrawerMenu.termsKey), findsOneWidget);
      expect(find.byKey(AppDrawerMenu.privacyKey), findsOneWidget);
      expect(find.byKey(AppDrawerMenu.aboutKey), findsOneWidget);
      // Quatre entrées, rien d'autre : ni mode sombre, ni aide, ni
      // déconnexion — l'écran Profil les porte déjà.
      expect(
          find.descendant(
            of: find.byType(AppDrawerMenu),
            matching: find.byType(InkWell),
          ),
          findsNWidgets(4));
    });

    testWidgets(
        '« Accueil » ramène à l\'écran d\'accueil, depuis un autre onglet',
        (tester) async {
      await _pumpShell(tester);

      // Un onglet autre que l'accueil, choisi **par son libellé** et vérifié
      // **par son écran**. Les annonces, et non le dernier onglet de la barre :
      // ce test porte sur le tiroir, pas sur la garde de session que « Profil »
      // ferait entrer en scène.
      await tester.tap(_navTab(_fr.navAnnouncements));
      await tester.pump();
      expect(_screen(tester), isA<AnnouncementsScreen>());

      // L'icône du menu **n'existe que sur l'accueil** — c'est la règle — donc
      // on ouvre le tiroir par son contrôleur. Ce que ce test vérifie n'est pas
      // l'ouverture (l'autre s'en charge) mais le rappel : « Accueil » ramène à
      // **l'accueil** depuis n'importe quel onglet, et non seulement depuis
      // celui d'où le menu s'ouvre aujourd'hui.
      _drawer(tester).open();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byKey(AppDrawerMenu.homeKey));
      await tester.pump();
      // L'onglet change immédiatement ; le tiroir se referme en s'animant.
      expect(_screen(tester), isA<HomeScreen>());

      await tester.pump(const Duration(milliseconds: 400));
      expect(_drawer(tester).isOpen(), isFalse);
    });

    test('l\'entrée « Accueil » désigne un onglet, pas un numéro', () {
      // La constante que le tiroir partage avec la coquille. Elle valait `0` ;
      // elle vaut maintenant un nom, et c'est le seul moyen qu'un
      // réordonnancement de la barre ne la laisse pas mentir en silence.
      expect(AppDrawerMenu.homeTab, HomeTab.home);
    });

    testWidgets('aucun glissement horizontal n\'ouvre le menu', (tester) async {
      await _pumpShell(tester);

      // Le geste est coupé (`disableDragGesture`) : trois carrousels et le
      // `PageView` de la visionneuse de statuts vivent sous cet écran.
      expect(
          tester.widget<ZoomDrawer>(find.byType(ZoomDrawer)).disableDragGesture,
          isTrue);

      await tester.dragFrom(const Offset(8, 400), const Offset(260, 0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_drawer(tester).isOpen(), isFalse);
    });
  });
}
