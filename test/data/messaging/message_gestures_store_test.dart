/// **Les gestes sur un message, dans le magasin** (M2, #141) — la citation
/// photographiée, l'agrégat des réactions, « supprimer pour moi », le tombstone
/// gardé, et la ligne serveur rangée après un geste. Sur une **vraie** base
/// Drift en mémoire, par les vraies fonctions de rangement.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/group_dao.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/messaging/message_gestures.dart';
import 'package:maison_du_miracle/data/messaging/messaging_channel.dart';
import 'package:maison_du_miracle/data/messaging/messaging_store_writer.dart';
import 'package:maison_du_miracle/data/repositories/store_echanges_repository.dart';
import 'package:maison_du_miracle/models/echanges_view.dart';

import '../local/local_database_fixtures.dart';
import '../../helpers/sync_fixtures.dart';

const String _replyId = '019a3000-0000-7000-8000-0000000rep01';

/// Une réponse de moi au message du co-membre, telle que le serveur M2 la sert.
const Map<String, Object?> _replyPayload = {
  'id': _replyId,
  'groupId': kGroupId,
  'authorId': kMeId,
  'isSystem': false,
  'body': 'J\'y serai.',
  'clientMessageId': null,
  'clientCreatedAt': null,
  'createdAt': '2026-09-03T11:00:00.000Z',
  'deletedAt': null,
  'editedAt': '2026-09-03T11:05:00.000Z',
  'isForwarded': false,
  'replyTo': {
    'messageId': '019a3000-0000-7000-8000-00000000msg1',
    'authorId': kPeerId,
    'excerpt': 'Répétition samedi à 16h…',
    'mediaKind': null,
    'deleted': false,
  },
};

Map<String, Object?> _reaction(
  String id,
  String userId,
  String emoji, {
  String messageId = '019a3000-0000-7000-8000-00000000msg1',
  String? deletedAt,
}) =>
    {
      'id': id,
      'groupId': kGroupId,
      'messageId': messageId,
      'userId': userId,
      'emoji': emoji,
      'createdAt': '2026-09-03T12:00:00.000Z',
      'updatedAt': '2026-09-03T12:00:00.000Z',
      'deletedAt': deletedAt,
    };

Map<String, Object?> _hide(String messageId) => {
      'id': 7,
      'groupId': kGroupId,
      'messageId': messageId,
      'createdAt': '2026-09-03T12:00:00.000Z',
    };

/// Rend des lignes serveur choisies d'avance.
class _ScriptedSender implements MessageGestureSender {
  _ScriptedSender(this.rows, {this.outcome = GestureOutcome.done});

  final List<Map<String, Object?>> rows;
  final GestureOutcome outcome;

  GestureReply get _reply => (outcome: outcome, rows: rows);

  @override
  Future<GestureReply> react(String g, String m, String e) async => _reply;
  @override
  Future<GestureReply> unreact(String g, String m) async => _reply;
  @override
  Future<GestureReply> edit(String g, String m, String b) async => _reply;
  @override
  Future<GestureReply> deleteForEveryone(String g, String m) async => _reply;
  @override
  Future<GestureReply> hideForMe(String g, String m) async => _reply;
  @override
  Future<GestureReply> forward(
          String g, String m, List<ForwardTarget> t) async =>
      _reply;
}

