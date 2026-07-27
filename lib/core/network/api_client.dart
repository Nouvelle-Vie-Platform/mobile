import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// URL du backend local.
///
/// Sur le simulateur iOS, `localhost` pointe directement sur la machine hôte.
/// Pour un appareil physique sur le même réseau Wi-Fi, remplacer par
/// l'adresse IP locale du Mac (ex. `http://192.168.1.X:3333`).
const String kBaseUrl = 'http://localhost:3333';

/// Clé de stockage sécurisé du token JWT.
const String _kTokenKey = 'auth_token';

/// Client HTTP global, pré-configuré avec :
/// - URL de base du backend local
/// - Headers JSON par défaut
/// - Intercepteur JWT : injecte automatiquement le token Bearer si présent
/// - Déballage de l'enveloppe `data` posée par le serveur
/// - Logs en mode debug
class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: kBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      _AuthInterceptor(_storage),
      unwrapEnvelopeInterceptor,
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (o) => print('[API] $o'), // ignore: avoid_print
      ),
    ]);
  }

  static final ApiClient instance = ApiClient._();

  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Dio get dio => _dio;

  // ── Token helpers ────────────────────────────────────────────────────────

  /// Persiste le JWT après une connexion réussie.
  Future<void> saveToken(String token) =>
      _storage.write(key: _kTokenKey, value: token);

  /// Supprime le JWT à la déconnexion.
  Future<void> deleteToken() => _storage.delete(key: _kTokenKey);

  /// Lit le JWT courant (null si absent).
  Future<String?> readToken() => _storage.read(key: _kTokenKey);
}

/// Intercepteur Dio : ajoute automatiquement `Authorization: Bearer <token>`
/// à chaque requête si un token est disponible en stockage sécurisé.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: _kTokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

/// Déballe l'enveloppe `data` que le serveur pose sur **toutes** ses réponses
/// (sérialiseur global monté sur `HttpContext`, partagé par ses modules).
///
/// Le déballage a lieu **une seule fois, ici** : les repositories — auth
/// aujourd'hui, feed / médiathèque / synchro demain — reçoivent le contenu à
/// plat et n'ont rien à savoir de l'enveloppe.
///
/// La condition est volontairement étroite — **une seule clé, nommée `data`** :
/// - `{data: {...}}` → déballé ;
/// - `{data: [...], meta: {...}}` (réponse paginée) → **intact** : `meta` porte
///   une information qu'on perdrait en déballant ;
/// - `{id: ..., name: ...}` (corps déjà à plat) → **intact**.
///
/// Exposé (plutôt que privé) pour être testable sans réseau.
@visibleForTesting
final Interceptor unwrapEnvelopeInterceptor = InterceptorsWrapper(
  onResponse: (res, handler) {
    final body = res.data;
    if (body is Map && body.length == 1 && body.containsKey('data')) {
      res.data = body['data'];
    }
    handler.next(res);
  },
);
