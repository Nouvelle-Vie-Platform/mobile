import 'package:flutter/material.dart';

import '../routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_controller.dart';
import '../widgets/app_avatar.dart';
import '../widgets/menu_tile.dart';

/// Onglet « Profil » : en-tête membre et menu de réglages.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const _ProfileHeader(name: 'Jean Kossi', since: 'Membre depuis Mai 2023'),
        const SizedBox(height: AppSpacing.sm),
        MenuTile(
          icon: Icons.account_balance_outlined,
          label: 'Ma branche',
          subtitle: 'Église Mère - Lomé',
          onTap: () {},
        ),
        const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
        MenuTile(
          icon: Icons.volunteer_activism_outlined,
          label: 'Mes contributions',
          onTap: () => Navigator.pushNamed(context, AppRoutes.donations),
        ),
        const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
        MenuTile(
          icon: Icons.menu_book_outlined,
          label: 'Mes notes spirituelles',
          onTap: () => Navigator.pushNamed(context, AppRoutes.notes),
        ),
        const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
        ValueListenableBuilder<ThemeMode>(
          valueListenable: themeModeNotifier,
          builder: (context, _, __) => MenuTile(
            icon: Icons.dark_mode_outlined,
            label: 'Mode sombre',
            showChevron: false,
            onTap: () => toggleTheme(context),
            trailing: Switch.adaptive(
              value: isDarkMode(context),
              onChanged: (_) => toggleTheme(context),
              activeTrackColor: AppColors.secondary,
            ),
          ),
        ),
        const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
        MenuTile(
            icon: Icons.settings_outlined, label: 'Paramètres', onTap: () {}),
        const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
        MenuTile(
            icon: Icons.help_outline, label: 'Aide & Support', onTap: () {}),
        const SizedBox(height: AppSpacing.sm),
        MenuTile(
          icon: Icons.logout,
          label: 'Se déconnecter',
          destructive: true,
          onTap: () => Navigator.pushNamedAndRemoveUntil(
              context, AppRoutes.login, (_) => false),
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
                    style: AppTypography.body.copyWith(
                        color: Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
