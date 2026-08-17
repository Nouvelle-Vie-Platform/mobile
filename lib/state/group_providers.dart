/// **Les providers de la messagerie de groupe réelle.**
///
/// La lecture ([groupRepositoryProvider]) est adossée au **magasin** quand le
/// backend est branché, à un double **en mémoire** sinon — exactement le patron
/// de la médiathèque et des annonces. L'écriture ([groupMessagingProvider]) est
/// **séparée** (autre source, autre forme, autre régime hors-ligne), sur le
/// `Dio` d'`ApiClient`, inerte hors backend.
///
/// Les écrans lisent des `AsyncValue` (chargement / vide / erreur) : c'est le
/// coût de la bascule du fictif synchrone au réel, assumé par le cadrage.
/// **Pas de réessai automatique** (`retry: _noAutomaticRetry`), comme partout
/// dans ce dépôt : une erreur de lecture du magasin est un état à montrer, pas à
/// retenter en boucle.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/local/group_dao.dart';
import '../data/repositories/group_messaging.dart';
import '../data/repositories/group_repository.dart';
import '../data/repositories/http_group_messaging.dart';
import '../data/repositories/in_memory_group_repository.dart';
import '../data/repositories/inert_group_messaging.dart';
import '../models/models.dart';
import 'auth_providers.dart';
import 'sync_providers.dart';

Duration? _noAutomaticRetry(int retryCount, Object error) => null;

/// Les lectures du magasin, côté messagerie de groupe.
final groupDaoProvider = Provider<GroupDao>(
  (ref) => ref.watch(appDatabaseProvider).groupDao,
);

/// La lecture : magasin réel avec backend, double en mémoire sinon.
///
/// Le magasin a besoin de **mon identité** pour décider `mine` sur un message :
/// il la lit sur la session. Le provider se recrée à la connexion/déconnexion,
/// ce qui suffit (une session dure ; l'identité ne change pas en vol).
final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  if (!AppEnv.useBackend) return const InMemoryGroupRepository();
  final userId = ref.watch(authProvider).user?.id;
  return StoreGroupRepository(
    ref.watch(groupDaoProvider),
    currentUserId: userId,
  );
});

/// L'écriture : HTTP avec backend, inerte sinon.
final groupMessagingProvider = Provider<GroupMessaging>(
  (ref) =>
      AppEnv.useBackend ? HttpGroupMessaging() : const InertGroupMessaging(),
);

/// L'**inbox** du hub « Échanges » (groupes réels, triés par récence).
final conversationsProvider = StreamProvider<List<Conversation>>(
  (ref) => ref.watch(groupRepositoryProvider).conversations(),
  retry: _noAutomaticRetry,
);

/// La rangée de **découverte** : groupes publics à rejoindre.
final groupsToJoinProvider = StreamProvider<List<DiscoverGroup>>(
  (ref) => ref.watch(groupRepositoryProvider).groupsToJoin(),
  retry: _noAutomaticRetry,
);

/// Le **détail** d'un groupe, par identifiant (source de vérité relue à chaque
/// build — jamais une copie figée au clic).
final groupByIdProvider = StreamProvider.family<Conversation?, String>(
  (ref, groupId) => ref.watch(groupRepositoryProvider).group(groupId),
  retry: _noAutomaticRetry,
);

/// Les **messages** d'un groupe.
final groupMessagesProvider = StreamProvider.family<List<ChatMessage>, String>(
  (ref, groupId) => ref.watch(groupRepositoryProvider).messages(groupId),
  retry: _noAutomaticRetry,
);

/// Les **demandes d'adhésion en attente** d'un groupe, à valider.
final groupPendingRequestsProvider =
    StreamProvider.family<List<GroupJoinRequest>, String>(
  (ref, groupId) => ref.watch(groupRepositoryProvider).pendingRequests(groupId),
  retry: _noAutomaticRetry,
);

/// Argument d'[institutionProfileProvider] / [institutionGroupsProvider] : une
/// institution est désignée par **le couple (nature, identifiant)**.
typedef InstitutionRef = ({GroupOwnerKind kind, int id});

/// La **fiche d'une institution** (décision D23).
final institutionProfileProvider =
    StreamProvider.family<InstitutionProfile?, InstitutionRef>(
  (ref, r) => ref.watch(groupRepositoryProvider).institution(r.kind, r.id),
  retry: _noAutomaticRetry,
);

/// Les **groupes d'une institution**, pour sa fiche.
final institutionGroupsProvider =
    StreamProvider.family<List<Conversation>, InstitutionRef>(
  (ref, r) =>
      ref.watch(groupRepositoryProvider).institutionGroups(r.kind, r.id),
  retry: _noAutomaticRetry,
);
