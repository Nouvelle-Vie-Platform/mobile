import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../router/app_router.dart';
import '../state/theme_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_avatar.dart';
import '../widgets/menu_tile.dart';

/// Onglet « Profil » : en-tête membre et menu de réglages.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final dark = isDarkModeActive(mode, context);

    return ListView(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      children: [
        const _ProfileHeader(
            name: 'Jean Kossi', since: 'Membre depuis Mai 2023'),
        const SizedBox(height: AppSpacing.sm),
        MenuTile(
          icon: Icons.account_balance_outlined,
          label: context.l10n.profileMyBranch,
          subtitle: 'Église Mère - Lomé',
          onTap: () {},
        ),
        const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
        MenuTile(
          icon: Icons.volunteer_activism_outlined,
          label: context.l10n.profileMyContributions,
          onTap: () => context.pushNamed(AppRoute.donations),
        ),
        const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
        MenuTile(
          icon: Icons.menu_book_outlined,
          label: context.l10n.profileMyNotes,
          onTap: () => context.pushNamed(AppRoute.notes),
        ),
        const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
        MenuTile(
          icon: Icons.dark_mode_outlined,
          label: context.l10n.darkMode,
          showChevron: false,
          onTap: () =>
              ref.read(themeModeProvider.notifier).toggle(platformIsDark: dark),
          trailing: Switch.adaptive(
            value: dark,
            onChanged: (_) => ref
                .read(themeModeProvider.notifier)
                .toggle(platformIsDark: dark),
            activeTrackColor: AppColors.secondary,
          ),
        ),
        const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
        MenuTile(
            icon: Icons.settings_outlined,
            label: context.l10n.settings,
            onTap: () {}),
        const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
        MenuTile(
            icon: Icons.help_outline,
            label: context.l10n.helpSupport,
            onTap: () {}),
        const SizedBox(height: AppSpacing.sm),
        MenuTile(
          icon: Icons.logout,
          label: context.l10n.logout,
          destructive: true,
          onTap: () => context.goNamed(AppRoute.login),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.name, required this.since});
  final String name;
  final String since;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        MediaQuery.of(context).padding.top + AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      decoration: const BoxDecoration(gradient: AppColors.gradientPrimary),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: AppAvatar(name: name, size: 60),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.h4.copyWith(color: Colors.white)),
                const SizedBox(height: 4),
                Text(since,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body
                        .copyWith(color: Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
