import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../models/models.dart';
import '../local/user_cache.dart';
import 'auth_repository.dart';

/// Implémentation HTTP de [AuthRepository], branchée sur le backend réel.
///
/// Endpoints — voir `docs/auth-contract.md` (v2), qui fait foi :
/// ```
/// POST /auth/request-code   → 202 { status: "sent" }
/// POST /auth/verify-code    → 200 { token, user, isNewUser }
/// GET  /auth/me             → 200 User            (Bearer)
/// PUT  /auth/profile        → 200 User            (Bearer)
/// POST /auth/sign-out       → 200                 (Bearer)
/// ```
///
/// Deux choses dont cette classe **n'a pas** à s'occuper, traitées une seule
/// fois dans `ApiClient` : l'enveloppe `data` posée sur toutes les réponses
/// (déballée par un intercepteur — les corps arrivent ici à plat) et le **401**
/// (purge du token + retour à `/auth`).
///
/// Rien non plus côté **rafraîchissement de token** : le serveur fait glisser
/// l'expiration sans changer la chaîne. Ni rotation, ni refresh token.
///
/// **La persistance locale du `User` vit ici**, derrière l'interface : le
/// repository écrit le cache à chaque réponse fraîche (`verifyCode`,
/// `updateProfile`, `me`) et l'efface dès qu'il n'y a plus de session. Les
/// écrans ne voient que `AuthRepository` — remplacer [UserCache] par ObjectBox
/// au jalon synchro ne touchera aucun widget.
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository({ApiClient? client, UserCache? cache})
      : _client = (client ?? ApiClient.instance).dio,
        _api = client ?? ApiClient.instance,
        _cache = cache ?? UserCache();

  final Dio _client;
  final ApiClient _api;
  final UserCache _cache;

  // ── requestCode ─────────────────────────────────────────────────────────

  @override
  Future<void> requestCode({
    required String identifier,
    required IdentifierChannel channel,
  }) async {
    try {
      await _client.post<void>(
        '/auth/request-code',
        data: {
          'identifier': identifier,
          'channel': channel.name, // 'phone' ou 'email'
        },
      );
    } on DioException catch (e) {
      throw mapAuthError(e);
    }
  }

  // ── verifyCode ───────────────────────────────────────────────────────────

  @override
  Future<Session> verifyCode({
    required String identifier,
    required String code,
  }) async {
    try {
      final res = await _client.post<Map<String, dynamic>>(
        '/auth/verify-code',
        data: {'identifier': identifier, 'code': code},
      );
      final session = Session.fromJson(res.data!);
      // Le token est **opaque** (`oat_…`) : on le stocke tel quel pour les
      // requêtes suivantes. Il ne contient aucune information — ne jamais
      // tenter de le décoder pour y lire une expiration ou un identifiant.
      await _api.saveToken(session.token);
      // Le cache prend le relais dès le prochain démarrage : sans lui, une
      // session valide repasserait par le réseau avant d'ouvrir l'app.
      await _cache.write(session.user);
      return session;
    } on DioException catch (e) {
      throw mapAuthError(e);
    }
  }

  // ── Social sign-in ───────────────────────────────────────────────────────

  @override
  Future<Session> signInWithGoogle() async {
    // TODO: implémenter quand le backend supporte OAuth Google.
    throw UnimplementedError(
        'Google sign-in non encore implémenté côté backend');
  }

  @override
  Future<Session> signInWithApple() async {
    // TODO: implémenter quand le backend supporte OAuth Apple.
    throw UnimplementedError(
        'Apple sign-in non encore implémenté côté backend');
  }

  // ── Session locale ───────────────────────────────────────────────────────

  /// Lecture **purement locale** : aucun octet ne part sur le réseau, donc
  /// aucune latence togolaise ni panne de connexion ne peut retarder le
  /// démarrage. C'est ce que consomme le splash.
  @override
  Future<User?> cachedUser() => _cache.read();

  @override
  Future<void> forgetSession() async {
    // Le token a en général déjà été purgé par l'intercepteur 401 ; l'appel
    // reste idempotent, et couvre le cas où on arrive ici autrement.
    await _api.deleteToken();
    await _cache.clear();
  }

  // ── currentUser ──────────────────────────────────────────────────────────

  @override
  Future<User?> currentUser() async {
    final token = await _api.readToken();
    if (token == null) {
      // Plus de token = plus de session : le cache ne décrit plus personne.
      await _cache.clear();
      return null;
    }
    try {
      final res = await _client.get<Map<String, dynamic>>('/auth/me');
      final user = User.fromJson(res.data!);
      // Revalidation réussie : le cache reflète désormais le serveur.
      await _cache.write(user);
      return user;
    } on DioException catch (e) {
      // Token invalide ou expiré : la purge du token et le retour à `/auth`
      // sont pris en charge globalement par l'intercepteur 401 d'ApiClient.
      // Le cache, lui, est notre affaire — le laisser survivrait à la session.
      if (e.response?.statusCode == 401) {
        await _cache.clear();
        return null;
      }
      // Toute autre erreur (réseau coupé, 500) laisse le cache **intact** :
      // l'utilisateur reste dans l'app avec ses données locales.
      throw mapAuthError(e);
    }
  }

  // ── updateProfile ────────────────────────────────────────────────────────

  /// Mise à jour **partielle** : seuls les champs fournis partent sur le
  /// réseau. `branchId` est un **entier**, comme `Branch.id` — les deux se
  /// comparent directement.
  ///
  /// `status` n'exprime qu'une intention (« je suis nouveau ») : côté serveur
  /// c'est `branchId` qui fait foi et qui dérive le statut.
  @override
  Future<User> updateProfile({
    UserTitle? title,
    String? firstName,
    String? lastName,
    int? branchId,
    UserStatus? status,
  }) async {
    try {
      final res = await _client.put<Map<String, dynamic>>(
        '/auth/profile',
        data: {
          if (title != null) 'title': title.name,
          if (firstName != null) 'firstName': firstName,
          if (lastName != null) 'lastName': lastName,
          if (branchId != null) 'branchId': branchId,
          if (status != null) 'status': status.name,
        },
      );
      final user = User.fromJson(res.data!);
      await _cache.write(user);
      return user;
    } on DioException catch (e) {
      throw mapAuthError(e);
    }
  }

  // ── signOut ──────────────────────────────────────────────────────────────

  /// Révoque le token courant côté serveur (les autres appareils restent
  /// connectés), puis supprime le token local **quoi qu'il arrive**.
  ///
  /// L'échec serveur est volontairement avalé — 500, timeout, avion en vol :
  /// une erreur réseau ne doit jamais laisser l'utilisateur connecté sur son
  /// appareil alors qu'il vient de demander à se déconnecter. Le `finally`
  /// couvre aussi ce qui n'est pas une `DioException`.
  ///
  /// **Token et cache partent ensemble** : effacer le seul token laisserait le
  /// prochain démarrage router vers l'accueil avec le nom de l'utilisateur qui
  /// vient de partir.
  @override
  Future<void> signOut() async {
    try {
      await _client.post<void>('/auth/sign-out');
    } on Object catch (_) {
      // Rien à remonter : la déconnexion locale ne dépend pas du serveur.
    } finally {
      await forgetSession();
    }
  }
}

