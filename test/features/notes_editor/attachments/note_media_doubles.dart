import 'dart:io';
import 'dart:typed_data';

import 'package:maison_du_miracle/data/messaging/media/group_media_transport.dart';
import 'package:maison_du_miracle/data/messaging/media/media_preparer.dart';
import 'package:maison_du_miracle/data/notes_media/note_media_transport.dart';
import 'package:maison_du_miracle/data/notes_media/note_media_urls.dart';

/// Le chemin présigné des notes, **scripté** : il note tout, échoue sur
/// commande, et rend les bornes qu'on lui donne.
class ScriptedNoteTransport implements NoteMediaTransport {
  int maxBytes = 2000000;
  int? maxDurationSeconds = 180;

  /// Le prochain `upload` lève (panne de réseau).
  bool failUpload = false;

  /// Le prochain `openUpload` lève ce code (un refus du serveur).
  String? rejectTicketWith;

  final List<Map<String, Object?>> tickets = [];
  final List<String> uploads = [];
  int _keys = 0;

  @override
  Future<MediaUploadTicket> openUpload({
    required String kind,
    String? contentType,
  }) async {
    final code = rejectTicketWith;
    if (code != null) {
      rejectTicketWith = null;
      throw GroupMediaTransportException(code, status: 422);
    }
    tickets.add({'kind': kind, 'contentType': contentType});
    return MediaUploadTicket(
      key: 'note-media/owner/k${_keys++}.${kind == 'thumbnail' ? 'jpg' : kind}',
      url: 'https://store.test/put',
      contentType: contentType ?? 'image/jpeg',
      maxBytes: kind == 'thumbnail' ? 200000 : maxBytes,
      maxDurationSeconds: kind == 'video' ? maxDurationSeconds : null,
    );
  }

  @override
  Future<void> upload(
    MediaUploadTicket ticket,
    String path, {
    void Function(double progress)? onProgress,
  }) async {
    if (failUpload) {
      failUpload = false;
      throw const GroupMediaTransportException(null);
    }
    uploads.add(ticket.key);
  }
}

/// Un préparateur qui « dégrade » en recopiant ; dimensions et durée fixes.
class CopyPreparer implements MediaPreparer {
  int images = 0;
  int videos = 0;
  int probes = 0;
  int videoSeconds = 42;

  @override
  Future<PreparedImage> prepareImage(String sourcePath, String outPath) async {
    images++;
    await File(sourcePath).copy(outPath);
    return PreparedImage(
      path: outPath,
      width: 1600,
      height: 1200,
      sizeBytes: await File(outPath).length(),
    );
  }

  @override
  Future<VideoProbe> probeVideo(String sourcePath) async {
    probes++;
    return VideoProbe(durationSeconds: videoSeconds, width: 1280, height: 720);
  }

  @override
  Future<PreparedVideo> prepareVideo(
    String sourcePath, {
    void Function(double progress)? onProgress,
  }) async {
    videos++;
    final out = '$sourcePath.compressed.mp4';
    await File(sourcePath).copy(out);
    final thumb = '$sourcePath.thumb.jpg';
    File(thumb).writeAsBytesSync(List<int>.filled(100, 1));
    return PreparedVideo(
      path: out,
      sizeBytes: await File(out).length(),
      durationSeconds: videoSeconds,
      thumbPath: thumb,
      width: 1280,
      height: 720,
    );
  }
}

/// Des URL signées en mémoire : clé → URL, et les octets d'une clé.
class FakeNoteMediaUrls implements NoteMediaUrls {
  final Map<String, Uint8List> stored = {};
  final List<String> resolved = [];

  @override
  Future<String?> resolve(String key) async {
    resolved.add(key);
    return stored.containsKey(key) ? 'https://store.test/$key' : null;
  }

  @override
  Future<String?> download(String key, String fileName) async => null;

  @override
  Future<Uint8List?> bytes(String key) async {
    resolved.add(key);
    return stored[key];
  }
}
