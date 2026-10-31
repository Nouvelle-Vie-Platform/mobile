/// **Le lien d'une note** (N5, #193) — l'attribut Quill `link`, au schéma
/// **fermé** que le serveur valide (`note_delta.ts`, `isValidNoteLink`) :
///
/// - `http(s)://…` — une adresse web ;
/// - `nv://note/<uuid>` — une autre note du membre ;
/// - `nv://teaching/<uuid>` — un enseignement ;
/// - `nv://bible/<OSIS>/<chapitre>[/<de>[-<à>]]` — une référence biblique.
///
/// Tout le reste (`javascript:`, `data:`, un `nv://` inconnu, un livre hors des
/// 66 codes OSIS, un chapitre nul, `de > à`) se lit `null` : jamais corrigé.
/// Pur Dart.
library;

/// Une adresse lisible par [NoteLink.parse], ou rien.
sealed class NoteLink {
  const NoteLink();

  /// Mêmes expressions que le serveur, pour qu'aucun lien posé ici ne
  /// revienne en 422.
  static final _http = RegExp(
    r'^https?://[^\s/?#]+[^\s]*$',
    caseSensitive: false,
  );
  static final _item = RegExp(r'^nv://(note|teaching)/([^/]+)$');
  static final _bible = RegExp(
    r'^nv://bible/([^/]+)/(\d{1,3})(?:/(\d{1,3})(?:-(\d{1,3}))?)?$',
  );
  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  static const _maxLength = 2000;

  static NoteLink? parse(String url) {
    if (url.length > _maxLength) return null;
    if (_http.hasMatch(url)) return WebLink(url);

    final item = _item.firstMatch(url);
    if (item != null) {
      final id = item.group(2)!;
      if (!_uuid.hasMatch(id)) return null;
      return item.group(1) == 'note' ? NoteRefLink(id) : TeachingLink(id);
    }

    final bible = _bible.firstMatch(url);
    if (bible != null) {
      final book = bible.group(1)!;
      final chapter = int.parse(bible.group(2)!);
      final from = bible.group(3) == null ? null : int.parse(bible.group(3)!);
      final to = bible.group(4) == null ? null : int.parse(bible.group(4)!);
      if (!osisBooksFr.containsKey(book) || chapter < 1) return null;
      if (from != null && from < 1) return null;
      if (to != null && to < from!) return null;
      return BibleLink(book, chapter, from: from, to: to);
    }
    return null;
  }

  /// L'adresse à poser dans l'attribut `link`.
  String toUrl();
}

/// Une adresse web, ouverte dans le navigateur du système.
final class WebLink extends NoteLink {
  const WebLink(this.url);
  final String url;

  /// **Ce que l'utilisateur a tapé**, rendu lien si possible : espaces
  /// retirés, `https://` ajouté quand aucun schéma n'est écrit. `null` si le
  /// résultat n'est pas une adresse web valide.
  static WebLink? fromInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final link = NoteLink.parse(withScheme);
    return link is WebLink ? link : null;
  }

  @override
  String toUrl() => url;
}

/// Une autre note du membre.
final class NoteRefLink extends NoteLink {
  const NoteRefLink(this.noteId);
  final String noteId;

  @override
  String toUrl() => 'nv://note/$noteId';
}

/// Un enseignement de la médiathèque.
final class TeachingLink extends NoteLink {
  const TeachingLink(this.teachingId);
  final String teachingId;

  @override
  String toUrl() => 'nv://teaching/$teachingId';
}

/// Une référence biblique : livre OSIS, chapitre, versets facultatifs
/// ([to] exige [from]).
final class BibleLink extends NoteLink {
  const BibleLink(this.book, this.chapter, {this.from, this.to})
      : assert(to == null || from != null);

  final String book;
  final int chapter;
  final int? from;
  final int? to;

  @override
  String toUrl() {
    final verses = from == null ? '' : '/$from${to == null ? '' : '-$to'}';
    return 'nv://bible/$book/$chapter$verses';
  }

  /// « Jean 3:16-18 », « Jean 3:16 », « Psaumes 23 ».
  ///
  /// **Le français n'est plus le défaut de l'affichage** : [labelIn] l'est, et
  /// la langue qu'on lui donne est celle de la **version ouverte**
  /// (`bibleBookLanguageProvider`). Lire l'éwé et voir « Jean 8:36 » au-dessus
  /// d'un verset en éwé était un mélange que rien ne justifiait.
  ///
  /// `labelFr` survit pour ce qui doit rester en français quelle que soit la
  /// version lue.
  String get labelFr => labelIn('fr');

  /// « Yohanes 3:16-18 » en éwé, « John 3:16 » en anglais. Repli sur le
  /// français pour une langue sans table — un titre dans la mauvaise langue
  /// reste lisible, un titre absent ne l'est pas.
  String labelIn(String languageCode) {
    final name = osisBooksFor(languageCode)[book] ?? osisBooksFr[book]!;
    if (from == null) return '$name $chapter';
    final range = (to == null || to == from) ? '$from' : '$from-$to';
    return '$name $chapter:$range';
  }
}

