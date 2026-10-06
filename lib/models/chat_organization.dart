/// **Organiser ses discussions** (#146, tranche M8) — ce que l'onglet Messages
/// fait de la liste : les épingles en tête, les archives à part.
library;

import 'package:flutter/foundation.dart';

import 'echanges_view.dart';

/// Au plus trois discussions épinglées — la borne de WhatsApp, que le serveur
/// tient aussi (`409 E_PINNED_GROUPS_LIMIT`).
const int kMaxPinnedChats = 3;

/// La liste des conversations, rangée.
@immutable
class ConversationShelves {
  const ConversationShelves({required this.main, required this.archived});

  /// La liste principale : les épingles d'abord (la plus récemment épinglée en
  /// tête), puis les autres **dans l'ordre reçu** (la récence).
  final List<ConversationView> main;

  /// Les discussions archivées, dans l'ordre reçu (la récence).
  final List<ConversationView> archived;
}

/// **Range la liste** : sort les archives, met les épingles en tête.
///
/// Une discussion archivée **reste archivée** quand un message y arrive — elle
/// ne revient jamais d'elle-même dans la liste principale. Une discussion à la
/// fois archivée et épinglée ne devrait pas exister (archiver désépingle) ; si
/// le magasin en montre une le temps d'une synchronisation, l'archive l'emporte.
ConversationShelves organizeConversations(List<ConversationView> all) {
  final archived = <ConversationView>[];
  final pinned = <ConversationView>[];
  final rest = <ConversationView>[];
  for (final c in all) {
    if (c.archived) {
      archived.add(c);
    } else if (c.pinned) {
      pinned.add(c);
    } else {
      rest.add(c);
    }
  }
  // Tri stable : deux épingles du même instant gardent l'ordre de récence.
  final ordered = [
    for (var i = 0; i < pinned.length; i++) (i, pinned[i]),
  ]..sort((a, b) {
      final byPin = b.$2.pinnedAt!.compareTo(a.$2.pinnedAt!);
      return byPin != 0 ? byPin : a.$1.compareTo(b.$1);
    });
  return ConversationShelves(
    main: [for (final e in ordered) e.$2, ...rest],
    archived: archived,
  );
}

/// Un résultat de recherche dans les messages.
@immutable
class MessageSearchHit {
  const MessageSearchHit({
    required this.messageId,
    required this.groupId,
    required this.body,
    this.createdAt,
    this.authorName,
  });

  final String messageId;
  final String groupId;
  final String body;
  final DateTime? createdAt;

  /// L'auteur, quand le magasin le connaît. `null` se rend comme une absence.
  final String? authorName;
}

/// Une page de résultats du serveur (l'historique que le magasin n'a pas).
@immutable
class RemoteSearchPage {
  const RemoteSearchPage({required this.hits, required this.hasMore});

  final List<MessageSearchHit> hits;

  /// Une page pleine : il y en a peut-être d'autres.
  final bool hasMore;
}

/// La longueur minimale d'une requête — la même que le serveur.
const int kMinSearchLength = 2;

/// **Normalise un texte pour la comparaison** : minuscules, sans accents. Sert
/// à la recherche sur les **noms** de discussions, faite en Dart sur la liste
/// déjà lue (« eglise » trouve « Église »).
String foldForSearch(String text) {
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_folds[char] ?? char);
  }
  return buffer.toString();
}

const Map<String, String> _folds = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', //
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i', //
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o', //
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u', //
  'ÿ': 'y', 'ñ': 'n', 'œ': 'oe', 'æ': 'ae', //
  'ɛ': 'e', 'ɔ': 'o', 'ŋ': 'n', 'ƒ': 'f', 'ʋ': 'v', 'ɖ': 'd', 'ɣ': 'g', //
};

/// Les discussions dont le **nom** contient la requête (accents et casse
/// ignorés), archives comprises.
List<ConversationView> conversationsMatching(
  List<ConversationView> all,
  String query,
) {
  final needle = foldForSearch(query.trim());
  if (needle.length < kMinSearchLength) return const [];
  return [
    for (final c in all)
      if (foldForSearch(c.title).contains(needle)) c,
  ];
}
