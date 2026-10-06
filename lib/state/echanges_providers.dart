/// **Les providers de la rubrique « Échanges »** (#96).
///
/// Même découpage que la médiathèque et les annonces : des `StreamProvider` de
/// **lecture** adossés au magasin, et **un seul** provider qui parle au réseau —
/// le composeur de messages.
///
/// ## ⚠️ L'acteur entre par un **paramètre de famille**, jamais par `ref.watch`
///
/// Toutes les lectures de cette rubrique ont besoin de savoir **qui je suis** :
/// mes conversations se lisent sur *mes* appartenances, « à rejoindre » veut dire
/// « dont je ne suis pas membre », et le `mine` d'une bulle est une comparaison à
/// mon identifiant.
///
/// La forme évidente — un `Provider` qui lit [echangesActorProvider], lui-même
/// lisant `authProvider` — **a été écrite, et elle casse l'application**. Elle
/// pose une chaîne de providers **synchrones** entre `authProvider` et les flux de
/// lecture, et le hub vit dans l'`IndexedStack` de la coquille, donc en permanence.
/// Le chemin qui tombe est exactement le plus courant : un invité touche l'onglet
/// Échanges, `requireSession()` **pousse** le parcours de connexion par-dessus la
/// coquille — ce qui met ses abonnements en pause (`TickerMode`) —, la connexion
/// aboutit, l'acteur change, la route se dépile, et Riverpod **vide la chaîne
/// pendant la construction** de l'overlay : « setState() or markNeedsBuild() called
/// during build ». L'application se peint en rouge au moment précis où quelqu'un
/// vient de se connecter.
///
/// Un paramètre de famille n'a pas ce défaut, et c'est structurel : un acteur
/// différent est une **autre clé**, donc un élément de provider **neuf** — rien
/// n'est invalidé, donc rien n'est à vider pendant un build. Le prix est une ligne
/// par écran (`ref.watch(echangesActorProvider)`), et un widget qui se reconstruit
/// sur un changement d'authentification est, lui, un chemin éprouvé : l'onglet
/// Profil le fait depuis toujours.
///
/// `test/screens/guest_tabs_test.dart` verrouille les deux gestes qui l'avaient
/// révélé.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/local/sync_dao.dart' show SyncCollectionKey;
import '../data/messaging/group_history.dart';
import '../data/messaging/group_mute_setter.dart';
import '../data/messaging/group_read_advancer.dart';
import '../data/messaging/message_gestures.dart';
import '../data/messaging/messaging_channel.dart';
import '../data/messaging/messaging_link.dart';
import '../data/messaging/messaging_store_writer.dart';
import '../data/messaging/sse_messaging_channel.dart';
import '../data/push/notification_reconciler.dart';
import '../data/repositories/echanges_repository.dart';
import '../data/repositories/group_message_composer.dart';
import '../data/repositories/group_message_sender.dart';
import '../data/repositories/store_echanges_repository.dart';
import '../models/echanges_view.dart';
import 'auth_providers.dart';
import 'chat_organization_providers.dart';
import 'receipts_providers.dart'
    show deliveryAcknowledgerProvider, messagingSignalHandlerProvider;
import 'push_providers.dart';
import 'sync_providers.dart';

/// Politique de réessai : **aucun réessai automatique**, comme la médiathèque et
/// l'agenda.
///
/// Riverpod 3 réessaie tout seul un provider en échec, jusqu'à dix fois avec une
/// attente qui double. Sur une lecture de **magasin local**, un échec n'est pas
/// une intermittence de réseau qu'attendre pourrait résoudre : c'est une base
/// illisible. Insister ne ferait que retarder l'aveu.
Duration? _noAutomaticRetry(int retryCount, Object error) => null;

/// **Moi**, ou `null` — lu par les **écrans**, qui le passent ensuite en clé de
/// famille. Voir l'en-tête du fichier : il ne doit jamais être lu par un autre
/// provider.
final echangesActorProvider = Provider<String?>(
  (ref) => ref.watch(authProvider).user?.id,
);

/// **La clé d'une lecture qui porte un identifiant** : l'acteur, et la chose
/// demandée.
///
/// Un `record` plutôt que deux familles imbriquées : les records sont comparés par
/// valeur en Dart, donc deux lectures du même fil par le même acteur partagent bien
/// un seul élément de provider.
typedef EchangesKey = ({String? actor, String id});

