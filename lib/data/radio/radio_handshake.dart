/// **La poignée de main par cookie de MediaMTX, faite à la main** (#108).
///
/// Le serveur HLS de MediaMTX n'ouvre pas son antenne à qui ne porte pas sa
/// session. Mesuré le 2026-10-01 depuis l'extérieur du VPS, sur
/// `https://stream.eenv.brainsial.com/antenne/` :
///
/// ```
/// sans cookie   → 401  {"status":"error","error":"session not found"}
/// avec cookie   → 200  playlist complète
/// ```
///
/// ⚠️ **La négociation se fait en deux temps, et il y a deux cookies, pas un.**
/// Un **302** pose `cookieCheck` — c'est MediaMTX qui vérifie que le client sait
/// garder un cookie —, puis le **200** qui suit pose `hlsSession`. Les deux sont
/// `HttpOnly; Secure; SameSite=None; Partitioned`. C'est la précision qui change
/// tout pour cette tranche : **suivre la redirection ne suffit pas, il faut
/// garder le bocal entre les deux sauts**. Un client qui suit le 302 sans
/// renvoyer `cookieCheck` au second saut ne reçoit jamais `hlsSession`, et tout
/// ce qui vient après rend 401.
///
/// C'est pour cela que ce pré-vol **ne délègue pas le suivi des redirections**
/// (`followRedirects: false`) : il fait les sauts un par un et renvoie à chacun
/// ce que les précédents ont posé. `dart:io` suit bien les 302 tout seul, mais
/// `HttpClient` n'a **aucun bocal** — il ne réémet pas un `Set-Cookie` reçu en
/// route —, donc le laisser faire reproduirait exactement la panne.
///
/// ## Et `just_audio` ne les porte pas
///
/// Relevé dans le source de la version 0.10.6, pas supposé : le mot « cookie »
/// n'apparaît **nulle part** dans son code Android ni Darwin. Android suit les
/// redirections (`setAllowCrossProtocolRedirects(true)`) mais passe par
/// `HttpURLConnection`, qui ne garde de cookies que si un `java.net.CookieHandler`
/// est installé par défaut — et il n'y en a aucun. iOS/macOS ne pose jamais
/// `AVURLAssetHTTPCookiesKey`. D'où ce pré-vol, et d'où le fait qu'on passe
/// ensuite au lecteur une **URL absolue finale** et un en-tête `Cookie:`.
///
/// ## Ce que ce fichier ne décide pas
///
/// **Comment son échec se dit.** Il lève, et c'est `classifyRadioFailure` qui
/// range — pour lui comme pour la route d'antenne et pour le lecteur. Un
/// pré-vol sur le chemin critique de l'écoute n'a pas droit à une **troisième
/// voix** : réponse absente → « vérifiez votre connexion » ; 401, 404, 5xx →
/// « antenne indisponible ». C'est pourquoi il lève une [DioException] **avec
/// sa réponse** quand le serveur a parlé, et laisse remonter telle quelle la
/// panne de transport quand personne n'a répondu.
///
/// ⚠️ **Aucun signal système n'est consulté**, ici pas plus qu'ailleurs : un seul
/// fichier du dépôt importe `connectivity_plus` (`network_transport.dart`), et
/// cette tranche n'en fait pas un second — voir `radio_failure.dart` pour la
/// raison (il répond « connecté » derrière un portail captif).
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// **La borne de temps du pré-vol**, et elle lui est propre.
///
/// Elle existe parce que le pré-vol est **sur le chemin critique de l'écoute** :
/// tant qu'il n'a pas rendu, aucun son ne sort, et le bouton tourne. Les deux
/// chiffres qui la décident :
///
/// - la fenêtre de rattrapage de l'antenne est de **40 secondes** (20 segments de
///   2 s, `docs/RADIO.md`) — tout ce que le pré-vol consomme est pris sur elle ;
/// - la négociation est de **deux allers-retours** à corps vide (un 302, un 200).
///
/// Cinq secondes laissent donc largement la place à deux échanges sur un réseau
/// lent tout en ne mangeant **qu'un huitième** de la fenêtre. Au-delà, il vaut
/// mieux dire « vérifiez votre connexion » que de faire tourner le bouton :
/// l'antenne ne nous attend pas.
///
/// ⚠️ Elle borne le **total**, pas chaque saut : c'est le total qui est pris sur
/// la fenêtre. Les délais de Dio ci-dessous bornent chaque saut *aussi*, pour
/// qu'un seul d'entre eux ne puisse pas s'approprier tout le budget.
const Duration kRadioHandshakeTimeout = Duration(seconds: 5);

