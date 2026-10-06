/// **La notification d'une conversation, comme WhatsApp** (tranche M5, décision
/// 10 du plan `messagerie-whatsapp-plan.md`) — la **règle**, sans greffon.
///
/// Ce fichier décide de ce qui s'affiche ; `wake_notifier.dart` le traduit pour
/// `flutter_local_notifications`. La frontière est celle de #97 : une valeur
/// immuable et une fonction pure ici, testées sans canal natif ; le greffon
/// là-bas, et nulle part ailleurs.
///
/// ## Une notification par conversation, avec ses derniers messages
///
/// Le style « messagerie » d'Android (MessagingStyle) : le nom du groupe, et sous
/// lui les derniers messages **non lus**, chacun avec son auteur. Un second
/// message **remplace** la notification du même fil — même identifiant système
/// — en l'allongeant d'une ligne. Quand plusieurs conversations ont du nouveau,
/// un **résumé** les coiffe ([NotificationSummary]).
///
/// ## Tout vient du magasin (ADR-0006)
///
/// [conversationNotification] ne lit qu'un [ConversationDigest], c'est-à-dire
/// ce que Drift contient après la synchronisation du réveil. Le push ne porte
/// aucun texte, et c'est structurel (`push_wake.dart`).
///
/// ## Les textes d'interface
///
/// « Vous », « Répondre », « Nouveau message »… viennent des `.arb`, mais la
/// notification se dresse souvent dans un isolate **sans `BuildContext`** (le
/// réveil d'une application fermée). On les reçoit donc tout faits
/// ([NotificationTexts]), choisis par l'appelant dans la langue du téléphone.
library;

import 'package:flutter/foundation.dart';

import '../local/group_dao.dart';

/// Le **groupe Android** de toutes les notifications de messages : c'est lui
/// qui les range ensemble sous le résumé.
const String kMessagesGroupKey =
    'com.maisondumiracle.maison_du_miracle.group.messages';

/// L'identifiant système du **résumé**. Fixe : il n'y en a qu'un.
const int kMessagesSummaryId = 0x4d35;

/// L'action « Répondre » (champ de saisie dans la notification).
const String kReplyActionId = 'reply';

/// L'action « Marquer comme lu ».
const String kMarkReadActionId = 'mark_read';

/// Combien de messages une notification empile, au plus. Android en montre
/// lui-même une poignée ; au-delà, c'est le compteur qui parle.
const int kNotificationMessageLimit = 6;

/// **Les textes d'interface d'une notification**, déjà dans la bonne langue.
@immutable
class NotificationTexts {
  const NotificationTexts({
    required this.you,
    required this.newMessage,
    required this.newMessageFrom,
    required this.media,
    required this.removedAuthor,
    required this.reply,
    required this.replyHint,
    required this.markRead,
    required this.summaryTitle,
    required this.summaryText,
  });

  /// Le nom que MessagingStyle donne à **moi** (« Vous »).
  final String you;

  /// L'aperçu masqué, sans auteur connu (« Nouveau message »).
  final String newMessage;

  /// L'aperçu masqué, avec l'auteur (« Nouveau message de Ama »).
  final String Function(String name) newMessageFrom;

  /// Un message sans texte — un média (#140).
  final String media;

  /// L'auteur d'un message dont le compte a été supprimé (ADR-0032). Un
  /// **fait**, comme dans la bulle du fil — jamais un nom inventé.
  final String removedAuthor;

  final String reply;
  final String replyHint;
  final String markRead;

  /// « 5 nouveaux messages » — le titre du résumé.
  final String Function(int messages) summaryTitle;

  /// « dans 2 discussions » — sa seconde ligne.
  final String Function(int conversations) summaryText;
}

/// Une ligne de la notification : un message, et qui l'a écrit.
@immutable
class NotificationLine {
  const NotificationLine({
    required this.text,
    required this.at,
    this.authorKey,
    this.authorName,
  });

  final String text;
  final DateTime at;

