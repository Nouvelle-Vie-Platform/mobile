import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';
import 'note_content.dart';

/// **Le corps d'une note, en texte brut** (#190) — le widget que la tranche N3
/// remplace par l'éditeur riche **sans toucher au reste de l'écran**.
///
/// Le contrat tient en deux membres : [initialBody], le texte aplati de la
/// note au moment d'ouvrir ; [onChanged], appelé à chaque frappe avec le texte
/// aplati **et** le Delta Quill en JSON — ici le Delta minimal de
/// [plainToDeltaJson], demain celui du `QuillController`.
class NoteBodyPlain extends StatefulWidget {
  const NoteBodyPlain({
    super.key,
    required this.initialBody,
    required this.onChanged,
    this.hint,
    this.focusNode,
  });

  final String initialBody;
  final void Function(String body, String contentJson) onChanged;
  final String? hint;
  final FocusNode? focusNode;

  @override
  State<NoteBodyPlain> createState() => _NoteBodyPlainState();
}

class _NoteBodyPlainState extends State<NoteBodyPlain> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialBody);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: widget.focusNode,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: TextInputType.multiline,
      style: AppTypography.bodyLarge,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: AppTypography.bodyLarge
            .copyWith(color: context.palette.textSecondary),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: (text) => widget.onChanged(text, plainToDeltaJson(text)),
    );
  }
}
