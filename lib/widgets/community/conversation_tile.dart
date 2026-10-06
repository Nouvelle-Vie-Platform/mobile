import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/echanges_view.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/event_time.dart';
import '../app_avatar.dart';
import '../app_card.dart';
import '../unread_badge.dart';
import 'muted_indicator.dart';

/// Tuile d'une conversation du hub « Échanges » : avatar, nom, aperçu du
/// dernier message et horodatage. Le tap ouvre le chat (décision D7).
///
/// **Aucune icône visio/audio** (décision D8) : il n'existe aucun backend
/// d'appel, la tuile ne fait qu'ouvrir la discussion.
///
/// ## Trois absences qui se rendent comme des absences
///
/// Un groupe sans message encore arrivé **n'a pas d'aperçu** et **pas
/// d'horodatage** : les deux lignes ne se rendent pas, plutôt que d'afficher un
/// vide qui ressemblerait à un message effacé. Et la tuile paraît quand même —
/// c'est la conversation qu'on vient de rejoindre, et la cacher pour défaut de
/// message serait la pire chose à faire.
class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    this.onTap,
    this.typingLabel,
  });

  final ConversationView conversation;
  final VoidCallback? onTap;

  /// **« Ama écrit… »** (#142, M3) — prend la place de l'aperçu tant que
  /// quelqu'un écrit, dans la teinte de marque, comme WhatsApp. `null` :
  /// l'aperçu du dernier message.
  final String? typingLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l = context.l10n;
    final stamp = conversation.lastMessageAt;
    // **Un dernier message sans texte est un média** (#140) : il y a un instant,
    // mais pas de phrase. On le dit, plutôt que de laisser croire au vide.
    final preview = typingLabel ??
        (conversation.lastMessageDeleted
            // M2 (#141) : un dernier message supprimé pour tous le dit.
            ? l.chatMessageDeleted
            : conversation.lastMessagePreview ??
                (stamp != null ? l.echangesMediaPreview : null));
    final unread = conversation.unreadCount;

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
                  conversation.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // Une conversation qui attend une lecture se voit : titre
                  // plus appuyé, comme l'heure et la pastille à droite.
                  style: unread > 0
                      ? AppTypography.bodyStrong
                          .copyWith(fontWeight: FontWeight.w800)
                      : AppTypography.bodyStrong,
                ),
                if (preview != null && preview.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    // La troncature vit **ici** et non dans le modèle : c'est la
                    // tuile qui connaît sa largeur, et le serveur ne sert pas de
                    // texte pré-formaté.
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: typingLabel != null
                          ? palette.primary
                          : palette.textSecondary,
                      fontStyle: typingLabel != null ? FontStyle.italic : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (stamp != null ||
              unread > 0 ||
              conversation.pinned ||
              conversation.isMuted) ...[
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (stamp != null)
                  Text(
                    formatConversationStamp(stamp, l.localeName),
                    style: AppTypography.caption
                        .copyWith(color: palette.textSecondary),
                  ),
                // La sourdine (M5) : sous l'heure, avant la pastille.
                if (conversation.isMuted) ...[
                  const SizedBox(height: 4),
                  const MutedIndicator(),
                ],
                if (unread > 0) ...[
                  const SizedBox(height: 4),
                  UnreadBadge(count: unread),
                ],
                // M8 (#146) : une discussion épinglée le montre.
                if (conversation.pinned) ...[
                  const SizedBox(height: 4),
                  Icon(
                    Icons.push_pin,
                    key: const Key('conversation_pinned_icon'),
                    size: 14,
                    color: palette.textSecondary,
                    semanticLabel: l.chatPinnedLabel,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Avatar de la conversation, avec une pastille discrète signalant un **groupe**
/// (plusieurs participants) — le seul rôle du discriminant à l'écran.
///
/// Pour un tête-à-tête, l'avatar porte le nom de l'autre ; pour un groupe, celui
/// du groupe. L'avatar **neutre** sert quand il n'y a aucun nom à montrer — un
/// tête-à-tête dont le profil de l'autre n'est pas encore arrivé.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.conversation});

  final ConversationView conversation;

  @override
  Widget build(BuildContext context) {
    final title = conversation.title;
    final avatar = title.trim().isEmpty
        ? const AppAvatar.neutral(size: 48)
        : AppAvatar(name: title, size: 48);
    if (conversation.isDirect) return avatar;

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
