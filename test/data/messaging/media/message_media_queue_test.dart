/// **La descente automatique des médias reçus** (T3, #225).
///
/// Les tests qui portent la tranche sont ceux du **réseau** et de
/// l'**historique** : en données mobiles, le compteur de téléchargements doit
/// être à **zéro** — pas « sans erreur » —, et un média antérieur au chantier
/// ne descend que si une bulle l'a affiché.
///
/// Le double de [GroupMediaUrls] **note dans le magasin** comme le vrai
/// (`rememberLocalMedia`, T1) : c'est ce qui permet de vérifier qu'un média
/// descendu **quitte** la file, laquelle est dérivée du magasin et non d'une
/// table à elle.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/downloads/disk_space.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/local/group_dao.dart';
import 'package:maison_du_miracle/data/local/sync_dao.dart';
import 'package:maison_du_miracle/data/messaging/media/group_media_urls.dart';
import 'package:maison_du_miracle/data/messaging/media/message_media_queue.dart';
import 'package:maison_du_miracle/data/messaging/messaging_store_writer.dart';
import 'package:maison_du_miracle/data/network/network_transport.dart';
import 'package:maison_du_miracle/models/media_preferences.dart';

import '../../../helpers/sync_fixtures.dart';
import '../../local/local_database_fixtures.dart';

/// L'instant qui sépare l'arrivé de l'historique, dans tous ces tests.
final DateTime kSince = DateTime.utc(2026, 10, 15, 12);

/// Compte les téléchargements, et **note au magasin** comme le vrai.
class _RecordingUrls implements GroupMediaUrls {
  _RecordingUrls(this.dao);

  final GroupDao dao;

  /// `<messageId>/<nom>`, dans l'ordre des appels. La vignette porte `thumb_`.
  final List<String> downloads = [];

  /// Les messages dont le téléchargement échoue (réseau, 404).
  final Set<String> failing = {};

  @override
  Future<String?> resolve({
    required String groupId,
    required String messageId,
    bool thumbnail = false,
  }) async =>
      'https://origine.test/$messageId';

  @override
  Future<String?> download({
    required String groupId,
    required String messageId,
    required String fileName,
    bool thumbnail = false,
  }) async {
    final name = '${thumbnail ? 'thumb_' : ''}$fileName';
    downloads.add('$messageId/$name');
    if (failing.contains(messageId)) return null;
    final path = '/magasin/$messageId/$name';
    await dao.rememberLocalMedia(
      messageId,
      path: thumbnail ? null : path,
      thumbPath: thumbnail ? path : null,
    );
    return path;
  }
}

