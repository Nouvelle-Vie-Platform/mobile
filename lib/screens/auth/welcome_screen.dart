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
/// texte blanc : visuels empilés, message de bienvenue, verset, puis bouton
/// « Commencer » et lien discret « Déjà membre ? » — tous deux menant à la
/// saisie de l'identifiant (flow login/inscription unifié).
///
/// Écran sans état : un simple [ConsumerWidget] suffit.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  /// Illustrations d'accueil (remplaçables par de vraies photos).
  static const _welcomeImages = [
    'https://picsum.photos/seed/eglise/500/600',
    'https://picsum.photos/seed/louange/500/600',
    'https://picsum.photos/seed/communaute/500/600',
  ];

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
                      const SizedBox(height: AppSpacing.xl),
                      const _StackedCards(imageUrls: _welcomeImages),
                      const SizedBox(height: AppSpacing.xxl),
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
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        l.onboardingSubtitle,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyLarge.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.5,
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

/// Illustration : trois cartes-photo empilées et pivotées (façon polaroid).
class _StackedCards extends StatelessWidget {
  const _StackedCards({required this.imageUrls});
  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    String url(int i) => i < imageUrls.length ? imageUrls[i] : '';
    return SizedBox(
      height: 300,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 24,
            bottom: 30,
            child: Transform.rotate(
              angle: -0.22,
              child: _ImageCard(url: url(0)),
            ),
          ),
          Positioned(
            right: 28,
            bottom: 44,
            child: Transform.rotate(
              angle: 0.16,
              child: _ImageCard(url: url(1)),
            ),
          ),
          Transform.rotate(
            angle: 0.03,
            child: _ImageCard(url: url(2), front: true),
          ),
        ],
      ),
    );
  }
}

/// Carte-photo à liseré blanc, avec repli coloré si l'image ne charge pas
/// (obligatoire : `Image.network` avec `errorBuilder`, cf. conventions).
class _ImageCard extends StatelessWidget {
  const _ImageCard({required this.url, this.front = false});
  final String url;
  final bool front;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(color: const Color(0xFFDDE3EC));
    return Container(
      width: 210,
      height: 160,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: front ? 0.28 : 0.14),
            blurRadius: front ? 22 : 10,
            offset: Offset(0, front ? 10 : 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: url.isEmpty
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => fallback,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : fallback,
              ),
      ),
    );
  }
}
