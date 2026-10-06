import 'package:v_video_compressor/v_video_compressor.dart';

import 'media_preparer.dart';

/// **Le seul fichier du dépôt qui importe `v_video_compressor`** (M4, #143).
///
/// Pourquoi ce greffon et pas `video_compress` (le plus téléchargé) : celui-ci
/// est un **Swift Package** (CocoaPods ne ressuscite pas dans ce dépôt), écrit
/// en Kotlin, maintenu (2026) ; `video_compress` n'a pas bougé depuis
/// février 2025 et ne s'installe que par CocoaPods.
///
/// Réglages : qualité **moyenne** (720p), **H.264** imposé (lisible partout,
/// le serveur n'accepte que `video/mp4`), **métadonnées retirées** — la
/// position GPS d'une vidéo voyage dans ses métadonnées comme celle d'une photo
/// dans son EXIF. `fallbackToOriginalIfNotSmaller: false` : rendre l'original
/// pourrait rendre un `.mov` HEVC que le serveur refuserait.
class VVideoCompressionEngine implements VideoCompressionEngine {
  VVideoCompressionEngine({VVideoCompressor? compressor})
      : _compressor = compressor ?? VVideoCompressor();

  final VVideoCompressor _compressor;

  @override
  Future<VideoProbe?> probe(String sourcePath) async {
    try {
      final info = await _compressor.getVideoInfo(sourcePath);
      if (info == null) return null;
      return VideoProbe(
        durationSeconds: (info.durationMillis / 1000).ceil(),
        width: info.width > 0 ? info.width : null,
        height: info.height > 0 ? info.height : null,
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<String?> compress(
    String sourcePath, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final result = await _compressor.compressVideo(
        sourcePath,
        const VVideoCompressionConfig.medium(
          fallbackToOriginalIfNotSmaller: false,
          includeMetadata: false,
          copyMetadata: false,
          advanced: VVideoAdvancedConfig(videoCodec: VVideoCodec.h264),
        ),
        onProgress: onProgress,
      );
      return result?.compressedFilePath;
    } on Object {
      return null;
    }
  }

  @override
  Future<String?> thumbnail(String videoPath) async {
    try {
      final result = await _compressor.getVideoThumbnail(
        videoPath,
        const VVideoThumbnailConfig(
          timeMs: 500,
          maxWidth: 480,
          maxHeight: 480,
          quality: 70,
        ),
      );
      return result?.thumbnailPath;
    } on Object {
      return null;
    }
  }
}
