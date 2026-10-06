/// **La recherche de la médiathèque, en un seul endroit** (#82).
///
/// La loupe de l'en-tête était un `onPressed: () {}` et la clé `mediaSearchHint`
/// vivait dans l'ARB sans appelant. Elle filtre désormais, et c'est ici que la
/// règle est écrite — une fois, pour les deux familles.
///
/// Trois limites assumées, écrites plutôt que découvertes :
///
/// 1. **La recherche porte sur le titre, et sur lui seul.** Ni la description,
///    ni le nom de l'intervenant : le serveur ne sert pas d'index, et une
///    recherche qui ramènerait un contenu dont le mot cherché n'apparaît nulle
///    part à l'écran se lit comme un bug.
/// 2. **`LIKE` de SQLite ne replie que l'ASCII** : « priere » ne trouve pas
///    « Prière ». Replier les accents demanderait soit une extension ICU — que
///    `sqlite3_flutter_libs` n'embarque pas —, soit une colonne de titre
///    normalisée que le serveur ne sert pas. Le jour où l'une des deux arrive,
///    c'est [searchPattern] qu'on change, et rien d'autre.
/// 3. **Les jokers de `LIKE` sont retirés de la saisie.** `%` et `_` y sont des
///    caractères ordinaires pour qui les tape ; les laisser passer ferait d'un
///    « 100 % » une recherche qui ramène tout le catalogue. SQLite n'a pas de
///    caractère d'échappement par défaut (il faut une clause `ESCAPE`), et les
///    retirer est le seul geste qui ne dépende pas de la forme de la requête
///    générée.
library;

/// Le motif `LIKE` d'une saisie, ou `null` quand il n'y a rien à chercher.
///
/// `null` et non une chaîne vide : « pas de recherche » est une absence de
/// clause, pas une clause qui accepte tout. Les confondre ferait d'un champ
/// vidé un filtre, et d'un filtre vide une erreur de requête.
String? searchPattern(String? raw) {
  final term = normalizeSearchTerm(raw);
  return term == null ? null : '%$term%';
}

/// La saisie, débarrassée de ses jokers et de ses blancs — ou `null` s'il ne
/// reste rien.
String? normalizeSearchTerm(String? raw) {
  final stripped = raw?.replaceAll(RegExp(r'[%_]'), '').trim();
  return (stripped == null || stripped.isEmpty) ? null : stripped;
}

/// **Normalise un texte pour la comparaison** : minuscules, sans accents. Sert
/// aux recherches faites en Dart sur une liste déjà lue — les **noms** de
/// discussions, les sections de la médiathèque en pages (« eglise » trouve
/// « Église »).
String foldForSearch(String text) {
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_folds[char] ?? char);
  }
  return buffer.toString();
}

const Map<String, String> _folds = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', //
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i', //
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o', //
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u', //
  'ÿ': 'y', 'ñ': 'n', 'œ': 'oe', 'æ': 'ae', //
  'ɛ': 'e', 'ɔ': 'o', 'ŋ': 'n', 'ƒ': 'f', 'ʋ': 'v', 'ɖ': 'd', 'ɣ': 'g', //
};
