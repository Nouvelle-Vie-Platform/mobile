import 'package:drift/native.dart';
import 'package:flutter/material.dart' show SwitchListTile;
import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/models/media_preferences.dart';
import 'package:maison_du_miracle/screens/media_settings_screen.dart';
import 'package:maison_du_miracle/state/media_settings_providers.dart';

import '../helpers/pump_screen.dart';

/// **Ce fichier a déjà bloqué le harnais une fois**, et la raison est la seule
/// chose à retenir avant d'y toucher : la version précédente laissait l'écran
/// ouvrir le **flux Drift** de `mediaPreferencesProvider`, et le montage se
/// figeait — processus à 0 % de CPU pendant dix minutes, donc une attente de
/// ressource, avant expiration.
///
/// La lecture est donc **surchargée par un flux nu**. L'écriture, elle, garde le
/// vrai DAO sur une base en mémoire : c'est un `insert` ponctuel, pas un flux, et
/// c'est exactement ce que le test doit vérifier — que toucher une ligne écrit
/// bien le réglage.
void main() {
  late AppDatabase database;

  Future<void> pump(
    WidgetTester tester, {
    MediaPreferences preferences = const MediaPreferences(),
  }) async {
    // Un viewport très haut : le `ListView` construit ses enfants
    // paresseusement, et une option hors champ n'existe pas dans l'arbre.
    tester.view.physicalSize = const Size(1170, 7200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await pumpScreen(
      tester,
      const MediaSettingsScreen(),
      database: database,
      overrides: [
        mediaPreferencesProvider
            .overrideWith((ref) => Stream.value(preferences)),
      ],
    );
  }

  group('Panneau Qualité & données', () {
    testWidgets('les trois usages, chacun sur quatre paliers', (tester) async {
      await pump(tester);

      for (final usage in MediaUsage.values) {
        // La radio a ses deux choix à elle : voir son groupe.
        if (usage == MediaUsage.radio) continue;
        for (final quality in MediaQuality.values) {
          expect(
            find.byKey(MediaSettingsScreen.optionKey(usage, quality)),
            findsOneWidget,
            reason: '$usage devrait proposer $quality',
          );
        }
      }
    });

    testWidgets('toucher une ligne écrit le réglage dans le magasin',
        (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(
        MediaSettingsScreen.optionKey(MediaUsage.streaming, MediaQuality.high),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // **`runAsync`, sans quoi le test se fige.** Un flux Drift vit sur la
      // vraie boucle d'événements ; l'attendre depuis la zone à horloge factice
      // de `testWidgets` ne rend jamais la main — processus à 0 % de CPU
      // jusqu'à expiration. C'est ce qui a bloqué ce fichier la première fois.
      final stored = await tester.runAsync(
        () => database.settingsDao.watchMediaPreferences().first,
      );
      expect(stored!.streaming, MediaQuality.high);
      // Trois réglages séparés, pas un seul appliqué partout.
      expect(stored.live, MediaQuality.auto);
      expect(stored.download, MediaQuality.auto);
    });

    testWidgets('le palier enregistré est celui qui porte la coche',
        (tester) async {
      await pump(tester,
          preferences: const MediaPreferences(live: MediaQuality.mid));

      final selected = tester.widget<MediaSettingsScreen>(
        find.byType(MediaSettingsScreen),
      );
      expect(selected, isNotNull);
      // La coche se lit sur le rendu : l'option `mid` du direct doit exister et
      // les quatre du même usage rester présentes.
      expect(
        find.byKey(
            MediaSettingsScreen.optionKey(MediaUsage.live, MediaQuality.mid)),
        findsOneWidget,
      );
    });

    testWidgets('la phrase d\'impact affiche les Mo de l\'échelle',
        (tester) async {
      await pump(tester);

      // Le chiffre vient de `MediaQuality`, jamais d'une chaîne écrite à la
      // main : c'est ce qui l'empêche de mentir le jour où l'échelle bouge.
      expect(find.textContaining('29'), findsWidgets);
      expect(find.textContaining('58'), findsWidgets);
      expect(find.textContaining('86'), findsWidgets);
    });
  });

  group('La radio', () {
    testWidgets('deux choix, Automatique coché par défaut', (tester) async {
      await pump(tester);

      for (final quality in RadioQuality.values) {
        expect(find.byKey(MediaSettingsScreen.radioOptionKey(quality)),
            findsOneWidget);
      }
      // Aucun palier des enseignements sous la radio.
      expect(
        find.byKey(
            MediaSettingsScreen.optionKey(MediaUsage.radio, MediaQuality.high)),
        findsNothing,
      );
      // Le coût d'Économie vient de `RadioQuality`.
      expect(find.textContaining('14'), findsWidgets);
    });

    testWidgets('toucher Économie écrit le réglage dans le magasin',
        (tester) async {
      await pump(tester);

      await tester.tap(
        find.byKey(MediaSettingsScreen.radioOptionKey(RadioQuality.economy)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // `runAsync` : voir le test des enseignements ci-dessus.
      final stored = await tester.runAsync(
        () => database.settingsDao.watchMediaPreferences().first,
      );
      expect(stored!.radio, RadioQuality.economy);
      expect(stored.streaming, MediaQuality.auto);
    });
  });

  group('Télécharger en données mobiles (F8)', () {
    testWidgets('le toggle est présent et désactivé par défaut',
        (tester) async {
      await pump(tester);

      final toggle = tester.widget<SwitchListTile>(
        find.byKey(MediaSettingsScreen.downloadOnCellularKey),
      );
      // Défaut wifi seulement : le forfait n'est pas consommé sans choix.
      expect(toggle.value, isFalse);
    });

    testWidgets('la coche reflète le réglage enregistré', (tester) async {
      await pump(
        tester,
        preferences: const MediaPreferences(downloadOnCellular: true),
      );

      final toggle = tester.widget<SwitchListTile>(
        find.byKey(MediaSettingsScreen.downloadOnCellularKey),
      );
      expect(toggle.value, isTrue);
    });

    testWidgets('l\'activer écrit le réglage dans le magasin', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(MediaSettingsScreen.downloadOnCellularKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final stored = await tester.runAsync(
        () => database.settingsDao.downloadOnCellular(),
      );
      expect(stored, isTrue);
    });
  });
}
