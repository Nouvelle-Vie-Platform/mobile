import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/media_thumbnail.dart';
import '../widgets/page_indicator.dart';

/// Écran d'accueil (onboarding) : titre de bienvenue, visuel et CTA.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: AppSpacing.screenPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.xxl),
                      RichText(
                        text: TextSpan(
                          style: AppTypography.h1
                              .copyWith(color: palette.textPrimary),
                          children: [
                            const TextSpan(text: 'Bienvenue\n'),
                            TextSpan(
                                text: 'Dans la Maison\ndu Miracle',
                                style: AppTypography.h1
                                    .copyWith(color: palette.primary)),
                            const TextSpan(text: ' !'),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Une communauté vivante, connectée et engagée pour la gloire de Dieu.',
                        style: AppTypography.bodyLarge
                            .copyWith(color: palette.textSecondary),
                      ),
                      const Spacer(),
                      const MediaThumbnail(
                        height: 240,
                        borderRadius: AppRadius.lg,
                        showPlay: false,
                        seed: 0,
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const PageIndicator(count: 3, activeIndex: 0),
                          AppButton(
                            label: 'Suivant',
                            expand: false,
                            trailingIcon: Icons.arrow_forward,
                            onPressed: () => context.goNamed(AppRoute.login),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
