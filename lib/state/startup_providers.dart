/// **Ce que `main()` sait avant le premier frame**, et que rien d'autre ne peut
/// savoir à temps.
///
/// Deux questions vivent ici, et une seule raison : toutes deux se décident
/// **avant** que le premier écran soit choisi, dans `main()`, hors de l'arbre de
/// widgets. Le reste de l'application les lit par provider et ne connaît que
/// leurs valeurs de repli — celles qui reproduisent exactement le démarrage
/// d'avant le mode invité.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../data/devices/device_repository.dart';

/// Ce que le coffre portait au démarrage, lu **une fois**, avant `runApp`.
///
/// C'est ce qui décide de l'existence du **splash**. Aujourd'hui l'état d'auth
/// part de `unknown` et le routeur réécrit toutes les routes vers `/` pendant la
/// résolution : un premier lancement montre donc un écran d'attente, puis la
/// page d'authentification. Un invité n'a rien à attendre, et cette lecture-ci
/// est le seul moyen de le dire **avant** le premier frame — le coffre est
/// asynchrone, `Notifier.build()` ne l'est pas.
enum StartupVault {
  /// Personne n'a regardé. **Le défaut**, et il conserve mot pour mot le
  /// démarrage d'avant le mode invité : `unknown`, donc splash, puis résolution.
  /// C'est la valeur sous `flutter test`, où aucun test n'a à se soucier du
  /// coffre.
  unread,

  /// Une session de **membre** attend d'être résolue → `unknown`, donc splash
  /// bref, exactement comme aujourd'hui.
  memberSession,

  /// Rien dans le coffre, **ou un jeton d'appareil seul**. Il n'y a pas de
  /// session de membre à attendre : on part **invité**, sans splash.
  ///
  /// Les deux cas se confondent exprès. Un jeton d'appareil n'est pas une
  /// session : le distinguer donnerait un troisième démarrage à tenir, pour une
  /// différence qu'aucun écran ne peut voir.
  noMemberSession,
}

/// Ce que le coffre portait au démarrage. Surchargé par `main()` ; partout
/// ailleurs — tests compris — il vaut [StartupVault.unread].
final startupVaultProvider = Provider<StartupVault>(
  (ref) => StartupVault.unread,
);

/// Lit le coffre pour répondre à **une** question : y a-t-il une session de
/// membre à résoudre ?
///
/// Deux lectures locales, aucun réseau — c'est ce qui permet de l'attendre avant
/// `runApp` sans rien coûter à l'ouverture (`AudioService.init()`, déjà attendu
/// là, est plus lent d'un ordre de grandeur).
///
/// **Un coffre illisible rend [StartupVault.unread]**, jamais « invité » : se
/// tromper de ce côté-là cacherait une session de membre derrière un accueil
/// anonyme, alors que l'autre erreur ne coûte qu'un splash de trop. C'est la
/// même asymétrie qu'[AuthTokenKind.parse], et elle penche du même côté.
Future<StartupVault> readStartupVault({ApiClient? client}) async {
  final api = client ?? ApiClient.instance;
  try {
    if (await api.readToken() == null) return StartupVault.noMemberSession;
    return await api.readTokenKind() == AuthTokenKind.member
        ? StartupVault.memberSession
        : StartupVault.noMemberSession;
  } on Object catch (_) {
    return StartupVault.unread;
  }
}

/// Le délai au-delà duquel le premier cycle de synchronisation part **sans**
/// attendre le jeton d'appareil.
///
/// Ce n'est pas un réglage de confort, c'est l'arbitrage entre deux échecs. Sans
/// jeton, un cycle échoue pour rien — d'où l'attente. Mais en avion l'ouverture
/// de session ne rend la main qu'au bout du `connectTimeout` (10 s) : attendre
/// sans borne reporterait le cycle d'autant, et surtout laisserait le
/// déclencheur « ouverture » dépendre du réseau, alors que c'est le seul qui
/// remplit le magasin au premier lancement. Passé ce délai on tente quand même :
/// l'échec est gratuit, et « retour au premier plan » rattrapera.
///
/// **Rien à l'écran n'attend ceci** : le premier frame est déjà peint quand le
/// compte à rebours commence. **Valeur à confirmer.**
const Duration kDeviceSessionStartupGrace = Duration(seconds: 5);

/// Le porteur d'appareil **tel que `main()` l'a installé**, et l'ouverture de
/// session qu'il a lancée au démarrage.
///
/// Un seul provider pour les deux, parce qu'il n'y a qu'un moment où les deux
/// naissent, et qu'un exemplaire unique du porteur est une condition de son
/// fonctionnement (voir `HttpDeviceRepository.wire`). Hors production il vaut
/// [none] : pas de mode invité câblé, donc rien à attendre et rien à reprendre —
/// exactement l'application d'avant.
class DeviceBootstrap {
  const DeviceBootstrap({this.repository, Future<bool>? session})
      : _session = session;

  /// Aucun porteur câblé : le défaut du provider, et l'état sous `flutter test`.
  static const DeviceBootstrap none = DeviceBootstrap();

  /// Le porteur, pour ce qui doit lui **parler** — la déconnexion, qui reprend
  /// un jeton pour le même appareil.
  final DeviceRepository? repository;

  /// L'ouverture de session lancée au démarrage, **jamais attendue par un
  /// écran**.
  final Future<bool>? _session;

  /// Attend qu'un jeton existe, **et jamais indéfiniment** — voir
  /// [kDeviceSessionStartupGrace].
  ///
  /// Ne lève pas : un échec d'ouverture de session est une requête qui échouera,
  /// pas une erreur à remonter (même règle que `DeviceSessionGuard.renew`).
  Future<bool> awaitToken({Duration grace = kDeviceSessionStartupGrace}) {
    final session = _session;
    // Pas de porteur câblé : rien à attendre, et surtout **aucune minuterie** —
    // un `timeout` posé pour rien laisserait un « pending timer » derrière lui
    // dans les tests qui montent l'application entière.
    if (session == null) return Future<bool>.value(false);
    final bounded = session.timeout(grace, onTimeout: () => false);
    return bounded.onError<Object>((_, __) => false);
  }
}

/// Le porteur d'appareil de cette exécution. Surchargé par `main()`.
final deviceBootstrapProvider = Provider<DeviceBootstrap>(
  (ref) => DeviceBootstrap.none,
);
