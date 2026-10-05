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
import 'package:maison_du_miracle/data/radio/radio_failure.dart';
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

  void expectPhase(
    WidgetTester tester,
    RadioPhase phase, {
    RadioFailureKind? failure,
  }) {
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
    if (phase == RadioPhase.failed) expect(status(tester).failure, failure);
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
  const tip =
      'Astuce : un appui long sur ce bouton ouvre le live à tout moment.';

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
  }) async {
    await pumpRouter(
      tester,
      buildRouter(),
      radio: radio,
      handshake: handshake,
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

    testWidgets('pas à l\'échec', (tester) async {
      await pumpPill(tester,
          radio: const FixedRadioRepository(RadioAntenna.unknown));
      await tapOnce(tester);

      await tester.pump(const Duration(minutes: 2));
      expectPhase(tester, RadioPhase.failed, failure: RadioFailureKind.antenna);
      expect(find.text(tip), findsNothing);

      // Et un son qui viendrait après l'abandon ne le ressuscite pas : le
      // lancement qui l'attendait est clos.
      await paintPlaying(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(tip), findsNothing);
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

  group('La reprise : six attentes, et deux minutes', () {
    testWidgets('les six délais, et pas de septième tentative', (tester) async {
      await pumpPill(tester);
      await tapOnce(tester);
      await paintPlaying(tester);

      // Chaque échec est instantané : ce sont les six attentes qui bornent.
      await paintFailure(tester, 'Response code: 500');
      expectPhase(tester, RadioPhase.retrying);

      // ⚠️ Les six attentes sont écrites **ici, en clair**, et pas relues depuis
      // `kRadioRetryDelays` : la constante est ce qu'on éprouve. Un test qui la
      // relirait passerait au vert sur six attentes d'une seconde — mesuré, c'est
      // exactement ce qu'il a fait avant cette ligne.
      const expected = [1, 2, 4, 8, 16, 32];
      var fired = 0;
      for (final seconds in expected) {
        final delay = Duration(seconds: seconds);
        await tester.pump(delay - const Duration(milliseconds: 1));
        expect(player.resumeCount, fired, reason: 'avant $delay');
        await tester.pump(const Duration(milliseconds: 1));
        fired++;
        expect(player.resumeCount, fired, reason: 'à $delay');
        // La tentative a effacé la panne de la valeur ; l'échec suivant la
        // ramène, et c'est lui qui programme l'attente d'après.
        if (fired < expected.length) {
          await paintFailure(tester, 'Response code: 500');
          expectPhase(tester, RadioPhase.retrying);
        }
      }
      expect(fired, 6);

      // Le septième échec ne trouve plus d'attente : on renonce.
      await paintFailure(tester, 'Response code: 500');
      expectPhase(tester, RadioPhase.failed, failure: RadioFailureKind.antenna);
      expect(dimmed(tester), isTrue);
      await tester.pump(const Duration(minutes: 10));
      expect(player.resumeCount, 6, reason: 'aucune septième tentative');
    });

    testWidgets('l\'abandon tombe à deux minutes quand les échecs traînent',
        (tester) async {
      await pumpPill(tester);
      await tapOnce(tester);
      await paintPlaying(tester);

      // Chaque tentative met vingt secondes à échouer — le cas d'un réseau qui
      // fait attendre plutôt que de refuser. Les six attentes n'auront pas le
      // temps d'être consommées : c'est l'horloge qui mord.
      const slow = Duration(seconds: 20);
      await paintFailure(tester, const SocketException('Failed host lookup'));

      var elapsed = Duration.zero;
      Future<void> advance(Duration step) async {
        elapsed += step;
        await tester.pump(step);
      }

      // Quatre tentatives, chacune suivie de ses vingt secondes d'agonie : elles
      // partent à t=1, 23, 47 et 75, et le cinquième échec tombe à t=95. Les
      // attentes sont écrites en clair, pour la raison du test précédent.
      for (final seconds in const [1, 2, 4, 8]) {
        await advance(Duration(seconds: seconds));
        await advance(slow);
        await paintFailure(tester, const SocketException('Failed host lookup'));
      }
      expect(player.resumeCount, 4);
      expect(elapsed, const Duration(seconds: 95));

      // La cinquième attente est de seize secondes : la tentative part à t=111.
      await advance(const Duration(seconds: 16));
      expect(player.resumeCount, 5);
      expect(elapsed, const Duration(seconds: 111));
      expectPhase(tester, RadioPhase.retrying);

      // Encore huit secondes : on en est à 119, et le bouton essaie toujours.
      await advance(const Duration(seconds: 8));
      expect(elapsed, const Duration(seconds: 119));
      expectPhase(tester, RadioPhase.retrying);

      // La seconde suivante : deux minutes pile, et le bouton s'éteint en disant
      // pourquoi — alors qu'il restait une attente à consommer.
      await advance(const Duration(seconds: 1));
      expect(elapsed, const Duration(minutes: 2));
      expectPhase(tester, RadioPhase.failed,
          failure: RadioFailureKind.connection);
      expect(dimmed(tester), isTrue);
      expect(status(tester).phase, isNot(RadioPhase.retrying));

      await advance(const Duration(minutes: 5));
      expect(player.resumeCount, 5,
          reason: 'plus rien ne part après l\'abandon');
    });

    testWidgets('le bouton éteint par un échec repart à l\'appui',
        (tester) async {
      await pumpPill(tester);
      await tapOnce(tester);
      await paintPlaying(tester);
      await paintFailure(tester, 'Response code: 404');
      // On laisse les deux minutes s'écouler sans qu'aucune tentative n'aboutisse.
      await tester.pump(const Duration(minutes: 2));
      expectPhase(tester, RadioPhase.failed, failure: RadioFailureKind.antenna);
      expect(dimmed(tester), isTrue);

      await tapOnce(tester);

      // Un geste efface le renoncement : c'est l'auditeur qui décide de réessayer.
      expect(player.loadedUrl, kTestAntennaOnAir.streamUrl);
      expect(player.value.isPlaying, isTrue);
    });
  });

  group('Les trois phrases, selon la nature de l\'échec', () {
    testWidgets(
        'la route d\'antenne injoignable → « vérifiez votre connexion »',
        (tester) async {
      await pumpPill(
        tester,
        radio: const FailingRadioRepository(
          SocketException('Failed host lookup'),
        ),
      );

      await tapOnce(tester);
      // Aucune adresse n'a pu être lue : la rafale part sans que le lecteur ait
      // jamais rien reçu.
      expect(player.loadCount, 0);
      expectPhase(tester, RadioPhase.retrying);

      await tester.pump(const Duration(minutes: 2));
      expectPhase(tester, RadioPhase.failed,
          failure: RadioFailureKind.connection);
      expect(dimmed(tester), isTrue);
    });

    testWidgets('une antenne sans adresse → « antenne indisponible »',
        (tester) async {
      // Le serveur a répondu, et il n'a pas d'antenne à donner : ce n'est pas le
      // réseau de l'auditeur qui manque.
      await pumpPill(tester,
          radio: const FixedRadioRepository(RadioAntenna.unknown));

      await tapOnce(tester);
      expectPhase(tester, RadioPhase.retrying);

      await tester.pump(const Duration(minutes: 2));
      expectPhase(tester, RadioPhase.failed, failure: RadioFailureKind.antenna);
      expect(dimmed(tester), isTrue);
    });

    testWidgets(
        'une panne opaque du lecteur ne dit PAS « vérifiez votre connexion »',
        (tester) async {
      // **Le défaut constaté sur iPhone**, et c'est pourquoi la troisième phrase
      // existe : AVFoundation rend sa panne sans code HTTP ni nom d'exception de
      // transport, et le repli de #104 l'habillait en coupure de réseau. Le
      // téléphone était connecté, et le bouton lui disait le contraire.
      await pumpPill(tester);
      await tapOnce(tester);
      await paintFailure(
        tester,
        'PlatformException(abort, The operation could not be completed, '
        'AVFoundationErrorDomain, -11800)',
      );

      expectPhase(tester, RadioPhase.retrying);

      await tester.pump(const Duration(minutes: 2));
      expectPhase(tester, RadioPhase.failed, failure: RadioFailureKind.unknown);
      expect(dimmed(tester), isTrue);
      expect(
        status(tester).failure,
        isNot(RadioFailureKind.connection),
        reason: 'rien ne dit que le réseau de l\'auditeur soit en cause',
      );
      expect(
        status(tester).failure,
        isNot(RadioFailureKind.antenna),
        reason: 'et rien ne dit que l\'église ait cessé de diffuser',
      );
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

    testWidgets('un pré-vol sans réponse → « vérifiez votre connexion »',
        (tester) async {
      // Son échec se lit **comme les autres** : il n'a pas de voix à lui. Même
      // phrase que la route d'antenne injoignable, et c'est `classifyRadioFailure`
      // qui la choisit — pour les deux. (La troisième phrase du bouton n'est pas
      // une voix de plus pour le pré-vol : elle ne sert que les échecs dont on ne
      // sait pas s'il y a eu une réponse, et un pré-vol sait toujours le dire.)
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
      expectPhase(tester, RadioPhase.failed,
          failure: RadioFailureKind.connection);
      expect(dimmed(tester), isTrue);
    });

    testWidgets('un 401 « session not found » → « antenne indisponible »',
        (tester) async {
      // Le serveur a répondu, et il a dit non : ce n'est pas le réseau de
      // l'auditeur qui manque, et l'inviter à le vérifier l'enverrait chercher une
      // panne qui n'est pas la sienne.
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
      expectPhase(tester, RadioPhase.failed, failure: RadioFailureKind.antenna);
      expect(dimmed(tester), isTrue);
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