void main() {
  late AppDatabase db;
  late MessagingStoreWriter writer;
  late _RecordingUrls urls;
  late FixedNetworkTransport network;

  setUp(() async {
    db = openTestDatabase();
    writer = MessagingStoreWriter(db);
    urls = _RecordingUrls(db.groupDao);
    network = FixedNetworkTransport();
    await writer.store(SyncCollectionKey.groups, myGroupPayload);
    await writer.store(SyncCollectionKey.groupMembers, myMembershipPayload);
    await writer.store(SyncCollectionKey.groupMembers, peerMembershipPayload);
  });

  tearDown(() async {
    await network.dispose();
    await db.close();
  });

  MessageMediaQueue queue({
    ChatMediaDescent descent = ChatMediaDescent.wifi,
    int? freeBytes,
  }) =>
      MessageMediaQueue(
        arrived: () => db.groupDao.watchMediaToDescend(kSince).first,
        urls: urls,
        network: network,
        descent: () async => descent,
        diskSpace: FixedDiskSpace(freeBytes),
      );

  /// Range un message-média servi par le serveur. [minutesAfterSince] négatif
  /// le place dans l'**historique**.
  Future<String> receive(
    String suffix, {
    required String kind,
    required String key,
    String? thumbnailKey,
    int size = 240000,
    int minutesAfterSince = 1,
    String? deletedAt,
  }) async {
    final id = '019a3000-0000-7000-8000-00000000$suffix';
    await writer.store(SyncCollectionKey.groupMessages, {
      'id': id,
      'groupId': kGroupId,
      'authorId': kPeerId,
      'isSystem': false,
      'body': null,
      'mediaKey': key,
      'mediaKind': kind,
      'mediaDuration': null,
      'mediaMeta': null,
      'mediaSize': size,
      'mediaMime': 'image/jpeg',
      'mediaThumbnailKey': thumbnailKey,
      'clientMessageId': null,
      'clientCreatedAt': null,
      'createdAt':
          kSince.add(Duration(minutes: minutesAfterSince)).toIso8601String(),
      'deletedAt': deletedAt,
    });
    return id;
  }

  Future<List<MediaToDescend>> waiting() =>
      db.groupDao.watchMediaToDescend(kSince).first;

  group('La file de la descente', () {
    test('un média arrivé descend, et quitte la file', () async {
      final id = await receive('0000img1',
          kind: 'image', key: 'group-media/$kGroupId/photo.jpg');
      expect((await waiting()).map((m) => m.messageId), [id]);

      await queue().pump();

      expect(urls.downloads, ['$id/photo.jpg']);
      // Il quitte la file parce que le magasin porte son chemin — pas parce
      // qu'on l'a rayé d'une table de file : il n'y en a pas.
      expect(await waiting(), isEmpty);
    });

    test('un second passage ne le redescend pas', () async {
      await receive('0000img2',
          kind: 'image', key: 'group-media/$kGroupId/b.jpg');
      final q = queue();
      await q.pump();
      await q.pump();

      expect(urls.downloads, hasLength(1));
    });

    test('la vignette d’une vidéo descend après son fichier', () async {
      final id = await receive(
        '0000vid1',
        kind: 'video',
        key: 'group-media/$kGroupId/clip.mp4',
        thumbnailKey: 'group-media/$kGroupId/clip-thumb.jpg',
      );

      await queue().pump();

      expect(urls.downloads, ['$id/clip.mp4', '$id/thumb_clip-thumb.jpg']);
    });

    test('une position (sans clé) n’a rien à descendre', () async {
      await writer.store(SyncCollectionKey.groupMessages, {
        'id': '019a3000-0000-7000-8000-000000000loc1',
        'groupId': kGroupId,
        'authorId': kPeerId,
        'isSystem': false,
        'body': null,
        'mediaKey': null,
        'mediaKind': 'location',
        'mediaDuration': null,
        'mediaMeta': '{"latitude":6.13,"longitude":1.22}',
        'mediaSize': null,
        'mediaMime': null,
        'mediaThumbnailKey': null,
        'clientMessageId': null,
        'clientCreatedAt': null,
        'createdAt': kSince.add(const Duration(minutes: 1)).toIso8601String(),
        'deletedAt': null,
      });

      await queue().pump();

      expect(urls.downloads, isEmpty);
      expect(await waiting(), isEmpty);
    });

    test('un média supprimé pour tous ne descend pas', () async {
      await receive('0000del1',
          kind: 'image',
          key: 'group-media/$kGroupId/d.jpg',
          deletedAt: '2026-10-15T13:00:00.000Z');

      await queue().pump();

      expect(urls.downloads, isEmpty);
    });
  });

  group('Le réseau — la décision du cadrage', () {
    test('en données mobiles, pas un octet ne part', () async {
      await receive('0000net1',
          kind: 'image', key: 'group-media/$kGroupId/n.jpg');
      network.emit(true);

      await queue().pump();

      // Zéro, et non « pas d'erreur » : c'est le coût du forfait togolais.
      expect(urls.downloads, isEmpty);
      // Et rien n'est perdu : la file est dérivée du magasin.
      expect(await waiting(), hasLength(1));
    });

    test('le wifi revenu, le même passage descend', () async {
      final id = await receive('0000net2',
          kind: 'image', key: 'group-media/$kGroupId/w.jpg');
      final q = queue();
      network.emit(true);
      await q.pump();
      expect(urls.downloads, isEmpty);

      network.emit(false);
      await q.pump();

      expect(urls.downloads, ['$id/w.jpg']);
    });

    test('« Toujours » part en données mobiles', () async {
      final id = await receive('0000net3',
          kind: 'image', key: 'group-media/$kGroupId/a.jpg');
      network.emit(true);

      await queue(descent: ChatMediaDescent.always).pump();

      expect(urls.downloads, ['$id/a.jpg']);
    });

    test('« Jamais » ne descend rien, même en wifi', () async {
      await receive('0000net4',
          kind: 'image', key: 'group-media/$kGroupId/j.jpg');

      await queue(descent: ChatMediaDescent.never).pump();

      expect(urls.downloads, isEmpty);
    });
  });

  group('L’historique', () {
    test('un média antérieur au chantier ne descend pas tout seul', () async {
      await receive('0000old1',
          kind: 'image',
          key: 'group-media/$kGroupId/vieux.jpg',
          minutesAfterSince: -60);

      await queue().pump();

      expect(urls.downloads, isEmpty);
    });

    test('mais un média affiché est gardé', () async {
      final id = await receive('0000old2',
          kind: 'image',
          key: 'group-media/$kGroupId/affiche.jpg',
          minutesAfterSince: -60);
      final q = queue();

      q.keep(
        groupId: kGroupId,
        messageId: id,
        mediaKey: 'group-media/$kGroupId/affiche.jpg',
        sizeBytes: 240000,
      );
      await q.pump();

      expect(urls.downloads, ['$id/affiche.jpg']);
    });

    test('un média affiché en données mobiles attend le wifi lui aussi',
        () async {
      final id = await receive('0000old3',
          kind: 'image',
          key: 'group-media/$kGroupId/attente.jpg',
          minutesAfterSince: -60);
      final q = queue();
      network.emit(true);

      q.keep(
        groupId: kGroupId,
        messageId: id,
        mediaKey: 'group-media/$kGroupId/attente.jpg',
      );
      await q.pump();
      // Peindre l'image coûte déjà ses octets ; l'écrire en coûterait une
      // seconde fois, et pas sur un forfait qu'on n'a pas autorisé.
      expect(urls.downloads, isEmpty);

      network.emit(false);
      await q.pump();

      expect(urls.downloads, ['$id/attente.jpg']);
    });

    test('« Jamais » vide la file des affichés au lieu de l’accumuler',
        () async {
      final id = await receive('0000old4',
          kind: 'image',
          key: 'group-media/$kGroupId/x.jpg',
          minutesAfterSince: -60);
      final q = queue(descent: ChatMediaDescent.never);
      q.keep(
        groupId: kGroupId,
        messageId: id,
        mediaKey: 'group-media/$kGroupId/x.jpg',
      );
      await q.pump();

      expect(urls.downloads, isEmpty);
    });
  });

  group('L’espace disque — le pré-check avant le premier octet', () {
    test('un média plus gros que la place libre n’est pas demandé', () async {
      await receive('0000spc1',
          kind: 'image', key: 'group-media/$kGroupId/gros.jpg', size: 240000);

      await queue(freeBytes: 1000).pump();

      // Avant le premier octet, parce que la taille vient du serveur.
      expect(urls.downloads, isEmpty);
    });

    test('la place est décomptée au fil du passage', () async {
      final first = await receive('0000spc2',
          kind: 'image',
          key: 'group-media/$kGroupId/un.jpg',
          size: 200000,
          minutesAfterSince: 1);
      await receive('0000spc3',
          kind: 'image',
          key: 'group-media/$kGroupId/deux.jpg',
          size: 200000,
          minutesAfterSince: 2);

      // 300 000 octets : le premier passe, le second ne tient plus.
      await queue(freeBytes: 300000).pump();

      expect(urls.downloads, ['$first/un.jpg']);
    });

    test('espace inconnu : on laisse passer (fail-open)', () async {
      final id = await receive('0000spc4',
          kind: 'image', key: 'group-media/$kGroupId/inconnu.jpg');

      await queue().pump();

      expect(urls.downloads, ['$id/inconnu.jpg']);
    });
  });

  group('Les échecs', () {
    test('trois échecs d’affilée arrêtent le passage', () async {
      for (var i = 1; i <= 5; i++) {
        final id = await receive('00000ko$i',
            kind: 'image',
            key: 'group-media/$kGroupId/ko$i.jpg',
            minutesAfterSince: i);
        urls.failing.add(id);
      }

      await queue().pump();

      // Ce n'est plus un média fautif, c'est le réseau : on arrête, et le
      // prochain cycle réessaiera la même file.
      expect(urls.downloads, hasLength(3));
      expect(await waiting(), hasLength(5));
    });

    test('un média définitivement cassé ne bloque pas celui d’après', () async {
      final broken = await receive('00000ko6',
          kind: 'image',
          key: 'group-media/$kGroupId/casse.jpg',
          minutesAfterSince: 1);
      urls.failing.add(broken);
      final fine = await receive('00000ok1',
          kind: 'image',
          key: 'group-media/$kGroupId/bon.jpg',
          minutesAfterSince: 2);

      await queue().pump();

      expect(urls.downloads, ['$broken/casse.jpg', '$fine/bon.jpg']);
    });
  });
}
