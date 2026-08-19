/// **Les providers du réveil push (FCM + ntfy/UnifiedPush).**
///
/// Le pendant, pour le push, des providers du temps-réel
/// (`realtime_providers.dart`) : le SSE couvre l'app **ouverte**, le push couvre
/// l'app **fermée** (PRD `docs/prd/notifications-push.md`). On y assemble le
/// squelette derrière des **abstractions**, avec des **doubles inertes** partout
/// où le vrai câblage exige des dépendances natives encore interdites (voir plus
/// bas « Le maillon restant »).
///
/// **Rien de natif ne tourne encore, et c'est voulu.** `firebase_messaging`,
/// `flutter_local_notifications`, `google_api_availability` et `unifiedpush`
/// sont des **dépendances natives** que `CLAUDE.md` interdit d'ajouter à ce
/// stade (iOS est SPM-only → un plugin sans `Package.swift` ressusciterait
/// CocoaPods ; Firebase n'est pas configuré → un build échouerait). Tant que ce
/// maillon n'est pas posé par le main loop, Firebase debout :
///
/// | provider | branché sur | à flipper quand Firebase sera là |
/// |---|---|---|
/// | [pushTransportProvider] | `InertPushTransport` | `FcmPushTransport` (puis UnifiedPush) |
/// | [platformPushCapabilitiesProvider] | `FixedPushCapabilities` | `RuntimePushCapabilities` |
/// | [localNotifierProvider] | `InertLocalNotifier` | `FlutterLocalNotifier` |
/// | [deviceRegistrarProvider] | **déjà réel** (`HttpDeviceRegistrar`) | — |
///
/// **Le push, comme le temps-réel, ne s'arme qu'avec une session.**
/// [pushRegistrationServiceProvider] observe le `userId` d'[authProvider] : **pas
/// de session, service inerte** — aucun transport natif, aucun POST. Sans cette
/// garde, l'app tenterait d'enregistrer un appareil avant même la connexion
/// (guard `api` → 401). Dès qu'une session apparaît, le provider se recrée ;
/// `app.dart` (qui *écoute* le provider) démarre alors le nouveau service.
///
/// La feuille de route détaillée du dernier maillon est dans
/// `docs/notifications-push-seam-natif.md`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/push/device_registrar.dart';
import '../data/push/inert_push_transport.dart';
import '../data/push/local_notifier.dart';
import '../data/push/platform_push_capabilities.dart';
import '../data/push/push_registration_service.dart';
import '../data/push/push_transport.dart';
import '../data/push/push_wake_handler.dart';
import '../data/sync/sync_scheduler.dart';
import 'auth_providers.dart';
import 'group_providers.dart';
import 'sync_providers.dart';

/// **Le transport de réveil push** — la voie par laquelle l'appareil obtient son
/// inscription (jeton FCM ou endpoint UnifiedPush) et signale ses rotations.
///
/// **Inerte POUR L'INSTANT**, et c'est le maillon central qui reste à poser.
/// TODO(push, Firebase debout) : remplacer par la vraie implémentation FCM
/// (`FcmPushTransport`, le seul fichier à importer `firebase_messaging`), puis la
/// voie UnifiedPush pour l'Android dé-googlé. La sélection entre les deux se fera
/// via [selectPushTransport] sur [platformPushCapabilitiesProvider]. Voir
/// `docs/notifications-push-seam-natif.md`.
///
/// Reste **plat, non-autoDispose** tant qu'il est inerte (l'inerte n'a aucune
/// ressource native à relâcher). Quand la vraie impl arrivera, la rendre
/// `autoDispose` et la scoper sur la session — comme `transmitClientProvider` —
/// pour qu'un changement de session reparte d'un transport vierge.
final pushTransportProvider = Provider<PushTransport>(
  (ref) => const InertPushTransport(),
);

/// **Les trois faits de plateforme** dont dépend le choix du transport (D4).
///
/// **Figés POUR L'INSTANT** — aucune plateforme n'est réellement interrogée.
/// TODO(push, Firebase debout) : remplacer par `RuntimePushCapabilities` (le seul
/// endroit à importer `google_api_availability` et `unifiedpush`). Exposé dès
/// maintenant pour que le futur [pushTransportProvider] réel puisse trancher avec
/// [selectPushTransport] sans nouveau câblage ici.
final platformPushCapabilitiesProvider = Provider<PlatformPushCapabilities>(
  (ref) => const FixedPushCapabilities(),
);

