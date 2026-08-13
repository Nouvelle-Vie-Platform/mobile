import 'package:maison_du_miracle/data/repositories/auth_repository.dart';
import 'package:maison_du_miracle/models/models.dart';

/// Une session **déjà ouverte**, dont on choisit le résumé d'acceptation.
///
/// `InMemoryAuthRepository` ne convient pas ici : il déclare le fidèle de la
/// maquette **à jour** des planchers de `SampleData` (sans quoi le mode
/// maquette serait un écran mort), ce qui rend la barrière intestable. Ce
/// double-ci laisse le test décider de ce qui a été accepté, et rien d'autre.
class SignedInAuthRepository implements AuthRepository {
  SignedInAuthRepository({Map<String, int> accepted = const {}})
      : user = User(
          id: 'u_1',
          firstName: 'Jean',
          status: UserStatus.affiliated,
          profileComplete: true,
          acceptedLegal: accepted,
        );

  /// L'utilisateur courant — relu par les tests après une acceptation, pour
  /// vérifier que le résumé est bien **redescendu au cache**.
  User user;

  @override
  Future<User?> cachedUser() async => user;

  @override
  Future<User?> currentUser() async => user;

  @override
  Future<void> rememberUser(User updated) async => user = updated;

  @override
  Future<void> forgetSession() async {}

  @override
  Future<void> signOut() async {}

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
