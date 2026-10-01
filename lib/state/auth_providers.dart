import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_env.dart';
import '../data/local/app_database.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/branch_repository.dart';
import '../data/repositories/http_auth_repository.dart';
import '../data/repositories/playback_progress_handover.dart';
import '../models/models.dart';
import 'branch_scope_providers.dart';
import 'playback_progress_providers.dart';
import 'push_providers.dart';
import 'startup_providers.dart';
import 'sync_providers.dart';

/// Fournit l'implémentation courante de [AuthRepository].
///
/// - [AppEnv.useBackend] == true  → [HttpAuthRepository] (backend local)
/// - [AppEnv.useBackend] == false → [InMemoryAuthRepository] (mock)
///
/// Pour brancher un vrai backend (phase B), on surchargera ce provider avec une
/// autre implémentation — aucun écran ne change (même pattern que
/// `churchRepositoryProvider`).
///
/// Le **porteur d'appareil** lui est passé quand il y en a un (`main()` l'a
/// câblé) : c'est ce qui fait qu'une déconnexion **reprend** un jeton d'appareil
/// au lieu de laisser le coffre vide, donc qu'un invité qui vient de se
/// déconnecter retombe sur le catalogue et non sur l'écran de connexion. Le
/// paramètre est facultatif — `null` = pas de mode invité câblé, et
/// `HttpAuthRepository` se comporte alors exactement comme avant.
/// La **cible de réveil** lui est passée par un rappel, pour la même raison que le
/// porteur d'appareil lui est passé tout court : `POST /auth/sign-out` doit désabonner
/// cet appareil-ci des notifications du compte qui part, sinon le membre suivant d'un
/// téléphone prêté verrait passer celles du précédent (#97). Un rappel et non une
/// valeur — l'enregistrement part au premier frame, après la construction d'ici.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (!AppEnv.useBackend) return InMemoryAuthRepository();
  return HttpAuthRepository(
    device: ref.watch(deviceBootstrapProvider).repository,
    pushTarget: () => ref.read(pushEnrolmentProvider).target,
  );
});

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

/// **Ce qui ramène la progression du compte avant une fusion**, et dit si c'est
/// frais.
///
/// Un cycle de synchronisation, et il doit être **entièrement postérieur au
/// remplacement du jeton**. Un cycle déjà en vol a pu partir avec le jeton
/// d'appareil : son manifeste décrit alors le périmètre d'un invité, où la
/// collection `private` est vide — conclure « le compte ne sait rien » sur ce
/// manifeste-là ferait pousser des positions en retard, c'est-à-dire reculer la
/// reprise du membre. On attend donc celui qui tourne, puis on en demande un qui
/// soit à nous.
///
/// Le booléen rendu est ce que `SyncScheduler` sait dire : `null` = cycle échoué
/// (voir `SyncScheduler.lastFailure`). Sans backend, jamais frais — il n'y a pas
/// de compte, et lire le planificateur ouvrirait une base Drift pour rien.
///
/// Provider séparé pour une seule raison : c'est le seul moyen qu'un test
/// exerce la fusion **entière** — vraie base, vrai DAO, vraie règle — sans ouvrir
/// de socket.
final accountProgressPullProvider = Provider<Future<bool> Function()>((ref) {
  if (!AppEnv.useBackend) return () async => false;
  return () async {
    final scheduler = ref.read(syncSchedulerProvider);
    if (scheduler.isRunning) await scheduler.refresh();
    return await scheduler.refresh() != null;
  };
});

/// **La fusion de la progression**, telle que l'ouverture de session l'appelle.
///
/// Inerte sans backend : pas de compte, donc rien à transférer (et aucune base
/// ouverte, aucune minuterie de Dio laissée derrière).
///
/// Il vit dans ce fichier-ci et non dans `playback_progress_providers.dart`
/// parce que son seul appelant est l'ouverture d'une session de membre, juste
/// en dessous ; le déplacer plus tard ne coûterait qu'un import.
final playbackProgressHandoverProvider = Provider<PlaybackProgressHandover>(
  (ref) {
    if (!AppEnv.useBackend) return const InertPlaybackProgressHandover();
    return StorePlaybackProgressHandover(
      dao: ref.watch(playbackDaoProvider),
      reporter: ref.watch(playbackProgressReporterProvider),
      pullAccountProgress: ref.watch(accountProgressPullProvider),
    );
  },
);

