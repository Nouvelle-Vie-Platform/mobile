import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../state/repository_providers.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/cards/group_tile.dart';

/// Onglet « Groupes » : liste des groupes communautaires.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);

    return SafeArea(
      child: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          const SizedBox(height: AppSpacing.md),
          Text('Mes groupes', style: AppTypography.h2),
          const SizedBox(height: AppSpacing.lg),
          for (final g in groups) ...[
            GroupTile(
              group: g,
              onTap: () => context.pushNamed(AppRoute.groupChat, extra: g),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.sm),
          AppButton(label: 'Découvrir plus de groupes', onPressed: () {}),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
