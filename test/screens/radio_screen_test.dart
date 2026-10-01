import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/config/radio_config.dart';
import 'package:maison_du_miracle/data/players/content_player.dart';
import 'package:maison_du_miracle/data/radio/radio_antenna.dart';
import 'package:maison_du_miracle/data/radio/radio_repository.dart';
import 'package:maison_du_miracle/screens/radio_screen.dart';
import 'package:maison_du_miracle/state/player_providers.dart';

import '../helpers/pump_screen.dart';
import '../helpers/radio_doubles.dart';

/// **L'écran d'antenne n'ouvre plus l'antenne lui-même** (#110).
///
/// Ce que ce fichier éprouve tient en une phrase : *tout chemin qui ouvre
/// l'antenne porte le cookie*. Deux chemins y arrivent — le bouton de l'accueil
/// (jugé dans `radio_cta_pill_test.dart`) et **cet écran**, qui démarre au
/// montage. Le second passait par `ContentPlayerView._loadOnce` → `_open` →
/// `player.load(url: content.playlistUrl)`, **sans en-têtes**, et prenait donc un
/// `401 {"error":"session not found"}` dans deux cas : un lien profond vers
/// `/radio`, et la course du second appui pendant les cinq secondes du pré-vol.
///
/// ⚠️ **Ce que ces tests ne prouvent PAS, et qu'il ne faut pas laisser croire** :
/// qu'un cookie traverse jusqu'à ExoPlayer ou AVFoundation. Ils s'arrêtent à
/// l'en-tête **remis au lecteur**, c'est-à-dire à la frontière du double inerte.
/// La suite demande un Android réel et un iPhone réel, et côté Darwin la clé que
/// `just_audio` pose (`AVURLAssetHTTPHeaderFieldsKey`) n'est pas documentée par
/// Apple et ne couvre peut-être pas les requêtes dérivées. Aucun harnais
/// `flutter test` ne peut en décider.
///
/// ⚠️ **Jamais `pumpAndSettle`** : la règle du dépôt, et ici le lecteur peint un
/// témoin de mise en tampon qui tourne sans fin.
void main() {
  late InertContentPlayer player;

  setUp(() => player = InertContentPlayer());
  tearDown(() => player.dispose());

  /// Monte l'écran et laisse le démarrage au montage aller jusqu'au bout.
  ///
  /// Le chemin est long et entièrement asynchrone — la route d'antenne répond, le
  /// `postFrameCallback` de `_loadOnce` part, l'enregistreur de progression
  /// s'ouvre sur le magasin, puis le pré-vol négocie —, et chaque étape rend la
  /// main à la boucle. On avance donc plusieurs images plutôt que de deviner la
  /// bonne.
  Future<RecordingRadioHandshake> pumpRadio(
    WidgetTester tester, {
    RadioRepository radio = const FixedRadioRepository(kTestAntennaOnAir),
  }) async {
    final handshake = RecordingRadioHandshake();
    await pumpScreen(
      tester,
      const RadioScreen(),
      radio: radio,
      handshake: handshake,
      overrides: [contentPlayerProvider.overrideWithValue(player)],
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    return handshake;
  }

  group('Entrer par l\'écran — y compris par un lien profond', () {
    testWidgets('l\'antenne est ouverte avec le cookie, jamais nue',
        (tester) async {
      // Personne n'a appuyé sur le bouton : c'est exactement l'entrée par lien
      // profond ou par URL web directe, le premier des deux cas de #110.
      final handshake = await pumpRadio(tester);

      expect(
        handshake.count,
        1,
        reason: 'le pré-vol a eu lieu avant toute ouverture',
      );
      expect(player.loadCount, 1);
      expect(player.loadedHeaders, {'Cookie': 'hlsSession=session-1'});
      expect(
        player.loadedUrl,
        RecordingRadioHandshake.resolvedUrlFor(kTestAntennaOnAir.streamUrl!),
        reason: 'et c\'est l\'URL finale, au-delà du 302, qui a été ouverte',
      );
    });

    testWidgets('la négociation part de l\'adresse d\'antenne', (tester) async {
      // ⚠️ Jamais de l'adresse déjà résolue : celle-ci est au-delà du 302, et ne
      // poserait donc plus aucun cookie — c'est tout l'objet du bocal de #108.
      final handshake = await pumpRadio(tester);

      expect(handshake.urls, [kTestAntennaOnAir.streamUrl]);
    });

    testWidgets('l\'antenne est annoncée au lecteur comme un direct',
        (tester) async {
      await pumpRadio(tester);

      expect(player.loadedIsLive, isTrue);
    });
  });

  group('Entrer par le bouton, puis ouvrir l\'écran', () {
    testWidgets('l\'écran ne renégocie pas ce que le bouton a déjà obtenu',
        (tester) async {
      // **La course de #110, dans l'autre sens.** Le bouton a lancé l'écoute, le
      // lecteur tient l'antenne, et l'écran se monte par-dessus. Il ne doit ni
      // rouvrir la source — ce qui couperait le tampon déjà rempli — ni consommer
      // un second aller-retour sur la fenêtre de rattrapage de 40 secondes.
      // L'antenne joue déjà, obtenue par un autre chemin — c'est l'état dans
      // lequel l'écran se monte quand on y arrive par le second appui du bouton.
      await player.load(
        contentId: RadioConfig.contentId,
        url: 'https://antenne.test/antenne/stream.m3u8',
        title: 'New Life Radio',
        isLive: true,
        headers: const {'Cookie': 'hlsSession=deja-obtenue'},
      );
      player.emit(
        const ContentPlayback(
          contentId: RadioConfig.contentId,
          isPlaying: true,
          hasStarted: true,
        ),
      );

      // ⚠️ L'antenne est **servie** par la route, donc l'écran construit bien son
      // lecteur et appelle `_loadOnce` : sans cela ce test serait vrai pour rien —
      // il passerait au vert sur un écran qui dessine une absence.
      final handshake = await pumpRadio(tester);

      expect(find.byType(RadioScreen), findsOneWidget);
      expect(handshake.count, 0, reason: 'aucun second pré-vol');
      expect(player.loadCount, 1, reason: 'la source n\'a pas été rouverte');
      expect(player.loadedHeaders, {'Cookie': 'hlsSession=deja-obtenue'});
    });
  });

  group('Quand la route d\'antenne échoue', () {
    testWidgets('rien n\'est ouvert, et surtout rien n\'est ouvert nu',
        (tester) async {
      // Une antenne sans adresse : l'écran dessine l'absence, et le lecteur ne
      // reçoit rien. C'est le cas où un `load` de repli serait le plus tentant à
      // écrire, et le plus sûrement nu.
      final handshake = await pumpRadio(
        tester,
        radio: const FixedRadioRepository(RadioAntenna.unknown),
      );

      expect(handshake.count, 0);
      expect(player.loadCount, 0);
      expect(find.text('Antenne indisponible'), findsOneWidget);
    });
  });
}
