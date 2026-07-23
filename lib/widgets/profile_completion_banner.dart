import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../router/app_router.dart';
import '../state/auth_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';

/// Notifier minimal portant l'état « bannière fermée ».
class _ProfileBannerDismissed extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() => state = true;
}

/// État éphémère « bannière fermée ». Partagé (Accueil + onglet Profil) pour
/// que fermer sur une page la ferme aussi ailleurs — d'où un provider dédié
/// plutôt qu'un `StatefulWidget` local.
final profileBannerDismissedProvider =
    NotifierProvider<_ProfileBannerDismissed, bool>(
  _ProfileBannerDismissed.new,
);

/// Bannière douce invitant à compléter le profil (jamais bloquante).
///
/// Ne s'affiche que si un utilisateur est connecté, que son profil n'est **pas**
/// complet et que la bannière n'a pas été fermée. Style `AppCard` (verre dépoli).
class ProfileCompletionBanner extends ConsumerWidget {
  const ProfileCompletionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final dismissed = ref.watch(profileBannerDismissedProvider);

    if (dismissed || user == null || user.profileComplete) {
      return const SizedBox.shrink();
    }

    final l = context.l10n;
    final palette = context.palette;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_circle_outlined,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l.profileIncompleteBanner,
                  style: AppTypography.bodyStrong
                      .copyWith(color: palette.textPrimary),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: palette.textSecondary,
                visualDensity: VisualDensity.compact,
                tooltip: l.actionCancel,
                onPressed: () =>
                    ref.read(profileBannerDismissedProvider.notifier).dismiss(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => context.goNamed(AppRoute.profileEdit),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
              ),
              child: Text(l.profileIncompleteBannerCta),
            ),
          ),
        ],
      ),
    );
  }
}
