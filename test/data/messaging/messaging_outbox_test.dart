/// **Ce qui n'est pas parti repart, et jamais deux fois** (#140) : le renvoi
/// automatique des messages et l'outbox de la lecture.
///
/// Piège 5 du plan : chaque geste écrit par le client porte une clé ou est
/// idempotent — un renvoi automatique ne doit jamais dupliquer.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/messaging/group_read_advancer.dart';
import 'package:maison_du_miracle/data/messaging/messaging_store_writer.dart';
import 'package:maison_du_miracle/data/repositories/group_message_composer.dart';
import 'package:maison_du_miracle/data/repositories/group_message_sender.dart';
import 'package:maison_du_miracle/data/repositories/store_echanges_repository.dart';
import 'package:maison_du_miracle/models/echanges_view.dart';

import '../local/local_database_fixtures.dart';
import '../../helpers/sync_fixtures.dart';

class _ScriptedSender implements GroupMessageSender {
  bool succeeds = true;
  final List<String> posted = [];

  @override
  Future<bool> send({
    required String groupId,
    required String body,
    required String clientMessageId,
    required DateTime clientCreatedAt,
  }) async {
    posted.add(clientMessageId);
    return succeeds;
  }
}

class _ScriptedReadSender implements GroupReadSender {
  ReadOutcome Function(String messageId) answer =
      (_) => const ReadUnreachable();
  final List<String> posted = [];

