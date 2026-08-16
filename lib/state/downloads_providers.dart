/// **Les providers du téléchargement offline** (#190) — l'état **partagé** du
/// socle, et rien de l'UI (bouton #192, page #193, cycle de vie #194).
///
/// Comme partout : les écrans **observent le magasin** (`downloads`), jamais le
/// moteur ni le réseau. Le [downloadManagerProvider] est le seul à parler au
/// plugin (via son abstraction), et il **écrit** dans le magasin ; les trois
/// autres providers ne font que lire ce que le magasin peint.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/downloads/background_downloader_backend.dart';
import '../data/downloads/disk_space.dart';
import '../data/downloads/download_backend.dart';
import '../data/downloads/download_lifecycle.dart';
import '../data/downloads/download_manager.dart';
import '../data/downloads/download_resolver.dart';
import '../data/local/app_database.dart';
import '../data/local/downloads_dao.dart';
import '../data/network/network_transport.dart';
import '../models/media_preferences.dart';
import 'media_settings_providers.dart';
import 'sync_providers.dart';
import 'theme_provider.dart';

/// Pas de réessai automatique, comme les autres lectures de magasin : une
/// lecture locale qui échoue ne réussira pas mieux à la seconde tentative.
Duration? _noAutomaticRetry(int retryCount, Object error) => null;

/// Le DAO du magasin de téléchargements — lectures **et** écritures (la table
/// est locale seule). À surcharger dans les tests via [appDatabaseProvider].
final downloadsDaoProvider = Provider<DownloadsDao>(
  (ref) => ref.watch(appDatabaseProvider).downloadsDao,
);

/// Le DAO des **notifications de purge** (#194, F16) — locale seule. À
/// surcharger dans les tests via [appDatabaseProvider].
final downloadNotificationsDaoProvider = Provider<DownloadNotificationsDao>(
  (ref) => ref.watch(appDatabaseProvider).downloadNotificationsDao,
);

/// **Le moteur de transfert en tâche de fond**, derrière son abstraction.
///
/// À surcharger par un `FakeDownloadBackend` dans les tests : l'implémentation
/// réelle ouvre des canaux natifs, absents du harnais. Pas `autoDispose` : le
/// moteur vit aussi longtemps que l'application, comme le lecteur.
final downloadBackendProvider = Provider<DownloadBackend>((ref) {
  final backend = BackgroundDownloaderBackend();
  // Best-effort : suivi persistant + notification + reprise depuis
  // l'arrière-plan. N'empêche jamais l'application de s'ouvrir.
  backend.initialize();
  ref.onDispose(backend.dispose);
  return backend;
});

/// La mesure d'espace disque, derrière son abstraction (pré-check F9). À
/// surcharger par un `FixedDiskSpace` dans les tests.
final diskSpaceProvider = Provider<DiskSpace>(
  (ref) => const BestEffortDiskSpace(),
);

/// **Le moteur de téléchargement** — mappe la table `downloads` ⇄ les tâches
/// natives, commande, écoute et écrit, réconcilie.
///
/// Pas `autoDispose`, et il **s'abonne** au transport dès sa création
/// (`start()`) : les rappels du moteur natif doivent atteindre le magasin même
/// quand aucun écran n'observe. Le câblage des déclencheurs de réconciliation
/// (démarrage, retour au premier plan) est laissé à #191–#194, qui ont l'arbre
/// de widgets ; le socle expose [DownloadManager.reconcile] prêt à l'emploi.
final downloadManagerProvider = Provider<DownloadManager>((ref) {
  final manager = DownloadManager(
    dao: ref.watch(downloadsDaoProvider),
    backend: ref.watch(downloadBackendProvider),
    diskSpace: ref.watch(diskSpaceProvider),
    network: ref.watch(networkTransportProvider),
    // La source de vérité des URLs/tailles, connue hors ligne (ADR-0038).
    metadataFor: (contentId) =>
        ref.read(mediathequeDaoProvider).downloadFor(contentId),
    // Le titre à **dénormaliser** sur la ligne au moment du téléchargement
    // (#194), pour nommer une copie purgée après un retrait (l'enseignement
    // aura alors quitté le magasin).
    titleFor: (contentId) =>
        ref.read(mediathequeDaoProvider).titleFor(contentId),
    // **Le toggle « données mobiles »** (#192, F8), branché sur le réglage
    // média persistant. Lu **à la demande** (une lecture ponctuelle, jamais un
    // flux) au moment de lancer ou de reprendre : le moteur consulte l'état
    // courant, il ne s'y abonne pas. Absent = wifi seulement, le défaut sûr.
    mobileDataAllowed: () => ref.read(settingsDaoProvider).downloadOnCellular(),
  );
  manager.start();
  ref.onDispose(manager.dispose);
  return manager;
});

