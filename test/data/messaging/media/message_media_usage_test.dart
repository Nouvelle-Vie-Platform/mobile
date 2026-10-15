/// **La pesée et la purge du magasin des médias** (T4, #226).
///
/// Des `test` nus et non des `testWidgets` : la pesée part dans un isolat et la
/// purge efface de vrais fichiers, et **la zone d'`async` d'un `testWidgets` ne
/// fait jamais aboutir une entrée-sortie réelle**. Ici elle aboutit, donc on
/// mesure la vérité du disque — ce que l'écran promet d'afficher. Les fixtures
/// restent en `writeAsBytesSync` : rien ne doit pouvoir pendre.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/messaging/media/message_media_usage.dart';
import 'package:maison_du_miracle/data/messaging/messaging_store_writer.dart';
import 'package:maison_du_miracle/models/message_media.dart';

import '../../local/local_database_fixtures.dart';
import '../../../helpers/sync_fixtures.dart';

Map<String, Object?> _message(
  String id, {
  required String groupId,
  required String kind,
  Map<String, Object?>? meta,
  int announcedSize = 9999999,
}) =>
    {
      'id': id,
      'groupId': groupId,
      'authorId': kPeerId,
      'isSystem': false,
      'body': null,
      'mediaKey': 'media/$id',
      'mediaKind': kind,
      'mediaDuration': null,
      'mediaMeta': meta,
      // **Volontairement énorme et volontairement faux** : c'est la taille
      // annoncée par le serveur, et aucun total de l'écran ne doit la contenir.
      'mediaSize': announcedSize,
      'mediaMime': 'application/octet-stream',
      'mediaThumbnailKey': null,
      'clientMessageId': null,
      'clientCreatedAt': null,
      'createdAt': '2026-10-01T09:00:00.000Z',
      'deletedAt': null,
    };

