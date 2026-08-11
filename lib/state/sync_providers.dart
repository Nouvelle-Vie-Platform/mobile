/// **Le socle de synchronisation, et les trois déclencheurs qui l'appellent.**
///
/// Le socle a été livré branché sur aucun écran (étape 1 du cadrage, `docs/prd/
/// mediatheque-mobile.md` §4.2) : il devait être vert **sans que la médiathèque
/// soit en jeu**, pour qu'un bug de socle ne se lise pas comme un bug de
/// médiathèque. Ce n'est plus le cas — les écrans lisent le magasin
/// ([mediathequeDaoProvider] via `StoreMediathequeRepository`), et c'est la
/// synchronisation qui le remplit. Les trois déclencheurs d'ADR-0017 :
///
/// | Déclencheur | Où il est câblé |
/// |---|---|
/// | ouverture | `app.dart`, au premier frame, sous `AppEnv.useBackend` |
/// | retour au premier plan | l'abonnement au cycle de vie posé par `SyncScheduler.start()` |
/// | tirer-pour-rafraîchir | [pullToRefreshProvider], passé à un `RefreshIndicator` |
///
/// **Jamais de polling** : aucun `Timer`, et `test/sync/sync_scheduler_test.dart`
/// le vérifie sur la source.
///
/// Rien ici n'est instancié tant que personne ne le lit : ouvrir la base est un
/// effet de bord (un fichier sur l'appareil), et les providers Riverpod sont
/// paresseux.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';

import '../data/local/announcement_dao.dart';
import '../data/local/app_database.dart';
import '../data/local/gathering_dao.dart';
import '../data/local/mediatheque_dao.dart';
import '../data/local/sync_dao.dart';
import '../data/sync/sync_api.dart';
import '../data/sync/sync_engine.dart';
import '../data/sync/sync_scheduler.dart';

/// **Le magasin local** — une seule instance pour toute l'application.
///
/// À surcharger dans les tests par une base en mémoire
/// (`AppDatabase(NativeDatabase.memory())`).
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.defaults();
  ref.onDispose(database.close);
  return database;
});

/// Les primitives transactionnelles du magasin — c'est le moteur qui les
/// appelle, jamais un écran.
final syncDaoProvider = Provider<SyncDao>(
  (ref) => ref.watch(appDatabaseProvider).syncDao,
);

/// Les lectures du magasin — ce sont les écrans qui les appelleront (étape 2),
/// jamais le moteur.
final mediathequeDaoProvider = Provider<MediathequeDao>(
  (ref) => ref.watch(appDatabaseProvider).mediathequeDao,
);

/// Les lectures du magasin, côté **rassemblements** — la seconde famille de la
/// médiathèque. Un DAO distinct, jamais des méthodes de plus sur le premier :
/// ce sont deux collections, deux types, deux écrans.
final gatheringDaoProvider = Provider<GatheringDao>(
  (ref) => ref.watch(appDatabaseProvider).gatheringDao,
);

/// Les lectures du magasin, côté **annonces** — les quatre collections du mur
/// de statuts. Un DAO de plus, pour les mêmes raisons : d'autres collections, un
/// autre modèle, un autre écran.
final announcementDaoProvider = Provider<AnnouncementDao>(
  (ref) => ref.watch(appDatabaseProvider).announcementDao,
);

/// Les deux routes du protocole, sur le `Dio` d'`ApiClient` : la requête
/// traverse les intercepteurs de production.
final syncApiProvider = Provider<SyncApi>((ref) => SyncApi());

/// La boucle manifeste → tirage → application.
final syncEngineProvider = Provider<SyncEngine>(
  (ref) => SyncEngine(
    api: ref.watch(syncApiProvider),
    dao: ref.watch(syncDaoProvider),
  ),
);

/// Les déclencheurs : ouverture, retour au premier plan, tirer-pour-rafraîchir.
/// **Jamais de polling.**
///
/// `app.dart` appelle `start()` au premier frame. Ce n'est pas seulement le
/// déclencheur « ouverture » : `start()` **abonne le planificateur au cycle de
/// vie**, et c'est de cet abonnement que vient le déclencheur « retour au
/// premier plan ». Les deux tiennent donc au même appel.
///
/// Le provider n'est **pas** `autoDispose`, et ça compte : l'abonnement au
/// cycle de vie vit aussi longtemps que l'instance. Un planificateur recréé à
/// chaque lecture se réabonnerait — ou pire, ne serait plus là pour entendre le
/// retour au premier plan.
final syncSchedulerProvider = Provider<SyncScheduler>((ref) {
  final scheduler = SyncScheduler(ref.watch(syncEngineProvider).synchronize);
  ref.onDispose(scheduler.dispose);
  return scheduler;
});

/// **Le déclencheur « tirer-pour-rafraîchir »**, sous la forme qu'attend
/// `RefreshIndicator.onRefresh`.
///
/// Le drapeau `AppEnv.useBackend` se lit **ici et non dans l'écran**, comme
/// partout ailleurs dans `lib/state/` : sans backend il n'y a rien à
/// synchroniser, et lire [syncSchedulerProvider] ouvrirait une base Drift —
/// donc un fichier sur l'appareil, ou sur le disque de la machine de test —
/// pour ne rien tirer.
///
/// Le geste, lui, reste offert dans les deux modes : un écran ne change pas de
/// forme selon l'environnement, et le mode maquette n'a de toute façon rien de
/// neuf à montrer.
///
/// Rend le cycle **en cours** s'il y en a un : un tirer-pour-rafraîchir pendant
/// qu'un retour au premier plan tourne rejoint le cycle plutôt que d'en lancer
/// un second (deux cycles se disputeraient les mêmes curseurs).
final pullToRefreshProvider = Provider<Future<void> Function()>((ref) {
  if (!AppEnv.useBackend) return () async {};
  return () => ref.read(syncSchedulerProvider).refresh();
});
