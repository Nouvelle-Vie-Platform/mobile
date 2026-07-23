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
/// Écran immersif sur fond dégradé bleu de marque ([AppColors.gradientPrimary]),
/// texte blanc : une colombe animée (WebP animé, boucle infinie) survolant le
/// dégradé, le message de bienvenue et un verset, puis le bouton « Commencer »
/// et le lien discret « Déjà membre ? » — tous deux menant à la saisie de
/// l'identifiant (flow login/inscription unifié).
///
/// Écran sans état : un simple [ConsumerWidget] suffit.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    // Le Scaffold reste transparent : c'est le DecoratedBox ci-dessous qui
    // pose le dégradé de marque en plein écran (écran immersif, comme l'accueil).
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.gradientPrimary),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: AppSpacing.screenPadding,
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      const _DoveAnimation(),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        l.onboardingWelcome,
                        textAlign: TextAlign.center,
                        style: AppTypography.h1.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l.onboardingTitleHighlight,
                        textAlign: TextAlign.center,
                        style: AppTypography.h2.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        l.onboardingVerse,
                        textAlign: TextAlign.center,
                        style: AppTypography.body.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontStyle: FontStyle.italic,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
              _BottomActions(
                startLabel: l.authStart,
                alreadyMemberLabel: l.authAlreadyMember,
                onStart: () => context.goNamed(AppRoute.authIdentifier),
                onAlreadyMember: () => context.goNamed(AppRoute.authIdentifier),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Colombe de la paix animée (WebP animé, alpha) posée sur le dégradé de marque.
///
/// Le WebP boucle nativement (`Loop Count : 0`) : aucun plugin, compatible web.
/// L'animation est détourée (fond transparent), donc la colombe survole
/// directement le dégradé — la couleur concorde par construction.
class _DoveAnimation extends StatelessWidget {
  const _DoveAnimation();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      width: double.infinity,
      child: Image.asset(
        'assets/animations/colombe.webp',
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}

/// Zone d'actions épinglée en bas : bouton principal « Commencer » (blanc,
/// texte bleu) + lien discret « Déjà membre ? ».
class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.startLabel,
    required this.alreadyMemberLabel,
    required this.onStart,
    required this.onAlreadyMember,
  });

  final String startLabel;
  final String alreadyMemberLabel;
  final VoidCallback onStart;
  final VoidCallback onAlreadyMember;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                onTap: onStart,
                child: Center(
                  child: Text(
                    startLabel,
                    style: AppTypography.button.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: onAlreadyMember,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.9),
            ),
            child: Text(
              alreadyMemberLabel,
              style: AppTypography.body.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
