import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'l10n/l10n_setup.dart';
import 'router/app_router.dart';
import 'state/theme_provider.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

/// Widget racine de l'application « Maison du Miracle ».
///
/// Consomme le [themeModeProvider] et le [routerProvider] via Riverpod.
class MaisonDuMiracleApp extends ConsumerWidget {
  const MaisonDuMiracleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      // Dégradé « glass » global : posé derrière tous les écrans (les Scaffold
      // sont transparents), il fait « lire » les surfaces translucides.
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient:
                isDark ? AppColors.gradientAppDark : AppColors.gradientAppLight,
          ),
          child: child,
        );
      },
    );
  }
}
