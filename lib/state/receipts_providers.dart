/// **Les providers des accusés, de la frappe, de la présence et de la
/// confidentialité** (#142, tranche M3).
///
/// Dans un fichier à part d'`echanges_providers.dart`, qui ne reçoit que les
/// deux branchements du lien (`onSignal`, la confirmation de distribution) :
/// plusieurs tranches de la messagerie écrivent en même temps, et un fichier
/// partagé est l'endroit où leurs écritures se heurtent.
///
/// Même règle que la rubrique Échanges : l'acteur entre par un **paramètre de
/// famille** pour les lectures d'écran (voir l'en-tête
/// d'`echanges_providers.dart`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/messaging/delivery_acknowledger.dart';
import '../data/messaging/messaging_channel.dart';
import '../data/messaging/messaging_ephemeral.dart';
import '../data/messaging/messaging_signals_api.dart';
import '../data/repositories/receipts_repository.dart';
import '../models/receipt_view.dart';
import 'auth_providers.dart';
import 'echanges_providers.dart' show EchangesKey;
import 'sync_providers.dart';

/// **Les six routes de M3** — HTTP avec backend, inertes sinon. `pumpScreen`
/// pose le double inerte : l'implémentation réelle ouvrirait une socket.
final messagingSignalsApiProvider = Provider<MessagingSignalsApi>(
  (ref) => AppEnv.useBackend
      ? HttpMessagingSignalsApi()
      : const InertMessagingSignalsApi(),
);

/// Les coches **pour un acteur donné** : le magasin avec backend et session,
/// rien sinon (le serveur ne sert `message_receipts` qu'à un compte).
final receiptsRepositoryProvider =
    Provider.family<ReceiptsRepository, String?>((ref, actor) {
  if (!AppEnv.useBackend || actor == null) {
    return const EmptyReceiptsRepository();
  }
  return StoreReceiptsRepository(ref.watch(appDatabaseProvider).receiptsDao);
});

/// **Les coches des messages d'un fil**, par identifiant de message.
final messageReceiptsProvider =
    StreamProvider.family<Map<String, ReceiptStatus>, EchangesKey>(
  (ref, key) =>
      ref.watch(receiptsRepositoryProvider(key.actor)).receiptsOf(key.id),
  retry: (_, __) => null,
);

/// **L'état éphémère** (frappe, présence), tenu en mémoire pour la durée de
/// l'application. Le lien du canal y remet ses signaux.
final messagingEphemeralStoreProvider = Provider<MessagingEphemeralStore>((
  ref,
) {
  final store = MessagingEphemeralStore();
  ref.onDispose(store.dispose);
  return store;
});

/// L'état éphémère, **publié** : les écrans le lisent (par `select`).
class MessagingEphemeralNotifier extends Notifier<MessagingEphemeralState> {
  @override
  MessagingEphemeralState build() {
    final store = ref.watch(messagingEphemeralStoreProvider);
    void listener() => state = store.state;
    store.addListener(listener);
    ref.onDispose(() => store.removeListener(listener));
    return store.state;
  }
}

final messagingEphemeralProvider =
    NotifierProvider<MessagingEphemeralNotifier, MessagingEphemeralState>(
  MessagingEphemeralNotifier.new,
);

/// **Qui écrit dans ce groupe**, moi exclu — clé : l'acteur et le groupe.
final typingInProvider = Provider.family<List<String>, EchangesKey>(
  (ref, key) => ref.watch(
    messagingEphemeralProvider.select(
      (state) => state.typingIn(key.id, me: key.actor),
    ),
  ),
);

/// **La présence connue d'une personne**, ou `null`.
final presenceOfProvider = Provider.family<MessagingPresenceEvent?, String>(
  (ref, userId) => ref.watch(
    messagingEphemeralProvider.select((state) => state.presence[userId]),
  ),
);

/// **Confirmer la distribution** (✓✓ des autres) — `null` sans backend ou sans
/// session. Suit la session comme le lien du canal : il lit l'acteur par
/// `ref.watch(authProvider.select(…))`, ce que l'interdit des lectures d'écran
/// ne concerne pas — aucun widget ne l'observe.
final deliveryAcknowledgerProvider = Provider<DeliveryAcknowledger?>((ref) {
  if (!AppEnv.useBackend) return null;
  final userId = ref.watch(authProvider.select((state) => state.user?.id));
  if (userId == null) return null;
  return DeliveryAcknowledger(
    me: userId,
    dao: ref.watch(appDatabaseProvider).receiptsDao,
    api: ref.watch(messagingSignalsApiProvider),
  );
});

/// **Ce que le lien du canal fait d'un signal** (#142) : le remettre à l'état
/// éphémère, et — un message d'un autre vient d'être rangé — confirmer sa
/// distribution.
final messagingSignalHandlerProvider =
    Provider<void Function(MessagingEvent event)>((ref) {
  final store = ref.watch(messagingEphemeralStoreProvider);
  return (event) {
    store.apply(event);
    if (event is MessagingRowEvent && event.type == 'message.created') {
      final acknowledger = ref.read(deliveryAcknowledgerProvider);
      if (acknowledger != null &&
          event.row['authorId'] is String &&
          event.row['authorId'] != acknowledger.me) {
        acknowledger.flush().catchError((Object _) {});
      }
    }
  };
});
