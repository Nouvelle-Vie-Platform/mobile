import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maison_du_miracle/data/repositories/auth_repository.dart';
import 'package:maison_du_miracle/models/models.dart';
import 'package:maison_du_miracle/state/auth_providers.dart';

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

  @override
  Future<User?> cachedUser() async => cached;

  @override
  Future<User?> currentUser() => remote.future;

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

ProviderContainer _containerFor(AuthRepository repository) =>
    ProviderContainer.test(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
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

    test('sans cache ni session, on tranche pour « déconnecté »', () async {
      final repo = _ScriptedAuthRepository();
      final container = _containerFor(repo);

      container.read(authProvider);
      await Future<void>.delayed(Duration.zero);
      repo.remote.complete(null);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
    });

    test('sans cache et réseau injoignable, le splash ne tourne pas sans fin',
        () async {
      final repo = _ScriptedAuthRepository();
      final container = _containerFor(repo);

      container.read(authProvider);
      await Future<void>.delayed(Duration.zero);
      repo.remote.completeError(AuthException(AuthErrorCode.network));
      await Future<void>.delayed(Duration.zero);

      // L'écran d'auth, lui, s'ouvre hors ligne : rester en `unknown`
      // laisserait l'utilisateur devant un spinner éternel.
      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
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

    test('un 401 pendant la revalidation de fond ramène à « déconnecté »',
        () async {
      final repo = _ScriptedAuthRepository(cached: _cachedUser);
      final container = _containerFor(repo);

      container.read(authProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(authProvider).status, AuthStatus.authenticated);

      // `ApiClient` a purgé le token et prévenu la couche application ; le
      // repository, lui, rend « personne n'est connecté ».
      container.read(authProvider.notifier).handleUnauthorized();
      repo.remote.complete(null);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
      // Le cache local part avec la session : c'est la seule chose que
      // l'intercepteur réseau ne sait pas effacer.
      expect(repo.forgetCalls, greaterThan(0));
      expect(repo.cached, isNull);
    });
  });
}