  /// L'identifiant stable de l'auteur (MessagingStyle regroupe par lui), ou
  /// `null` quand on ne nomme personne.
  final String? authorKey;

  /// Le nom à afficher, ou `null` : aperçu masqué, ou profil pas encore arrivé.
  final String? authorName;

  @override
  bool operator ==(Object other) =>
      other is NotificationLine &&
      other.text == text &&
      other.at == at &&
      other.authorKey == authorKey &&
      other.authorName == authorName;

  @override
  int get hashCode => Object.hash(text, at, authorKey, authorName);

  @override
  String toString() => 'NotificationLine(${authorName ?? '-'}: "$text")';
}

/// **Ce qui s'affiche pour une conversation**, déjà décidé.
@immutable
class ConversationNotification {
  const ConversationNotification({
    required this.id,
    required this.groupId,
    required this.title,
    required this.isGroup,
    required this.lines,
    required this.unreadCount,
    required this.texts,
    this.alert = true,
  });

  /// L'identifiant **système**, dérivé du `groupId` : une notification par
  /// conversation, remplacée à chaque message.
  final int id;

  /// La conversation à ouvrir au tap, et que les deux actions désignent — lue
  /// du **magasin**, jamais du push.
  final String groupId;

  /// Le nom du groupe, ou — pour un tête-à-tête — celui de l'autre.
  final String title;

  /// Vrai pour un groupe : MessagingStyle y nomme l'auteur de chaque ligne.
  final bool isGroup;

  /// Les derniers non-lus, du plus ancien au plus récent. Jamais vide.
  final List<NotificationLine> lines;

  /// Le compteur : tous mes non-lus de la conversation.
  final int unreadCount;

  /// Les libellés des actions et le « Vous » de MessagingStyle.
  final NotificationTexts texts;

  /// `false` : mise à jour **silencieuse** (le contenu change, rien ne sonne).
  final bool alert;

  /// **Le corps d'une seule ligne** — celui des appareils qui ne savent pas
  /// dessiner MessagingStyle, et de l'écran verrouillé : le dernier message,
  /// préfixé de son auteur dans un groupe. Un auteur sans nom n'est pas
  /// préfixé : l'absence se rend comme une absence (#97).
  String get body {
    final last = lines.last;
    final name = last.authorName;
    if (isGroup && name != null && name.isNotEmpty) {
      return '$name : ${last.text}';
    }
    return last.text;
  }

  @override
  String toString() =>
      'ConversationNotification($id, "$title", $unreadCount, $lines)';
}

/// **Le résumé** qui coiffe les notifications de plusieurs conversations.
@immutable
class NotificationSummary {
  const NotificationSummary({
    required this.title,
    required this.text,
    required this.totalUnread,
    required this.conversations,
    required this.lines,
  });

  /// « 5 nouveaux messages ».
  final String title;

  /// « dans 2 discussions ».
  final String text;

  final int totalUnread;
  final int conversations;

  /// Une ligne par conversation (son titre), pour le style « boîte de
  /// réception » du résumé déplié.
  final List<String> lines;

  @override
  String toString() => 'NotificationSummary("$title", "$text")';
}

/// L'identifiant système de la notification d'une conversation : un entier
/// stable et positif, dérivé du `groupId` (iOS refuse les négatifs).
int conversationNotificationId(String groupId) => groupId.hashCode & 0x7fffffff;

