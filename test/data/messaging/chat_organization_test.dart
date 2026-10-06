/// **Organiser ses discussions** (#146, tranche M8) — le magasin et l'outbox :
/// le rangement servi et le rangement local, la borne des trois épingles,
/// l'ordre des événements, la recherche locale bornée à mes groupes, et la
/// remontée d'un fil jusqu'à un message.
///
/// Tout tourne sur une **vraie** base Drift en mémoire, par les vraies
/// fonctions de rangement (celles du registre, que le moteur et le canal
/// partagent).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/chat_organization_dao.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/messaging/group_arranger.dart';
import 'package:maison_du_miracle/data/messaging/group_history.dart';
import 'package:maison_du_miracle/data/messaging/messaging_store_writer.dart';
import 'package:maison_du_miracle/data/messaging/thread_message_locator.dart';
import 'package:maison_du_miracle/data/repositories/chat_search_repository.dart';
import 'package:maison_du_miracle/data/repositories/store_echanges_repository.dart';

import '../local/local_database_fixtures.dart';
import '../../helpers/sync_fixtures.dart';

Map<String, Object?> _arrangement(
  String groupId, {
  String? archivedAt,
  String? pinnedAt,
  required String arrangedAt,
  int id = 1,
}) =>
    {
      'id': id,
      'groupId': groupId,
      'archivedAt': archivedAt,
      'pinnedAt': pinnedAt,
      'arrangedAt': arrangedAt,
    };

Map<String, Object?> _group(String id, String name) => {
      ...myGroupPayload,
      'id': id,
      'name': name,
    };

Map<String, Object?> _membership(int id, String groupId, String userId) => {
      ...myMembershipPayload,
      'id': id,
      'groupId': groupId,
      'userId': userId,
    };

Map<String, Object?> _message(
  String id,
  String groupId,
  String body, {
  required DateTime at,
  String authorId = kPeerId,
  bool system = false,
}) =>
    {
      'id': id,
      'groupId': groupId,
      'authorId': system ? null : authorId,
      'isSystem': system,
      'body': body,
      'clientMessageId': null,
      'clientCreatedAt': null,
      'createdAt': at.toUtc().toIso8601String(),
      'deletedAt': null,
    };

/// Un envoyeur qui retient ce qu'on lui confie, et répond ce qu'on lui dit.
class _RecordingSender implements GroupArrangementSender {
  _RecordingSender(this.answer);

  ArrangeOutcome Function(String groupId, bool archived, bool pinned) answer;
  final List<({String groupId, bool archived, bool pinned})> sent = [];

  @override
  Future<ArrangeOutcome> send({
    required String groupId,
    required bool archived,
    required bool pinned,
  }) async {
    sent.add((groupId: groupId, archived: archived, pinned: pinned));
    return answer(groupId, archived, pinned);
  }
}

ArrangeOutcome _confirm(String groupId, bool archived, bool pinned) =>
    ArrangeConfirmed(
      _arrangement(
        groupId,
        archivedAt: archived ? '2026-10-06T10:00:00.000Z' : null,
        pinnedAt: pinned ? '2026-10-06T10:00:00.000Z' : null,
        arrangedAt: '2026-10-06T10:00:00.000Z',
      ),
    );

/// Un historique qui range des pages préparées, une par appel.
class _PagedHistory implements GroupHistory {
  _PagedHistory(this._writer, this._pages);

  final MessagingStoreWriter _writer;
  final List<List<Map<String, Object?>>> _pages;
  final List<String> asked = [];

  @override
  Future<HistoryOutcome> loadBefore({
    required String groupId,
    required String beforeId,
  }) async {
    asked.add(beforeId);
    if (_pages.isEmpty) return HistoryOutcome.exhausted;
    await _writer.storeMessages(_pages.removeAt(0));
    return _pages.isEmpty ? HistoryOutcome.exhausted : HistoryOutcome.more;
  }
}

