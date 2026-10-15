import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../local/group_dao.dart';
import 'message_media_store.dart';

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
///
/// Ce cache-là ne garde que l'**URL**, en mémoire. Les **octets** vivent dans
/// `MessageMediaStore` (T1, #223), qui survit au système — et [download] les y
/// cherche **avant** d'appeler [GroupMediaUrls.resolve].
abstract interface class GroupMediaUrls {
  /// L'URL de lecture du média de [messageId] — ou de sa vignette —, ou
  /// `null` si elle ne peut pas être obtenue (hors ligne, média retiré).
  Future<String?> resolve({
    required String groupId,
    required String messageId,
    bool thumbnail = false,
  });

  /// **Le fichier local du média** de [messageId] — ou de sa vignette —, sous
  /// le nom [fileName], téléchargé seulement **s'il n'est pas déjà là**.
  /// `null` en cas d'échec.
  ///
  /// C'est ici que vit la règle « le disque avant le réseau » (T1, #223) : le
  /// chemin au magasin est déductible de l'identité du message, on le **teste
  /// avant** de demander une URL présignée. Hors ligne, un média déjà descendu
  /// s'ouvre donc ; en ligne, le rouvrir ne coûte plus une requête.
  Future<String?> download({
    required String groupId,
    required String messageId,
    required String fileName,
    bool thumbnail = false,
  });
}

class HttpGroupMediaUrls implements GroupMediaUrls {
  HttpGroupMediaUrls({
    Dio? api,
    Dio? storeClient,
    DateTime Function()? now,
    MessageMediaStore? store,
    this.dao,
  })  : _api = api ?? ApiClient.instance.dio,
        _http = storeClient ?? Dio(),
        _now = now ?? DateTime.now,
        _store = store ?? MessageMediaStore();

  final Dio _api;
  final Dio _http;
  final DateTime Function() _now;
  final MessageMediaStore _store;

  /// Où **noter** qu'un média est désormais sur l'appareil, pour que la bulle
  /// le serve sans rien demander (`local_message_media`). `null` : on
  /// télécharge quand même, on ne note rien — le chemin reste déductible.
  final GroupDao? dao;

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
    bool thumbnail = false,
  }) async {
    try {
      final target = await _store.pathFor(
        messageId: messageId,
        fileName: fileName,
        thumbnail: thumbnail,
      );
      // **Le disque avant le réseau** (#223). Le chemin ne dépend que de
      // l'identité du message, et un média de message est immuable : si le
      // fichier est là, il est bon, et il n'y a rien à revalider — ce qui
      // tombe bien, `If-Range` étant ignoré par cette origine (ADR-0012 de
      // `streaming-service`).
      if (await File(target).exists()) return target;

      final url = await resolve(
        groupId: groupId,
        messageId: messageId,
        thumbnail: thumbnail,
      );
      if (url == null) return null;

      // On écrit **à côté**, puis on renomme : un téléchargement coupé (réseau
      // togolais, application tuée) laisserait sinon un fichier tronqué que le
      // test ci-dessus prendrait pour complet, et le média serait abîmé pour
      // toujours. `rename` est atomique dans un même dossier.
      await _store.prepare(target);
      final partial = '$target.part';
      await _http.download(url, partial);
      await File(partial).rename(target);

      await dao?.rememberLocalMedia(
        messageId,
        path: thumbnail ? null : target,
        thumbPath: thumbnail ? target : null,
      );
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
    bool thumbnail = false,
  }) async =>
      null;
}
