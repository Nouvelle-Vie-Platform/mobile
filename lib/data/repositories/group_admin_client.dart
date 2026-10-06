/// **Les gestes d'adhésion et d'administration d'un groupe** (#145, tranche M6
/// du plan `server-portal/docs/messagerie-whatsapp-plan.md`, décisions 8 et 9).
///
/// Séparés de la lecture (`EchangesRepository`) pour les trois raisons qui
/// séparent déjà l'envoi d'un message : ni la même source (serveur / magasin),
/// ni la même forme (`Future` / `Stream`), ni le même régime hors-ligne.
///
/// ## Ces gestes exigent le réseau, et c'est assumé
///
/// À la différence d'un message, aucun n'a d'écho optimiste : rejoindre, quitter
/// ou retirer quelqu'un change ce que **d'autres** voient, et un « fait » affiché
/// sans que le serveur l'ait accepté serait un mensonge à défaire. L'écran
/// attend la réponse, et c'est **la synchronisation** (ou le canal `users/{id}`,
/// qui annonce `membership.changed`) qui peint le résultat — le réseau ne peint
/// jamais (ADR-0026).
///
/// ## Idempotence (piège 5 du plan)
///
/// Chaque geste est rejouable sans effet de bord : rejoindre un groupe dont on
/// est déjà membre, ou redemander une adhésion en attente, rend un 409 que ce
/// client lit comme **déjà fait**. La création d'un groupe porte un `id`
/// frappé ici (UUIDv7) : la rejouer rend le groupe existant.
library;

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_client.dart';
import '../../models/group_management.dart';

/// L'issue d'un geste — trois cas, parce que l'écran a trois phrases à dire.
enum GroupActionOutcome {
  /// Le serveur l'a accepté (ou l'avait déjà fait).
  done,

  /// Le serveur l'a refusé : droits, politique du groupe, cible introuvable.
  refused,

  /// Aucune réponse : réseau absent ou serveur injoignable.
  unreachable,
}

/// Contrat des gestes d'adhésion et d'administration.
abstract interface class GroupAdminClient {
  /// `GET /groups/capabilities` — `GroupCapabilities.none` sur toute panne :
  /// sans réponse, on n'offre pas de créer.
  Future<GroupCapabilities> capabilities();

  /// `POST /groups` — crée un groupe sous [id] (UUIDv7 frappé par l'appelant,
  /// la clé d'idempotence), avec [memberIds] parmi mes contacts.
  Future<GroupActionOutcome> createGroup({
    required String id,
    required String name,
    String? description,
    required List<int> branchIds,
    required List<String> memberIds,
  });

  /// `POST /groups/:id/join` — politique `open`.
  Future<GroupActionOutcome> join(String groupId);

  /// `POST /groups/:id/join-requests` — politique `request`.
  Future<GroupActionOutcome> requestToJoin(String groupId);

  /// `POST /groups/:id/leave`.
  Future<GroupActionOutcome> leave(String groupId);

  /// `POST /groups/:id/members`.
  Future<GroupActionOutcome> addMember(String groupId, String userId);

  /// `DELETE /groups/:id/members/:userId`.
  Future<GroupActionOutcome> removeMember(String groupId, String userId);

  /// `PATCH /groups/:id/members/:userId` — [role] `member` | `moderator`.
  Future<GroupActionOutcome> setRole(
    String groupId,
    String userId,
    String role,
  );

  /// `GET /groups/:id/join-requests` — la file, pour un admin du groupe.
  /// `null` = illisible (réseau, droits) : l'écran se tait plutôt que d'afficher
  /// une file vide qui mentirait.
  Future<List<PendingJoinRequestView>?> joinRequests(String groupId);

  /// `POST /groups/:id/join-requests/:requestId/approve|reject`.
  Future<GroupActionOutcome> decideJoinRequest(
    String groupId,
    int requestId, {
    required bool approve,
  });
}

/// **Frappe l'identifiant d'un groupe à créer** : un UUIDv7, comme la clé d'un
/// message — il trie dans le temps, et le serveur l'accepte tel quel.
String mintGroupId() => const Uuid().v7();

/// **Les refus qui veulent dire « c'est déjà fait »**, geste par geste : rejouer
/// un geste qui avait abouti (réponse perdue) ne doit jamais se lire comme un
/// échec.
const Set<String> _alreadyMember = {'E_ALREADY_GROUP_MEMBER'};
const Set<String> _alreadyRequested = {
  'E_GROUP_JOIN_REQUEST_ALREADY_PENDING',
  'E_ALREADY_GROUP_MEMBER',
};
const Set<String> _alreadyGone = {'E_TARGET_NOT_GROUP_MEMBER'};
const Set<String> _alreadyLeft = {'E_NOT_GROUP_MEMBER'};

/// Implémentation HTTP de [GroupAdminClient]. Corps en `camelCase` (VineJS),
/// enveloppe `data` déballée par `ApiClient`.
class HttpGroupAdminClient implements GroupAdminClient {
  HttpGroupAdminClient({ApiClient? client})
      : _client = (client ?? ApiClient.instance).dio;

  final Dio _client;

  @override
  Future<GroupCapabilities> capabilities() async {
    try {
      final response = await _client.get<Object?>('/groups/capabilities');
      final data = response.data;
      if (data is! Map) return GroupCapabilities.none;
      final branches = data['createBranchIds'];
      return GroupCapabilities(
        canCreateGroup: data['canCreateGroup'] == true,
        createBranchIds: [
          if (branches is List)
            for (final id in branches)
              if (id is num) id.toInt(),
        ],
      );
    } on DioException {
      return GroupCapabilities.none;
    }
  }

