import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/echanges_view.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/event_time.dart';
import '../app_avatar.dart';

/// Bulle de message d'une discussion.
///
/// - Reçu : aligné à gauche, fond clair, avatar + nom de l'auteur.
/// - Envoyé : aligné à droite, fond secondaire, heure + état d'envoi.
///
/// ## Elle ne se rend **que** pour une origine en bulle
///
/// Deux des trois origines de [MessageOrigin] : un membre, et un **auteur
/// retiré**. Le message système, lui, est un `ChatInfoBanner`, et c'est l'écran
/// qui choisit entre les deux — sur `message.origin.isBubble`, jamais sur un
/// auteur absent.
///
/// ## L'auteur retiré porte un **fait**, pas un nom
///
/// Ligne d'auteur « Membre retiré » (`chatAuthorRemoved`), et
/// [AppAvatar.neutral] — un constructeur **sans paramètre `name`**, pour que le
/// libellé ne puisse pas se glisser là où il produirait les initiales « MR » et
/// une couleur dérivée de sa longueur. C'est la même règle que les quatre
/// absences : l'absence s'affiche comme une absence, mais ici la personne est
/// **partie**, et le dire est plus juste que ne rien dire.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message, this.onAuthorTap});

  final GroupMessageView message;

  /// Tap sur l'auteur (avatar + nom) d'un message **reçu** — ouvre son profil,
  /// d'où l'on peut lui répondre en privé. `null` = non interactif.
  ///
  /// Un **auteur retiré** n'en reçoit jamais : il n'y a plus de profil à ouvrir,
  /// et une zone qui ne répond pas se lit comme un bug. C'est l'écran qui le
  /// décide, sur l'origine.
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l = context.l10n;
    final mine = message.mine;
    final removed = message.origin == MessageOrigin.removedAuthor;

    // Le libellé d'un auteur retiré est un **fait d'interface** ; celui d'un
    // membre est une **donnée**, et il peut manquer (profil pas encore arrivé, ou
    // compte sans nom). Dans ce dernier cas la ligne ne se rend pas : jamais
    // d'« Utilisateur inconnu », qui ressemblerait à une donnée.
    final authorLine = removed ? l.chatAuthorRemoved : message.authorName;

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
          if (!mine && authorLine != null) ...[
            GestureDetector(
              onTap: onAuthorTap,
              child: Text(
                authorLine,
                style: AppTypography.caption.copyWith(
                  // L'auteur retiré n'est pas un lien : sa ligne reste en teinte
                  // secondaire, là où le nom d'un membre porte la couleur de
                  // marque qui dit « on peut toucher ».
                  color: removed ? palette.textSecondary : palette.primary,
                  fontWeight: FontWeight.w700,
                  fontStyle: removed ? FontStyle.italic : null,
                ),
              ),
            ),
            const SizedBox(height: 2),
          ],
          Text(
            message.body,
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
              // L'heure est **formatée ici**, depuis un instant : le serveur ne
              // sert pas de texte pré-formaté, et un fuseau se résout dans la vue.
              // Un instant absent ne se rend pas, plutôt qu'une date inventée.
              if (message.createdAt != null)
                Text(
                  formatMessageTime(message.createdAt!, l.localeName),
                  style: AppTypography.caption.copyWith(
                    fontSize: 10,
                    color: mine
                        ? Colors.white.withValues(alpha: 0.8)
                        : palette.textSecondary,
                  ),
                ),
              if (mine) ...[
                const SizedBox(width: 3),
                _DeliveryMark(delivery: message.delivery),
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
              // `AppAvatar.neutral` **ne prend pas de nom** : le libellé de
              // l'auteur retiré ne peut donc pas s'y glisser.
              child: removed
                  ? const AppAvatar.neutral(size: 32)
                  : AppAvatar(name: message.authorName ?? '', size: 32),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

/// L'état d'envoi, sur un message **à moi** et nulle part ailleurs.
///
/// Trois marques, et c'est le prix de l'écho optimiste (décision 2 du cadrage) :
/// un message paraît avant d'être parti, donc l'écran doit dire où il en est.
/// L'ancienne double coche « lu » a disparu — les accusés de lecture sont
/// explicitement hors de la V1 (PRD), et une coche qui ne mesure rien est un
/// mensonge visuel.
class _DeliveryMark extends StatelessWidget {
  const _DeliveryMark({required this.delivery});

  final MessageDelivery delivery;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (delivery) {
      MessageDelivery.sent => (
          Icons.check,
          Colors.white.withValues(alpha: 0.9)
        ),
      MessageDelivery.sending => (
          Icons.schedule,
          Colors.white.withValues(alpha: 0.7),
        ),
      // L'échec est le seul qui change de teinte : il demande un geste.
      MessageDelivery.failed => (Icons.error_outline, AppColors.accent),
    };

    return Icon(icon, size: 14, color: color);
  }
}
