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
/// Un quatrième s'y est ajouté depuis (#101, refait par #140), et il n'est pas
/// d'ADR-0017 : le **rattrapage du canal temps réel** ([realtimeSyncProvider]) —
/// à chaque (re)connexion du canal `users/{id}`, et quand il cite un groupe
/// inconnu. Même mécanisme, même moteur — seul le déclencheur est neuf.
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
import '../data/local/auth_channels_dao.dart';
import '../data/local/app_database.dart';
import '../data/local/device_settings_dao.dart';
import '../data/local/gathering_dao.dart';
import '../data/local/group_dao.dart';
import '../data/local/interaction_dao.dart';
import '../data/local/legal_dao.dart';
import '../data/local/mediatheque_dao.dart';
import '../data/local/menu_dao.dart';
import '../data/local/playback_dao.dart';
import '../data/local/season_dao.dart';
import '../data/local/sync_dao.dart';
import '../data/local/vocabulary_dao.dart';
import '../data/sync/sync_api.dart';
import '../data/sync/sync_engine.dart';
import '../data/sync/sync_scheduler.dart';
import '../data/sync/synced_collection.dart';
import 'branch_scope_providers.dart';

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

/// Les lectures du magasin, côté **reprise de lecture** — les deux tables de
/// l'issue #43. Un DAO de plus, pour les mêmes raisons que les trois autres.
///
/// Celui-ci **écrit**, à la différence des trois précédents : la position à
/// chaud, et elle seule. La collection répliquée `playback_progress` n'a
/// d'autre écrivain que le moteur de synchronisation.
final playbackDaoProvider = Provider<PlaybackDao>(
  (ref) => ref.watch(appDatabaseProvider).playbackDao,
);

/// Les lectures du magasin, côté **documents légaux** — CGU, politique de
/// confidentialité, « à propos » (#55). Un DAO de plus, pour les mêmes
/// raisons : une autre collection, un autre modèle, d'autres écrans.
///
/// Il ne choisit aucune langue : les sections en sortent **brutes**, et c'est
/// `LegalDocumentView.resolve` qui tranche, une fois, pour le document entier
/// (ADR-0035).
final legalDaoProvider = Provider<LegalDao>(
  (ref) => ref.watch(appDatabaseProvider).legalDao,
);

/// Les lectures du magasin, côté **saisons** — la période datée dont le fond
/// vertical habille les deux lecteurs. Un DAO de plus, même motif que les
/// précédents.
final seasonDaoProvider = Provider<SeasonDao>(
  (ref) => ref.watch(appDatabaseProvider).seasonDao,
);

/// Les lectures du magasin, côté **vocabulaire** — les mots réglés au portail
/// (#81). Un DAO de plus, même motif que les précédents.
///
/// Il ne choisit aucune langue et n'applique aucune précédence : il rend les
/// surcharges brutes, et c'est `AppWords` (`l10n/vocabulary.dart`) qui tranche
/// — à un seul endroit.
final vocabularyDaoProvider = Provider<VocabularyDao>(
  (ref) => ref.watch(appDatabaseProvider).vocabularyDao,
);

/// Les lectures du magasin, côté **menus** — les entrées réglées au portail
/// (#82). Un DAO de plus, même motif que les précédents.
///
/// C'est lui qui résout les slugs de rubrique et qui compte, surface par
/// surface, ce que chaque destination ramènerait : les deux choses dont « pas de
/// contenu, pas de section » a besoin, et qu'une entrée ne porte pas elle-même.
final menuDaoProvider = Provider<MenuDao>(
  (ref) => ref.watch(appDatabaseProvider).menuDao,
);

/// Les lectures du magasin, côté **canaux de connexion** — par quelles portes
/// l'application propose d'entrer (#83). Un DAO de plus, même motif que les
/// précédents.
///
/// C'est lui, et lui seul, qui traduit une table vide en **offre** : le repli
/// est l'e-mail seul, jamais « tous les canaux ».
final authChannelsDaoProvider = Provider<AuthChannelsDao>(
  (ref) => ref.watch(appDatabaseProvider).authChannelsDao,
);

/// Les lectures du magasin, côté **réglage d'exploitation du parc** — le seuil
/// du bandeau de mise à jour (#91). Un DAO de plus, même motif que les
/// précédents.
///
/// C'est lui, et lui seul, qui traduit une table vide **et** une colonne nulle
/// en la même réponse : pas de seuil, donc pas de bandeau.
final deviceSettingsDaoProvider = Provider<DeviceSettingsDao>(
  (ref) => ref.watch(appDatabaseProvider).deviceSettingsDao,
);

