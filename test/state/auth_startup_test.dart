import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/local/app_database.dart';
import 'package:maison_du_miracle/data/repositories/auth_repository.dart';
import 'package:maison_du_miracle/models/models.dart';
import 'package:maison_du_miracle/state/auth_providers.dart';
import 'package:maison_du_miracle/state/startup_providers.dart';
import 'package:maison_du_miracle/state/sync_providers.dart';

import '../data/local/local_database_fixtures.dart';

/// Repository pilotable : le cache répond tout de suite, la revalidation
/// réseau est un [Completer] que le test ouvre quand il veut.
///
/// C'est exactement la forme du problème testé ici — savoir ce que fait l'app
/// **pendant** que le réseau n'a pas encore répondu.
class _ScriptedAuthRepository implements AuthRepository {
  _ScriptedAuthRepository({this.cached});

  User? cached;
  final Completer<User?> remote = Completer<User?>();
  int forgetCalls = 0;

  /// Combien de fois le **réseau** a été sollicité. Ajouté avec le mode
  /// invité : « pas de splash » ne se prouve pas seulement par l'état publié,
  /// il se prouve par l'absence d'aller-retour à attendre.
  int currentUserCalls = 0;

  @override
  Future<User?> cachedUser() async => cached;

  @override
  Future<User?> currentUser() {
    currentUserCalls++;
    return remote.future;
  }

  @override
  Future<void> rememberUser(User user) async {
    cached = user;
  }

  /// Le double ne supprime rien : aucun test de ce fichier n'exerce la
  /// suppression de compte, il n'a qu'à satisfaire le contrat.
  @override
  Future<void> deleteAccount() async {}

  @override
  Future<void> forgetSession() async {
    forgetCalls++;
    cached = null;
  }

  @override
  Future<void> signOut() async {
    cached = null;
  }

  @override
  Future<void> requestCode({
    required String identifier,
    required IdentifierChannel channel,
  }) async {}

  @override
  Future<Session> verifyCode({
    required String identifier,
    required String code,
  }) =>
      throw UnimplementedError();

  @override
  Future<Session> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<Session> signInWithApple() => throw UnimplementedError();

  @override
  Future<User> updateProfile({
    UserTitle? title,
    String? firstName,
    String? lastName,
    int? branchId,
    UserStatus? status,
  }) =>
      throw UnimplementedError();
}

const _cachedUser = User(
  id: 'u_1',
  email: 'jean.kossi@email.com',
  title: UserTitle.brother,
  firstName: 'Jean',
  branchId: 1,
  status: UserStatus.affiliated,
  profileComplete: true,
);

/// [vault] est ce que `main()` a lu du coffre avant le premier frame. Le
/// défaut — [StartupVault.unread] — est celui du provider, donc celui de tous
/// les tests écrits avant le mode invité : ils décrivent le démarrage
/// **inchangé**.
ProviderContainer _containerFor(
  AuthRepository repository, {
  StartupVault vault = StartupVault.unread,
  AppDatabase? database,
}) =>
    ProviderContainer.test(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        startupVaultProvider.overrideWithValue(vault),
        if (database != null) appDatabaseProvider.overrideWithValue(database),
      ],
    );

