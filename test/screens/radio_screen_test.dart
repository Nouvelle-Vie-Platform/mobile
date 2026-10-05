import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/config/radio_config.dart';
import 'package:maison_du_miracle/data/players/content_player.dart';
import 'package:maison_du_miracle/data/radio/radio_antenna.dart';
import 'package:maison_du_miracle/data/radio/radio_repository.dart';
import 'package:maison_du_miracle/screens/radio_screen.dart';
import 'package:maison_du_miracle/state/player_providers.dart';
import 'package:maison_du_miracle/widgets/app_error_state.dart';

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

  /// **Ce que l'écran dit de l'antenne** (#125) — le bouton de l'accueil ne
  /// nomme aucune cause, c'est ici qu'elle se lit.
  group('L\'état de l\'antenne se lit sur /radio', () {
    const offAir = 'Hors antenne';
    const live = 'En direct';
    const retrying = 'Nouvelle tentative…';

    /// Peint « le son sort » : le lecteur inerte ne pose jamais `hasStarted` de
    /// lui-même.
    Future<void> paintPlaying(WidgetTester tester) async {
      player.emit(
        const ContentPlayback(
          contentId: RadioConfig.contentId,
          isPlaying: true,
          hasStarted: true,
        ),
      );
      await tester.pump();
    }

    /// Peint une panne du lecteur, en cours d'écoute.
    Future<void> paintFailure(WidgetTester tester, Object error) async {
      player.emit(
        ContentPlayback(
          contentId: RadioConfig.contentId,
          isPlaying: true,
          hasStarted: true,
          error: error,
        ),
      );
      await tester.pump();
    }

    /// Aucune des quatre lignes, ni les deux phrases génériques de la fiche.
    void expectNothingSaid() {
      expect(find.byKey(RadioAirStatus.offAirKey), findsNothing);
      expect(find.byKey(RadioAirStatus.liveKey), findsNothing);
      expect(find.byKey(RadioAirStatus.retryingKey), findsNothing);
      expect(find.byKey(RadioAirStatus.failedKey), findsNothing);
    }

    /// Une panne, puis les deux minutes sans succès : l'abandon.
    Future<void> abandonOn(WidgetTester tester, Object error) async {
      await paintPlaying(tester);
      await paintFailure(tester, error);
      expect(find.text(retrying), findsOneWidget);
      await tester.pump(const Duration(minutes: 2));
      expect(find.byKey(RadioAirStatus.retryingKey), findsNothing);
      expect(find.byKey(RadioAirStatus.failedKey), findsOneWidget);
      expect(find.byKey(AppErrorState.retryKey), findsOneWidget);
    }

    testWidgets('hors antenne quand la route a dit onAir: false',
        (tester) async {
      await pumpRadio(
        tester,
        radio: const FixedRadioRepository(kTestAntennaSilent),
      );

      expect(find.text(offAir), findsOneWidget);
      expect(find.byKey(RadioAirStatus.offAirKey), findsOneWidget);
    });

    testWidgets('onAir: null n\'affiche jamais « hors antenne »',
        (tester) async {
      // « Je ne sais pas » n'est pas « elle se tait » : l'affirmer serait dire
      // que l'église ne diffuse pas, sans preuve.
      await pumpRadio(
        tester,
        radio: const FixedRadioRepository(
          RadioAntenna(streamUrl: 'https://antenne.test/antenne/index.m3u8'),
        ),
      );

      expect(find.text(offAir), findsNothing);
      expectNothingSaid();
    });

    testWidgets('en direct quand le son sort — même annoncée muette',
        (tester) async {
      // L'état de la route n'est lu qu'au lancement : l'antenne a pu reprendre,
      // et le son qui sort l'emporte sur ce qu'elle disait.
      await pumpRadio(
        tester,
        radio: const FixedRadioRepository(kTestAntennaSilent),
      );
      await paintPlaying(tester);

      expect(find.text(live), findsOneWidget);
      expect(find.text(offAir), findsNothing);
    });

    testWidgets(
        'nouvelle tentative pendant les six attentes, puis la cause à l\'abandon',
        (tester) async {
      await pumpRadio(tester);
      await paintPlaying(tester);
      await paintFailure(tester, 'Response code: 500');

      // ⚠️ Les six attentes sont écrites **en clair**, jamais relues depuis
      // `kRadioRetryDelays` : la constante est ce qu'on éprouve.
      const expected = [1, 2, 4, 8, 16, 32];
      var fired = 0;
      for (final seconds in expected) {
        // Pendant toute l'attente, l'écran dit qu'il réessaie — et ne nomme
        // pas la panne qu'il combat encore.
        expect(find.text(retrying), findsOneWidget,
            reason: 'avant ${seconds}s');
        expect(find.text('Antenne indisponible'), findsNothing);
        expect(find.text('Lecture interrompue'), findsNothing);
        await tester.pump(Duration(seconds: seconds));
        fired++;
        expect(player.resumeCount, fired, reason: 'à ${seconds}s');
        if (fired < expected.length) {
          await paintFailure(tester, 'Response code: 500');
        }
      }

      // Le septième échec ne trouve plus d'attente : on renonce, et on dit
      // pourquoi.
      await paintFailure(tester, 'Response code: 500');
      expect(find.text(retrying), findsNothing);
      expect(find.text('Antenne indisponible'), findsOneWidget);
      expect(find.byKey(AppErrorState.retryKey), findsOneWidget);
    });

    testWidgets('abandon sur une coupure → « vérifiez votre connexion »',
        (tester) async {
      await pumpRadio(tester);
      await abandonOn(tester, const SocketException('Failed host lookup'));

      expect(find.text('Vérifiez votre connexion'), findsOneWidget);
    });

    testWidgets('abandon sur un refus → « antenne indisponible »',
        (tester) async {
      await pumpRadio(tester);
      await abandonOn(tester, 'Response code: 404');

      expect(find.text('Antenne indisponible'), findsOneWidget);
    });

    testWidgets('abandon sur une panne opaque → « écoute impossible »',
        (tester) async {
      // La panne d'AVFoundation ne dit pas s'il y a eu une réponse (#110) :
      // l'écran ne nomme ni le réseau ni l'antenne.
      await pumpRadio(tester);
      await abandonOn(
        tester,
        'PlatformException(abort, The operation could not be completed, '
        'AVFoundationErrorDomain, -11800)',
      );

      expect(find.text('Écoute impossible'), findsOneWidget);
      expect(find.text('Vérifiez votre connexion'), findsNothing);
    });

    testWidgets('« Réessayer » relance par le pré-vol, jamais le lecteur seul',
        (tester) async {
      final handshake = await pumpRadio(tester);
      await abandonOn(tester, 'Response code: 404');
      expect(handshake.count, 1);
      final resumes = player.resumeCount;

      await tester.tap(find.byKey(AppErrorState.retryKey));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      // Une nouvelle négociation, puis une réouverture avec le cookie neuf :
      // c'est `RadioListening.start`, pas un `resume()` nu.
      expect(handshake.count, 2);
      expect(player.loadCount, 2);
      expect(player.loadedHeaders, {
        'Cookie': RecordingRadioHandshake.sessionAt(2),
      });
      expect(player.resumeCount, resumes);
      expect(find.byKey(RadioAirStatus.failedKey), findsNothing);
    });
  });
}
