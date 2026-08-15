import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/models/theme_preferences.dart';
import 'package:maison_du_miracle/screens/profile_screen.dart';
import 'package:maison_du_miracle/widgets/theme_sheet.dart';

import '../helpers/pump_screen.dart';

/// Comme pour le panneau média : la **lecture** est surchargée par un flux nu —
/// un flux Drift attendu sous l'horloge factice fige le montage — et
/// l'**écriture** garde le vrai DAO sur une base en mémoire, puisque c'est
/// justement ce qu'il faut prouver.
void main() {
  late AppDatabase database;

  /// Monte l'onglet Profil et ouvre la feuille par le bouton de l'en-tête —
  /// le seul chemin qui existe désormais.
  Future<void> openSheet(
    WidgetTester tester, {
    ThemePreferences preferences = const ThemePreferences(),
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await pumpScreen(
      tester,
      const Scaffold(body: ProfileScreen()),
      database: database,
      theme: preferences,
    );

    await tester.tap(find.byKey(ProfileScreen.themeButtonKey));
    await tester.pumpAndSettle();
  }

  Future<ThemePreferences> stored(WidgetTester tester) async {
    return (await tester.runAsync(
      () => database.settingsDao.watchThemePreferences().first,
    ))!;
  }

  group('L\'accès depuis le Profil', () {
    testWidgets('la liste ne porte plus le réglage d\'apparence',
        (tester) async {
      await pumpScreen(tester, const Scaffold(body: ProfileScreen()));

      // Il vit désormais derrière l'icône de l'en-tête, et là seulement.
      expect(find.byType(ThemeSheet), findsNothing);
      expect(find.byKey(ProfileScreen.themeButtonKey), findsOneWidget);
    });

    testWidgets('le bouton de l\'en-tête ouvre la feuille', (tester) async {
      await openSheet(tester);
      expect(find.byType(ThemeSheet), findsOneWidget);
    });
  });

  group('La feuille d\'apparence', () {
    testWidgets('propose les quatre positions', (tester) async {
      await openSheet(tester);
      for (final choice in ThemeChoice.values) {
        expect(find.byKey(ThemeSheet.segmentKey(choice)), findsOneWidget);
      }
    });

    testWidgets('choisir une position l\'écrit dans le magasin',
        (tester) async {
      await openSheet(tester);

      await tester.tap(find.byKey(ThemeSheet.segmentKey(ThemeChoice.dark)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect((await stored(tester)).choice, ThemeChoice.dark);
    });

    testWidgets('elle reste ouverte après un choix', (tester) async {
      // C'est un panneau, pas un menu : on doit pouvoir comparer les quatre
      // positions sans rouvrir à chaque fois.
      await openSheet(tester);

      await tester.tap(find.byKey(ThemeSheet.segmentKey(ThemeChoice.dark)));
      await tester.pumpAndSettle();

      expect(find.byType(ThemeSheet), findsOneWidget);
    });

    testWidgets('hors Auto, aucune heure', (tester) async {
      await openSheet(tester);
      expect(find.byKey(ThemeSheet.darkFromKey), findsNothing);
    });

    testWidgets('en Auto, les deux heures s\'affichent sans autre geste',
        (tester) async {
      // L'engrenage interne a disparu avec le passage en feuille : il n'existait
      // que parce que la ligne du Profil était à l'étroit.
      await openSheet(tester,
          preferences: const ThemePreferences(choice: ThemeChoice.auto));

      expect(find.byKey(ThemeSheet.darkFromKey), findsOneWidget);
      expect(find.byKey(ThemeSheet.lightFromKey), findsOneWidget);
      expect(find.text('19:00'), findsOneWidget);
      expect(find.text('06:00'), findsOneWidget);
    });
  });
}