/// Combien de sauts le pré-vol accepte de faire avant de renoncer.
///
/// La négociation mesurée en fait **un**. Trois laissent la place à un
/// intermédiaire de plus (un `Location` vers le même hôte en HTTPS, un
/// répartiteur) sans jamais tourner en rond : un cycle de redirections sur le
/// chemin de l'écoute est une panne, pas une patience à avoir.
const int kRadioHandshakeMaxHops = 3;

/// **Ce qu'il faut présenter au lecteur pour que l'antenne joue** : l'adresse
/// réellement finale, et les en-têtes qui portent la session.
///
/// Les deux ensemble, et pas l'un sans l'autre. L'URL de départ ne suffit pas —
/// le `Location` du 302 est absolu et à la racine, donc rouvrir l'URL de départ
/// referait la négociation **sans le bocal**, c'est-à-dire la panne. Et
/// l'adresse finale seule rend 401.
@immutable
class RadioHandshake {
  const RadioHandshake({required this.url, this.headers = const {}});

  /// L'URL absolue à ouvrir — celle sur laquelle la négociation a abouti.
  final String url;

  /// Les en-têtes à poser sur **toutes** les requêtes du lecteur : `Cookie:`
  /// quand la négociation a posé quelque chose, vide sinon.
  ///
  /// Vide n'est pas un échec : un MediaMTX configuré sans session rendrait 200
  /// du premier coup, et l'antenne jouerait sans cookie. Inventer un en-tête
  /// pour que la carte soit pleine n'aurait rien prouvé.
  final Map<String, String> headers;

  @override
  bool operator ==(Object other) =>
      other is RadioHandshake &&
      other.url == url &&
      mapEquals(other.headers, headers);

  @override
  int get hashCode =>
      Object.hash(url, Object.hashAllUnordered(headers.entries));

  @override
  String toString() => 'RadioHandshake(url: $url, headers: $headers)';
}

/// **Le contrat du pré-vol** — derrière une abstraction, comme le reste de
/// `lib/data/`.
///
/// Deux raisons, et aucune n'est de la symétrie : le web n'a pas le droit de le
/// faire (voir [DirectRadioHandshake]), et aucun test d'écran ne doit ouvrir de
/// socket au premier appui sur le bouton d'antenne.
abstract interface class RadioHandshakeResolver {
  /// Négocie la session pour [url] et rend de quoi ouvrir le flux.
  ///
  /// **Lève** quand la négociation n'aboutit pas, et laisse `classifyRadioFailure`
  /// en tirer l'une des **deux** phrases de #104. Ne rend jamais une URL sans
  /// avoir essayé : une poignée de main sautée en silence redonnerait le 401 que
  /// cette tranche existe pour faire disparaître.
  Future<RadioHandshake> resolve(String url);
}

/// **Le pré-vol qui n'en fait pas** : l'URL passe telle quelle, sans en-tête.
///
/// Deux emplois, et le premier est de production :
///
/// - **le web.** Le bocal y appartient au navigateur, et il le tient très bien
///   tout seul ; mais on ne peut ni lire un `Set-Cookie` depuis JavaScript (le
///   navigateur le cache), ni poser un en-tête `Cookie:` sur une requête (c'est
///   un *forbidden header name* de la spécification Fetch), ni en poser aucun sur
///   un élément `<audio>`. Un pré-vol y échouerait donc **et** serait inutile :
///   `hls_content_player.dart` ignore les en-têtes pour la même raison.
/// - **les tests d'écran**, qui montent le bouton d'antenne sans parler de radio
///   et n'ont pas à ouvrir de socket pour cela.
class DirectRadioHandshake implements RadioHandshakeResolver {
  const DirectRadioHandshake();