/// Fournit l'implémentation d'[EchangesRepository] **pour un acteur donné**.
///
/// Avec backend **et** une session : le **magasin local**, que la synchronisation
/// alimente. Le réseau ne peint jamais (ADR-0026) — c'est ce qui rend une
/// conversation relisible hors ligne dès la première image.
///
/// Sans l'un ou l'autre : le double **vide**.
///
/// ⚠️ **Vide, et non plus `SampleData`.** `InMemoryChurchRepository` était le seul
/// double câblé en production sans condition, et il servait quatre groupes, sept
/// conversations et le même fil de cinq messages pour toutes les discussions. Une
/// application sans backend montre désormais une rubrique vide, ce qui est la
/// vérité. Et sans session il n'y a rien non plus : le serveur ne sert aucune de
/// ces collections à un porteur sans compte — les trois privées sont refusées, les
/// deux `branch` sont servies **vides**.
final echangesRepositoryProvider =
    Provider.family<EchangesRepository, String?>((ref, actor) {
  if (!AppEnv.useBackend || actor == null) {
    return InMemoryEchangesRepository();
  }
  return StoreEchangesRepository(ref.watch(groupDaoProvider), userId: actor);
});

/// **Mes conversations**, groupes et tête-à-tête mêlés, triées par récence.
final conversationsProvider =
    StreamProvider.family<List<ConversationView>, String?>(
  (ref, actor) => ref.watch(echangesRepositoryProvider(actor)).conversations(),
  retry: _noAutomaticRetry,
);

/// **Les groupes à rejoindre** de la rangée de découverte.
final discoverGroupsProvider =
    StreamProvider.family<List<DiscoverGroupView>, String?>(
  (ref, actor) => ref.watch(echangesRepositoryProvider(actor)).discoverGroups(),
  retry: _noAutomaticRetry,
);

/// **La clé du fil** : l'acteur, le groupe, et la **fenêtre** — le nombre de
/// messages les plus récents à montrer (#140, historique par pages).
typedef ThreadKey = ({String? actor, String id, int limit});

/// La fenêtre d'ouverture d'un fil, et le pas dont elle s'élargit quand on
/// remonte. Le même nombre que la page de `GET /groups/:id/messages`.
const int kThreadWindow = kHistoryPageSize;

/// **Le fil d'un groupe**, écho optimiste compris, borné à ses [ThreadKey.limit]
/// derniers messages.
///
/// Un `StreamProvider` et non un `FutureProvider`, et ici cette règle porte un
/// nom : le **détachement d'auteur** (ADR-0032) arrive sur une ligne déjà
/// stockée. Une bulle affichée doit perdre son auteur sous les yeux du lecteur.
final groupThreadProvider =
    StreamProvider.family<List<GroupMessageView>, ThreadKey>(
  (ref, key) => ref
      .watch(echangesRepositoryProvider(key.actor))
      .thread(key.id, limit: key.limit),
  retry: _noAutomaticRetry,
);

/// **Le badge de l'onglet Échanges** (#140) : la somme des non-lus de mes
/// conversations, lue sur le même flux que la liste — le badge et les
/// pastilles des tuiles ne peuvent pas se contredire.
final unreadTotalProvider = Provider.family<int, String?>(
  (ref, actor) => totalUnread(
    ref.watch(conversationsProvider(actor)).value ?? const [],
  ),
);

/// **La fiche d'un groupe**, roster compris. `null` = le magasin ne connaît pas
/// cet identifiant, et c'est une **absence**, pas une erreur.
final groupDetailProvider =
    StreamProvider.family<GroupDetailView?, EchangesKey>(
  (ref, key) => ref.watch(echangesRepositoryProvider(key.actor)).group(key.id),
  retry: _noAutomaticRetry,
);

/// **La fiche d'une personne.** `null` tant que `profiles` ne l'a pas livrée.
final memberProfileProvider =
    StreamProvider.family<MemberProfileView?, EchangesKey>(
  (ref, key) => ref.watch(echangesRepositoryProvider(key.actor)).member(key.id),
  retry: _noAutomaticRetry,
);

