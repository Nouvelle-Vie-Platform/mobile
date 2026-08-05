/// **Le socle de synchronisation, câblé — et branché sur aucun écran.**
///
/// C'est voulu, et c'est l'objet de l'étape 1 du cadrage (`docs/prd/
/// mediatheque-mobile.md` §4.2) : le socle doit être vert **sans que la
/// médiathèque soit en jeu**, pour qu'un bug de socle ne se lise pas comme un
/// bug de médiathèque. `SampleData` reste la source des écrans jusqu'à
/// l'étape 2, qui les branchera sur `MediathequeDao` et surchargera
/// [appDatabaseProvider] dans ses tests.
///
/// Rien ici n'est instancié tant que personne ne le lit : ouvrir la base est un
/// effet de bord (un fichier sur l'appareil), et les providers Riverpod sont
/// paresseux.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/app_database.dart';
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
/// C'est l'étape 2 qui appellera `start()` au démarrage de l'application ;
/// l'appeler ici ferait synchroniser une application dont aucun écran ne lit
/// encore le magasin.
final syncSchedulerProvider = Provider<SyncScheduler>((ref) {
  final scheduler = SyncScheduler(ref.watch(syncEngineProvider).synchronize);
  ref.onDispose(scheduler.dispose);
  return scheduler;
});
