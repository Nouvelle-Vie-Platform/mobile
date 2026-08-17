import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_avatar.dart';

/// Bulle de message d'une discussion.
///
/// - Reçu : aligné à gauche, fond clair, avatar + nom de l'auteur.
/// - Envoyé : aligné à droite, fond secondaire, heure + accusé de lecture.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message, this.onAuthorTap});

  final ChatMessage message;

  /// Tap sur l'auteur (avatar + nom) d'un message **reçu** — ouvre son profil,
  /// d'où l'on peut lui répondre en privé. `null` = non interactif.
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final mine = message.mine;

    final bubble = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: mine ? AppColors.secondary : palette.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(AppRadius.lg),
          topRight: const Radius.circular(AppRadius.lg),
          bottomLeft: Radius.circular(mine ? AppRadius.lg : 4),
          bottomRight: Radius.circular(mine ? 4 : AppRadius.lg),
        ),
        border: mine ? null : Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne d'auteur **seulement si un nom existe** : au réel, le mobile
          // n'a pas de source de nom de membre (ADR-0029), et « auteur retiré »
          // n'a pas de nom non plus — pas de ligne vide, pas d'« inconnu ».
          if (!mine && message.author.isNotEmpty) ...[
            GestureDetector(
              onTap: onAuthorTap,
              child: Text(
                message.author,
                style: AppTypography.caption.copyWith(
                    color: palette.primary, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 2),
          ],
          Text(
            message.text,
            style: AppTypography.body.copyWith(
              fontSize: 14,
              color: mine ? Colors.white : palette.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                message.time,
                style: AppTypography.caption.copyWith(
                  fontSize: 10,
                  color: mine
                      ? Colors.white.withValues(alpha: 0.8)
                      : palette.textSecondary,
                ),
              ),
              if (mine) ...[
                const SizedBox(width: 3),
                // Accusé de lecture (double coche).
                Icon(Icons.done_all,
                    size: 14, color: Colors.white.withValues(alpha: 0.9)),
              ],
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            GestureDetector(
              onTap: onAuthorTap,
              child: AppAvatar(name: message.author, size: 32),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}
