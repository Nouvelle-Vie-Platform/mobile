/// **Ce que la page live montre au-dessus du son** (#135) : le direct, les
/// réactions, le fil et sa modération.
///
/// Contrat serveur (`server-portal`, issues #508 à #510) : `GET /radio/antenna`,
/// `GET /radio/comments`, `GET /radio/moderation/comments` et les événements du
/// canal `radio` (`app/radio/contracts/radio_channel.ts`). Les **mêmes formes**
/// circulent sur le fil et dans les lectures de resynchronisation — c'est ce qui
/// permet de **remplacer** l'affichage par une relecture après une coupure, sans
/// rien traduire.
///
/// ## Rien n'est stocké, et ce n'est pas un oubli
///
/// Pas de table Drift, pas de curseur, pas de collection de synchronisation : le
/// fil n'existe que pendant un direct (décision 5 du plan), il n'est jamais
/// rediffusé (décision 10), et un téléphone qui rouvre la page relit les
/// cinquante derniers messages. C'est la même règle que pour l'adresse
/// d'antenne : connaître le fil hors ligne ne sert à rien, puisqu'on ne peut pas
/// écouter hors ligne.
///
/// ## Lecteurs tolérants, jamais inventifs
///
/// Un champ illisible rend une absence (`null`, liste vide), jamais une valeur
/// fabriquée : un commentaire sans identifiant ne peut être ni masqué ni signalé,
/// il est donc écarté plutôt qu'affiché.
library;

import 'package:flutter/foundation.dart';

/// Le nombre de messages que le fil garde à l'écran — celui que le serveur rend
/// à la resynchronisation (`commentResyncLimit`). Au-delà, les plus anciens
/// tombent : la page n'est pas une archive.
const int kRadioCommentWindow = 50;

/// **Le trajet de la voix, de la régie à l'antenne** (mobile#187) : ce que met
/// le son du studio à atteindre le flux, en plus de l'heure de l'événement.
/// Le badge « EN DIRECT » s'allume à `startedAt + kLiveAudioLatency` entendus,
/// et s'éteint à `endedAt + kLiveAudioLatency`. Nommé **une seule fois** ;
/// **valeur à mesurer** au prochain direct (`radio-direct-aligne-plan.md`,
/// décision 6).
const Duration kLiveAudioLatency = Duration(seconds: 4);

/// **Le jeu de réactions, fixe** (décision 9) : ❤️ 🙏 🙌 🔥 « Amen ».
///
/// Le serveur ne manipule que les **identifiants ASCII** ([wire]) ; l'emoji est
/// un rendu, qui appartient au téléphone. L'ordre est celui de l'affichage, et
/// c'est aussi celui des clés de l'agrégat diffusé
/// (`app/radio/support/radio_reactions.ts`). Ajouter une réaction est un
/// changement de contrat, pas une ligne de configuration.
enum RadioReaction {
  heart('heart', '❤️'),
  pray('pray', '🙏'),
  praise('praise', '🙌'),
  fire('fire', '🔥'),

  /// « Amen » n'a pas d'emoji : il se rend en **mot**, et ce mot vit dans les
  /// `.arb` (`radioReactionAmen`) — l'écran le lit là, jamais ici.
  amen('amen', null);

  const RadioReaction(this.wire, this.emoji);

  /// L'identifiant du contrat (`POST /radio/reactions`, clés de l'agrégat).
  final String wire;

  /// Le rendu, `null` pour [amen].
  final String? emoji;

  /// `null` pour un identifiant inconnu — un serveur plus récent qui en
  /// ajouterait un ne doit rien casser ici.
  static RadioReaction? fromWire(Object? raw) {
    for (final reaction in values) {
      if (reaction.wire == raw) return reaction;
    }
    return null;
  }
}

/// **Le direct en cours** — `null` partout quand personne ne tient l'antenne.
///
/// Volontairement minuscule, comme côté serveur : l'instant d'ouverture, rien
/// d'autre. Le badge « EN DIRECT » et le fil en dépendent (décision 2).
@immutable
class RadioLive {
  const RadioLive({required this.startedAt});

  final DateTime startedAt;

