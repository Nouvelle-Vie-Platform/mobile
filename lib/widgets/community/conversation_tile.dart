import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/echanges_view.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/event_time.dart';
import '../app_avatar.dart';
import '../app_card.dart';

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
  const ConversationTile({super.key, required this.conversation, this.onTap});

  final ConversationView conversation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l = context.l10n;
    final preview = conversation.lastMessagePreview;
    final stamp = conversation.lastMessageAt;

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
                  style: AppTypography.bodyStrong,
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
                    style: AppTypography.caption
                        .copyWith(color: palette.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (stamp != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              formatConversationStamp(stamp, l.localeName),
              style:
                  AppTypography.caption.copyWith(color: palette.textSecondary),
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
