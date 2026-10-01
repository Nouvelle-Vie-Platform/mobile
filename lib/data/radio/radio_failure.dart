/// **Pourquoi l'écoute n'a pas marché — lu sur l'échec, jamais sur un test de
/// connectivité.**
///
/// ⚠️ **Le dépôt refuse `connectivity_plus` pour trancher « y a-t-il
/// internet »**, et la raison est écrite dans `network_transport.dart` : il
/// répond « connecté » derrière un portail captif — un hôtel, **un wifi d'église
/// mal configuré** —, c'est-à-dire exactement quand sa réponse compterait. Un
/// seul fichier du dépôt l'importe, et ce fichier-ci **n'en fait pas un
/// second** : il ne consulte aucun signal système, même pour avancer une
/// tentative. La reprise est purement temporelle (`radio_retry.dart`).
///
/// La question n'est pas « y a-t-il du réseau » mais « **à qui dire d'agir** » :
///
/// | ce qui échoue | ce qu'on dit |
/// | --- | --- |
/// | résolution DNS, socket refusée, délai dépassé | « vérifiez votre connexion » |
/// | 404, 401, une page HTML là où on attend une playlist | « antenne indisponible » |
///
/// Le partage se fait donc sur **l'existence d'une réponse**, exactement comme
/// `mapCalendarError` : « personne n'a répondu » se règle en retrouvant du
/// réseau, « on m'a répondu non » ne se règle pas depuis le téléphone.
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Ce qu'on dit à l'auditeur. Deux valeurs, et il n'y en aura pas une
/// troisième : un bouton n'a pas la place d'un diagnostic.
enum RadioFailureKind {
  /// « Vérifiez votre connexion » — rien n'a répondu.
  connection,

  /// « Antenne indisponible » — quelque chose a répondu, et ce n'était pas une
  /// playlist.
  antenna,
}

/// **Range un échec dans l'une des deux phrases.**
///
/// Trois familles d'entrée, et elles arrivent toutes pour de vrai :
///
/// 1. une [DioException] de la route publique d'antenne — le partage y est net,
///    `response == null` veut dire « personne n'a répondu » ;
/// 2. une `SocketException` ou un délai dépassé remontés nus ;
/// 3. **la panne du lecteur**, qui arrive par `ContentPlayback.error` et dont le
///    type appartient à `just_audio` — qu'aucun autre fichier de `lib/` n'a le
///    droit d'importer (garde-fou de source,
///    `test/data/content_player_test.dart`). On ne peut donc pas la reconnaître
///    par son type : on lit le **code de statut** que la plateforme met dans son
///    message (`Response code: 401` côté ExoPlayer, `status code of 404` côté
///    AVPlayer), ou la signature d'une page HTML servie à la place d'une
///    playlist.
///
/// ⚠️ **Ce troisième chemin n'a pas été vu sur appareil** : le bloc Caddy de
/// MediaMTX n'est pas posé (`context#6`), donc aucune écoute réelle n'est
/// possible aujourd'hui et aucune de ces deux chaînes n'a été mesurée. C'est
/// pour cela qu'il **penche du côté sûr** : un échec qu'on ne sait pas nommer est
/// rendu [RadioFailureKind.connection], parce que « vérifiez votre connexion »
/// invite à un geste utile là où « antenne indisponible » **affirmerait** une
/// panne de l'église dont on n'a aucune preuve.
RadioFailureKind classifyRadioFailure(Object error) {
  if (error is DioException) {
    // Le serveur a parlé — 401, 404, 5xx, ou une page d'erreur de proxy : ce
    // n'est pas le réseau de l'auditeur qui manque.
    return error.response == null
        ? RadioFailureKind.connection
        : RadioFailureKind.antenna;
  }

  final message = error.toString();
  if (radioStatusCodeIn(message) != null) return RadioFailureKind.antenna;
  if (looksLikeHtmlPage(message)) return RadioFailureKind.antenna;
  return RadioFailureKind.connection;
}

/// Le code de statut HTTP écrit **en clair** dans un message de plateforme, ou
/// `null`.
///
/// Volontairement étroit : un nombre de la famille HTTP (`1xx`–`5xx`) précédé à
/// courte distance du mot « code » ou « status ». Attraper n'importe quel nombre
/// à trois chiffres ferait d'un numéro de ligne ou d'un code d'erreur natif une
/// réponse du serveur, et dirait « antenne indisponible » devant une coupure
/// réseau.
@visibleForTesting
int? radioStatusCodeIn(String message) {
  final match = RegExp(
    r'(?:code|status)\D{0,12}([1-5]\d\d)\b',
    caseSensitive: false,
  ).firstMatch(message);
  return match == null ? null : int.tryParse(match.group(1)!);
}

/// Vrai quand ce texte commence comme une page HTML.
///
/// C'est la signature du cas que le cadrage nomme : « une page HTML là où on
/// attend une playlist » — un proxy mal configuré, une page d'erreur, une
/// redirection vers un portail captif qui a répondu 200.
@visibleForTesting
bool looksLikeHtmlPage(String body) {
  final head = body.trimLeft().toLowerCase();
  return head.startsWith('<!doctype html') || head.startsWith('<html');
}
