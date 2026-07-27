import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/api_client.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n_setup.dart';
import 'router/app_router.dart';
import 'state/auth_providers.dart';
import 'state/theme_provider.dart';
import 'theme/app_theme.dart';

/// Widget racine de l'application « Maison du Miracle ».
///
/// Consomme le [themeModeProvider] et le [routerProvider] via Riverpod, et
/// câble la réaction au **401** global (voir [_MaisonDuMiracleAppState]).
class MaisonDuMiracleApp extends ConsumerStatefulWidget {
  const MaisonDuMiracleApp({super.key});

  @override
  ConsumerState<MaisonDuMiracleApp> createState() => _MaisonDuMiracleAppState();
}

class _MaisonDuMiracleAppState extends ConsumerState<MaisonDuMiracleApp> {
  @override
  void initState() {
    super.initState();
    // Point de jonction du 401 : `ApiClient` est un singleton de la couche
    // réseau, sans accès à Riverpod ni à GoRouter — et il ne doit pas en
    // acquérir. C'est ici, où les deux existent, qu'on branche la réaction.
    ApiClient.instance.onUnauthorized = _handleUnauthorized;
  }

  @override
  void dispose() {
    ApiClient.instance.onUnauthorized = null;
    super.dispose();
  }

  /// Le serveur a refusé le token : `ApiClient` l'a purgé, on repasse l'état
  /// d'auth à « déconnecté ». La garde `redirect` du routeur, déjà branchée sur
  /// `authProvider`, ramène alors à `/auth` depuis n'importe quel écran — nul
  /// besoin de manipuler le routeur ici.
  void _handleUnauthorized() {
    if (!mounted) return;
    ref.read(authProvider.notifier).handleUnauthorized();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      routerConfig: router,
    );
  }
}
