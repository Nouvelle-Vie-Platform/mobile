/// **L'implémentation web de [TransmitClient], par `fetch` — et pas par
/// `EventSource`.**
///
/// Pourquoi `fetch` et non l'`EventSource` natif du navigateur, qui existe
/// pourtant *exactement* pour lire du SSE : **`EventSource` ne porte pas
/// d'en-tête `Authorization`** (l'API n'expose aucun moyen d'ajouter un en-tête
/// à la requête). Or les routes `/__transmit/*` sont sous le guard `api`
/// (Bearer). La seule parade sans en-tête serait de mettre le token dans l'URL
/// (`?token=…`), ce qui l'inscrirait dans les journaux serveur, l'historique et
/// le `Referer` : inacceptable pour un token qui **est** la session et ouvre le
/// compte 90 jours (ADR-0020). D'où un lecteur SSE **maison** basé sur `fetch` +
/// `ReadableStream`, qui envoie le Bearer **dans l'en-tête** et **jamais dans
/// l'URL** — l'URL ne porte que le `uid` de connexion, aléatoire et non secret.
///
/// C'est la moitié « web » de la porte `transmit_client_factory.dart` (import
/// conditionnel `if (dart.library.js_interop)`, patron de
/// `web_content_player.dart`) ; la moitié native/VM est `HttpTransmitClient`
/// (flux Dio). Les deux exposent le **même** point d'entrée
/// [createTransmitClient], et se comportent à l'identique côté contrat, y
/// compris la reconnexion : elles rejouent les abonnements retenus et émettent
/// le **signal de rattrapage** [HttpTransmitClient.reconnectSignalChannel] (D4).
///
/// Ce fichier n'a **aucune décision de lecture** : le découpage des trames SSE
/// et la lecture de `{ channel, payload }` vivent dans `transmit_sse.dart`, qui
/// se teste sur la VM sans navigateur. Ici il n'y a que des **câbles** — ouvrir
/// le `fetch`, tirer le `ReadableStream`, décoder l'UTF-8, poster les
/// abonnements. Même coupe que `hls_content_player.dart` ⟂
/// `media_element_playback.dart`.
///
/// Il n'est **jamais compilé pour la VM ni pour le mobile** : il importe
/// `dart:js_interop` et `package:web`, absents hors du web. La porte l'isole ;
/// tant qu'elle n'existe pas, ce fichier n'est importé par personne, donc jamais
/// compilé par `flutter test` : rien à casser.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:uuid/uuid.dart';
import 'package:web/web.dart' as web;

import '../../core/network/api_client.dart';
// Uniquement pour la sentinelle de reconnexion, **source unique de vérité**
// partagée avec le chemin natif : le `RealtimeService` ne lit pas le canal (il
// déclenche une sync sur tout événement), mais réutiliser la même valeur évite
// qu'un littéral recopié se périme en silence, et la garde hors de l'espace
// `groups/{id}`.
import 'http_transmit_client.dart' show HttpTransmitClient;
import 'transmit_client.dart';
import 'transmit_sse.dart';

/// Construit le client Transmit du web. Point d'entrée de la porte
/// `transmit_client_factory.dart` (moitié web) — même symbole que le
/// `createTransmitClient()` natif, ce qu'exige l'export conditionnel.
///
/// [readToken] et [baseUrl] sont injectables mais par défaut branchés sur
/// l'`ApiClient` du dépôt : c'est lui qui détient le token (coffre sécurisé) et
/// l'URL de base. Le token est **relu à chaque requête** (et non capturé une
/// fois) pour qu'un rafraîchissement ou une purge (401) soit pris en compte au
/// prochain `fetch`.
TransmitClient createTransmitClient({
  Future<String?> Function()? readToken,
  String baseUrl = kBaseUrl,
}) =>
    WebTransmitClient(
      readToken: readToken ?? ApiClient.instance.readToken,
      baseUrl: baseUrl,
    );

/// **Le client Transmit du web.** Voir l'en-tête du fichier pour le *pourquoi
/// `fetch`*.
class WebTransmitClient implements TransmitClient {
  WebTransmitClient({
    required Future<String?> Function() readToken,
    String baseUrl = kBaseUrl,
    String? uid,
  })  : _readToken = readToken,
        _baseUrl = baseUrl,
        // Le `uid` identifie **la connexion** (D6) : généré une fois, aléatoire,
        // non secret — il relie le flux d'événements aux abonnements. Ce n'est
        // pas le token, et lui **peut** aller dans l'URL.
        _uid = uid ?? const Uuid().v4();

  final Future<String?> Function() _readToken;
  final String _baseUrl;
  final String _uid;

  /// Le flux broadcast exposé par [events] : il ne se **ferme jamais** à un
  /// [disconnect] (contrat) — il se tait, puis reprend au [connect] suivant, sur
  /// une nouvelle connexion réseau derrière la même connexion Dart.
  final StreamController<TransmitEvent> _events =
      StreamController<TransmitEvent>.broadcast();