void main() {
  group('démarrage', () {
    test('le cache route immédiatement, sans attendre /auth/me', () async {
      final repo = _ScriptedAuthRepository(cached: _cachedUser);
      final container = _containerFor(repo);

      container.read(authProvider);
      // Un tour de boucle suffit à lire le cache ; la revalidation, elle,
      // n'a toujours pas répondu.
      await Future<void>.delayed(Duration.zero);

      expect(repo.remote.isCompleted, isFalse);
      final state = container.read(authProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user?.firstName, 'Jean');
    });

    test('mode avion : la session en cache reste ouverte', () async {
      final repo = _ScriptedAuthRepository(cached: _cachedUser);
      final container = _containerFor(repo);

      container.read(authProvider);
      await Future<void>.delayed(Duration.zero);
      repo.remote.completeError(
        AuthException(AuthErrorCode.network, 'Impossible de joindre'),
      );
      await Future<void>.delayed(Duration.zero);

      // Une coupure réseau n'est pas une déconnexion : le token reste valide
      // 90 jours glissants.
      expect(container.read(authProvider).status, AuthStatus.authenticated);
      expect(container.read(authProvider).user?.id, 'u_1');
    });

    test('sans cache ni session, on tranche pour « invité »', () async {
      final repo = _ScriptedAuthRepository();
      final container = _containerFor(repo);

      container.read(authProvider);
      await Future<void>.delayed(Duration.zero);
      repo.remote.complete(null);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(authProvider).status, AuthStatus.guest);
    });

    test('sans cache et réseau injoignable, le splash ne tourne pas sans fin',
        () async {
      final repo = _ScriptedAuthRepository();
      final container = _containerFor(repo);

      container.read(authProvider);
      await Future<void>.delayed(Duration.zero);
      repo.remote.completeError(AuthException(AuthErrorCode.network));
      await Future<void>.delayed(Duration.zero);

      // La surface publique, elle, s'ouvre hors ligne : rester en `unknown`
      // laisserait l'utilisateur devant un spinner éternel.
      expect(container.read(authProvider).status, AuthStatus.guest);
    });

    test('une revalidation qui diffère met l\'état à jour', () async {
      final repo = _ScriptedAuthRepository(cached: _cachedUser);
      final container = _containerFor(repo);

      container.read(authProvider);
      await Future<void>.delayed(Duration.zero);
      repo.remote.complete(const User(
        id: 'u_1',
        email: 'jean.kossi@email.com',
        title: UserTitle.brother,
        firstName: 'Jean',
        lastName: 'Kossi',
        branchId: 2,
        status: UserStatus.affiliated,
        profileComplete: true,
      ));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user?.lastName, 'Kossi');
      expect(state.user?.branchId, 2);
    });

    test('un 401 pendant la revalidation de fond ramène à « invité »',
        () async {
      final repo = _ScriptedAuthRepository(cached: _cachedUser);
      final container = _containerFor(repo);

      container.read(authProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(authProvider).status, AuthStatus.authenticated);

      // `ApiClient` a purgé le token et prévenu la couche application ; le
      // repository, lui, rend « personne n'est connecté ».
      //
      // **`true` = il y a quelqu'un à renvoyer vers la connexion**, et c'est de
      // cette valeur que `app.dart` déduit l'éjection vers `/auth`. Une session
      // expirée n'est pas une déconnexion choisie : la reposer sur l'accueil
      // invité serait la seule façon de cacher à la personne qu'elle l'a perdue.
      final lost = container.read(authProvider.notifier).handleUnauthorized();
      expect(lost, isTrue);
      repo.remote.complete(null);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(authProvider).status, AuthStatus.guest);
      // Le cache local part avec la session : c'est la seule chose que
      // l'intercepteur réseau ne sait pas effacer.
      expect(repo.forgetCalls, greaterThan(0));
      expect(repo.cached, isNull);
    });
  });

  /// **Le cas qui n'existait pas** : un premier lancement.
  ///
  /// Les six tests ci-dessus décrivent tous un coffre qu'on n'a pas lu
  /// ([StartupVault.unread]) — c'est-à-dire le démarrage d'avant le mode
  /// invité, et ils sont là pour prouver qu'il n'a pas bougé d'un octet. Ceux
  /// qui suivent décrivent le seul démarrage nouveau : celui où l'on sait,
  /// **avant le premier frame**, qu'il n'y a pas de session de membre à
  /// attendre.
  group('démarrage sans session de membre', () {
    test('coffre vide : invité dès le premier état, aucun splash', () async {
      final repo = _ScriptedAuthRepository();
      final container = _containerFor(
        repo,
        vault: StartupVault.noMemberSession,
      );

      // **Aucun `await` ici, et c'est tout le test.** Le premier état publié
      // est déjà « invité » : le routeur envoie `/` sur l'accueil à la première
      // évaluation de sa garde, donc le splash ne se peint pas. Un `unknown`
      // même bref aurait suffi à le montrer.
      expect(container.read(authProvider).status, AuthStatus.guest);

      await Future<void>.delayed(Duration.zero);
      expect(container.read(authProvider).status, AuthStatus.guest);
      // Et rien n'a été demandé au réseau : il n'y a pas de session à
      // revalider. Sans cette vérification, un `GET /auth/me` par ouverture
      // passerait inaperçu — il aboutit à « invité » de toute façon.
      expect(repo.currentUserCalls, 0);
      expect(repo.remote.isCompleted, isFalse);
    });

    test('avec un jeton de membre, `unknown` d\'abord — comme avant', () async {
      final repo = _ScriptedAuthRepository(cached: _cachedUser);
      final container = _containerFor(
        repo,
        vault: StartupVault.memberSession,
      );

      // Le splash existe encore, et il doit exister : c'est la contrainte du
      // client — « quand la personne s'est déjà connectée, tout se passe
      // exactement comme présentement ».
      expect(container.read(authProvider).status, AuthStatus.unknown);

      await Future<void>.delayed(Duration.zero);
      expect(container.read(authProvider).status, AuthStatus.authenticated);
      expect(repo.currentUserCalls, 1, reason: 'la revalidation a bien lieu');
    });

    test('un jeton d\'appareil n\'est pas une session de membre', () async {
      // La règle, à sa source : c'est la lecture du coffre qui décide, et elle
      // met « rien du tout » et « un jeton d'appareil » dans le même sac. Un
      // invité dont l'appareil porte déjà un jeton ne doit pas se retrouver
      // « en cours de résolution » — il n'y a personne à résoudre.
      FlutterSecureStorage.setMockInitialValues({
        'auth_token': 'oat_appareil',
        'auth_token_kind': 'device',
      });
      expect(await readStartupVault(), StartupVault.noMemberSession);

      FlutterSecureStorage.setMockInitialValues({});
      expect(await readStartupVault(), StartupVault.noMemberSession);

      FlutterSecureStorage.setMockInitialValues({
        'auth_token': 'oat_membre',
        'auth_token_kind': 'member',
      });
      expect(await readStartupVault(), StartupVault.memberSession);

      // Une installation d'avant le mode invité : un jeton, **pas de
      // marqueur**. C'est un membre, et `AuthTokenKind.parse` le dit déjà — la
      // lecture du coffre ne le contredit pas.
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'oat_ancien'});
      expect(await readStartupVault(), StartupVault.memberSession);
    });
  });

  group('sortie de session', () {
    test('la déconnexion ramène à l\'invité et n\'efface rien', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = _ScriptedAuthRepository(cached: _cachedUser);
      final container = _containerFor(repo, database: db);

      container.read(authProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(authProvider).status, AuthStatus.authenticated);

      // Ce qu'un fidèle a écouté, tenu localement par le lecteur. C'est la
      // moitié de ce que la déconnexion ne doit pas emporter ; l'autre — les
      // téléchargements — vit dans le même fichier de base et part avec lui,
      // donc le vérifier deux fois ne dirait rien de plus.
      await db.playbackDao.saveLocalPosition(
        contentId: 'ens_1',
        progressId: '0190-aaaa',
        positionSeconds: 742,
      );

      await container.read(authProvider.notifier).signOut();

      // On **reste dans l'application**, du côté public : la garde du routeur
      // en déduit l'accueil invité, elle ne renvoie plus vers `/auth`.
      expect(container.read(authProvider).status, AuthStatus.guest);
      expect(container.read(authProvider).user, isNull);

      // Et rien n'a été effacé. La progression redevient simplement locale —
      // la collection répliquée cesse d'être alimentée, elle n'est pas purgée.
      // C'est `deleteAccount()`, et elle seule, qui appelle
      // `eraseEverything()`.
      final resume = await db.playbackDao.resumeFor('ens_1');
      expect(resume?.positionSeconds, 742);
    });

    test('un 401 d\'invité ne renvoie personne à la connexion', () async {
      final repo = _ScriptedAuthRepository();
      final container = _containerFor(
        repo,
        vault: StartupVault.noMemberSession,
      );
      expect(container.read(authProvider).status, AuthStatus.guest);

      // Le cas arrive pour de vrai : un invité dont l'ouverture de session
      // d'appareil a été refusée part **sans porteur**, et son 401 n'est
      // estampillé « appareil » par personne — il remonte donc jusqu'ici. Il
      // n'a pas de session à perdre, et surtout rien à aller faire sur l'écran
      // de connexion : sa requête a échoué, c'est tout.
      final lost = container.read(authProvider.notifier).handleUnauthorized();
      expect(lost, isFalse);
      expect(container.read(authProvider).status, AuthStatus.guest);
    });
  });
}
