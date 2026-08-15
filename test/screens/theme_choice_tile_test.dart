import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/models/theme_preferences.dart';
import 'package:maison_du_miracle/widgets/theme_choice_tile.dart';

import '../helpers/pump_screen.dart';

/// Comme pour le panneau média : la **lecture** est surchargée par un flux nu —
/// un flux Drift attendu sous l'horloge factice fige le montage — et
/// l'**écriture** garde le vrai DAO sur une base en mémoire, puisque c'est
/// justement ce qu'il faut prouver.
void main() {
  late AppDatabase database;

  Future<void> pump(
    WidgetTester tester, {
    ThemePreferences preferences = const ThemePreferences(),
  }) async {
    tester.view.physicalSize = const Size(1170, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await pumpScreen(
      tester,
      const Scaffold(body: SingleChildScrollView(child: ThemeChoiceTile())),
      database: database,
      theme: preferences,
    );
  }

  Future<ThemePreferences> stored(WidgetTester tester) async {
    return (await tester.runAsync(
      () => database.settingsDao.watchThemePreferences().first,
    ))!;
  }

  group('Le bloc d\'apparence', () {
    testWidgets('propose les quatre positions', (tester) async {
      await pump(tester);
      for (final choice in ThemeChoice.values) {
        expect(find.byKey(ThemeChoiceTile.segmentKey(choice)), findsOneWidget);
      }
    });

    testWidgets('choisir une position l\'écrit dans le magasin',
        (tester) async {
      await pump(tester);

      await tester
          .tap(find.byKey(ThemeChoiceTile.segmentKey(ThemeChoice.dark)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect((await stored(tester)).choice, ThemeChoice.dark);
    });

    testWidgets('hors Auto, aucun engrenage', (tester) async {
      // Un engrenage visible en permanence promettrait des réglages qui
      // n'existent pas pour les trois autres positions.
      await pump(tester);
      expect(find.byKey(ThemeChoiceTile.gearKey), findsNothing);
    });

    testWidgets('en Auto, l\'engrenage apparaît', (tester) async {
      await pump(tester,
          preferences: const ThemePreferences(choice: ThemeChoice.auto));
      expect(find.byKey(ThemeChoiceTile.gearKey), findsOneWidget);
    });

    testWidgets('les heures ne se déplient que sur l\'engrenage',
        (tester) async {
      await pump(tester,
          preferences: const ThemePreferences(choice: ThemeChoice.auto));

      expect(find.byKey(ThemeChoiceTile.darkFromKey), findsNothing);

      await tester.tap(find.byKey(ThemeChoiceTile.gearKey));
      await tester.pump();

      expect(find.byKey(ThemeChoiceTile.darkFromKey), findsOneWidget);
      expect(find.byKey(ThemeChoiceTile.lightFromKey), findsOneWidget);
    });

    testWidgets('hors Auto, aucun résumé horaire', (tester) async {
      await pump(tester);
      expect(find.textContaining('19:00'), findsNothing);
    });

    testWidgets('en Auto, le résumé annonce les deux heures', (tester) async {
      // Sans lui, rien ne distinguerait « Système » d'« Auto » à l'œil.
      await pump(tester,
          preferences: const ThemePreferences(choice: ThemeChoice.auto));
      expect(find.textContaining('19:00'), findsWidgets);
      expect(find.textContaining('06:00'), findsWidgets);
    });
  });
}
