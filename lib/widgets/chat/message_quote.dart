import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/echanges_view.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// **La citation d'une réponse** (M2, #141 ; décision 11) — dans la bulle, et
/// au-dessus du champ pendant qu'on rédige la réponse.
///
/// Une barre de couleur, l'auteur cité (« Vous » quand c'est moi), puis
/// l'extrait — ou, à défaut, ce que le message était : « Message vocal »,
/// « Photo », « Média », ou « Message supprimé » quand l'origine a été supprimée
/// pour tous. Un auteur sans nom en magasin n'a pas de ligne d'auteur : jamais
/// d'« Utilisateur inconnu », qui ressemblerait à une donnée.
///
/// [onTap] : **toucher la citation fait défiler jusqu'au message d'origine**
/// (l'écran s'en charge).
class MessageQuote extends StatelessWidget {
  const MessageQuote({
    super.key,
    required this.quote,
    this.onTap,
    this.onDarkBubble = false,
  });

  final MessageQuoteView quote;
  final VoidCallback? onTap;

  /// La citation est peinte dans **ma** bulle (fond de marque) : texte clair.
  final bool onDarkBubble;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l = context.l10n;
    final author = quote.mine ? l.chatQuoteYou : quote.authorName;
    final text = quoteText(context, quote);
    final textColor = onDarkBubble
        ? Colors.white.withValues(alpha: 0.85)
        : palette.textSecondary;

    return GestureDetector(
      key: const Key('message_quote'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: onDarkBubble
              ? Colors.white.withValues(alpha: 0.15)
              : palette.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border(
            left: BorderSide(
              color: onDarkBubble ? Colors.white : palette.primary,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (author != null)
              Text(
                author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: onDarkBubble ? Colors.white : palette.primary,
                ),
              ),
            Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: textColor,
                fontStyle: quote.excerpt == null || quote.deleted
                    ? FontStyle.italic
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// **Ce que dit une citation**, écrit une fois : l'extrait, ou ce que le
  /// message était.
  static String quoteText(BuildContext context, MessageQuoteView quote) {
    final l = context.l10n;
    if (quote.deleted) return l.chatQuoteDeleted;
    final excerpt = quote.excerpt;
    if (excerpt != null && excerpt.isNotEmpty) return excerpt;
    return switch (quote.mediaKind) {
      'audio' || 'voice' => l.chatQuoteAudio,
      'image' => l.chatQuoteImage,
      // Les formes de M4 (#143).
      'video' => l.m4QuoteVideo,
      'document' => l.m4QuoteDocument,
      'location' => l.m4QuoteLocation,
      'contact' => l.m4QuoteContact,
      _ => l.chatQuoteMedia,
    };
  }
}

/// **Ce qui se passe au-dessus du champ** (M2, #141) : la réponse en cours (la
/// citation du message visé) ou la modification en cours. Une croix l'annule.
class ComposerContextBar extends StatelessWidget {
  const ComposerContextBar.reply({
    super.key,
    required MessageQuoteView this.quote,
    required this.onCancel,
  }) : editing = false;

  const ComposerContextBar.edit({super.key, required this.onCancel})
      : quote = null,
        editing = true;

  final MessageQuoteView? quote;
  final bool editing;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l = context.l10n;
    final quote = this.quote;

    final String title;
    if (editing) {
      title = l.chatEditing;
    } else if (quote!.mine) {
      title = l.chatReplyingTo(l.chatQuoteYou);
    } else if (quote.authorName != null) {
      title = l.chatReplyingTo(quote.authorName!);
    } else {
      title = l.chatReplying;
    }

    return Container(
      key: Key(editing ? 'composer_edit_bar' : 'composer_reply_bar'),
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        0,
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border(left: BorderSide(color: palette.primary, width: 3)),
      ),
      child: Row(
        children: [
          Icon(
            editing ? Icons.edit_outlined : Icons.reply,
            size: 18,
            color: palette.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: palette.primary,
                  ),
                ),
                if (quote != null)
                  Text(
                    MessageQuote.quoteText(context, quote),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption
                        .copyWith(color: palette.textSecondary),
                  ),
              ],
            ),
          ),
          IconButton(
            key: const Key('composer_context_cancel'),
            tooltip: editing ? l.chatCancelEdit : l.chatCancelReply,
            icon: const Icon(Icons.close, size: 18),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// **L'en-tête d'une bulle** (M2, #141) : « Transféré », puis la citation d'une
/// réponse. Rend `null` quand il n'y a rien à dire — l'écran ne passe alors
/// aucun en-tête à la bulle.
Widget? messageBubbleHeader(
  BuildContext context,
  GroupMessageView message, {
  VoidCallback? onQuoteTap,
}) {
  if (message.deleted) return null;
  final quote = message.quote;
  if (!message.forwarded && quote == null) return null;
  final palette = context.palette;
  final mine = message.mine;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (message.forwarded)
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            key: const Key('chat_bubble_forwarded'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.forward,
                size: 12,
                color: mine
                    ? Colors.white.withValues(alpha: 0.8)
                    : palette.textSecondary,
              ),
              const SizedBox(width: 2),
              Text(
                context.l10n.chatMessageForwarded,
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: mine
                      ? Colors.white.withValues(alpha: 0.8)
                      : palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      if (quote != null)
        MessageQuote(quote: quote, onTap: onQuoteTap, onDarkBubble: mine),
    ],
  );
}
