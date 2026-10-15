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
  String get labelFr {
    final name = osisBooksFr[book]!;
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
