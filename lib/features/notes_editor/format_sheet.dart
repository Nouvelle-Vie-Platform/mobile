/// **La feuille Format façon Apple** (N3, #191), ouverte par le « T » de la
/// pilule.
///
/// Trois rangées, comme la capture `ios-26-…-text-formatting-options.png` :
/// les styles de paragraphe (titre / sous-titre / titre secondaire / corps,
/// pilule jaune sur l'actif), les styles en ligne (B I U S, surlignage,
/// pastille de couleur), puis puces / numérotée / cases, désindenter /
/// indenter, monostyle / citation.
///
/// **La feuille reste ouverte pendant qu'on formate**, comme chez Apple : elle
/// agit sur la sélection du contrôleur et se repeint à chaque changement. Elle
/// n'a pas de tirets : flutter_quill ne connaît qu'une liste à puces.
library;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../l10n/l10n_extension.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'note_colors.dart';
import 'note_formatting.dart';

Future<void> showFormatSheet(BuildContext context, QuillController controller) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => FormatSheet(controller: controller),
  );
}

class FormatSheet extends StatefulWidget {
  const FormatSheet({super.key, required this.controller});

  final QuillController controller;

  static const Key closeKey = Key('note_format_close');
  static const Key titleKey = Key('note_format_title');
  static const Key subtitleKey = Key('note_format_subtitle');
  static const Key headingKey = Key('note_format_heading');
  static const Key bodyKey = Key('note_format_body');
  static const Key boldKey = Key('note_format_bold');
  static const Key italicKey = Key('note_format_italic');
  static const Key underlineKey = Key('note_format_underline');
  static const Key strikeKey = Key('note_format_strike');
  static const Key highlightKey = Key('note_format_highlight');
  static const Key colorKey = Key('note_format_color');
  static const Key bulletKey = Key('note_format_bullet');
  static const Key numberedKey = Key('note_format_numbered');
  static const Key checklistKey = Key('note_format_checklist');
  static const Key outdentKey = Key('note_format_outdent');
  static const Key indentKey = Key('note_format_indent');
  static const Key monostyleKey = Key('note_format_monostyle');
  static const Key quoteKey = Key('note_format_quote');
  static Key swatchKey(String hex) => Key('note_format_swatch_$hex');

  @override
  State<FormatSheet> createState() => _FormatSheetState();
}

class _FormatSheetState extends State<FormatSheet> {
  bool _paletteOpen = false;