// ── Mapping des erreurs ────────────────────────────────────────────────────

/// Traduit une [DioException] en [AuthException], en se fondant sur le champ
/// **`code`** du corps d'erreur — **jamais sur le statut HTTP seul**.
///
/// Le serveur (`I18nException`, AdonisJS) répond
/// `{ "code": "E_…", "message": "…" }` à plat, hors de l'enveloppe `data` :
///
/// | `code` serveur | HTTP | [AuthErrorCode] |
/// | --- | --- | --- |
/// | `E_INVALID_OTP_CODE` | 422 | `invalidCode` (invalide **et** expiré) |
/// | `E_OTP_TOO_MANY_ATTEMPTS` | 429 | `tooManyAttempts` |
/// | `E_OTP_RATE_LIMITED` | 429 | `tooManyAttempts` |
/// | `E_INVALID_PHONE_NUMBER` | 422 | `unknown` + message serveur |
/// | `E_VALIDATION_ERROR` | 422 | `unknown` + message du validateur |
///
/// Deux codes distincts partagent le **429** : mapper sur le statut seul
/// suffirait ici par chance, mais confondrait n'importe quel futur 429. Et le
/// **422** couvre aussi bien « code invalide » qu'une erreur de validation.
///
/// Le **401** n'est pas traité ici : `UnauthorizedInterceptor` l'a déjà pris en
/// charge globalement (purge du token, retour à `/auth`). Il retombe donc sur
/// `unknown` — l'appel en cours doit échouer, sans prétendre que le *code* de
/// l'utilisateur était mauvais.
///
/// Les messages sont **déjà localisés** par le serveur (fr / en) : on les
/// remonte tels quels pour les cas `unknown`, qui n'ont pas de libellé propre.
///
/// Fonction de niveau bibliothèque (et non méthode privée) pour rester
/// testable sans réseau — `flutter test` répond 400 à tout accès réel.
@visibleForTesting
AuthException mapAuthError(DioException e) {
  // Le serveur n'a pas répondu (timeout, DNS, coupure, TLS) : c'est le réseau,
  // pas une erreur métier. `cancel` mis à part, toute absence de réponse vaut
  // « injoignable » — sans importer `dart:io`, qui casserait la cible web.
  if (e.type == DioExceptionType.cancel) {
    return AuthException(AuthErrorCode.unknown, e.message);
  }
  final response = e.response;
  if (response == null) {
    return AuthException(
      AuthErrorCode.network,
      'Impossible de joindre le serveur (${e.message})',
    );
  }

  final body = response.data;
  final code = body is Map ? body['code'] as String? : null;
  final message = body is Map ? body['message'] as String? : null;
  final retryAfter = _retryAfterOf(response);

  return switch (code) {
    'E_INVALID_OTP_CODE' => AuthException(AuthErrorCode.invalidCode, message),
    'E_OTP_TOO_MANY_ATTEMPTS' || 'E_OTP_RATE_LIMITED' => AuthException(
        AuthErrorCode.tooManyAttempts,
        message,
        retryAfter,
      ),
    _ => AuthException(AuthErrorCode.unknown, message ?? e.message, retryAfter),
  };
}

/// Délai de réessai annoncé par le serveur : corps `retryAfter` (secondes)
/// d'abord — c'est le champ du contrat — puis l'en-tête HTTP `Retry-After`.
///
/// `Retry-After` peut aussi porter une **date** HTTP : non parsable en entier,
/// elle rend `null`, et l'UI retombe sur son cooldown par défaut. Le serveur
/// n'émet aujourd'hui ni l'un ni l'autre : tout est donc facultatif.
Duration? _retryAfterOf(Response<dynamic> response) {
  final body = response.data;
  final seconds = _asSeconds(body is Map ? body['retryAfter'] : null) ??
      _asSeconds(response.headers.value('retry-after'));
  return seconds == null ? null : Duration(seconds: seconds);
}

/// Lit un nombre de secondes positif depuis un entier, un décimal ou une
/// chaîne. Toute autre forme (ou une valeur négative) rend `null`.
int? _asSeconds(Object? raw) {
  final value = switch (raw) {
    final num n => n.round(),
    final String s => int.tryParse(s.trim()),
    _ => null,
  };
  return (value == null || value < 0) ? null : value;
}
