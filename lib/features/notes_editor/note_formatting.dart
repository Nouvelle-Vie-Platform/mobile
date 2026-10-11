/// **Les gestes de mise en forme**, partagés par la pilule et la feuille
/// Format (N3, #191).
///
/// flutter_quill ne « bascule » rien de lui-même : `formatSelection(bold)`
/// pose le gras, `formatSelection(bold vidé)` le retire. Ce fichier porte
/// cette logique une fois, pour que les deux surfaces qui la montrent
/// (pilule, feuille) ne la réécrivent pas chacune de leur côté — et pour que
/// les attributs posés restent dans la liste fermée de `note_content.dart`.
library;

import 'package:flutter_quill/flutter_quill.dart';

import 'note_colors.dart';

extension NoteFormatting on QuillController {
  Style get _style => getSelectionStyle();

  /// `true` si l'attribut [attribute] est posé sur la sélection, **avec la
  /// même valeur** (un `header: 2` n'est pas un `header: 1`).
  bool isActive(Attribute attribute) =>
      _style.attributes[attribute.key]?.value == attribute.value;

  /// Pose ou retire un attribut **booléen** (gras, italique, souligné, barré,
  /// monostyle, citation).
  void toggle(Attribute attribute) {
    formatSelection(
      isActive(attribute) ? Attribute.clone(attribute, null) : attribute,
    );
  }

  /// Le niveau de titre courant (1–3), `null` pour un corps.
  int? get headerLevel => switch (_style.attributes[Attribute.header.key]) {
        final a when a?.value is int => a!.value as int,
        _ => null,
      };

  /// `header: level`, ou le corps pour `null`.
  void setHeader(int? level) {
    formatSelection(switch (level) {
      1 => Attribute.h1,
      2 => Attribute.h2,
      3 => Attribute.h3,
      _ => Attribute.header,
    });
  }

  /// Le type de liste courant (`bullet`, `ordered`, `checked`, `unchecked`),
  /// ou `null`.
  String? get listType =>
      _style.attributes[Attribute.list.key]?.value as String?;

  /// `true` pour une case, cochée ou non.
  bool get isChecklist => listType == 'checked' || listType == 'unchecked';

  /// Pose la liste [attribute] (`Attribute.ul`, `.ol`, `.unchecked`), ou la
  /// retire si elle est déjà là — une case cochée compte comme une case.
  void toggleList(Attribute<String?> attribute) {
    final active = attribute == Attribute.unchecked
        ? isChecklist
        : listType == attribute.value;
    formatSelection(active ? Attribute.clone(Attribute.list, null) : attribute);
  }

  /// La couleur de texte posée, ou `null`.
  String? get textColor =>
      _style.attributes[Attribute.color.key]?.value as String?;

  /// Pose une couleur de la palette fermée, ou la retire pour `null`. Une
  /// couleur hors palette est **ignorée** : c'est le serveur qui la refuserait.
  void setTextColor(String? hex) {
    if (hex == null) {
      formatSelection(Attribute.color);
    } else if (isNoteTextColor(hex)) {
      formatSelection(ColorAttribute(hex.toLowerCase()));
    }
  }

  bool get isHighlighted => isNoteHighlight(
        _style.attributes[Attribute.background.key]?.value as String?,
      );

  /// Pose ou retire le surlignage jaune de la marque — la seule valeur de
  /// `background` admise.
  void toggleHighlight() {
    formatSelection(
      isHighlighted
          ? Attribute.background
          : const BackgroundAttribute(noteHighlight),
    );
  }
}