void main() {
  late AppDatabase db;
  late MessagingStoreWriter writer;
  late StoreEchangesRepository repository;

  setUp(() {
    db = openTestDatabase();
    writer = MessagingStoreWriter(db);
    repository = StoreEchangesRepository(db.groupDao, userId: kMeId);
  });

  tearDown(() => db.close());

  Future<void> seedGroup() async {
    await writer.store(SyncCollectionKey.groups, myGroupPayload);
    await writer.store(SyncCollectionKey.groupMembers, myMembershipPayload);
    await writer.store(SyncCollectionKey.groupMembers, peerMembershipPayload);
    await writer.store(SyncCollectionKey.groupMessages, memberMessagePayload);
    await writer.store(SyncCollectionKey.groupMessages, myMessagePayload);
  }

  Future<List<GroupMessageView>> thread() => repository.thread(kGroupId).first;

  group('La citation', () {
    test('la ligne serveur se range à plat, et le fil la peint sans l\'origine',
        () async {
      await writer.store(SyncCollectionKey.groups, myGroupPayload);
      await writer.store(SyncCollectionKey.groupMembers, myMembershipPayload);
      await writer.store(SyncCollectionKey.groupMessages, _replyPayload);

      final reply = (await thread()).single;
      expect(reply.quote, isNotNull);
      expect(reply.quote!.messageId, '019a3000-0000-7000-8000-00000000msg1');
      expect(reply.quote!.authorId, kPeerId);
      expect(reply.quote!.excerpt, 'Répétition samedi à 16h…');
      expect(reply.quote!.deleted, isFalse);
      expect(reply.edited, isTrue);
      expect(reply.forwarded, isFalse);
    });

    test('une citation d\'origine supprimée dit « supprimé », sans extrait',
        () async {
      await seedGroup();
      await writer.store(SyncCollectionKey.groupMessages, {
        ..._replyPayload,
        'replyTo': {
          'messageId': '019a3000-0000-7000-8000-00000000msg1',
          'authorId': kPeerId,
          'excerpt': null,
          'mediaKind': null,
          'deleted': true,
        },
      });

      final reply = (await thread()).singleWhere((m) => m.id == _replyId);
      expect(reply.quote!.deleted, isTrue);
      expect(reply.quote!.excerpt, isNull);
    });

    test('un serveur antérieur à M2 (aucun champ neuf) ne casse rien',
        () async {
      await seedGroup();
      final message = (await thread())
          .singleWhere((m) => m.id == memberMessagePayload['id']);
      expect(message.quote, isNull);
      expect(message.edited, isFalse);
      expect(message.forwarded, isFalse);
      expect(message.deleted, isFalse);
    });
  });

  group('Le tombstone gardé', () {
    test(
        'un message supprimé pour tous reste au fil, sans texte, et ne compte '
        'plus en non-lu', () async {
      await seedGroup();
      expect(await db.groupDao.unreadCountOf(kGroupId, kMeId), greaterThan(0));

      await writer.store(SyncCollectionKey.groupMessages, {
        ...memberMessagePayload,
        'deletedAt': '2026-09-04T11:00:00.000Z',
      });

      final deleted = (await thread())
          .singleWhere((m) => m.id == memberMessagePayload['id']);
      expect(deleted.deleted, isTrue);
      expect(deleted.body, isNull);
      expect(deleted.reactions, isEmpty);
      expect(await db.groupDao.unreadCountOf(kGroupId, kMeId), 0);
    });

    test('le dernier message supprimé : la tuile le sait', () async {
      await writer.store(SyncCollectionKey.groups, myGroupPayload);
      await writer.store(SyncCollectionKey.groupMembers, myMembershipPayload);
      await writer.store(SyncCollectionKey.groupMessages, {
        ...memberMessagePayload,
        'deletedAt': '2026-09-04T11:00:00.000Z',
      });

      final tile = (await repository.conversations().first).single;
      expect(tile.lastMessageDeleted, isTrue);
    });
  });

  group('Les réactions', () {
    test('une par personne ; l\'agrégat, le plus partagé d\'abord ; la mienne',
        () async {
      await seedGroup();
      await writer.store(
        SyncCollectionKey.groupMessageReactions,
        _reaction('019a4000-0000-7000-8000-0000000rea01', kPeerId, '👍'),
      );
      await writer.store(
        SyncCollectionKey.groupMessageReactions,
        _reaction('019a4000-0000-7000-8000-0000000rea02', kMeId, '🙏'),
      );
      await writer.store(
        SyncCollectionKey.groupMessageReactions,
        _reaction('019a4000-0000-7000-8000-0000000rea03', kGoneId, '🙏'),
      );

      final message = (await thread())
          .singleWhere((m) => m.id == memberMessagePayload['id']);
      expect(message.reactions.map((r) => (r.emoji, r.count, r.mine)), [
        ('🙏', 2, true),
        ('👍', 1, false),
      ]);
      expect(message.myReaction, '🙏');

      final reactors = await repository
          .reactors(memberMessagePayload['id']! as String)
          .first;
      expect(reactors, hasLength(3));
      expect(reactors.where((r) => r.mine).single.emoji, '🙏');
    });

    test('changer remplace (même id), retirer (tombstone) efface', () async {
      await seedGroup();
      const id = '019a4000-0000-7000-8000-0000000rea02';
      await writer.store(
        SyncCollectionKey.groupMessageReactions,
        _reaction(id, kMeId, '🙏'),
      );
      await writer.store(
        SyncCollectionKey.groupMessageReactions,
        _reaction(id, kMeId, '❤️'),
      );
      var message = (await thread())
          .singleWhere((m) => m.id == memberMessagePayload['id']);
      expect(message.myReaction, '❤️');
      expect(message.reactions.single.count, 1);

      await writer.store(
        SyncCollectionKey.groupMessageReactions,
        _reaction(id, kMeId, '❤️', deletedAt: '2026-09-03T13:00:00.000Z'),
      );
      message = (await thread())
          .singleWhere((m) => m.id == memberMessagePayload['id']);
      expect(message.reactions, isEmpty);
      expect(message.myReaction, isNull);
    });

    test('parseReactions ignore une entrée mal formée', () {
      final raw = [
        '👍${String.fromCharCode(31)}u-1',
        'cassé',
        '${String.fromCharCode(31)}u-2',
      ].join(String.fromCharCode(30));
      expect(GroupDao.parseReactions(raw), [(emoji: '👍', userId: 'u-1')]);
      expect(GroupDao.parseReactions(null), isEmpty);
    });
  });

  group('Supprimer pour moi', () {
    test(
        'le message quitte MON fil, mes non-lus et l\'aperçu de ma liste — '
        'sans être effacé du magasin', () async {
      await seedGroup();
      final hidden = memberMessagePayload['id']! as String;

      await writer.store(SyncCollectionKey.groupMessageHides, _hide(hidden));

      expect((await thread()).map((m) => m.id), isNot(contains(hidden)));
      expect(await db.groupDao.unreadCountOf(kGroupId, kMeId), 0);
      expect(
        (await db.select(db.groupMessages).get()).map((m) => m.id),
        contains(hidden),
      );
      expect(await repository.newerThan(kGroupId, hidden), isNull);
    });

    test('la condition est réutilisable (recherche de M8)', () {
      expect(GroupDao.notHiddenForMe('x'), contains('group_message_hides'));
    });
  });

  group('Le saut vers une citation', () {
    test('newerThan compte les messages plus récents ; null s\'il manque',
        () async {
      await seedGroup();
      expect(
        await repository.newerThan(
          kGroupId,
          memberMessagePayload['id']! as String,
        ),
        1,
      );
      expect(await repository.newerThan(kGroupId, 'inconnu'), isNull);
      expect(
        await repository.oldestMessageId(kGroupId),
        memberMessagePayload['id'],
      );
    });
  });

  group('Le geste, puis la ligne serveur au magasin', () {
    test('une réaction acceptée se range aussitôt', () async {
      await seedGroup();
      final gestures = MessageGestures(
        sender: _ScriptedSender([
          _reaction('019a4000-0000-7000-8000-0000000rea09', kMeId, '😂'),
        ]),
        store: writer.store,
      );

      final outcome = await gestures.toggleReaction(
        groupId: kGroupId,
        messageId: memberMessagePayload['id']! as String,
        emoji: '😂',
        current: null,
      );

      expect(outcome, GestureOutcome.done);
      final message = (await thread())
          .singleWhere((m) => m.id == memberMessagePayload['id']);
      expect(message.myReaction, '😂');
    });

    test('un geste refusé ne range rien', () async {
      await seedGroup();
      final gestures = MessageGestures(
        sender: _ScriptedSender(
          [_hide(memberMessagePayload['id']! as String)],
          outcome: GestureOutcome.windowClosed,
        ),
        store: writer.store,
      );

      final outcome = await gestures.hideForMe(
        groupId: kGroupId,
        messageId: memberMessagePayload['id']! as String,
      );

      expect(outcome, GestureOutcome.windowClosed);
      expect(await db.select(db.groupMessageHides).get(), isEmpty);
    });
  });

  group('Le canal', () {
    String frame(String type, String key, Map<String, Object?> row) =>
        jsonEncode({
          'channel': 'users/$kMeId',
          'payload': {'type': type, key: row},
        });

    test('reaction.changed et message.hidden se rangent dans leur collection',
        () {
      final reaction = decodeMessagingData(
        frame(
          'reaction.changed',
          'reaction',
          _reaction('019a4000-0000-7000-8000-0000000rea01', kPeerId, '👍'),
        ),
        channel: 'users/$kMeId',
      )! as MessagingRowEvent;
      expect(reaction.collection, SyncCollectionKey.groupMessageReactions);
      expect(reaction.groupId, kGroupId);

      final hide = decodeMessagingData(
        frame('message.hidden', 'hide', _hide('m-1')),
        channel: 'users/$kMeId',
      )! as MessagingRowEvent;
      expect(hide.collection, SyncCollectionKey.groupMessageHides);
    });
  });

  test('aggregateReactions : à égalité, l\'ordre d\'arrivée', () {
    final aggregate = aggregateReactions(
      const [
        (emoji: '😮', userId: 'a'),
        (emoji: '👍', userId: 'b'),
        (emoji: '👍', userId: 'c'),
        (emoji: '😢', userId: 'me'),
      ],
      me: 'me',
    );
    expect(aggregate.map((r) => r.emoji), ['👍', '😮', '😢']);
    expect(aggregate.last.mine, isTrue);
  });
}
