import '../../models/legal_document_view.dart';
import '../../models/models.dart';
import '../sample_data.dart';

/// Codes d'erreur d'authentification (voir docs/auth-contract.md).
///
/// Il n'y a **pas** de `expiredCode` : le serveur fusionne délibérément
/// « invalide » et « expiré » dans une réponse générique, pour ne pas
/// renseigner un attaquant sur l'état d'un code.
enum AuthErrorCode { invalidCode, tooManyAttempts, network, unknown }

/// Exception levée par [AuthRepository] en cas d'échec métier.
class AuthException implements Exception {
  AuthException(this.code, [this.message, this.retryAfter]);

  final AuthErrorCode code;

  /// Message **déjà localisé par le serveur** (fr / en selon l'en-tête de
  /// langue). À n'afficher que pour les codes sans libellé propre côté app
  /// ([AuthErrorCode.unknown]) : les autres passent par `context.l10n`.
  final String? message;

  /// Délai avant de pouvoir réessayer, tel qu'annoncé par le serveur sur un
  /// **429** (corps `retryAfter`, en secondes, ou en-tête `Retry-After`).
  ///
  /// `null` quand le serveur ne l'a pas dit — l'UI retombe alors sur son
  /// cooldown par défaut. Le serveur connaît la seconde exacte ; l'app ne doit
  /// jamais la deviner quand elle est disponible.
  final Duration? retryAfter;

  @override
  String toString() => 'AuthException(${code.name}'
      '${message == null ? '' : ': $message'}'
      '${retryAfter == null ? '' : ' [retryAfter: ${retryAfter!.inSeconds}s]'})';
}

/// Contrat d'authentification — **source de vérité définie par le front**.
///
/// Pour brancher un vrai backend (phase B), il suffira de fournir une autre
/// implémentation via `authRepositoryProvider` — aucun écran ne change.
abstract interface class AuthRepository {
  /// Envoie un code à **6 chiffres** sur le canal choisi.
  /// [identifier] : téléphone E.164 (ex. « +22890123456 ») ou email.
  Future<void> requestCode({
    required String identifier,
    required IdentifierChannel channel,
  });

  /// Vérifie le code. Réussite → session (token + user + isNewUser).
  /// Échec → [AuthException] (invalidCode | tooManyAttempts).
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
    String? firstName,
    String? lastName,
    int? branchId, // null + status newcomer = « Je suis nouveau »
    UserStatus? status,
  });

  /// Utilisateur en **cache local**, sans le moindre accès réseau.
  ///
  /// C'est ce que lit le splash pour router **immédiatement** : `null` = on n'a
  /// rien à afficher, sinon on entre dans l'app avec ces données (mode avion
  /// compris) pendant que [currentUser] revalide en arrière-plan.
  ///
  /// Le *où* de cette persistance est un détail d'implémentation du
  /// repository — coffre sécurisé aujourd'hui, ObjectBox au jalon synchro.
  /// Aucun écran ne doit le savoir.
  Future<User?> cachedUser();

  /// Utilisateur courant **revalidé auprès du serveur** (`GET /auth/me`), et
  /// cache local rafraîchi au passage. `null` = plus de session (pas de token,
  /// ou token refusé).
  ///
  /// Peut lever si le serveur est injoignable : l'appelant garde alors ce que
  /// [cachedUser] lui avait donné.
  Future<User?> currentUser();

  /// Réécrit le **cache local** avec cet utilisateur, sans rien demander au
  /// serveur.
  ///
  /// Une seule chose l'appelle, et une seule doit l'appeler : l'acceptation des
  /// documents légaux (#56). `POST /legal/accept` rend le résumé à jour ; s'il
  /// ne descendait pas jusqu'au cache, le prochain démarrage **hors ligne**
  /// rouvrirait la barrière à quelqu'un qui vient d'accepter — et il ne pourrait
  /// pas la refermer, l'accord exigeant le réseau (ADR-0036, décision 2).
  ///
  /// Ce n'est pas une porte d'écriture générale : rien d'autre que ce que le
  /// serveur vient de dire ne doit passer par là.
  Future<void> rememberUser(User user);

  /// Oublie la session **localement** — token et cache — sans appeler le
  /// serveur.
  ///
  /// Sert quand le serveur a déjà invalidé le token (**401**) : le rappeler
  /// serait refusé de la même façon. À ne pas confondre avec [signOut], qui
  /// révoque côté serveur.
  Future<void> forgetSession();

  Future<void> signOut();

  /// **Supprime définitivement le compte** (`DELETE /auth/me`).
  ///
  /// Exigence d'entrée à l'App Store (règle 5.1.1(v)) : une application qui
  /// permet de créer un compte doit permettre de le supprimer **depuis
  /// l'application**. Le Bearer désigne le compte — il n'existe aucune forme de
  /// cette requête qui puisse en désigner un autre.
  ///
  /// Rend la main **sans avoir rien effacé localement** : c'est l'appelant qui
  /// enchaîne, parce que l'effacement local ne concerne pas que la session (le
  /// magasin Drift porte la progression d'écoute du fidèle). Voir
  /// `AuthNotifier.deleteAccount`.
  ///
  /// **Un `401` compte comme un succès.** Le serveur révoque tous les tokens
  /// dans la transaction de suppression : un second appel — ou un appel dont le
  /// token venait d'expirer — reçoit `401` et il n'existe pas d'état
  /// « déjà supprimé » à distinguer. Dans les deux cas il n'y a plus de session,
  /// et effacer localement est la bonne suite.
  ///
  /// Lève en revanche sur une panne réseau ou un `5xx` : le compte est alors
  /// **toujours vivant**, et effacer le téléphone laisserait quelqu'un
  /// convaincu d'avoir disparu alors que son compte existe encore.
  Future<void> deleteAccount();
}

