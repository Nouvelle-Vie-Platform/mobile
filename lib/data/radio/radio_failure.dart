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
/// | une panne du lecteur dont rien ne dit s'il y a eu réponse | « écoute impossible » |
///
/// Le partage se fait donc sur **l'existence d'une réponse**, exactement comme
/// `mapCalendarError` : « personne n'a répondu » se règle en retrouvant du
/// réseau, « on m'a répondu non » ne se règle pas depuis le téléphone.
///
/// ## La troisième phrase, et pourquoi elle est arrivée après les deux autres
///
/// #104 n'en voulait pas, et sa raison était bonne : *un bouton n'a pas la place
/// d'un diagnostic*. Ce qui l'a rendue nécessaire est une **mesure sur appareil**,
/// le 2026-10-01 sur un iPhone réel : l'antenne ne joue pas, le bouton tourne,
/// puis il annonce **« vérifiez votre connexion » sur un téléphone connecté** —
/// la seule phrase dont l'auditeur puisse savoir à coup sûr qu'elle est fausse.
///
/// La cause n'est pas le partage, c'est le **repli**. Il penchait vers
/// « connexion » faute de mieux, or AVFoundation rend ses pannes sous une forme
/// **opaque** (`AVFoundationErrorDomain -11800`, « The operation could not be
/// completed »), sans code HTTP lisible. Un 401 sur une sous-playlist arrive donc
/// exactement comme une coupure de réseau, et le repli l'habillait en coupure de
/// réseau.
///
/// ⚠️ **Les deux cas que #104 rangeait bien se rangent toujours de la même
/// façon** : un DNS qui ne résout pas reste « vérifiez votre connexion », un 404
/// reste « antenne indisponible ». Ce qui change est que « je ne sais pas » **se
/// dit** au lieu d'emprunter la voix de la connexion. Le prix en est que le repli
/// ne pousse plus à un geste utile ; le bénéfice est qu'il n'affirme plus rien de
/// faux — et l'arbitrage a été tranché par l'appareil, parce qu'une phrase que
/// l'auditeur sait fausse lui apprend à ne plus lire le bouton du tout.
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Ce qu'on dit à l'auditeur. **Trois valeurs, et la troisième est un aveu, pas
/// un diagnostic de plus** — voir l'en-tête du fichier.
enum RadioFailureKind {
  /// « Vérifiez votre connexion » — on **sait** que personne n'a répondu.
  connection,

  /// « Antenne indisponible » — quelque chose a répondu, et ce n'était pas une
  /// playlist.
  antenna,

  /// « Écoute impossible » — **on ignore s'il y a eu une réponse**, et on ne
  /// prétend pas le savoir.
  ///
  /// C'est le cas de la panne d'AVFoundation, qui ne porte ni code HTTP ni nom
  /// d'exception de transport. Nommer le réseau y serait un mensonge mesurable
  /// (le téléphone était connecté) ; nommer l'antenne accuserait l'église sans
  /// preuve. La phrase dit donc ce qui est vrai, et rien de plus.
  unknown,
}

/// **Range un échec dans l'une des trois phrases.**
///
/// Trois familles d'entrée, et elles arrivent toutes pour de vrai :
///
/// 1. une [DioException] de la route publique d'antenne ou du pré-vol — le
///    partage y est net, `response == null` veut dire « personne n'a répondu » ;
/// 2. une `SocketException` ou un délai dépassé remontés nus ;
/// 3. **la panne du lecteur**, qui arrive par `ContentPlayback.error` et dont le
///    type appartient à `just_audio` — qu'aucun autre fichier de `lib/` n'a le
///    droit d'importer (garde-fou de source,
///    `test/data/content_player_test.dart`). On ne peut donc pas la reconnaître
///    par son type : on lit le **code de statut** que la plateforme met dans son
///    message (`Response code: 401` côté ExoPlayer, `status code of 404` côté
///    AVPlayer), la signature d'une page HTML servie à la place d'une playlist,
///    ou le **nom d'une panne de transport** ([looksLikeTransportFailure]).
///
/// ⚠️ **Le repli n'est plus [RadioFailureKind.connection], et c'est le correctif
/// de #110.** Il l'était parce que le chemin du lecteur n'avait pas été mesuré ;
/// il l'a été, sur iPhone, et le résultat était « vérifiez votre connexion » sur
/// un téléphone connecté. Le repli est donc désormais
/// [RadioFailureKind.unknown] : chacune des deux autres phrases **affirme**
/// quelque chose, et on n'affirme pas sur un message qu'on n'a pas su lire.
///
/// Ce qui ne bouge pas : tout ce que ce fichier **sait** reconnaître se range
/// comme avant. Le repli ne reçoit que ce que personne ne sait nommer.
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
  if (looksLikeTransportFailure(message)) return RadioFailureKind.connection;
  return RadioFailureKind.unknown;
}

/// Vrai quand ce message **nomme** une panne de transport.
///
/// Elle existe pour que la troisième phrase ne mange pas la première : avant
/// elle, « vérifiez votre connexion » était le repli, donc une coupure franche y
/// tombait sans avoir à être reconnue. Désormais le repli n'affirme rien, et il
/// faut donc **reconnaître** la coupure pour continuer à la nommer.
///
/// La liste est courte et ne contient que des noms **écrits en clair** par les
/// couches qui traversent jusqu'à Dart :
///
/// - `dart:io` et `package:http` — `SocketException`, `HandshakeException`,
///   `TlsException`, `TimeoutException` (celui du pré-vol), `ClientException` ;
/// - **ExoPlayer**, qui recopie le nom de l'exception Java dans son message —
///   `UnknownHostException` (DNS), `ConnectException`, `NoRouteToHostException`,
///   `SocketTimeoutException`, `SSLHandshakeException`.
///
/// ⚠️ **iOS n'y figure pas, et ce n'est pas un oubli.** AVFoundation rend
/// `AVFoundationErrorDomain -11800` sans nommer la cause sous-jacente : une
/// coupure réseau et un 401 sur une sous-playlist y sont **indistinguables**. Une
/// coupure franche sur iPhone tombera donc dans [RadioFailureKind.unknown], et
/// c'est le comportement juste — on ne sait pas, on le dit. Ajouter `-11800` à
/// cette liste reviendrait à affirmer « réseau » devant un 401, c'est-à-dire à
/// réécrire la panne qu'on vient de corriger.
///
/// `dart:io` n'est pas importé ici : ce fichier est compilé pour le web, où il
/// n'existe pas. On lit donc le texte, comme [radioStatusCodeIn].
@visibleForTesting
bool looksLikeTransportFailure(String message) =>
    _kTransportFailureNames.any(message.contains);

const List<String> _kTransportFailureNames = [
  'SocketException',
  'HandshakeException',
  'TlsException',
  'TimeoutException',
  'ClientException',
  'UnknownHostException',
  'ConnectException',
  'NoRouteToHostException',
  'SocketTimeoutException',
  'SSLHandshakeException',
];

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
