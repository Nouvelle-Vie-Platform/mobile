/// **Les trois visages de la page live** (#135), en images de référence —
/// pour que l'œil juge ce qu'aucune assertion ne dit : la composition, le
/// voile, la lisibilité sur le fond de saison.
///
/// Taille téléphone (390 × 844 points, densité 1), texte en Atkinson
/// Hyperlegible et pictogrammes Material chargés pour de vrai — sans quoi le
/// harnais peint des rectangles (police Ahem). ⚠️ **Les emojis restent des
/// rectangles** : aucune police emoji n'est embarquée dans le dépôt, et le
/// harnais n'en a pas. Ce n'est pas un défaut de la page ; sur un téléphone,
/// la police du système les dessine.
///
/// Générer ou régénérer les images :
///
/// ```sh
/// flutter test --update-goldens test/screens/radio_live_golden_test.dart
/// ```
///
/// Elles dépendent du rendu des polices de la machine qui les produit : à
/// régénérer sur la même machine que la CI si elles y sont un jour vérifiées.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/config/radio_config.dart';
import 'package:maison_du_miracle/data/players/content_player.dart';
import 'package:maison_du_miracle/data/radio/radio_antenna.dart';
import 'package:maison_du_miracle/data/radio/radio_channel.dart';
import 'package:maison_du_miracle/data/radio/radio_live.dart';
import 'package:maison_du_miracle/data/radio/radio_repository.dart';
import 'package:maison_du_miracle/screens/radio_screen.dart';
import 'package:maison_du_miracle/state/player_providers.dart';

import '../helpers/pump_screen.dart';
import '../helpers/radio_live_doubles.dart';

const _url = 'https://antenne.test/antenne/index.m3u8';

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> assets) async {
    final loader = FontLoader(family);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    try {
      await loader.load();
    } catch (_) {
      // Une police absente du paquet de test donne des rectangles, pas un
      // échec : l'image reste utile pour la composition.
    }
  }

  await load('Atkinson Hyperlegible', const [
    'assets/fonts/Atkinson_Hyperlegible/AtkinsonHyperlegible-Regular.ttf',
    'assets/fonts/Atkinson_Hyperlegible/AtkinsonHyperlegible-Bold.ttf',
  ]);
  await load('MaterialIcons', const ['fonts/MaterialIcons-Regular.otf']);
}

void main() {
  setUpAll(_loadFonts);

  late InertContentPlayer player;
  late ControllableRadioChannel channel;
  late RecordingRadioLiveRepository repo;

  setUp(() {
    player = InertContentPlayer();
    channel = ControllableRadioChannel();
    repo = RecordingRadioLiveRepository();
  });
  tearDown(() => player.dispose());

  Future<void> pumpGolden(WidgetTester tester, RadioAntenna antenna) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpScreen(
      tester,
      const RadioScreen(),
      radio: FixedRadioRepository(antenna),
      radioChannel: channel,
      radioLive: repo,
      overrides: [contentPlayerProvider.overrideWithValue(player)],
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    // « Le son sort » : le lecteur inerte ne le dit jamais de lui-même.
    player.emit(
      const ContentPlayback(
        contentId: RadioConfig.contentId,
        isPlaying: true,
        hasStarted: true,
      ),
    );
    await tester.pump();

    // Le fond de saison (ici le plancher du dépôt) se décode hors de l'horloge
    // factice : une seule sortie, pour toutes les images à l'écran.
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        final image = element.widget as Image;
        await precacheImage(image.image, element);
      }
    });
    await tester.pump();
  }

  testWidgets('hors direct, sans compteur', (tester) async {
    await pumpGolden(
      tester,
      const RadioAntenna(streamUrl: _url, onAir: true),
    );
    await expectLater(
      find.byType(RadioScreen),
      matchesGoldenFile('goldens/radio_live_hors_direct_sans_compteur.png'),
    );
  });

  testWidgets('hors direct, avec compteur', (tester) async {
    await pumpGolden(
      tester,
      const RadioAntenna(streamUrl: _url, onAir: true, listeners: 128),
    );
    await expectLater(
      find.byType(RadioScreen),
      matchesGoldenFile('goldens/radio_live_hors_direct_compteur.png'),
    );
  });

  testWidgets('en direct : fil, réactions, outils du modérateur',
      (tester) async {
    final comments = [
      testComment('c-1', 'Amen ! Que Dieu bénisse ce message.'),
      testComment('c-2', 'Gloire à Dieu',
          name: 'Kossi', kind: RadioAuthorKind.guest),
      testComment('c-3', 'Bonsoir depuis Lomé', name: 'Afi D.'),
      testComment('c-4', 'Merci pasteur pour cette parole',
          name: 'Yao', kind: RadioAuthorKind.guest),
      testComment('c-5', 'Alléluia !', name: 'Ama K.'),
    ];
    repo
      ..threadValue = RadioThread(
        live: kTestLive,
        comments: comments,
        viewer: const RadioViewer(moderator: true, canComment: true),
      )
      ..queue = RadioModerationQueue(
        live: kTestLive,
        items: [
          RadioReportedComment(comment: comments[3], pendingReports: 2),
          RadioReportedComment(comment: comments[1], pendingReports: 1),
        ],
      );
    await pumpGolden(
      tester,
      RadioAntenna(
        streamUrl: _url,
        onAir: true,
        listeners: 128,
        live: kTestLive,
      ),
    );

    // L'audience réagit : un agrégat d'une seconde, des cœurs en vol.
    channel.open(moderation: true);
    await tester.pump();
    channel.emit(const RadioReactionsAggregated({
      RadioReaction.heart: 5,
      RadioReaction.pray: 2,
      RadioReaction.praise: 0,
      RadioReaction.fire: 1,
      RadioReaction.amen: 2,
    }));
    await tester.pump(const Duration(milliseconds: 900));

    await expectLater(
      find.byType(RadioScreen),
      matchesGoldenFile('goldens/radio_live_en_direct_moderateur.png'),
    );
    // Les réactions finissent leur course : aucune horloge ne survit au test.
    await tester.pump(const Duration(seconds: 4));
  });
}
