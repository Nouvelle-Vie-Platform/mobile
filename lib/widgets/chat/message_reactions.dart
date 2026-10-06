import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/echanges_view.dart';
import '../../models/message_gesture_rules.dart';
import '../../state/echanges_providers.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// **L'agrégat des réactions sous une bulle** (M2, #141) — une pastille par
/// emoji, son compte quand il dépasse un, la mienne surlignée. Le toucher
/// montre qui a réagi ([onTap]).
class MessageReactionsRow extends StatelessWidget {
  const MessageReactionsRow({
    super.key,
    required this.reactions,
    required this.alignEnd,
    this.onTap,
  });

  final List<MessageReactionView> reactions;

  /// Sous ma bulle (à droite) ou sous celle d'un autre (à gauche).
  final bool alignEnd;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    final palette = context.palette;

    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        key: const Key('message_reactions'),
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.only(
            left: alignEnd ? 0 : 40,
            top: 2,
            bottom: AppSpacing.xs,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: palette.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final reaction in reactions)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    reaction.count > 1
                        ? '${reaction.emoji} ${reaction.count}'
                        : reaction.emoji,
                    style: AppTypography.caption.copyWith(
                      fontSize: 13,
                      fontWeight: reaction.mine ? FontWeight.w700 : null,
                      color:
                          reaction.mine ? palette.primary : palette.textPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// **Le jeu rapide de réactions**, en tête du menu d'appui long : les six de
/// WhatsApp et « + ». La mienne est surlignée — la retoucher la retire.
class QuickReactionsBar extends StatelessWidget {
  const QuickReactionsBar({
    super.key,
    required this.current,
    required this.onPick,
    required this.onMore,
  });

  final String? current;
  final ValueChanged<String> onPick;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final emoji in kQuickReactions)
            _EmojiButton(
              key: Key('quick_reaction_$emoji'),
              emoji: emoji,
              selected: emoji == current,
              onTap: () => onPick(emoji),
            ),
          IconButton(
            key: const Key('quick_reaction_more'),
            tooltip: context.l10n.chatMoreReactions,
            onPressed: onMore,
            icon: Icon(Icons.add_circle_outline, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _EmojiButton extends StatelessWidget {
  const _EmojiButton({
    super.key,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? palette.primary.withValues(alpha: 0.15) : null,
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 26)),
      ),
    );
  }
}

/// **« + » : le reste des réactions** — une grille sobre de [kMoreReactions].
/// Rend l'emoji choisi, ou `null`.
Future<String?> showMoreReactionsSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (sheet) => SafeArea(
      child: GridView.count(
        key: const Key('more_reactions_grid'),
        crossAxisCount: 8,
        shrinkWrap: true,
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          for (final emoji in [...kQuickReactions, ...kMoreReactions])
            InkResponse(
              key: Key('more_reaction_$emoji'),
              onTap: () => Navigator.of(sheet).pop(emoji),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
        ],
      ),
    ),
  );
}

/// **Qui a réagi** (M2, #141) — ouvert en touchant l'agrégat. Une ligne par
/// personne, la mienne en premier : la toucher retire ma réaction ([onRemove]).
Future<void> showReactorsSheet(
  BuildContext context, {
  required String? actor,
  required String messageId,
  required VoidCallback onRemove,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Consumer(
        builder: (context, ref, _) {
          final l = context.l10n;
          final palette = context.palette;
          final reactors = ref
                  .watch(
                    messageReactorsProvider((actor: actor, id: messageId)),
                  )
                  .value ??
              const <ReactorView>[];
          final ordered = [
            ...reactors.where((r) => r.mine),
            ...reactors.where((r) => !r.mine),
          ];
          return Column(
            key: const Key('reactors_sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  l.chatReactionsTitle,
                  style:
                      AppTypography.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              for (final reactor in ordered)
                ListTile(
                  key: Key('reactor_${reactor.userId}'),
                  leading: Text(
                    reactor.emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                  // Un nom absent ne se remplace pas par un faux : la ligne
                  // garde son emoji, sans titre.
                  title: Text(
                    reactor.mine ? l.chatQuoteYou : (reactor.displayName ?? ''),
                  ),
                  subtitle: reactor.mine
                      ? Text(
                          l.chatReactionsRemove,
                          style: AppTypography.caption
                              .copyWith(color: palette.textSecondary),
                        )
                      : null,
                  onTap: reactor.mine
                      ? () {
                          Navigator.of(sheet).pop();
                          onRemove();
                        }
                      : null,
                ),
            ],
          );
        },
      ),
    ),
  );
}
