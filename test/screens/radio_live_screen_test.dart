/// **La page radio plein écran, façon live** (#135) — ce qu'elle montre selon
/// le direct et le compteur, ce que font ses gestes, et quand elle écoute le
/// canal.
///
/// L'écoute elle-même (pré-vol, cookie, reprise, causes) est jugée par
/// `radio_screen_test.dart`, qui monte le **même** écran : la page live n'a
/// changé que la présentation, et ces tests-là doivent rester verts sans y
/// toucher.
///
/// ⚠️ **Jamais `pumpAndSettle`** : le gros bouton tourne en attente, et les
/// réactions montent sur une horloge.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maison_du_miracle/data/radio/radio_antenna.dart';
import 'package:maison_du_miracle/data/radio/radio_channel.dart';
import 'package:maison_du_miracle/data/radio/radio_live.dart';
import 'package:maison_du_miracle/data/radio/radio_repository.dart';
import 'package:maison_du_miracle/router/app_router.dart';
import 'package:maison_du_miracle/screens/radio_screen.dart';
import 'package:maison_du_miracle/widgets/content_player_view.dart';
import 'package:maison_du_miracle/widgets/radio_live/radio_comment_feed.dart';
import 'package:maison_du_miracle/widgets/radio_live/radio_live_scene.dart';
import 'package:maison_du_miracle/widgets/radio_live/radio_live_sheets.dart';
import 'package:maison_du_miracle/widgets/radio_live/radio_reaction_particles.dart';

import '../helpers/pump_screen.dart';
import '../helpers/radio_live_doubles.dart';

const _url = 'https://antenne.test/antenne/index.m3u8';
const _offAirNoCounter = RadioAntenna(streamUrl: _url, onAir: true);
const _offAirCounter =
    RadioAntenna(streamUrl: _url, onAir: true, listeners: 128);
final _live = RadioAntenna(
  streamUrl: _url,
  onAir: true,
  listeners: 128,
  live: kTestLive,
);

