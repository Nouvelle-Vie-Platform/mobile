/// **Le chemin présigné d'un média de message, côté téléphone** (M4, #143 —
/// reprend #98 ; serveur #485 + M4).
///
/// Trois temps, et **les octets ne passent jamais par l'API** (ADR-0005) :
///
/// 1. `POST /groups/:id/media-uploads` — un ticket : clé, URL présignée, type
///    à annoncer, **bornes** (`maxBytes`, `maxDurationSeconds`) ;
/// 2. `PUT` du fichier **droit au magasin**, sur l'URL du ticket ;
/// 3. `POST /groups/:id/messages` en citant la clé, avec le même
///    `clientMessageId` que tout message (idempotence).
///
/// Une position ou un contact n'ont pas de fichier : seulement le temps 3.
library;

import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

/// Le ticket de dépôt rendu par le serveur.
class MediaUploadTicket {
  const MediaUploadTicket({
    required this.key,
    required this.url,
    required this.contentType,
    required this.maxBytes,
    this.maxDurationSeconds,
  });

  final String key;
  final String url;

  /// Le type **signé avec l'URL** : le `PUT` doit l'annoncer à l'identique.
  final String contentType;

  /// La borne que le serveur appliquera — vérifiée **avant** la montée.
  final int maxBytes;
  final int? maxDurationSeconds;

  static MediaUploadTicket fromJson(Map<String, Object?> json) {
    final key = json['key'], url = json['url'], type = json['contentType'];
    final max = json['maxBytes'];
    if (key is! String || url is! String || type is! String || max is! num) {
      throw const GroupMediaTransportException(null);
    }
    final duration = json['maxDurationSeconds'];
    return MediaUploadTicket(
      key: key,
      url: url,
      contentType: type,
      maxBytes: max.toInt(),
      maxDurationSeconds: duration is num ? duration.toInt() : null,
    );
  }
}

/// Un refus, ou une panne. [code] est le code d'erreur du serveur
/// (`E_GROUP_MEDIA_TOO_LARGE`…), `null` pour une panne de réseau — qui se
/// réessaie.
class GroupMediaTransportException implements Exception {
  const GroupMediaTransportException(this.code, {this.status});

  final String? code;
  final int? status;

  /// Le serveur a **refusé** (4xx) : réessayer à l'identique referait la même
  /// chose — sauf un objet absent, qui se remonte.
  bool get isRejection => status != null && status! >= 400 && status! < 500;

  @override
  String toString() => 'GroupMediaTransportException($code, $status)';
}

/// Le contrat du chemin présigné. Les tests posent un double — jamais de vrai
/// réseau sous `flutter test`.
abstract interface class GroupMediaTransport {
  /// Temps 1 : le ticket. [kind] est la forme **serveur** (`audio`, `image`,
  /// `video`, `document`, `thumbnail`).
  Future<MediaUploadTicket> openUpload({
    required String groupId,
    required String kind,
    String? contentType,
    bool? voice,
  });

  /// Temps 2 : le `PUT` du fichier [path] droit au magasin. [onProgress]
  /// reçoit `0..1`.
  Future<void> upload(
    MediaUploadTicket ticket,
    String path, {
    void Function(double progress)? onProgress,
  });

  /// Temps 3 : le message, qui cite la clé (ou porte la méta d'une position,
  /// d'un contact).
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
  });
}

/// L'implémentation HTTP.
///
/// ⚠️ **Le `PUT` part d'un `Dio` nu**, sans intercepteur : l'URL présignée
/// porte sa signature, et un en-tête `Authorization: Bearer …` de plus ferait
/// refuser la requête par le magasin (« un seul mécanisme d'authentification »)
/// — et enverrait le jeton du fidèle à un tiers.
class HttpGroupMediaTransport implements GroupMediaTransport {
  HttpGroupMediaTransport({ApiClient? client, Dio? storeClient})
      : _api = (client ?? ApiClient.instance).dio,
        _store = storeClient ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                // Un vocal de 2,4 Mo sur un réseau dégradé : large.
                sendTimeout: const Duration(minutes: 5),
                receiveTimeout: const Duration(seconds: 30),
              ),
            );

  final Dio _api;
  final Dio _store;

  @override
  Future<MediaUploadTicket> openUpload({
    required String groupId,
    required String kind,
    String? contentType,
    bool? voice,
  }) async {
    try {
      final response = await _api.post<Object?>(
        '/groups/$groupId/media-uploads',
        data: {
          'kind': kind,
          if (contentType != null) 'contentType': contentType,
          if (voice != null) 'voice': voice,
        },
      );
      final data = response.data;
      if (data is! Map) throw const GroupMediaTransportException(null);
      return MediaUploadTicket.fromJson(data.cast<String, Object?>());
    } on DioException catch (error) {
      throw _translate(error);
    }
  }

  @override
  Future<void> upload(
    MediaUploadTicket ticket,
    String path, {
    void Function(double progress)? onProgress,
  }) async {
    final file = File(path);
    final length = await file.length();
    try {
      await _store.put<void>(
        ticket.url,
        data: file.openRead(),
        options: Options(
          headers: {
            Headers.contentTypeHeader: ticket.contentType,
            Headers.contentLengthHeader: length,
          },
        ),
        onSendProgress: (sent, total) {
          final size = total > 0 ? total : length;
          if (size > 0) onProgress?.call((sent / size).clamp(0.0, 1.0));
        },
      );
    } on DioException catch (error) {
      // Le magasin parle XML, pas l'enveloppe de l'API : pas de code à lire.
      throw GroupMediaTransportException(
        null,
        status: error.response?.statusCode,
      );
    }
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
    final caption = body?.trim();
    try {
      await _api.post<Object?>(
        '/groups/$groupId/messages',
        data: {
          if (caption != null && caption.isNotEmpty) 'body': caption,
          'mediaKind': mediaKind,
          if (mediaKey != null) 'mediaKey': mediaKey,
          if (mediaDuration != null) 'mediaDuration': mediaDuration,
          if (mediaMeta != null) 'mediaMeta': mediaMeta,
          if (mediaThumbnailKey != null) 'mediaThumbnailKey': mediaThumbnailKey,
          'clientMessageId': clientMessageId,
          'clientCreatedAt': clientCreatedAt.toUtc().toIso8601String(),
        },
      );
    } on DioException catch (error) {
      throw _translate(error);
    }
  }

  static GroupMediaTransportException _translate(DioException error) {
    final response = error.response;
    final data = response?.data;
    final code = data is Map ? data['code'] : null;
    return GroupMediaTransportException(
      code is String ? code : null,
      status: response?.statusCode,
    );
  }
}

/// Double **inerte** : sans backend (`AppEnv.useBackend == false`) ni réseau.
/// Tout « réussit », rien ne part — l'écho reste au fil, ce qui est la seule
/// chose honnête quand aucun serveur ne viendra le confirmer.
class InertGroupMediaTransport implements GroupMediaTransport {
  const InertGroupMediaTransport();

  @override
  Future<MediaUploadTicket> openUpload({
    required String groupId,
    required String kind,
    String? contentType,
    bool? voice,
  }) async =>
      MediaUploadTicket(
        key: 'group-media/$groupId/inert',
        url: 'about:blank',
        contentType: contentType ?? 'application/octet-stream',
        maxBytes: 1 << 40,
      );

  @override
  Future<void> upload(
    MediaUploadTicket ticket,
    String path, {
    void Function(double progress)? onProgress,
  }) async =>
      onProgress?.call(1);

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
  }) async {}
}
