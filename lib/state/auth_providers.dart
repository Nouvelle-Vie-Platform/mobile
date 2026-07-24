import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/http_auth_repository.dart';
import '../data/sample_data.dart';
import '../models/models.dart';

/// Fournit l'implémentation courante de [AuthRepository].
///
/// - [AppEnv.useBackend] == true  → [HttpAuthRepository] (backend local)
/// - [AppEnv.useBackend] == false → [InMemoryAuthRepository] (mock)
///
/// Pour brancher un vrai backend (phase B), on surchargera ce provider avec une
/// autre implémentation — aucun écran ne change (même pattern que
/// `churchRepositoryProvider`).
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AppEnv.useBackend
      ? HttpAuthRepository()
      : InMemoryAuthRepository(),
);

/// Branches locales sélectionnables (liste statique en phase mock).
final branchesProvider = Provider<List<Branch>>(
  (ref) => SampleData.branches,
);

/// État global d'authentification.
enum AuthStatus {
  /// Init en cours (session pas encore résolue) → on reste sur le splash.
  unknown,

  /// Aucun utilisateur connecté.
  unauthenticated,

  /// Utilisateur connecté ([AuthState.user] non nul).
  authenticated,
}

/// Instantané de l'état d'authentification, exposé par [authProvider].
class AuthState {
  const AuthState({required this.status, this.user});

  final AuthStatus status;
  final User? user;

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

/// Contrôleur d'authentification : orchestre [AuthRepository] et publie
/// l'[AuthState] consommé par les écrans et les gardes du routeur.
class AuthController extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    // Résolution asynchrone de la session existante ; l'état part de `unknown`.
    unawaited(_load());
    return const AuthState(status: AuthStatus.unknown);
  }

  Future<void> _load() async {
    final user = await _repo.currentUser();
    state = user == null
        ? const AuthState(status: AuthStatus.unauthenticated)
        : AuthState(status: AuthStatus.authenticated, user: user);
  }

  /// Demande l'envoi d'un code sur le canal choisi.
  Future<void> requestCode({
    required String identifier,
    required IdentifierChannel channel,
  }) {
    return _repo.requestCode(identifier: identifier, channel: channel);
  }

  /// Vérifie le code ; en cas de succès passe à `authenticated` et **retourne
  /// la [Session]** (l'écran lit `isNewUser` pour router vers profil/accueil).
  Future<Session> verifyCode({
    required String identifier,
    required String code,
  }) async {
    final session = await _repo.verifyCode(identifier: identifier, code: code);
    state = AuthState(status: AuthStatus.authenticated, user: session.user);
    return session;
  }

  /// Connexion Google (saute l'étape code). Retourne la [Session].
  Future<Session> signInWithGoogle() async {
    final session = await _repo.signInWithGoogle();
    state = AuthState(status: AuthStatus.authenticated, user: session.user);
    return session;
  }

  /// Connexion Apple (saute l'étape code). Retourne la [Session].
  Future<Session> signInWithApple() async {
    final session = await _repo.signInWithApple();
    state = AuthState(status: AuthStatus.authenticated, user: session.user);
    return session;
  }

  /// Met à jour le profil de l'utilisateur courant.
  Future<void> updateProfile({
    UserTitle? title,
    String? fullName,
    String? branchId,
    UserStatus? status,
  }) async {
    final user = await _repo.updateProfile(
      title: title,
      fullName: fullName,
      branchId: branchId,
      status: status,
    );
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  /// Déconnecte l'utilisateur.
  Future<void> signOut() async {
    await _repo.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

/// État d'authentification partagé à l'échelle de l'application.
final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