  @override
  Future<GroupActionOutcome> createGroup({
    required String id,
    required String name,
    String? description,
    required List<int> branchIds,
    required List<String> memberIds,
  }) {
    final trimmedDescription = description?.trim();
    return _act(
      () => _client.post<Object?>(
        '/groups',
        data: {
          'id': id,
          'name': name.trim(),
          if (trimmedDescription != null && trimmedDescription.isNotEmpty)
            'description': trimmedDescription,
          'joinPolicy': 'invite_only',
          'branchIds': branchIds,
          'memberIds': memberIds,
        },
      ),
    );
  }

  @override
  Future<GroupActionOutcome> join(String groupId) => _act(
        () => _client.post<Object?>('/groups/$groupId/join'),
        alreadyDone: _alreadyMember,
      );

  @override
  Future<GroupActionOutcome> requestToJoin(String groupId) => _act(
        () => _client.post<Object?>('/groups/$groupId/join-requests'),
        alreadyDone: _alreadyRequested,
      );

  @override
  Future<GroupActionOutcome> leave(String groupId) => _act(
        () => _client.post<Object?>('/groups/$groupId/leave'),
        alreadyDone: _alreadyLeft,
      );

  @override
  Future<GroupActionOutcome> addMember(String groupId, String userId) => _act(
        () => _client.post<Object?>(
          '/groups/$groupId/members',
          data: {'userId': userId},
        ),
        alreadyDone: _alreadyMember,
      );

  @override
  Future<GroupActionOutcome> removeMember(String groupId, String userId) =>
      _act(
        () => _client.delete<Object?>('/groups/$groupId/members/$userId'),
        alreadyDone: _alreadyGone,
      );

  @override
  Future<GroupActionOutcome> setRole(
    String groupId,
    String userId,
    String role,
  ) =>
      _act(
        () => _client.patch<Object?>(
          '/groups/$groupId/members/$userId',
          data: {'role': role},
        ),
      );

  @override
  Future<List<PendingJoinRequestView>?> joinRequests(String groupId) async {
    try {
      final response =
          await _client.get<Object?>('/groups/$groupId/join-requests');
      final data = response.data;
      if (data is! List) return null;
      return [
        for (final row in data)
          if (row is Map && row['id'] is num && row['userId'] is String)
            PendingJoinRequestView(
              id: (row['id'] as num).toInt(),
              userId: row['userId'] as String,
              displayName: row['displayName'] as String?,
            ),
      ];
    } on DioException {
      return null;
    }
  }

  @override
  Future<GroupActionOutcome> decideJoinRequest(
    String groupId,
    int requestId, {
    required bool approve,
  }) =>
      _act(
        () => _client.post<Object?>(
          '/groups/$groupId/join-requests/$requestId/'
          '${approve ? 'approve' : 'reject'}',
        ),
      );

  Future<GroupActionOutcome> _act(
    Future<Object?> Function() call, {
    Set<String> alreadyDone = const {},
  }) async {
    try {
      await call();
      return GroupActionOutcome.done;
    } on DioException catch (error) {
      final response = error.response;
      if (response == null) return GroupActionOutcome.unreachable;
      final body = response.data;
      final code = body is Map ? body['code'] : null;
      if (alreadyDone.contains(code)) return GroupActionOutcome.done;
      final status = response.statusCode ?? 0;
      return status >= 500
          ? GroupActionOutcome.unreachable
          : GroupActionOutcome.refused;
    }
  }
}

/// Double **inerte** : n'offre rien, ne poste rien. Sert sans backend et aux
/// tests d'écran — l'implémentation HTTP ouvrirait une socket que
/// `flutter test` refuse.
class InertGroupAdminClient implements GroupAdminClient {
  const InertGroupAdminClient();

  @override
  Future<GroupCapabilities> capabilities() async => GroupCapabilities.none;

  @override
  Future<GroupActionOutcome> createGroup({
    required String id,
    required String name,
    String? description,
    required List<int> branchIds,
    required List<String> memberIds,
  }) async =>
      GroupActionOutcome.unreachable;

  @override
  Future<GroupActionOutcome> join(String groupId) async =>
      GroupActionOutcome.unreachable;

  @override
  Future<GroupActionOutcome> requestToJoin(String groupId) async =>
      GroupActionOutcome.unreachable;

  @override
  Future<GroupActionOutcome> leave(String groupId) async =>
      GroupActionOutcome.unreachable;

  @override
  Future<GroupActionOutcome> addMember(String groupId, String userId) async =>
      GroupActionOutcome.unreachable;

  @override
  Future<GroupActionOutcome> removeMember(
    String groupId,
    String userId,
  ) async =>
      GroupActionOutcome.unreachable;

  @override
  Future<GroupActionOutcome> setRole(
    String groupId,
    String userId,
    String role,
  ) async =>
      GroupActionOutcome.unreachable;

  @override
  Future<List<PendingJoinRequestView>?> joinRequests(String groupId) async =>
      null;

  @override
  Future<GroupActionOutcome> decideJoinRequest(
    String groupId,
    int requestId, {
    required bool approve,
  }) async =>
      GroupActionOutcome.unreachable;
}