/// **La règle.** Rend `null` quand il n'y a rien à annoncer : aucun non-lu, ou
/// une conversation que le magasin ne nomme pas encore. Mieux vaut se taire
/// qu'annoncer « (sans titre) ».
///
/// [showPreview] est le réglage « Afficher le contenu » : faux, la notification
/// ne porte plus qu'**une** ligne — « Nouveau message » pour un tête-à-tête,
/// « Nouveau message de Ama » pour un groupe — et aucun texte de message.
///
/// La sourdine **n'est pas** jugée ici : c'est le handler qui décide de montrer
/// ou non ; cette fonction dit seulement *quoi* montrer.
ConversationNotification? conversationNotification(
  ConversationDigest digest, {
  required bool showPreview,
  required NotificationTexts texts,
  bool alert = true,
}) {
  if (digest.unreadCount <= 0 || digest.messages.isEmpty) return null;

  final peer = _clean(digest.peerName);
  final group = _clean(digest.groupName);
  final title = digest.isDirect ? (peer ?? group) : group;
  if (title == null) return null;

  final isGroup = !digest.isDirect;
  final List<NotificationLine> lines;
  if (showPreview) {
    lines = [
      for (final message in digest.messages)
        _line(message, digest: digest, title: title, texts: texts),
    ];
  } else {
    // **L'aperçu masqué** : rien du texte, une seule ligne. Le nom de l'auteur
    // reste dans un groupe — c'est ce que WhatsApp montre, et c'est ce que le
    // réglage promet (« Nouveau message de Ama ») ; dans un tête-à-tête, le
    // titre le dit déjà.
    final last = digest.messages.last;
    final author = _clean(last.authorName);
    lines = [
      NotificationLine(
        text: isGroup && author != null
            ? texts.newMessageFrom(author)
            : texts.newMessage,
        at: last.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        // Aucun auteur sur la ligne : le nom, s'il y en a un, est **dans** le
        // texte. MessagingStyle n'a donc rien à préfixer.
        authorKey: isGroup ? null : digest.groupId,
        authorName: isGroup ? null : title,
      ),
    ];
  }

  return ConversationNotification(
    id: conversationNotificationId(digest.groupId),
    groupId: digest.groupId,
    title: title,
    isGroup: isGroup,
    lines: lines,
    unreadCount: digest.unreadCount,
    texts: texts,
    alert: alert,
  );
}

NotificationLine _line(
  DigestMessage message, {
  required ConversationDigest digest,
  required String title,
  required NotificationTexts texts,
}) {
  final body = message.body?.trim();
  final text = body == null || body.isEmpty ? texts.media : body;
  final at = message.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  // Un tête-à-tête n'a qu'un autre : c'est lui qui écrit, sous le nom du titre.
  if (digest.isDirect) {
    return NotificationLine(
      text: text,
      at: at,
      authorKey: message.authorId ?? digest.groupId,
      authorName: title,
    );
  }

  // `authorId` nul et non système (la formule des non-lus écarte le serveur) :
  // un auteur retiré. Le fait est dit comme le fil le dit (« Membre retiré »).
  if (message.authorId == null) {
    return NotificationLine(
      text: text,
      at: at,
      authorKey: 'removed',
      authorName: null,
    );
  }

  return NotificationLine(
    text: text,
    at: at,
    authorKey: message.authorId,
    // Profil pas encore arrivé : `null`, jamais un nom inventé.
    authorName: _clean(message.authorName),
  );
}

/// **Le résumé**, depuis mes conversations — ou `null` quand il n'y a rien à
/// coiffer : aucune conversation non lue et hors sourdine.
///
/// Les conversations en sourdine n'y comptent pas : elles ne notifient pas, et
/// le résumé ne doit pas annoncer ce qu'aucune notification ne montre.
NotificationSummary? notificationSummary(
  List<ConversationRecord> conversations, {
  required NotificationTexts texts,
  required DateTime now,
}) {
  final pending = [
    for (final c in conversations)
      if (c.unreadCount > 0 && !c.isMutedAt(now)) c,
  ];
  if (pending.isEmpty) return null;

  final total = pending.fold<int>(0, (sum, c) => sum + c.unreadCount);
  return NotificationSummary(
    title: texts.summaryTitle(total),
    text: texts.summaryText(pending.length),
    totalUnread: total,
    conversations: pending.length,
    lines: [
      for (final c in pending)
        c.isDirect ? (c.peerName ?? c.groupName) : c.groupName,
    ],
  );
}

String? _clean(String? raw) {
  final trimmed = raw?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