/// **Le cycle de vie serveur ↔ copie locale** (#194) — révision → `outdated`,
/// retrait → purge + notification.
///
/// Sans état, reconstruit à la demande. Son `reconcile()` est branché **après
/// une sync réussie** et au démarrage / retour au premier plan (`app.dart`,
/// via `SyncScheduler.onCycleSucceeded`). Il ne monte aucun flux : ses lectures
/// sont ponctuelles, donc sûres sous l'horloge factice des tests.
final downloadLifecycleProvider = Provider<DownloadLifecycle>((ref) {
  return DownloadLifecycle(
    dao: ref.watch(downloadsDaoProvider),
    notifications: ref.watch(downloadNotificationsDaoProvider),
    manager: ref.watch(downloadManagerProvider),
    // L'état du magasin **après** la sync fait foi (ADR-0026) : retrait = ligne
    // absente, révision = version changée. Lu à la demande, jamais observé.
    syncStateFor: (contentId) =>
        ref.read(mediathequeDaoProvider).syncStateFor(contentId),
  );
});

/// **L'état réseau du routage offline-first** (#191) — « y a-t-il un tuyau ? »,
/// pas « y a-t-il internet ». À surcharger par un [FixedNetworkStatus] dans les
/// tests : l'implémentation réelle ouvre un canal de plugin, absent du harnais.
/// Voir [NetworkStatus] pour pourquoi cette question-ci est légitime là où
/// [NetworkTransport] refuse de trancher « y a-t-il internet ».
final networkStatusProvider = Provider<NetworkStatus>(
  (ref) => ConnectivityNetworkStatus(),
);

/// **Le point de résolution unique de la lecture** (#191, F10/F11).
///
/// L'écran de lecture le lit au lieu de `playlistUrl` en brut : il tranche entre
/// le fichier local (complet partout, partiel hors ligne) et le HLS. C'est un
/// service sans état, reconstruit à la demande — il ne fait que lire le magasin
/// et l'état réseau.
final downloadResolverProvider = Provider<DownloadResolver>(
  (ref) => DownloadResolver(
    dao: ref.watch(downloadsDaoProvider),
    network: ref.watch(networkStatusProvider),
  ),
);

/// **La qualité de téléchargement choisie** (réglage média, défaut `mid`, F6).
///
/// Distinct de la qualité d'écoute : le réglage `download` peut valoir `auto` en
/// magasin, mais un fichier `.aac` a une qualité concrète — c'est le
/// `DownloadManager` qui résout `auto` en un palier (défaut `mid`).
final downloadQualityProvider = Provider<MediaQuality>((ref) {
  return ref.watch(mediaPreferencesProvider).value?.of(MediaUsage.download) ??
      MediaQuality.auto;
});

/// **Tous les téléchargements**, observés depuis le magasin (page #193).
final downloadsListProvider = StreamProvider<List<DownloadRow>>(
  (ref) => ref.watch(downloadsDaoProvider).watchAll(),
  retry: _noAutomaticRetry,
);

/// **Le téléchargement d'un contenu**, ou `null` (bouton 5 états #192).
final downloadForContentProvider = StreamProvider.family<DownloadRow?, String>(
  (ref, contentId) =>
      ref.watch(downloadsDaoProvider).watchForContent(contentId),
  retry: _noAutomaticRetry,
);

/// **L'espace total occupé** par les téléchargements, en octets (page #193).
final downloadsStorageUsageProvider = StreamProvider<int>(
  (ref) => ref.watch(downloadsDaoProvider).watchStorageUsage(),
  retry: _noAutomaticRetry,
);

/// **Les notifications de purge**, observées depuis le magasin (bandeau #194).
final downloadNotificationsProvider =
    StreamProvider<List<DownloadNotificationRow>>(
  (ref) => ref.watch(downloadNotificationsDaoProvider).watchAll(),
  retry: _noAutomaticRetry,
);
