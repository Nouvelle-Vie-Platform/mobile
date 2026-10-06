/// **Le réveil d'une application fermée**, et le câblage qu'il exige.
///
/// Firebase réveille l'application dans un **isolate séparé** : rien de ce que
/// `main()` a construit n'y existe — ni conteneur Riverpod, ni magasin ouvert, ni
/// client HTTP câblé. Tout est donc remonté ici, le temps d'un réveil, puis refermé.
///
/// Ce fichier ne connaît **pas** Firebase, et c'est le même partage que le lecteur
/// web (« deux fichiers, une porte ») : `fcm_push_transport.dart` porte le point
/// d'entrée annoté `@pragma('vm:entry-point')` et aplatit le `RemoteMessage` en une
/// carte ; ici vivent les décisions, sans aucun type de greffon dans la signature.
///
/// ## Cinq choses qui se rateraient en silence
///
/// 1. **`DartPluginRegistrant.ensureInitialized()` d'abord.** Dans un isolate de
///    fond, aucun greffon n'est enregistré : sans cet appel, le coffre
///    (`flutter_secure_storage`) et le magasin (`sqlite3_flutter_libs`) lèvent, et
///    le réveil échoue entièrement — sans rien à l'écran, puisqu'il n'y en a pas.
/// 2. **Le garde du mode invité doit être câblé ici aussi.** Sans
///    `HttpDeviceRepository.wire()`, un 401 sur un jeton d'appareil ne se
///    renouvelle pas : `ApiClient` **purge le coffre**, et l'application se
///    retrouverait sans porteur au prochain lancement — déconnectée par un réveil,
///    la pire façon de perdre sa session.
/// 3. **Le moteur est restreint, et il ne persiste donc pas la version de
///    périmètre** (`persistsScopeVersion: false`). Voir `sync_engine.dart` : la
///    persister après un cycle partiel éteindrait pour toujours un resync que les
///    autres collections n'ont pas fait.
/// 4. **La base se referme.** Un isolate de fond est tué sans préavis ; laisser le
///    fichier ouvert risquerait un verrou que l'isolate principal retrouverait au
///    retour au premier plan.
/// 5. **Rien ne lève vers l'appelant.** Une exception dans un handler de fond est
///    invisible et peut faire considérer le message comme non délivré par l'OS. On
///    avale, comme partout dans ce dépôt sur un chemin muet.
library;

import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';

import '../../core/config/app_env.dart';
import '../branch_scope/branch_scope_store.dart';
import '../devices/http_device_repository.dart';
import '../local/app_database.dart';
import '../local/sync_dao.dart' show SyncCollectionKey;
import '../local/user_cache.dart';
import '../messaging/group_read_advancer.dart';
import '../messaging/messaging_store_writer.dart';
import '../repositories/group_message_composer.dart';
import '../repositories/group_message_sender.dart';
import '../sync/sync_api.dart';
import '../sync/sync_engine.dart';
import '../sync/synced_collection.dart';
import 'conversation_notification.dart';
import 'notification_action_handler.dart';
import 'notification_texts.dart';
import 'push_wake_handler.dart';
import 'wake_notifier.dart';

/// Traite un réveil reçu **application fermée**. Ne lève jamais.
///
/// [data] est le bloc `data` du push, aplati par l'appelant : ce fichier n'a donc
/// aucun type de Firebase dans sa signature, et le handler qu'il monte est le
/// **même** que celui du premier plan.
Future<void> handleBackgroundWake(Map<String, Object?> data) async {
  DartPluginRegistrant.ensureInitialized();

  if (!AppEnv.useBackend) return;

  // Le garde du mode invité, avant la première requête : voir le point 2 de
  // l'en-tête. Son retour ne nous intéresse pas — on ne le garde pas non plus,
  // l'isolate meurt avec le réveil.
  HttpDeviceRepository.wire();

  final database = AppDatabase.defaults();
  try {
    final notifier = LocalWakeNotifier();
    await notifier.prepare();

    final handler = PushWakeHandler(
      synchronize: (collections) => _pull(database, collections),
      store: await _storeFor(database),
      notifier: notifier,
      texts: notificationTextsForSystem(),
    );
    await handler.handle(data);
  } on Object catch (error, stackTrace) {
    debugPrint('[push] réveil de fond abandonné : $error\n$stackTrace');
  } finally {
    await database.close();
  }
}

