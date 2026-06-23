import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_avatar.dart';

/// Bulle de message de discussion de groupe.
///
/// - Messages reçus : alignés à gauche, fond clair, avatar + nom.
/// - Messages envoyés : alignés à droite, fond vert secondaire.
/// - Messages système : centrés, fond neutre.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (message.system) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: palette.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(message.text,
              textAlign: TextAlign.center,
              style:
                  AppTypography.caption.copyWith(color: palette.textSecondary)),
        ),
      );
    }

    final bubble = Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: message.mine ? AppColors.secondary : palette.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(AppRadius.lg),
          topRight: const Radius.circular(AppRadius.lg),
          bottomLeft: Radius.circular(message.mine ? AppRadius.lg : 4),
          bottomRight: Radius.circular(message.mine ? 4 : AppRadius.lg),
        ),
        border: message.mine ? null : Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.mine)
            Text(message.author,
                style: AppTypography.caption.copyWith(
                    color: palette.primary, fontWeight: FontWeight.w700)),
          if (!message.mine) const SizedBox(height: 2),
          Text(
            message.text,
            style: AppTypography.bodyLarge.copyWith(
              fontSize: 14,
              color: message.mine ? Colors.white : palette.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message.time,
            style: AppTypography.caption.copyWith(
              fontSize: 10,
              color: message.mine
                  ? Colors.white.withValues(alpha: 0.8)
                  : palette.textSecondary,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            message.mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.mine) ...[
            AppAvatar(name: message.author, size: 32),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}
