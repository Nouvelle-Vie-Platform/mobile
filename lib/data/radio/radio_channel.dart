/// **Le canal temps réel de la radio** (#135) — et ici, contrairement aux
/// groupes, **la charge de l'événement EST la donnée**.
///
/// ## Pourquoi ce fichier vit dans `lib/data/radio/`
///
/// Le canal par groupe de #101 (`lib/data/realtime/`, retiré par #140) ne
/// transportait qu'un **signal** vide, et un garde-fou de source y interdisait
/// tout `jsonDecode`. La messagerie a depuis suivi le découpage de ce fichier-ci
/// (`lib/data/messaging/`).
///
/// La radio n'a pas de magasin : ni table, ni curseur, ni cycle à déclencher
/// (`radio_live.dart`). Un cœur qui monte, un commentaire qui arrive, un
/// compteur qui change **se lisent dans l'événement**, et il n'y a nulle part
/// d'autre où les lire — sauf la relecture REST, qui sert à **remplacer**
/// l'affichage après une coupure. Il n'y a donc pas de « chemin mixte » à
/// craindre : une seule chose écrit l'état de la page, le contrôleur
/// (`radio_live_providers.dart`), et il ne l'écrit qu'en mémoire.
///
/// Le protocole, lui, est **le même** que celui des groupes, et il est réutilisé
/// tel quel (`sse_radio_channel.dart`) : même `Dio`, mêmes trois routes de
/// Transmit, même ordre, même `receiveTimeout` désarmé.
///
/// ## La forme d'une trame Transmit, relevée dans `@boringnode/transmit`
///
/// ```
/// data: {"channel":"radio","payload":{"type":"reactions","counts":{…},…}}
/// ```
///
/// Une connexion peut porter **deux** abonnements (`radio`, et
/// `radio/moderation` pour un modérateur) : le nom du canal départage.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'radio_live.dart';

/// Le canal public — membres **et invités** (le seul ouvert au garde `device`,
/// `server-portal/start/transmit.ts`).
const String kRadioChannel = 'radio';

/// Le canal **privé** des modérateurs : un appareil y est refusé deux fois.
const String kRadioModerationChannel = 'radio/moderation';

/// **Un événement du canal radio**, déjà décodé.
sealed class RadioChannelEvent {
  const RadioChannelEvent();
}

/// **La connexion vient de s'ouvrir** — première fois ou après une coupure.
///
/// Pas un événement du serveur : c'est le client qui l'émet, **après**
/// l'abonnement réussi. Un canal neuf n'a aucune mémoire de ce qui s'est passé
/// avant lui (une bascule bleu/vert coupe Transmit ~120 s, piège 2 du plan) :
/// c'est donc le moment de **relire** l'antenne et le fil, et de remplacer
/// l'affichage. Même règle que le signal d'ouverture des groupes.
final class RadioChannelOpened extends RadioChannelEvent {
  const RadioChannelOpened({required this.moderation});

  /// Vrai si l'abonnement à `radio/moderation` a aussi été accepté.
  final bool moderation;
}

/// `live.started` / `live.ended` : l'état public **en entier**, jamais un delta.
final class RadioLiveChanged extends RadioChannelEvent {
  const RadioLiveChanged({required this.live, required this.listeners});

  /// `null` : le direct vient de finir, **le fil est fermé**.
  final RadioLive? live;
  final int? listeners;
}

/// `listeners` : le chiffre affiché vient de changer (`null` = le cacher).
final class RadioListenersChanged extends RadioChannelEvent {
  const RadioListenersChanged(this.listeners);
  final int? listeners;
}

/// `reactions` : l'agrégat d'**une seconde** de toute l'audience.
final class RadioReactionsAggregated extends RadioChannelEvent {
  const RadioReactionsAggregated(this.counts);

  /// Les cinq clés, zéro compris — un agrégat entièrement nul n'est jamais
  /// diffusé.
  final Map<RadioReaction, int> counts;
}

/// `comment.posted`.
final class RadioCommentPosted extends RadioChannelEvent {
  const RadioCommentPosted(this.comment);
  final RadioComment comment;
}

/// `comment.hidden` : le retirer de l'écran. Ni texte, ni auteur, ni qui.
final class RadioCommentHidden extends RadioChannelEvent {
  const RadioCommentHidden(this.commentId);
  final String commentId;
}

