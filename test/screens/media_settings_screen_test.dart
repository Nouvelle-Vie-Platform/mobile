import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show Key, Scrollable, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/models/media_preferences.dart';
import 'package:maison_du_miracle/screens/media_settings_screen.dart';

import '../helpers/pump_screen.dart';

void main() {
  late AppDatabase database;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await pumpScreen(
      tester,
      const MediaSettingsScreen(),
      database: database,
    );
  }

  Future<void> choose(WidgetTester tester, Key key) async {
    await tester.scrollUntilVisible(
      find.byKey(key),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(key));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('Panneau Qualité & données', () {
    testWidgets('les trois usages sont proposés, chacun sur quatre paliers',
        (tester) async {
      await pump(tester);

      for (final usage in MediaUsage.values) {
        for (final quality in MediaQuality.values) {
          await tester.scrollUntilVisible(
            find.byKey(MediaSettingsScreen.optionKey(usage, quality)),
            300,
            scrollable: find.byType(Scrollable).first,
          );
          expect(
            find.byKey(MediaSettingsScreen.optionKey(usage, quality)),
            findsOneWidget,
          );
        }
      }
    });

    testWidgets('choisir un palier l\'écrit dans le magasin', (tester) async {
      await pump(tester);

      await choose(
        tester,
        MediaSettingsScreen.optionKey(MediaUsage.streaming, MediaQuality.high),
      );

      final prefs = await database.settingsDao.watchMediaPreferences().first;
      expect(prefs.streaming, MediaQuality.high);
      // Les deux autres usages ne bougent pas : trois réglages séparés, pas un
      // seul appliqué partout.
      expect(prefs.live, MediaQuality.auto);
      expect(prefs.download, MediaQuality.auto);
    });

    testWidgets('la phrase d\'impact affiche les Mo de l\'échelle',
        (tester) async {
      await pump(tester);

      // Le chiffre vient de `MediaQuality`, jamais d'une chaîne écrite à la
      // main : c'est ce qui l'empêche de mentir le jour où l'échelle bouge.
      expect(find.textContaining('29'), findsWidgets);
      expect(find.textContaining('58'), findsWidgets);
    });
  });
}
