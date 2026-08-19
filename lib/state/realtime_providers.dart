/// **Les providers du temps-réel (SSE Transmit).**
///
/// Le pendant, pour le SSE, du couple lecture/écriture de la messagerie de
/// groupe : un [transmitClientProvider] (le transport, réel avec backend, inerte
/// sinon — patron `AppEnv.useBackend` de `groupMessagingProvider`) et un
/// [realtimeServiceProvider] (l'orchestrateur qui coalesce les événements et
/// déclenche une sync `SyncTrigger.realtime`). Voir `docs/temps-reel-sse.md`.
///
/// **Le temps-réel ne s'ouvre qu'avec une session.** [realtimeServiceProvider]
/// observe le `userId` de [authProvider] : **pas de session, service inerte** —
/// aucune socket, aucun signal, et le magasin n'est **pas** ouvert. Sans cette
/// garde, l'app tenterait un flux SSE avant même la connexion (guard `api` →
/// 401 en boucle du backoff de reconnexion). Dès qu'une session apparaît, le
/// provider se recrée avec le client réel ; `app.dart` (qui *écoute* le provider)
/// démarre alors le nouveau service. À la déconnexion, l'inverse : le service
/// réel est disposé (observateur retiré, minuterie annulée) et le client réel,
/// n'étant plus observé, est **auto-disposé** — sa socket se ferme.
///
/// **Un client neuf par session.** [transmitClientProvider] est `autoDispose` :
/// son unique observateur est le service authentifié. Une session qui s'en va
/// le laisse sans observateur → il se ferme ; la session suivante en obtient un
/// **vierge** (uid neuf, aucun canal hérité). C'est ce qui empêche les canaux
/// d'un fidèle de fuiter dans la connexion du suivant (D2/D6).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/realtime/inert_transmit_client.dart';
import '../data/realtime/realtime_service.dart';
import '../data/realtime/transmit_client.dart';
// La **porte** d'import conditionnel (natif Dio ⟂ web `fetch`) : le seul chemin
// par lequel on obtient un client réel, sans jamais nommer une implémentation.
import '../data/realtime/transmit_client_factory.dart';
import '../data/sync/sync_scheduler.dart';
import 'auth_providers.dart';
import 'group_providers.dart';
import 'sync_providers.dart';

/// **Le transport Transmit** : réel (la porte `createTransmitClient`, Http natif
/// ou Web `fetch`) avec backend, [InertTransmitClient] sinon.
///
/// `autoDispose` **à dessein** : sa vie est celle de la session qui l'observe
/// ([realtimeServiceProvider] authentifié). Perdre son observateur (déconnexion)
/// le ferme (`ref.onDispose` → `disconnect`) ; la session suivante en reçoit un
/// neuf, aux abonnements vierges. L'inerte, lui, n'a rien à fermer.
final transmitClientProvider = Provider.autoDispose<TransmitClient>((ref) {
  if (!AppEnv.useBackend) return const InertTransmitClient();
  final client = createTransmitClient();
  ref.onDispose(() => unawaited(client.disconnect()));
  return client;
});

/// **L'orchestrateur du temps-réel** — possède le client, observe le cycle de
/// vie et mes appartenances, coalesce, déclenche une sync `realtime`.
///
/// Le callback `onRealtimeSignal` est le **seul** lien vers le socle : le service
/// ignore tout du `SyncScheduler`, il sait seulement « déclencher une sync »
/// (D1). Le flux d'appartenances vient de `groupDao.watchMyGroupIds(userId)` — la
/// source du réabonnement réactif (D7).
///
/// `app.dart` appelle `start()` ; ce provider, lui, ne fait que **construire**
/// (et disposer proprement). Le [ref.onDispose] est ce qui, à un changement de
/// session, arrête l'ancien service avant que le nouveau ne démarre.
///
/// `autoDispose` : maintenu en vie par l'écoute de `app.dart` (`listenManual`),
/// il libère l'[transmitClientProvider] `autoDispose` en passant à sa branche
/// inerte (déconnexion) — une garde `keepAlive` observant un `autoDispose`
/// violerait la règle de durée de vie de Riverpod.
final realtimeServiceProvider = Provider.autoDispose<RealtimeService>((ref) {
  // Le `userId` n'est lu **que** sous backend : en mode maquette on ne touche
  // ni à l'auth ni au magasin (comme `pullToRefreshProvider`).
  final userId = AppEnv.useBackend
      ? ref.watch(authProvider.select((state) => state.user?.id))
      : null;

  if (userId == null) {
    // Sans backend **ou** sans session : service inerte. Aucune socket, aucun
    // signal, et surtout aucune ouverture de la base pour rien. Il se reconstruit
    // dès qu'une session apparaît (le `userId` change → ce provider se recrée).
    final service = RealtimeService(
      client: const InertTransmitClient(),
      myGroupIds: const Stream<List<String>>.empty(),
      onRealtimeSignal: () async {},
    );
    ref.onDispose(service.dispose);
    return service;
  }

  final client = ref.watch(transmitClientProvider);
  final myGroupIds = ref.watch(groupDaoProvider).watchMyGroupIds(userId).watch();

  final service = RealtimeService(
    client: client,
    myGroupIds: myGroupIds,
    // Le pont vers le socle. `trigger` ne lève pas (le planificateur retient
    // l'échec) : un temps-réel raté n'est jamais une panne d'application.
    onRealtimeSignal: () async {
      await ref.read(syncSchedulerProvider).trigger(SyncTrigger.realtime);
    },
  );
  ref.onDispose(service.dispose);
  return service;
});
