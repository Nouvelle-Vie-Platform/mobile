/// **Ce qu'un réveil dit, et ce qu'il ne peut pas dire.**
///
/// Les deux réveils silencieux du serveur sont des messages FCM `data` dont le
/// contenu est **structurellement absent** (ADR-0006 : la base est la seule source
/// de vérité, le push n'est qu'un accélérateur de notification) :
///
/// ```
/// { type: 'group_message', groupId: '…', messageId: '…' }   // GroupWakePayload
/// { type: 'group_message_muted', groupId, messageId }       // idem, en sourdine (M5)
/// { type: 'sync_nudge',    collection: 'announcements' }    // SyncNudgePayload
/// ```
///
/// Les formes sont relevées dans le code du serveur — `app/groups/contracts/
/// group_pusher.ts` et `app/sync/contracts/sync_pusher.ts` —, jamais devinées
/// depuis le client : un fixture qui recopie l'hypothèse du client ne teste plus
/// rien (CLAUDE.md, « le piège le plus coûteux du moteur »).
///
/// ## Pourquoi [PushWake] ne porte aucun champ de texte
///
/// C'est **la** décision de ce fichier, et ce n'est pas de la prudence : c'est ce
/// qui rend impossible la faute que la tranche doit éviter. [readPushWake] jette
/// toute clé qu'il ne nomme pas, donc un `body` ou un `title` glissé dans un push
/// — par le serveur, par un intermédiaire, par un attaquant qui pousserait sur un
/// jeton volé — n'a **aucun champ où atterrir**. Le handler ne peut donc pas
/// peindre une notification depuis la charge utile, même par accident : il n'y a
/// rien à peindre. Ce qu'il reçoit est un **type** et des **identifiants**, c'est
/// à dire de quoi aller chercher, jamais de quoi afficher.
///
/// Les notifications **visibles** (annonces, changements d'événement) ne passent
/// pas par ici : elles arrivent avec un bloc `notification` complet, et c'est le
/// système qui les dessine. Leur bloc `data` porte un `type` que ce fichier ne
/// connaît pas, et un type inconnu est **ignoré** — jamais rabattu sur un réveil
/// de substitution, pour la raison de `destinationKind` (#82) : un repli muet vaut
/// mieux qu'un repli faux.
library;

import 'package:flutter/foundation.dart';

import '../local/sync_dao.dart';

/// Un réveil lisible. Hiérarchie **scellée** : un `switch` qui oublie un cas ne
/// compile pas, et un troisième réveil ne pourra pas se glisser dans le code sans
/// que chaque lecteur ait été relu.
@immutable
sealed class PushWake {
  const PushWake();

  /// **Les collections à tirer avant de lire le magasin.**
  ///
  /// C'est tout ce dont le handler a besoin du réveil : il ne décide pas de ce
  /// qu'il affiche, il décide de ce qu'il va chercher.
  Set<String> get collections;
}

/// `{ type: 'group_message', groupId, messageId }` — un message est arrivé dans
/// une conversation.
///
/// [messageId] est un **indice de curseur** (UUIDv7 serveur), pas une donnée à
/// afficher : c'est par lui qu'on retrouve en magasin la ligne que la
/// synchronisation vient d'appliquer.
///
/// `{ type: 'group_message_muted', … }` (M5) est le **même** réveil, envoyé à
/// qui a mis la conversation en sourdine : on synchronise, on ne notifie pas.
/// [muted] le porte. Le serveur en décide à l'instant de l'envoi ; le magasin
/// en décide aussi, à l'instant de la lecture (une sourdine posée depuis ce
/// téléphone et pas encore arrivée au serveur) — l'une ou l'autre suffit.
final class GroupMessageWake extends PushWake {
  const GroupMessageWake({
    required this.groupId,
    required this.messageId,
    this.muted = false,
  });

  final String groupId;
  final String messageId;

  /// Le serveur sait la conversation en sourdine pour moi : pas d'alerte.
  final bool muted;