/// **Le seul provider de cette rubrique qui parle au réseau.**
///
/// Il pose l'écho local, poste, déclenche un cycle de synchronisation et laisse le
/// flux delta ramener la ligne autoritaire. Sans backend, l'envoyeur est **inerte**
/// — il dit « parti » sans rien poster : l'écho reste alors au fil, ce qui est la
/// seule chose honnête quand aucun serveur ne viendra le confirmer.
///
/// Il ne dépend **pas** de l'acteur : le serveur lit l'auteur sur le porteur de la
/// requête, et la table locale de l'écho ne range pas par personne — elle est
/// vidée avec la base à la suppression de compte, comme tout le reste.
final groupMessageComposerProvider = Provider<GroupMessageComposer>(
  (ref) => GroupMessageComposer(
    dao: ref.watch(groupDaoProvider),
    sender: AppEnv.useBackend
        ? HttpGroupMessageSender()
        : const InertGroupMessageSender(),
    // Le même rappel que le tirer-pour-rafraîchir : un envoi réussi rejoint le
    // cycle en cours plutôt que d'en lancer un second, qui se disputerait les
    // mêmes curseurs.
    resynchronize: ref.watch(pullToRefreshProvider),
  ),
);

/// **Le canal temps réel de la messagerie** (#140) — SSE avec backend, muet
/// sinon. Le défaut de tous les tests (`pumpScreen` le pose muet).
final messagingChannelProvider = Provider<MessagingChannel>(
  (ref) => AppEnv.useBackend
      ? SseMessagingChannel()
      : const SilentMessagingChannel(),
);

/// **Range dans le magasin les lignes reçues hors du tirage** (#140) — canal,
/// historique, réponse de lecture —, par la même fonction que le tirage.
final messagingStoreWriterProvider = Provider<MessagingStoreWriter>(
  (ref) => MessagingStoreWriter(ref.watch(appDatabaseProvider)),
);

/// **Le lien `users/{monId}`** (#140), ouvert tant que la session est active —
/// et, par son observateur du cycle de vie, tant que l'application est au
/// premier plan. `null` sans backend ou sans session : un invité n'a pas de
/// canal (le serveur le lui refuse, `guestOnlyOnRadio`).
///
/// **Pas `autoDispose`** : personne ne l'affiche, il doit vivre aussi longtemps
/// que la session. `app.dart` l'écoute (`listenManual`), et c'est cet
/// abonnement qui le construit et le garde. Un changement de session (connexion,
/// déconnexion, autre compte) **reconstruit** le provider : `onDispose` ferme
/// l'ancien lien, et le nouveau s'ouvre sur le bon canal.
///
/// ⚠️ Il lit l'acteur par `ref.watch(authProvider.select(…))`, ce que l'en-tête de
/// ce fichier interdit aux **lectures d'écran**. La raison de l'interdit ne vaut
/// pas ici : aucun widget ne l'observe pendant un `build` — seul `app.dart`
/// l'écoute, hors de tout arbre de widgets —, il n'y a donc aucune chaîne à
/// vider pendant la construction d'un overlay.
final messagingLinkProvider = Provider<MessagingLink?>((ref) {
  if (!AppEnv.useBackend) return null;
  final userId = ref.watch(authProvider.select((state) => state.user?.id));
  if (userId == null) return null;

  final writer = ref.watch(messagingStoreWriterProvider);
  final link = MessagingLink(
    userId: userId,
    channel: ref.watch(messagingChannelProvider),
    apply: (event) => writer.store(event.collection, event.row),
    resynchronize: ref.watch(realtimeSyncProvider),
    // #142 (M3) : frappe, présence, et la distribution d'un message reçu.
    onSignal: ref.watch(messagingSignalHandlerProvider),
  );
  ref.onDispose(link.close);
  link.open();
  return link;
});

/// **L'outbox de la lecture** (#140) : `POST /groups/:id/read`, posé d'abord en
/// local, rejoué tant qu'il n'est pas confirmé. Inerte sans backend.
final groupReadAdvancerProvider = Provider<GroupReadAdvancer>((ref) {
  final writer = ref.watch(messagingStoreWriterProvider);
  return GroupReadAdvancer(
    dao: ref.watch(groupDaoProvider),
    sender: AppEnv.useBackend
        ? HttpGroupReadSender()
        : const InertGroupReadSender(),
    storeRead: (row) => writer.store(SyncCollectionKey.groupReads, row),
  );
});

/// **L'historique par pages** (#140), rangé dans le magasin. Sans backend : rien
/// au-delà de ce que le magasin possède.
final groupHistoryProvider = Provider<GroupHistory>((ref) {
  if (!AppEnv.useBackend) return const NoGroupHistory();
  final writer = ref.watch(messagingStoreWriterProvider);
  return HttpGroupHistory(store: writer.storeMessages);
});

