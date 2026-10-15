/// **Les deux contrats de lecture de la Bible** (M1, #199, décision 8).
///
/// Tout le module lit le texte par [BibleSource] et les versions par
/// [BibleCatalog] — jamais une implémentation. Aujourd'hui la seule est
/// factice (`placeholder_bible.dart`) ; le chantier du contenu (versions
/// téléchargées en zip) posera la vraie derrière les mêmes signatures.
/// Une référence (`BibleLink`) ne dépend **jamais** d'une version.
library;

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
}