/// État global d'authentification.
///
/// **`unauthenticated` a été remplacé par [guest], et ce n'est pas un renommage
/// de confort.** L'ancien nom disait « personne n'est connecté » et le routeur
/// en déduisait « donc rien n'est permis » : tout était réécrit vers `/auth`.
/// Sous le mode invité, cet état-là n'existe plus — il n'y a plus de situation
/// où l'absence de compte ferme l'application. Renommer plutôt qu'ajouter met
/// **le compilateur** sur chaque `switch` et chaque comparaison qui supposait
/// l'ancien sens : aucun site ne peut survivre à la bascule sans avoir été relu.
///
/// Ce que ça rend impossible : traiter « invité » comme un cas particulier
/// d'« utilisateur absent » dans un coin du code, et écrire un `if (!isAuthenticated)`
/// qui veut dire « envoie-le se connecter ».
enum AuthStatus {
  /// Init en cours (session pas encore résolue) → on reste sur le splash.
  ///
  /// **Cet état ne se produit plus quand le coffre ne porte pas de session de
  /// membre** : `main()` a lu le coffre avant le premier frame
  /// ([StartupVault]), et l'état part alors directement de [guest]. C'est ce
  /// qui supprime l'écran d'attente du premier lancement.
  unknown,

  /// **Invité** : aucune session de membre, et l'application s'utilise.
  ///
  /// Ce n'est ni une erreur, ni un état transitoire, ni une antichambre de la
  /// connexion : c'est le régime normal de quelqu'un qui n'a pas de compte, et
  /// [AuthState.user] y est nul pour de bon. Ce qui exige un compte se demande
  /// au moment du geste (`requireSession`), jamais à l'entrée.
  guest,

  /// Utilisateur connecté ([AuthState.user] non nul).
  authenticated,
}

/// Instantané de l'état d'authentification, exposé par [authProvider].
class AuthState {
  const AuthState({required this.status, this.user});

  /// L'invité, écrit une fois : il n'y a rien à y paramétrer, et un
  /// `AuthState(status: AuthStatus.guest, user: quelqu'un)` serait un mensonge.
  static const AuthState guest = AuthState(status: AuthStatus.guest);

  /// Le démarrage à résoudre.
  static const AuthState unknown = AuthState(status: AuthStatus.unknown);

  final AuthStatus status;
  final User? user;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// Un invité — à ne pas dériver de `!isAuthenticated`, qui est **aussi** vrai
  /// pendant la résolution du démarrage.
  bool get isGuest => status == AuthStatus.guest;
}

