/// **Les providers de la gestion des discussions et des groupes** (#145,
/// tranche M6 : décisions 8 et 9 du plan de messagerie).
///
/// Même règle que `echanges_providers.dart` : **l'acteur entre par un
/// paramètre de famille**, jamais par `ref.watch(authProvider)` — voir
/// l'en-tête de ce fichier-là pour la panne que la forme évidente provoque.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/repositories/group_admin_client.dart';
import '../models/group_management.dart';
import 'echanges_providers.dart';
import 'sync_providers.dart';

Duration? _noAutomaticRetry(int retryCount, Object error) => null;

/// **Le client des gestes d'adhésion et d'administration** — HTTP avec
/// backend, inerte sinon (et dans tous les tests d'écran, qui le posent).
final groupAdminClientProvider = Provider<GroupAdminClient>(
  (ref) => AppEnv.useBackend
      ? HttpGroupAdminClient()
      : const InertGroupAdminClient(),
);

/// **Ce que l'application peut offrir à cet acteur côté groupes** — aujourd'hui,
/// créer un groupe (responsables seulement, décision 9). Lu une fois par
/// acteur ; un échec rend [GroupCapabilities.none], jamais une erreur : sans
/// réponse, on n'offre pas de créer, et rien d'autre ne change.
final groupCapabilitiesProvider =
    FutureProvider.family<GroupCapabilities, String?>((ref, actor) async {
  if (actor == null) return GroupCapabilities.none;
  return ref.watch(groupAdminClientProvider).capabilities();
}, retry: _noAutomaticRetry);

/// **Mes contacts de groupe**, lus dans le magasin : le sélecteur de « Nouvelle
/// discussion » et des membres d'un groupe à créer.
final contactsProvider = StreamProvider.family<List<ContactView>, String?>(
  (ref, actor) => ref.watch(echangesRepositoryProvider(actor)).contacts(),
  retry: _noAutomaticRetry,
);

/// **La file des demandes d'adhésion** d'un groupe, pour un admin. `null` =
/// illisible : la section se tait. Relue après chaque décision
/// (`ref.invalidate`).
final groupJoinRequestsProvider =
    FutureProvider.autoDispose.family<List<PendingJoinRequestView>?, String>(
  (ref, groupId) => ref.watch(groupAdminClientProvider).joinRequests(groupId),
  retry: _noAutomaticRetry,
);

/// **Les gestes, suivis d'un cycle de synchronisation** quand ils aboutissent :
/// c'est le magasin qui peint le résultat (ADR-0026). Le canal `users/{id}`
/// l'apporte souvent avant — `membership.changed` part à chaque entrée, sortie
/// et changement de rôle —, le cycle est le rattrapage.
final groupActionsProvider = Provider<GroupActions>(
  (ref) => GroupActions(
    client: ref.watch(groupAdminClientProvider),
    resynchronize: ref.watch(pullToRefreshProvider),
  ),
);

/// Les gestes d'adhésion et d'administration, vus de l'écran.
class GroupActions {
  GroupActions({
    required GroupAdminClient client,
    required Future<void> Function() resynchronize,
  })  : _client = client,
        _resynchronize = resynchronize;

  final GroupAdminClient _client;
  final Future<void> Function() _resynchronize;

  Future<GroupActionOutcome> _then(Future<GroupActionOutcome> gesture) async {
    final outcome = await gesture;
    if (outcome == GroupActionOutcome.done) {
      try {
        await _resynchronize();
      } catch (_) {
        // Le geste a abouti ; le cycle est un confort. Le canal ou le cycle
        // suivant ramèneront la ligne.
      }
    }
    return outcome;
  }

  Future<GroupActionOutcome> createGroup({
    required String id,
    required String name,
    String? description,
    required List<int> branchIds,
    required List<String> memberIds,
  }) =>
      _then(
        _client.createGroup(
          id: id,
          name: name,
          description: description,
          branchIds: branchIds,
          memberIds: memberIds,
        ),
      );

  Future<GroupActionOutcome> join(String groupId) =>
      _then(_client.join(groupId));

  Future<GroupActionOutcome> requestToJoin(String groupId) =>
      _then(_client.requestToJoin(groupId));

  Future<GroupActionOutcome> leave(String groupId) =>
      _then(_client.leave(groupId));

  /// Ajoute chacun de [userIds], l'un après l'autre. `done` si **tous** sont
  /// entrés (ou l'étaient déjà) ; sinon l'issue du premier échec — les ajouts
  /// réussis restent faits, et le roster le montre.
  Future<GroupActionOutcome> addMembers(
    String groupId,
    List<String> userIds,
  ) async {
    var outcome = GroupActionOutcome.done;
    for (final userId in userIds) {
      final one = await _client.addMember(groupId, userId);
      if (one != GroupActionOutcome.done &&
          outcome == GroupActionOutcome.done) {
        outcome = one;
      }
    }
    try {
      await _resynchronize();
    } catch (_) {}
    return outcome;
  }

  Future<GroupActionOutcome> removeMember(String groupId, String userId) =>
      _then(_client.removeMember(groupId, userId));

  Future<GroupActionOutcome> setRole(
    String groupId,
    String userId,
    String role,
  ) =>
      _then(_client.setRole(groupId, userId, role));

  Future<GroupActionOutcome> decideJoinRequest(
    String groupId,
    int requestId, {
    required bool approve,
  }) =>
      _then(_client.decideJoinRequest(groupId, requestId, approve: approve));
}
