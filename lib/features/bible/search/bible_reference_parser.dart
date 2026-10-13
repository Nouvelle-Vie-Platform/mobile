/// **Lire une référence tapée** (M3, #201) : « jn 3 16 », « Jean 3:16-18 »,
/// « 1 Co 13 », « ps 23 » → [BibleLink].
///
/// Le livre se reconnaît par son nom, une abréviation du canon ou son code
/// OSIS (sans casse ni accents, espaces et points ignorés), sinon par un
/// **préfixe** de son nom qui ne désigne qu'un livre (« philip » → Philippiens ;
/// « phi » → refusé, Philippiens ou Philémon). Le chapitre est obligatoire ;
/// une référence hors du canon (« Jean 22 », « Ps 23:7 ») se lit `null` —
/// la saisie reste alors une recherche de mots. Pur Dart.
library;

import '../../../utils/search_terms.dart';
import '../data/canon.dart';

final _shape = RegExp(
  r'^\s*((?:[1-3]\s*)?[^\d\s][^\d]*?)\s*(\d{1,3})'
  r'(?:\s*[:.,\s]\s*(\d{1,3})(?:\s*[-–]\s*(\d{1,3}))?)?\s*$',
);

String _key(String s) => foldForSearch(s).replaceAll(RegExp(r"[\s.\-'’]"), '');

/// Clé normalisée → livre ; `null` quand deux livres la revendiquent.
final Map<String, String?> _exact = () {
  final map = <String, String?>{};
  void add(String key, String osis) {
    final k = _key(key);
    if (map.containsKey(k) && map[k] != osis) {
      map[k] = null;
    } else {
      map[k] = osis;
    }
  }

  for (final b in bibleCanon) {
    add(b.name, b.osis);
    add(b.osis, b.osis);
    for (final a in b.abbreviations) {
      add(a, b.osis);
    }
  }
  return map;
}();

/// Le livre désigné par [input], ou `null` (inconnu ou ambigu).
String? resolveBibleBook(String input) {
  final k = _key(input);
  if (k.isEmpty || !RegExp(r'[a-z]').hasMatch(k)) return null;
  if (_exact.containsKey(k)) return _exact[k];
  final candidates = {
    for (final b in bibleCanon)
      if (_key(b.name).startsWith(k)) b.osis,
  };
  return candidates.length == 1 ? candidates.single : null;
}

/// La référence que [query] désigne, ou `null`.
BibleLink? parseBibleReference(String query) {
  final m = _shape.firstMatch(query);
  if (m == null) return null;
  final book = resolveBibleBook(m.group(1)!);
  if (book == null) return null;
  final chapter = int.parse(m.group(2)!);
  final from = m.group(3) == null ? null : int.parse(m.group(3)!);
  var to = m.group(4) == null ? null : int.parse(m.group(4)!);
  if (to == from) to = null;
  final link = BibleLink(book, chapter, from: from, to: to);
  return isValidBibleRef(link) ? link : null;
}