/// **Les 66 livres**, code OSIS → nom français, dans l'ordre canonique.
/// Recopie de `server-portal/app/spiritual_notes/support/osis_books.ts` :
/// jeu fermé, sensible à la casse.
const Map<String, String> osisBooksFr = {
  'Gen': 'Genèse',
  'Exod': 'Exode',
  'Lev': 'Lévitique',
  'Num': 'Nombres',
  'Deut': 'Deutéronome',
  'Josh': 'Josué',
  'Judg': 'Juges',
  'Ruth': 'Ruth',
  '1Sam': '1 Samuel',
  '2Sam': '2 Samuel',
  '1Kgs': '1 Rois',
  '2Kgs': '2 Rois',
  '1Chr': '1 Chroniques',
  '2Chr': '2 Chroniques',
  'Ezra': 'Esdras',
  'Neh': 'Néhémie',
  'Esth': 'Esther',
  'Job': 'Job',
  'Ps': 'Psaumes',
  'Prov': 'Proverbes',
  'Eccl': 'Ecclésiaste',
  'Song': 'Cantique des cantiques',
  'Isa': 'Ésaïe',
  'Jer': 'Jérémie',
  'Lam': 'Lamentations',
  'Ezek': 'Ézéchiel',
  'Dan': 'Daniel',
  'Hos': 'Osée',
  'Joel': 'Joël',
  'Amos': 'Amos',
  'Obad': 'Abdias',
  'Jonah': 'Jonas',
  'Mic': 'Michée',
  'Nah': 'Nahum',
  'Hab': 'Habacuc',
  'Zeph': 'Sophonie',
  'Hag': 'Aggée',
  'Zech': 'Zacharie',
  'Mal': 'Malachie',
  'Matt': 'Matthieu',
  'Mark': 'Marc',
  'Luke': 'Luc',
  'John': 'Jean',
  'Acts': 'Actes',
  'Rom': 'Romains',
  '1Cor': '1 Corinthiens',
  '2Cor': '2 Corinthiens',
  'Gal': 'Galates',
  'Eph': 'Éphésiens',
  'Phil': 'Philippiens',
  'Col': 'Colossiens',
  '1Thess': '1 Thessaloniciens',
  '2Thess': '2 Thessaloniciens',
  '1Tim': '1 Timothée',
  '2Tim': '2 Timothée',
  'Titus': 'Tite',
  'Phlm': 'Philémon',
  'Heb': 'Hébreux',
  'Jas': 'Jacques',
  '1Pet': '1 Pierre',
  '2Pet': '2 Pierre',
  '1John': '1 Jean',
  '2John': '2 Jean',
  '3John': '3 Jean',
  'Jude': 'Jude',
  'Rev': 'Apocalypse',
};

/// **Le nom d'un livre dans la langue de l'application.**
///
/// Les codes OSIS ne bougent **jamais** : ce sont les clés de `bible_marks`, de
/// `bible_reading_states` et des liens de notes. Seuls les libellés suivent la langue.
///
/// Repli sur le français pour toute langue sans table, et pour un code inconnu — un titre
/// dans la mauvaise langue reste lisible, un titre absent ne l'est pas.
Map<String, String> osisBooksFor(String languageCode) => switch (languageCode) {
      'en' => osisBooksEn,
      'ee' => osisBooksEe,
      _ => osisBooksFr,
    };

/// **Les 66 livres en anglais**, code OSIS → nom.
///
/// Ce n'est pas une traduction mais la **nomenclature canonique** : « Song of Songs »
/// n'est pas un choix de traducteur. Elle manquait, et l'application servait donc des
/// titres français à ses lecteurs anglophones — constaté le 27/10/2026 sur une capture
/// où « Genèse » et « Exode » s'alignaient sous « Old Testament ».

const Map<String, String> osisBooksEn = {
  'Gen': 'Genesis',
  'Exod': 'Exodus',
  'Lev': 'Leviticus',
  'Num': 'Numbers',
  'Deut': 'Deuteronomy',
  'Josh': 'Joshua',
  'Judg': 'Judges',
  'Ruth': 'Ruth',
  '1Sam': '1 Samuel',
  '2Sam': '2 Samuel',
  '1Kgs': '1 Kings',
  '2Kgs': '2 Kings',
  '1Chr': '1 Chronicles',
  '2Chr': '2 Chronicles',
  'Ezra': 'Ezra',
  'Neh': 'Nehemiah',
  'Esth': 'Esther',
  'Job': 'Job',
  'Ps': 'Psalms',
  'Prov': 'Proverbs',
  'Eccl': 'Ecclesiastes',
  'Song': 'Song of Songs',
  'Isa': 'Isaiah',
  'Jer': 'Jeremiah',
  'Lam': 'Lamentations',
  'Ezek': 'Ezekiel',
  'Dan': 'Daniel',
  'Hos': 'Hosea',
  'Joel': 'Joel',
  'Amos': 'Amos',
  'Obad': 'Obadiah',
  'Jonah': 'Jonah',
  'Mic': 'Micah',
  'Nah': 'Nahum',
  'Hab': 'Habakkuk',
  'Zeph': 'Zephaniah',
  'Hag': 'Haggai',
  'Zech': 'Zechariah',
  'Mal': 'Malachi',
  'Matt': 'Matthew',
  'Mark': 'Mark',
  'Luke': 'Luke',
  'John': 'John',
  'Acts': 'Acts',
  'Rom': 'Romans',
  '1Cor': '1 Corinthians',
  '2Cor': '2 Corinthians',
  'Gal': 'Galatians',
  'Eph': 'Ephesians',
  'Phil': 'Philippians',
  'Col': 'Colossians',
  '1Thess': '1 Thessalonians',
  '2Thess': '2 Thessalonians',
  '1Tim': '1 Timothy',
  '2Tim': '2 Timothy',
  'Titus': 'Titus',
  'Phlm': 'Philemon',
  'Heb': 'Hebrews',
  'Jas': 'James',
  '1Pet': '1 Peter',
  '2Pet': '2 Peter',
  '1John': '1 John',
  '2John': '2 John',
  '3John': '3 John',
  'Jude': 'Jude',
  'Rev': 'Revelation',
};