  @override
  Future<RadioHandshake> resolve(String url) async => RadioHandshake(url: url);
}

/// **Le pré-vol réel : les sauts un par un, et le bocal gardé entre eux.**
class HttpRadioHandshakeResolver implements RadioHandshakeResolver {
  HttpRadioHandshakeResolver({Dio? client}) : client = client ?? _buildDio();

  /// **Un `Dio` à lui, et non celui d'`ApiClient`** — l'arbitrage le plus
  /// important de ce fichier.
  ///
  /// Le client global porte trois intercepteurs dont aucun n'a sa place sur une
  /// requête adressée au serveur de flux, et le second est dangereux :
  ///
  /// 1. `_AuthInterceptor` poserait `Authorization: Bearer <jeton>` sur une
  ///    requête vers **un autre hôte** que l'API. Le jeton ouvre le compte
  ///    pendant 90 jours glissants ; il n'a rien à faire dans les journaux d'un
  ///    serveur de streaming.
  /// 2. `UnauthorizedInterceptor` traiterait le **401 de MediaMTX** comme un 401
  ///    de l'API : purge du jeton et éjection vers `/auth`. Autrement dit, une
  ///    antenne mal configurée **déconnecterait l'auditeur** — exactement la
  ///    panne que ce fichier est censé corriger, en pire.
  /// 3. `unwrapEnvelopeInterceptor` cherche une enveloppe `data` qu'une playlist
  ///    HLS n'a pas.
  ///
  /// S'y ajoute que `baseUrl` et les délais du client global ne sont pas ceux
  /// qu'on veut ici (voir [kRadioHandshakeTimeout]).
  ///
  /// Exposé — et non privé — pour que cette absence d'intercepteurs soit
  /// **vérifiable** : un `UnauthorizedInterceptor` qui reviendrait ici
  /// déconnecterait l'auditeur au premier 401 de l'antenne, et rien à l'écran ne
  /// relierait les deux.
  @visibleForTesting
  final Dio client;

  static Dio _buildDio() => Dio(
        BaseOptions(
          // Chaque saut est borné *aussi*, pour qu'un seul ne puisse pas
          // s'approprier tout le budget du total.
          connectTimeout: kRadioHandshakeTimeout,
          receiveTimeout: kRadioHandshakeTimeout,
          sendTimeout: kRadioHandshakeTimeout,
        ),
      );

  @override
  Future<RadioHandshake> resolve(String url) =>
      // La borne de temps est posée **ici**, autour de toute la négociation :
      // c'est le total qui est pris sur la fenêtre de 40 secondes de l'antenne.
      // Un `TimeoutException` n'a pas de réponse, donc il se range du côté
      // « vérifiez votre connexion » — ce qui est juste : personne n'a répondu à
      // temps.
      _resolve(url).timeout(kRadioHandshakeTimeout);