/// **Traite une action de notification** (« Répondre », « Marquer comme lu »,
/// M5) dans l'isolate de fond que le greffon a démarré. Ne lève jamais.
///
/// Les mêmes précautions que [handleBackgroundWake], pour les mêmes raisons :
/// greffons enregistrés d'abord, garde du porteur d'appareil câblée avant la
/// première requête, base refermée à la fin. Le geste lui-même est décrit — et
/// testé — dans [notificationActionHandlerFor].
///
/// ⚠️ **L'écriture se fait par une autre connexion** que celle de l'isolate
/// principal (#138, point 9 de `CLAUDE.md`) : l'écho de la réponse
/// (`pending_group_messages`), la lecture (`pending_group_reads`,
/// `group_reads`) et les lignes tirées ne sont vus de l'application ouverte
/// qu'au `markTablesUpdated` de son retour au premier plan — qui couvre déjà ces
/// tables-là. Rien à ajouter au registre.
Future<void> handleBackgroundNotificationAction(
  NotificationAction action,
) async {
  DartPluginRegistrant.ensureInitialized();

  if (!AppEnv.useBackend) return;
  HttpDeviceRepository.wire();

  final database = AppDatabase.defaults();
  try {
    final notifier = LocalWakeNotifier();
    await notifier.prepare();

    final handler = notificationActionHandlerFor(
      database,
      store: await _storeFor(database),
      sender: HttpGroupMessageSender(),
      readSender: HttpGroupReadSender(),
      notifier: notifier,
      texts: notificationTextsForSystem(),
      synchronize: (collections) => _pull(database, collections),
    );
    await handler.handle(action);
  } on Object catch (error, stackTrace) {
    debugPrint(
        '[push] action de notification abandonnée : $error\n$stackTrace');
  } finally {
    await database.close();
  }
}

/// **Le câblage d'une action de notification sur un magasin** — exposé pour
/// les tests, qui le montent sur une base en mémoire avec des doubles du
/// réseau. C'est le chemin du fond, isolate excepté.
///
/// Le composeur est **celui du fil** ([GroupMessageComposer]) : même clé
/// d'idempotence, même écho, même renvoi automatique s'il échoue. Sa
/// resynchronisation est un cycle **ciblé** sur le fil et la lecture — de quoi
/// ramener la ligne serveur de la réponse, puis la position qu'on avance.
NotificationActionHandler notificationActionHandlerFor(
  AppDatabase database, {
  required WakeStore store,
  required GroupMessageSender sender,
  required GroupReadSender readSender,
  required WakeNotifier notifier,
  required NotificationTexts texts,
  required TargetedSync synchronize,
}) {
  final writer = MessagingStoreWriter(database);
  return NotificationActionHandler(
    composer: GroupMessageComposer(
      dao: database.groupDao,
      sender: sender,
      resynchronize: () => synchronize(const {
        SyncCollectionKey.groupReads,
        SyncCollectionKey.groupMessages,
      }),
    ),
    reads: GroupReadAdvancer(
      dao: database.groupDao,
      sender: readSender,
      storeRead: (row) => writer.store(SyncCollectionKey.groupReads, row),
    ),
    latestMessage: latestMessageFrom(database.groupDao),
    notifier: notifier,
    refresher: NotificationRefresher(
      store: store,
      notifier: notifier,
      texts: texts,
    ),
  );
}

/// **Ce que le fond lit du magasin**, pour l'utilisateur dont le téléphone
/// garde la session. Le coffre est lu ici, une fois : un isolate de fond n'a
/// pas d'`authProvider`. Pas de compte (invité, déconnecté) → aucune
/// conversation, donc aucune notification de message.
Future<WakeStore> _storeFor(AppDatabase database) async {
  final me = (await UserCache().read())?.id;
  return StoreWakeStore(
    groups: database.groupDao,
    showPreview: database.settingsDao.notificationPreview,
    userId: () => me,
  );
}

/// **Un cycle ciblé.** Le registre réduit aux collections nommées par le réveil,
/// dans l'ordre du registre — `synced_collection.dart` reste la seule autorité de
/// cet ordre, et `profiles` y passe donc avant `group_messages` sans qu'on ait à le
/// redire ici.
Future<void> _pull(AppDatabase database, Set<String> collections) async {
  final restricted = syncedCollections()
      .where((collection) => collections.contains(collection.key))
      .toList(growable: false);

  // Un réveil qui nomme une collection que ce client ne réplique pas : il n'y a
  // rien à tirer, et surtout pas « tout ». Un registre vide ferait un cycle qui
  // demande un manifeste pour rien.
  if (restricted.isEmpty) return;

  await SyncEngine(
    api: SyncApi(),
    dao: database.syncDao,
    collections: restricted,
    // **La préférence de branche part aussi d'ici**, et ce n'est pas une
    // précaution : un `sync_nudge` peut nommer `teachings` ou `announcements`, qui
    // sont filtrées (`kBranchScopedCollections`). Un cycle de fond sans filtre y
    // écrirait les lignes des huit autres assemblées, et le fidèle les retrouverait
    // sur son accueil au réveil suivant — sans que rien ne dise d'où elles viennent.
    //
    // Le rappel de **422** n'est pas branché, lui, et c'est délibéré : oublier une
    // préférence est un geste qui touche les curseurs de quatre collections, et il
    // n'a rien à faire dans un isolate de fond que l'OS peut tuer au milieu. Le
    // réveil échoue alors, et le cycle complet suivant le rattrape — c'est
    // exactement ce que `SyncEngine.synchronize` fait quand `onUnknownBranch` est nul.
    branchId: BranchScopeStore(database).read,
    // Voir le point 3 de l'en-tête, et `sync_engine.dart`.
    persistsScopeVersion: false,
  ).synchronize();
}
