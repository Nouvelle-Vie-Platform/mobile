/// **Les providers de l'organisation des discussions** (#146, tranche M8) :
/// archiver, épingler, rechercher, ouvrir un fil sur un message.
///
/// Rangés à part d'`echanges_providers.dart`, que toutes les tranches de la
/// messagerie touchent. La règle de ce fichier-là vaut ici : **l'acteur entre par
/// un paramètre de famille**, lu par l'écran — jamais par un `ref.watch` de
/// `authProvider` dans un provider qu'un écran observe.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/local/chat_organization_dao.dart';
import '../data/local/sync_dao.dart' show SyncCollectionKey;
import '../data/messaging/group_arranger.dart';
import '../data/messaging/thread_message_locator.dart';
import '../data/repositories/chat_search_repository.dart';
import 'echanges_providers.dart';
import 'sync_providers.dart';

/// Le DAO de l'organisation des discussions.
final chatOrganizationDaoProvider = Provider<ChatOrganizationDao>(
  (ref) => ref.watch(appDatabaseProvider).chatOrganizationDao,
);

/// **L'envoi d'un rangement** — HTTP avec backend, inerte sans. Surchargé par
/// les tests (`flutter test` refuse le réseau).
final groupArrangementSenderProvider = Provider<GroupArrangementSender>(
  (ref) => AppEnv.useBackend
      ? HttpGroupArrangementSender()
      : const InertGroupArrangementSender(),
);

/// **L'outbox du rangement**, pour un acteur. `null` sans session : un invité
/// n'a pas de discussion à ranger.
final groupArrangerProvider =
    Provider.family<GroupArranger?, String?>((ref, actor) {
  if (actor == null) return null;
  final writer = ref.watch(messagingStoreWriterProvider);
  return GroupArranger(
    dao: ref.watch(chatOrganizationDaoProvider),
    sender: ref.watch(groupArrangementSenderProvider),
    userId: actor,
    storeArrangement: (row) =>
        writer.store(SyncCollectionKey.groupArrangements, row),
  );
});

/// **La recherche dans les messages**, pour un acteur : le magasin d'abord, le
/// serveur pour l'historique. Sans backend ou sans session : rien.
final chatSearchRepositoryProvider =
    Provider.family<ChatSearchRepository, String?>((ref, actor) {
  if (actor == null) return InMemoryChatSearchRepository();
  return StoreChatSearchRepository(
    ref.watch(chatOrganizationDaoProvider),
    userId: actor,
    remote: AppEnv.useBackend ? HttpRemoteMessageSearch() : null,
  );
});

/// **Remonter un fil jusqu'à un message** — le magasin, puis l'historique.
final threadMessageLocatorProvider = Provider<ThreadMessageLocator>(
  (ref) => ThreadMessageLocator(
    dao: ref.watch(chatOrganizationDaoProvider),
    history: ref.watch(groupHistoryProvider),
  ),
);
