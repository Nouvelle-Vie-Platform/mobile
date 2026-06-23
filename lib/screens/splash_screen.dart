import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/brand_logo.dart';

/// Écran de démarrage (splash) — fond bleu, emblème centré et baseline.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientPrimary),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              const BrandLogo(size: 200),
              const SizedBox(height: AppSpacing.xl),
              Text(context.l10n.appName,
                  style: AppTypography.h2.copyWith(color: Colors.white)),
              const SizedBox(height: AppSpacing.sm),
              Text(context.l10n.splashTagline,
                  style: AppTypography.bodyLarge
                      .copyWith(color: Colors.white.withValues(alpha: 0.85))),
              const Spacer(flex: 3),
              // Bouton invisible déclenchant l'entrée (remplace l'auto-timer
              // pour rester sans état tout en restant navigable).
              TextButton(
                onPressed: () => context.goNamed(AppRoute.onboarding),
                child: const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
