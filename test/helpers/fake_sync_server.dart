import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// **Double du serveur de synchronisation** — pas du client.
///
/// Sert les réponses écrites à la main de `sync_fixtures.dart` sur les deux
/// routes du protocole, **sans réseau** :
///
/// - `GET /sync` — le manifeste ;
/// - `GET /sync/{collection}` — le tirage delta.
///
/// ## Où il s'insère
///
/// C'est un [HttpClientAdapter] : il se substitue au **transport** de n'importe
/// quel `Dio`, y compris `ApiClient.instance.dio`. La requête traverse donc
/// tous les intercepteurs de production — injection du Bearer, déballage de
/// l'enveloppe `data`, traitement du 401 — et s'arrête juste avant la socket.
/// Ce qu'on teste au-dessus est le vrai chemin, pas une imitation.
///
/// Ne dépend que de `dart:convert`, `dart:typed_data` et `package:dio` :
/// aucune importation Flutter, aucun `dart:ui`. Le double tourne donc sur la
/// **VM Dart** — ni appareil, ni émulateur.
///
/// ## Comment on l'écrit
///
/// Les réponses sont **scriptées**, jamais calculées : ce ticket livre des
/// *formes de réponse*, pas une réimplémentation du serveur. Chaque collection
/// a sa file de réponses, consommée dans l'ordre ; **la dernière se répète**,
/// comme un serveur stable à qui l'on redemanderait la même chose.
///
/// ```dart
/// final server = FakeSyncServer()
///   ..serveManifest(manifestNominal())
///   ..servePages('teachings', teachingsPagesAtLimitOne());
/// dio.httpClientAdapter = server;
/// ```
///
/// Une collection jamais scriptée n'existe pas : elle répond **404**, comme le
/// registre serveur le fait d'une clé non enregistrée. C'est voulu — il faut
/// que demander `gatherings` coûte exactement ce que ça coûte en production.
class FakeSyncServer implements HttpClientAdapter {
  /// Toutes les requêtes vues, dans l'ordre — chemin, verbe, en-têtes et query
  /// string compris. C'est là qu'on vérifie qu'un client rejoue bien le
  /// curseur qu'on lui a donné, et qu'il n'en fabrique pas (ADR-0026).
  final List<RequestOptions> requests = [];

  final List<_Reply> _manifest = [];
  final Map<String, List<_Reply>> _collections = {};

  /// La dernière requête vue.
  RequestOptions get lastRequest => requests.last;

  /// Les requêtes adressées à une collection donnée, dans l'ordre.
  List<RequestOptions> requestsFor(String collection) => requests
      .where((r) => r.uri.path == '/sync/$collection')
      .toList(growable: false);

  /// Les requêtes de manifeste, dans l'ordre.
  List<RequestOptions> get manifestRequests =>
      requests.where((r) => r.uri.path == '/sync').toList(growable: false);

  // ── Scénarisation ────────────────────────────────────────────────────────

  /// Ajoute un manifeste à la file de `GET /sync`.
  void serveManifest(Map<String, Object?> payload) =>
      _manifest.add(_Reply.json(200, payload));

  /// Ajoute plusieurs manifestes successifs — pour faire **progresser** la
  /// `scope_version` d'un appel à l'autre.
  void serveManifests(Iterable<Map<String, Object?>> payloads) {
    for (final payload in payloads) {
      serveManifest(payload);
    }
  }

  /// Enregistre une collection et lui ajoute une page.
  ///
  /// Enregistrer, c'est faire exister : tant qu'une clé n'est pas passée ici,
  /// le double répond 404 pour elle.
  void serveCollection(String key, Map<String, Object?> page) =>
      _queueFor(key).add(_Reply.json(200, page));

  /// Enregistre une collection et lui ajoute plusieurs pages successives —
  /// une par tour de la boucle de rattrapage du client.
  void servePages(String key, Iterable<Map<String, Object?>> pages) {
    for (final page in pages) {
      serveCollection(key, page);
    }
  }

  /// Enregistre une collection qui répond une **erreur applicative** (corps
  /// `{ code, message }` à plat, hors enveloppe `data`).
  void serveErrorOn(
    String key, {
    int status = 500,
    String code = 'E_INTERNAL_SERVER_ERROR',
    String? message,
  }) =>
      _queueFor(key).add(_Reply.error(status, code, message));

