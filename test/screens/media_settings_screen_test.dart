import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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
/// La lecture est donc **surchargée par un flux nu**. L'écriture, elle, garde
/// le vrai DAO sur une base en mémoire : c'est un `insert` ponctuel, pas un
/// flux, et c'est exactement ce que le test doit vérifier — que toucher une
/// pastille écrit bien le réglage. Corollaire : le choix affiché ne suit pas
/// l'écriture (le flux est figé), ce qui garde l'arc immobile d'un toucher à
/// l'autre.
void main() {
  late AppDatabase database;

  Future<void> pump(
    WidgetTester tester, {
    MediaPreferences preferences = const MediaPreferences(),
  }) async {
    // Un téléphone ordinaire en largeur (390 px logiques), très haut pour que
    // l'interrupteur du téléchargement soit construit sans défiler.
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

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// **`runAsync`, sans quoi le test se fige.** Un flux Drift vit sur la vraie
  /// boucle d'événements ; l'attendre depuis la zone à horloge factice de
  /// `testWidgets` ne rend jamais la main.
  Future<MediaPreferences> stored(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final value = await tester.runAsync(
      () => database.settingsDao.watchMediaPreferences().first,
    );
    return value!;
  }

  Finder radioOption(RadioQuality quality) =>
      find.byKey(MediaSettingsScreen.radioOptionKey(quality));

  group('La page Qualité', () {
    testWidgets('trois onglets, la radio d\'abord', (tester) async {
      await pump(tester);

      expect(find.text('RADIO'), findsOneWidget);
      expect(find.text('ÉCOUTE'), findsOneWidget);
      expect(find.text('TÉLÉCHARGEMENT'), findsOneWidget);
      expect(find.text('Quelle qualité pour la radio ?'), findsOneWidget);
    });

    testWidgets('ni Direct ni Mon assemblée ici', (tester) async {
      await pump(tester);

      expect(find.text('Mon assemblée'), findsNothing);
      expect(find.byKey(const Key('branch_scope_all')), findsNothing);
      for (final tab in ['RADIO', 'ÉCOUTE', 'TÉLÉCHARGEMENT']) {
        await openTab(tester, tab);
        expect(find.textContaining('Direct'), findsNothing, reason: tab);
      }
    });
  });

  group('Onglet Radio', () {
    testWidgets('chaque pastille enregistre son choix', (tester) async {
      await pump(tester);

      for (final quality in RadioQuality.values) {
        await tester.tap(radioOption(quality));
        expect((await stored(tester)).radio, quality, reason: '$quality');
      }
      // La radio a sa clé à elle : les enseignements n'ont pas bougé.
      expect((await stored(tester)).streaming, MediaQuality.auto);
    });

    testWidgets('la pastille choisie est la grande, et porte le nom',
        (tester) async {
      await pump(
        tester,
        preferences: const MediaPreferences(radio: RadioQuality.economy),
      );

      final chosen = radioOption(RadioQuality.economy);
      final chosenWidth = tester.getSize(chosen).width;
      for (final other in [
        RadioQuality.minimum,
        RadioQuality.auto,
        RadioQuality.high,
      ]) {
        final width = tester.getSize(radioOption(other)).width;
        expect(chosenWidth / width, closeTo(1.6, 0.01), reason: '$other');
      }
      expect(
        find.descendant(of: chosen, matching: find.text('Économie')),
        findsOneWidget,
      );
      // Les autres n'ont pas de libellé.
      expect(find.text('Automatique'), findsNothing);
      expect(find.text('Minimum'), findsNothing);
      // La consommation vient du débit : 32 k ≈ 14 Mo par heure.
      expect(find.text('≈ 14 Mo par heure'), findsOneWidget);
    });

    testWidgets('Automatique dit qu\'il s\'adapte', (tester) async {
      await pump(tester);

      expect(find.text('S\'adapte à votre réseau'), findsOneWidget);
    });

    testWidgets('glisser le curseur change le choix', (tester) async {
      await pump(tester);
      final slider = find.byKey(
        MediaSettingsScreen.sliderKey(MediaUsage.radio),
      );

      await tester.drag(slider, const Offset(-180, 0));
      expect((await stored(tester)).radio, RadioQuality.minimum);

      await tester.drag(slider, const Offset(180, 0));
      expect((await stored(tester)).radio, RadioQuality.high);
    });

    testWidgets('pastille et curseur se lisent au lecteur d\'écran',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      expect(
        tester.getSemantics(radioOption(RadioQuality.auto)),
        containsSemantics(
          label: 'Automatique',
          isButton: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(
          find.byKey(MediaSettingsScreen.sliderKey(MediaUsage.radio)),
        ),
        containsSemantics(
          isSlider: true,
          value: 'Automatique',
          increasedValue: 'Haute',
          decreasedValue: 'Économie',
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('Onglet Écoute', () {
    testWidgets('quatre paliers, chacun enregistré', (tester) async {
      await pump(tester);
      await openTab(tester, 'ÉCOUTE');

      expect(find.text('Quelle qualité pour l\'écoute ?'), findsOneWidget);
      for (final quality in MediaSettingsScreen.arcOrder) {
        await tester.tap(find.byKey(
          MediaSettingsScreen.optionKey(MediaUsage.streaming, quality),
        ));
        final prefs = await stored(tester);
        expect(prefs.streaming, quality, reason: '$quality');
        expect(prefs.download, MediaQuality.auto);
      }
    });

    testWidgets('Haute choisie : la grande, et ≈ 86 Mo par heure',
        (tester) async {
      await pump(
        tester,
        preferences: const MediaPreferences(streaming: MediaQuality.high),
      );
      await openTab(tester, 'ÉCOUTE');

      final chosen = find.byKey(
        MediaSettingsScreen.optionKey(MediaUsage.streaming, MediaQuality.high),
      );
      expect(
        find.descendant(of: chosen, matching: find.text('Haute')),
        findsOneWidget,
      );
      expect(find.text('≈ 86 Mo par heure'), findsOneWidget);
    });

    testWidgets('glisser le curseur change le choix', (tester) async {
      await pump(tester);
      await openTab(tester, 'ÉCOUTE');

      await tester.drag(
        find.byKey(MediaSettingsScreen.sliderKey(MediaUsage.streaming)),
        const Offset(-180, 0),
      );
      expect((await stored(tester)).streaming, MediaQuality.low);
    });
  });

  group('Onglet Téléchargement', () {
    testWidgets('quatre paliers, chacun enregistré', (tester) async {
      await pump(tester);
      await openTab(tester, 'TÉLÉCHARGEMENT');

      expect(
        find.text('Quelle qualité pour les téléchargements ?'),
        findsOneWidget,
      );
      for (final quality in MediaSettingsScreen.arcOrder) {
        await tester.tap(find.byKey(
          MediaSettingsScreen.optionKey(MediaUsage.download, quality),
        ));
        final prefs = await stored(tester);
        expect(prefs.download, quality, reason: '$quality');
        expect(prefs.streaming, MediaQuality.auto);
      }
    });

    testWidgets('l\'interrupteur n\'est que dans cet onglet', (tester) async {
      await pump(tester);

      expect(
        find.byKey(MediaSettingsScreen.downloadOnCellularKey),
        findsNothing,
      );
      await openTab(tester, 'TÉLÉCHARGEMENT');
      final toggle = tester.widget<SwitchListTile>(
        find.byKey(MediaSettingsScreen.downloadOnCellularKey),
      );
      // Défaut wifi seulement : le forfait n'est pas consommé sans choix.
      expect(toggle.value, isFalse);
    });

    testWidgets('il reflète le réglage enregistré', (tester) async {
      await pump(
        tester,
        preferences: const MediaPreferences(downloadOnCellular: true),
      );
      await openTab(tester, 'TÉLÉCHARGEMENT');

      final toggle = tester.widget<SwitchListTile>(
        find.byKey(MediaSettingsScreen.downloadOnCellularKey),
      );
      expect(toggle.value, isTrue);
    });

    testWidgets('l\'activer écrit le réglage', (tester) async {
      await pump(tester);
      await openTab(tester, 'TÉLÉCHARGEMENT');

      await tester.tap(find.byKey(MediaSettingsScreen.downloadOnCellularKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final value = await tester.runAsync(
        () => database.settingsDao.downloadOnCellular(),
      );
      expect(value, isTrue);
    });
  });
}