/// **Le renvoi de tout ce qui n'est pas parti** (#140) : les messages en échec
/// (ou restés « en cours » par une application tuée) et les lectures non
/// confirmées. `app.dart` l'appelle après **chaque cycle réussi** — donc au
/// retour du réseau (la reconnexion du canal lance un cycle), au retour au
/// premier plan, et à l'ouverture. Jamais de doublon : chaque geste porte sa
/// clé (`clientMessageId`) ou est idempotent (la lecture).
final messagingOutboxProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await ref.read(groupMessageComposerProvider).resendUnconfirmed();
    await ref.read(groupReadAdvancerProvider).replay();
    // M8 (#146) : les rangements (archiver, épingler) posés hors ligne.
    await ref
        .read(groupArrangerProvider(ref.read(echangesActorProvider)))
        ?.replay();
    // #142 (M3) : ce que ce téléphone a rangé depuis, confirmé reçu (✓✓).
    await ref.read(deliveryAcknowledgerProvider)?.flush();
  };
});

// ─────────────────────────────────────────────────────────────────────────────
// La sourdine et les notifications (tranche M5)
// ─────────────────────────────────────────────────────────────────────────────

/// **Ma sourdine dans une conversation**, du magasin — `null` si je ne l'ai
/// jamais réglée. Le menu du fil la lit pour proposer « Mettre en sourdine » ou
/// « Réactiver les notifications ». La sourdine est-elle **active** ? C'est
/// `isGroupMuted`, à l'instant de l'affichage.
final groupMuteProvider = StreamProvider.family<GroupMuteRowView?, String>(
  (ref, groupId) =>
      ref.watch(groupDaoProvider).muteOf(groupId).watchSingleOrNull().map(
            (row) => row == null
                ? null
                : (mutedUntil: row.mutedUntil, mutedForever: row.mutedForever),
          ),
  retry: _noAutomaticRetry,
);

/// **Poser ou lever une sourdine** (M5) — en ligne, la ligne confirmée rangée
/// par la même fonction que le canal. Inerte sans backend.
final groupMuteSetterProvider = Provider<GroupMuteSetter>((ref) {
  final writer = ref.watch(messagingStoreWriterProvider);
  return GroupMuteSetter(
    sender: AppEnv.useBackend
        ? HttpGroupMuteSender()
        : const InertGroupMuteSender(),
    storeMute: (row) => writer.store(SyncCollectionKey.groupMutes, row),
  );
});

/// **Effacer, application ouverte, la notification d'une conversation lue**
/// (M5) — ici, ou ailleurs (`read.advanced` sur le canal). Voir
/// `NotificationReconciler`.
///
/// `null` sans notifieur d'effacement (aucun transport de réveil : rien à
/// effacer) ou sans session. Comme [messagingLinkProvider], il lit l'acteur
/// par `authProvider.select` — seul `app.dart` l'écoute, hors de tout `build`.
/// Pas `autoDispose` : il vit avec la session, et un changement de compte le
/// reconstruit sur les conversations du nouveau.
final notificationReconcilerProvider = Provider<Object?>((ref) {
  final dismisser = ref.watch(wakeDismisserProvider);
  if (dismisser == null) return null;
  final userId = ref.watch(authProvider.select((state) => state.user?.id));
  if (userId == null) return null;

  final reconciler = NotificationReconciler(notifier: dismisser);
  final subscription = ref
      .watch(groupDaoProvider)
      .conversationsOf(userId)
      .watch()
      .listen(reconciler.onConversations, onError: (Object _) {});
  ref.onDispose(subscription.cancel);
  return subscription;
});

/// Ce que le menu du fil lit de ma sourdine — sans le reste de la ligne.
typedef GroupMuteRowView = ({DateTime? mutedUntil, bool mutedForever});

/// **Les gestes sur un message** (M2, #141) — réagir, modifier, supprimer pour
/// moi ou pour tous, transférer. La ligne que rend le serveur se range aussitôt
/// par le même écrivain que le canal. Inerte sans backend.
final messageGesturesProvider = Provider<MessageGestures>((ref) {
  final writer = ref.watch(messagingStoreWriterProvider);
  return MessageGestures(
    sender: AppEnv.useBackend
        ? HttpMessageGestureSender()
        : const InertMessageGestureSender(),
    store: (collection, row) async {
      await writer.store(collection, row);
    },
  );
});

/// **Qui a réagi à un message** (M2, #141) — la feuille ouverte en touchant
/// l'agrégat sous une bulle.
final messageReactorsProvider =
    StreamProvider.family<List<ReactorView>, EchangesKey>(
  (ref, key) =>
      ref.watch(echangesRepositoryProvider(key.actor)).reactors(key.id),
  retry: _noAutomaticRetry,
);