/// Les lectures du magasin, côté **« Échanges »** (#96) — et les seules écritures
/// du domaine, qui ne touchent que la table locale seule de l'écho optimiste.
///
/// Un DAO de plus, même motif que les précédents : un par domaine, et c'est lui
/// qui porte les règles de lecture que deux écrans partagent — au premier rang le
/// fait qu'une conversation se lit sur `group_members` et non sur `groups`.
final groupDaoProvider = Provider<GroupDao>(
  (ref) => ref.watch(appDatabaseProvider).groupDao,
);

/// La lecture de **mes requêtes** (#148), la collection privée `my_interactions`.
final interactionDaoProvider = Provider<InteractionDao>(
  (ref) => ref.watch(appDatabaseProvider).interactionDao,
);

/// Les deux routes du protocole, sur le `Dio` d'`ApiClient` : la requête
/// traverse les intercepteurs de production.
final syncApiProvider = Provider<SyncApi>((ref) => SyncApi());

/// La boucle manifeste → tirage → application.
///
/// **La préférence de branche y entre par deux rappels, jamais par une valeur.**
/// [SyncEngine] la relit à chaque cycle : capturée ici, elle figerait le filtre
/// au premier `ref.watch` et le geste du fidèle resterait sans effet jusqu'au
/// redémarrage suivant. Et le rappel de 422 est ce qui permet à une branche
/// disparue du référentiel de ne pas éteindre **toute** la synchronisation.
///
/// L'importation de `branch_scope_providers.dart` est locale à ce provider et va
/// dans ce sens-là seulement : c'est la préférence qui ignore le moteur, pas
/// l'inverse.
final syncEngineProvider = Provider<SyncEngine>(
  (ref) => SyncEngine(
    api: ref.watch(syncApiProvider),
    dao: ref.watch(syncDaoProvider),
    branchId: () => ref.read(branchScopeStoreProvider).read(),
    // **Le magasin et le miroir, pas la façade.** `BranchScope` resynchronise
    // dans son `forget`, et resynchroniser depuis le chemin d'erreur d'un cycle
    // ouvrirait un second cycle sur les mêmes curseurs — pire, la chaîne
    // `branchScopeProvider → pullToRefreshProvider → syncSchedulerProvider →
    // syncEngineProvider` boucle, et Riverpod refuse une dépendance circulaire.
    // Le miroir est remis à zéro ici même : sans ça, le prochain démarrage
    // irait rechercher la même branche morte dans le compte et rejouerait le
    // même 422, indéfiniment.
    onUnknownBranch: (_) async {
      await ref.read(branchScopeStoreProvider).forget();
      await ref.read(branchScopeMirrorProvider).write(null);
    },
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
///
/// **Au retour au premier plan, les flux se relisent** (#138) : le réveil push
/// d'une application en arrière-plan écrit par une **autre connexion** au même
/// fichier, et avance le curseur — le cycle du retour n'a alors plus rien à
/// écrire, et aucun flux de l'isolate principal ne serait prévenu. On marque
/// donc comme modifiées les tables des collections synchronisées, plus l'écho
/// optimiste du fil (`pending_group_messages`), que lisent les mêmes requêtes.
final syncSchedulerProvider = Provider<SyncScheduler>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final scheduler = SyncScheduler(ref.watch(syncEngineProvider).synchronize)
    ..onForeground = () => database.markTablesUpdated({
          for (final collection in syncedCollections())
            collection.tableIn(database.syncDao),
          database.pendingGroupMessages,
          // L'outbox de la lecture (#140) entre dans le calcul des non-lus :
          // ses flux se relisent avec les autres.
          database.pendingGroupReads,
        });
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

/// **Le déclencheur du canal temps réel** (#140), sous la même forme que
/// [pullToRefreshProvider] : un cycle de **rattrapage**, demandé par
/// `MessagingLink` à chaque (re)connexion du canal `users/{id}` et quand une
/// ligne reçue cite un groupe que le magasin ne connaît pas.
///
/// Le canal range lui-même les lignes qu'il porte ; ce cycle comble ce qu'il a
/// pu manquer (coupure, bascule bleu/vert — piège 4 du plan).
///
/// Le drapeau `AppEnv.useBackend` se lit **ici**, comme pour le
/// tirer-pour-rafraîchir : sans backend il n'y a rien à synchroniser.
final realtimeSyncProvider = Provider<Future<void> Function()>((ref) {
  if (!AppEnv.useBackend) return () async {};
  return () => ref.read(syncSchedulerProvider).trigger(SyncTrigger.realtime);
});