  /// **Coupure réseau au milieu d'un cycle.** Ajoute, à la suite des pages déjà
  /// scriptées, une panne de transport : la requête suivante lève une
  /// [DioException] sans qu'aucune réponse ne soit rendue.
  ///
  /// C'est le seul moyen de vérifier qu'un cycle interrompu ne valide rien à
  /// moitié — ni le curseur, ni la `scope_version`, ni les lignes déjà lues.
  void cutConnectionOn(String key, {String reason = 'coupure simulée'}) =>
      _queueFor(key).add(_Reply.transportFailure(reason));

  /// Même coupure, sur le manifeste.
  void cutConnectionOnManifest({String reason = 'coupure simulée'}) =>
      _manifest.add(_Reply.transportFailure(reason));

  List<_Reply> _queueFor(String key) => _collections.putIfAbsent(key, () => []);

  // ── Transport ────────────────────────────────────────────────────────────

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    final path = options.uri.path;
    if (path == '/sync') return _consume(_manifest, options, '/sync');

    if (path.startsWith('/sync/')) {
      final key = path.substring('/sync/'.length);
      final queue = _collections[key];
      // Clé non enregistrée : exactement ce que rend le registre serveur.
      if (queue == null) return _collectionNotFound(key);
      return _consume(queue, options, path);
    }

    throw StateError(
      'FakeSyncServer ne double que `GET /sync` et `GET /sync/{collection}` ; '
      'reçu « $path ». Utiliser FakeAdapter pour les autres routes.',
    );
  }

  ResponseBody _consume(
    List<_Reply> queue,
    RequestOptions options,
    String path,
  ) {
    if (queue.isEmpty) {
      throw StateError(
        'Aucune réponse scriptée pour « $path ». Appeler serveManifest / '
        'serveCollection avant de lancer la requête.',
      );
    }
    // La dernière réponse se répète : un serveur ne cesse pas d'exister parce
    // qu'on lui redemande la même chose.
    final reply = queue.length == 1 ? queue.first : queue.removeAt(0);
    return reply.materialize(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Réponse 404 d'une clé de collection non enregistrée.
///
/// Le corps est à plat, **hors** enveloppe `data`, comme toutes les erreurs du
/// serveur. Le `code` est composé à partir du libellé de la ressource
/// (`RessourceNotExistsException`) : pour la route de tirage, le libellé est
/// `collection`, d'où [kCollectionNotFoundCode].
ResponseBody _collectionNotFound(String key) => _Reply.error(
      404,
      kCollectionNotFoundCode,
      "collection n'existe pas avec l'identifiant $key",
    ).materialize(null);

/// Le code d'erreur **réellement servi** sur une clé de collection inconnue.
///
/// ⚠️ Relevé dans le code, pas dans la documentation : la documentation Swagger
/// de `pullCollectionDelta` annonce `E_RESSOURCE_NOT_EXISTS`, mais
/// `RessourceNotExistsException` interpole le **libellé de la ressource** dans
/// son code (`E_NOT_EXISTS` → `E_COLLECTION_NOT_EXISTS`), et le controller
/// passe `'collection'`. Les tests fonctionnels du serveur confirment le motif
/// sur les autres ressources (`E_GROUP_NOT_EXISTS`, `E_INTERACTION_NOT_EXISTS`).
///
/// Un client ne devrait de toute façon **pas** se fonder sur ce code : c'est le
/// **statut 404** qui dit « cette collection n'existe pas ici », et un 404 de
/// collection n'est pas fatal — il faut sauter la collection, pas échouer la
/// synchronisation.
const String kCollectionNotFoundCode = 'E_COLLECTION_NOT_EXISTS';

/// Une réponse scriptée : succès JSON, erreur applicative, ou panne de
/// transport.
class _Reply {
  const _Reply._(this._status, this._body, this._failureReason);

  /// Succès : le corps est **enveloppé sous `data`**, comme en production.
  factory _Reply.json(int status, Object? payload) =>
      _Reply._(status, {'data': payload}, null);

  /// Erreur applicative : `{ code, message }` à plat, hors enveloppe.
  factory _Reply.error(int status, String code, String? message) => _Reply._(
        status,
        {'code': code, if (message != null) 'message': message},
        null,
      );

  /// Panne de transport : aucune réponse, une [DioException] est levée.
  factory _Reply.transportFailure(String reason) => _Reply._(0, null, reason);

  final int _status;
  final Object? _body;
  final String? _failureReason;

  ResponseBody materialize(RequestOptions? options) {
    final reason = _failureReason;
    if (reason != null) {
      throw DioException.connectionError(
        requestOptions: options ?? RequestOptions(path: '/sync'),
        reason: reason,
      );
    }
    return ResponseBody.fromString(
      jsonEncode(_body),
      _status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
