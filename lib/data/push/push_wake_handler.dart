/// **Le handler de réveil push** — le cœur de D6 : réveil silencieux → sync
/// ciblée → notification LOCALE composée **depuis le magasin**.
///
/// La chaîne, pièce par pièce (`docs/prd/notifications-push.md`) :
///
/// 1. Un push **content-free** (`{ type, groupId, messageId }`) réveille l'app
///    (FCM data ou UnifiedPush) ; [PushWakePayload] l'a déjà décodé.
/// 2. Le handler **déclenche une sync** — via un callback [onSync], jamais une
///    dépendance dure au `SyncScheduler`. Exactement le patron du `RealtimeService`
///    (D1 de `docs/temps-reel-sse.md`) : le SSE/push **déclenche** un cycle
///    (`SyncTrigger.push`), il ne peint jamais le message. Le message arrive
///    ensuite par le flux delta comme d'habitude.
/// 3. Une fois synchronisé, le handler **lit le message dans le magasin** par
///    `(groupId, messageId)`, compose le contenu — titre = nom du **groupe**, ou
///    du **pair** pour un DM (via `profiles`) ; corps = **texte** du message — et
///    le remet à un [LocalNotifier].
///
/// **Content-free jamais peint ; tout vient du magasin** (D1/D6, ADR-0026 — le
/// réseau/le réveil ne peint jamais). Corollaire assumé : si le message reste
/// **introuvable après la sync** (course — la page delta ne l'a pas encore
/// ramené, ou il a été tombstoné entre-temps), on **ne notifie pas**
/// (silencieux) plutôt que d'inventer un contenu. Un réveil sans notification
/// vaut mieux qu'une notification sans vérité.
///
/// Ce fichier ne dépend d'**aucun** plugin natif : `onSync` est un callback,
/// l'accès au magasin est un [GroupDao] (100% VM), et la peinture est derrière
/// [LocalNotifier] (double inerte par défaut). Il se prouve entièrement sous
/// `flutter test`.
library;

import '../local/app_database.dart';
import '../local/group_dao.dart';
import 'local_notifier.dart';
import 'push_wake_payload.dart';

/// Réveil → sync → notification locale, à partir d'un réveil déjà décodé.
class PushWakeHandler {
  PushWakeHandler({
    required Future<void> Function() onSync,
    required GroupDao groupDao,
    required LocalNotifier notifier,
    this.currentUserId,
  })  : _onSync = onSync,
        _groupDao = groupDao,
        _notifier = notifier;

  /// **Déclenche une sync et rend la main une fois le cycle terminé.** C'est le
  /// point d'accroche du `SyncScheduler` (via `SyncTrigger.push`), injecté par
  /// l'app — le handler ne connaît pas le planificateur, comme le `RealtimeService`.
  final Future<void> Function() _onSync;

  /// **L'accès lecture au magasin.** Le handler lit, il n'écrit jamais : c'est la
  /// sync qui a rempli le magasin.
  final GroupDao _groupDao;

  /// **La peinture de la notification**, derrière l'abstraction — double inerte
  /// sous test et tant que le maillon `flutter_local_notifications` n'est pas là.
  final LocalNotifier _notifier;

  /// L'identité de l'acteur, nécessaire pour résoudre le **pair d'un DM** (l'autre
  /// membre, `userId != moi`) via `profiles`. Sans elle, un DM ne saura pas se
  /// titrer par le pair ; un groupe se titre par son nom sans en avoir besoin.
  final String? currentUserId;

  /// **Traite un réveil décodé** : sync, puis lecture + composition + notification.
  ///
  /// Séquence stricte — la sync **d'abord**, sinon on lirait un magasin périmé qui
  /// ne connaît pas encore le message. Silencieux (aucune notification) si, après
  /// la sync, le message ou le groupe reste introuvable.
  Future<void> handle(PushWakePayload payload) async {
    // 1. Réveil → sync ciblée. On attend la fin du cycle avant de lire.
    await _onSync();

    // 2. Le message, lu par (groupId, messageId). Introuvable = course → silence.
    final message = await _messageById(payload.groupId, payload.messageId);
    if (message == null) return;

    // 3. Le fil, pour composer le titre (nom du groupe, ou du pair d'un DM).
    final group = await _groupDao
        .watchGroup(payload.groupId, currentUserId)
        .getSingleOrNull();
    if (group == null) return;

    final title = group.group.isDirect
        // DM : le pair (jointure `profiles`). Vide tant que le profil n'est pas
        // synchronisé — jamais un nom inventé.
        ? (group.peerProfile?.displayName ?? '')
        // Groupe : son nom.
        : group.group.name;

    await _notifier.show(
      PushNotificationContent(
        title: title,
        body: message.body ?? '',
        conversationId: payload.groupId,
      ),
    );
  }

  /// Lit un message par son identifiant dans un groupe donné. Rend `null` s'il
  /// n'est pas (encore) dans le magasin. S'appuie sur la lecture existante du DAO
  /// (`watchMessages`) — le handler ne connaît que des lectures publiques.
  Future<GroupMessageRow?> _messageById(String groupId, String messageId) async {
    final messages = await _groupDao.watchMessages(groupId).get();
    for (final message in messages) {
      if (message.id == messageId) return message;
    }
    return null;
  }
}
