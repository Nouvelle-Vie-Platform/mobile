/// **La pilule sombre de la maquette** (N3, #191) : T, B, I, U, puces,
/// numérotée, case à cocher, puis les deux emplacements des tranches N4
/// (trombone) et N5 (lien).
///
/// Elle flotte au-dessus du clavier — c'est [RichNoteEditor] qui la place et
/// ne la montre que quand l'éditeur a le focus. Chaque bouton reflète la
/// sélection courante (B allumé sur du gras…) ; « T » ouvre la feuille Format
/// et **rend le focus** à l'éditeur quand elle se referme.
library;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../l10n/l10n_extension.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'format_sheet.dart';
import 'note_formatting.dart';

class FormatPill extends StatelessWidget {
  const FormatPill({
    super.key,
    required this.controller,
    required this.focusNode,
    this.attachmentSlot,
    this.linkSlot,
  });

  static const double height = 48;

  static const Key formatKey = Key('note_pill_format');
  static const Key boldKey = Key('note_pill_bold');
  static const Key italicKey = Key('note_pill_italic');
  static const Key underlineKey = Key('note_pill_underline');
  static const Key bulletKey = Key('note_pill_bullet');
  static const Key numberedKey = Key('note_pill_numbered');
  static const Key checklistKey = Key('note_pill_checklist');

  final QuillController controller;
  final FocusNode focusNode;
  final Widget? attachmentSlot;
  final Widget? linkSlot;

  Future<void> _openFormat(BuildContext context) async {
    await showFormatSheet(context, controller);
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.neutralDark,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.elevation2,
      ),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            PillButton(
              key: formatKey,
              label: l.noteEditorOpenFormat,
              onTap: () => _openFormat(context),
              child: const Text(
                'T',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            PillButton(
              key: boldKey,
              label: l.noteEditorBold,
              active: controller.isActive(Attribute.bold),
              onTap: () => controller.toggle(Attribute.bold),
              child: const Icon(Icons.format_bold),
            ),
            PillButton(
              key: italicKey,
              label: l.noteEditorItalic,
              active: controller.isActive(Attribute.italic),
              onTap: () => controller.toggle(Attribute.italic),
              child: const Icon(Icons.format_italic),
            ),
            PillButton(
              key: underlineKey,
              label: l.noteEditorUnderline,
              active: controller.isActive(Attribute.underline),
              onTap: () => controller.toggle(Attribute.underline),
              child: const Icon(Icons.format_underlined),
            ),
            PillButton(
              key: bulletKey,
              label: l.noteEditorBulletList,
              active: controller.listType == 'bullet',
              onTap: () => controller.toggleList(Attribute.ul),
              child: const Icon(Icons.format_list_bulleted),
            ),
            PillButton(
              key: numberedKey,
              label: l.noteEditorNumberedList,
              active: controller.listType == 'ordered',
              onTap: () => controller.toggleList(Attribute.ol),
              child: const Icon(Icons.format_list_numbered),
            ),
            PillButton(
              key: checklistKey,
              label: l.noteEditorChecklist,
              active: controller.isChecklist,
              onTap: () => controller.toggleList(Attribute.unchecked),
              child: const Icon(Icons.check_box_outlined),
            ),
            if (attachmentSlot != null) attachmentSlot!,
            if (linkSlot != null) linkSlot!,
          ],
        ),
      ),
    );
  }
}

/// Un bouton de la pilule : blanc sur sombre, jaune de la marque quand il est
/// actif. **Public pour N4 et N5**, qui remplissent les deux emplacements avec
/// le même dessin.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.active = false,
  });

  /// Le libellé d'accessibilité (info-bulle et lecteur d'écran).
  final String label;
  final VoidCallback onTap;
  final bool active;

  /// Une icône ou un texte ; la couleur lui est donnée ici.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? AppColors.neutralDark : Colors.white;
    return Tooltip(
      message: label,
      child: Material(
        color: active ? AppColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: IconTheme(
                data: IconThemeData(color: foreground, size: 22),
                child: DefaultTextStyle(
                  style: TextStyle(color: foreground),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
