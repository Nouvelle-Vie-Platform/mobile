/// **La pilule d'action flottante** (M2, #200), posée par le lecteur
/// au-dessus de la sélection : la palette des cinq pastels, « effacer », puis
/// les actions des tranches (`verseActions` — copier, favori, note, partager ;
/// écouter, studio… pour M4).
///
/// Elle était une boîte sombre à deux étages, libellés compris. Les références
/// de #250 montrent **une seule rangée d'icônes dans une pilule translucide**,
/// qui laisse deviner le verset derrière elle : d'où le flou de fond, la forme
/// de stade, et les libellés passés en infobulle — le sens reste accessible,
/// mais il ne mange plus deux lignes au-dessus du texte.
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_spacing.dart';
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
    final l = context.l10n;
    final palette = context.palette;
    return Material(
      key: menuKey,
      color: Colors.transparent,
      elevation: 8,
      shadowColor: Colors.black38,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        // Le flou est ce qui fait la pilule « translucide » : sans lui, un
        // fond à 80 % n'est qu'un gris sale.
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: ColoredBox(
          color: palette.surface.withValues(alpha: 0.82),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final MapEntry(key: name, value: color)
                    in bibleHighlightColors.entries)
                  _Swatch(
                    key: colorKey(name),
                    color: color,
                    tooltip: l.bibleM2Highlight,
                    onTap: () {
                      onDone();
                      highlightVerses(ref, selection, name);
                    },
                  ),
                _Swatch(
                  key: clearKey,
                  tooltip: l.bibleM2ClearHighlight,
                  onTap: () {
                    onDone();
                    highlightVerses(ref, selection, null);
                  },
                ),
                Container(
                  width: 1,
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  color: palette.divider,
                ),
                for (final a in actions)
                  Tooltip(
                    message: a.label(context),
                    child: InkResponse(
                      key: Key('bible_action_${a.id}'),
                      radius: 24,
                      onTap: () {
                        onDone();
                        a.run(context, ref, selection, versionCode);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Icon(
                          a.icon,
                          size: 22,
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
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
    final palette = context.palette;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 5,
            vertical: AppSpacing.sm,
          ),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: palette.border, width: 1.5),
            ),
            child: color == null
                ? Icon(
                    Icons.format_color_reset,
                    size: 14,
                    color: palette.textSecondary,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