/// Contrôleur d'authentification : orchestre [AuthRepository] et publie
/// l'[AuthState] consommé par les écrans et les gardes du routeur.
class AuthController extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Lu **paresseusement**, jamais observé : seule la suppression de compte en
  /// a besoin, et `ref.watch` ferait dépendre tout l'état d'authentification du
  /// magasin — donc ouvrirait la base au démarrage, avant même de savoir s'il y
  /// a une session (Drift n'ouvre qu'à la première requête).
  AppDatabase get _database => ref.read(appDatabaseProvider);

  @override
  AuthState build() {
    // **Le splash n'existe que s'il y a une session de membre à attendre.**
    //
    // `main()` a lu le coffre avant le premier frame : rien dedans — ou un jeton
    // d'appareil seul — et il n'y a rien à résoudre, donc rien à faire attendre.
    // L'état part alors d'`invité`, le routeur envoie `/` sur l'accueil à la
    // **première** évaluation de sa garde, et l'écran d'attente ne se peint pas
    // du tout. Avec une session de membre (ou un coffre qu'on n'a pas lu, ce qui
    // est le cas sous `flutter test`), on repart de `unknown` : splash bref puis
    // résolution, exactement comme avant le mode invité.
    final vault = ref.watch(startupVaultProvider);
    final hasMemberSession = vault != StartupVault.noMemberSession;
    unawaited(_load(hasMemberSession: hasMemberSession));
    return hasMemberSession ? AuthState.unknown : AuthState.guest;
  }

  /// Démarrage **non bloquant** : le cache local décide de la route, le réseau
  /// ne fait que corriger ensuite.
  ///
  /// L'ordre compte. Lire le cache d'abord, c'est afficher l'accueil en
  /// quelques millisecondes plutôt qu'après un aller-retour HTTP — sensible sur
  /// une connexion lente, et seule façon d'ouvrir l'app hors ligne.
  Future<void> _load({required bool hasMemberSession}) async {
    final cached = await _repo.cachedUser();
    if (cached != null) {
      state = AuthState(status: AuthStatus.authenticated, user: cached);
    } else if (!hasMemberSession) {
      // **Rien à revalider.** Le coffre ne porte pas de session de membre, on
      // est déjà invité, et `GET /auth/me` partirait avec un jeton d'appareil
      // pour se faire refuser — un 401, un renouvellement silencieux et un rejeu
      // à chaque ouverture, pour apprendre ce qu'on savait déjà.
      return;
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
        state = AuthState.guest;
        return;
      }
      if (!_sameUser(state.user, fresh)) {
        state = AuthState(status: AuthStatus.authenticated, user: fresh);
      }
    } on Exception catch (_) {
      // Serveur injoignable : on garde les données locales. Une coupure réseau
      // n'est pas une déconnexion — le token reste valide 90 jours glissants.
      if (settleOnFailure) {
        state = AuthState.guest;
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
    return _openMemberSession(session);
  }

  /// Connexion Google (saute l'étape code). Retourne la [Session].
  Future<Session> signInWithGoogle() async {
    return _openMemberSession(await _repo.signInWithGoogle());
  }

  /// Connexion Apple (saute l'étape code). Retourne la [Session].
  Future<Session> signInWithApple() async {
    return _openMemberSession(await _repo.signInWithApple());
  }

  /// **Une session de membre vient de s'ouvrir** — les trois voies confondues :
  /// code par SMS/e-mail, Google, Apple.
  ///
  /// Un seul endroit, et c'est le point de la méthode. Trois voies et deux
  /// endroits qui réagissent, c'est une divergence annoncée : le jour où Google
  /// et Apple cessent de lever `UnimplementedError`, il n'y aura rien à
  /// rebrancher. C'est le pendant de ce que la tranche du porteur d'appareil a
  /// fait pour le jeton — un seul emplacement dans le coffre, un seul
  /// remplacement.
  ///
  /// **L'état passe d'abord**, et l'adoption part ensuite sans être attendue :
  /// quelqu'un qui se connecte doit entrer. Ce qui suit est une commodité qui
  /// parle au réseau (un cycle de synchronisation, des poussées de progression) ;
  /// l'attendre ferait dépendre l'entrée dans l'application d'une 3G togolaise,
  /// et un échec ferait échouer une connexion réussie. Rien de tout ceci ne lève.
  Future<Session> _openMemberSession(Session session) async {
    state = AuthState(status: AuthStatus.authenticated, user: session.user);
    adoption = _adoptLocalTrail();
    return session;
  }

  /// **L'adoption en cours, exposée pour les tests seulement.**
  ///
  /// Elle n'est pas attendue par l'application — c'est tout le sujet de
  /// [_openMemberSession] —, et un test qui n'aurait aucun moyen de l'attendre
  /// devrait dormir un nombre de tours de boucle deviné. Aucun écran ne la lit.
  @visibleForTesting
  Future<void>? adoption;

  /// **Ce que cet appareil a accumulé sans compte rejoint le compte.** Deux
  /// gestes, muets tous les deux, et dans cet ordre.
  ///
  /// 1. **Le miroir de la préférence d'assemblée** (`hydrateFromAccount`) : un
  ///    appareil qui n'a jamais choisi adopte ce que le compte porte, un appareil
  ///    qui a choisi remonte son réglage si le compte n'en a pas. Idempotent,
  ///    muet, et il ne part **jamais** pour un invité — le miroir lit la nature
  ///    du porteur avant d'appeler. Il vient **en premier** parce qu'il peut
  ///    changer le filtre de branche, et donc ce que le cycle suivant tire.
  /// 2. **La fusion de la progression d'écoute** : voir
  ///    `playback_progress_handover.dart` pour la règle de conflit et pour qui
  ///    l'arbitre.
  ///
  /// Les deux échecs sont avalés **séparément** : une préférence d'assemblée qui
  /// ne se recopie pas n'a pas à emporter le transfert de la progression avec
  /// elle.
  ///
  /// **Un seul déclencheur, et c'est une décision assumée** : l'ouverture d'une
  /// session, et non le démarrage d'une session déjà en cache. La question se
  /// pose pour de bon — un transfert interrompu (application tuée, cycle de
  /// synchronisation échoué) attend donc la **prochaine** connexion, qui peut
  /// être dans trois mois, le jeton glissant sur quatre-vingt-dix jours. Deux
  /// raisons de ne pas l'accrocher aussi à [_load] :
  ///
  /// - **le prix serait payé par tout le monde pour un cas rare** : à chaque
  ///   ouverture de l'application, le miroir demanderait un `GET /auth/me` (en
  ///   plus de celui de la revalidation) et la fusion un cycle de
  ///   synchronisation, alors que la trace à transférer n'existe que sur un
  ///   appareil qui a servi **d'invité** puis s'est connecté ;
  /// - **le lecteur rattrape le cas fréquent tout seul** : un contenu qu'on
  ///   réouvre est rapporté au premier déclencheur de
  ///   `PlaybackProgressRecorder`, et la position qu'il rapporte est celle que la
  ///   fusion a laissée en local.
  ///
  /// Si le produit veut l'autre arbitrage, c'est un appel de plus dans [_load],
  /// après qu'une session de membre a été confirmée : la fusion est idempotente,
  /// sérialisée, et ne coûte pas un octet quand il n'y a rien en local.
  Future<void> _adoptLocalTrail() async {
    try {
      // `hydrateFromAccount` ne lève jamais ; ce `catch` couvre ce qui l'entoure
      // (un conteneur Riverpod déjà disposé, un magasin indisponible).
      await ref.read(branchScopeProvider).hydrateFromAccount();
    } on Object catch (error) {
      debugPrint('[branche] miroir de compte ignoré à la connexion : $error');
    }
    try {
      await ref.read(playbackProgressHandoverProvider).run();
    } on Object catch (error) {
      debugPrint('[progression] fusion ignorée à la connexion : $error');
    }
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
  /// L'état repasse à **invité**, mais la navigation, elle, **éjecte vers
  /// l'écran de connexion** — et c'est `app.dart` qui s'en charge, au point où le
  /// 401 se branche. Voir là-bas pourquoi les deux gestes ne se ressemblent pas.
  ///
  /// Rend `true` quand une session de membre vient d'être perdue, c'est-à-dire
  /// quand il y a **quelqu'un** à renvoyer vers la connexion. Rend `false` pour
  /// un invité : sa requête a simplement échoué, et il n'y a rien à lui dire. Le
  /// cas existe vraiment — un invité dont l'ouverture de session d'appareil a été
  /// refusée part sans porteur, et son 401 n'est estampillé « appareil » par
  /// personne.
  ///
  /// L'état `unknown` compte comme une session à perdre : c'est un démarrage à
  /// froid dont la revalidation de fond a pris le 401, et le coffre portait donc
  /// bien un jeton de membre.
  ///
  /// **Un jeton d'appareil est redemandé au passage**, pour la raison exacte qui
  /// le rend obligatoire à la déconnexion (`HttpAuthRepository.signOut`) :
  /// `ApiClient` vient de purger le jeton **et son marqueur**, l'application n'a
  /// donc plus aucun porteur ; la requête suivante partirait nue, son 401 se
  /// relirait comme un 401 de membre, et l'invité n'aurait plus jamais de jeton
  /// jusqu'au prochain démarrage. Vrai quelle que soit la destination de la
  /// navigation. `resume()` ne lève pas et est sérialisé côté porteur.
  bool handleUnauthorized() {
    unawaited(_repo.forgetSession());
    if (state.status == AuthStatus.guest) return false;
    unawaited(_resumeDeviceSession());
    state = AuthState.guest;
    return true;
  }

  /// Déconnecte l'utilisateur, qui **redevient un invité** et reste dans
  /// l'application.
  ///
  /// **Rien n'est effacé**, et c'est une décision explicite du client, assumée y
  /// compris sur un téléphone partagé : ni les téléchargements, ni la
  /// progression d'écoute — qui redevient simplement locale, la collection
  /// répliquée cessant d'être alimentée. C'est ce qui distingue cette méthode de
  /// [deleteAccount], la seule qui appelle `eraseEverything()`.
  ///
  /// **Et cette méthode-ci ne navigue pas**, contrairement à
  /// [handleUnauthorized] : l'accueil invité se déduit de l'état, par la garde du
  /// routeur. La personne a choisi de partir, on ne lui demande pas de revenir.
  ///
  /// Le jeton d'appareil, lui, est reprise par le repository (`device:`), qui est
  /// le seul à savoir que le coffre vient d'être purgé — le redemander **ici**
  /// ferait deux jetons pour un appareil.
  Future<void> signOut() async {
    await _repo.signOut();
    state = AuthState.guest;
  }

  /// Redemande un jeton d'appareil pour **le même** appareil. Muet, sans jamais
  /// lever : un invité n'a rien à voir de cette mécanique.
  Future<void> _resumeDeviceSession() async {
    final device = ref.read(deviceBootstrapProvider).repository;
    if (device == null) return;
    try {
      await device.resume();
    } on Object catch (_) {
      // `resume` ne lève pas ; ce `catch` couvre ce qui n'est pas du réseau (un
      // coffre indisponible). Perdre sa session ne peut pas échouer.
    }
  }

  /// **Supprime le compte, puis efface tout ce qui en restait sur l'appareil.**
  ///
  /// L'ordre n'est pas négociable : **le serveur d'abord**. Une panne réseau
  /// laisse le compte vivant, et vider le téléphone laisserait quelqu'un
  /// convaincu d'avoir disparu alors qu'il est toujours inscrit — l'exception
  /// remonte donc à l'écran, qui garde la main.
  ///
  /// Le magasin local vient **ensuite**, et il est aussi important que la
  /// session : `signOut()` ne l'a jamais touché, ce qui est défendable pour une
  /// déconnexion (on reprend son catalogue en revenant) et ne l'est pas ici. Le
  /// serveur a effacé la progression d'écoute, donc il n'enverra jamais de
  /// rétraction pour la retirer d'ici — et l'email libéré permet de créer un
  /// compte **neuf** dans la minute, sur ce téléphone-ci. Sans cet effacement,
  /// la personne suivante reprendrait un prêche là où la précédente s'était
  /// arrêtée.
  /// Le compte supprimé, l'appareil reste : on repart **invité**, avec un jeton
  /// d'appareil frais pour le même `deviceId`. Sans lui, l'application se
  /// retrouverait sans porteur — voir [handleUnauthorized].
  Future<void> deleteAccount() async {
    await _repo.deleteAccount();
    await _database.eraseEverything();
    await _repo.forgetSession();
    unawaited(_resumeDeviceSession());
    state = AuthState.guest;
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
