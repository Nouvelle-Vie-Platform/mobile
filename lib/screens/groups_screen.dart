import 'package:flutter/material.dart';

import '../data/sample_data.dart';
import '../routes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../widgets/cards/group_tile.dart';

/// Onglet « Groupes » : liste des groupes communautaires.
class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          const SizedBox(height: AppSpacing.md),
          Text('Mes groupes', style: AppTypography.h2),
          const SizedBox(height: AppSpacing.lg),
          for (final g in SampleData.groups) ...[
            GroupTile(
              group: g,
              onTap: () => Navigator.pushNamed(context, AppRoutes.groupChat),
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
