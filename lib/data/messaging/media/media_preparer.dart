import 'dart:io';

import 'package:flutter/foundation.dart';

import 'image_degrade.dart';

/// Une image prête : le JPEG dégradé, ses dimensions.
class PreparedImage {
  const PreparedImage({
    required this.path,
    required this.width,
    required this.height,
    required this.sizeBytes,
  });

  final String path;
  final int width;
  final int height;
  final int sizeBytes;
}

/// Une vidéo prête : le MP4 compressé, sa vignette JPEG, sa durée.
class PreparedVideo {
  const PreparedVideo({
    required this.path,
    required this.sizeBytes,
    required this.durationSeconds,
    this.thumbPath,
    this.width,
    this.height,
  });

  final String path;
  final int sizeBytes;
  final int durationSeconds;
  final String? thumbPath;
  final int? width;
  final int? height;
}

/// Ce qu'on sait d'une vidéo **avant** de la compresser — assez pour refuser
/// une vidéo trop longue sans dépenser la batterie à la compresser.
class VideoProbe {
  const VideoProbe({required this.durationSeconds, this.width, this.height});

  final int durationSeconds;
  final int? width;
  final int? height;
}

/// **Le moteur de compression vidéo**, derrière une couture : un seul fichier
/// importe le greffon (`v_video_compressor_engine.dart`), et les tests posent un
/// double — sous `flutter test`, un canal de greffon lève
/// `MissingPluginException`.
abstract interface class VideoCompressionEngine {
  /// Durée et dimensions de la source, ou `null` si illisible.
  Future<VideoProbe?> probe(String sourcePath);

  /// Compresse [sourcePath] en MP4 (H.264 + AAC), **métadonnées retirées**
  /// (la position de la prise de vue, comme l'EXIF d'une photo). Rend le
  /// chemin produit, ou `null` en cas d'échec. [onProgress] reçoit `0..1`.
  Future<String?> compress(
    String sourcePath, {
    void Function(double progress)? onProgress,
  });

  /// Une vignette JPEG de la vidéo, ou `null`.
  Future<String?> thumbnail(String videoPath);
}

/// **Prépare un média avant la montée** : « le téléphone dégrade » (règle
/// d'Échanges). Lève [MediaPreparationException] quand la source est
/// illisible.
abstract interface class MediaPreparer {
  /// Dégrade une image (JPEG q80, ≤ 1600 px, **EXIF retiré**) vers [outPath].
  Future<PreparedImage> prepareImage(String sourcePath, String outPath);

  /// Lit la durée d'une vidéo, sans la compresser.
  Future<VideoProbe> probeVideo(String sourcePath);

  /// Compresse une vidéo et en tire la vignette.
  Future<PreparedVideo> prepareVideo(
    String sourcePath, {
    void Function(double progress)? onProgress,
  });
}

/// La source n'a pas pu être lue ou dégradée.
class MediaPreparationException implements Exception {
  const MediaPreparationException(this.reason);

  final String reason;

  @override
  String toString() => 'MediaPreparationException($reason)';
}

/// L'implémentation de l'appareil : l'image en pur Dart **hors du fil de
/// l'interface** (`compute`), la vidéo par [VideoCompressionEngine].
class DeviceMediaPreparer implements MediaPreparer {
  DeviceMediaPreparer({required VideoCompressionEngine video}) : _video = video;

  final VideoCompressionEngine _video;

  @override
  Future<PreparedImage> prepareImage(String sourcePath, String outPath) async {
    final DegradedImage degraded;
    try {
      final source = await File(sourcePath).readAsBytes();
      // Décoder 12 Mpx bloquerait l'interface une à deux secondes.
      degraded = await compute(degradeImageBytes, source);
    } on Object catch (error) {
      throw MediaPreparationException('image: $error');
    }
    await File(outPath).writeAsBytes(degraded.bytes, flush: true);
    return PreparedImage(
      path: outPath,
      width: degraded.width,
      height: degraded.height,
      sizeBytes: degraded.bytes.length,
    );
  }

  @override
  Future<VideoProbe> probeVideo(String sourcePath) async {
    final probe = await _video.probe(sourcePath);
    if (probe == null) throw const MediaPreparationException('video probe');
    return probe;
  }

  @override
  Future<PreparedVideo> prepareVideo(
    String sourcePath, {
    void Function(double progress)? onProgress,
  }) async {
    final probe = await probeVideo(sourcePath);
    final compressed =
        await _video.compress(sourcePath, onProgress: onProgress);
    if (compressed == null) {
      throw const MediaPreparationException('video compress');
    }
    final thumb = await _video.thumbnail(compressed);
    return PreparedVideo(
      path: compressed,
      sizeBytes: await File(compressed).length(),
      durationSeconds: probe.durationSeconds,
      thumbPath: thumb,
      width: probe.width,
      height: probe.height,
    );
  }
}
