import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import 'group_messaging.dart';

/// Implémentation HTTP de [GroupMessaging].
///
/// ```
/// POST /groups/:id/messages                       guard `api`
/// POST /groups/:id/join                           guard `api`
/// POST /groups/:id/join-requests                  guard `api`
/// POST /groups/:id/leave                          guard `api`
/// POST /groups/:id/join-requests/:reqId/approve   guard `api`
/// POST /groups/:id/join-requests/:reqId/reject    guard `api`
/// ```
///
/// Corps en **`camelCase`** — la convention des corps de cette API REST, dont le
/// `snake_case` est réservé aux query strings et à l'enveloppe `/sync` (voir
/// `HttpAnnouncementComposer`). Le Bearer est injecté par `ApiClient`, le 401
/// est traité globalement (purge + retour à `/auth`) mais **remonté** ici :
/// l'écriture en cours a échoué, l'utilisateur doit le savoir.
///
/// **La réponse n'est pas lue.** Le message / l'appartenance / la demande revient
/// par le flux delta au prochain cycle de synchronisation.
///
/// ⚠️ **Contrat DOCUMENTÉ, endpoints partiellement à réconcilier** avec l'agent
/// serveur : `POST /groups/:id/messages`, `/join`, `/leave` sont figés
/// (`docs/human/groups.md`) ; `join-requests` (création + approve/reject) sont
/// **dérivés** du PRD `messagerie-groupes-officiels.md` (décision D12, table
/// `group_join_requests`) et sont l'hypothèse la plus fragile de ce lot.
class HttpGroupMessaging implements GroupMessaging {
  HttpGroupMessaging({ApiClient? client})
      : _client = (client ?? ApiClient.instance).dio;

  final Dio _client;

  @override
  Future<void> sendMessage(
    String groupId, {
    required String body,
    String? clientMessageId,
    DateTime? clientCreatedAt,
  }) =>
      _post('/groups/$groupId/messages', <String, Object?>{
        'body': body,
        if (clientMessageId != null) 'clientMessageId': clientMessageId,
        if (clientCreatedAt != null)
          'clientCreatedAt': clientCreatedAt.toUtc().toIso8601String(),
      });

  @override
  Future<void> join(String groupId) => _post('/groups/$groupId/join', null);

  @override
  Future<void> requestToJoin(String groupId) =>
      _post('/groups/$groupId/join-requests', null);

  @override
  Future<void> leave(String groupId) => _post('/groups/$groupId/leave', null);

  @override
  Future<void> approveJoinRequest(String groupId, int requestId) =>
      _post('/groups/$groupId/join-requests/$requestId/approve', null);

  @override
  Future<void> rejectJoinRequest(String groupId, int requestId) =>
      _post('/groups/$groupId/join-requests/$requestId/reject', null);

  Future<void> _post(String path, Map<String, Object?>? data) async {
    try {
      await _client.post<void>(path, data: data);
    } on DioException catch (e) {
      throw mapGroupWriteError(e);
    }
  }
}

/// Traduit une [DioException] en [GroupWriteException].
///
/// | Situation | code |
/// | --- | --- |
/// | pas de réponse (timeout, DNS, coupure, TLS) | `network` |
/// | **401** | `unauthorized` |
/// | **403** | `forbidden` — non-membre, diffusion, verrou, rôle insuffisant |
/// | **404 / 410** | `gone` |
/// | **409** | `conflict` — déjà membre / déjà en attente |
/// | **422** | `rejected` + message du validateur |
/// | autre réponse HTTP (5xx…) | `server` |
/// | requête annulée, reste | `unknown` |
///
/// Fonction de niveau bibliothèque (et non méthode privée) pour rester testable
/// sans réseau — `flutter test` répond 400 à tout accès réel.
@visibleForTesting
GroupWriteException mapGroupWriteError(DioException e) {
  if (e.type == DioExceptionType.cancel) {
    return const GroupWriteException(GroupWriteErrorCode.unknown);
  }

  final response = e.response;
  if (response == null) {
    return GroupWriteException(
      GroupWriteErrorCode.network,
      'Impossible de joindre le serveur (${e.message})',
    );
  }

  final body = response.data;
  final message = body is Map ? body['message'] as String? : null;

  return switch (response.statusCode) {
    401 => GroupWriteException(GroupWriteErrorCode.unauthorized, message),
    403 => GroupWriteException(GroupWriteErrorCode.forbidden, message),
    404 || 410 => GroupWriteException(GroupWriteErrorCode.gone, message),
    409 => GroupWriteException(GroupWriteErrorCode.conflict, message),
    422 => GroupWriteException(GroupWriteErrorCode.rejected, message),
    _ => GroupWriteException(GroupWriteErrorCode.server, message ?? e.message),
  };
}
