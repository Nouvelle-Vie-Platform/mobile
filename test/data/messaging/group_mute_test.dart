import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/group_dao.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/messaging/group_mute_setter.dart';
import 'package:maison_du_miracle/data/messaging/messaging_channel.dart';
import 'package:maison_du_miracle/data/messaging/messaging_store_writer.dart';
import 'package:maison_du_miracle/data/sync/synced_collection.dart';

import '../../data/local/local_database_fixtures.dart';
import '../../helpers/sync_fixtures.dart';

/// **La sourdine d'une discussion, côté client** (M5) : la ligne `group_mutes`
/// — d'où qu'elle vienne, tirage, canal ou réponse du `PUT` — se range par la
/// même fonction, jamais par-dessus un réglage plus récent ; le geste part au
/// serveur et c'est sa réponse qui entre au magasin ; la liste lit la sourdine.
void main() {
  late AppDatabase db;
  late MessagingStoreWriter writer;

  Map<String, Object?> muteRow({
    String? until,
    bool forever = false,
    required String changedAt,
  }) =>
      {
        'id': 1,
        'groupId': kGroupId,
        'mutedUntil': until,
        'mutedForever': forever,
        'muteChangedAt': changedAt,
      };

  setUp(() async {
    db = openTestDatabase();
    writer = MessagingStoreWriter(db);
    Future<void> apply(String key, List<Map<String, Object?>> rows) =>
        syncedCollectionFor(key)!.applyLive(db.syncDao, rows);
    await apply(SyncCollectionKey.profiles, [myProfilePayload]);
    await apply(SyncCollectionKey.groups, [myGroupPayload]);
    await apply(SyncCollectionKey.groupMembers, [myMembershipPayload]);
  });

  tearDown(() => db.close());

  group('Le canal', () {
    test('mute.changed se range dans group_mutes', () {
      final event = decodeMessagingData(
        jsonEncode({
          'channel': 'users/$kMeId',
          'payload': {
            'type': 'mute.changed',
            'mute': muteRow(forever: true, changedAt: '2026-10-06T10:00:00Z'),
          },
        }),
        channel: userChannelName(kMeId),
      );

      expect(event, isA<MessagingRowEvent>());
      final row = event! as MessagingRowEvent;
      expect(row.collection, SyncCollectionKey.groupMutes);
      expect(row.groupId, kGroupId);
    });
  });

  group('Le rangement', () {
    test('une sourdine reçue se range, et la liste la lit', () async {
      await writer.store(
        SyncCollectionKey.groupMutes,
        muteRow(forever: true, changedAt: '2026-10-06T10:00:00.000Z'),
      );

      final mute = await db.groupDao.muteOf(kGroupId).getSingle();
      expect(mute.mutedForever, isTrue);
      final conversation =
          (await db.groupDao.conversationsOf(kMeId).get()).single;
      expect(conversation.isMutedAt(DateTime.now()), isTrue);
    });

    test('un réglage plus ancien, arrivé en retard, ne recouvre pas le récent',
        () async {
      // Réactivée à 10 h…
      await writer.store(
        SyncCollectionKey.groupMutes,
        muteRow(changedAt: '2026-10-06T10:00:00.000Z'),
      );
      // … puis l'écho tardif de la sourdine posée à 9 h arrive par le canal.
      await writer.store(
        SyncCollectionKey.groupMutes,
        muteRow(forever: true, changedAt: '2026-10-06T09:00:00.000Z'),
      );

      final mute = await db.groupDao.muteOf(kGroupId).getSingle();
      expect(mute.mutedForever, isFalse);
    });

    test('une sourdine bornée échue n\'est plus une sourdine', () {
      final now = DateTime.utc(2026, 10, 6, 12);
      expect(
        isGroupMuted(
          mutedUntil: now.subtract(const Duration(seconds: 1)),
          mutedForever: false,
          now: now,
        ),
        isFalse,
      );
      expect(
        isGroupMuted(
          mutedUntil: now.add(const Duration(hours: 8)),
          mutedForever: false,
          now: now,
        ),
        isTrue,
      );
      expect(
        isGroupMuted(mutedUntil: null, mutedForever: true, now: now),
        isTrue,
      );
      expect(
        isGroupMuted(mutedUntil: null, mutedForever: false, now: now),
        isFalse,
      );
    });
  });

  group('Le geste', () {
    test('part au serveur avec sa durée, et range la ligne rendue', () async {
      final sender = _RecordingMuteSender(
        reply: muteRow(
          until: '2099-01-01T00:00:00.000Z',
          changedAt: '2026-10-06T10:00:00.000Z',
        ),
      );
      final setter = GroupMuteSetter(
        sender: sender,
        storeMute: (row) => writer.store(SyncCollectionKey.groupMutes, row),
      );

      final ok =
          await setter.set(groupId: kGroupId, duration: MuteDuration.oneWeek);

      expect(ok, isTrue);
      expect(sender.calls.single, (groupId: kGroupId, duration: '1w'));
      final mute = await db.groupDao.muteOf(kGroupId).getSingle();
      expect(mute.mutedUntil!.isAtSameMomentAs(DateTime.utc(2099)), isTrue);
    });

    test('réactiver envoie une durée nulle', () async {
      final sender = _RecordingMuteSender(
        reply: muteRow(changedAt: '2026-10-06T10:00:00.000Z'),
      );
      final setter = GroupMuteSetter(
        sender: sender,
        storeMute: (row) => writer.store(SyncCollectionKey.groupMutes, row),
      );

      await setter.set(groupId: kGroupId, duration: null);

      expect(sender.calls.single, (groupId: kGroupId, duration: null));
    });

    test('un refus ne range rien, et le dit', () async {
      final setter = GroupMuteSetter(
        sender: _RecordingMuteSender(reply: null),
        storeMute: (row) => writer.store(SyncCollectionKey.groupMutes, row),
      );

      final ok =
          await setter.set(groupId: kGroupId, duration: MuteDuration.forever);

      expect(ok, isFalse);
      expect(await db.groupDao.muteOf(kGroupId).getSingleOrNull(), isNull);
    });

    test('les trois durées sont celles que le serveur attend', () {
      expect(
        MuteDuration.values.map((d) => d.wire),
        ['8h', '1w', 'forever'],
      );
    });
  });
}

class _RecordingMuteSender implements GroupMuteSender {
  _RecordingMuteSender({required this.reply});

  final Map<String, Object?>? reply;
  final List<({String groupId, String? duration})> calls = [];

  @override
  Future<Map<String, Object?>?> send({
    required String groupId,
    required MuteDuration? duration,
  }) async {
    calls.add((groupId: groupId, duration: duration?.wire));
    return reply;
  }
}