  /// Les canaux que le service **veut** — l'intention, retenue même connexion
  /// fermée (contrat) et **rejouée** à chaque (ré)établissement du flux.
  final Set<String> _channels = <String>{};

  /// Vrai entre [connect] et [disconnect] : la boucle de connexion doit tourner.
  bool _connected = false;

  /// Vrai quand le flux d'événements est **établi** côté serveur (réponse `ok`
  /// reçue), donc quand un `subscribe`/`unsubscribe` immédiat a une chance
  /// d'aboutir. Faux le reste du temps : on se contente alors de retenir
  /// l'intention, rejouée à l'établissement.
  bool _established = false;

  /// De quoi **couper** le `fetch` en vol à [disconnect] : `abort()` fait
  /// échouer la lecture du corps, ce que la boucle interprète comme une fin.
  web.AbortController? _abort;

  @override
  Stream<TransmitEvent> get events => _events.stream;

  @override
  Future<void> connect() async {
    // Idempotent (contrat) : une connexion déjà ouverte ne se rouvre pas.
    if (_connected) return;
    _connected = true;
    // La boucle vit toute seule ; [connect] rend la main tout de suite et ne
    // **lève pas** sur panne (contrat, D8) : le backoff est interne.
    unawaited(_runLoop());
  }

  @override
  Future<void> disconnect() async {
    if (!_connected) return;
    _connected = false;
    _established = false;
    // Coupe le flux en cours ; la boucle voit `_connected == false` et s'arrête.
    _abort?.abort();
    _abort = null;
    // Les canaux voulus sont **conservés** : un futur [connect] les réémet.
  }

  @override
  Future<void> subscribe(String channel) async {
    // Sans effet si déjà voulu (contrat). L'intention est retenue quoi qu'il
    // arrive ; le POST n'a lieu que si le flux est établi, sinon il partira au
    // prochain flush (à l'établissement).
    if (!_channels.add(channel)) return;
    if (_established) await _post('subscribe', channel);
  }

  @override
  Future<void> unsubscribe(String channel) async {
    if (!_channels.remove(channel)) return;
    if (_established) await _post('unsubscribe', channel);
  }

  /// **Ferme définitivement** le client : au-delà du contrat, pour un éventuel
  /// démontage. Ferme [_events] — un client fermé ne se rouvre pas. Pendant du
  /// `dispose()` natif.
  Future<void> dispose() async {
    await disconnect();
    await _events.close();
  }

  /// **La boucle de connexion + reconnexion**, avec backoff exponentiel plafonné.
  ///
  /// Un flux SSE ne « finit » pas : [_pump] ne rend la main qu'à une coupure
  /// (serveur, réseau) ou à un [disconnect]. Tant que [_connected], on rouvre.
  /// Le backoff se remet à zéro dès qu'une connexion a été **établie** — une
  /// coupure après des heures de flux ne doit pas hériter du délai d'un échec
  /// initial —, tout en gardant un plancher d'une seconde ([_backoff]) qui
  /// empêche une connexion instable de boucler à chaud.
  ///
  /// La toute **première** ouverture n'est pas une reconnexion : sa sync de
  /// rattrapage est déjà couverte par le déclencheur de premier plan. Toute
  /// ouverture réussie **suivante** émet le signal de rattrapage (D4).
  Future<void> _runLoop() async {
    var attempt = 0;
    var isReconnect = false;
    while (_connected) {
      final abort = web.AbortController();
      _abort = abort;
      var established = false;
      try {
        established = await _pump(abort.signal, isReconnect: isReconnect);
      } catch (_) {
        // Toute panne du flux est **avalée** : le temps-réel est un accélérateur
        // (D4), jamais une source d'erreur remontée. On reconnecte.
      } finally {
        _established = false;
      }
      if (!_connected) break;
      // Après la première tentative — réussie ou non —, toute ouverture est une
      // reconnexion (même sémantique que le chemin natif).
      isReconnect = true;
      attempt = established ? 0 : attempt + 1;
      await _backoff(attempt);
    }
  }

