import 'package:flutter/material.dart';

import '../models/note_view.dart';

/// **Les six pastels des notes** (#190), par clé du contrat serveur, en clair
/// et en sombre.
///
/// Relevés sur la maquette (`ressources/Note_bible/`) : des fonds de carte
/// pâles sur lesquels le texte reste sombre. En mode sombre, la même teinte
/// assombrie, sur laquelle le texte clair de la palette reste lisible. Une
/// note **sans** catégorie se peint sur `palette.surfaceAlt` — ce fichier ne
/// porte que les couleurs portées par une catégorie.
abstract final class NotePalette {
  static const Map<NoteColor, Color> _light = {
    NoteColor.blue: Color(0xFFCFE2FF),
    NoteColor.pink: Color(0xFFFFCDE1),
    NoteColor.green: Color(0xFFD3F5D3),
    NoteColor.yellow: Color(0xFFFFF0B8),
    NoteColor.orange: Color(0xFFFFD6C2),
    NoteColor.purple: Color(0xFFE2D4FF),
  };

  static const Map<NoteColor, Color> _dark = {
    NoteColor.blue: Color(0xFF26395C),
    NoteColor.pink: Color(0xFF5A2F42),
    NoteColor.green: Color(0xFF274A2F),
    NoteColor.yellow: Color(0xFF5A4F22),
    NoteColor.orange: Color(0xFF5C3A28),
    NoteColor.purple: Color(0xFF3F2F5E),
  };

  /// Le fond d'une carte ou d'une puce de [color], selon la luminosité du
  /// thème courant.
  static Color of(BuildContext context, NoteColor color) =>
      Theme.of(context).brightness == Brightness.dark
          ? _dark[color]!
          : _light[color]!;
}
