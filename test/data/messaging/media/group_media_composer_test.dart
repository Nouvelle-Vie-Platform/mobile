/// **L'envoi d'un média** (M4, #143 — reprend #98) : écho avant la montée,
/// bornes vérifiées **avant** de monter, progression, échec visible et
/// réessayable, reprise sans remonter.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/messaging/media/group_media_composer.dart';
import 'package:maison_du_miracle/data/messaging/media/group_media_transport.dart';
import 'package:maison_du_miracle/data/messaging/media/media_outbox.dart';
import 'package:maison_du_miracle/data/messaging/media/media_preparer.dart';
import 'package:maison_du_miracle/data/messaging/media/media_upload_progress.dart';
import 'package:maison_du_miracle/data/repositories/group_message_composer.dart';
import 'package:maison_du_miracle/data/repositories/group_message_sender.dart';
import 'package:maison_du_miracle/data/repositories/store_echanges_repository.dart';
import 'package:maison_du_miracle/models/echanges_view.dart';
import 'package:maison_du_miracle/models/message_media.dart';

import '../../local/local_database_fixtures.dart';

/// Le chemin présigné, **scripté** : il note tout, et il échoue sur commande.
class _ScriptedTransport implements GroupMediaTransport {
  int maxBytes = 4000000;
  int? maxDurationSeconds = 600;

  /// Le prochain `upload` lève (panne de réseau).
  bool failUpload = false;

  /// Le prochain `sendMessage` lève ce code (un refus du serveur).
  String? rejectSendWith;

  final List<Map<String, Object?>> tickets = [];
  final List<String> uploads = [];
  final List<Map<String, Object?>> messages = [];

  /// Ce que le magasin local montrait **au moment** de la montée.
  final List<Future<void> Function()> onUpload = [];

  int _keys = 0;

  @override
  Future<MediaUploadTicket> openUpload({
    required String groupId,
    required String kind,
    String? contentType,
    bool? voice,
  }) async {
    tickets.add({'kind': kind, 'contentType': contentType, 'voice': voice});
    return MediaUploadTicket(
      key: 'group-media/$groupId/k${_keys++}',
      url: 'https://store.test/put',
      contentType: contentType ?? 'audio/mp4',
      maxBytes: maxBytes,
      maxDurationSeconds: maxDurationSeconds,
    );
  }

  @override
  Future<void> upload(
    MediaUploadTicket ticket,
    String path, {
    void Function(double progress)? onProgress,
  }) async {
    for (final hook in onUpload) {
      await hook();
    }
    if (failUpload) {
      failUpload = false;
      throw const GroupMediaTransportException(null);
    }
    onProgress?.call(0.5);
    onProgress?.call(1);
    uploads.add(ticket.key);
  }

  @override
  Future<void> sendMessage({
    required String groupId,
    required String clientMessageId,
    required DateTime clientCreatedAt,
    required String mediaKind,
    String? body,
    String? mediaKey,
    int? mediaDuration,
    Map<String, Object?>? mediaMeta,
    String? mediaThumbnailKey,
  }) async {
    final code = rejectSendWith;
    if (code != null) {
      rejectSendWith = null;
      throw GroupMediaTransportException(code, status: 422);
    }
    messages.add({
      'clientMessageId': clientMessageId,
      'mediaKind': mediaKind,
      'body': body,
      'mediaKey': mediaKey,
      'mediaDuration': mediaDuration,
      'mediaMeta': mediaMeta,
      'mediaThumbnailKey': mediaThumbnailKey,
    });
  }
}

/// Un préparateur qui « dégrade » en recopiant, et dit des dimensions fixes.
class _CopyPreparer implements MediaPreparer {
  int prepared = 0;

  @override
  Future<PreparedImage> prepareImage(String sourcePath, String outPath) async {
    prepared++;
    await File(sourcePath).copy(outPath);
    return PreparedImage(
      path: outPath,
      width: 1600,
      height: 1200,
      sizeBytes: await File(outPath).length(),
    );
  }

  @override
  Future<VideoProbe> probeVideo(String sourcePath) async =>
      const VideoProbe(durationSeconds: 400);

  @override
  Future<PreparedVideo> prepareVideo(
    String sourcePath, {
    void Function(double progress)? onProgress,
  }) =>
      throw const MediaPreparationException('pas appelé');
}

