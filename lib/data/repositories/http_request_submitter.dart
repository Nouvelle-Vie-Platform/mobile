import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import 'my_requests_repository.dart';

/// Implémentation HTTP de [RequestSubmitter] (#148).
///
/// ```
/// POST /interactions   guard `api`
/// ```
///
/// **La réponse n'est pas lue**, pour la raison du composeur d'annonces : rien
/// n'est écrit dans le magasin ici. C'est le cycle de synchronisation suivant
/// qui ramène la ligne par la collection `my_interactions`.
///
/// Le serveur fige seul la branche de routage (Home Branch de l'auteur) et
/// garde l'auteur même anonyme (ADR-0007) : rien de cela n'est dans le corps.
class HttpRequestSubmitter implements RequestSubmitter {
  HttpRequestSubmitter({
    ApiClient? client,
    String Function()? mintId,
    DateTime Function()? now,
  })  : _client = (client ?? ApiClient.instance).dio,
        _mintId = mintId ?? mintRequestId,
        _now = now ?? DateTime.now;

  final Dio _client;
  final String Function() _mintId;
  final DateTime Function() _now;

  static const String _path = '/interactions';

  @override
  Future<void> submit(RequestDraft draft) async {
    try {
      await _client.post<void>(
        _path,
        data: draft.toJson(id: _mintId(), now: _now()),
      );
    } on DioException catch (e) {
      throw mapRequestSubmitError(e);
    }
  }
}

@visibleForTesting
RequestSubmitException mapRequestSubmitError(DioException e) {
  final response = e.response;
  if (response == null) {
    return RequestSubmitException(RequestSubmitErrorCode.network, e.message);
  }
  final body = response.data;
  final message = body is Map ? body['message'] as String? : null;
  return switch (response.statusCode) {
    401 => RequestSubmitException(RequestSubmitErrorCode.unauthorized, message),
    422 => RequestSubmitException(RequestSubmitErrorCode.invalid, message),
    _ => RequestSubmitException(RequestSubmitErrorCode.server, message),
  };
}
