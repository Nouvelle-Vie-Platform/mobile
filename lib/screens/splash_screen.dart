import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/brand_logo.dart';

/// Écran de démarrage (splash) — pur écran de marque.
///
/// Aiguillage **automatique** : le `redirect` du routeur, piloté par
/// `authProvider`, garde l'utilisateur ici tant que la session n'est pas
/// résolue (`AuthStatus.unknown`), puis l'envoie vers `/auth` ou `/home`.
/// Cet écran ne navigue donc **jamais** de lui-même — il se contente
/// d'afficher l'emblème et un indicateur de chargement pendant la résolution.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.gradientPrimary),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                const BrandLogo(size: 200),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  context.l10n.appName,
                  style: AppTypography.h2.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  context.l10n.splashTagline,
                  style: AppTypography.bodyLarge
                      .copyWith(color: Colors.white.withValues(alpha: 0.85)),
                ),
                const Spacer(flex: 3),
                // Indicateur de résolution de la session (non interactif) :
                // le `redirect` du routeur aiguille automatiquement dès que
                // `authProvider` quitte l'état `unknown`.
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