  /// `null` pour tout ce qui n'est pas `{ startedAt: "<ISO 8601>" }` : un
  /// direct dont on ne sait pas lire l'ouverture n'est pas un direct qu'on peut
  /// annoncer.
  static RadioLive? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final started = _date(raw['startedAt']);
    return started == null ? null : RadioLive(startedAt: started);
  }

  @override
  bool operator ==(Object other) =>
      other is RadioLive && other.startedAt == startedAt;

  @override
  int get hashCode => startedAt.hashCode;

  @override
  String toString() => 'RadioLive(startedAt: $startedAt)';
}

/// Qui a écrit : un membre (« Ama K. ») ou un invité (son pseudo).
enum RadioAuthorKind { member, guest }

/// **Un commentaire du direct**, sous la forme du canal **et** de la relecture.
///
/// ⚠️ **Aucun identifiant d'auteur**, par contrat : un identifiant stable
/// permettrait de suivre une personne d'un direct à l'autre. Le modérateur agit
/// sur un **message**, et le serveur retrouve l'auteur.
@immutable
class RadioComment {
  const RadioComment({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.authorKind,
    required this.authorName,
    this.avatarUrl,
    DateTime? airedAt,
  }) : _airedAt = airedAt;

  /// UUIDv7 — la clé de masquage, de signalement et de dédoublonnage.
  final String id;
  final String body;
  final DateTime createdAt;

  final DateTime? _airedAt;

  /// **L'instant d'antenne que son auteur écoutait** (mobile#187) : c'est à
  /// cette heure entendue qu'il s'affiche chez chacun. Un serveur d'avant
  /// `airedAt` ne le donne pas : on prend [createdAt], l'heure de réception.
  DateTime get airedAt => _airedAt ?? createdAt;
  final RadioAuthorKind authorKind;

  /// Tel qu'affiché au moment d'écrire (décision 13).
  final String authorName;

  /// Toujours `null` aujourd'hui (pas de photo de profil) : le champ est au
  /// contrat pour que la photo arrive sans changer sa forme.
  final String? avatarUrl;

  bool get byGuest => authorKind == RadioAuthorKind.guest;

