/// **Les deux contrats de lecture de la Bible** (M1, #199, décision 8).
///
/// Tout le module lit le texte par [BibleSource] et les versions par
/// [BibleCatalog] — jamais une implémentation. Aujourd'hui la seule est
/// factice (`placeholder_bible.dart`) ; le chantier du contenu (versions
/// téléchargées en zip) posera la vraie derrière les mêmes signatures.
/// Une référence (`BibleLink`) ne dépend **jamais** d'une version — mais sa
/// **validité**, si : la versification est propre à chaque version (C3, #240),
/// et c'est le catalogue qui la rend ([BibleCatalog.versificationFor]).
library;

import 'versification.dart';

/// Un verset : son numéro et son texte.
final class BibleVerse {
  const BibleVerse(this.number, this.text);
  final int number;
  final String text;
}

/// Une version de la Bible telle que le catalogue la décrit.
final class BibleVersion {
  const BibleVersion({
    required this.code,
    required this.name,
    required this.language,
    this.installed = false,
  });

  /// Clé stable (`bible_reading_states.versionCode`, `bible_fts.version_code`).
  final String code;
  final String name;

  /// `fr`, `ee`, `en`…
  final String language;
  final bool installed;
}

/// Le texte d'**une** version.
abstract interface class BibleSource {
  String get versionCode;

  /// Les versets de [book] [chapter], dans l'ordre. Vide hors du canon.
  Future<List<BibleVerse>> chapter(String book, int chapter);
}

/// Les versions disponibles, et le texte de celles qui sont installées.
abstract interface class BibleCatalog {
  /// Toutes les versions connues, installées ou non.
  Future<List<BibleVersion>> versions();

  /// La version ouverte quand rien n'a encore été choisi.
  String get defaultVersionCode;

  /// Le texte d'une version installée, ou `null`.
  BibleSource? sourceFor(String versionCode);

  /// **La versification de [versionCode]** : la sienne si la version
  /// installée en porte une, sinon le canon figé (`kCanonVersification`).
  /// C'est elle que suivent la grille, la validation des références et
  /// l'index plein texte.
  BibleVersification versificationFor(String versionCode);

  /// **La langue de [versionCode]** (`fr`, `ee`, `en`…), le français à défaut.
  ///
  /// Elle ne décide pas de la langue de l'application : elle décide des **noms
  /// de livres affichés**. Un fidèle qui n'a téléchargé que l'éwé lit un texte
  /// en éwé ; lui titrer « Jean 8:36 » au-dessus serait un mélange que rien ne
  /// justifie.
  String languageFor(String versionCode);
}
