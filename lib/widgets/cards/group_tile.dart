import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_avatar.dart';
import '../app_card.dart';

/// Ligne de groupe communautaire (nom, nombre de membres, rôle).
class GroupTile extends StatelessWidget {
  const GroupTile({super.key, required this.group, this.onTap});

  final CommunityGroup group;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          AppAvatar(name: group.name, size: 46),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name, style: AppTypography.bodyStrong),
                const SizedBox(height: 3),
                Text(
                  group.role == null
                      ? '${group.members} membres'
                      : '${group.members} membres • ${group.role}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.palette.textSecondary),
        ],
      ),
    );
  }
}
