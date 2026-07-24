/// Configuration d'environnement de l'application.
///
/// Permet de basculer entre le backend local et le mock en mémoire
/// sans toucher les écrans ni les providers.
///
/// Usage :
///   - Développement avec backend : `AppEnv.useBackend = true;`
///   - Développement maquette     : `AppEnv.useBackend = false;`
///
/// À terme, ce flag pourra être passé via `--dart-define` pour les
/// différents targets de build (debug / staging / release).
class AppEnv {
  AppEnv._();

  /// `true`  → utilise [HttpAuthRepository] + backend local sur port 3333.
  /// `false` → utilise [InMemoryAuthRepository] (données factices).
  static bool useBackend = true;

  /// URL de base du backend (redéfinie via `--dart-define=BASE_URL=...`).
  static const String baseUrl =
      String.fromEnvironment('BASE_URL', defaultValue: 'http://localhost:3333');
}
