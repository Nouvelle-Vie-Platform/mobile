/// **Les modèles de lecture des notes** (#190) : ce que la liste et l'éditeur
/// affichent, déjà départagé entre le brouillon local et la ligne synchronisée
/// (`NotesDao`).
library;

import 'package:flutter/foundation.dart';

/// Les six couleurs du contrat serveur (`note_categories.color`), par leur
/// clé sur le fil. Une clé inconnue se lit `null` : la carte se peint neutre.
enum NoteColor {
  blue,
  pink,
  green,
  yellow,
  orange,
  purple;

  static NoteColor? parse(String? key) {
    for (final color in values) {
      if (color.name == key) return color;
    }
    return null;
  }
}

@immutable
class NoteCategoryView {
  const NoteCategoryView({
    required this.id,
    required this.name,
    required this.color,
  });

  final String id;
  final String name;
  final NoteColor? color;
}

@immutable
class NoteView {
  const NoteView({
    required this.id,
    required this.title,
    required this.body,
    required this.content,
    required this.categoryId,
    required this.pinned,
    required this.teachingId,
    required this.updatedAt,
    required this.isLocal,
  });

  final String id;

  /// Nul ou vide : la carte et l'éditeur disent « Nouvelle note ».
  final String? title;

  /// Le texte aplati — l'aperçu de la carte, et ce que la recherche fouille.
  final String body;

  /// Le Delta Quill en JSON, ou nul pour une note d'avant le titre riche.
  final String? content;
  final String? categoryId;
  final bool pinned;
  final String? teachingId;
  final DateTime? updatedAt;

  /// Vient du brouillon local (pas encore revenu par le delta), pour le
  /// diagnostic et les tests — aucun écran ne le peint.
  final bool isLocal;

  bool get isEmpty => (title ?? '').trim().isEmpty && body.trim().isEmpty;
}
