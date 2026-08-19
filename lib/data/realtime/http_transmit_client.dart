/// **Le client Transmit natif** (iOS/Android) — SSE sur le `Dio` d'`ApiClient`
/// (décisions D6 et D8 de `docs/temps-reel-sse.md`).
///
/// C'est la moitié « native/VM » de la porte `transmit_client_factory.dart` ;
/// le web reçoit `WebTransmitClient` (lecteur `fetch`), car l'`EventSource` du
/// navigateur **ne porte pas** l'en-tête `Authorization` qu'exige le guard
/// `api`. Ici, `Dio` porte déjà le Bearer (intercepteur d'`ApiClient`) et le
/// 401 est traité en amont, une fois pour toutes.
///
/// ## Le protocole Transmit, tel qu'on le parle
///
/// - **Une connexion** = un flux SSE `GET /__transmit/events?uid={uid}`, ouvert
///   en `ResponseType.stream` pour lire les octets au fil de l'eau au lieu de
///   les tamponner. Le [_uid] identifie la connexion, il est **fabriqué par le
///   client** (`uuid`) et relie le flux à ses abonnements.
/// - **S'abonner / se désabonner** = `POST /__transmit/subscribe` /
///   `/unsubscribe`, corps `{ uid, channel }`.
///
/// ## Lire un flux SSE sur Dio
///
/// Le corps arrive en octets ; on le décode en UTF-8 **en continu** (le
/// décodeur retient les séquences multi-octets coupées entre deux paquets),
/// puis on découpe en lignes. Une trame SSE se termine par une **ligne vide** ;
/// on accumule les lignes `data:` et on décode le JSON à la trame complète.
/// Chaque trame Transmit est un objet `{ channel, payload }` : on en tire un
/// [TransmitEvent]. Les **pings** (lignes de commentaire commençant par `:`) et
/// les autres champs SSE (`event:`, `id:`, `retry:`) sont **ignorés**.
///
/// **Le `receiveTimeout` par défaut d'`ApiClient` (15 s) tuerait ce flux** : il
/// borne l'attente *entre deux paquets*, or un flux SSE au repos n'en envoie
/// pas. On l'annule (`Duration.zero`) pour ce seul appel — un flux long-vivant
/// n'a pas de délai de réception.
///
/// ## Reconnexion
///
/// Une coupure (erreur réseau, fin de flux serveur) **ne remonte jamais** vers
/// l'appelant : le temps-réel est un accélérateur, la non-perte est garantie
/// par le curseur `?since` de `/sync` (D4). On rouvre le flux avec un backoff
/// simple (1 s → 2 s → 5 s, plafonné) pour ne pas marteler le serveur. À chaque
/// **reconnexion** (et non au premier `connect`, dont la sync de rattrapage est
/// déjà couverte par le déclencheur de premier plan), on ré-abonne tous les
/// canaux retenus **et** on émet un signal générique
/// ([reconnectSignalChannel]) : le `RealtimeService` le traite comme n'importe
/// quel événement — il déclenche une sync de rattrapage (D4). Rien de ce qui a
/// été émis pendant le trou n'est perdu, le curseur le rejoue.
///
/// ## Le payload n'est PAS peint (D1)
///
/// [TransmitEvent.payload] est décodé et **porté**, jamais lu pour afficher :
/// un événement ne sert qu'à **déclencher un cycle de sync**, le message revient
/// par le flux delta. « Le réseau ne peint jamais » (ADR-0026). On ne dépend
/// donc pas de la forme du payload, que le contrat serveur n'a pas figée.
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_client.dart';
import 'transmit_client.dart';

/// Fabrique de la porte `transmit_client_factory.dart` (moitié native/VM) —
/// pendant de `createWebContentPlayer()` côté lecteur. Le web fournira la
/// sienne dans `web_transmit_client.dart`.
TransmitClient createTransmitClient() => HttpTransmitClient();

/// Implémentation native de [TransmitClient] : SSE sur le `Dio` d'`ApiClient`.
///
/// [dio] et [uid] ne sont paramétrables que pour les tests d'intégration
/// `live-server` (déterminisme) ; en production les défauts sont les bons.
class HttpTransmitClient implements TransmitClient {
  HttpTransmitClient({Dio? dio, String? uid})
      : _dio = dio ?? ApiClient.instance.dio,
        _uid = uid ?? const Uuid().v4();