  @override
  Future<ReadOutcome> send({
    required String groupId,
    required String messageId,
  }) async {
    posted.add(messageId);
    return answer(messageId);
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  group('Le renvoi automatique des messages', () {
    late _ScriptedSender sender;
    late GroupMessageComposer composer;
    var minted = 0;

    setUp(() {
      sender = _ScriptedSender();
      minted = 0;
      composer = GroupMessageComposer(
        dao: db.groupDao,
        sender: sender,
        resynchronize: () async {},
        now: () => DateTime.utc(2026, 10, 5, 10, 0, minted),
        mintId: () => 'c-${++minted}',
      );
    });

    Future<List<GroupMessageView>> thread() =>
        StoreEchangesRepository(db.groupDao, userId: kMeId)
            .thread(kGroupId)
            .first;

    test(
        'un message en échec repart tout seul, sous SA clé, et une seule fois',
        () async {
      sender.succeeds = false;
      await composer.send(groupId: kGroupId, body: 'Amen');
      await composer.send(groupId: kGroupId, body: 'Alléluia');
      expect(
        (await thread()).map((m) => m.delivery),
        everyElement(MessageDelivery.failed),
      );

      // Le réseau revient : un cycle réussit, l'outbox est rejouée.
      sender.succeeds = true;
      sender.posted.clear();
      await composer.resendUnconfirmed();

      // Dans l'ordre de rédaction, sous les clés d'origine — jamais une neuve.
      expect(sender.posted, ['c-1', 'c-2']);
      expect(
        (await thread()).map((m) => m.delivery),
        everyElement(MessageDelivery.sending),
        reason: 'parti, pas encore confirmé : la ligne serveur arrivera par le '
            'canal ou le cycle suivant',
      );
    });

    test('un renvoi qui échoue encore remet « pas parti »', () async {
      sender.succeeds = false;
      await composer.send(groupId: kGroupId, body: 'Amen');
      await composer.resendUnconfirmed();
      expect((await thread()).single.delivery, MessageDelivery.failed);
    });

    test('un message déjà confirmé par le serveur ne repart pas', () async {
      sender.succeeds = false;
      final key = await composer.send(groupId: kGroupId, body: 'Amen');
      // La ligne serveur est arrivée (la réponse s'était perdue).
      await MessagingStoreWriter(db).store(SyncCollectionKey.groupMessages, {
        ...memberMessagePayload,
        'id': '019a3000-0000-7000-8000-0000000msg20',
        'authorId': kMeId,
        'body': 'Amen',
        'clientMessageId': key,
      });

      sender.posted.clear();
      await composer.resendUnconfirmed();
      expect(sender.posted, isEmpty);
    });

    test('un envoi encore en cours n\'est pas doublé par le renvoi', () async {
      // L'envoi d'origine est suspendu ; le renvoi automatique passe pendant ce
      // temps.
      final slow = _SlowSender();
      final composer = GroupMessageComposer(
        dao: db.groupDao,
        sender: slow,
        resynchronize: () async {},
        mintId: () => 'c-lent',
      );
      final sending = composer.send(groupId: kGroupId, body: 'Amen');
      await pumpEventQueue();

      await composer.resendUnconfirmed();
      slow.release();
      await sending;

      expect(slow.posted, ['c-lent']);
    });
  });

  group('L\'outbox de la lecture', () {
    late _ScriptedReadSender sender;
    late GroupReadAdvancer advancer;
    late MessagingStoreWriter writer;

    setUp(() async {
      sender = _ScriptedReadSender();
      writer = MessagingStoreWriter(db);
      advancer = GroupReadAdvancer(
        dao: db.groupDao,
        sender: sender,
        storeRead: (row) => writer.store(SyncCollectionKey.groupReads, row),
      );
      await writer.store(SyncCollectionKey.groups, myGroupPayload);
      await writer.store(SyncCollectionKey.groupMembers, myMembershipPayload);
      await writer.store(
        SyncCollectionKey.groupMessages,
        removedAuthorMessagePayload,
      );
    });

    final readId = removedAuthorMessagePayload['id']! as String;
    final readAt = DateTime.utc(2026, 9, 3, 10, 40);

    Map<String, Object?> confirmed(String messageId) => {
          'id': 1,
          'groupId': kGroupId,
          'lastReadMessageId': messageId,
          'lastReadAt': '2026-10-05T10:00:00.000Z',
          'advanced': true,
        };

    test(
        'confirmée : la ligne servie est rangée, PUIS la lecture locale part',
        () async {
      sender.answer = (id) => ReadConfirmed(confirmed(id));
      await advancer.advance(
        groupId: kGroupId,
        messageId: readId,
        messageCreatedAt: readAt,
      );

      expect(sender.posted, [readId]);
      expect((await db.groupDao.readOf(kGroupId))!.lastReadMessageId, readId);
      expect(await db.groupDao.pendingReads(), isEmpty);
      expect(await db.groupDao.unreadCountOf(kGroupId, kMeId), 0);
    });

    test(
        'injoignable : la lecture locale reste — la pastille est déjà '
        'éteinte —, et le rejeu la renvoie', () async {
      await advancer.advance(
        groupId: kGroupId,
        messageId: readId,
        messageCreatedAt: readAt,
      );
      expect(await db.groupDao.pendingReads(), hasLength(1));
      expect(await db.groupDao.unreadCountOf(kGroupId, kMeId), 0);

      sender.answer = (id) => ReadConfirmed(confirmed(id));
      await advancer.replay();

      expect(sender.posted, [readId, readId], reason: 'rejouer est sûr');
      expect(await db.groupDao.pendingReads(), isEmpty);
    });

    test('refusée (plus membre, message disparu) : rien à rejouer', () async {
      sender.answer = (_) => const ReadRejected();
      await advancer.advance(
        groupId: kGroupId,
        messageId: readId,
        messageCreatedAt: readAt,
      );
      expect(await db.groupDao.pendingReads(), isEmpty);

      await advancer.replay();
      expect(sender.posted, [readId]);
    });

    test('une lecture qui n\'avance pas ne poste rien', () async {
      await advancer.advance(
        groupId: kGroupId,
        messageId: readId,
        messageCreatedAt: readAt,
      );
      await advancer.advance(
        groupId: kGroupId,
        messageId: memberMessagePayload['id']! as String,
        messageCreatedAt: DateTime.utc(2026, 9, 3, 10, 30),
      );
      expect(sender.posted, [readId]);
    });
  });
}

/// Un envoyeur qui ne répond qu'au signal — pour observer la fenêtre où un
/// envoi est en cours.
class _SlowSender implements GroupMessageSender {
  final List<String> posted = [];
  final List<Completer<bool>> _pending = [];

  void release() {
    for (final pending in _pending) {
      pending.complete(true);
    }
  }

  @override
  Future<bool> send({
    required String groupId,
    required String body,
    required String clientMessageId,
    required DateTime clientCreatedAt,
  }) {
    posted.add(clientMessageId);
    final pending = Completer<bool>();
    _pending.add(pending);
    return pending.future;
  }
}
