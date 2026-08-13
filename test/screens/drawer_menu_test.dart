import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:maison_du_miracle/data/repositories/calendar_repository.dart';
import 'package:maison_du_miracle/screens/home_screen.dart';
import 'package:maison_du_miracle/screens/home_shell.dart';
import 'package:maison_du_miracle/state/calendar_providers.dart';
import 'package:maison_du_miracle/widgets/app_drawer_menu.dart';

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

/// Index de l'onglet affiché par la coquille.
int? _tab(WidgetTester tester) =>
    tester.widget<IndexedStack>(find.byKey(HomeShell.tabsKey)).index;

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
      // déconnexion — l'onglet Profil les porte déjà.
      expect(
          find.descendant(
            of: find.byType(AppDrawerMenu),
            matching: find.byType(InkWell),
          ),
          findsNWidgets(4));
    });

    testWidgets('« Accueil » revient à l\'onglet 0 depuis un autre onglet',
        (tester) async {
      await _pumpShell(tester);

      // Onglet « Profil » (le dernier de la barre).
      await tester.tap(find.text('Profil'));
      await tester.pump();
      expect(_tab(tester), 3);

      // L'icône du menu **n'existe que sur l'accueil** — c'est la règle — donc
      // on ouvre le tiroir par son contrôleur. Ce que ce test vérifie n'est pas
      // l'ouverture (l'autre s'en charge) mais le rappel : « Accueil » ramène à
      // l'onglet 0 **depuis n'importe quel onglet**, et non seulement depuis
      // celui d'où le menu s'ouvre aujourd'hui.
      _drawer(tester).open();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byKey(AppDrawerMenu.homeKey));
      await tester.pump();
      // L'onglet change immédiatement ; le tiroir se referme en s'animant.
      expect(_tab(tester), 0);

      await tester.pump(const Duration(milliseconds: 400));
      expect(_drawer(tester).isOpen(), isFalse);
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
