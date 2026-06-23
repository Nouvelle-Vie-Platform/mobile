import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_card.dart';
import '../media_thumbnail.dart';

/// Ligne d'enseignement (médiathèque, derniers enseignements).
class TeachingTile extends StatelessWidget {
  const TeachingTile({super.key, required this.teaching, this.onTap});

  final Teaching teaching;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          MediaThumbnail(width: 76, height: 64, seed: teaching.seed),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(teaching.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyStrong),
                const SizedBox(height: 4),
                Text('${teaching.author} • ${teaching.duration}',
                    style: AppTypography.caption
                        .copyWith(color: palette.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.play_circle_fill, color: palette.primary, size: 30),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
    );
  }
}