  final Dio _dio;

  /// Identifie **la connexion** : le même [_uid] au flux (`?uid=`) et aux corps
  /// d'abonnement. Généré par le client (contrat), il n'est pas dans
  /// l'interface.
  final String _uid;

  /// Le flux d'événements, **broadcast** et **tous canaux confondus** (Transmit
  /// multiplexe, D2). Ne se ferme **pas** à un [disconnect] : il se tait puis
  /// reprend au [connect] suivant (contrat).
  final StreamController<TransmitEvent> _events =
      StreamController<TransmitEvent>.broadcast();

  /// Les canaux **voulus** — l'intention d'abonnement, indépendante de l'état de
  /// la connexion. Conservée à travers [disconnect] et réappliquée à chaque
  /// (ré)ouverture du flux : c'est ce qui rend `subscribe` à froid légitime.
  final Set<String> _channels = <String>{};

  /// Les lignes `data:` de la trame SSE en cours de lecture, vidées à chaque
  /// trame complète (ligne vide).
  final List<String> _dataLines = <String>[];

  StreamSubscription<String>? _lineSub;
  CancelToken? _cancel;
  Timer? _reconnectTimer;

  /// L'étape de backoff courante, remise à zéro à chaque ouverture réussie.
  int _backoffStep = 0;

  /// Vrai tant que le flux SSE est ouvert et alimente [_events].
  bool _connected = false;

  /// Vrai pendant un [disconnect] délibéré : distingue une fermeture voulue
  /// (pas de reconnexion) d'une coupure subie (reconnexion).
  bool _closing = false;

