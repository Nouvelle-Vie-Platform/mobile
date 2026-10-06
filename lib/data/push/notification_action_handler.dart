/// **Ce que font les deux actions d'une notification de message** (tranche M5) :
/// « Répondre » et « Marquer comme lu ».
///
/// Ce fichier ne connaît ni le greffon de notification, ni Firebase, ni le
/// cycle de vie d'un isolate : il reçoit une [NotificationAction] déjà lue et
/// des collaborateurs injectés. C'est ce qui le rend testable de bout en bout —
/// le point d'entrée réel (`wakeActionEntryPoint`, dans un isolate de fond
/// démarré par le greffon) ne l'est pas, et n'est donc qu'un aplatisseur.
///
/// ## Répondre : **le même chemin que le composeur**
///
/// Pas un second envoi écrit pour l'occasion : [GroupMessageComposer], celui du
/// fil, avec sa **clé d'idempotence** frappée avant l'envoi et son écho posé
/// dans `pending_group_messages`. Conséquences, et ce sont celles qu'on veut :
///
/// - un envoi qui échoue (avion) n'est pas perdu : l'écho reste marqué « pas
///   parti », et le **renvoi automatique** du premier plan le reposte sous la
///   même clé au prochain cycle réussi (#140) — jamais de doublon (piège 5) ;
/// - le fil, rouvert, montre la réponse à sa place, comme si on l'avait tapée.
///
/// Répondre **marque aussi la conversation lue** — WhatsApp le fait, et c'est
/// juste : on ne répond pas sans avoir lu.
///
/// ## Marquer comme lu : **la même outbox que le fil**
///
/// [GroupReadAdvancer], jusqu'au dernier message que le magasin connaît. La
/// route est idempotente et monotone ; une lecture que le réseau perd reste
/// dans `pending_group_reads` et se rejoue (#140).
///
/// ## Et la notification
///
/// Le greffon l'a déjà retirée au geste (`cancelNotification`) ; on l'efface
/// quand même — un geste rejoué ne doit pas dépendre de ce détail —, puis on
/// recalcule le **résumé**, qui n'a peut-être plus rien à coiffer.
library;

import 'package:flutter/foundation.dart';

import '../local/group_dao.dart';
import '../messaging/group_read_advancer.dart';
import '../repositories/group_message_composer.dart';
import 'conversation_notification.dart';
import 'push_wake_handler.dart';
import 'wake_notifier.dart';

/// Une action lue sur une réponse du greffon. Hiérarchie **scellée**.
@immutable
sealed class NotificationAction {
  const NotificationAction(this.groupId);

  /// La conversation — lue sur la charge utile de la notification, qui est un
  /// identifiant de fil **venu du magasin**.
  final String groupId;
}

/// « Répondre », avec le texte saisi dans la notification.
final class ReplyAction extends NotificationAction {
  const ReplyAction(super.groupId, this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      other is ReplyAction && other.groupId == groupId && other.text == text;

  @override
  int get hashCode => Object.hash('reply', groupId, text);

  @override
  String toString() => 'ReplyAction($groupId, "$text")';
}

/// « Marquer comme lu ».
final class MarkReadAction extends NotificationAction {
  const MarkReadAction(super.groupId);

  @override
  bool operator ==(Object other) =>
      other is MarkReadAction && other.groupId == groupId;

  @override
  int get hashCode => Object.hash('mark_read', groupId);

  @override
  String toString() => 'MarkReadAction($groupId)';
}

/// **Lit une réponse du greffon.** `null` pour tout ce qui n'est pas une de nos
/// deux actions : un tap sur la notification (pas d'`actionId`), une action
/// inconnue, une réponse sans conversation, une réponse vide.
NotificationAction? readNotificationAction({
  String? actionId,
  String? payload,
  String? input,
}) {
  final groupId = payload?.trim();
  if (groupId == null || groupId.isEmpty) return null;
  switch (actionId) {
    case kReplyActionId:
      final text = input?.trim();
      // Android n'envoie pas de réponse vide, mais un clavier peut rendre des
      // espaces. Rien à poster : le composeur refuserait de toute façon.
      if (text == null || text.isEmpty) return null;
      return ReplyAction(groupId, text);
    case kMarkReadActionId:
      return MarkReadAction(groupId);
    default:
      return null;
  }
}

/// Le dernier message d'un groupe en magasin — `GroupDao.latestMessageOf`.
typedef LatestMessageLookup = Future<({String id, DateTime createdAt})?>
    Function(String groupId);

/// **Traite une action.** Ne lève jamais.
class NotificationActionHandler {
  NotificationActionHandler({
    required GroupMessageComposer composer,
    required GroupReadAdvancer reads,
    required LatestMessageLookup latestMessage,
    required WakeNotifier notifier,
    required NotificationRefresher refresher,
  })  : _composer = composer,
        _reads = reads,
        _latestMessage = latestMessage,
        _notifier = notifier,
        _refresher = refresher;

  final GroupMessageComposer _composer;
  final GroupReadAdvancer _reads;
  final LatestMessageLookup _latestMessage;
  final WakeNotifier _notifier;
  final NotificationRefresher _refresher;

  Future<void> handle(NotificationAction action) async {
    try {
      switch (action) {
        case ReplyAction(:final groupId, :final text):
          // Le composeur pose l'écho, poste sous sa clé, puis resynchronise :
          // si l'envoi a abouti, la ligne serveur est en magasin quand on lit
          // le dernier message ci-dessous, et la lecture avance jusqu'à elle.
          await _composer.send(groupId: groupId, body: text);
          await _markRead(groupId);
        case MarkReadAction(:final groupId):
          await _markRead(groupId);
      }
    } on Object catch (error) {
      _trace('action ${action.runtimeType} abandonnée : $error');
    }

    await _notifier.cancel(action.groupId);
    await _refresher.refresh();
  }

  Future<void> _markRead(String groupId) async {
    final latest = await _latestMessage(groupId);
    if (latest == null) return;
    await _reads.advance(
      groupId: groupId,
      messageId: latest.id,
      messageCreatedAt: latest.createdAt,
    );
  }

  void _trace(String message) {
    assert(() {
      debugPrint('[push] action de notification — $message');
      return true;
    }());
  }
}

/// [LatestMessageLookup] sur le magasin : le dernier message, s'il porte un
/// instant serveur — une position de lecture se compare dans l'ordre du fil,
/// `(createdAt, id)`, et un message sans instant n'en est pas une.
LatestMessageLookup latestMessageFrom(GroupDao dao) => (groupId) async {
      final row = await dao.latestMessageOf(groupId);
      final at = row?.createdAt;
      if (row == null || at == null) return null;
      return (id: row.id, createdAt: at);
    };
