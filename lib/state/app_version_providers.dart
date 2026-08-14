import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_version.dart';

/// Politique de réessai : **aucun réessai automatique**.
///
/// Riverpod 3 réessaie tout seul un provider en échec, jusqu'à dix fois avec
/// une attente qui double. Le numéro de version d'un binaire ne change pas
/// pendant qu'il tourne : insister ne ferait que laisser des minuteries
/// derrière soi, y compris sous `flutter test`.
Duration? _noAutomaticRetry(int retryCount, Object error) => null;

/// Le lecteur de version en service. `package_info_plus` en production, un
/// lecteur fixé dans les tests d'écran.
final appVersionReaderProvider = Provider<AppVersionReader>(
  (ref) => const PackageInfoAppVersionReader(),
);

/// La version du binaire installé, ou `null` si elle n'est pas connaissable.
///
/// Un `FutureProvider` et non un `Provider` : la lecture passe par un canal de
/// plugin. Elle se résout en quelques millisecondes et **ne se recharge
/// jamais** — un binaire ne change pas de version pendant qu'il tourne.
final appVersionProvider = FutureProvider<AppVersionInfo?>(
  (ref) => ref.watch(appVersionReaderProvider).read(),
  retry: _noAutomaticRetry,
);
