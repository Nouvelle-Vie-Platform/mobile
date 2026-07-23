import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../router/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Première page de `/auth` : accueil / point d'entrée du parcours unifié.
///
/// Écran immersif : une scène nocturne (image de fond, église + rayon de
/// lumière), une colombe animée (WebP animé, boucle infinie) nimbée d'un halo,
/// le message de bienvenue, puis le bouton « Commencer » menant à la saisie de
/// l'identifiant (flow login/inscription unifié).
///
/// Écran sans état : un simple [ConsumerWidget] suffit.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    // Le Scaffold reste transparent : l'image de fond ci-dessous couvre l'écran.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fond immersif plein écran (repli sur le dégradé de marque).
          Image.asset(
            'assets/images/welcome_bg.webp',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.gradientPrimary),
            ),
          ),
          // Léger voile bas pour la lisibilité du texte et du bouton.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x66020A1E)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Align(
                    alignment: const Alignment(0, -0.32),
                    child: SingleChildScrollView(
                      padding: AppSpacing.screenPadding,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _DoveAnimation(),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            l.onboardingWelcome,
                            textAlign: TextAlign.center,
                            style: AppTypography.h1.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 42,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          // Fin trait lumineux (centre plus clair), façon maquette.
                          Container(
                            width: 160,
                            height: 1.5,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.6),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            l.onboardingTitleHighlight,
                            textAlign: TextAlign.center,
                            style: AppTypography.body.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _StartButton(
                  label: l.authStart,
                  onTap: () => context.goNamed(AppRoute.authIdentifier),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Colombe de la paix animée (WebP animé, alpha) nimbée d'un halo lumineux.
///
/// Le WebP boucle nativement (`Loop Count : 0`) : aucun plugin, compatible web.
/// L'animation est détourée (fond transparent) et survole la scène de fond.
class _DoveAnimation extends StatelessWidget {
  const _DoveAnimation();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 340,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo radial derrière la colombe.
          IgnorePointer(
            child: Container(
              width: 320,
              height: 320,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x33FFFFFF), Colors.transparent],
                  stops: [0.15, 1.0],
                ),
              ),
            ),
          ),
          Image.asset(
            'assets/animations/colombe.webp',
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Bouton principal « Commencer » épinglé en bas : pilule blanche, texte bleu,
/// et pastille circulaire bleue avec flèche à gauche (façon maquette).
class _StartButton extends StatelessWidget {
  const _StartButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: onTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Text(
                    label,
                    style: AppTypography.button.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
