import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/models/media_preferences.dart';
import 'package:maison_du_miracle/screens/media_settings_screen.dart';
import 'package:maison_du_miracle/state/chat_media_providers.dart';
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
    ({int count, int bytes}) waiting = (count: 0, bytes: 0),
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
        // Même raison que la ligne du dessus : ce provider ouvre un **flux
        // Drift** (`GroupDao.watchMediaToDescend`), que l'horloge factice de
        // `testWidgets` ne fait jamais avancer.
        chatMediaWaitingProvider.overrideWith((ref) => Stream.value(waiting)),
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
    testWidgets('quatre onglets, la radio d\'abord', (tester) async {
      await pump(tester);

      expect(find.text('RADIO'), findsOneWidget);
      expect(find.text('ÉCOUTE'), findsOneWidget);
      expect(find.text('TÉLÉCHARGEMENT'), findsOneWidget);
      expect(find.text('MESSAGERIE'), findsOneWidget);
      expect(find.text('Quelle qualité pour la radio\u00a0?'), findsOneWidget);
    });

    testWidgets('ni Direct ni Mon assemblée ici', (tester) async {
      await pump(tester);

      expect(find.text('Mon assemblée'), findsNothing);
      expect(find.byKey(const Key('branch_scope_all')), findsNothing);
      for (final tab in [
        'RADIO',
        'ÉCOUTE',
        'TÉLÉCHARGEMENT',
        'MESSAGERIE',
      ]) {
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
        expect(chosenWidth / width, closeTo(104 / 60, 0.01), reason: '$other');
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

    testWidgets(
        'les pastilles restent à leur place : seule la taille suit le choix',
        (tester) async {
      Map<RadioQuality, Offset> centers() => {
            for (final q in RadioQuality.values)
              q: tester.getCenter(radioOption(q)),
          };

      await pump(
        tester,
        preferences: const MediaPreferences(radio: RadioQuality.economy),
      );
      final before = centers();
      await pump(
        tester,
        preferences: const MediaPreferences(radio: RadioQuality.high),
      );
      final after = centers();

      for (final q in RadioQuality.values) {
        expect(after[q]!.dx, closeTo(before[q]!.dx, 0.5), reason: '$q');
        expect(after[q]!.dy, closeTo(before[q]!.dy, 0.5), reason: '$q');
      }
      // De gauche à droite, dans l'ordre de l'arc.
      for (var i = 1; i < RadioQuality.values.length; i++) {
        expect(
          before[RadioQuality.values[i]]!.dx,
          greaterThan(before[RadioQuality.values[i - 1]]!.dx),
        );
      }
    });

    testWidgets('la carte dit le forfait en heures, le réseau et le rendu',
        (tester) async {
      await pump(
        tester,
        preferences: const MediaPreferences(radio: RadioQuality.minimum),
      );
      expect(find.text('≈ 7 Mo par heure'), findsOneWidget);
      expect(
        find.text('1 Go de forfait ≈ 142 h d\'écoute'),
        findsOneWidget,
      );
      expect(find.text('Passe même en 2G (EDGE)'), findsOneWidget);
      expect(find.text('Voix claire, musique sourde'), findsOneWidget);
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
        isSemantics(
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
        isSemantics(
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

      expect(find.text('Quelle qualité pour l\'écoute\u00a0?'), findsOneWidget);
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
        find.text('Quelle qualité en téléchargement\u00a0?'),
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

  /// **L'onglet MESSAGERIE** (T3, #225). Le test qui porte la tranche est le
  /// premier : l'interrupteur du téléchargement **n'est pas** ici, parce que
  /// autoriser le forfait pour un enseignement d'une heure qu'on a demandé
  /// n'est pas autoriser toutes les vidéos qu'un groupe publiera demain.
  group('L\'onglet Messagerie', () {
    testWidgets('n\'emprunte pas l\'interrupteur du téléchargement',
        (tester) async {
      await pump(tester);
      await openTab(tester, 'MESSAGERIE');

      expect(
        find.byKey(MediaSettingsScreen.downloadOnCellularKey),
        findsNothing,
      );
      // Il a son propre cadran, à trois crans.
      for (final descent in ChatMediaDescent.values) {
        expect(
          find.byKey(MediaSettingsScreen.chatMediaOptionKey(descent)),
          findsOneWidget,
          reason: descent.key,
        );
      }
    });

    testWidgets('sa question, son explication, et le wifi par défaut',
        (tester) async {
      await pump(tester);
      await openTab(tester, 'MESSAGERIE');

      expect(
        find.text('Garder les médias des conversations\u00a0?'),
        findsOneWidget,
      );
      expect(
        find.textContaining('se revoit hors ligne'),
        findsOneWidget,
      );
      // Le défaut est « En wifi » : seule la pastille choisie porte son nom.
      expect(find.text('En wifi'), findsOneWidget);
      expect(
        find.textContaining('attend le wifi'),
        findsOneWidget,
      );
    });

    testWidgets('toucher un cran écrit le réglage', (tester) async {
      await pump(tester);
      await openTab(tester, 'MESSAGERIE');

      for (final descent in ChatMediaDescent.values) {
        await tester
            .tap(find.byKey(MediaSettingsScreen.chatMediaOptionKey(descent)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        final value = await tester.runAsync(
          () => database.settingsDao.chatMediaDescent(),
        );
        expect(value, descent, reason: descent.key);
      }
    });

    testWidgets('le poids annoncé est celui du magasin, pas une estimation',
        (tester) async {
      await pump(tester, waiting: (count: 3, bytes: 2400000));
      await openTab(tester, 'MESSAGERIE');

      // 2 400 000 octets = « 2,4 Mo », par `formatByteSize` — le même
      // formatage que la taille d'un document dans une bulle.
      expect(find.text('2,4 Mo en attente'), findsOneWidget);
      expect(find.text('3 médias reçus'), findsOneWidget);
    });

    testWidgets('rien en attente s\'affiche comme une absence', (tester) async {
      await pump(tester);
      await openTab(tester, 'MESSAGERIE');

      expect(find.text('Tout est déjà sur l\'appareil'), findsOneWidget);
      expect(find.textContaining('en attente'), findsNothing);
      expect(find.textContaining('médias reçus'), findsNothing);
    });
  });
}
