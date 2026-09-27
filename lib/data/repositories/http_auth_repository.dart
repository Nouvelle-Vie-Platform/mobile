import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../models/models.dart';
import '../devices/device_repository.dart';
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
///
/// **Le porteur d'appareil entoure ce cycle de vie**, et à deux endroits :
///
/// - à la **connexion**, `verifyCode` range le jeton de membre **à la place** du
///   jeton d'appareil (un seul emplacement dans le coffre). Le serveur révoque
///   celui-ci de son côté, à partir du porteur qui a présenté la requête de
///   connexion : c'est pour cela que `POST /auth/verify-code` doit partir **avec
///   le jeton d'appareil**, ce que `_AuthInterceptor` fait déjà en posant le
///   jeton présent. Rien à lui demander de plus ;
/// - à la **déconnexion**, l'application **redemande** un jeton d'appareil avec
///   le **même** `deviceId` ([DeviceRepository.resume]), pour que l'invité
///   retombe sur le catalogue et non sur l'écran de connexion.
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository({
    ApiClient? client,
    UserCache? cache,
    DeviceRepository? device,
  })  : _client = (client ?? ApiClient.instance).dio,
        _api = client ?? ApiClient.instance,
        _cache = cache ?? UserCache(),
        _device = device;

  final Dio _client;
  final ApiClient _api;
  final UserCache _cache;

  /// Le porteur d'appareil, **facultatif** : `null` = pas de mode invité câblé,
  /// et la déconnexion laisse alors le coffre vide, comme avant.
  final DeviceRepository? _device;

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
      //
      // Il prend la place du jeton d'appareil, dans le même emplacement et avec
      // le marqueur `member` : à partir d'ici, un 401 redevient une éjection vers
      // `/auth`, ce qui est bien ce qu'on veut pour quelqu'un de connecté.
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

  /// Écriture **purement locale**, elle aussi : ce que le serveur vient de dire
  /// descend jusqu'au cache sans repasser par lui.
  @override
  Future<void> rememberUser(User user) => _cache.write(user);

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
  ///
  /// **La reprise d'un jeton d'appareil vient après la purge, et elle est aussi
  /// obligatoire que la purge.** Sans elle, l'application se retrouve sans aucun
  /// porteur : la requête suivante part nue, son 401 se lit comme un 401 de
  /// membre, et un invité qui vient de se déconnecter tombe sur l'écran de
  /// connexion — exactement ce que le mode invité supprime.
  ///
  /// Elle tient aussi dans le cas que `signOut` traite déjà de travers en
  /// apparence : le coffre est purgé **même quand le réseau est absent**. La
  /// reprise échoue alors elle aussi, mais [DeviceRepository.resume] a marqué le
  /// coffre comme *attendant* un jeton d'appareil, et le prochain 401 la
  /// relancera en silence. Rien ne reste sans jeton pour toujours.
  @override
  Future<void> signOut() async {
    try {
      await _client.post<void>('/auth/sign-out');
    } on Object catch (_) {
      // Rien à remonter : la déconnexion locale ne dépend pas du serveur.
    } finally {
      await forgetSession();
      // `resume` ne lève pas ; le `catch` couvre ce qui n'est pas une
      // `DioException` (coffre indisponible), car partir ne peut pas échouer.
      try {
        await _device?.resume();
      } on Object catch (_) {}
    }
  }

  /// `DELETE /auth/me` — aucun paramètre, aucun corps : le Bearer désigne le
  /// compte, et c'est ce qui rend cette route incapable de supprimer autrui.
  ///
  /// **N'efface rien localement.** Le magasin Drift et la session sont la
  /// responsabilité de l'appelant, qui n'y touche qu'après le succès.
  @override
  Future<void> deleteAccount() async {
    try {
      await _client.delete<void>('/auth/me');
    } on DioException catch (e) {
      // Le serveur révoque tous les tokens dans la transaction : un second
      // appel — ou un token qui venait d'expirer — reçoit `401`, et il n'y a
      // pas d'état « déjà supprimé » à distinguer. Plus de session dans les
      // deux cas : l'appelant peut effacer.
      if (e.response?.statusCode == 401) return;
      throw mapAuthError(e);
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