  /// **Ouvre le flux d'événements et le lit jusqu'à sa fin.** Rend `true` si la
  /// connexion a été **établie** (réponse `ok`), pour la remise à zéro du backoff.
  ///
  /// Le token est mis **dans l'en-tête**, jamais dans l'URL (le seul paramètre
  /// d'URL est le `uid`, non secret).
  Future<bool> _pump(web.AbortSignal signal, {required bool isReconnect}) async {
    final headers = web.Headers();
    final token = await _readToken();
    if (token != null) headers.append('Authorization', 'Bearer $token');
    headers.append('Accept', 'text/event-stream');

    final response = await web.window
        .fetch(
          '$_baseUrl/__transmit/events?uid=$_uid'.toJS,
          web.RequestInit(method: 'GET', headers: headers, signal: signal),
        )
        .toDart;
    if (!response.ok) return false;

    // La connexion est enregistrée côté serveur sous ce `uid` : on peut
    // (ré)abonner les canaux voulus. Fait **avant** de lire le corps pour ne pas
    // manquer un message émis juste après.
    _established = true;
    await _flushSubscriptions();

    // D4 : une reconnexion rejoue le trou par une sync de rattrapage. Le service
    // ne lit pas le canal — tout événement déclenche une sync ; la sentinelle
    // sert juste à provoquer cet événement sans faux message de groupe.
    if (isReconnect && !_events.isClosed) {
      _events.add(const TransmitEvent(HttpTransmitClient.reconnectSignalChannel));
    }

    final body = response.body;
    if (body == null) return true; // établie, mais rien à lire

    final reader = (body as _ByteReadableStream).getReader();
    final decoder = web.TextDecoder();
    final parser = SseFrameParser();
    try {
      while (true) {
        final chunk = await reader.read().toDart;
        if (chunk.done) break;
        final bytes = chunk.value;
        if (bytes == null) continue;
        // `stream: true` : le décodeur garde en mémoire un octet UTF-8 coupé
        // entre deux chunks au lieu de rendre un caractère de remplacement.
        final text = decoder.decode(bytes, _streamDecode);
        for (final data in parser.addChunk(text)) {
          final event = decodeTransmitEvent(data);
          if (event != null && !_events.isClosed) _events.add(event);
        }
      }
    } finally {
      // Libère le lecteur ; une annulation déjà avortée peut lever, sans intérêt.
      try {
        await reader.cancel().toDart;
      } catch (_) {}
    }
    return true;
  }

  /// (Ré)émet **tous** les abonnements voulus. Appelé à chaque établissement du
  /// flux : c'est ce qui rend un `subscribe` reçu connexion fermée effectif, et
  /// ce qui répare un POST d'abonnement qui aurait échoué.
  Future<void> _flushSubscriptions() async {
    for (final channel in _channels.toList()) {
      await _post('subscribe', channel);
    }
  }

  /// `POST /__transmit/{action}` avec `{ uid, channel }` et le Bearer en en-tête.
  /// **N'échoue jamais bruyamment** (D8) : un abonnement raté est rattrapé au
  /// prochain flush et par la sync de rattrapage (D4).
  Future<void> _post(String action, String channel) async {
    try {
      final headers = web.Headers();
      headers.append('Content-Type', 'application/json');
      final token = await _readToken();
      if (token != null) headers.append('Authorization', 'Bearer $token');
      await web.window
          .fetch(
            '$_baseUrl/__transmit/$action'.toJS,
            web.RequestInit(
              method: 'POST',
              headers: headers,
              body: jsonEncode({'uid': _uid, 'channel': channel}).toJS,
            ),
          )
          .toDart;
    } catch (_) {
      // Avalé volontairement — voir le doc de la méthode.
    }
  }

  /// Délai avant la nᵉ tentative : 1 s, 2 s, 4 s… plafonné à 30 s, plancher à
  /// 1 s. `Future.delayed` (et non un `Timer` répété) : c'est un simple
  /// attendre-puis-réessayer, pas du polling. Le garde-fou « aucun `Timer` » ne
  /// vise que `lib/data/sync/` ; le backoff de reconnexion appartient bien à
  /// l'implémentation du client (contrat).
  Future<void> _backoff(int attempt) async {
    final shift = attempt.clamp(0, 5);
    final ms = (1000 << shift).clamp(1000, 30000);
    await Future<void>.delayed(Duration(milliseconds: ms));
  }
}

/// `{ stream: true }` mémorisé une fois : voir [WebTransmitClient._pump].
final web.TextDecodeOptions _streamDecode = web.TextDecodeOptions(stream: true);

// ─────────────────────────────────────────────────────────────────────────────
// La part de l'API `ReadableStream` (streams d'octets de `fetch`) dont ce
// lecteur dépend — trois membres. On la déclare soi-même, comme
// `hls_content_player.dart` déclare `_HlsEngine` : le typage de `package:web`
// pour `getReader()` passe par une union peu commode, alors qu'ici on sait
// exactement ce que `response.body` rend — un flux d'octets dont le lecteur
// livre des `Uint8Array`.
// ─────────────────────────────────────────────────────────────────────────────

extension type _ByteReadableStream._(JSObject _) implements JSObject {
  external _ByteStreamReader getReader();
}

extension type _ByteStreamReader._(JSObject _) implements JSObject {
  external JSPromise<_ByteStreamChunk> read();
  external JSPromise<JSAny?> cancel();
}

extension type _ByteStreamChunk._(JSObject _) implements JSObject {
  /// Vrai quand le flux est épuisé — [value] est alors absent.
  external bool get done;
  external JSUint8Array? get value;
}