  Future<RadioHandshake> _resolve(String url) async {
    // **Le bocal.** Il vit le temps d'une négociation et pas une seconde de
    // plus : la session expire, et #108 exige qu'une réouverture **renégocie**
    // au lieu de rejouer. Rien ici ne retient donc quoi que ce soit d'un appel
    // sur l'autre, et c'est volontaire.
    final jar = <String, String>{};
    var target = url;

    for (var hop = 0; hop <= kRadioHandshakeMaxHops; hop++) {
      final response = await client.get<dynamic>(
        target,
        options: Options(
          // **On suit les redirections soi-même** : voir l'en-tête du fichier.
          // C'est le seul moyen de renvoyer au second saut ce que le premier a
          // posé.
          followRedirects: false,
          // Un 302 et un 401 sont tous deux des réponses à lire, pas des
          // exceptions à rattraper. C'est la boucle qui décide de ce qu'ils
          // valent, et elle lève elle-même quand il n'y a plus d'espoir.
          validateStatus: (_) => true,
          // Le corps ne nous intéresse pas — on ne vient que pour les
          // en-têtes. Le lire en octets évite de décoder une playlist pour
          // rien, et évite surtout qu'une page HTML d'erreur fasse lever un
          // décodeur JSON à la place du nôtre.
          responseType: ResponseType.bytes,
          headers: {
            if (jar.isNotEmpty) _kCookieHeader: _cookieValue(jar),
          },
        ),
      );

      _collectCookies(jar, response);
      final status = response.statusCode ?? 0;

      if (status >= 200 && status < 300) {
        return RadioHandshake(
          url: target,
          headers: jar.isEmpty ? const {} : {_kCookieHeader: _cookieValue(jar)},
        );
      }

      if (status >= 300 && status < 400) {
        final location = response.headers.value('location')?.trim();
        // Une redirection sans destination est une réponse cassée, pas une
        // absence de réseau : le serveur a parlé, donc « antenne indisponible ».
        if (location == null || location.isEmpty) throw _refused(response);
        // `resolve` gère les trois formes qu'un `Location` peut prendre —
        // absolue, enracinée, relative. La mesure n'en a montré qu'une (absolue
        // à la racine), mais s'en tenir à celle-là rendrait la radio muette le
        // jour où MediaMTX en écrit une autre.
        target = Uri.parse(target).resolve(location).toString();
        continue;
      }

      // 401 « session not found », 404, 5xx : quelque chose a répondu, et ce
      // n'était pas une playlist.
      throw _refused(response);
    }

    // Plus de sauts disponibles : on tourne en rond. Le dernier mot reste une
    // réponse du serveur, donc la même phrase.
    throw DioException(
      requestOptions: RequestOptions(path: target),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: target),
        statusCode: 508, // « Loop detected » — le plus proche de ce qu'on a vu.
      ),
      type: DioExceptionType.badResponse,
      error: 'La poignée de main de l\'antenne redirige en boucle '
          '(plus de $kRadioHandshakeMaxHops sauts).',
    );
  }

  /// La panne **avec sa réponse attachée** : c'est ce que lit
  /// `classifyRadioFailure` pour dire « antenne indisponible » plutôt que
  /// « vérifiez votre connexion ».
  DioException _refused(Response<dynamic> response) => DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
}

const String _kCookieHeader = 'Cookie';

/// Range dans le bocal ce que cette réponse a posé.
///
/// Un nom déjà présent est **remplacé** : c'est ce que fait un navigateur, et
/// c'est ce qu'il faut ici — MediaMTX peut reposer `cookieCheck` au second saut.
///
/// ⚠️ **Aucun nom de cookie n'est écrit ici.** La mesure en a vu deux
/// (`cookieCheck`, `hlsSession`), mais filtrer sur ces deux mots ferait de la
/// configuration de MediaMTX une constante du binaire : le jour où la version du
/// serveur en renomme un, l'antenne se taierait **sans qu'aucun test rougisse**.
/// On garde donc tout ce qui est posé sur le chemin de l'écoute, et rien d'autre
/// n'y passe.
void _collectCookies(Map<String, String> jar, Response<dynamic> response) {
  for (final raw in response.headers.map['set-cookie'] ?? const <String>[]) {
    // `name=value; Path=/…; HttpOnly; Secure; SameSite=None; Partitioned` — seul
    // le premier couple voyage dans un en-tête `Cookie:`, les attributs sont
    // pour le navigateur.
    final pair = raw.split(';').first;
    final cut = pair.indexOf('=');
    if (cut <= 0) continue;
    final name = pair.substring(0, cut).trim();
    if (name.isEmpty) continue;
    jar[name] = pair.substring(cut + 1).trim();
  }
}

String _cookieValue(Map<String, String> jar) =>
    jar.entries.map((e) => '${e.key}=${e.value}').join('; ');
