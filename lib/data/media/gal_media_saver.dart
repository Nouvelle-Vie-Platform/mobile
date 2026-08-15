import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';

import 'media_saver.dart';

/// Implémentation réelle de [MediaSaver] : récupère les octets de l'image via
/// `dio`, puis les remet à `gal` pour l'ajout à la galerie Photos.
///
/// **Pas de support web** (`gal` ne l'implémente pas) : l'appel est refusé tôt
/// par [kIsWeb] avec [MediaSaveError.unsupported], et l'écran masque de toute
/// façon le bouton sur le web.
class GalMediaSaver extends MediaSaver {
  const GalMediaSaver();

  @override
  Future<void> saveImageFromUrl(String url) async {
    if (kIsWeb) {
      throw const MediaSaveException(MediaSaveError.unsupported);
    }
    final Uint8List bytes;
    try {
      final res = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = res.data;
      if (data == null || data.isEmpty) {
        throw const MediaSaveException(MediaSaveError.network);
      }
      bytes = Uint8List.fromList(data);
    } on DioException {
      throw const MediaSaveException(MediaSaveError.network);
    }

    try {
      await Gal.putImageBytes(bytes);
    } on GalException catch (e) {
      throw MediaSaveException(
        e.type == GalExceptionType.accessDenied
            ? MediaSaveError.permissionDenied
            : MediaSaveError.unknown,
      );
    }
  }
}
