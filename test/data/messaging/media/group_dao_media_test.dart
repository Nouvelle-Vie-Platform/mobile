/// **Le média dans le magasin** (M4, #143) : une ligne servie avec son média
/// se range par le même chemin que le canal, se relit dans le fil, et donne
/// à la liste des conversations de quoi dire « 🎤 Message vocal ».
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/messaging/messaging_store_writer.dart';
import 'package:maison_du_miracle/data/repositories/store_echanges_repository.dart';
import 'package:maison_du_miracle/models/echanges_view.dart';
import 'package:maison_du_miracle/models/message_media.dart';

import '../../local/local_database_fixtures.dart';
import '../../../helpers/sync_fixtures.dart';

Map<String, Object?> _media(
  String id,
  String at, {
  required String kind,
  String? key,
  Map<String, Object?>? meta,
  String? body,
  int? duration,
}) =>
    {
      'id': id,
      'groupId': kGroupId,
      'authorId': kPeerId,
      'isSystem': false,
      'body': body,
      'mediaKey': key,
      'mediaKind': kind,
      'mediaDuration': duration,
      'mediaMeta': meta,
      'mediaSize': key == null ? null : 240000,
      'mediaMime': key == null ? null : 'audio/mp4',
      'mediaThumbnailKey': null,
      'clientMessageId': null,
      'clientCreatedAt': null,
      'createdAt': at,
      'deletedAt': null,
    };

void main() {
  late AppDatabase db;
  late MessagingStoreWriter writer;

  setUp(() {
    db = openTestDatabase();
    writer = MessagingStoreWriter(db);
  });

  tearDown(() => db.close());

  Future<void> seedGroup() async {
    await writer.store(SyncCollectionKey.groups, myGroupPayload);
    await writer.store(SyncCollectionKey.groupMembers, myMembershipPayload);
    await writer.store(SyncCollectionKey.groupMembers, peerMembershipPayload);
  }

  StoreEchangesRepository repository() =>
      StoreEchangesRepository(db.groupDao, userId: kMeId);

  test('un vocal servi se relit au fil avec sa forme d’onde et sa durée',
      () async {
    await seedGroup();
    await writer.store(
      SyncCollectionKey.groupMessages,
      _media(
        '019a3000-0000-7000-8000-0000000000v1',
        '2026-09-03T11:00:00.000Z',
        kind: 'audio',
        key: 'group-media/g/v.m4a',
        meta: {
          'voice': true,
          'waveform': [5, 50, 95],
        },
        duration: 42,
      ),
    );

    final message = (await repository().thread(kGroupId).first).last;
    expect(message.body, isNull);
    expect(message.media!.kind, MessageMediaKind.voice);
    expect(message.media!.waveform, [5, 50, 95]);
    expect(message.media!.durationSeconds, 42);
    expect(message.media!.key, 'group-media/g/v.m4a');
    expect(message.delivery, MessageDelivery.sent);
  });

  test('la liste des conversations connaît la forme du dernier média',
      () async {
    await seedGroup();
    await writer.store(
      SyncCollectionKey.groupMessages,
      _media(
        '019a3000-0000-7000-8000-0000000000a1',
        '2026-09-03T11:00:00.000Z',
        kind: 'audio',
        key: 'group-media/g/s.mp3',
        meta: {'voice': false, 'name': 'Chant.mp3'},
      ),
    );

    final conversation = (await repository().conversations().first).single;
    expect(conversation.lastMessagePreview, isNull);
    expect(conversation.lastMessageMedia, MessageMediaKind.audio);
  });

  test(
      'supprimé pour tous ou pour moi (M2) : ni média au fil, ni image dans '
      'la fiche du groupe', () async {
    await seedGroup();
    const kept = '019a3000-0000-7000-8000-0000000000i1';
    const gone = '019a3000-0000-7000-8000-0000000000i2';
    const hidden = '019a3000-0000-7000-8000-0000000000i3';
    for (final (id, at) in [
      (kept, '2026-09-03T11:00:00.000Z'),
      (gone, '2026-09-03T11:01:00.000Z'),
      (hidden, '2026-09-03T11:02:00.000Z'),
    ]) {
      await writer.store(
        SyncCollectionKey.groupMessages,
        _media(id, at, kind: 'image', key: 'group-media/$kGroupId/$id.jpg'),
      );
    }
    // Un tombstone qui porterait encore son média (un serveur fautif) : la
    // vue ne le peint pas pour autant.
    await writer.store(
      SyncCollectionKey.groupMessages,
      {
        ..._media(gone, '2026-09-03T11:01:00.000Z',
            kind: 'image', key: 'group-media/$kGroupId/$gone.jpg'),
        'deletedAt': '2026-09-03T12:00:00.000Z',
      },
    );
    await writer.store(SyncCollectionKey.groupMessageHides, {
      'id': 1,
      'groupId': kGroupId,
      'messageId': hidden,
      'createdAt': '2026-09-03T12:00:00.000Z',
    });

    expect(await db.groupDao.sharedImagesOf(kGroupId).get(), [kept]);

    final thread = await repository().thread(kGroupId).first;
    final tombstone = thread.singleWhere((m) => m.id == gone);
    expect(tombstone.deleted, isTrue);
    expect(tombstone.media, isNull);
    expect(thread.where((m) => m.id == hidden), isEmpty);
  });

  test('une position (sans clé) se range et se relit', () async {
    await seedGroup();
    await writer.store(
      SyncCollectionKey.groupMessages,
      _media(
        '019a3000-0000-7000-8000-0000000000l1',
        '2026-09-03T11:00:00.000Z',
        kind: 'location',
        meta: {'latitude': 6.13, 'longitude': 1.22, 'label': 'Temple'},
      ),
    );

    final message = (await repository().thread(kGroupId).first).last;
    expect(message.media!.kind, MessageMediaKind.location);
    expect(message.media!.label, 'Temple');
    final conversation = (await repository().conversations().first).single;
    expect(conversation.lastMessageMedia, MessageMediaKind.location);
  });

  test('l’écho d’un média : son fichier local, sa légende, sa cause d’échec',
      () async {
    await seedGroup();
    await db.groupDao.rememberPendingMedia(
      clientMessageId: 'c-1',
      groupId: kGroupId,
      createdAt: DateTime.utc(2026, 9, 3, 12),
      mediaKind: 'image',
      caption: 'Regardez',
      mediaPath: '/outbox/c-1-src.jpg',
    );
    await db.groupDao.markPendingMediaFailed('c-1', 'tooLarge');

    final echo = (await repository().thread(kGroupId).first).last;
    expect(echo.id, 'c-1');
    expect(echo.body, 'Regardez');
    expect(echo.delivery, MessageDelivery.failed);
    expect(echo.mediaError, MediaSendError.tooLarge);
    expect(echo.media!.kind, MessageMediaKind.image);
    expect(echo.media!.localPath, '/outbox/c-1-src.jpg');
  });

  test('l’écho d’un média sans légende n’a pas de texte (corps vide → nul)',
      () async {
    await seedGroup();
    await db.groupDao.rememberPendingMedia(
      clientMessageId: 'c-2',
      groupId: kGroupId,
      createdAt: DateTime.utc(2026, 9, 3, 12),
      mediaKind: 'audio',
      mediaPath: '/outbox/v.m4a',
      mediaMime: 'audio/mp4',
      mediaDuration: 4,
    );

    final echo = (await repository().thread(kGroupId).first).last;
    expect(echo.body, isNull);
    expect(echo.delivery, MessageDelivery.sending);
    expect(await db.groupDao.pendingMediaFiles(), {'/outbox/v.m4a'});
  });
}