void main() {
  late AppDatabase db;
  late _ScriptedTransport transport;
  late _CopyPreparer preparer;
  late MediaUploadProgress progress;
  late GroupMediaComposer composer;
  late Directory dir;
  late List<double> seenProgress;
  var minted = 0;

  const groupId = 'g-1';
  const me = 'u-me';

  setUp(() {
    db = openTestDatabase();
    transport = _ScriptedTransport();
    preparer = _CopyPreparer();
    progress = MediaUploadProgress();
    seenProgress = [];
    progress.addListener(() {
      final value = progress.value.values;
      if (value.isNotEmpty) seenProgress.add(value.first);
    });
    dir = Directory.systemTemp.createTempSync('m4_outbox');
    composer = GroupMediaComposer(
      dao: db.groupDao,
      transport: transport,
      preparer: preparer,
      outbox: MediaOutbox(root: () async => dir),
      progress: progress,
      resynchronize: () async {},
      now: () => DateTime.utc(2026, 10, 6, 10),
      mintId: () => 'c-${minted++}',
    );
  });

  tearDown(() async {
    await db.close();
    progress.dispose();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  String sourceFile(String name, int bytes) {
    final file = File('${dir.path}/../m4_src_${minted}_$name')
      ..writeAsBytesSync(List<int>.filled(bytes, 7));
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });
    return file.path;
  }

  Future<List<GroupMessageView>> thread() =>
      StoreEchangesRepository(db.groupDao, userId: me)
          .thread(groupId)
          .first;

  group('L’écho paraît avant la montée', () {
    test('un vocal est au fil, « en cours d’envoi », pendant qu’il monte',
        () async {
      List<GroupMessageView>? duringUpload;
      transport.onUpload.add(() async => duringUpload = await thread());

      await composer.send(
        groupId: groupId,
        media: OutgoingMedia.voice(
          path: sourceFile('voice.m4a', 2000),
          durationSeconds: 8,
          waveform: const [10, 60, 30],
        ),
      );

      final echo = duringUpload!.single;
      expect(echo.delivery, MessageDelivery.sending);
      expect(echo.media!.kind, MessageMediaKind.voice);
      expect(echo.media!.waveform, [10, 60, 30]);
      expect(echo.body, isNull, reason: 'un vocal sans légende n’a pas de texte');

      // Puis le message part, sous la même clé, en citant la clé montée.
      expect(transport.tickets.single['kind'], 'audio');
      expect(transport.messages.single['clientMessageId'], 'c-0');
      expect(transport.messages.single['mediaKey'], transport.uploads.single);
      expect(transport.messages.single['mediaMeta'], {
        'voice': true,
        'waveform': [10, 60, 30],
      });
    });

    test('la progression de la montée est rapportée, puis effacée', () async {
      await composer.send(
        groupId: groupId,
        media: OutgoingMedia.voice(
          path: sourceFile('voice.m4a', 2000),
          durationSeconds: 3,
        ),
      );
      expect(seenProgress, containsAllInOrder([0.0, 0.5, 1.0]));
      expect(progress.value, isEmpty);
    });
  });

  group('Les bornes, avant toute montée', () {
    test('un fichier trop lourd est refusé ici, avec sa cause, sans montée',
        () async {
      transport.maxBytes = 1000;

      final id = await composer.send(
        groupId: groupId,
        media: OutgoingMedia.document(
          path: sourceFile('gros.pdf', 5000),
          name: 'gros.pdf',
          mime: 'application/pdf',
          sizeBytes: 5000,
        ),
      );

      expect(transport.uploads, isEmpty, reason: 'aucune montée inutile');
      expect(transport.messages, isEmpty);
      final echo = (await thread()).single;
      expect(echo.id, id);
      expect(echo.delivery, MessageDelivery.failed);
      expect(echo.mediaError, MediaSendError.tooLarge);
      // Le type déclaré d'un document part avec le ticket.
      expect(transport.tickets.single['contentType'], 'application/pdf');
    });

    test('un vocal au-delà du plafond de durée est refusé côté client', () async {
      transport.maxDurationSeconds = 600;

      await composer.send(
        groupId: groupId,
        media: OutgoingMedia.voice(
          path: sourceFile('long.m4a', 2000),
          durationSeconds: 601,
        ),
      );

      expect(transport.uploads, isEmpty);
      final echo = (await thread()).single;
      expect(echo.delivery, MessageDelivery.failed);
      expect(echo.mediaError, MediaSendError.tooLong);
    });

    test('une vidéo trop longue est refusée AVANT d’être compressée', () async {
      transport.maxDurationSeconds = 180;

      await composer.send(
        groupId: groupId,
        media: OutgoingMedia.video(path: sourceFile('film.mp4', 3000)),
      );

      // `_CopyPreparer.prepareVideo` lèverait : on n'y est jamais allé.
      final echo = (await thread()).single;
      expect(echo.mediaError, MediaSendError.tooLong);
      expect(transport.uploads, isEmpty);
    });
  });

  group('Un échec reste à l’écran, réessayable', () {
    test('une panne de réseau à la montée : échec sans cause, puis reprise',
        () async {
      transport.failUpload = true;
      final id = await composer.send(
        groupId: groupId,
        media: OutgoingMedia.image(path: sourceFile('photo.jpg', 3000)),
      );

      var echo = (await thread()).single;
      expect(echo.delivery, MessageDelivery.failed);
      expect(echo.mediaError, isNull, reason: 'le réseau n’a pas de cause à dire');
      expect(echo.media!.localPath, isNotNull, reason: 'la photo reste peinte');

      expect(await composer.deliver(id, manual: true), isTrue);
      // L'image n'a été dégradée qu'une fois : la reprise part du fichier prêt.
      expect(preparer.prepared, 1);
      expect(transport.messages.single['mediaMeta'], {
        'width': 1600,
        'height': 1200,
      });
    });

    test('un refus d’envoi garde la clé montée : la reprise ne remonte pas',
        () async {
      transport.rejectSendWith = 'E_SOMETHING_TRANSIENT';
      final id = await composer.send(
        groupId: groupId,
        media: OutgoingMedia.voice(
          path: sourceFile('v.m4a', 1000),
          durationSeconds: 2,
        ),
      );
      expect(transport.uploads, hasLength(1));

      await composer.deliver(id, manual: true);
      expect(transport.uploads, hasLength(1), reason: 'déjà monté');
      expect(transport.messages, hasLength(1));
    });

    test('« objet absent » oublie la clé : la reprise remonte le fichier',
        () async {
      transport.rejectSendWith = 'E_GROUP_MEDIA_MISSING';
      final id = await composer.send(
        groupId: groupId,
        media: OutgoingMedia.voice(
          path: sourceFile('v.m4a', 1000),
          durationSeconds: 2,
        ),
      );

      await composer.deliver(id, manual: true);
      expect(transport.uploads, hasLength(2));
      expect(transport.messages.single['mediaKey'], transport.uploads.last);
    });

    test('le renvoi automatique ne rejoue pas un échec définitif', () async {
      transport.maxBytes = 10;
      final id = await composer.send(
        groupId: groupId,
        media: OutgoingMedia.voice(
          path: sourceFile('v.m4a', 1000),
          durationSeconds: 2,
        ),
      );
      final tickets = transport.tickets.length;

      expect(await composer.deliver(id), isFalse);
      expect(transport.tickets.length, tickets, reason: 'rien n’est retenté');
    });

    test('le composeur de texte délègue le renvoi d’un écho de média',
        () async {
      transport.failUpload = true;
      final id = await composer.send(
        groupId: groupId,
        media: OutgoingMedia.voice(
          path: sourceFile('v.m4a', 1000),
          durationSeconds: 2,
        ),
      );

      final text = GroupMessageComposer(
        dao: db.groupDao,
        sender: const InertGroupMessageSender(),
        resynchronize: () async {},
        resendMedia: (id, {required manual}) =>
            composer.deliver(id, manual: manual),
      );
      await text.resendUnconfirmed();

      expect(transport.messages.single['clientMessageId'], id);
    });
  });

  group('Position et contact : des données, pas un fichier', () {
    test('une position part sans ticket ni montée', () async {
      await composer.send(
        groupId: groupId,
        media: const OutgoingMedia.location(
          latitude: 6.1319,
          longitude: 1.2228,
          label: ' Temple ',
        ),
      );

      expect(transport.tickets, isEmpty);
      expect(transport.uploads, isEmpty);
      expect(transport.messages.single['mediaKind'], 'location');
      expect(transport.messages.single['mediaMeta'], {
        'latitude': 6.1319,
        'longitude': 1.2228,
        'label': 'Temple',
      });
    });

    test('un contact part avec son nom et ses numéros', () async {
      await composer.send(
        groupId: groupId,
        media: const OutgoingMedia.contact(
          name: 'Diacre Kossi',
          phones: [ContactPhone(number: '+228 90 11 22 33')],
        ),
      );

      expect(transport.messages.single['mediaMeta'], {
        'name': 'Diacre Kossi',
        'phones': [
          {'number': '+228 90 11 22 33'},
        ],
      });
    });
  });

  test('un fichier audio déclare son type et `voice: false`', () async {
    await composer.send(
      groupId: groupId,
      media: OutgoingMedia.audioFile(
        path: sourceFile('chant.mp3', 1000),
        name: 'chant.mp3',
        mime: 'audio/mpeg',
      ),
    );

    expect(transport.tickets.single, {
      'kind': 'audio',
      'contentType': 'audio/mpeg',
      'voice': false,
    });
  });

  test('une image légendée part avec son texte', () async {
    await composer.send(
      groupId: groupId,
      media: OutgoingMedia.image(
        path: sourceFile('p.jpg', 1000),
        caption: 'Le culte de dimanche',
      ),
    );
    expect(transport.messages.single['body'], 'Le culte de dimanche');
    expect(transport.tickets.single['kind'], 'image');
  });
}
