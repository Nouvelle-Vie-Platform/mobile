import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../models/models.dart';
import '../router/app_router.dart';
import '../state/auth_providers.dart';
import '../state/theme_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_avatar.dart';
import '../widgets/menu_tile.dart';
import '../widgets/profile_completion_banner.dart';

/// Onglet « Profil » : en-tête de marque (avatar, rôle, branche, statistiques,
/// badges) surmontant une feuille de réglages.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final palette = context.palette;
    final mode = ref.watch(themeModeProvider);
    final dark = isDarkModeActive(mode, context);

    final user = ref.watch(authProvider).user;
    final branches = ref.watch(branchesProvider);

    // Nom affiché : recomposition Frère/Sœur + nom, repli sur le rôle générique.
    final displayName = user?.displayName ?? '';
    final name = displayName.isEmpty ? l.profileRole : displayName;

    // Branche : « nouveau » ou pas de rattachement → libellé de statut dédié.
    String branchLabel = l.statusNewLabel;
    if (user != null &&
        user.status != UserStatus.nouveau &&
        user.branchId != null) {
      for (final b in branches) {
        if (b.id == user.branchId) {
          branchLabel = b.name;
          break;
        }
      }
    }

    return Column(
      children: [
        _ProfileHeader(
          name: name,
          role: l.profileRole,
          branch: branchLabel,
        ),
        // Feuille de réglages remontant sur l'en-tête.
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListView(
              padding: EdgeInsets.only(
                top: AppSpacing.md,
                bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
              ),
              children: [
                // Bannière douce d'invitation à compléter le profil.
                if (user != null && !user.profileComplete) ...[
                  Padding(
                    padding: AppSpacing.screenPadding,
                    child: const ProfileCompletionBanner(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                MenuTile(
                  icon: Icons.edit_outlined,
                  label: l.profileEditAction,
                  onTap: () => context.goNamed(AppRoute.profileEdit),
                ),
                _divider,
                MenuTile(
                  icon: Icons.dark_mode_outlined,
                  label: l.darkMode,
                  showChevron: false,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .toggle(platformIsDark: dark),
                  trailing: Switch.adaptive(
                    value: dark,
                    onChanged: (_) => ref
                        .read(themeModeProvider.notifier)
                        .toggle(platformIsDark: dark),
                    activeTrackColor: AppColors.secondary,
                  ),
                ),
                _divider,
                MenuTile(
                  icon: Icons.help_outline,
                  label: l.helpSupport,
                  onTap: () {},
                ),
                const SizedBox(height: AppSpacing.sm),
                MenuTile(
                  icon: Icons.logout,
                  label: l.logout,
                  destructive: true,
                  // Confirmation puis déconnexion : le `redirect` du routeur
                  // renvoie ensuite vers `/auth` (pas de navigation manuelle).
                  onTap: () => _confirmSignOut(context, ref),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Demande confirmation avant de déconnecter. À confirmation, appelle
  /// `signOut()` ; la garde de route (`redirect`) renvoie ensuite vers `/auth`.
  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.logoutConfirmTitle),
        content: Text(l.logoutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(l.logout),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).signOut();
    }
  }

  static const _divider =
      Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg);
}

/// En-tête de profil au dégradé de marque : barre, avatar + nom + rôle,
/// branche + bouton « Modifier » et raccourcis.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.role,
    required this.branch,
  });

  final String name;
  final String role;
  final String branch;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.gradientPrimary),
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
        bottom: AppSpacing.xl,
      ),
      child: Column(
        children: [
          // Barre supérieure.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l.navProfile,
                    style: AppTypography.h2.copyWith(color: Colors.white)),
                IconButton(
                  icon:
                      const Icon(Icons.settings_outlined, color: Colors.white),
                  tooltip: l.settings,
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Avatar + nom + rôle.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: AppAvatar(name: name, size: 64),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              AppTypography.h3.copyWith(color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(role,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body.copyWith(
                              color: Colors.white.withValues(alpha: 0.9))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Branche + bouton Modifier.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(branch,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body.copyWith(
                                color: Colors.white.withValues(alpha: 0.9))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _EditButton(label: l.profileEdit),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Raccourcis rapides (badges hexagonaux).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: _BadgeShortcut(
                    icon: Icons.account_balance,
                    label: l.profileMyBranch,
                    color: AppColors.primary,
                    onTap: () {},
                  ),
                ),
                Expanded(
                  child: _BadgeShortcut(
                    icon: Icons.menu_book,
                    label: l.profileStatNotes,
                    color: const Color(0xFF7A5AF8),
                    onTap: () => context.pushNamed(AppRoute.notes),
                  ),
                ),
                Expanded(
                  child: _BadgeShortcut(
                    icon: Icons.event_outlined,
                    label: l.navAgenda,
                    color: AppColors.warning,
                    onTap: () => context.pushNamed(AppRoute.agenda),
                  ),
                ),
                Expanded(
                  child: _BadgeShortcut(
                    icon: Icons.volunteer_activism,
                    label: l.navDonations,
                    color: AppColors.danger,
                    onTap: () => context.pushNamed(AppRoute.donations),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.goNamed(AppRoute.profileEdit),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(label,
                style: AppTypography.bodyStrong
                    .copyWith(color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}

/// Raccourci : badge hexagonal (icône) surmontant un libellé, tappable.
class _BadgeShortcut extends StatelessWidget {
  const _BadgeShortcut({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          ClipPath(
            clipper: _HexagonClipper(),
            child: Container(
              width: 46,
              height: 52,
              color: Colors.white,
              child: Center(child: Icon(icon, color: color, size: 24)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.caption
                .copyWith(color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }
}

/// Découpe une forme hexagonale (badges).
class _HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width, size.height * 0.25)
      ..lineTo(size.width, size.height * 0.75)
      ..lineTo(size.width * 0.5, size.height)
      ..lineTo(0, size.height * 0.75)
      ..lineTo(0, size.height * 0.25)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