void main() {
  late AppDatabase db;
  late MessagingStoreWriter writer;
  late Directory root;

  setUp(() {
    db = openTestDatabase();
    writer = MessagingStoreWriter(db);
    root = Directory.systemTemp.createTempSync('t4_stockage');
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// Un fichier de [bytes] octets, écrit **synchroniquement**, et noté au
  /// magasin pour [messageId].
  String file(String messageId, int bytes, {bool thumbnail = false}) {
    final dir = Directory('${root.path}/$messageId')
      ..createSync(recursive: true);
    final path = '${dir.path}/${thumbnail ? 'thumb_' : ''}f.bin';
    File(path).writeAsBytesSync(List.filled(bytes, 7));
    return path;
  }

  Future<void> seedGroups() async {
    await writer.store(SyncCollectionKey.groups, myGroupPayload);
    await writer.store(SyncCollectionKey.groups, directGroupPayload);
    await writer.store(SyncCollectionKey.groupMembers, myMembershipPayload);
    await writer.store(SyncCollectionKey.groupMembers, peerMembershipPayload);
  }

  MessageMediaStorage storage() => MessageMediaStorage(db.groupDao);

  test(
      'le total est celui du disque, pas celui que le serveur annonce ; '
      'et les conversations sortent du plus lourd au plus léger', () async {
    await seedGroups();
    await writer.store(
      SyncCollectionKey.groupMessages,
      _message('m1', groupId: kGroupId, kind: 'image'),
    );
    await writer.store(
      SyncCollectionKey.groupMessages,
      _message('m2', groupId: kDirectGroupId, kind: 'video'),
    );
    await writer.store(
      SyncCollectionKey.groupMessages,
      // Annoncé par le serveur, **jamais descendu** : aucun chemin au magasin.
      _message('m3', groupId: kGroupId, kind: 'image'),
    );

    await db.groupDao.rememberLocalMedia('m1', path: file('m1', 1000));
    await db.groupDao.rememberLocalMedia(
      'm2',
      path: file('m2', 5000),
      thumbPath: file('m2', 200, thumbnail: true),
    );

    final usage = await storage().weigh();

    // 1000 + 5000 + 200 = 6200 o réellement sur le disque. La somme des
    // `mediaSize` annoncés vaudrait 29 997 000 o.
    expect(usage.totalBytes, 6200);
    expect(
      usage.conversations.map((c) => c.groupId).toList(),
      [kDirectGroupId, kGroupId],
      reason: 'le tête-à-tête pèse 5200 o, la chorale 1000 o',
    );
    final direct = usage.conversations.first;
    expect(direct.bytes, 5200);
    expect(direct.fileCount, 2, reason: 'le fichier et sa vignette');
    expect(usage.conversations.last.bytes, 1000);
    expect(
      usage.conversations.last.fileCount,
      1,
      reason: 'm3 n\'est pas descendu : il ne compte pas comme un fichier',
    );
    expect(usage.byKind, {
      MessageMediaKind.image: 1000,
      MessageMediaKind.video: 5200,
    });
  });

  test('un chemin noté dont le fichier a disparu pèse zéro, et ne mentit pas',
      () async {
    await seedGroups();
    await writer.store(
      SyncCollectionKey.groupMessages,
      _message('m1', groupId: kGroupId, kind: 'document'),
    );
    final path = file('m1', 4096);
    await db.groupDao.rememberLocalMedia('m1', path: path);
    // Le système a vidé le dossier, ou une purge a échoué à mi-chemin.
    File(path).deleteSync();

    final usage = await storage().weigh();

    expect(usage.totalBytes, 0);
    expect(usage.conversations, isEmpty);
    expect(usage.byKind, isEmpty);
    expect(usage.isEmpty, isTrue);
  });

  test('un vocal ne se compte pas avec une pièce audio', () async {
    await seedGroups();
    await writer.store(
      SyncCollectionKey.groupMessages,
      _message('m1', groupId: kGroupId, kind: 'audio'),
    );
    await writer.store(
      SyncCollectionKey.groupMessages,
      // `meta.voice: false` : une pièce audio jointe, pas un dictaphone.
      _message(
        'm2',
        groupId: kGroupId,
        kind: 'audio',
        meta: const {'voice': false},
      ),
    );
    await db.groupDao.rememberLocalMedia('m1', path: file('m1', 700));
    await db.groupDao.rememberLocalMedia('m2', path: file('m2', 300));

    final usage = await storage().weigh();

    expect(usage.byKind, {
      MessageMediaKind.voice: 700,
      MessageMediaKind.audio: 300,
    });
  });

  test(
      'vider une conversation emporte ses fichiers et ses lignes, '
      'et ne touche pas à la voisine', () async {
    await seedGroups();
    await writer.store(
      SyncCollectionKey.groupMessages,
      _message('m1', groupId: kGroupId, kind: 'image'),
    );
    await writer.store(
      SyncCollectionKey.groupMessages,
      _message('m2', groupId: kDirectGroupId, kind: 'image'),
    );
    final kept = file('m2', 400);
    final gone = file('m1', 900);
    final goneThumb = file('m1', 100, thumbnail: true);
    await db.groupDao
        .rememberLocalMedia('m1', path: gone, thumbPath: goneThumb);
    await db.groupDao.rememberLocalMedia('m2', path: kept);

    await storage().purgeConversation(kGroupId);

    expect(File(gone).existsSync(), isFalse);
    expect(File(goneThumb).existsSync(), isFalse);
    expect(File(kept).existsSync(), isTrue);
    // La ligne part avec le fichier : sans quoi la bulle tenterait un `File`
    // inexistant au lieu de redemander l'URL présignée.
    expect(
      (await db.groupDao.localMediaFiles()).map((r) => r.messageId).toList(),
      ['m2'],
    );
    expect((await storage().weigh()).totalBytes, 400);
  });

  test('vider un type traverse les conversations, et lui seul', () async {
    await seedGroups();
    await writer.store(
      SyncCollectionKey.groupMessages,
      _message('m1', groupId: kGroupId, kind: 'video'),
    );
    await writer.store(
      SyncCollectionKey.groupMessages,
      _message('m2', groupId: kDirectGroupId, kind: 'video'),
    );
    await writer.store(
      SyncCollectionKey.groupMessages,
      _message('m3', groupId: kGroupId, kind: 'image'),
    );
    final v1 = file('m1', 8000);
    final v2 = file('m2', 6000);
    final photo = file('m3', 500);
    await db.groupDao.rememberLocalMedia('m1', path: v1);
    await db.groupDao.rememberLocalMedia('m2', path: v2);
    await db.groupDao.rememberLocalMedia('m3', path: photo);

    await storage().purgeKind(MessageMediaKind.video);

    expect(File(v1).existsSync(), isFalse);
    expect(File(v2).existsSync(), isFalse);
    expect(File(photo).existsSync(), isTrue);
    final usage = await storage().weigh();
    expect(usage.byKind, {MessageMediaKind.image: 500});
    expect(usage.conversations.single.groupId, kGroupId);
  });
}
