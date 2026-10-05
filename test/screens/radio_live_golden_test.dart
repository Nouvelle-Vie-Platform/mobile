/// **Les trois visages de la page live** (#135), en images de référence —
/// pour que l'œil juge ce qu'aucune assertion ne dit : la composition, le
/// voile, la lisibilité sur le fond de saison.
///
/// Taille téléphone (390 × 844 points, densité 1), texte en Atkinson
/// Hyperlegible et pictogrammes Material chargés pour de vrai — sans quoi le
/// harnais peint des rectangles (police Ahem). ⚠️ **Les emojis restent des
/// rectangles** sans `GOLDEN_EMOJI_FONT` (voir plus bas) : aucune police emoji
/// n'est embarquée dans le dépôt, et le harnais n'en a pas. Ce n'est pas un
/// défaut de la page ; sur un téléphone, la police du système les dessine.
///
/// **Étiqueté `golden`, donc sauté par défaut** (`dart_test.yaml`) : les images
/// dépendent du rendu des polices de la machine qui les produit, et des PNG
/// faits sur macOS échoueraient en CI Linux sur un anticrénelage, pas sur un
/// défaut de la page.
///
/// Générer ou régénérer les images, sur sa machine :
///
/// ```sh
/// flutter test --run-skipped --update-goldens test/screens/radio_live_golden_test.dart
/// ```
///
/// Pour voir les emojis plutôt que des rectangles, désigner une police emoji
/// **en couleurs COLR** (Twemoji ou OpenMoji « glyf_colr_0 ») : le `.ttc` du
/// système ne se charge pas, et Noto Color Emoji (bitmaps CBDT) reste vide
/// sous le rendu macOS du harnais.
///
/// ```sh
/// GOLDEN_EMOJI_FONT=/chemin/vers/Twemoji-glyf_colr_0.ttf \
///   flutter test --run-skipped --update-goldens test/screens/radio_live_golden_test.dart
/// ```
@Tags(['golden'])
library;

import 'dart:io';

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

/// Vrai quand une police emoji a été chargée (`GOLDEN_EMOJI_FONT`).
var _emojiLoaded = false;
const _emojiFamily = 'GoldenEmoji';

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

  final emoji = Platform.environment['GOLDEN_EMOJI_FONT'];
  if (emoji != null && File(emoji).existsSync()) {
    final bytes = File(emoji).readAsBytesSync();
    final loader = FontLoader(_emojiFamily)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
    _emojiLoaded = true;
  }
}

/// L'écran, avec la police emoji en **repli** du thème quand elle est chargée :
/// le harnais n'a aucun repli système, et un glyphe absent d'Atkinson y reste
/// un rectangle.
Widget _screen() {
  const screen = RadioScreen();
  if (!_emojiLoaded) return screen;
  return Builder(
    builder: (context) {
      final base = Theme.of(context);
      return Theme(
        data: base.copyWith(
          textTheme:
              base.textTheme.apply(fontFamilyFallback: const [_emojiFamily]),
        ),
        child: screen,
      );
    },
  );
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
      _screen(),
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
    // Image par image : un seul `pump` de 900 ms ne donnerait à l'horloge des
    // particules qu'une image, à l'instant zéro — toutes encore invisibles.
    for (var i = 0; i < 45; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    await expectLater(
      find.byType(RadioScreen),
      matchesGoldenFile('goldens/radio_live_en_direct_moderateur.png'),
    );
    // Les réactions finissent leur course : aucune horloge ne survit au test.
    await tester.pump(const Duration(seconds: 4));
  });
}
