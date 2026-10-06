import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/messaging/group_read_advancer.dart';
import 'package:maison_du_miracle/data/push/conversation_notification.dart';
import 'package:maison_du_miracle/data/push/notification_action_handler.dart';
import 'package:maison_du_miracle/data/push/push_background.dart';
import 'package:maison_du_miracle/data/push/push_wake_handler.dart';
import 'package:maison_du_miracle/data/repositories/group_message_sender.dart';
import 'package:maison_du_miracle/data/sync/synced_collection.dart';

import '../../data/local/local_database_fixtures.dart';
import '../../helpers/sync_fixtures.dart';
import 'notification_doubles.dart';

/// **Les deux actions d'une notification de message** (M5) — « Répondre » et
/// « Marquer comme lu » —, montées par le **câblage du fond**
/// (`notificationActionHandlerFor`, celui que l'isolate du greffon appelle) sur
/// un magasin en mémoire, avec des doubles du réseau. Seul l'isolate est absent.
void main() {
  const msg1 = '019a3000-0000-7000-8000-00000000msg1';

  late AppDatabase db;
  late _RecordingSender sender;
  late _RecordingReadSender reads;
  late RecordingNotifier notifier;
  late List<Set<String>> pulls;

  Future<void> seed() async {
    Future<void> apply(String key, List<Map<String, Object?>> rows) =>
        syncedCollectionFor(key)!.applyLive(db.syncDao, rows);

    await apply(SyncCollectionKey.profiles, [
      myProfilePayload,
      peerProfilePayload,
    ]);
    await apply(SyncCollectionKey.groups, [myGroupPayload]);
    await apply(SyncCollectionKey.groupMembers, [
      myMembershipPayload,
      peerMembershipPayload,
    ]);
    await apply(SyncCollectionKey.groupMessages, [memberMessagePayload]);
  }

  NotificationActionHandler handler() => notificationActionHandlerFor(
        db,
        store: StoreWakeStore(
          groups: db.groupDao,
          showPreview: () async => true,
          userId: () => kMeId,
        ),
        sender: sender,
        readSender: reads,
        notifier: notifier,
        texts: kTestNotificationTexts,
        synchronize: (collections) async => pulls.add(collections),
      );

  setUp(() async {
    db = openTestDatabase();
    sender = _RecordingSender();
    reads = _RecordingReadSender();
    notifier = RecordingNotifier();
    pulls = [];
    await seed();
  });

  tearDown(() => db.close());

  group('Lire une réponse du greffon', () {
    test('« Répondre » porte la conversation et le texte saisi', () {
      expect(
        readNotificationAction(
          actionId: kReplyActionId,
          payload: kGroupId,
          input: '  Amen, j\'arrive  ',
        ),
        const ReplyAction(kGroupId, 'Amen, j\'arrive'),
      );
    });

    test('« Marquer comme lu » porte la conversation', () {
      expect(
        readNotificationAction(actionId: kMarkReadActionId, payload: kGroupId),
        const MarkReadAction(kGroupId),
      );
    });

    test('un tap, une réponse vide, une action inconnue : rien', () {
      expect(readNotificationAction(payload: kGroupId), isNull);
      expect(
        readNotificationAction(
          actionId: kReplyActionId,
          payload: kGroupId,
          input: '   ',
        ),
        isNull,
      );
      expect(
        readNotificationAction(actionId: 'archive', payload: kGroupId),
        isNull,
      );
      expect(readNotificationAction(actionId: kMarkReadActionId), isNull);
    });
  });

  group('Répondre depuis la notification', () {
    test('part par le composeur : une clé client, un écho, puis la synchro',
        () async {
      await handler().handle(const ReplyAction(kGroupId, 'Amen, j\'y serai'));

      // **Le même chemin que la barre de saisie** : une clé d'idempotence
      // frappée avant l'envoi, et la même dans l'écho local.
      final sent = sender.calls.single;
      expect(sent.groupId, kGroupId);
      expect(sent.body, 'Amen, j\'y serai');
      expect(sent.clientMessageId, isNotEmpty);
      final echo = await db.groupDao.pendingById(sent.clientMessageId);
      expect(echo, isNotNull);
      expect(echo!.body, 'Amen, j\'y serai');
      expect(echo.failed, isFalse);

      // La resynchronisation est **ciblée** : le fil et la lecture.
      expect(pulls.single, {
        SyncCollectionKey.groupReads,
        SyncCollectionKey.groupMessages,
      });
    });

    test('répondre marque aussi la conversation lue', () async {
      await handler().handle(const ReplyAction(kGroupId, 'Amen'));

      expect(reads.calls.single, (groupId: kGroupId, messageId: msg1));
    });

    test('un envoi qui échoue laisse un écho « pas parti », sans doublon',
        () async {
      sender.succeeds = false;

      await handler().handle(const ReplyAction(kGroupId, 'Amen'));

      // L'écho reste, marqué : le renvoi automatique du premier plan le
      // reposte sous la **même** clé au prochain cycle réussi (#140).
      final echoes = await db.select(db.pendingGroupMessages).get();
      expect(echoes, hasLength(1));
      expect(echoes.single.failed, isTrue);
      expect(
          echoes.single.clientMessageId, sender.calls.single.clientMessageId);
    });

    test('la notification s\'efface', () async {
      await handler().handle(const ReplyAction(kGroupId, 'Amen'));

      expect(notifier.cancelled, contains(kGroupId));
    });
  });

  group('Marquer comme lu depuis la notification', () {
    test('avance la lecture jusqu\'au dernier message, par l\'outbox',
        () async {
      await handler().handle(const MarkReadAction(kGroupId));

      expect(reads.calls.single, (groupId: kGroupId, messageId: msg1));
      // Confirmée : la ligne servie est rangée, l'outbox vidée.
      expect((await db.groupDao.readOf(kGroupId))?.lastReadMessageId, msg1);
      expect(await db.groupDao.pendingReads(), isEmpty);
      expect(await db.groupDao.unreadCountOf(kGroupId, kMeId), 0);
    });

    test('la notification et le résumé s\'effacent', () async {
      await handler().handle(const MarkReadAction(kGroupId));

      expect(notifier.cancelled, contains(kGroupId));
      expect(notifier.summaries, isEmpty);
      expect(notifier.summaryCancelled, isPositive);
    });

    test('injoignable : la lecture reste dans l\'outbox, à rejouer', () async {
      reads.reachable = false;

      await handler().handle(const MarkReadAction(kGroupId));

      final pending = await db.groupDao.pendingReads();
      expect(pending.single.messageId, msg1);
      // La pastille s'éteint sans attendre le réseau.
      expect(await db.groupDao.unreadCountOf(kGroupId, kMeId), 0);
    });

    test('rejouer le geste renvoie la même position (la route est idempotente)',
        () async {
      await handler().handle(const MarkReadAction(kGroupId));
      await handler().handle(const MarkReadAction(kGroupId));

      // La même position, deux fois : la route ne recule jamais et n'écrit rien
      // la seconde fois (contrat M1a §2) — rejouer est sûr (piège 5).
      expect(reads.calls.map((c) => c.messageId), [msg1, msg1]);
      expect((await db.groupDao.readOf(kGroupId))?.lastReadMessageId, msg1);
    });
  });
}

class _RecordingSender implements GroupMessageSender {
  final List<({String groupId, String body, String clientMessageId})> calls =
      [];
  bool succeeds = true;

  @override
  Future<bool> send({
    required String groupId,
    required String body,
    required String clientMessageId,
    required DateTime clientCreatedAt,
    String? replyToMessageId,
  }) async {
    calls.add(
      (groupId: groupId, body: body, clientMessageId: clientMessageId),
    );
    return succeeds;
  }
}

class _RecordingReadSender implements GroupReadSender {
  final List<({String groupId, String messageId})> calls = [];
  bool reachable = true;

  @override
  Future<ReadOutcome> send({
    required String groupId,
    required String messageId,
  }) async {
    calls.add((groupId: groupId, messageId: messageId));
    if (!reachable) return const ReadUnreachable();
    return ReadConfirmed({
      'id': 1,
      'groupId': groupId,
      'lastReadMessageId': messageId,
      'lastReadAt': '2026-09-05T10:00:00.000Z',
      'advanced': true,
    });
  }
}
