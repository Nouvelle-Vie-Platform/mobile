import '../../models/models.dart';
import '../sample_data.dart';

/// Codes d'erreur d'authentification (voir docs/auth-contract.md).
enum AuthErrorCode {
  invalidCode,
  expiredCode,
  tooManyAttempts,
  network,
  unknown
}

/// Exception levée par [AuthRepository] en cas d'échec métier.
class AuthException implements Exception {
  AuthException(this.code, [this.message]);

  final AuthErrorCode code;
  final String? message;

  @override
  String toString() =>
      'AuthException(${code.name}${message == null ? '' : ': $message'})';
}

/// Contrat d'authentification — **source de vérité définie par le front**.
///
/// Pour brancher un vrai backend (phase B), il suffira de fournir une autre
/// implémentation via `authRepositoryProvider` — aucun écran ne change.
abstract interface class AuthRepository {
  /// Envoie un code à 4 chiffres sur le canal choisi.
  /// [identifier] : téléphone E.164 (ex. « +22890123456 ») ou email.
  Future<void> requestCode({
    required String identifier,
    required IdentifierChannel channel,
  });

  /// Vérifie le code. Réussite → session (token + user + isNewUser).
  /// Échec → [AuthException] (invalidCode | expiredCode | tooManyAttempts).
  Future<Session> verifyCode({
    required String identifier,
    required String code,
  });

  /// Connexion sociale : saute l'étape code. `isNewUser` possible = true.
  Future<Session> signInWithGoogle();
  Future<Session> signInWithApple();

  /// Complète / met à jour le profil (nécessite un token). Facultatif.
  Future<User> updateProfile({
    UserTitle? title,
    String? fullName,
    String? branchId, // null = « Je suis nouveau »
    UserStatus? status,
  });

  /// Utilisateur courant depuis le token stocké (`null` si déconnecté).
  Future<User?> currentUser();

  Future<void> signOut();
}

/// Implémentation factice (phase C) : **aucun réseau, aucun plugin**.
///
/// Session en mémoire seule (pas de persistance) : redémarrer l'app déconnecte.
/// Code magique **`0000`** = succès ; tout autre = [AuthErrorCode.invalidCode].
class InMemoryAuthRepository implements AuthRepository {
  User? _user;

  static const _delay = Duration(milliseconds: 600);
  static const _lookup = Duration(milliseconds: 300);

  /// Identifiant déterministe (pas de `Random`) dérivé de l'identifiant saisi.
  static String _idFor(String identifier) =>
      'u_${identifier.hashCode.toUnsigned(32).toRadixString(16)}';

  static bool _isEmail(String identifier) => identifier.contains('@');

  @override
  Future<void> requestCode({
    required String identifier,
    required IdentifierChannel channel,
  }) async {
    // Aucun effet : on simule seulement l'aller-retour réseau.
    await Future<void>.delayed(_delay);
  }

  @override
  Future<Session> verifyCode({
    required String identifier,
    required String code,
  }) async {
    await Future<void>.delayed(_delay);
    if (code != '0000') {
      throw AuthException(AuthErrorCode.invalidCode);
    }
    final trimmed = identifier.trim();
    final isKnown = SampleData.knownIdentifiers.contains(trimmed.toLowerCase());
    final isNewUser = !isKnown;
    final isEmail = _isEmail(trimmed);
    final user = User(
      id: _idFor(trimmed),
      phone: isEmail ? null : trimmed,
      email: isEmail ? trimmed.toLowerCase() : null,
      status: UserStatus.nouveau,
      // Un utilisateur déjà connu est considéré comme profil complet
      // (pas de bannière) ; un nouveau doit compléter son profil.
      profileComplete: isKnown,
    );
    _user = user;
    return Session(
      token: 'mock-token-${user.id}',
      user: user,
      isNewUser: isNewUser,
    );
  }

  @override
  Future<Session> signInWithGoogle() => _social('u_google');

  @override
  Future<Session> signInWithApple() => _social('u_apple');

  Future<Session> _social(String id) async {
    await Future<void>.delayed(_delay);
    final user = User(
      id: id,
      status: UserStatus.nouveau,
      profileComplete: false,
    );
    _user = user;
    return Session(token: 'mock-token-$id', user: user, isNewUser: true);
  }

  @override
  Future<User> updateProfile({
    UserTitle? title,
    String? fullName,
    String? branchId,
    UserStatus? status,
  }) async {
    await Future<void>.delayed(_lookup);
    final current = _user;
    if (current == null) {
      throw AuthException(AuthErrorCode.unknown, 'Aucun utilisateur connecté');
    }
    final resolvedTitle = title ?? current.title;
    final resolvedName = fullName ?? current.fullName;
    final resolvedStatus = status ?? current.status;
    final complete = resolvedTitle != null &&
        (resolvedName != null && resolvedName.trim().isNotEmpty) &&
        (branchId != null || resolvedStatus == UserStatus.nouveau);
    final updated = User(
      id: current.id,
      phone: current.phone,
      email: current.email,
      title: resolvedTitle,
      fullName: resolvedName,
      branchId: branchId, // null = « Je suis nouveau »
      status: resolvedStatus,
      avatarUrl: current.avatarUrl,
      profileComplete: complete,
    );
    _user = updated;
    return updated;
  }

  @override
  Future<User?> currentUser() async {
    // Léger délai : simule la vérification du token stocké.
    await Future<void>.delayed(_lookup);
    return _user;
  }

  @override
  Future<void> signOut() async {
    await Future<void>.delayed(_lookup);
    _user = null;
  }
}