/// Implémentation factice (phase C) : **aucun réseau, aucun plugin**.
///
/// Session en mémoire seule (pas de persistance) : redémarrer l'app déconnecte.
/// Code magique [magicCode] = succès ; tout autre = [AuthErrorCode.invalidCode].
class InMemoryAuthRepository implements AuthRepository {
  User? _user;

  /// Code magique de la démo, à **6 chiffres** comme celui du serveur
  /// (contrat v2, décision 8). Le mock doit se tromper de la même façon que la
  /// production : accepter 4 chiffres ferait passer pour valide une saisie que
  /// le backend rejetterait.
  static const String magicCode = '000000';

  static const _delay = Duration(milliseconds: 600);
  static const _lookup = Duration(milliseconds: 300);

  /// Identifiant déterministe (pas de `Random`) dérivé de l'identifiant saisi.
  static String _idFor(String identifier) =>
      'u_${identifier.hashCode.toUnsigned(32).toRadixString(16)}';

  static bool _isEmail(String identifier) => identifier.contains('@');

  /// Ce que le fidèle de la **maquette** a déjà accepté.
  ///
  /// Le mode maquette n'a pas de serveur, donc aucun `POST /legal/accept` ne
  /// peut y aboutir : un utilisateur factice sans acceptation se retrouverait
  /// devant une barrière qu'**aucun geste ne peut lever** (ADR-0036,
  /// décision 2 — l'accord exige le réseau). Il est donc à jour.
  ///
  /// Calculé depuis `SampleData` plutôt que recopié : ajouter un document
  /// fictif ou bousculer son plancher ne doit pas éteindre la maquette en
  /// silence.
  static Map<String, int> get _acceptedLegal => {
        for (final document in SampleData.legalDocuments)
          if (LegalDocumentKind.acceptable.contains(document.kind) &&
              document.lastMandatoryVersion != null)
            document.kind: document.version,
      };

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
    if (code != magicCode) {
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
      status: UserStatus.newcomer,
      // Un utilisateur déjà connu est considéré comme profil complet
      // (pas de bannière) ; un nouveau doit compléter son profil.
      profileComplete: isKnown,
      acceptedLegal: _acceptedLegal,
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
      status: UserStatus.newcomer,
      profileComplete: false,
      acceptedLegal: _acceptedLegal,
    );
    _user = user;
    return Session(token: 'mock-token-$id', user: user, isNewUser: true);
  }

  @override
  Future<User> updateProfile({
    UserTitle? title,
    String? firstName,
    String? lastName,
    int? branchId,
    UserStatus? status,
  }) async {
    await Future<void>.delayed(_lookup);
    final current = _user;
    if (current == null) {
      throw AuthException(AuthErrorCode.unknown, 'Aucun utilisateur connecté');
    }
    final resolvedTitle = title ?? current.title;
    final resolvedFirstName = firstName ?? current.firstName;
    final resolvedLastName = lastName ?? current.lastName;
    final resolvedStatus = status ?? current.status;
    final complete = resolvedTitle != null &&
        (resolvedFirstName != null && resolvedFirstName.trim().isNotEmpty) &&
        (branchId != null || resolvedStatus == UserStatus.newcomer);
    final updated = User(
      id: current.id,
      phone: current.phone,
      email: current.email,
      title: resolvedTitle,
      firstName: resolvedFirstName,
      lastName: resolvedLastName,
      branchId: branchId, // null = « Je suis nouveau »
      status: resolvedStatus,
      avatarUrl: current.avatarUrl,
      profileComplete: complete,
      acceptedLegal: current.acceptedLegal,
    );
    _user = updated;
    return updated;
  }

  /// Le mock n'a pas de persistance : sa « session en cache » est la session
  /// en mémoire. Redémarrer l'app déconnecte, comme avant.
  @override
  Future<User?> cachedUser() async => _user;

  @override
  Future<void> rememberUser(User user) async {
    _user = user;
  }

  @override
  Future<User?> currentUser() async {
    // Léger délai : simule la vérification du token stocké.
    await Future<void>.delayed(_lookup);
    return _user;
  }

  @override
  Future<void> forgetSession() async {
    _user = null;
  }

  @override
  Future<void> signOut() async {
    await Future<void>.delayed(_lookup);
    _user = null;
  }

  /// En maquette, supprimer revient à oublier : il n'y a ni serveur à prévenir
  /// ni donnée persistée à reprendre. Le double **réussit** plutôt que de lever
  /// — l'écran de suppression doit pouvoir se parcourir sans backend.
  @override
  Future<void> deleteAccount() async {
    await Future<void>.delayed(_lookup);
    _user = null;
  }
}
