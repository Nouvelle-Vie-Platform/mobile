import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Bandeau d'information centré, utilisé pour les messages « système »
/// (annonces, consignes) au fil de la discussion.
class ChatInfoBanner extends StatelessWidget {
  const ChatInfoBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: palette.infoBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 16, color: palette.primary),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: AppTypography.caption
                    .copyWith(color: palette.textSecondary, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