/// **L'enregistrement de l'appareil auprès du serveur** — `POST /devices/tokens`
/// (et purge par `POST /auth/sign-out {deviceToken}` à la déconnexion).
///
/// **Déjà réel** : `HttpDeviceRegistrar` ne dépend d'aucun plugin natif (il ne
/// manipule que la valeur plate `PushRegistration` sur le `Dio` d'`ApiClient`),
/// il n'y a donc rien à attendre de Firebase pour lui. Inerte hors backend, comme
/// `groupMessagingProvider`. Best-effort : ni `register` ni `unregister` ne lève.
final deviceRegistrarProvider = Provider<DeviceRegistrar>(
  (ref) => AppEnv.useBackend
      ? HttpDeviceRegistrar()
      : const InertDeviceRegistrar(),
);

/// **La peinture de la notification locale** (D6 — dernier maillon du réveil).
///
/// **Inerte POUR L'INSTANT** (no-op). TODO(push, Firebase debout) : remplacer par
/// `FlutterLocalNotifier` (le seul fichier à importer
/// `flutter_local_notifications`), qui posera `conversationId` dans le payload de
/// la notification pour le deep-link au tap. Ne change **rien** au
/// [pushWakeHandlerProvider] : c'est tout l'intérêt du seam.
final localNotifierProvider = Provider<LocalNotifier>(
  (ref) => const InertLocalNotifier(),
);

/// **Le service qui garde l'inscription push alignée sur le serveur** — le nœud
/// entre [pushTransportProvider] (qui *obtient* la cible) et
/// [deviceRegistrarProvider] (qui l'*envoie*).
///
/// `autoDispose` **à dessein**, exactement comme `realtimeServiceProvider` :
/// maintenu en vie par l'écoute de `app.dart` (`listenManual`), il se recrée à
/// chaque changement de session (le `userId` change), Riverpod dispose l'ancien
/// service, et `app.dart` démarre le neuf.
///
/// **Gate session** : sans backend **ou** sans session, on injecte les doubles
/// **inertes** (aucun transport natif, aucun POST) — `start()` devient alors un
/// no-op. Tant que [pushTransportProvider] est inerte, cette branche et la branche
/// « session » sont fonctionnellement identiques ; la garde est déjà en place
/// pour le jour où le transport réel arrivera.
final pushRegistrationServiceProvider =
    Provider.autoDispose<PushRegistrationService>((ref) {
  // Le `userId` n'est lu **que** sous backend : en mode maquette on ne touche
  // ni à l'auth ni au réseau (comme `realtimeServiceProvider`).
  final userId = AppEnv.useBackend
      ? ref.watch(authProvider.select((state) => state.user?.id))
      : null;

  if (userId == null) {
    // Sans backend **ou** sans session : service inerte. Aucun transport natif,
    // aucun enregistrement. Il se reconstruit dès qu'une session apparaît.
    final service = PushRegistrationService(
      transport: const InertPushTransport(),
      registrar: const InertDeviceRegistrar(),
    );
    ref.onDispose(service.dispose);
    return service;
  }

  final service = PushRegistrationService(
    transport: ref.watch(pushTransportProvider),
    registrar: ref.watch(deviceRegistrarProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// **Le handler de réveil push** (D6) : réveil silencieux → sync ciblée →
/// notification LOCALE lue dans le magasin.
///
/// **Exposé mais PAS déclenché ici.** Il le sera par le vrai *background isolate
/// handler* FCM (seam futur, `docs/notifications-push-seam-natif.md`), qui
/// décodera le réveil (`PushWakePayload.tryParse`) et appellera [handle]. On le
/// pré-câble derrière ce provider pour que ce maillon-là n'ait qu'à le lire.
///
/// Le pont vers le socle est le callback `onSync` → `SyncTrigger.push`, à l'image
/// du `RealtimeService` : le handler ne connaît pas le `SyncScheduler`. Le
/// `currentUserId` (session) sert à résoudre le **pair d'un DM** via `profiles`.
///
/// Non-`autoDispose` : le background handler est appelé hors de l'arbre de
/// widgets, il ne « garde » aucun provider en vie par une écoute. Il reste
/// paresseux — rien n'ouvre le magasin tant que personne ne lit ce provider.
final pushWakeHandlerProvider = Provider<PushWakeHandler>((ref) {
  final userId = AppEnv.useBackend
      ? ref.watch(authProvider.select((state) => state.user?.id))
      : null;

  return PushWakeHandler(
    // `trigger` ne lève pas (le planificateur retient l'échec) : un réveil raté
    // n'est jamais une panne d'application. Hors backend, rien à synchroniser.
    onSync: () async {
      if (!AppEnv.useBackend) return;
      await ref.read(syncSchedulerProvider).trigger(SyncTrigger.push);
    },
    groupDao: ref.watch(groupDaoProvider),
    notifier: ref.watch(localNotifierProvider),
    currentUserId: userId,
  );
});