  /// **Quatre collections, et chacune porte un morceau de la notification.**
  ///
  /// | collection | ce qu'elle apporte |
  /// |---|---|
  /// | `group_messages` | le **texte** du message |
  /// | `profiles` | le **nom de l'auteur** |
  /// | `groups` | le **nom du fil**, donc le titre |
  /// | `group_members` | le fait que cette conversation est **mienne** |
  ///
  /// Les quatre sont nécessaires, et la plus facile à croire superflue est
  /// `groups` : « le groupe est déjà en magasin dès que j'en suis membre ». C'est
  /// vrai **sauf au premier message après une installation**, c'est-à-dire
  /// exactement le réveil qu'on remarque. Sans le nom du fil, la notification n'a
  /// pas de titre, et `conversationNotification` se tait alors — un réveil
  /// silencieux là où quelque chose venait d'arriver.
  ///
  /// `group_join_requests` n'y est pas, elle : une demande d'adhésion n'entre dans
  /// aucune notification de message, et un réveil n'a pas à payer un tirage dont il
  /// ne lira rien.
  ///
  /// L'ordre, lui, n'est **pas** décidé ici : c'est `synced_collection.dart` qui
  /// l'écrit, et `profiles` y passe donc avant `group_messages` sans qu'on ait à le
  /// redire — d'où un `Set` et non une liste.
  ///
  /// **Deux de plus depuis M5**, parce que la notification empile désormais
  /// les **non-lus** : `group_reads` dit où j'en suis (une conversation lue sur
  /// un autre appareil n'a plus rien à montrer, et sa notification s'efface), et
  /// `group_mutes` dit si je l'ai mise en sourdine ailleurs.
  @override
  Set<String> get collections => const {
        SyncCollectionKey.profiles,
        SyncCollectionKey.groups,
        SyncCollectionKey.groupMembers,
        SyncCollectionKey.groupReads,
        SyncCollectionKey.groupMutes,
        SyncCollectionKey.groupMessages,
      };

  @override
  bool operator ==(Object other) =>
      other is GroupMessageWake &&
      other.groupId == groupId &&
      other.messageId == messageId &&
      other.muted == muted;

  @override
  int get hashCode => Object.hash(groupId, messageId, muted);

  @override
  String toString() =>
      'GroupMessageWake($groupId, $messageId${muted ? ', muet' : ''})';
}

/// `{ type: 'sync_nudge', collection }` — une collection a changé.
///
/// Aucune notification n'en découle : l'UX de réveil des domaines autres que les
/// messages est hors périmètre (#97, PRD §7). Ce qu'il fait est ce qu'il annonce —
/// il **pousse le moteur**, et les écrans se repeignent du magasin. C'est déjà
/// tout l'intérêt d'un nudge.
final class SyncNudgeWake extends PushWake {
  const SyncNudgeWake(this.collection);

  final String collection;

  @override
  Set<String> get collections => {collection};

  @override
  bool operator ==(Object other) =>
      other is SyncNudgeWake && other.collection == collection;

  @override
  int get hashCode => collection.hashCode;

  @override
  String toString() => 'SyncNudgeWake($collection)';
}

/// **Lit un bloc `data` de push.** Rend `null` pour tout ce qui n'est pas un
/// réveil silencieux connu — y compris une charge utile de notification visible,
/// qu'il n'y a rien à faire d'ici.
///
/// FCM ne transporte que des chaînes dans `data` : la carte arrive en
/// `Map<String, Object?>` parce que c'est ce que rendent les deux plateformes, et
/// chaque valeur est relue en `String?`. Une valeur manquante ou d'un autre type
/// rend `null` — un réveil tronqué ne se devine pas.
PushWake? readPushWake(Map<String, Object?> data) {
  final type = _text(data['type']);
  switch (type) {
    case 'group_message':
    case 'group_message_muted':
      final groupId = _text(data['groupId']);
      final messageId = _text(data['messageId']);
      if (groupId == null || messageId == null) return null;
      return GroupMessageWake(
        groupId: groupId,
        messageId: messageId,
        muted: type == 'group_message_muted',
      );
    case 'sync_nudge':
      final collection = _text(data['collection']);
      if (collection == null) return null;
      return SyncNudgeWake(collection);
    default:
      // Un type inconnu — une notification visible, ou un réveil d'une version
      // de serveur plus récente. On ne fait rien, et surtout pas « au mieux ».
      return null;
  }
}

/// Une chaîne non vide, ou `null`. La chaîne vide est traitée comme une absence :
/// un `groupId` vide ne désigne aucun fil.
String? _text(Object? raw) {
  if (raw is! String) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}
