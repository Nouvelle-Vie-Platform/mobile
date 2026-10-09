import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/core/config/radio_config.dart';
import 'package:maison_du_miracle/data/players/content_player.dart';
import 'package:maison_du_miracle/data/radio/radio_antenna.dart';
import 'package:maison_du_miracle/data/radio/radio_repository.dart';
import 'package:maison_du_miracle/screens/radio_screen.dart';
import 'package:maison_du_miracle/state/player_providers.dart';
import 'package:flutter/material.dart';
import 'package:maison_du_miracle/widgets/app_error_state.dart';
import 'package:maison_du_miracle/widgets/content_player_view.dart';

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
/// `/radio`, et la course du second appui (le double-appui d'alors, remplacé
/// par l'appui long depuis #134) pendant les cinq secondes du pré-vol.
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
      // lequel l'écran se monte quand on y arrive par l'appui long du bouton.
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

  /// **Ce que l'écran dit de l'antenne** (#125, #179) — le bouton de l'accueil
  /// ne nomme rien, c'est ici que l'état se lit.
  group('L\'état de l\'antenne se lit sur /radio', () {
    const offAir = 'Hors antenne';
    // « À l'antenne » et non plus « En direct » (#135) : ce mot-là est le badge
    // d'un direct de la régie, et la radio tourne 24 h/24 sans direct.
    const live = 'À l\'antenne';
    const unstable = 'Connexion instable…';
    const retrying = 'Reconnexion…';

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

    /// Peint un tampon qui attend, en cours d'écoute — ce qu'iOS montre
    /// pendant un blocage, sans aucune erreur.
    Future<void> paintBuffering(WidgetTester tester) async {
      player.emit(
        const ContentPlayback(
          contentId: RadioConfig.contentId,
          isPlaying: true,
          isBuffering: true,
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
      expect(find.byKey(RadioAirStatus.unstableKey), findsNothing);
      expect(find.byKey(RadioAirStatus.retryingKey), findsNothing);
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
        'un tampon de 2 s remplace « À l\'antenne » par « Connexion '
        'instable… » (#179)', (tester) async {
      // Le faux « À l'antenne » d'iOS : le lecteur reste « en lecture »
      // pendant un blocage, sans erreur. C'est le tampon qui le trahit.
      await pumpRadio(tester);
      await paintPlaying(tester);
      await paintBuffering(tester);

      await tester.pump(const Duration(milliseconds: 1999));
      expect(find.text(live), findsOneWidget,
          reason: 'un hoquet ne se dit pas');

      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text(unstable), findsOneWidget);
      expect(find.byKey(RadioAirStatus.unstableKey), findsOneWidget);
      expect(find.text(live), findsNothing);

      // Le son revient : l'état aussi.
      await paintPlaying(tester);
      expect(find.text(live), findsOneWidget);
      expect(find.text(unstable), findsNothing);
    });

    testWidgets(
        '« Reconnexion… » pendant la reprise, sans nommer la panne — et sans '
        'abandon', (tester) async {
      await pumpRadio(tester);
      await paintPlaying(tester);
      await paintFailure(tester, 'Response code: 404');

      expect(find.text(retrying), findsOneWidget);
      final loads = player.loadCount;

      // Dix minutes de tentatives qui n'aboutissent pas : l'écran dit toujours
      // qu'il se reconnecte, ne nomme pas la panne, et n'offre aucune carte
      // d'échec — seul l'auditeur arrête.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(seconds: 10));
        expect(find.text(retrying), findsOneWidget, reason: 'à ${i * 10}s');
      }
      expect(find.text('Antenne indisponible'), findsNothing);
      expect(find.text('Lecture interrompue'), findsNothing);
      expect(player.loadCount, greaterThan(loads + 10),
          reason: 'les tentatives continuent');
      expect(player.resumeCount, 0, reason: 'jamais un resume() à la position');
    });

    testWidgets(
        'en reconnexion, le gros bouton offre ▶ et un appui relance par le '
        'pré-vol', (tester) async {
      final handshake = await pumpRadio(tester);
      // Le lecteur porte la panne **et** `isPlaying` : c'est l'état qui
      // affichait ⏸ et dont le premier appui « mettait en pause » un silence.
      await paintPlaying(tester);
      await paintFailure(tester, 'Response code: 404');
      expect(handshake.count, 1);

      final button = find.byKey(ContentPlayerView.playButtonKey);
      expect(
        find.descendant(of: button, matching: find.byIcon(Icons.play_arrow)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: button, matching: find.byIcon(Icons.pause)),
        findsNothing,
      );

      await tester.tap(button);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      // **Un seul appui** : nouvelle négociation, réouverture avec le cookie
      // neuf, jamais un `resume()` nu.
      expect(handshake.count, 2);
      expect(player.loadCount, 2);
      expect(player.loadedHeaders, {
        'Cookie': RecordingRadioHandshake.sessionAt(2),
      });
      expect(player.resumeCount, 0);
    });
  });
  testWidgets(
      'ouverte hors ligne : l\'état se fond dans la scène, et le retour du '
      'réseau relit l\'antenne sans geste', (tester) async {
    final network = StreamController<void>.broadcast();
    addTearDown(network.close);
    final repo = _OfflineThenOnline();
    await pumpScreen(
      tester,
      const RadioScreen(),
      radio: repo,
      radioNetwork: network.stream,
      overrides: [contentPlayerProvider.overrideWithValue(player)],
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.byKey(AppErrorState.retryKey), findsOneWidget);
    // Pas de carte posée sur l'image : aucun AppCard dans l'état d'erreur.
    expect(
      find.descendant(
        of: find.byType(AppErrorState),
        matching: find
            .byWidgetPredicate((w) => w.runtimeType.toString() == 'AppCard'),
      ),
      findsNothing,
    );
    final offline = repo.calls;

    repo.online = true;
    network.add(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(
      repo.calls,
      greaterThan(offline),
      reason: 'relue au retour du réseau, sans appui',
    );
    expect(find.byKey(AppErrorState.retryKey), findsNothing);
  });
}

class _OfflineThenOnline implements RadioRepository {
  var online = false;
  var calls = 0;

  @override
  Future<RadioAntenna> antenna() async {
    calls++;
    if (!online) throw Exception('Failed host lookup');
    return kTestAntennaOnAir;
  }

  @override
  Future<void> reportListening(String listenId) async {}
}