  /// `null` quand il manque de quoi agir dessus (identifiant) ou de quoi
  /// l'afficher (texte, nom).
  static RadioComment? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final body = raw['body'];
    final author = raw['author'];
    if (id is! String || id.isEmpty || body is! String || author is! Map) {
      return null;
    }
    final name = author['name'];
    if (name is! String || name.trim().isEmpty) return null;
    final avatar = author['avatarUrl'];
    return RadioComment(
      id: id,
      body: body,
      createdAt: _date(raw['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      authorKind: author['kind'] == 'guest'
          ? RadioAuthorKind.guest
          : RadioAuthorKind.member,
      authorName: name.trim(),
      avatarUrl: avatar is String && avatar.isNotEmpty ? avatar : null,
      airedAt: _date(raw['airedAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RadioComment &&
      other.id == id &&
      other.body == body &&
      other.createdAt == createdAt &&
      other.authorKind == authorKind &&
      other.authorName == authorName &&
      other.avatarUrl == avatarUrl &&
      other.airedAt == airedAt;

  @override
  int get hashCode => Object.hash(
      id, body, createdAt, authorKind, authorName, avatarUrl, airedAt);

  @override
  String toString() => 'RadioComment($id, $authorName: $body)';
}

/// **Ce que CE porteur peut faire** — le bloc `viewer` de `GET /radio/comments`.
@immutable
class RadioViewer {
  const RadioViewer({
    this.kind = RadioAuthorKind.member,
    this.pseudonym,
    this.silenced = false,
    this.canComment = false,
    this.moderator = false,
  });

  /// Avant toute réponse : on ne sait rien, donc on n'offre aucun outil de
  /// modération. Le champ de saisie, lui, dépend du direct et du silence — pas
  /// de [canComment], qui est faux pour un invité sans pseudo alors qu'il doit
  /// pouvoir écrire (le serveur répond alors `E_RADIO_PSEUDONYM_REQUIRED`, et
  /// la page ouvre le formulaire de pseudo).
  static const RadioViewer unknown = RadioViewer();

  final RadioAuthorKind kind;

  /// Le pseudo d'un invité, `null` tant qu'il n'en a pas choisi (et toujours
  /// pour un membre).
  final String? pseudonym;

  /// Réduit au silence par un modérateur, jusqu'à la fin du direct.
  final bool silenced;
  final bool canComment;

  /// Les outils de modération s'affichent — et rien d'autre ne les ouvre.
  final bool moderator;

  bool get isGuest => kind == RadioAuthorKind.guest;

  static RadioViewer fromJson(Object? raw) {
    if (raw is! Map) return unknown;
    final pseudonym = raw['pseudonym'];
    return RadioViewer(
      kind: raw['kind'] == 'guest'
          ? RadioAuthorKind.guest
          : RadioAuthorKind.member,
      pseudonym:
          pseudonym is String && pseudonym.trim().isNotEmpty ? pseudonym : null,
      silenced: raw['silenced'] == true,
      canComment: raw['canComment'] == true,
      moderator: raw['moderator'] == true,
    );
  }

  RadioViewer copyWith({String? pseudonym, bool? silenced}) => RadioViewer(
        kind: kind,
        pseudonym: pseudonym ?? this.pseudonym,
        silenced: silenced ?? this.silenced,
        canComment: canComment,
        moderator: moderator,
      );

  @override
  bool operator ==(Object other) =>
      other is RadioViewer &&
      other.kind == kind &&
      other.pseudonym == pseudonym &&
      other.silenced == silenced &&
      other.canComment == canComment &&
      other.moderator == moderator;

  @override
  int get hashCode =>
      Object.hash(kind, pseudonym, silenced, canComment, moderator);
}

/// **Le fil du direct**, tel que `GET /radio/comments` le rend — la lecture qui
/// **remplace** l'affichage à l'ouverture et après chaque reconnexion.
@immutable
class RadioThread {
  const RadioThread({
    this.live,
    this.comments = const [],
    this.viewer = RadioViewer.unknown,
  });

  /// Hors direct : fil fermé, rien à lire.
  static const RadioThread closed = RadioThread();

  final RadioLive? live;

  /// Du plus ancien au plus récent.
  final List<RadioComment> comments;
  final RadioViewer viewer;

  static RadioThread fromJson(Object? raw) {
    if (raw is! Map) return closed;
    return RadioThread(
      live: RadioLive.fromJson(raw['live']),
      comments: _comments(raw['comments']),
      viewer: RadioViewer.fromJson(raw['viewer']),
    );
  }
}

/// **Un message signalé**, dans la file des modérateurs.
@immutable
class RadioReportedComment {
  const RadioReportedComment({
    required this.comment,
    required this.pendingReports,
    this.firstReportedAt,
  });

  final RadioComment comment;
  final int pendingReports;
  final DateTime? firstReportedAt;

  static RadioReportedComment? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final comment = RadioComment.fromJson(raw['comment']);
    if (comment == null) return null;
    final pending = raw['pendingReports'];
    return RadioReportedComment(
      comment: comment,
      pendingReports: pending is int ? pending : 1,
      firstReportedAt: _date(raw['firstReportedAt']),
    );
  }
}

/// **La file des signalements**, `GET /radio/moderation/comments`.
@immutable
class RadioModerationQueue {
  const RadioModerationQueue({this.live, this.items = const []});

  static const RadioModerationQueue empty = RadioModerationQueue();

  final RadioLive? live;
  final List<RadioReportedComment> items;

  static RadioModerationQueue fromJson(Object? raw) {
    if (raw is! Map) return empty;
    final items = raw['items'];
    return RadioModerationQueue(
      live: RadioLive.fromJson(raw['live']),
      items: items is List
          ? items
              .map(RadioReportedComment.fromJson)
              .whereType<RadioReportedComment>()
              .toList(growable: false)
          : const [],
    );
  }
}

List<RadioComment> _comments(Object? raw) {
  if (raw is! List) return const [];
  final all = raw
      .map(RadioComment.fromJson)
      .whereType<RadioComment>()
      .toList(growable: false);
  return all.length <= kRadioCommentWindow
      ? all
      : all.sublist(all.length - kRadioCommentWindow);
}

DateTime? _date(Object? raw) => raw is String ? DateTime.tryParse(raw) : null;