void main() {
  late AppDatabase db;
  late MessagingStoreWriter writer;
  late ChatOrganizationDao dao;

  setUp(() {
    db = openTestDatabase();
    writer = MessagingStoreWriter(db);
    dao = db.chatOrganizationDao;
  });

  tearDown(() => db.close());

  /// Mon groupe (avec moi et un co-membre) et ses messages.
  Future<void> seedMyGroup() async {
    await writer.store(SyncCollectionKey.groups, myGroupPayload);
    await writer.store(SyncCollectionKey.groupMembers, myMembershipPayload);
    await writer.store(SyncCollectionKey.groupMembers, peerMembershipPayload);
    await writer.store(SyncCollectionKey.groupMessages, memberMessagePayload);
    await writer.store(SyncCollectionKey.groupMessages, myMessagePayload);
    await writer.store(SyncCollectionKey.groupMessages, systemMessagePayload);
  }

  /// [count] groupes de plus dont je suis membre — de quoi éprouver la borne.
  Future<List<String>> seedMoreGroups(int count) async {
    final ids = <String>[];
    for (var i = 0; i < count; i++) {
      final id = '019a2000-0000-7000-8000-0000000ext0$i';
      await writer.store(SyncCollectionKey.groups, _group(id, 'Groupe $i'));
      await writer.store(
        SyncCollectionKey.groupMembers,
        _membership(100 + i, id, kMeId),
      );
      ids.add(id);
    }
    return ids;
  }

  GroupArranger arranger(_RecordingSender sender) => GroupArranger(
        dao: dao,
        sender: sender,
        userId: kMeId,
        storeArrangement: (row) =>
            writer.store(SyncCollectionKey.groupArrangements, row),
      );

  Future<({bool archived, DateTime? pinnedAt})> listed(String groupId) async {
    final rows = await db.groupDao.conversationsOf(kMeId).get();
    final row = rows.singleWhere((r) => r.groupId == groupId);
    return (archived: row.isArchived, pinnedAt: row.pinnedAt);
  }

  group('Le rangement servi', () {
    test('une ligne group_arrangements archive et épingle dans la liste',
        () async {
      await seedMyGroup();
      expect((await listed(kGroupId)).archived, isFalse);

      await writer.store(
        SyncCollectionKey.groupArrangements,
        _arrangement(
          kGroupId,
          archivedAt: '2026-10-06T09:00:00.000Z',
          arrangedAt: '2026-10-06T09:00:00.000Z',
        ),
      );
      expect((await listed(kGroupId)).archived, isTrue);

      // Désarchiver revient avec le champ nul — sans tombstone.
      await writer.store(
        SyncCollectionKey.groupArrangements,
        _arrangement(
          kGroupId,
          pinnedAt: '2026-10-06T09:05:00.000Z',
          arrangedAt: '2026-10-06T09:05:00.000Z',
        ),
      );
      final now = await listed(kGroupId);
      expect(now.archived, isFalse);
      expect(now.pinnedAt, isNotNull);
    });

    test('un événement plus ancien ne recule pas le rangement (deux appareils)',
        () async {
      await seedMyGroup();
      await writer.store(
        SyncCollectionKey.groupArrangements,
        _arrangement(
          kGroupId,
          archivedAt: '2026-10-06T09:10:00.000Z',
          arrangedAt: '2026-10-06T09:10:00.000Z',
        ),
      );
      // Arrivé après, mais fait avant : ignoré.
      await writer.store(
        SyncCollectionKey.groupArrangements,
        _arrangement(kGroupId, arrangedAt: '2026-10-06T09:00:00.000Z'),
      );
      expect((await listed(kGroupId)).archived, isTrue);
    });

    test('une discussion archivée le reste quand un message arrive', () async {
      await seedMyGroup();
      await writer.store(
        SyncCollectionKey.groupArrangements,
        _arrangement(
          kGroupId,
          archivedAt: '2026-10-06T09:00:00.000Z',
          arrangedAt: '2026-10-06T09:00:00.000Z',
        ),
      );
      await writer.store(
        SyncCollectionKey.groupMessages,
        _message(
          '019a3000-0000-7000-8000-0000000new01',
          kGroupId,
          'Nouveau message',
          at: DateTime.utc(2026, 10, 6, 11),
        ),
      );
      final row = (await db.groupDao.conversationsOf(kMeId).get())
          .singleWhere((r) => r.groupId == kGroupId);
      expect(row.isArchived, isTrue);
      expect(row.unreadCount, greaterThan(0));
    });

    test('le dépôt des Échanges porte archived et pinnedAt', () async {
      await seedMyGroup();
      await writer.store(
        SyncCollectionKey.groupArrangements,
        _arrangement(
          kGroupId,
          pinnedAt: '2026-10-06T09:00:00.000Z',
          arrangedAt: '2026-10-06T09:00:00.000Z',
        ),
      );
      final list = await StoreEchangesRepository(db.groupDao, userId: kMeId)
          .conversations()
          .first;
      final c = list.singleWhere((c) => c.groupId == kGroupId);
      expect(c.pinned, isTrue);
      expect(c.archived, isFalse);
    });
  });

  group('L\'outbox du rangement', () {
    test('archiver : la liste bouge tout de suite, la ligne confirmée reste',
        () async {
      await seedMyGroup();
      final sender = _RecordingSender(_confirm);

      final result = await arranger(sender).archive(kGroupId, value: true);

      expect(result, ArrangeResult.done);
      expect(sender.sent.single,
          (groupId: kGroupId, archived: true, pinned: false));
      expect((await listed(kGroupId)).archived, isTrue);
      expect(await dao.pendingArrangements(), isEmpty);
      expect((await dao.arrangementOf(kGroupId))?.archivedAt, isNotNull);
    });

    test('hors ligne : le geste tient à l\'écran, et repart au rejeu',
        () async {
      await seedMyGroup();
      final sender =
          _RecordingSender((_, __, ___) => const ArrangeUnreachable());
      final outbox = arranger(sender);

      await outbox.archive(kGroupId, value: true);
      expect((await listed(kGroupId)).archived, isTrue);
      expect(await dao.pendingArrangements(), hasLength(1));

      sender.answer = _confirm;
      await outbox.replay();
      expect(sender.sent, hasLength(2));
      expect(await dao.pendingArrangements(), isEmpty);
      expect((await listed(kGroupId)).archived, isTrue);
    });

    test('idempotent : un geste déjà fait ne part pas', () async {
      await seedMyGroup();
      final sender = _RecordingSender(_confirm);
      final outbox = arranger(sender);

      await outbox.archive(kGroupId, value: true);
      final again = await outbox.archive(kGroupId, value: true);

      expect(again, ArrangeResult.unchanged);
      expect(sender.sent, hasLength(1));
    });

    test('archiver désépingle, épingler désarchive', () async {
      await seedMyGroup();
      final sender = _RecordingSender(_confirm);
      final outbox = arranger(sender);

      await outbox.pin(kGroupId, value: true);
      expect((await listed(kGroupId)).pinnedAt, isNotNull);
      await outbox.archive(kGroupId, value: true);
      expect(
          sender.sent.last, (groupId: kGroupId, archived: true, pinned: false));
      await outbox.pin(kGroupId, value: true);
      expect(
          sender.sent.last, (groupId: kGroupId, archived: false, pinned: true));
    });

    test('trois épingles au plus : la quatrième est refusée sans rien écrire',
        () async {
      await seedMyGroup();
      final others = await seedMoreGroups(3);
      final sender = _RecordingSender(_confirm);
      final outbox = arranger(sender);
      for (final id in others) {
        expect(await outbox.pin(id, value: true), ArrangeResult.done);
      }

      final fourth = await outbox.pin(kGroupId, value: true);

      expect(fourth, ArrangeResult.pinLimit);
      expect(sender.sent, hasLength(3));
      expect((await listed(kGroupId)).pinnedAt, isNull);

      // Désépingler libère une place.
      await outbox.pin(others.first, value: false);
      expect(await outbox.pin(kGroupId, value: true), ArrangeResult.done);
    });

    test('409 du serveur (épinglé ailleurs) : le geste est retiré', () async {
      await seedMyGroup();
      final sender = _RecordingSender((_, __, ___) => const ArrangePinLimit());

      final result = await arranger(sender).pin(kGroupId, value: true);

      expect(result, ArrangeResult.pinLimit);
      expect(await dao.pendingArrangements(), isEmpty);
      expect((await listed(kGroupId)).pinnedAt, isNull);
    });
  });

  group('La recherche locale', () {
    test('trouve le texte dans MES groupes, jamais ailleurs', () async {
      await seedMyGroup();
      // Contre-épreuve : un groupe dont je ne suis pas membre, dont un message
      // contient le mot cherché. Sans la jointure sur mes appartenances, il
      // sortirait.
      await writer.store(SyncCollectionKey.groups, openGroupPayload);
      await writer.store(
        SyncCollectionKey.groupMessages,
        _message(
          '019a3000-0000-7000-8000-0000000frg01',
          kOpenGroupId,
          'Répétition chez les autres',
          at: DateTime.utc(2026, 9, 3, 11),
        ),
      );

      final hits = await StoreChatSearchRepository(dao, userId: kMeId)
          .searchLocal('répétition');

      expect(hits.map((h) => h.messageId), [memberMessagePayload['id']]);
    });

    test('ni System Messages, et les jokers sont cherchés littéralement',
        () async {
      await seedMyGroup();
      await writer.store(
        SyncCollectionKey.groupMessages,
        _message(
          '019a3000-0000-7000-8000-0000000pct01',
          kGroupId,
          'Remise de 100% ce dimanche',
          at: DateTime.utc(2026, 9, 4),
        ),
      );
      final search = StoreChatSearchRepository(dao, userId: kMeId);

      // Le texte du System Message (« Un nouveau membre a rejoint… »).
      expect(await search.searchLocal('nouveau membre'), isEmpty);
      // `%%` non échappé rendrait tous les messages.
      expect(await search.searchLocal('%%'), isEmpty);
      expect(
        (await search.searchLocal('0%')).map((h) => h.messageId),
        ['019a3000-0000-7000-8000-0000000pct01'],
      );
      // Une seule lettre ne cherche pas.
      expect(await search.searchLocal('a'), isEmpty);
    });
  });

  group('Retrouver un message dans son fil', () {
    test('sa place depuis le plus récent, échos compris', () async {
      await seedMyGroup();
      // Trois messages : msg1 (10:30), msg2 (10:32), msg3 (10:35).
      expect(
        await dao.positionFromNewest(
            kGroupId, memberMessagePayload['id']! as String),
        3,
      );
      expect(
        await dao.positionFromNewest(
            kGroupId, systemMessagePayload['id']! as String),
        1,
      );
      expect(await dao.positionFromNewest(kGroupId, 'inconnu'), isNull);
      expect(await dao.oldestMessageIdOf(kGroupId), memberMessagePayload['id']);
    });

    test('absent du magasin : on remonte l\'historique jusqu\'à lui', () async {
      await seedMyGroup();
      final base = DateTime.utc(2026, 9, 1);
      final older = [
        for (var i = 0; i < 3; i++)
          _message(
            '019a3000-0000-7000-8000-0000000old0$i',
            kGroupId,
            'Ancien $i',
            at: base.add(Duration(hours: i)),
          ),
      ];
      final oldest = [
        _message(
          '019a3000-0000-7000-8000-0000000vold1',
          kGroupId,
          'Très ancien',
          at: DateTime.utc(2026, 8, 1),
        ),
      ];
      final history = _PagedHistory(writer, [older, oldest]);

      final window = await ThreadMessageLocator(dao: dao, history: history)
          .windowFor(kGroupId, '019a3000-0000-7000-8000-0000000vold1');

      // Deux pages demandées, chacune depuis le plus ancien du magasin.
      expect(history.asked, [
        memberMessagePayload['id'],
        '019a3000-0000-7000-8000-0000000old00',
      ]);
      // 3 du fil + 3 anciens + lui-même.
      expect(window, 7);
    });

    test('introuvable (historique épuisé) : null, le fil s\'ouvre normalement',
        () async {
      await seedMyGroup();
      final history = _PagedHistory(writer, []);

      final window = await ThreadMessageLocator(dao: dao, history: history)
          .windowFor(kGroupId, 'disparu');

      expect(window, isNull);
    });
  });

  test('arrangementIsNotOlder : la seconde fait foi, l\'absence se range', () {
    final local = GroupArrangementRow(
      syncStamp: 0,
      groupId: kGroupId,
      arrangedAt: DateTime.utc(2026, 10, 6, 9),
    );
    expect(
      arrangementIsNotOlder(local, {'arrangedAt': '2026-10-06T08:59:59.000Z'}),
      isFalse,
    );
    expect(
      arrangementIsNotOlder(local, {'arrangedAt': '2026-10-06T09:00:00.500Z'}),
      isTrue,
    );
    expect(arrangementIsNotOlder(null, {'arrangedAt': null}), isTrue);
    expect(arrangementIsNotOlder(local, {}), isTrue);
  });
}