  /// Le backoff de reconnexion : 1 s, 2 s, puis 5 s à répétition. Plafonné pour
  /// ne pas marteler le serveur ; jamais nul pour ne pas boucler frénétiquement.
  static const List<Duration> _backoff = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 5),
  ];

  /// Canal **sentinelle** émis à chaque reconnexion pour forcer une sync de
  /// rattrapage (D4). Ce n'est pas un vrai canal `groups/{id}` ; le
  /// `RealtimeService` ne lit pas le canal, il déclenche une sync sur tout
  /// événement — d'où un nom volontairement hors de l'espace `groups/`.
  static const String reconnectSignalChannel = '__transmit_reconnect__';

  @override
  Stream<TransmitEvent> get events => _events.stream;

  @override
  Future<void> connect() async {
    _closing = false;
    if (_connected) return; // idempotent : ne rouvre pas un flux déjà ouvert.
    await _openStream(isReconnect: false);
  }

  @override
  Future<void> disconnect() async {
    _closing = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _backoffStep = 0;
    await _lineSub?.cancel();
    _lineSub = null;
    // Annule la requête GET en vol : sans cela le flux resterait ouvert côté
    // socket. Le message de cancel n'est jamais remonté (best-effort).
    _cancel?.cancel('disconnect');
    _cancel = null;
    _connected = false;
    _dataLines.clear();
    // [_channels] est **conservé** (l'intention survit, contrat) et [_events]
    // n'est **pas** fermé (il reprendra au prochain connect).
  }

  @override
  Future<void> subscribe(String channel) async {
    final isNew = _channels.add(channel);
    // Idempotent : si déjà voulu, rien à faire. À froid, l'intention est
    // simplement retenue et sera appliquée à la prochaine ouverture du flux.
    if (_connected && isNew) await _postChannel('/__transmit/subscribe', channel);
  }

  @override
  Future<void> unsubscribe(String channel) async {
    final existed = _channels.remove(channel);
    if (_connected && existed) {
      await _postChannel('/__transmit/unsubscribe', channel);
    }
  }

  /// **Ferme définitivement** le client : au-delà du contrat, pour les tests et
  /// un éventuel démontage. Ferme [_events] — un client fermé ne se rouvre pas.
  Future<void> dispose() async {
    await disconnect();
    await _events.close();
  }

  // ── Flux SSE ───────────────────────────────────────────────────────────────

  /// Ouvre (ou rouvre) le flux SSE, ré-abonne les canaux retenus et, sur une
  /// **reconnexion**, émet le signal de rattrapage. Ne lève jamais : toute
  /// panne mène à une reconnexion planifiée.
  Future<void> _openStream({required bool isReconnect}) async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    final cancel = CancelToken();
    _cancel = cancel;

    try {
      final response = await _dio.get<ResponseBody>(
        '/__transmit/events',
        queryParameters: <String, dynamic>{'uid': _uid},
        options: Options(
          responseType: ResponseType.stream,
          // Un flux long-vivant n'a pas de délai de réception : le défaut de
          // 15 s le couperait au premier silence (voir l'en-tête).
          receiveTimeout: Duration.zero,
        ),
        cancelToken: cancel,
      );

      final body = response.data;
      if (body == null) {
        if (!_closing) _scheduleReconnect();
        return;
      }

      _connected = true;
      _backoffStep = 0;
      _listen(body.stream);

      // (Ré)abonne l'intégralité des canaux voulus : après une coupure, le
      // serveur a oublié les abonnements de cette connexion.
      for (final channel in _channels) {
        await _postChannel('/__transmit/subscribe', channel);
      }

      // D4 : une reconnexion rejoue le trou par une sync de rattrapage. Le
      // premier `connect` en est dispensé — le premier plan a déjà synchronisé.
      if (isReconnect) _emitReconnectSignal();
    } on DioException catch (_) {
      if (!_closing) _scheduleReconnect();
    } catch (_) {
      // Best-effort : aucune panne d'ouverture ne remonte à l'appelant.
      if (!_closing) _scheduleReconnect();
    }
  }

  /// Branche le découpage octets → UTF-8 → lignes → trames SSE.
  void _listen(Stream<List<int>> byteStream) {
    _dataLines.clear();
    _lineSub = byteStream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          _onLine,
          onError: (Object _) => _onStreamEnded(),
          onDone: _onStreamEnded,
          cancelOnError: true,
        );
  }

  /// Une ligne SSE. Ligne vide → fin de trame ; `:` → ping/commentaire ignoré ;
  /// `data:` → accumulée (le reste des champs SSE ne nous concerne pas).
  void _onLine(String line) {
    if (line.isEmpty) {
      _dispatchFrame();
      return;
    }
    if (line.startsWith(':')) return; // ping / commentaire
    if (line.startsWith('data:')) {
      var value = line.substring(5);
      if (value.startsWith(' ')) value = value.substring(1); // espace optionnel
      _dataLines.add(value);
    }
  }

  /// Décode la trame accumulée et, si elle porte un canal, émet l'événement.
  void _dispatchFrame() {
    if (_dataLines.isEmpty) return;
    final raw = _dataLines.join('\n');
    _dataLines.clear();

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return; // trame non-JSON (heartbeat applicatif éventuel) — ignorée
    }

    if (decoded is Map && decoded['channel'] is String) {
      _emit(
        TransmitEvent(decoded['channel'] as String, payload: decoded['payload']),
      );
    }
  }

  /// Le flux s'est tari (fin serveur ou erreur réseau). Bascule hors-ligne et,
  /// si ce n'est pas une fermeture voulue, planifie une reconnexion.
  void _onStreamEnded() {
    _lineSub = null;
    _connected = false;
    _dataLines.clear();
    if (_closing) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_closing) return;
    if (_reconnectTimer != null) return; // une seule tentative en vol
    final delay = _backoff[_backoffStep];
    if (_backoffStep < _backoff.length - 1) _backoffStep++;
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      _openStream(isReconnect: true);
    });
  }

  void _emitReconnectSignal() =>
      _emit(const TransmitEvent(reconnectSignalChannel));

  void _emit(TransmitEvent event) {
    if (_events.isClosed) return;
    _events.add(event);
  }

  /// `POST /__transmit/(un)subscribe` `{ uid, channel }`, **best-effort** : une
  /// panne ne remonte pas. L'état voulu vit dans [_channels] ; une reconnexion
  /// réapplique l'ensemble, ce qui rattrape un abonnement raté.
  Future<void> _postChannel(String path, String channel) async {
    try {
      await _dio.post<dynamic>(
        path,
        data: <String, dynamic>{'uid': _uid, 'channel': channel},
      );
    } catch (_) {
      // Silencieux (D6 : le SSE est un accélérateur). La reconnexion rattrape.
    }
  }
}