/// Canal **privé** : `comment.reported` ([kept] et [hidden] nuls) ou
/// `comment.reviewed` (l'un des deux vrai). Ne porte qu'un identifiant : la file
/// se relit par la route, jamais par l'événement.
final class RadioModerationChanged extends RadioChannelEvent {
  const RadioModerationChanged({required this.commentId, this.outcome});

  final String commentId;

  /// `null` pour un signalement ; `'hidden'` ou `'kept'` pour une décision.
  final String? outcome;

  bool get isReview => outcome != null;
}

/// **Décode une trame** `data:` de Transmit en événement radio.
///
/// Rend `null` pour tout ce qu'on ne sait pas lire — un autre canal, un type
/// inconnu (un serveur plus récent), une charge mal formée. Un événement qu'on
/// ignore ne coûte rien : la prochaine relecture remet tout d'aplomb. Un
/// événement qu'on inventerait afficherait un faux.
RadioChannelEvent? decodeRadioChannelData(String data) {
  final Object? decoded;
  try {
    decoded = jsonDecode(data);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final channel = decoded['channel'];
  final payload = decoded['payload'];
  if (payload is! Map) return null;
  final type = payload['type'];

  if (channel == kRadioChannel) {
    switch (type) {
      case 'live.started':
      case 'live.ended':
        return RadioLiveChanged(
          live:
              type == 'live.ended' ? null : RadioLive.fromJson(payload['live']),
          listeners: _listeners(payload['listeners']),
        );
      case 'listeners':
        return RadioListenersChanged(_listeners(payload['listeners']));
      case 'reactions':
        final counts = payload['counts'];
        if (counts is! Map) return null;
        return RadioReactionsAggregated({
          for (final reaction in RadioReaction.values)
            reaction: _count(counts[reaction.wire]),
        });
      case 'comment.posted':
        final comment = RadioComment.fromJson(payload['comment']);
        return comment == null ? null : RadioCommentPosted(comment);
      case 'comment.hidden':
        final id = payload['commentId'];
        return id is String && id.isNotEmpty ? RadioCommentHidden(id) : null;
    }
    return null;
  }

  if (channel == kRadioModerationChannel) {
    final id = payload['commentId'];
    if (id is! String || id.isEmpty) return null;
    switch (type) {
      case 'comment.reported':
        return RadioModerationChanged(commentId: id);
      case 'comment.reviewed':
        final outcome = payload['outcome'];
        return RadioModerationChanged(
          commentId: id,
          outcome: outcome is String ? outcome : 'kept',
        );
    }
  }
  return null;
}

int? _listeners(Object? raw) {
  if (raw is int && raw >= 0) return raw;
  if (raw is double && raw.isFinite && raw >= 0) return raw.round();
  return null;
}

int _count(Object? raw) {
  if (raw is int && raw > 0) return raw;
  if (raw is double && raw.isFinite && raw > 0) return raw.round();
  return 0;
}

/// **L'abonnement au canal `radio` a été refusé** — ce n'est pas une panne, et
/// ça ne se réessaie pas (même règle que `GroupChannelRefused`).
class RadioChannelRefused implements Exception {
  const RadioChannelRefused(this.statusCode);

  final int? statusCode;

  @override
  String toString() => 'RadioChannelRefused(${statusCode ?? 'sans code'})';
}

/// Contrat d'écoute du canal radio.
abstract interface class RadioChannel {
  /// Ouvre **une** connexion, abonnée à `radio` et — si [moderation] — à
  /// `radio/moderation`. Le flux ne se termine pas de lui-même tant que la
  /// connexion tient ; annuler l'abonnement la ferme. Une fin de flux ou une
  /// erreur disent « le canal est tombé ».
  ///
  /// Le premier événement d'une connexion réussie est toujours
  /// [RadioChannelOpened].
  Stream<RadioChannelEvent> watch({required bool moderation});
}

/// **Double muet** : aucune socket, aucun événement, et un flux **jamais clos**
/// — un flux qui se fermerait tout de suite se lirait comme un canal tombé, et
/// ferait tourner la réouverture dans le vide. Le défaut sans backend et dans
/// tous les tests d'écran.
class SilentRadioChannel implements RadioChannel {
  const SilentRadioChannel();

  @override
  Stream<RadioChannelEvent> watch({required bool moderation}) =>
      // ignore: close_sinks — fermé par l'annulation de l'abonnement.
      StreamController<RadioChannelEvent>().stream;
}

/// Une trace de diagnostic, en debug seulement.
void traceRadioChannel(String message) {
  assert(() {
    debugPrint('[radio-live] $message');
    return true;
  }());
}
