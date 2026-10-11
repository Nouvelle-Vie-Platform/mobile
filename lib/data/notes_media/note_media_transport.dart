/// **Le chemin présigné des pièces jointes de notes** (N4, mobile#192 ;
/// serveur N1, `POST /notes/media-uploads`).
///
/// Le chemin des médias de message, transposé : un ticket (clé choisie par le
/// serveur sous `note-media/<ownerId>/`, URL présignée, bornes), puis le `PUT`
/// droit au magasin. Il n'y a pas de temps 3 : la clé part dans l'embed de la
/// note, au prochain `POST /notes`.
///
/// Adaptateur sur `group_media_transport.dart`, **sans le modifier** : même
/// ticket ([MediaUploadTicket]), même exception, et le `PUT` est délégué à
/// [HttpGroupMediaTransport.upload] — un `Dio` nu, sans intercepteur.
library;

import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../messaging/media/group_media_transport.dart';

abstract interface class NoteMediaTransport {
  /// Le ticket. [kind] ∈ `image | video | audio | document | thumbnail` ;
  /// [contentType] est **déclaré** pour un audio ou un document.
  Future<MediaUploadTicket> openUpload({
    required String kind,
    String? contentType,
  });

  /// Le `PUT` du fichier [path] sur l'URL du ticket.
  Future<void> upload(
    MediaUploadTicket ticket,
    String path, {
    void Function(double progress)? onProgress,
  });
}

class HttpNoteMediaTransport implements NoteMediaTransport {
  HttpNoteMediaTransport({ApiClient? client, GroupMediaTransport? store})
      : _api = (client ?? ApiClient.instance).dio,
        _store = store ?? HttpGroupMediaTransport(client: client);

  final Dio _api;
  final GroupMediaTransport _store;

  @override
  Future<MediaUploadTicket> openUpload({
    required String kind,
    String? contentType,
  }) async {
    try {
      final response = await _api.post<Object?>(
        '/notes/media-uploads',
        data: {
          'kind': kind,
          if (contentType != null) 'contentType': contentType,
        },
      );
      final data = response.data;
      if (data is! Map) throw const GroupMediaTransportException(null);
      return MediaUploadTicket.fromJson(data.cast<String, Object?>());
    } on DioException catch (error) {
      final data = error.response?.data;
      final code = data is Map ? data['code'] : null;
      throw GroupMediaTransportException(
        code is String ? code : null,
        status: error.response?.statusCode,
      );
    }
  }

  @override
  Future<void> upload(
    MediaUploadTicket ticket,
    String path, {
    void Function(double progress)? onProgress,
  }) =>
      _store.upload(ticket, path, onProgress: onProgress);
}

/// Sans backend : aucun ticket. L'embed reste « en envoi », ce qui est la
/// seule chose honnête quand aucun serveur ne viendra le confirmer.
class InertNoteMediaTransport implements NoteMediaTransport {
  const InertNoteMediaTransport();

  @override
  Future<MediaUploadTicket> openUpload({
    required String kind,
    String? contentType,
  }) async =>
      throw const GroupMediaTransportException(null);

  @override
  Future<void> upload(
    MediaUploadTicket ticket,
    String path, {
    void Function(double progress)? onProgress,
  }) async {}
}
