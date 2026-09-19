import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// URL du backend, injectée au build.
///
/// ```sh
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3333
/// flutter build ipa --dart-define=API_BASE_URL=https://api.example.org
/// ```
///
/// La valeur par défaut ne vaut **que pour le développement** : `localhost`
/// désigne la machine hôte depuis le simulateur iOS, mais l'appareil lui-même
/// depuis un téléphone physique. Tester sur un vrai appareil se fait donc en
/// passant `--dart-define`, jamais en éditant ce fichier — une URL de dev codée
/// en dur finit par partir en production.
const String kBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://eenv.brainsial.com',
);

/// Clé de stockage sécurisé du token d'authentification.
const String _kTokenKey = 'auth_token';

/// Client HTTP global, pré-configuré avec :
/// - l'URL de base du backend ([kBaseUrl], injectée par `--dart-define`)
/// - Headers JSON par défaut
/// - Intercepteur d'auth : injecte automatiquement le token Bearer si présent
/// - Déballage de l'enveloppe `data` posée par le serveur
/// - Traitement global du 401 (purge du token + [onUnauthorized])
/// - Logs en mode debug
class ApiClient {
  ApiClient._() {
    ensureSecureBaseUrl();

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
      UnauthorizedInterceptor(_handleUnauthorized),
      // Uniquement en debug : ces logs contiennent les corps de requête et le
      // header `Authorization`, qui n'ont rien à faire dans les journaux d'un
      // appareil de production.
      if (kDebugMode)
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (o) => debugPrint('[API] $o'),
        ),
    ]);
  }

  static final ApiClient instance = ApiClient._();

  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Dio get dio => _dio;

  /// Appelé quand le serveur répond **401** sur n'importe quelle requête. Le
  /// token vient d'être purgé ; il reste à ramener l'utilisateur à `/auth`.
  ///
  /// Ce point d'accroche existe pour que la couche réseau **ignore** Riverpod
  /// et go_router : c'est la couche application qui le câble au démarrage
  /// (`MaisonDuMiracleApp`), là où le routeur et les providers existent. Les
  /// couches basses ne connaissent pas les couches hautes.
  void Function()? onUnauthorized;

  /// Refuse une URL de base en HTTP clair dans un build **release**.
  ///
  /// Un `assert` ne suffirait pas : il est retiré à la compilation en release,
  /// c'est-à-dire exactement dans le build qu'il faut protéger. D'où un vrai
  /// contrôle, qui lève. Le token Bearer ouvre le compte pendant 90 jours
  /// glissants : il ne doit jamais transiter en clair.
  ///
  /// Appelé au démarrage (`main`) pour échouer tout de suite, et à la création
  /// du client pour qu'aucun chemin ne puisse le contourner.
  ///
  /// [url] et [releaseMode] ne sont paramétrables que pour les tests : en
  /// production les deux valeurs par défaut sont les bonnes.
  static void ensureSecureBaseUrl({
    String url = kBaseUrl,
    bool releaseMode = kReleaseMode,
  }) {
    if (!releaseMode || url.startsWith('https://')) return;
    throw StateError(
      'API_BASE_URL doit être en HTTPS dans un build release (reçu : "$url"). '
      'Le token Bearer y transiterait en clair, or il ouvre le compte pendant '
      '90 jours. Relancer le build avec '
      '--dart-define=API_BASE_URL=https://mon-domaine.example',
    );
  }

  /// Réaction au 401, dans l'ordre : purger le token (personne d'autre ne le
  /// fera — l'appel en cours, lui, échoue), puis prévenir la couche
  /// application.
  Future<void> _handleUnauthorized() async {
    await deleteToken();
    onUnauthorized?.call();
  }

  // ── Token helpers ────────────────────────────────────────────────────────

  /// Persiste le token après une connexion réussie.
  Future<void> saveToken(String token) =>
      _storage.write(key: _kTokenKey, value: token);

  /// Supprime le token à la déconnexion.
  Future<void> deleteToken() => _storage.delete(key: _kTokenKey);

  /// Lit le token courant (null si absent).
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

/// Intercepteur Dio : traite le **401** une fois pour toutes.
///
/// Un 401 n'est pas une erreur métier : il dit que le token n'est plus valide
/// (révoqué, ou 90 jours d'inactivité). On le purge et on prévient la couche
/// application via [ApiClient.onUnauthorized], au lieu de laisser chaque
/// repository — auth, feed, médiathèque, synchro — remonter une `DioException`
/// brute jusqu'à l'UI.
///
/// L'erreur poursuit malgré tout sa route (`handler.next`) : l'appel en cours
/// doit échouer, il n'a simplement plus à décider du sort du token.
///
/// [_onUnauthorized] est injecté (et non lu sur [ApiClient]) pour rendre
/// l'intercepteur testable sans réseau ni stockage sécurisé.
class UnauthorizedInterceptor extends Interceptor {
  UnauthorizedInterceptor(this._onUnauthorized);

  final Future<void> Function() _onUnauthorized;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      await _onUnauthorized();
    }
    handler.next(err);
  }
}
