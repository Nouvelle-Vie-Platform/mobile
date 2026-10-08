import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/core/config/radio_config.dart';
import 'package:maison_du_miracle/data/players/content_player.dart';
import 'package:maison_du_miracle/data/radio/radio_antenna.dart';
import 'package:maison_du_miracle/data/radio/radio_handshake.dart';
import 'package:maison_du_miracle/data/radio/radio_repository.dart';
import 'package:maison_du_miracle/data/radio/radio_status.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/state/player_providers.dart';
import 'package:maison_du_miracle/state/radio_providers.dart';
import 'package:maison_du_miracle/widgets/home/radio_cta_pill.dart';

import '../helpers/pump_screen.dart';
import '../helpers/radio_doubles.dart';

/// **Le bouton d'antenne de l'accueil** (#104, #134) — le geste, l'inertie, les
/// états et la reprise.
///
/// ⚠️ **Jamais `pumpAndSettle` ici**, et ce n'est pas une précaution de style : le
/// bouton porte une **animation continue** (le pictogramme pulse sans fin, et un
/// témoin tourne pendant la connexion). `pumpAndSettle` attendrait une
/// stabilisation qui n'arrive jamais et expirerait au bout de dix minutes. On
/// avance l'horloge, comme partout dans ce dépôt.
void main() {
  /// Ce que la page d'antenne affiche — on ne monte pas le vrai écran : ce qu'on
  /// vérifie est **qu'on y va**, pas ce qu'elle dessine (`feature_screens_test`
  /// s'en charge).
  const pageMarker = 'page-antenne';

  /// **Le libellé du bouton ne varie plus** (44092f0) : le nom de l'antenne
  /// (`radioTitle`, « New Life Radio ») dans tous les états. Les six phrases d'avant — « Suivre », « Hors antenne »,
  /// « Nouvelle tentative… » et les trois causes d'échec — ont quitté le bouton.
  ///
  /// La règle que ces phrases rendaient visibles, elle, n'a pas bougé : c'est
  /// [RadioListening] qui décide de la phase et qui classe la cause d'un échec.
  /// Les tests la lisent donc là où elle vit désormais, sur l'état que le bouton
  /// observe — et vérifient, à chaque fois, que le bouton est bien là avec son
  /// libellé.
  const label = 'New Life Radio';

  RadioStatus status(WidgetTester tester) => ProviderScope.containerOf(
        tester.element(find.byType(RadioCtaPill, skipOffstage: false)),
      ).read(radioListeningProvider);

  void expectPhase(WidgetTester tester, RadioPhase phase) {
    // Dans le bouton : le mini-lecteur (#117) porte le même titre pendant que
    // l'antenne joue, et chercher dans tout l'écran le compterait deux fois.
    expect(
      find.descendant(
        of: find.byType(RadioCtaPill),
        matching: find.text(label),
      ),
      findsOneWidget,
    );
    expect(status(tester).phase, phase);
  }

  /// La phase seule, sans chercher le libellé : la page d'antenne couvre le
  /// bouton une fois ouverte.
  void expectPhaseOnly(WidgetTester tester, RadioPhase phase) =>
      expect(status(tester).phase, phase);

  /// **Tout ce qui se touche dans le bouton**, par clé : le bouton lui-même, et
  /// rien d'autre. Un bouton d'arrêt indépendant y ajouterait son propre
  /// détecteur — c'est son absence qu'on lit ici, sans dépendre de son
  /// pictogramme.
  List<Key?> gestures(WidgetTester tester) => tester
      .widgetList<GestureDetector>(find.descendant(
        of: find.byType(RadioCtaPill),
        matching: find.byType(GestureDetector),
      ))
      .map((detector) => detector.key)
      .toList();

  /// **Le bouton s'efface sans disparaître** — la seule trace visible, depuis
  /// 44092f0, d'une antenne annoncée muette ou d'un renoncement : le fond du
  /// bouton passe à 55 % d'opacité, et il reste appuyable.
  bool dimmed(WidgetTester tester) {
    final box = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byKey(RadioCtaPill.buttonKey),
            matching: find.byType(Container),
          ),
        )
        .first;
    return (box.decoration! as BoxDecoration).color!.a < 1;
  }

  /// Le message qui fait découvrir l'appui long (décision 15).
  const tip = 'Appui long pour ouvrir le live';

  late InertContentPlayer player;

  setUp(() => player = InertContentPlayer());

  tearDown(() => player.dispose());

  GoRouter buildRouter() => GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(
              body: Center(child: RadioCtaPill()),
            ),
          ),
          GoRoute(
            name: AppRoute.radio,
            path: '/radio',
            builder: (_, __) => const Scaffold(body: Text(pageMarker)),
          ),
        ],
      );

  Future<void> pumpPill(
    WidgetTester tester, {
    RadioRepository radio = const FixedRadioRepository(kTestAntennaOnAir),
    RadioHandshakeResolver? handshake,
    Stream<void>? radioNetwork,
  }) async {
    await pumpRouter(
      tester,
      buildRouter(),
      radio: radio,
      handshake: handshake,
      radioNetwork: radioNetwork,
      overrides: [contentPlayerProvider.overrideWithValue(player)],
    );
  }

  /// Un appui, puis **une seule image sans durée**.
  ///
  /// C'est l'assertion la plus importante de ce fichier, et elle est dans le
  /// harnais : si quoi que ce soit attendait une fenêtre de double-clic — ou si
  /// l'appui long retenait l'appui simple —, rien ne se serait produit à ce
  /// moment-là. `pump()` sans durée ne fait expirer aucune minuterie — il ne
  /// vide que la file de micro-tâches.
  Future<void> tapOnce(WidgetTester tester) async {
    await tester.tap(find.byKey(RadioCtaPill.buttonKey));
    await tester.pump();
    await tester.pump();
  }

  /// Un appui long, puis de quoi laisser la page s'ouvrir (la transition de
  /// route) — sans `pumpAndSettle`, pour la raison écrite en tête.
  Future<void> longPress(WidgetTester tester) async {
    await tester.longPress(find.byKey(RadioCtaPill.buttonKey));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  /// Peint l'état « le son sort » — le lecteur inerte ne pose jamais `hasStarted`
  /// de lui-même, puisqu'il ne décode rien.
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

  /// Peint une panne de lecture, de la nature voulue.
  ///
  /// `hasStarted` reste **vrai** : c'est le cas fidèle d'un décrochage en cours
  /// d'écoute, et c'est aussi celui qui piège — `resume()` republie `isPlaying` et
  /// `isBuffering` sans effacer `hasStarted`, donc une tentative ressemble de très
  /// près à un succès.
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

  group('L\'appui simple : lance ou arrête, tout de suite', () {
    testWidgets('à l\'arrêt, un appui lance le flux', (tester) async {
      await pumpPill(tester);
      expectPhase(tester, RadioPhase.idle);

      await tapOnce(tester);

      // Le flux est parti au premier contact, sans qu'aucune minuterie n'ait eu à
      // expirer : c'est ce que `tapOnce` prouve en ne pompant aucune durée.
      expect(player.loadedUrl, kTestAntennaOnAir.streamUrl);
      expect(player.value.contentId, RadioConfig.contentId);
      expect(player.value.isPlaying, isTrue);
      // ...et la page n'est pas ouverte : un appui ne navigue pas.
      expect(find.text(pageMarker), findsNothing);
    });

    testWidgets('un appui simple agit sans aucune attente, appui long ou pas',
        (tester) async {
      // ⚠️ **Le garde-fou de #134.** Le détecteur porte désormais `onLongPress` :
      // s'il retenait l'appui simple jusqu'à savoir qu'il n'est pas long, le
      // lancement partirait au mieux après une attente. On appuie et on relâche
      // à la main, sans laisser passer le moindre temps, puis une image **sans
      // durée** : l'écoute doit déjà être en route.
      await pumpPill(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(RadioCtaPill.buttonKey)),
      );
      await gesture.up();
      await tester.pump();

      expectPhase(tester, RadioPhase.connecting);
      await tester.pump();
      expect(player.loadCount, 1);
      expect(player.value.isPlaying, isTrue);
    });

    testWidgets('en lecture, un appui arrête', (tester) async {
      await pumpPill(tester);
      await tapOnce(tester);
      await paintPlaying(tester);
      expectPhase(tester, RadioPhase.playing);

      await tapOnce(tester);

      expect(player.loadedUrl, isNull);
      expect(player.value.contentId, isNull);
      expectPhase(tester, RadioPhase.idle);
      expect(find.text(pageMarker), findsNothing);
    });

    testWidgets('deux appuis rapprochés ne sont plus un geste à part',
        (tester) async {
      // Le double-appui de #104 a disparu : le second appui est un appui comme
      // un autre. En lecture, il arrête — puis le suivant relance, et rien
      // n'ouvre la page.
      await pumpPill(tester);
      await tapOnce(tester); // lance
      await paintPlaying(tester);

      await tapOnce(tester); // arrête
      await tapOnce(tester); // relance, sans naviguer

      expect(player.loadCount, 2);
      expect(find.text(pageMarker), findsNothing);
    });
  });

  group('L\'appui long : la page, sans toucher au son', () {
    testWidgets('en lecture, il ouvre la page et n\'arrête pas l\'antenne',
        (tester) async {
      // **Le défaut que #134 corrige** : l'ancien double-appui arrêtait puis
      // relançait — la connexion était fermée puis rouverte, et ça s'entendait.
      await pumpPill(tester);
      await tapOnce(tester);
      await paintPlaying(tester);

      await longPress(tester);

      expect(find.text(pageMarker), findsOneWidget);
      expect(player.value.contentId, RadioConfig.contentId);
      expect(player.value.isPlaying, isTrue, reason: 'rien n\'a été arrêté');
      // Un arrêt, même suivi d'une relance, aurait effacé l'adresse tenue.
      expect(player.loadedUrl, kTestAntennaOnAir.streamUrl);
      expect(player.loadCount, 1, reason: 'rien n\'a été rouvert');
      expectPhaseOnly(tester, RadioPhase.playing);
    });

    testWidgets('à l\'arrêt, il ouvre la page sans lancer', (tester) async {
      await pumpPill(tester);

      await longPress(tester);

      expect(find.text(pageMarker), findsOneWidget);
      expect(player.loadCount, 0, reason: 'le bouton n\'a rien lancé');
      expect(player.value.contentId, isNull);
      expectPhaseOnly(tester, RadioPhase.idle);
    });

    testWidgets('en connexion, il ouvre la page, connexion intacte',
        (tester) async {
      await pumpPill(tester);
      await tapOnce(tester);
      expect(find.byKey(RadioCtaPill.workingKey), findsOneWidget);
      expectPhase(tester, RadioPhase.connecting);

      await longPress(tester);

      expect(find.text(pageMarker), findsOneWidget);
      expect(player.loadCount, 1);
      expect(player.value.contentId, RadioConfig.contentId);
      expect(player.value.isPlaying, isTrue);
    });

    testWidgets('les lecteurs d\'écran annoncent l\'appui long',
        (tester) async {
      await pumpPill(tester);
      final semantics = tester.ensureSemantics();

      expect(
        tester.getSemantics(find.byKey(RadioCtaPill.buttonKey)),
        isSemantics(
          label: label,
          isButton: true,
          hasTapAction: true,
          hasLongPressAction: true,
          onLongPressHint: 'ouvrir le live',
        ),
      );
      semantics.dispose();
    });
  });

  group('Le message qui fait découvrir l\'appui long', () {
    testWidgets('au premier son d\'un lancement parti d\'ici', (tester) async {
      await pumpPill(tester);
      await tapOnce(tester);
      // En connexion, rien encore : le lancement n'a pas réussi.
      expect(find.text(tip), findsNothing);

      await paintPlaying(tester);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(tip), findsOneWidget);
    });

    testWidgets(
        'aussi quand le lecteur repasse au repos pendant le chargement '
        '(connexion → repos → lecture, relevé sur iPhone)', (tester) async {
      await pumpPill(tester);
      await tapOnce(tester);

      // Le repos transitoire : l'antenne déjà entendue, pas encore relancée —
      // `hasStarted` vrai, `isPlaying` faux. Ce n'est pas un arrêt.
      player.emit(
        const ContentPlayback(
          contentId: RadioConfig.contentId,
          hasStarted: true,
        ),
      );
      await tester.pump();
      expect(find.text(tip), findsNothing);

      await paintPlaying(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(tip), findsOneWidget);
    });

    testWidgets('pas pendant la reprise — puis au son qui finit par venir',
        (tester) async {
      await pumpPill(tester,
          radio: const FixedRadioRepository(RadioAntenna.unknown));
      await tapOnce(tester);

      await tester.pump(const Duration(minutes: 2));
      expectPhase(tester, RadioPhase.retrying);
      expect(find.text(tip), findsNothing);

      // La reprise ne s'arrête jamais (#179) : une antenne qui finit par
      // répondre est un lancement réussi, et le message vient alors.
      await paintPlaying(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(tip), findsOneWidget);
    });

    testWidgets('pas pour un lancement venu d\'ailleurs', (tester) async {
      // L'écran d'antenne et le mini-lecteur lancent aussi : le bouton ne
      // l'apprend que par le lecteur, et n'a rien à en dire.
      await pumpPill(tester);
      await player.load(
        contentId: RadioConfig.contentId,
        url: kTestAntennaOnAir.streamUrl!,
        title: label,
        isLive: true,
      );
      player.play();
      await paintPlaying(tester);
      await tester.pump(const Duration(milliseconds: 500));

      expectPhaseOnly(tester, RadioPhase.playing);
      expect(find.text(tip), findsNothing);
    });

    testWidgets('pas quand la page est déjà ouverte', (tester) async {
      // L'auditeur a lancé puis aussitôt ouvert le live : il connaît le geste.
      await pumpPill(tester);
      await tapOnce(tester);
      await longPress(tester);
      expect(find.text(pageMarker), findsOneWidget);

      await paintPlaying(tester);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(tip), findsNothing);
    });

    testWidgets('une seule fois par lancement', (tester) async {
      await pumpPill(tester);
      await tapOnce(tester);
      await paintPlaying(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(tip), findsOneWidget);

      // Le message s'efface (quatre secondes, puis sa sortie animée) ; un
      // hoquet du lecteur (tampon, puis son) ne le fait pas revenir.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text(tip), findsNothing);
      player.emit(
        const ContentPlayback(
          contentId: RadioConfig.contentId,
          isPlaying: true,
          hasStarted: true,
          isBuffering: true,
        ),
      );
      await tester.pump();
      await paintPlaying(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(tip), findsNothing);
    });
  });

  group('L\'inertie protège la connexion, pas la navigation', () {
    testWidgets('un appui pendant la connexion ne casse pas la connexion',
        (tester) async {
      await pumpPill(tester);
      await tapOnce(tester);
      expect(find.byKey(RadioCtaPill.workingKey), findsOneWidget);

      await tapOnce(tester);

      expect(player.value.contentId, RadioConfig.contentId);
      expect(player.value.isPlaying, isTrue, reason: 'rien n\'a été arrêté');
      expect(player.loadCount, 1, reason: 'rien n\'a été rouvert');
      expect(find.text(pageMarker), findsNothing);
    });

    testWidgets('une antenne mise en pause n\'est pas une antenne en connexion',
        (tester) async {
      // L'écran d'antenne et la notification savent tous deux mettre en pause, et
      // ce bouton-ci ne l'apprend que par le lecteur. Pris pour une connexion, il
      // tournerait indéfiniment **et** refuserait de s'arrêter — l'inertie — sur
      // une antenne parfaitement silencieuse.
      await pumpPill(tester);
      await tapOnce(tester);
      await paintPlaying(tester);

      player.pause();
      await tester.pump();

      expect(find.byKey(RadioCtaPill.workingKey), findsNothing);
      expectPhase(tester, RadioPhase.idle);

      // Et un appui redémarre sans rouvrir la source : le tampon déjà rempli
      // n'est pas jeté.
      await tapOnce(tester);
      expect(player.value.isPlaying, isTrue);
      expect(player.loadCount, 1);
    });

    testWidgets('en connexion, il n\'y a pas d\'arrêt à offrir',
        (tester) async {
      // Absence, pas grisage — la règle du sélecteur de canaux (#83) : une
      // commande offerte qui ne répond pas est une promesse que personne ne tient.
      //
      // Le bouton d'arrêt indépendant a quitté l'accueil (44092f0) : l'arrêt
      // passe par le simple appui (« en lecture, un appui arrête »). La règle
      // se lit donc sur `offersStop`, que l'appui consulte — et le bouton
      // retiré ne doit pas revenir pendant la connexion.
      await pumpPill(tester);
      await tapOnce(tester);
      expect(gestures(tester), [RadioCtaPill.buttonKey]);
      expect(status(tester).offersStop, isFalse);

      await paintPlaying(tester);
      expect(status(tester).offersStop, isTrue);
    });
  });

  group('Hors antenne : le bouton le dit, et lance quand même', () {
    testWidgets('il se montre éteint', (tester) async {
      // « Hors antenne » n'est plus écrit (44092f0) : le bouton le dit en
      // s'effaçant, au repos.
      await pumpPill(
        tester,
        radio: const FixedRadioRepository(kTestAntennaSilent),
      );
      expectPhase(tester, RadioPhase.idle);
      expect(dimmed(tester), isTrue);
    });

    testWidgets('et l\'appui lance quand même, et marche', (tester) async {
      // L'état n'est lu qu'au lancement et au retour à l'écran : l'antenne a pu
      // reprendre sans qu'on le sache. L'information guide, elle n'interdit pas.
      await pumpPill(
        tester,
        radio: const FixedRadioRepository(kTestAntennaSilent),
      );

      await tapOnce(tester);

      expect(player.loadedUrl, kTestAntennaSilent.streamUrl);
      expect(player.value.isPlaying, isTrue);
    });

    testWidgets('une antenne inconnue n\'est pas une antenne éteinte',
        (tester) async {
      // Le défaut de `pumpScreen` : la route n'a rien dit. Le bouton se présente
      // **au repos**, parce que « je ne sais pas » n'autorise pas à annoncer que
      // l'église ne diffuse pas.
      await pumpPill(tester,
          radio: const FixedRadioRepository(RadioAntenna.unknown));
      expectPhase(tester, RadioPhase.idle);
      expect(dimmed(tester), isFalse);
    });
  });

  /// **La reprise réactive** (#179, plan radio adaptative, décisions 2, 8, 9) :
  /// instable à 2 s, relance à 8 s, essais 1, 2, 4 puis 5 s **sans fin**, un
  /// seul essai en vol, le réseau qui revient comme accélérateur, et l'arrêt
  /// qui arrête tout.
  ///
  /// ⚠️ Les durées sont écrites **ici, en clair**, et jamais relues depuis
  /// `radio_retry.dart` : la constante est ce qu'on éprouve. Un test qui la
  /// relirait passerait au vert sur n'importe quelle valeur.
  group('La reprise : réactive, et sans abandon', () {
    /// Peint un tampon qui attend après le premier son — le blocage d'iOS, qui
    /// ne remonte aucune erreur.
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

    RadioListening listening(WidgetTester tester) => ProviderScope.containerOf(
          tester.element(find.byType(RadioCtaPill, skipOffstage: false)),
        ).read(radioListeningProvider.notifier);

    testWidgets('« Connexion instable… » à 2 s de tampon, pas avant',
        (tester) async {
      await pumpPill(tester);
      await tapOnce(tester);
      await paintPlaying(tester);
      await paintBuffering(tester);

      await tester.pump(const Duration(milliseconds: 1999));
      expectPhase(tester, RadioPhase.playing);
      expect(find.byKey(RadioCtaPill.workingKey), findsNothing);

      await tester.pump(const Duration(milliseconds: 1));
      expectPhase(tester, RadioPhase.unstable);
      expect(find.byKey(RadioCtaPill.workingKey), findsOneWidget);
      // Une antenne qui vacille s'arrête toujours.
      expect(status(tester).offersStop, isTrue);

      // Le son revient : tout s'efface, rien n'a été rouvert.
      await paintPlaying(tester);
      expectPhase(tester, RadioPhase.playing);
      expect(player.loadCount, 1);
      await tester.pump(const Duration(seconds: 30));
      expect(player.loadCount, 1, reason: 'la relance à 8 s est désarmée');
    });

    testWidgets(
        'à 8 s de tampon, une relance au bord du direct : route relue, pré-vol '
        'neuf, jamais resume()', (tester) async {
      final repository = _CountingRadioRepository();
      final handshake = RecordingRadioHandshake();
      await pumpPill(tester, radio: repository, handshake: handshake);
      await tapOnce(tester);
      await paintPlaying(tester);
      final reads = repository.calls;
      await paintBuffering(tester);

      await tester.pump(const Duration(milliseconds: 7999));
      expectPhase(tester, RadioPhase.unstable);
      expect(player.loadCount, 1);

      await tester.pump(const Duration(milliseconds: 1));
      expectPhase(tester, RadioPhase.retrying);
      expect(player.loadCount, 2, reason: 'la source est rouverte');
      expect(repository.calls, reads + 1, reason: 'GET /radio/antenna relu');
      expect(handshake.count, 2, reason: 'un pré-vol neuf');
      expect(player.loadedHeaders,
          {'Cookie': RecordingRadioHandshake.sessionAt(2)},
          reason: 'jamais l\'ancien cookie');
      expect(player.resumeCount, 0, reason: 'jamais à l\'ancienne position');
      // Ouverte sans position : le lecteur part du bord du direct.
      expect(player.value.position, Duration.zero);
      expect(player.value.hasStarted, isFalse);

      // Le son revient : la reconnexion s'efface.
      await paintPlaying(tester);
      expectPhase(tester, RadioPhase.playing);
    });

    testWidgets('après une panne : 1, 2, 4, puis 5 s, indéfiniment',
        (tester) async {
      final handshake = RecordingRadioHandshake();
      await pumpPill(tester, handshake: handshake);
      await tapOnce(tester);
      await paintPlaying(tester);

      // Chaque échec est instantané : ce sont les attentes qui bornent.
      await paintFailure(tester, 'Response code: 500');
      expectPhase(tester, RadioPhase.retrying);

      const expected = [1, 2, 4, 5, 5, 5, 5, 5, 5, 5];
      var loads = player.loadCount;
      for (final seconds in expected) {
        final delay = Duration(seconds: seconds);
        await tester.pump(delay - const Duration(milliseconds: 1));
        expect(player.loadCount, loads, reason: 'avant $delay');
        await tester.pump(const Duration(milliseconds: 1));
        loads++;
        expect(player.loadCount, loads, reason: 'à $delay');
        expectPhase(tester, RadioPhase.retrying);
        await paintFailure(tester, 'Response code: 500');
      }
      // Chaque essai est un démarrage frais, pré-vol compris.
      expect(handshake.count, 1 + expected.length);
      expect(player.resumeCount, 0);
    });

    testWidgets('aucun abandon : dix minutes de pannes, et ça essaie encore',
        (tester) async {
      final repository = _CountingRadioRepository(
        failure: const SocketException('Failed host lookup'),
      );
      await pumpPill(tester, radio: repository);
      await tapOnce(tester);
      expectPhase(tester, RadioPhase.retrying);
      final before = repository.calls;

      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(seconds: 10));
        expectPhase(tester, RadioPhase.retrying);
      }
      // 1 + 2 + 4, puis une toutes les cinq secondes : bien plus de cent.
      expect(repository.calls - before, greaterThan(100));
      expect(player.loadCount, 0);

      // La route revient : la tentative suivante joue.
      repository.failure = null;
      await tester.pump(const Duration(seconds: 5));
      expect(player.loadCount, 1);
      await paintPlaying(tester);
      expectPhase(tester, RadioPhase.playing);
    });

    testWidgets(
        'une tentative sans son ni panne (iOS) compte comme un échec au bout '
        'de 20 s', (tester) async {
      await pumpPill(tester);
      await tapOnce(tester);
      expectPhase(tester, RadioPhase.connecting);

      // Le lecteur inerte ne sort jamais de son : la connexion pend.
      await tester.pump(const Duration(milliseconds: 19999));
      expectPhase(tester, RadioPhase.connecting);
      await tester.pump(const Duration(milliseconds: 1));
      expectPhase(tester, RadioPhase.retrying);

      await tester.pump(const Duration(seconds: 1));
      expect(player.loadCount, 2, reason: 'la séquence a pris le relais');
    });

    testWidgets(
        'un seul essai en vol : la relance à 8 s ne double pas un essai '
        'programmé', (tester) async {
      await pumpPill(tester);
      await tapOnce(tester);
      await paintPlaying(tester);
      await paintFailure(tester, 'Response code: 500');
      // Un essai est programmé dans une seconde. Le lecteur se remet à
      // attendre son tampon, sans panne : la relance à 8 s ne s'arme pas.
      await paintBuffering(tester);

      await tester.pump(const Duration(seconds: 1));
      expect(player.loadCount, 2, reason: 'l\'essai programmé est parti');
      await tester.pump(const Duration(seconds: 15));
      expect(player.loadCount, 2, reason: 'et rien ne s\'y est ajouté');
    });

    testWidgets(
        'un seul essai en vol : ni la séquence ni le réseau ne doublent un '
        'démarrage qui résout', (tester) async {
      final network = StreamController<void>.broadcast();
      addTearDown(network.close);
      final handshake = _ManualRadioHandshake();
      await pumpPill(tester,
          handshake: handshake, radioNetwork: network.stream);
      await tapOnce(tester);
      handshake.complete(0);
      await tester.pump();
      await paintPlaying(tester);
      await paintFailure(tester, 'Response code: 500');

      await tester.pump(const Duration(seconds: 1));
      expect(handshake.calls, 2,
          reason: 'l\'essai est en vol, pré-vol en cours');

      network.add(null);
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      expect(handshake.calls, 2, reason: 'rien ne s\'est cumulé');
      expect(player.loadCount, 1);

      handshake.complete(1);
      await tester.pump();
      expect(player.loadCount, 2);
    });

    testWidgets(
        'le réseau qui revient : un essai tout de suite, et la séquence '
        'réarmée', (tester) async {
      final network = StreamController<void>.broadcast();
      addTearDown(network.close);
      await pumpPill(tester, radioNetwork: network.stream);
      await tapOnce(tester);
      await paintPlaying(tester);

      // Tant que tout va bien, le réseau ne déclenche rien.
      network.add(null);
      await tester.pump();
      expect(player.loadCount, 1);

      await paintFailure(tester, 'Response code: 500');
      await tester.pump(const Duration(seconds: 1));
      await paintFailure(tester, 'Response code: 500');
      await tester.pump(const Duration(seconds: 2));
      await paintFailure(tester, 'Response code: 500');
      expect(player.loadCount, 3);
      // La prochaine attente serait de quatre secondes.

      network.add(null);
      await tester.pump();
      expect(player.loadCount, 4, reason: 'essai immédiat');

      // La séquence repart de 1 s, et l'attente de 4 s a disparu.
      await paintFailure(tester, 'Response code: 500');
      await tester.pump(const Duration(milliseconds: 999));
      expect(player.loadCount, 4);
      await tester.pump(const Duration(milliseconds: 1));
      expect(player.loadCount, 5);
    });

    testWidgets('le réseau qui change pendant « Connexion instable… » relance',
        (tester) async {
      final network = StreamController<void>.broadcast();
      addTearDown(network.close);
      await pumpPill(tester, radioNetwork: network.stream);
      await tapOnce(tester);
      await paintPlaying(tester);
      await paintBuffering(tester);
      await tester.pump(const Duration(seconds: 2));
      expectPhase(tester, RadioPhase.unstable);

      network.add(null);
      await tester.pump();

      expectPhase(tester, RadioPhase.retrying);
      expect(player.loadCount, 2);
      // La relance à 8 s ne part pas en plus.
      await tester.pump(const Duration(seconds: 7));
      expect(player.loadCount, 2);
    });

    testWidgets('le bouton arrête tout : essai programmé, seuils et réseau',
        (tester) async {
      final network = StreamController<void>.broadcast();
      addTearDown(network.close);
      await pumpPill(tester, radioNetwork: network.stream);
      await tapOnce(tester);
      await paintPlaying(tester);
      await paintFailure(tester, 'Response code: 500');
      expectPhase(tester, RadioPhase.retrying);

      await tapOnce(tester); // arrête
      expectPhase(tester, RadioPhase.idle);
      expect(player.value.contentId, isNull);

      network.add(null);
      await tester.pump(const Duration(minutes: 5));
      expect(player.loadCount, 1, reason: 'plus rien ne part après l\'arrêt');
      expectPhase(tester, RadioPhase.idle);
    });

    testWidgets('l\'arrêt pendant un pré-vol en vol : rien ne rouvre après',
        (tester) async {
      final handshake = _ManualRadioHandshake();
      await pumpPill(tester, handshake: handshake);
      await tapOnce(tester);
      handshake.complete(0);
      await tester.pump();
      await paintPlaying(tester);
      await paintFailure(tester, 'Response code: 500');
      await tester.pump(const Duration(seconds: 1));
      expect(handshake.calls, 2, reason: 'un essai résout son pré-vol');

      // La ✕ du mini-lecteur passe par là.
      listening(tester).stop();
      await tester.pump();
      handshake.complete(1);
      await tester.pump(const Duration(minutes: 1));

      expect(player.loadCount, 1, reason: 'le démarrage en vol a renoncé');
      expect(player.value.contentId, isNull);
      expectPhase(tester, RadioPhase.idle);
    });

    testWidgets(
        'la notification balayée pendant un pré-vol en vol arrête aussi tout',
        (tester) async {
      final handshake = _ManualRadioHandshake();
      await pumpPill(tester, handshake: handshake);
      await tapOnce(tester);
      handshake.complete(0);
      await tester.pump();
      await paintPlaying(tester);
      await paintFailure(tester, 'Response code: 500');
      await tester.pump(const Duration(seconds: 1));
      expect(handshake.calls, 2);

      // Le système relâche le lecteur : il oublie ce qu'il tenait.
      player.stop();
      await tester.pump();
      handshake.complete(1);
      await tester.pump(const Duration(minutes: 1));

      expect(player.loadCount, 1);
      expect(player.value.contentId, isNull);
      expectPhase(tester, RadioPhase.idle);
    });

    testWidgets('la notification dit l\'état, y compris après une relance',
        (tester) async {
      await pumpPill(tester);
      await tapOnce(tester);
      await paintPlaying(tester);
      expect(player.statusLine, isNull);

      await paintBuffering(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(player.statusLine, 'Connexion instable…');

      await tester.pump(const Duration(seconds: 6));
      expectPhase(tester, RadioPhase.retrying);
      // La relance a rouvert la source — et `load` efface la ligne : elle a
      // été reposée.
      expect(player.loadCount, 2);
      expect(player.statusLine, 'Reconnexion…');

      await paintPlaying(tester);
      expect(player.statusLine, isNull);
    });

    testWidgets(
        'une pause pendant la reconnexion annule tout — et l\'auditeur '
        'reprend au bord du direct', (tester) async {
      final network = StreamController<void>.broadcast();
      addTearDown(network.close);
      final handshake = RecordingRadioHandshake();
      await pumpPill(
        tester,
        handshake: handshake,
        radioNetwork: network.stream,
      );
      await tapOnce(tester);
      await paintPlaying(tester);
      await paintFailure(tester, 'Response code: 500');
      expectPhase(tester, RadioPhase.retrying);

      // Le bouton pause, ou un appel : le lecteur se met en pause.
      player.pause();
      await tester.pump();
      expectPhase(tester, RadioPhase.idle);

      network.add(null);
      await tester.pump(const Duration(minutes: 5));
      expect(player.loadCount, 1, reason: 'aucun essai ne remet le son');
      expect(player.value.isPlaying, isFalse);
      expectPhase(tester, RadioPhase.idle);

      await tapOnce(tester);
      expect(player.loadCount, 2, reason: 'un démarrage frais');
      expect(handshake.count, 2, reason: 'pré-vol neuf');
      expect(player.resumeCount, 0);
    });

    testWidgets(
        'une pause pendant « Connexion instable… » : pas de relance à 8 s, et '
        'la reprise rouvre au lieu de jouer la source figée', (tester) async {
      final handshake = RecordingRadioHandshake();
      await pumpPill(tester, handshake: handshake);
      await tapOnce(tester);
      await paintPlaying(tester);
      await paintBuffering(tester);
      await tester.pump(const Duration(seconds: 2));
      expectPhase(tester, RadioPhase.unstable);

      player.pause();
      await tester.pump();
      expectPhase(tester, RadioPhase.idle);
      await tester.pump(const Duration(minutes: 1));
      expect(player.loadCount, 1, reason: 'la relance à 8 s est désarmée');
      expect(player.value.isPlaying, isFalse);

      // Sans panne en main, c'est la pause elle-même qui exige la réouverture.
      await tapOnce(tester);
      expect(player.loadCount, 2);
      expect(handshake.count, 2);
      expect(player.resumeCount, 0);
    });

    testWidgets(
        'un appel pendant un essai en vol : l\'essai renonce, et la fin de '
        'l\'appel rouvre au bord du direct', (tester) async {
      final handshake = _ManualRadioHandshake();
      await pumpPill(tester, handshake: handshake);
      await tapOnce(tester);
      handshake.complete(0);
      await tester.pump();
      await paintPlaying(tester);
      await paintFailure(tester, 'Response code: 500');
      await tester.pump(const Duration(seconds: 1));
      expect(handshake.calls, 2, reason: 'un essai résout son pré-vol');

      // `just_audio` met en pause de lui-même à l'interruption.
      player.pause();
      await tester.pump();
      expectPhase(tester, RadioPhase.idle);
      handshake.complete(1);
      await tester.pump(const Duration(minutes: 1));
      expect(player.loadCount, 1, reason: 'l\'essai en vol a renoncé');
      expect(player.value.isPlaying, isFalse);

      // Fin de l'appel : `just_audio` relance la lecture sans passer par le
      // contrôleur — la notification fait de même. La source périmée n'est
      // pas reprise : on rouvre.
      player.play();
      await tester.pump();
      expect(handshake.calls, 3, reason: 'un démarrage frais');
      handshake.complete(2);
      await tester.pump();
      expect(player.loadCount, 2);
      expect(player.loadedHeaders, {'Cookie': 'hlsSession=manual-2'});
    });
  });

  group('Un seul lecteur : la radio remplace', () {
    testWidgets('un enseignement en cours est remplacé, pas mis en pause',
        (tester) async {
      await pumpPill(tester);
      await player.load(
        contentId: 'teaching-42',
        url: 'https://media.test/teaching-42/master.m3u8',
        title: 'La foi qui déplace',
        author: 'Pasteur',
      );
      player.play();
      await tester.pump();

      await tapOnce(tester);

      // Le lecteur ne tient plus qu'une chose, et c'est l'antenne. Il n'y a ni
      // priorité, ni file, ni « reprendre ce qui jouait » — et cette tranche n'en
      // invente pas.
      expect(player.value.contentId, RadioConfig.contentId);
      expect(player.loadedUrl, kTestAntennaOnAir.streamUrl);
      expect(player.loadedTitle, 'New Life Radio');
      expect(player.loadedAuthor, isNull);
    });

    testWidgets('l\'antenne est annoncée au lecteur comme un direct',
        (tester) async {
      // C'est ce drapeau qui retire « ±30 s » et le déplacement de la
      // notification et de l'écran verrouillé. Le handler qui le lit ne peut pas
      // s'instancier sous `flutter test` (aucun canal de plugin) — mais le chemin
      // qui le porte jusqu'ici, lui, peut se briser en silence.
      await pumpPill(tester);
      await tapOnce(tester);
      expect(player.loadedIsLive, isTrue);
    });
  });

  group('La poignée de main par cookie de MediaMTX (#108)', () {
    late RecordingRadioHandshake handshake;

    setUp(() => handshake = RecordingRadioHandshake());

    testWidgets('rien n\'est ouvert avant que la session soit obtenue',
        (tester) async {
      // ⚠️ **L'assertion qui porte la tranche.** Le pré-vol doit être **attendu**,
      // pas lancé à côté : une ouverture partie avant la session rendrait
      // `401 {"error":"session not found"}` dès la sous-playlist, c'est-à-dire
      // exactement la panne que #108 corrige. Le portillon rend la chose
      // observable — tant qu'il n'a pas rendu, le lecteur ne doit tenir rien.
      final gate = _GatedRadioHandshake();
      await pumpPill(tester, handshake: gate);

      await tapOnce(tester);

      expect(gate.calls, 1, reason: 'le pré-vol est parti');
      expect(player.loadCount, 0, reason: 'et le lecteur attend');
      // Et le bouton dit qu'il travaille pendant ce temps-là : le pré-vol est sur
      // le chemin critique de l'écoute, il ne doit pas ressembler à un bouton mort.
      expect(find.byKey(RadioCtaPill.workingKey), findsOneWidget);

      gate.complete(
        const RadioHandshake(
          url: 'https://antenne.test/antenne/stream.m3u8',
          headers: {'Cookie': 'hlsSession=abc'},
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(player.loadCount, 1);
      expect(player.value.isPlaying, isTrue);
    });

    testWidgets('l\'URL finale ET le cookie arrivent jusqu\'au lecteur',
        (tester) async {
      // Les deux, et pas l'un sans l'autre : l'adresse de départ referait la
      // négociation sans le bocal, et l'adresse finale seule rend 401. Ce que les
      // moteurs natifs font de cet en-tête ne se voit pas ici (il y faut un
      // appareil) — mais le **chemin** qui le porte, lui, se brise en silence.
      await pumpPill(tester, handshake: handshake);

      await tapOnce(tester);

      expect(handshake.urls, [kTestAntennaOnAir.streamUrl]);
      expect(
        player.loadedUrl,
        RecordingRadioHandshake.resolvedUrlFor(kTestAntennaOnAir.streamUrl!),
      );
      expect(player.loadedUrl, isNot(kTestAntennaOnAir.streamUrl));
      expect(player.loadedHeaders,
          {'Cookie': RecordingRadioHandshake.sessionAt(1)});
    });

    testWidgets('une réouverture renégocie au lieu de rejouer', (tester) async {
      // Une session MediaMTX expire : une reprise après deux minutes de coupure ne
      // peut pas rejouer l'ancien cookie. Un pré-vol mis en cache « pour épargner
      // un aller-retour » rendrait l'antenne muette précisément quand l'auditeur
      // insiste — et le test passerait au vert.
      await pumpPill(tester, handshake: handshake);
      await tapOnce(tester);
      await paintPlaying(tester);
      expect(
        player.loadedHeaders,
        {'Cookie': RecordingRadioHandshake.sessionAt(1)},
      );

      await tapOnce(tester); // arrête
      await tapOnce(tester); // relance : la source est rouverte

      expect(handshake.count, 2, reason: 'on a renégocié');
      expect(
        player.loadedHeaders,
        {'Cookie': RecordingRadioHandshake.sessionAt(2)},
        reason: 'et c\'est la session fraîche qui est partie',
      );
      // ⚠️ La négociation repart de l'**adresse d'antenne**, jamais de l'adresse
      // déjà résolue : celle-ci est au-delà du 302, donc n'en poserait plus aucun
      // cookie.
      expect(handshake.urls, [
        kTestAntennaOnAir.streamUrl,
        kTestAntennaOnAir.streamUrl,
      ]);
    });

    testWidgets('un pré-vol sans réponse : rien n\'est ouvert, et on insiste',
        (tester) async {
      // Son échec se lit **comme les autres** : il n'a pas de voix à lui, et la
      // reprise le combat sans le nommer (#179).
      await pumpPill(
        tester,
        handshake: const FailingRadioHandshake(
          SocketException('Failed host lookup'),
        ),
      );

      await tapOnce(tester);

      expect(player.loadCount, 0, reason: 'aucune source n\'a été ouverte');
      expectPhase(tester, RadioPhase.retrying);

      await tester.pump(const Duration(minutes: 2));
      expectPhase(tester, RadioPhase.retrying);
      expect(player.loadCount, 0);
      expect(dimmed(tester), isFalse);
    });

    testWidgets('un 401 « session not found » : rien n\'est ouvert nu',
        (tester) async {
      final options = RequestOptions(path: '/antenne/index.m3u8');
      await pumpPill(
        tester,
        handshake: FailingRadioHandshake(
          DioException(
            requestOptions: options,
            response: Response<dynamic>(
              requestOptions: options,
              statusCode: 401,
              data: '{"status":"error","error":"session not found"}',
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
      );

      await tapOnce(tester);

      expect(player.loadCount, 0);
      expectPhase(tester, RadioPhase.retrying);

      await tester.pump(const Duration(minutes: 2));
      expectPhase(tester, RadioPhase.retrying);
      expect(player.loadCount, 0);
    });
  });
}

/// **Un pré-vol qu'on fait attendre**, pour voir ce qui se passe pendant.
///
/// Il n'existe que pour une assertion, et elle vaut le détour : prouver que le
/// `load` **attend** la session. Un pré-vol qui rendrait tout de suite laisserait
/// les deux ordres possibles indiscernables.
class _GatedRadioHandshake implements RadioHandshakeResolver {
  final Completer<RadioHandshake> _gate = Completer<RadioHandshake>();

  int calls = 0;

  void complete(RadioHandshake handshake) => _gate.complete(handshake);

  @override
  Future<RadioHandshake> resolve(String url) {
    calls++;
    return _gate.future;
  }
}

/// **Un pré-vol qu'on libère à la main**, appel par appel — pour voir ce qui se
/// passe pendant qu'un essai est en vol.
class _ManualRadioHandshake implements RadioHandshakeResolver {
  final List<Completer<RadioHandshake>> _pending = [];

  int get calls => _pending.length;

  /// Libère le n-ième appel (le premier vaut 0), avec une session propre.
  void complete(int call) => _pending[call].complete(
        RadioHandshake(
          url: 'https://antenne.test/antenne/stream.m3u8',
          headers: {'Cookie': 'hlsSession=manual-$call'},
        ),
      );

  @override
  Future<RadioHandshake> resolve(String url) {
    final pending = Completer<RadioHandshake>();
    _pending.add(pending);
    return pending.future;
  }
}

/// **Une route d'antenne qui compte ses lectures**, et qu'on peut faire
/// échouer puis revenir — pour prouver qu'une relance la relit.
class _CountingRadioRepository implements RadioRepository {
  _CountingRadioRepository({this.failure});

  Object? failure;
  int calls = 0;

  @override
  Future<RadioAntenna> antenna() async {
    calls++;
    final error = failure;
    if (error != null) throw error;
    return kTestAntennaOnAir;
  }
}
