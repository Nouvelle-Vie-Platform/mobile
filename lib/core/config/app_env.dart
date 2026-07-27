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

  // L'URL du backend vit dans `kBaseUrl` (lib/core/network/api_client.dart),
  // alimentée par `--dart-define=API_BASE_URL=…`. L'ancien `AppEnv.baseUrl`
  // (define `BASE_URL`) n'était lu nulle part : deux conventions concurrentes
  // pour un seul réglage, c'est une erreur de configuration en attente.
}
