import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../models/models.dart';
import 'auth_repository.dart';

/// Implémentation HTTP de [AuthRepository] branchée sur le backend local.
///
/// Correspond au contrat défini dans `AuthRepository`.
/// Les endpoints sont à adapter selon les routes définies dans ton backend.
///
/// Structure attendue du backend :
/// ```
/// POST /auth/request-code   → 200 OK
/// POST /auth/verify-code    → { token, user, isNewUser }
/// GET  /auth/me             → User (requiert Bearer token)
/// PUT  /auth/profile        → User (requiert Bearer token)
/// POST /auth/sign-out       → 200 OK (requiert Bearer token)
/// ```
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository({ApiClient? client})
      : _client = (client ?? ApiClient.instance).dio,
        _api = client ?? ApiClient.instance;

  final Dio _client;
  final ApiClient _api;

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
          'channel': channel.name, // 'sms' ou 'email'
        },
      );
    } on DioException catch (e) {
      throw _mapError(e);
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
      // Persiste le token JWT pour les requêtes suivantes.
      await _api.saveToken(session.token);
      return session;
    } on DioException catch (e) {
      throw _mapError(e);
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

  // ── currentUser ──────────────────────────────────────────────────────────

  @override
  Future<User?> currentUser() async {
    final token = await _api.readToken();
    if (token == null) return null;
    try {
      final res = await _client.get<Map<String, dynamic>>('/auth/me');
      return User.fromJson(res.data!);
    } on DioException catch (e) {
      // Token invalide ou expiré : on nettoie et on déconnecte.
      if (e.response?.statusCode == 401) {
        await _api.deleteToken();
        return null;
      }
      throw _mapError(e);
    }
  }

  // ── updateProfile ────────────────────────────────────────────────────────

  @override
  Future<User> updateProfile({
    UserTitle? title,
    String? fullName,
    String? branchId,
    UserStatus? status,
  }) async {
    try {
      final res = await _client.put<Map<String, dynamic>>(
        '/auth/profile',
        data: {
          if (title != null) 'title': title.name,
          if (fullName != null) 'fullName': fullName,
          if (branchId != null) 'branchId': branchId,
          if (status != null) 'status': status.name,
        },
      );
      return User.fromJson(res.data!);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ── signOut ──────────────────────────────────────────────────────────────

  @override
  Future<void> signOut() async {
    try {
      await _client.post<void>('/auth/sign-out');
    } on DioException catch (_) {
      // On ignore les erreurs réseau à la déconnexion : le token local
      // est supprimé dans tous les cas.
    } finally {
      await _api.deleteToken();
    }
  }

  // ── error mapping ────────────────────────────────────────────────────────

  /// Mappe les réponses d'erreur du backend vers les [AuthErrorCode] connus.
  ///
  /// Convention backend attendue :
  /// - 400 + body `{ "error": "invalid_code" | "expired_code" | "too_many_attempts" }`
  /// - 401 → invalide / expiré
  /// - Timeout / pas de réseau → `network`
  AuthException _mapError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return AuthException(
        AuthErrorCode.network,
        'Impossible de joindre le serveur (${e.message})',
      );
    }

    final status = e.response?.statusCode;
    final body = e.response?.data;

    if (status == 401) {
      return AuthException(AuthErrorCode.invalidCode, 'Session expirée');
    }

    if (status == 400 && body is Map) {
      final code = body['error'] as String?;
      return switch (code) {
        'invalid_code' => AuthException(AuthErrorCode.invalidCode),
        'expired_code' => AuthException(AuthErrorCode.expiredCode),
        'too_many_attempts' => AuthException(AuthErrorCode.tooManyAttempts),
        _ => AuthException(AuthErrorCode.unknown, body.toString()),
      };
    }

    if (status == 429) {
      return AuthException(AuthErrorCode.tooManyAttempts);
    }

    return AuthException(AuthErrorCode.unknown, e.message);
  }
}
