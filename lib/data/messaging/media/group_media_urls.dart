import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_client.dart';

/// **Échanger la clé d'un média contre une URL de lecture** (M4, #143).
///
/// `GET /groups/:id/messages/:mid/media` répond **302** vers une URL présignée
/// du magasin, valable une heure. On ne laisse **pas** le lecteur (image,
/// audio, vidéo) suivre la redirection avec l'en-tête `Authorization` : il le
/// recopierait vers le magasin, qui refuserait une requête portant deux
/// authentifications — et le jeton du fidèle partirait chez un tiers. On lit
/// donc le `Location` ici, sans suivre, et on donne au lecteur une URL **nue**.
///
/// L'URL est gardée en mémoire **50 minutes** (elle en vaut 60) : une image
/// revue en remontant le fil ne se retélécharge pas sous une URL neuve, et
/// aucune URL signée n'est jamais écrite sur le disque.
abstract interface class GroupMediaUrls {
  /// L'URL de lecture du média de [messageId] — ou de sa vignette —, ou
  /// `null` si elle ne peut pas être obtenue (hors ligne, média retiré).
  Future<String?> resolve({
    required String groupId,
    required String messageId,
    bool thumbnail = false,
  });

  /// **Télécharge** le média dans un fichier temporaire nommé [fileName] —
  /// pour l'ouvrir par l'application du système (un document). `null` en
  /// cas d'échec.
  Future<String?> download({
    required String groupId,
    required String messageId,
    required String fileName,
  });
}

class HttpGroupMediaUrls implements GroupMediaUrls {
  HttpGroupMediaUrls({
    ApiClient? client,
    Dio? storeClient,
    DateTime Function()? now,
  })  : _api = (client ?? ApiClient.instance).dio,
        _store = storeClient ?? Dio(),
        _now = now ?? DateTime.now;

  final Dio _api;
  final Dio _store;
  final DateTime Function() _now;

  static const Duration _ttl = Duration(minutes: 50);
  final Map<String, ({String url, DateTime at})> _cache = {};

  @override
  Future<String?> resolve({
    required String groupId,
    required String messageId,
    bool thumbnail = false,
  }) async {
    final cacheKey = '$messageId${thumbnail ? '#thumb' : ''}';
    final cached = _cache[cacheKey];
    if (cached != null && _now().difference(cached.at) < _ttl) {
      return cached.url;
    }
    try {
      final response = await _api.get<Object?>(
        '/groups/$groupId/messages/$messageId/media',
        queryParameters: thumbnail ? {'variant': 'thumbnail'} : null,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      final location = response.headers.value(HttpHeaders.locationHeader);
      if (location == null || location.isEmpty) return null;
      _cache[cacheKey] = (url: location, at: _now());
      return location;
    } on DioException {
      return null;
    }
  }

  @override
  Future<String?> download({
    required String groupId,
    required String messageId,
    required String fileName,
  }) async {
    final url = await resolve(groupId: groupId, messageId: messageId);
    if (url == null) return null;
    try {
      final dir = await getTemporaryDirectory();
      // Un dossier par message : deux documents de même nom ne s'écrasent pas.
      final folder = Directory('${dir.path}/message_media/$messageId');
      if (!await folder.exists()) await folder.create(recursive: true);
      final safeName = fileName.replaceAll(RegExp(r'[/\\:]'), '_');
      final target = '${folder.path}/$safeName';
      if (await File(target).exists()) return target;
      await _store.download(url, target);
      return target;
    } on Object {
      return null;
    }
  }
}

/// Sans backend, et dans les tests : rien à résoudre. Les bulles peignent
/// alors leur gabarit (icône, durée, nom) sans image.
class InertGroupMediaUrls implements GroupMediaUrls {
  const InertGroupMediaUrls();

  @override
  Future<String?> resolve({
    required String groupId,
    required String messageId,
    bool thumbnail = false,
  }) async =>
      null;

  @override
  Future<String?> download({
    required String groupId,
    required String messageId,
    required String fileName,
  }) async =>
      null;
}
