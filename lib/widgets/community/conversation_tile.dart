import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_avatar.dart';
import '../app_card.dart';

/// Tuile d'une conversation du hub « Échanges » : avatar, nom, aperçu du
/// dernier message et heure. Le tap ouvre le chat (décision D7).
///
/// **Aucune icône visio/audio** (décision D8) : il n'existe aucun backend
/// d'appel, la tuile ne fait qu'ouvrir la discussion.
class ConversationTile extends StatelessWidget {
  const ConversationTile({super.key, required this.conversation, this.onTap});

  final Conversation conversation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          _Avatar(conversation: conversation),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyStrong,
                ),
                const SizedBox(height: 2),
                Text(
                  conversation.lastMessagePreview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption
                      .copyWith(color: palette.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            conversation.time,
            style: AppTypography.caption.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Avatar de la conversation, avec une pastille discrète signalant un **groupe**
/// (plusieurs participants) — le seul rôle du discriminant à l'écran.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final avatar = AppAvatar(name: conversation.name, size: 48);
    if (conversation.kind != ConversationKind.group) return avatar;

    final palette = context.palette;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: palette.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.groups, size: 13, color: palette.textSecondary),
          ),
        ),
      ],
    );
  }
}
