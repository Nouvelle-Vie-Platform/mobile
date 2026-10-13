import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../models/models.dart';
import '../router/app_router.dart';
import '../features/bible/shell/bible_shell.dart';
import '../state/auth_providers.dart';
import '../state/branch_scope_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_avatar.dart';
import '../widgets/menu_tile.dart';
import '../widgets/notification_preview_tile.dart';
import '../widgets/profile_completion_banner.dart';
import '../widgets/theme_sheet.dart';

/// Écran « Profil » : en-tête de marque (avatar, rôle, branche, statistiques,
/// badges) surmontant une feuille de réglages.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.showBack = false});

  final bool showBack;

  static const Key deleteAccountKey = Key('profile_delete_account');

  /// L'entrée « Confidentialité » (#142).
  static const Key privacyKey = Key('profile_privacy');
  static const Key themeButtonKey = Key('profile_theme_button');

  /// La ligne « Mon assemblée » (#184).
  static const Key branchScopeKey = Key('profile_branch_scope');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final palette = context.palette;

    final user = ref.watch(authProvider).user;
    final branches = ref.watch(branchesProvider).value ?? const <Branch>[];

    final displayName =
        user == null ? '' : user.displayName(l.userTitleLabel(user.title));
    final name = displayName.isEmpty ? l.profileRole : displayName;

    String branchLabel = l.statusNewLabel;
    if (user != null &&
        user.status != UserStatus.newcomer &&
        user.branchId != null) {
      branchLabel = l.profileMyBranch;
      for (final b in branches) {
        if (b.id == user.branchId) {
          branchLabel = b.name;
          break;
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _ProfileHeader(
            name: name,
            role: l.profileRole,
            branch: branchLabel,
            showBack: showBack,
          ),
          Expanded(
            child: Material(
              color: palette.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              clipBehavior: Clip.antiAlias,
              child: ListView(
                padding: EdgeInsets.only(
                  top: AppSpacing.md,
                  bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
                ),
                children: [
                  if (user != null && !user.profileComplete) ...[
                    Padding(
                      padding: AppSpacing.screenPadding,
                      child: const ProfileCompletionBanner(),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  // #142 (M3) : accusés de lecture, vu à / en ligne.
                  if (user != null) ...[
                    MenuTile(
                      key: ProfileScreen.privacyKey,
                      icon: Icons.lock_outline,
                      label: l.privacyMenu,
                      subtitle: l.privacyMenuSubtitle,
                      onTap: () => context.pushNamed(AppRoute.privacySettings),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  // Mon assemblée (#184) — sortie de la page Qualité.
                  const _BranchScopeTile(),
                  const SizedBox(height: AppSpacing.sm),
                  // Le contenu des notifications de messages (M5).
                  const NotificationPreviewTile(),
                  const SizedBox(height: AppSpacing.sm),
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
                    onTap: () => _confirmSignOut(context, ref),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  MenuTile(
                    key: ProfileScreen.deleteAccountKey,
                    icon: Icons.person_remove_outlined,
                    label: l.deleteAccount,
                    destructive: true,
                    onTap: () => context.pushNamed(AppRoute.profileDelete),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.role,
    required this.branch,
    this.showBack = false,
  });

  final String name;
  final String role;
  final String branch;
  final bool showBack;

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (showBack)
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => context.pop(),
                      ),
                    Text(l.navProfile,
                        style: AppTypography.h2.copyWith(color: Colors.white)),
                  ],
                ),
                IconButton(
                  key: ProfileScreen.themeButtonKey,
                  icon: const Icon(Icons.brightness_6, color: Colors.white),
                  tooltip: l.themeSectionTitle,
                  onPressed: () => showThemeSheet(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: _BadgeShortcut(
                    icon: Icons.download_rounded,
                    label: l.profileDownloads,
                    color: AppColors.primary,
                    onTap: () => context.pushNamed(AppRoute.downloads),
                  ),
                ),
                Expanded(
                  child: _BadgeShortcut(
                    icon: Icons.menu_book,
                    label: l.profileStatNotes,
                    color: const Color(0xFF7A5AF8),
                    onTap: () => context.pushNamed(
                      AppRoute.bible,
                      queryParameters: {'tab': BibleModuleTab.notes.name},
                    ),
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
                    icon: Icons.tune,
                    label: l.mediaSettings,
                    color: AppColors.secondary,
                    onTap: () => context.pushNamed(AppRoute.mediaSettings),
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

/// **Mon assemblée**, et l'assemblée choisie en sous-titre.
///
/// Les deux lectures sont ponctuelles (voir `preferredBranchProvider`) ; la
/// page invalide la préférence après un choix, et le sous-titre suit.
class _BranchScopeTile extends ConsumerWidget {
  const _BranchScopeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final selected = ref.watch(preferredBranchProvider).value;
    final branches = ref.watch(branchScopeChoicesProvider).value ?? const [];
    var subtitle = l.branchScopeAll;
    for (final branch in branches) {
      if (branch.id == selected) subtitle = branch.name;
    }

    return MenuTile(
      key: ProfileScreen.branchScopeKey,
      icon: Icons.church_outlined,
      label: l.branchScopeTitle,
      subtitle: subtitle,
      onTap: () => context.pushNamed(AppRoute.branchScope),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.pushNamed(AppRoute.profileEdit),
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
