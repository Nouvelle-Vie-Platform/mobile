/// **Le menu d'action flottant** (M2, #200), posé par le lecteur sous la
/// sélection : une rangée d'actions (les `verseActions` de toutes les
/// tranches — copier, favori, note, partager ; écouter, studio… pour M4), et
/// la palette des cinq pastels avec « effacer ».
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_typography.dart';
import '../data/canon.dart';
import '../shell/bible_slots.dart';
import 'bible_marks_store.dart';
import 'bible_verse_actions.dart';

class BibleVerseMenu extends ConsumerWidget {
  const BibleVerseMenu({
    super.key,
    required this.selection,
    required this.versionCode,
    required this.actions,
    required this.onDone,
  });

  final BibleLink selection;
  final String versionCode;
  final List<BibleVerseAction> actions;

  /// Appelé après un geste : le lecteur lève la sélection.
  final VoidCallback onDone;

  static const Key menuKey = Key('bible_verse_menu');
  static const Key clearKey = Key('bible_highlight_clear');
  static Key colorKey(String color) => Key('bible_highlight_$color');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const fg = Colors.white;
    return Material(
      key: menuKey,
      color: AppColors.neutralDark,
      elevation: 10,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final a in actions)
                    InkWell(
                      key: Key('bible_action_${a.id}'),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      onTap: () {
                        onDone();
                        a.run(context, ref, selection, versionCode);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(a.icon, color: fg, size: 22),
                            const SizedBox(height: 2),
                            Text(
                              a.label(context),
                              style: AppTypography.caption.copyWith(
                                color: fg,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final MapEntry(key: name, value: color)
                    in bibleHighlightColors.entries)
                  _Swatch(
                    key: colorKey(name),
                    color: color,
                    tooltip: context.l10n.bibleM2Highlight,
                    onTap: () {
                      onDone();
                      highlightVerses(ref, selection, name);
                    },
                  ),
                _Swatch(
                  key: clearKey,
                  tooltip: context.l10n.bibleM2ClearHighlight,
                  onTap: () {
                    onDone();
                    highlightVerses(ref, selection, null);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    this.color,
    required this.tooltip,
    required this.onTap,
  });

  /// `null` : la pastille « effacer ».
  final Color? color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white70, width: 1.5),
            ),
            child: color == null
                ? const Icon(
                    Icons.format_color_reset,
                    size: 16,
                    color: Colors.white,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