/// **Les 66 livres en éwé**, code OSIS → nom.
///
/// **Recopiés du `BookNames.xml` de l'éditeur**, celui que Biblica publie avec la
/// traduction que l'application sert — `Biblica® Se aɖeke mebla Biblia zazã o
/// Agbenya La™`, 2020, distribuée par eBible.org. C'est la seule autorité qui
/// existe ici : le XML du texte lui-même ne porte que des **numéros** de livre,
/// jamais leurs noms (mesuré sur `Ewe2020Bible.xml`).
///
/// La table précédente venait d'un relevé sans source et se trompait sur **31 noms
/// sur 66** — « Hakpukpuiwo » pour les Psaumes là où l'éditeur écrit « Psalmowo »,
/// « Vonɔlawo » pour les Juges là où il écrit « Ʋɔnudrɔ̃lawo », et un Pentateuque
/// numéroté à la française. Relevé par un lecteur éwé le 31/10/2026.
///
/// **Seule retouche à la sortie de l'éditeur** : ses chiffres arabes (« Mose 1 »)
/// passent en chiffres romains (« Mose I »), forme attendue par l'église. Le reste
/// est recopié au caractère près.
///
/// Sans cette table, une Bible en éwé afficherait du vrai texte éwé sous des titres
/// français : le texte juste, l'habillage dans la mauvaise langue.

const Map<String, String> osisBooksEe = {
  'Gen': 'Mose I',
  'Exod': 'Mose II',
  'Lev': 'Mose III',
  'Num': 'Mose IV',
  'Deut': 'Mose V',
  'Josh': 'Yosua',
  'Judg': 'Ʋɔnudrɔ̃lawo',
  'Ruth': 'Rut',
  '1Sam': 'Samuel I',
  '2Sam': 'Samuel II',
  '1Kgs': 'Fiawo I',
  '2Kgs': 'Fiawo II',
  '1Chr': 'Kronika I',
  '2Chr': 'Kronika II',
  'Ezra': 'Ezra',
  'Neh': 'Nehemia',
  'Esth': 'Ester',
  'Job': 'Hiob',
  'Ps': 'Psalmowo',
  'Prov': 'Lododowo',
  'Eccl': 'Nyagblɔla',
  'Song': 'Hawo',
  'Isa': 'Yesaya',
  'Jer': 'Yeremia',
  'Lam': 'Konyifahawo',
  'Ezek': 'Hezekiel',
  'Dan': 'Daniel',
  'Hos': 'Hosea',
  'Joel': 'Yoel',
  'Amos': 'Amos',
  'Obad': 'Obadia',
  'Jonah': 'Yona',
  'Mic': 'Mika',
  'Nah': 'Nahum',
  'Hab': 'Habakuk',
  'Zeph': 'Zefania',
  'Hag': 'Hagai',
  'Zech': 'Zekaria',
  'Mal': 'Malaki',
  'Matt': 'Mateo',
  'Mark': 'Marko',
  'Luke': 'Luka',
  'John': 'Yohanes',
  'Acts': 'Dɔwɔwɔwo',
  'Rom': 'Romatɔwo',
  '1Cor': 'Korintotɔwo I',
  '2Cor': 'Korintotɔwo II',
  'Gal': 'Galatiatɔwo',
  'Eph': 'Efesotɔwo',
  'Phil': 'Filipitɔwo',
  'Col': 'Kolosetɔwo',
  '1Thess': 'Tesalonikatɔwo I',
  '2Thess': 'Tesalonikatɔwo II',
  '1Tim': 'Timoteo I',
  '2Tim': 'Timoteo II',
  'Titus': 'Tito',
  'Phlm': 'Filemon',
  'Heb': 'Hebritɔwo',
  'Jas': 'Yakobo',
  '1Pet': 'Petro I',
  '2Pet': 'Petro II',
  '1John': 'Yohanes I',
  '2John': 'Yohanes II',
  '3John': 'Yohanes III',
  'Jude': 'Yuda',
  'Rev': 'Nyaɖeɖefia',
};