  QuillController get c => widget.controller;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.palette;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.noteEditorFormatTitle,
                      style: AppTypography.h4.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _RoundButton(
                    key: FormatSheet.closeKey,
                    label: l.noteEditorClose,
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _StyleChip(
                      key: FormatSheet.titleKey,
                      label: l.noteEditorStyleTitle,
                      size: 22,
                      bold: true,
                      active: c.headerLevel == 1,
                      onTap: () => c.setHeader(c.headerLevel == 1 ? null : 1),
                    ),
                    _StyleChip(
                      key: FormatSheet.subtitleKey,
                      label: l.noteEditorStyleSubtitle,
                      size: 18,
                      bold: true,
                      active: c.headerLevel == 2,
                      onTap: () => c.setHeader(c.headerLevel == 2 ? null : 2),
                    ),
                    _StyleChip(
                      key: FormatSheet.headingKey,
                      label: l.noteEditorStyleHeading,
                      size: 15,
                      bold: true,
                      active: c.headerLevel == 3,
                      onTap: () => c.setHeader(c.headerLevel == 3 ? null : 3),
                    ),
                    _StyleChip(
                      key: FormatSheet.bodyKey,
                      label: l.noteEditorStyleBody,
                      size: 15,
                      bold: false,
                      active: c.headerLevel == null,
                      onTap: () => c.setHeader(null),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: _Group(
                      children: [
                        _GroupButton(
                          key: FormatSheet.boldKey,
                          label: l.noteEditorBold,
                          active: c.isActive(Attribute.bold),
                          onTap: () => c.toggle(Attribute.bold),
                          child: const Icon(Icons.format_bold),
                        ),
                        _GroupButton(
                          key: FormatSheet.italicKey,
                          label: l.noteEditorItalic,
                          active: c.isActive(Attribute.italic),
                          onTap: () => c.toggle(Attribute.italic),
                          child: const Icon(Icons.format_italic),
                        ),
                        _GroupButton(
                          key: FormatSheet.underlineKey,
                          label: l.noteEditorUnderline,
                          active: c.isActive(Attribute.underline),
                          onTap: () => c.toggle(Attribute.underline),
                          child: const Icon(Icons.format_underlined),
                        ),
                        _GroupButton(
                          key: FormatSheet.strikeKey,
                          label: l.noteEditorStrike,
                          active: c.isActive(Attribute.strikeThrough),
                          onTap: () => c.toggle(Attribute.strikeThrough),
                          child: const Icon(Icons.format_strikethrough),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: _Group(
                      children: [
                        _GroupButton(
                          key: FormatSheet.highlightKey,
                          label: l.noteEditorHighlight,
                          active: c.isHighlighted,
                          onTap: c.toggleHighlight,
                          child: const Icon(Icons.border_color),
                        ),
                        _GroupButton(
                          key: FormatSheet.colorKey,
                          label: l.noteEditorTextColor,
                          active: _paletteOpen,
                          onTap: () =>
                              setState(() => _paletteOpen = !_paletteOpen),
                          child: _Swatch(
                            hex: c.textColor,
                            fallback: palette.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 150),
                alignment: Alignment.topCenter,
                child: _paletteOpen
                    ? Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: _ColorPalette(
                          selected: c.textColor,
                          onSelect: (hex) => c.setTextColor(hex),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _Group(
                      children: [
                        _GroupButton(
                          key: FormatSheet.bulletKey,
                          label: l.noteEditorBulletList,
                          active: c.listType == 'bullet',
                          onTap: () => c.toggleList(Attribute.ul),
                          child: const Icon(Icons.format_list_bulleted),
                        ),
                        _GroupButton(
                          key: FormatSheet.numberedKey,
                          label: l.noteEditorNumberedList,
                          active: c.listType == 'ordered',
                          onTap: () => c.toggleList(Attribute.ol),
                          child: const Icon(Icons.format_list_numbered),
                        ),
                        _GroupButton(
                          key: FormatSheet.checklistKey,
                          label: l.noteEditorChecklist,
                          active: c.isChecklist,
                          onTap: () => c.toggleList(Attribute.unchecked),
                          child: const Icon(Icons.check_box_outlined),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: _Group(
                      children: [
                        _GroupButton(
                          key: FormatSheet.outdentKey,
                          label: l.noteEditorOutdent,
                          onTap: () => c.indentSelection(false),
                          child: const Icon(Icons.format_indent_decrease),
                        ),
                        _GroupButton(
                          key: FormatSheet.indentKey,
                          label: l.noteEditorIndent,
                          onTap: () => c.indentSelection(true),
                          child: const Icon(Icons.format_indent_increase),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: _Group(
                      children: [
                        _GroupButton(
                          key: FormatSheet.monostyleKey,
                          label: l.noteEditorMonostyle,
                          active: c.isActive(Attribute.codeBlock),
                          onTap: () => c.toggle(Attribute.codeBlock),
                          child: const Icon(Icons.code),
                        ),
                        _GroupButton(
                          key: FormatSheet.quoteKey,
                          label: l.noteEditorQuote,
                          active: c.isActive(Attribute.blockQuote),
                          onTap: () => c.toggle(Attribute.blockQuote),
                          child: const Icon(Icons.format_quote),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un style de paragraphe : le libellé dans sa propre taille, pilule jaune
/// quand il est actif.
class _StyleChip extends StatelessWidget {
  const _StyleChip({
    super.key,
    required this.label,
    required this.size,
    required this.bold,
    required this.active,
    required this.onTap,
  });

  final String label;
  final double size;
  final bool bold;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(right: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: active ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: size,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: active ? AppColors.neutralDark : palette.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Un groupe de boutons sur fond `surfaceAlt`, séparés d'un filet.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) VerticalDivider(width: 1, color: palette.border),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

class _GroupButton extends StatelessWidget {
  const _GroupButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.active = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = active ? AppColors.neutralDark : palette.textPrimary;
    return Tooltip(
      message: label,
      child: Material(
        color: active ? AppColors.accent : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: IconTheme(
              data: IconThemeData(color: foreground, size: 22),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: label,
      child: Material(
        color: palette.surfaceAlt,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: IconTheme(
              data: IconThemeData(color: palette.textPrimary),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// La pastille : la couleur posée, ou la couleur du texte courant.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.hex, required this.fallback});

  final String? hex;
  final Color fallback;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: noteColorOf(hex) ?? fallback,
        shape: BoxShape.circle,
        border: Border.all(color: context.palette.border),
      ),
    );
  }
}

class _ColorPalette extends StatelessWidget {
  const _ColorPalette({required this.selected, required this.onSelect});

  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final hex in noteTextColors)
          GestureDetector(
            key: FormatSheet.swatchKey(hex),
            // Retoucher la couleur déjà posée la retire : le texte reprend
            // la couleur du thème.
            onTap: () => onSelect(selected == hex ? null : hex),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: noteColorOf(hex),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected == hex ? palette.textPrimary : palette.border,
                  width: selected == hex ? 2.5 : 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// La [Color] d'un `#rrggbb` de la palette, `null` hors palette.
Color? noteColorOf(String? hex) {
  if (!isNoteTextColor(hex)) return null;
  return Color(int.parse('ff${hex!.substring(1)}', radix: 16));
}
