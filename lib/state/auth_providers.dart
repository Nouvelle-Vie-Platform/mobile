import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/branch_repository.dart';
import '../data/repositories/http_auth_repository.dart';
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
  (ref) => AppEnv.useBackend ? HttpAuthRepository() : InMemoryAuthRepository(),
);

/// Fournit l'implémentation courante de [BranchRepository] — mêmes règles que
/// [authRepositoryProvider] : HTTP avec backend, mock sinon.
final branchRepositoryProvider = Provider<BranchRepository>(
  (ref) => AppEnv.useBackend
      ? HttpBranchRepository()
      : const InMemoryBranchRepository(),
);

/// Référentiel des branches, **servi par le serveur** (`GET /sync/branches`).
///
/// Asynchrone à dessein : l'appel est authentifié et peut échouer. Les écrans
/// consomment l'[AsyncValue] et **dégradent** — chargement, erreur ou liste
/// vide laissent le formulaire de profil utilisable, l'option « Je suis
/// nouveau » ne dépendant d'aucun référentiel.
final branchesProvider = FutureProvider<List<Branch>>(
  (ref) => ref.watch(branchRepositoryProvider).branches(),
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

  /// Démarrage **non bloquant** : le cache local décide de la route, le réseau
  /// ne fait que corriger ensuite.
  ///
  /// L'ordre compte. Lire le cache d'abord, c'est afficher l'accueil en
  /// quelques millisecondes plutôt qu'après un aller-retour HTTP — sensible sur
  /// une connexion lente, et seule façon d'ouvrir l'app hors ligne.
  Future<void> _load() async {
    final cached = await _repo.cachedUser();
    if (cached != null) {
      state = AuthState(status: AuthStatus.authenticated, user: cached);
    }
    await _revalidate(settleOnFailure: cached == null);
  }

  /// Revalidation `GET /auth/me`, en arrière-plan quand le cache a déjà routé.
  ///
  /// [settleOnFailure] : sans cache, l'état est encore `unknown` et le splash
  /// tourne indéfiniment si le réseau échoue — il faut alors trancher pour
  /// « déconnecté » (l'écran d'auth, lui, s'ouvre sans réseau). Avec un cache,
  /// au contraire, une panne réseau ne doit rien changer.
  Future<void> _revalidate({required bool settleOnFailure}) async {
    try {
      final fresh = await _repo.currentUser();
      if (fresh == null) {
        // Plus de token, ou token refusé (401) : `ApiClient` a déjà purgé le
        // token et prévenu [handleUnauthorized] ; on converge ici de toute
        // façon, y compris quand le 401 tombe sur un démarrage à froid.
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      if (!_sameUser(state.user, fresh)) {
        state = AuthState(status: AuthStatus.authenticated, user: fresh);
      }
    } on Exception catch (_) {
      // Serveur injoignable : on garde les données locales. Une coupure réseau
      // n'est pas une déconnexion — le token reste valide 90 jours glissants.
      if (settleOnFailure) {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    }
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
    String? firstName,
    String? lastName,
    int? branchId,
    UserStatus? status,
  }) async {
    final user = await _repo.updateProfile(
      title: title,
      firstName: firstName,
      lastName: lastName,
      branchId: branchId,
      status: status,
    );
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  /// Applique le **résumé d'acceptation** que vient de rendre
  /// `POST /legal/accept` (#56).
  ///
  /// C'est ici que la barrière se lève, et **nulle part ailleurs** : l'écran ne
  /// navigue pas, il ne se ferme pas lui-même. L'état change, le `redirect` se
  /// réévalue et retire l'écran — le motif déjà suivi par la déconnexion, à
  /// l'envers.
  ///
  /// Le cache local suit ([AuthRepository.rememberUser]) : sans lui, le
  /// prochain démarrage hors ligne rouvrirait une barrière que le réseau seul
  /// peut refermer.
  ///
  /// Sans utilisateur connecté, il n'y a rien à appliquer : la garde a déjà
  /// renvoyé vers `/auth`.
  Future<void> applyAcceptedLegal(Map<String, int> accepted) async {
    final current = state.user;
    if (current == null) return;
    final updated = current.withAcceptedLegal(accepted);
    await _repo.rememberUser(updated);
    state = AuthState(status: AuthStatus.authenticated, user: updated);
  }

  /// Session invalidée par le serveur (**401** sur n'importe quel appel).
  ///
  /// Branché sur `ApiClient.onUnauthorized` au démarrage de l'app. Le token a
  /// déjà été purgé par [ApiClient] ; reste le **cache local**, qui vit
  /// derrière le repository et que la couche réseau ne connaît pas : le
  /// laisser en place ferait rentrer l'utilisateur suivant dans l'app avec le
  /// profil de l'ancien. Pas d'appel réseau — le token étant refusé,
  /// `signOut()` le serait aussi.
  ///
  /// L'état repasse ensuite à « déconnecté », dont la garde `redirect` du
  /// routeur déduit le retour à `/auth`, y compris depuis un démarrage à froid
  /// où c'est la revalidation de fond qui a pris le 401.
  void handleUnauthorized() {
    unawaited(_repo.forgetSession());
    if (state.status == AuthStatus.unauthenticated) return;
    state = const AuthState(status: AuthStatus.unauthenticated);
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

/// Deux `User` décrivent-ils la même chose ?
///
/// [User] n'a pas d'`==` de valeur : sans cette comparaison, la revalidation de
/// fond republierait un état identique à chaque démarrage et ferait rebâtir
/// tous les écrans qui l'observent pour rien. La comparaison passe par le JSON,
/// qui est déjà la forme canonique du modèle (et celle du cache).
///
/// **`acceptedLegal` se compare à part**, et l'oublier annulerait le paragraphe
/// ci-dessus : `mapEquals` est *superficiel*, deux cartes de même contenu mais
/// d'instances différentes n'y sont pas égales, et chaque revalidation
/// republierait donc un état identique — y compris jusqu'à la garde de route.
bool _sameUser(User? a, User? b) {
  if (a == null || b == null) return a == b;
  if (!mapEquals(a.acceptedLegal, b.acceptedLegal)) return false;
  final left = a.toJson()..remove('acceptedLegal');
  final right = b.toJson()..remove('acceptedLegal');
  return mapEquals(left, right);
}
