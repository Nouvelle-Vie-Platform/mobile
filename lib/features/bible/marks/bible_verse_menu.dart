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
///
/// Les cinq pastels y tenaient en ligne ; la référence n'en montre **qu'une**,
/// multicolore, qui déploie la palette. Elle reste donc toujours à gauche et
/// sert d'interrupteur : fermée, la rangée est celle de la référence (effacer,
/// puis les actions) ; ouverte, elle laisse la place aux cinq couleurs. Une
/// rangée, jamais deux, quel que soit l'état.
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

class BibleVerseMenu extends ConsumerStatefulWidget {
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
  static const Key paletteKey = Key('bible_highlight_palette');
  static const Key clearKey = Key('bible_highlight_clear');
  static Key colorKey(String color) => Key('bible_highlight_$color');

  @override
  ConsumerState<BibleVerseMenu> createState() => _BibleVerseMenuState();
}

class _BibleVerseMenuState extends ConsumerState<BibleVerseMenu> {
  /// La palette est-elle déployée ? Fermée, la rangée est celle des
  /// références ; ouverte, elle montre les cinq pastels.
  bool _colors = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;
    return Material(
      key: BibleVerseMenu.menuKey,
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
                _Swatch(
                  key: BibleVerseMenu.paletteKey,
                  tooltip: l.bibleM2Colors,
                  onTap: () => setState(() => _colors = !_colors),
                  child: const _PaletteDot(),
                ),
                if (_colors)
                  for (final MapEntry(key: name, value: color)
                      in bibleHighlightColors.entries)
                    _Swatch(
                      key: BibleVerseMenu.colorKey(name),
                      color: color,
                      tooltip: l.bibleM2Highlight,
                      onTap: () => _run(() => highlightVerses(
                            ref,
                            widget.selection,
                            name,
                          )),
                    )
                else ...[
                  _Swatch(
                    key: BibleVerseMenu.clearKey,
                    tooltip: l.bibleM2ClearHighlight,
                    onTap: () => _run(() => highlightVerses(
                          ref,
                          widget.selection,
                          null,
                        )),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: palette.textSecondary,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    margin:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    color: palette.divider,
                  ),
                  for (final a in widget.actions)
                    Tooltip(
                      message: a.label(context),
                      child: InkResponse(
                        key: Key('bible_action_${a.id}'),
                        radius: 24,
                        onTap: () => _run(() => a.run(
                              context,
                              ref,
                              widget.selection,
                              widget.versionCode,
                            )),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Un geste : la sélection se lève, puis l'action part.
  void _run(VoidCallback action) {
    widget.onDone();
    action();
  }
}

/// La pastille multicolore des références : trois disques qui se chevauchent,
/// plutôt qu'un dégradé — c'est ce qui se lit comme « des couleurs » et non
/// comme « une couleur ».
class _PaletteDot extends StatelessWidget {
  const _PaletteDot();

  @override
  Widget build(BuildContext context) {
    const colors = ['blue', 'pink', 'yellow'];
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        // Peintes de la droite vers la gauche : le jaune finit devant, comme
        // sur la référence, et les deux autres dépassent derrière lui.
        for (final (i, name) in colors.indexed)
          Positioned(
            left: (colors.length - 1 - i) * 6,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: bibleHighlightColors[name],
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    this.color,
    this.child,
    required this.tooltip,
    required this.onTap,
  });

  /// La teinte d'une pastille de la palette ; `null` avec un [child] pour les
  /// deux pastilles qui ne sont pas une couleur (la palette, « effacer »).
  final Color? color;
  final Widget? child;
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
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: color == null
                  ? null
                  : Border.all(color: palette.border, width: 1.5),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
