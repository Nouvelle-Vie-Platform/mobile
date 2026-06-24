import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
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
                            TextSpan(
                                text: '${context.l10n.onboardingWelcome}\n'),
                            TextSpan(
                                text: context.l10n.onboardingTitleHighlight,
                                style: AppTypography.h1
                                    .copyWith(color: palette.primary)),
                            const TextSpan(text: ' !'),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        context.l10n.onboardingSubtitle,
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
                            label: context.l10n.actionNext,
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