void main() {
  late ControllableRadioChannel channel;
  late RecordingRadioLiveRepository repo;

  setUp(() {
    channel = ControllableRadioChannel();
    repo = RecordingRadioLiveRepository();
  });

  /// Un téléphone, pas la surface 800 × 600 du harnais.
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> pumpLive(
    WidgetTester tester, {
    RadioAntenna antenna = _offAirNoCounter,
    Widget screen = const RadioScreen(),
  }) async {
    phone(tester);
    await pumpScreen(
      tester,
      screen,
      radio: FixedRadioRepository(antenna),
      radioChannel: channel,
      radioLive: repo,
    );
    await settle(tester);
  }

  Finder particle(String glyph) => find.descendant(
        of: find.byType(RadioReactionParticles),
        matching: find.text(glyph),
      );

  group('Deux intensités (décision 2)', () {
    testWidgets('hors direct, sans compteur : réactions seulement',
        (tester) async {
      await pumpLive(tester);
      expect(find.byKey(RadioLiveScene.liveBadgeKey), findsNothing);
      expect(find.byKey(RadioLiveScene.listenersKey), findsNothing);
      expect(find.byType(RadioCommentFeed), findsNothing);
      expect(find.byKey(RadioLiveScene.composerKey), findsNothing);
      for (final reaction in RadioReaction.values) {
        expect(
            find.byKey(RadioLiveScene.reactionKey(reaction)), findsOneWidget);
      }
      expect(find.byKey(ContentPlayerView.playButtonKey), findsOneWidget);
      expect(find.text('New Life Radio'), findsOneWidget);
    });

    testWidgets('hors direct, avec compteur : le chiffre, et pas de badge',
        (tester) async {
      await pumpLive(tester, antenna: _offAirCounter);
      expect(find.byKey(RadioLiveScene.listenersKey), findsOneWidget);
      expect(find.text('128'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(RadioLiveScene.listenersKey)),
        isSemantics(label: '128 à l\'écoute'),
      );
      expect(find.byKey(RadioLiveScene.liveBadgeKey), findsNothing);
      expect(find.byKey(RadioLiveScene.composerKey), findsNothing);
    });

    testWidgets('en direct : badge, fil et champ en plus', (tester) async {
      repo.threadValue = RadioThread(
        live: kTestLive,
        comments: [
          testComment('c-1', 'Amen !'),
          testComment('c-2', 'gloire à Dieu',
              name: 'Kossi', kind: RadioAuthorKind.guest),
        ],
        viewer: const RadioViewer(canComment: true),
      );
      await pumpLive(tester, antenna: _live);
      expect(find.byKey(RadioLiveScene.liveBadgeKey), findsOneWidget);
      expect(find.text('EN DIRECT'), findsOneWidget);
      expect(find.byType(RadioCommentFeed), findsOneWidget);
      expect(find.textContaining('Amen !', findRichText: true), findsOneWidget);
      expect(find.textContaining('gloire à Dieu', findRichText: true),
          findsOneWidget);
      expect(find.byKey(RadioLiveScene.composerKey), findsOneWidget);
    });

    testWidgets('la fin du direct ferme le fil sous les yeux', (tester) async {
      repo.threadValue = RadioThread(
        live: kTestLive,
        comments: [testComment('c-1', 'Amen !')],
      );
      await pumpLive(tester, antenna: _live);
      channel.emit(const RadioLiveChanged(live: null, listeners: 90));
      await settle(tester);
      expect(find.byKey(RadioLiveScene.liveBadgeKey), findsNothing);
      expect(find.byType(RadioCommentFeed), findsNothing);
      expect(find.byKey(RadioLiveScene.composerKey), findsNothing);
      expect(find.text('90'), findsOneWidget);
    });
  });

  group('Les réactions', () {
    testWidgets('un appui : elle monte tout de suite, et part au serveur',
        (tester) async {
      await pumpLive(tester);
      await tester
          .tap(find.byKey(RadioLiveScene.reactionKey(RadioReaction.heart)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(particle('❤️'), findsOneWidget);
      expect(repo.reactions, [RadioReaction.heart]);

      // Elle sort de l'écran, et l'horloge s'arrête avec elle.
      await tester.pump(kRadioParticleLife);
      await tester.pump(const Duration(milliseconds: 100));
      expect(particle('❤️'), findsNothing);
    });

    testWidgets('les réactions de l\'audience montent aussi, bornées',
        (tester) async {
      await pumpLive(tester);
      channel.open();
      await settle(tester);
      for (var i = 0; i < 6; i++) {
        channel.emit(const RadioReactionsAggregated({
          RadioReaction.heart: 500,
          RadioReaction.pray: 500,
          RadioReaction.praise: 500,
          RadioReaction.fire: 500,
          RadioReaction.amen: 500,
        }));
      }
      await tester.pump(const Duration(seconds: 1));
      final shown = find
          .descendant(
            of: find.byType(RadioReactionParticles),
            matching: find.byType(Opacity),
          )
          .evaluate()
          .length;
      expect(shown, greaterThan(0));
      expect(shown, lessThanOrEqualTo(kRadioMaxParticles));
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('animations réduites : rien ne monte, l\'envoi part quand même',
        (tester) async {
      await pumpLive(
        tester,
        screen: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const RadioScreen(),
          ),
        ),
      );
      await tester
          .tap(find.byKey(RadioLiveScene.reactionKey(RadioReaction.pray)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(particle('🙏'), findsNothing);
      expect(repo.reactions, [RadioReaction.pray]);
    });

    testWidgets('chaque bouton porte un libellé pour le lecteur d\'écran',
        (tester) async {
      await pumpLive(tester);
      expect(
        tester.getSemantics(
            find.byKey(RadioLiveScene.reactionKey(RadioReaction.amen))),
        isSemantics(label: 'Dire Amen', isButton: true),
      );
    });
  });

  group('Écrire pendant le direct', () {
    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byKey(RadioLiveScene.composerKey), text);
      await tester.tap(find.byKey(RadioLiveScene.sendKey));
      await settle(tester);
    }

    testWidgets(
        'un invité sans pseudo : la feuille, puis le message repart tout seul',
        (tester) async {
      repo
        ..threadValue = RadioThread(
          live: kTestLive,
          viewer: const RadioViewer(kind: RadioAuthorKind.guest),
        )
        ..postResults.add(kPseudonymRequired);
      await pumpLive(tester, antenna: _live);

      await type(tester, 'Amen !');
      expect(find.text('Choisissez un pseudo'), findsOneWidget);
      expect(repo.posted, ['Amen !']);

      await tester.enterText(find.byKey(RadioPseudonymSheet.fieldKey), 'Kossi');
      await tester.tap(find.byKey(RadioPseudonymSheet.confirmKey));
      await settle(tester);
      await tester.pump(const Duration(seconds: 1)); // la feuille se replie

      expect(repo.pseudonyms, ['Kossi']);
      expect(repo.posted, ['Amen !', 'Amen !'], reason: 'renvoyé sans geste');
      expect(find.text('Choisissez un pseudo'), findsNothing);
      expect(find.textContaining('Amen !', findRichText: true), findsOneWidget);
      final field =
          tester.widget<TextField>(find.byKey(RadioLiveScene.composerKey));
      expect(field.controller!.text, isEmpty);

      // Les fois suivantes, il écrit directement : le serveur se souvient.
      await type(tester, 'Gloire');
      expect(find.text('Choisissez un pseudo'), findsNothing);
      expect(repo.posted.last, 'Gloire');
      expect(repo.pseudonyms, ['Kossi']);
    });

    testWidgets('un pseudo trop court est refusé dans la feuille',
        (tester) async {
      repo
        ..threadValue = RadioThread(
          live: kTestLive,
          viewer: const RadioViewer(kind: RadioAuthorKind.guest),
        )
        ..postResults.add(kPseudonymRequired);
      await pumpLive(tester, antenna: _live);
      await type(tester, 'Amen');
      await tester.enterText(find.byKey(RadioPseudonymSheet.fieldKey), 'K');
      await tester.tap(find.byKey(RadioPseudonymSheet.confirmKey));
      await settle(tester);
      expect(find.text('Entre 2 et 24 caractères.'), findsOneWidget);
      expect(repo.pseudonyms, isEmpty);
      expect(repo.posted, ['Amen'], reason: 'rien ne repart sans pseudo');
    });

    testWidgets('429 : une phrase claire, le texte reste', (tester) async {
      repo
        ..threadValue = RadioThread(live: kTestLive)
        ..postResults.add(kThrottled);
      await pumpLive(tester, antenna: _live);
      await type(tester, 'Vite');
      expect(find.text('Doucement : un message toutes les cinq secondes.'),
          findsOneWidget);
      final field =
          tester.widget<TextField>(find.byKey(RadioLiveScene.composerKey));
      expect(field.controller!.text, 'Vite');
    });

    testWidgets('403 silence : la phrase, puis le champ cède la place',
        (tester) async {
      repo
        ..threadValue = RadioThread(live: kTestLive)
        ..postResults.add(kSilenced);
      await pumpLive(tester, antenna: _live);
      await type(tester, 'Encore');
      expect(find.byKey(RadioLiveScene.composerKey), findsNothing);
      expect(find.byKey(RadioLiveScene.silencedKey), findsOneWidget);
    });

    testWidgets('409 fermé : le direct est fini, le fil part', (tester) async {
      repo
        ..threadValue = RadioThread(live: kTestLive)
        ..postResults.add(kClosed);
      await pumpLive(tester, antenna: _live);
      await type(tester, 'Trop tard');
      expect(find.text('Le direct est terminé : les commentaires sont fermés.'),
          findsOneWidget);
      expect(find.byKey(RadioLiveScene.composerKey), findsNothing);
      expect(find.byType(RadioCommentFeed), findsNothing);
    });
  });

  group('Le fil et sa modération', () {
    final thread = RadioThread(
      live: kTestLive,
      comments: [
        testComment('c-1', 'Message limite',
            name: 'Kossi', kind: RadioAuthorKind.guest),
      ],
      viewer: const RadioViewer(canComment: true),
    );

    testWidgets('comment.hidden retire le message de l\'écran', (tester) async {
      repo.threadValue = thread;
      await pumpLive(tester, antenna: _live);
      expect(find.textContaining('Message limite', findRichText: true),
          findsOneWidget);
      channel.emit(const RadioCommentHidden('c-1'));
      await settle(tester);
      expect(find.textContaining('Message limite', findRichText: true),
          findsNothing);
    });

    testWidgets('un auditeur : signaler, et aucun outil de modération',
        (tester) async {
      repo.threadValue = thread;
      await pumpLive(tester, antenna: _live);
      expect(find.byKey(RadioLiveScene.reportedQueueKey), findsNothing);

      await tester.longPress(find.byKey(RadioCommentFeed.messageKey('c-1')));
      await settle(tester);
      expect(find.byKey(RadioMessageActionKeys.report), findsOneWidget);
      expect(find.byKey(RadioMessageActionKeys.hide), findsNothing);
      expect(find.byKey(RadioMessageActionKeys.silence), findsNothing);
      expect(find.byKey(RadioMessageActionKeys.resetPseudonym), findsNothing);

      await tester.tap(find.byKey(RadioMessageActionKeys.report));
      await settle(tester);
      expect(repo.reports, ['c-1']);
      expect(find.text('Merci, un modérateur va le regarder.'), findsOneWidget);
      // Signalé, il reste visible jusqu'à la décision d'un modérateur.
      expect(find.textContaining('Message limite', findRichText: true),
          findsOneWidget);
    });

    testWidgets('un modérateur : les trois gestes, et la file signalée',
        (tester) async {
      repo
        ..threadValue = RadioThread(
          live: kTestLive,
          comments: thread.comments,
          viewer: const RadioViewer(moderator: true, canComment: true),
        )
        ..queue = RadioModerationQueue(
          live: kTestLive,
          items: [
            RadioReportedComment(
                comment: thread.comments.single, pendingReports: 2),
          ],
        );
      await pumpLive(tester, antenna: _live);

      expect(find.byKey(RadioLiveScene.reportedQueueKey), findsOneWidget);
      await tester.longPress(find.byKey(RadioCommentFeed.messageKey('c-1')));
      await settle(tester);
      expect(find.byKey(RadioMessageActionKeys.hide), findsOneWidget);
      expect(find.byKey(RadioMessageActionKeys.silence), findsOneWidget);
      expect(find.byKey(RadioMessageActionKeys.resetPseudonym), findsOneWidget);

      await tester.tap(find.byKey(RadioMessageActionKeys.hide));
      await settle(tester);
      expect(repo.moderation, ['hide:c-1']);
      expect(find.textContaining('Message limite', findRichText: true),
          findsNothing);
    });

    testWidgets('la file : garder retire l\'entrée, le message reste au fil',
        (tester) async {
      repo
        ..threadValue = RadioThread(
          live: kTestLive,
          comments: thread.comments,
          viewer: const RadioViewer(moderator: true),
        )
        ..queue = RadioModerationQueue(
          items: [
            RadioReportedComment(
                comment: thread.comments.single, pendingReports: 2),
          ],
        );
      await pumpLive(tester, antenna: _live);
      await tester.tap(find.byKey(RadioLiveScene.reportedQueueKey));
      await settle(tester);
      expect(find.text('2 signalements'), findsOneWidget);

      await tester.tap(find.byKey(RadioMessageActionKeys.keep));
      await settle(tester);
      expect(repo.moderation, ['keep:c-1']);
      expect(find.text('Aucun message en attente.'), findsOneWidget);
    });
  });

  group('Le canal suit la page', () {
    testWidgets('ouvert en entrant, rendu en sortant', (tester) async {
      phone(tester);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('accueil')),
          ),
          GoRoute(
            name: AppRoute.radio,
            path: '/radio',
            builder: (_, __) => const RadioScreen(),
          ),
        ],
      );
      await pumpRouter(
        tester,
        router,
        radio: const FixedRadioRepository(_offAirCounter),
        radioChannel: channel,
        radioLive: repo,
      );
      expect(channel.watches, isEmpty,
          reason: 'aucun abonnement hors de la page');

      router.pushNamed(AppRoute.radio);
      await settle(tester);
      expect(channel.watches, [false]);
      expect(channel.isOpen, isTrue);

      router.pop();
      await settle(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(channel.isOpen, isFalse, reason: 'la socket part avec la page');
      expect(channel.cancels, 1);

      await tester.pump(const Duration(minutes: 1));
      expect(channel.watches, [false], reason: 'rien ne se rouvre après coup');
    });

    testWidgets('chaque reconnexion relit, et remplace ce qui est affiché',
        (tester) async {
      repo.threadValue = RadioThread(
        live: kTestLive,
        comments: [testComment('c-1', 'Avant la coupure')],
      );
      await pumpLive(tester, antenna: _live);
      final reads = repo.threadReads;

      await channel.drop();
      repo.threadValue = RadioThread(
        live: kTestLive,
        comments: [testComment('c-9', 'Après la coupure')],
      );
      await tester.pump(const Duration(seconds: 10));
      channel.open();
      await settle(tester);

      expect(repo.threadReads, reads + 1);
      expect(find.textContaining('Avant la coupure', findRichText: true),
          findsNothing);
      expect(find.textContaining('Après la coupure', findRichText: true),
          findsOneWidget);
    });
  });

  testWidgets('le gros bouton et l\'arrêt sont nommés', (tester) async {
    await pumpLive(tester);
    expect(find.byKey(ContentPlayerView.stopButtonKey), findsOneWidget);
    expect(find.bySemanticsLabel('Arrêter l\'écoute'), findsOneWidget);
  });
}
