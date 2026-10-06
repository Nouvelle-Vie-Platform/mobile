/// **Quels gestes offrir sur un message** (tranche M2, #141 ; plan
/// `messagerie-whatsapp-plan.md`, décision 5) — écrit une fois, testé seul.
///
/// Le serveur reste le seul juge : ces règles ne servent qu'à **ne pas offrir**
/// un geste qui prendrait un refus (la règle de `canWrite`). L'horloge du
/// téléphone et le magasin peuvent être en retard ; un refus tardif se dit
/// alors en clair (`GestureOutcome.windowClosed`).
library;

import 'echanges_view.dart';

/// **Modifier** : dans les 15 minutes qui suivent l'envoi (instant serveur).
const Duration kMessageEditWindow = Duration(minutes: 15);

/// **Supprimer pour tous** : dans les 2 jours (un administrateur, toujours).
const Duration kDeleteForEveryoneWindow = Duration(days: 2);

/// **Le jeu rapide de réactions**, dans l'ordre de WhatsApp. « + » ouvre le
/// reste ([kMoreReactions]).
const List<String> kQuickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

/// Ce que « + » propose au-delà du jeu rapide — une palette courte et sobre,
/// sans dépendance de sélecteur d'emoji.
const List<String> kMoreReactions = [
  '🙌', '👏', '🔥', '🎉', '💯', '✅', '🤝', '💪', //
  '😊', '😍', '🥰', '😇', '🤗', '🤔', '😅', '😭', //
  '😡', '😱', '🙄', '😴', '👀', '💔', '💐', '🕊️', //
  '✝️', '📖', '⛪', '🎶', '☀️', '🌍', '👌', '👎', //
];

/// Les gestes du menu d'appui long, dans l'ordre où ils s'affichent.
enum MessageAction {
  reply,
  copy,
  forward,
  edit,

  /// « Infos du message » (M3, #142) : qui a reçu, qui a lu — mes messages.
  info,
  deleteForMe,
  deleteForEveryone,
}

/// **Les gestes que ce message admet, pour moi, maintenant.**
///
/// - un **écho** (pas encore confirmé) n'a pas d'identité serveur : on ne peut
///   que le copier ;
/// - un message **supprimé pour tous** ne garde que « supprimer pour moi » ;
/// - **répondre** exige de pouvoir écrire ([canWrite]) ;
/// - **modifier** : le mien, du texte, dans les 15 minutes, et la barre de
///   saisie présente ([canWrite]) ;
/// - **supprimer pour tous** : administrateur ([isAdmin]) à tout moment, ou le
///   mien dans les 2 jours ;
/// - **infos** (M3, #142) : mes messages confirmés et vivants ;
/// - **supprimer pour moi** : toujours, sur un message confirmé.
Set<MessageAction> availableMessageActions(
  GroupMessageView message, {
  required bool isAdmin,
  required bool canWrite,
  required DateTime now,
}) {
  if (!message.isConfirmed) {
    return {if (message.body != null) MessageAction.copy};
  }
  if (message.deleted) return {MessageAction.deleteForMe};

  final createdAt = message.createdAt;
  final age = createdAt == null ? null : now.difference(createdAt);
  final withinEdit = age != null && age <= kMessageEditWindow;
  final withinDelete = age != null && age <= kDeleteForEveryoneWindow;

  return {
    if (canWrite) MessageAction.reply,
    if (message.body != null) MessageAction.copy,
    MessageAction.forward,
    // Modifier passe par la barre de saisie : sans elle (lecture seule), pas
    // de modification offerte.
    if (canWrite && message.mine && message.body != null && withinEdit)
      MessageAction.edit,
    if (message.mine) MessageAction.info,
    MessageAction.deleteForMe,
    if (isAdmin || (message.mine && withinDelete))
      MessageAction.deleteForEveryone,
  };
}

/// **Peut-on réagir à ce message ?** Confirmé, et pas supprimé.
bool canReactTo(GroupMessageView message) =>
    message.isConfirmed && !message.deleted;

/// **Peut-on y répondre en glissant ?** Les mêmes conditions que « Répondre »
/// dans le menu.
bool canSwipeToReply(GroupMessageView message, {required bool canWrite}) =>
    canWrite && message.isConfirmed && !message.deleted;
