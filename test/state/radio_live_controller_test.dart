/// **L'état de la page live** (#135) : ce qui le remplit, ce qui le remplace,
/// ce qui le ferme — et ce qui ne le relit jamais.
///
/// `testWidgets` et non `test` : le contrôleur s'abonne au cycle de vie de
/// l'application, et l'horloge factice du harnais est ce qui permet de prouver
/// « dix minutes passent et rien ne se relit » sans attendre dix minutes.
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/radio/radio_antenna.dart';
import 'package:maison_du_miracle/data/radio/radio_channel.dart';
import 'package:maison_du_miracle/data/radio/radio_live.dart';
import 'package:maison_du_miracle/data/radio/radio_repository.dart';
import 'package:maison_du_miracle/state/radio_live_providers.dart';
import 'package:maison_du_miracle/state/radio_providers.dart';

import '../helpers/radio_live_doubles.dart';

const _antenna = RadioAntenna(
  streamUrl: 'https://antenne.test/antenne/index.m3u8',
  onAir: true,
  listeners: 128,
);

void main() {
  late ControllableRadioChannel channel;
  late RecordingRadioLiveRepository repo;
  late ProviderContainer container;
  late ProviderSubscription<RadioLiveState> page;
  late List<RadioReactionBurst> bursts;

  /// « La page s'ouvre » : un auditeur du provider, comme l'écran.
  Future<void> openPage(
    WidgetTester tester, {
    RadioAntenna antenna = _antenna,
  }) async {
    container = ProviderContainer(
      overrides: [
        radioChannelProvider.overrideWithValue(channel),
        radioLiveRepositoryProvider.overrideWithValue(repo),
        radioRepositoryProvider
            .overrideWithValue(FixedRadioRepository(antenna)),
      ],
    );
    page = container.listen(radioLiveProvider, (_, __) {});
    bursts = [];
    container.read(radioLiveProvider.notifier).bursts.listen(bursts.add);
    await settle(tester);
  }

  /// Ferme la page, puis le conteneur : aucune minuterie ne doit survivre.
  Future<void> closePage(WidgetTester tester) async {
    page.close();
    container.dispose();
    await tester.pump();
  }

  RadioLiveState state() => container.read(radioLiveProvider);
  RadioLiveController controller() =>
      container.read(radioLiveProvider.notifier);

  setUp(() {
    channel = ControllableRadioChannel();
    repo = RecordingRadioLiveRepository();
  });

  group('L\'ouverture', () {
    testWidgets('relit l\'antenne et le fil, et s\'abonne au canal public',
        (tester) async {
      repo.threadValue = RadioThread(
        live: kTestLive,
        comments: [testComment('c-1', 'Amen !')],
        viewer: const RadioViewer(canComment: true),
      );
      await openPage(tester);

      expect(repo.threadReads, 1);
      expect(channel.watches, [false]);
      expect(state().listeners, 128);
      expect(state().isLive, isTrue);
      expect(state().comments.single.body, 'Amen !');
      await closePage(tester);
    });

    testWidgets('hors direct, compteur absent : rien à afficher, jamais zéro',
        (tester) async {
      await openPage(
        tester,
        antenna: const RadioAntenna(streamUrl: 'x', onAir: true),
      );
      expect(state().listeners, isNull);
      expect(state().isLive, isFalse);
      expect(state().comments, isEmpty);
      expect(state().offersComposer, isFalse);
      await closePage(tester);
    });
  });

  group('La reconnexion relit, et remplace', () {
    testWidgets(
        'chaque ouverture du canal relit le fil et remplace l\'affichage',
        (tester) async {
      repo.threadValue = RadioThread(
        live: kTestLive,
        comments: [testComment('c-1', 'Avant la coupure')],
      );
      await openPage(tester);
      channel.open();
      await settle(tester);
      expect(repo.threadReads, 2);

      // Pendant la coupure, un message est masqué et deux autres arrivent :
      // aucun événement ne nous le dira.
      await channel.drop();
      await settle(tester);
      expect(state().connected, isFalse);
      repo.threadValue = RadioThread(
        live: kTestLive,
        comments: [
          testComment('c-2', 'Pendant'),
          testComment('c-3', 'la coupure'),
        ],
      );

      await tester.pump(kRadioChannelRetryDelay);
      expect(channel.watches, hasLength(2), reason: 'le canal est rouvert');
      expect(repo.threadReads, 2, reason: 'une réouverture ne relit rien');

      channel.open();
      await settle(tester);
      expect(repo.threadReads, 3);
      expect(state().connected, isTrue);
      expect(state().comments.map((c) => c.id), ['c-2', 'c-3']);
      await closePage(tester);
    });

    testWidgets('un refus ne se réessaie jamais', (tester) async {
      await openPage(tester);
      channel.refuse();
      await settle(tester);
      await tester.pump(const Duration(minutes: 2));
      expect(channel.watches, hasLength(1));
      await closePage(tester);
    });

    testWidgets('le retour d\'arrière-plan relit, puis rouvre', (tester) async {
      await openPage(tester);
      channel.open();
      await settle(tester);
      final reads = repo.threadReads;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await settle(tester);
      expect(channel.isOpen, isFalse, reason: 'l\'arrière-plan ferme');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      expect(repo.threadReads, reads + 1);
      expect(channel.watches, hasLength(2));
      await closePage(tester);
    });
  });

  group('Jamais de sondage', () {
    testWidgets('dix minutes sans événement : une seule lecture, une connexion',
        (tester) async {
      await openPage(tester);
      channel.open();
      await settle(tester);
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(seconds: 10));
      }
      expect(repo.threadReads, 2,
          reason: 'ouverture + connexion, rien de plus');
      expect(channel.watches, hasLength(1));
      await closePage(tester);
    });

    test('garde-fou de source : aucune horloge périodique dans la page live',
        () {
      // Un `Timer.periodic` « pour être sûr » ne casserait aucun test de
      // comportement — il relirait le fil d'un téléphone sur une connexion
      // facturée pour apprendre qu'il n'y a rien de neuf.
      final sources = [
        'lib/state/radio_live_providers.dart',
        'lib/data/radio/radio_channel.dart',
        'lib/data/radio/sse_radio_channel.dart',
        'lib/data/radio/radio_live_repository.dart',
        'lib/data/radio/http_radio_live_repository.dart',
        'lib/screens/radio_screen.dart',
        ...Directory('lib/widgets/radio_live')
            .listSync()
            .whereType<File>()
            .map((f) => f.path),
      ];
      for (final path in sources) {
        final code = File(path)
            .readAsLinesSync()
            .where((line) => !line.trimLeft().startsWith('//'))
            .join('\n');
        for (final interdit in ['Timer.periodic', 'Stream.periodic']) {
          expect(code, isNot(contains(interdit)),
              reason: '$path introduit une horloge périodique : la page live '
                  'se relit à la connexion, jamais sur un battement');
        }
      }
    });
  });

  group('Les événements du canal', () {
    testWidgets('compteur, début et fin du direct', (tester) async {
      await openPage(tester);
      channel.open();
      await settle(tester);

      channel.emit(const RadioListenersChanged(null));
      await settle(tester);
      expect(state().listeners, isNull);

      repo.threadValue = RadioThread(
        live: kTestLive,
        viewer: const RadioViewer(canComment: true),
      );
      channel.emit(RadioLiveChanged(live: kTestLive, listeners: 40));
      await settle(tester);
      expect(state().isLive, isTrue);
      expect(state().listeners, 40);
      expect(state().viewer.canComment, isTrue, reason: 'le viewer est relu');

      channel.emit(RadioCommentPosted(testComment('c-1', 'Amen')));
      await settle(tester);
      expect(state().comments, hasLength(1));

      channel.emit(const RadioLiveChanged(live: null, listeners: 12));
      await settle(tester);
      expect(state().isLive, isFalse);
      expect(state().comments, isEmpty, reason: 'fin du direct : fil fermé');
      await closePage(tester);
    });

    testWidgets('un message arrive une fois, et le fil garde les 50 derniers',
        (tester) async {
      repo.threadValue = RadioThread(live: kTestLive);
      await openPage(tester);
      for (var i = 0; i < 55; i++) {
        channel.emit(RadioCommentPosted(testComment('c-$i', 'n°$i')));
      }
      channel.emit(RadioCommentPosted(testComment('c-54', 'n°54')));
      await settle(tester);
      expect(state().comments, hasLength(kRadioCommentWindow));
      expect(state().comments.first.id, 'c-5');
      expect(state().comments.last.id, 'c-54');
      await closePage(tester);
    });

    testWidgets('comment.hidden retire le message', (tester) async {
      repo.threadValue = RadioThread(
        live: kTestLive,
        comments: [testComment('c-1', 'Un'), testComment('c-2', 'Deux')],
      );
      await openPage(tester);
      channel.emit(const RadioCommentHidden('c-1'));
      await settle(tester);
      expect(state().comments.map((c) => c.id), ['c-2']);
      await closePage(tester);
    });
  });

  group('Les réactions', () {
    testWidgets('la mienne monte tout de suite, et ne monte pas deux fois',
        (tester) async {
      await openPage(tester);
      controller().react(RadioReaction.heart);
      expect(bursts.single.own, isTrue, reason: 'avant toute réponse');
      await settle(tester);
      expect(repo.reactions, [RadioReaction.heart]);

      // L'agrégat de la seconde suivante compte la mienne : trois cœurs, dont
      // un à moi — deux seulement montent.
      channel.emit(const RadioReactionsAggregated({
        RadioReaction.heart: 3,
        RadioReaction.pray: 0,
        RadioReaction.praise: 0,
        RadioReaction.fire: 0,
        RadioReaction.amen: 0,
      }));
      await settle(tester);
      expect(bursts.last.own, isFalse);
      expect(bursts.last.count, 2);
      await closePage(tester);
    });

    testWidgets(
        'une audience nombreuse fait monter une poignée, pas trois cents',
        (tester) async {
      await openPage(tester);
      channel.emit(const RadioReactionsAggregated({
        RadioReaction.heart: 300,
        RadioReaction.pray: 0,
        RadioReaction.praise: 0,
        RadioReaction.fire: 0,
        RadioReaction.amen: 2,
      }));
      await settle(tester);
      expect(bursts.map((b) => (b.reaction, b.count)), [
        (RadioReaction.heart, kRadioReactionBurstCap),
        (RadioReaction.amen, 2),
      ]);
      await closePage(tester);
    });

    testWidgets(
        '429 silencieux : rien ne lève, et la mienne n\'est plus attendue',
        (tester) async {
      repo.reactionError = kThrottled;
      await openPage(tester);
      controller().react(RadioReaction.fire);
      await settle(tester);
      channel.emit(const RadioReactionsAggregated({
        RadioReaction.heart: 0,
        RadioReaction.pray: 0,
        RadioReaction.praise: 0,
        RadioReaction.fire: 1,
        RadioReaction.amen: 0,
      }));
      await settle(tester);
      // Le 🔥 de l'agrégat est celui de quelqu'un d'autre : il monte.
      expect(bursts.where((b) => !b.own).single.count, 1);
      await closePage(tester);
    });
  });

  group('Les commentaires', () {
    testWidgets('envoyé : il paraît une fois, même revenu par le canal',
        (tester) async {
      repo.threadValue = RadioThread(live: kTestLive);
      await openPage(tester);
      expect(await controller().send('  Amen  '), RadioSendOutcome.sent);
      expect(repo.posted, ['Amen']);
      channel.emit(RadioCommentPosted(state().comments.single));
      await settle(tester);
      expect(state().comments, hasLength(1));
      await closePage(tester);
    });

    testWidgets('les refus, chacun à sa place', (tester) async {
      repo.threadValue = RadioThread(live: kTestLive);
      await openPage(tester);

      repo.postResults.add(kPseudonymRequired);
      expect(await controller().send('x'), RadioSendOutcome.pseudonymRequired);

      repo.postResults.add(kThrottled);
      expect(await controller().send('x'), RadioSendOutcome.throttled);

      repo.postResults.add(kSilenced);
      expect(await controller().send('x'), RadioSendOutcome.silenced);
      expect(state().viewer.silenced, isTrue);
      expect(state().offersComposer, isFalse);

      repo.postResults.add(kClosed);
      expect(await controller().send('x'), RadioSendOutcome.closed);
      expect(state().isLive, isFalse, reason: 'le serveur dit : pas de direct');
      await closePage(tester);
    });

    testWidgets('vide ou trop long : refusé sans aller-retour', (tester) async {
      await openPage(tester);
      expect(await controller().send('   '), RadioSendOutcome.invalid);
      expect(await controller().send('a' * 201), RadioSendOutcome.invalid);
      expect(repo.posted, isEmpty);
      await closePage(tester);
    });

    testWidgets('le pseudo : 2 à 24 caractères, puis retenu', (tester) async {
      await openPage(tester);
      expect(
          await controller().savePseudonym('K'), RadioPseudonymOutcome.invalid);
      expect(repo.pseudonyms, isEmpty);
      expect(await controller().savePseudonym(' Kossi '),
          RadioPseudonymOutcome.saved);
      expect(repo.pseudonyms, ['Kossi']);
      expect(state().viewer.pseudonym, 'Kossi');
      await closePage(tester);
    });
  });

  group('La modération', () {
    testWidgets('un modérateur s\'abonne au canal privé et lit sa file',
        (tester) async {
      repo
        ..threadValue = RadioThread(
          live: kTestLive,
          comments: [testComment('c-1', 'Signalé')],
          viewer: const RadioViewer(moderator: true),
        )
        ..queue = RadioModerationQueue(
          live: kTestLive,
          items: [
            RadioReportedComment(
              comment: testComment('c-1', 'Signalé'),
              pendingReports: 2,
            ),
          ],
        );
      await openPage(tester);
      expect(channel.watches, [false, true],
          reason: 'rouvert avec le canal privé, une fois le rôle connu');
      expect(state().reported, hasLength(1));

      final reads = repo.queueReads;
      channel.emit(const RadioModerationChanged(commentId: 'c-1'));
      await settle(tester);
      expect(repo.queueReads, reads + 1,
          reason: 'un signalement relit la file');

      channel.emit(
        const RadioModerationChanged(commentId: 'c-1', outcome: 'kept'),
      );
      await settle(tester);
      expect(state().reported, isEmpty,
          reason: 'une décision retire sans relire');
      expect(repo.queueReads, reads + 1);
      await closePage(tester);
    });

    testWidgets('masquer retire du fil et de la file', (tester) async {
      repo
        ..threadValue = RadioThread(
          live: kTestLive,
          comments: [testComment('c-1', 'Un'), testComment('c-2', 'Deux')],
          viewer: const RadioViewer(moderator: true),
        )
        ..queue = RadioModerationQueue(items: [
          RadioReportedComment(
            comment: testComment('c-1', 'Un'),
            pendingReports: 1,
          ),
        ]);
      await openPage(tester);
      expect(await controller().hide('c-1'), RadioModerationOutcome.done);
      expect(repo.moderation, ['hide:c-1']);
      expect(state().comments.map((c) => c.id), ['c-2']);
      expect(state().reported, isEmpty);
      await closePage(tester);
    });

    testWidgets('un auditeur ordinaire n\'ouvre jamais le canal privé',
        (tester) async {
      repo.threadValue = RadioThread(
        live: kTestLive,
        viewer: const RadioViewer(kind: RadioAuthorKind.guest),
      );
      await openPage(tester);
      channel.open();
      await settle(tester);
      expect(channel.watches, [false]);
      expect(repo.queueReads, 0);
      await closePage(tester);
    });
  });

  testWidgets('quitter la page rend la socket, et rien ne se rouvre',
      (tester) async {
    await openPage(tester);
    channel.open();
    await settle(tester);

    page.close();
    await settle(tester);
    expect(channel.cancels, 1);
    expect(channel.isOpen, isFalse);

    await tester.pump(const Duration(minutes: 1));
    expect(channel.watches, hasLength(1));
    container.dispose();
  });
}

/// Laisse passer les microtâches et les réponses des doubles.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}
