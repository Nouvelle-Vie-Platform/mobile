import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/network/api_client.dart';

/// **Échanger la clé d'une pièce jointe contre une URL de lecture** (N4,
/// mobile#192 ; serveur N1, `GET /notes/media/<key>`).
///
/// Le patron de `group_media_urls.dart` (qu'on ne modifie pas : sa clé de
/// lecture est un message, pas une clé de magasin) : le 302 est lu **sans le
/// suivre** — sinon `Authorization` partirait vers le magasin —, et l'URL nue
/// est gardée **50 minutes** en mémoire (elle en vaut 60). Aucune URL signée
/// n'est écrite sur le disque.
abstract interface class NoteMediaUrls {
  /// L'URL présignée de [key], ou `null` (hors ligne, média retiré).
  Future<String?> resolve(String key);

  /// Télécharge [key] dans le dossier temporaire sous [fileName], pour
  /// l'ouvrir par l'application du système. `null` en cas d'échec.
  Future<String?> download(String key, String fileName);

  /// Les octets de [key] (photo pour le PDF). `null` en cas d'échec.
  Future<Uint8List?> bytes(String key);
}

class HttpNoteMediaUrls implements NoteMediaUrls {
  HttpNoteMediaUrls({
    ApiClient? client,
    Dio? storeClient,
    DateTime Function()? now,
  })  : _api = (client ?? ApiClient.instance).dio,
        _store = storeClient ?? Dio(),
        _now = now ?? DateTime.now;

  final Dio _api;
  final Dio _store;
  final DateTime Function() _now;

  static const Duration ttl = Duration(minutes: 50);
  final Map<String, ({String url, DateTime at})> _cache = {};

  @override
  Future<String?> resolve(String key) async {
    final cached = _cache[key];
    if (cached != null && _now().difference(cached.at) < ttl) return cached.url;
    try {
      // La clé porte ses `/` : la route est un joker (`/notes/media/*`).
      final response = await _api.get<Object?>(
        '/notes/media/$key',
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      final location = response.headers.value(HttpHeaders.locationHeader);
      if (location == null || location.isEmpty) return null;
      _cache[key] = (url: location, at: _now());
      return location;
    } on DioException {
      return null;
    }
  }

  @override
  Future<String?> download(String key, String fileName) async {
    final url = await resolve(key);
    if (url == null) return null;
    try {
      final dir = await getTemporaryDirectory();
      // Un dossier par clé : deux fichiers de même nom ne s'écrasent pas.
      final folder = Directory(
        '${dir.path}/note_media/${key.replaceAll(RegExp(r'[/\\:]'), '_')}',
      );
      if (!await folder.exists()) await folder.create(recursive: true);
      final target =
          '${folder.path}/${fileName.replaceAll(RegExp(r'[/\\:]'), '_')}';
      if (await File(target).exists()) return target;
      await _store.download(url, target);
      return target;
    } on Object {
      return null;
    }
  }

  @override
  Future<Uint8List?> bytes(String key) async {
    final url = await resolve(key);
    if (url == null) return null;
    try {
      final response = await _store.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      return data == null ? null : Uint8List.fromList(data);
    } on Object {
      return null;
    }
  }
}

/// Sans backend, et dans les tests : rien à résoudre.
class InertNoteMediaUrls implements NoteMediaUrls {
  const InertNoteMediaUrls();

  @override
  Future<String?> resolve(String key) async => null;

  @override
  Future<String?> download(String key, String fileName) async => null;

  @override
  Future<Uint8List?> bytes(String key) async => null;
}
