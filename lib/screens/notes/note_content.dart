/// **Le contenu d'une note, sous sa forme minimale** (#190).
///
/// Le serveur stocke un Delta Quill (`content`, décision 3 du cadrage) et le
/// texte aplati (`body`). Tant que l'éditeur riche de la tranche N3 n'est pas
/// là, le corps est du texte brut, et c'est ici qu'il devient le Delta le plus
/// simple qui soit : une seule opération `insert`, terminée par le retour à la
/// ligne que Quill exige.
library;

import 'dart:convert';

/// `{"ops":[{"insert":"<texte>\n"}]}`.
String plainToDeltaJson(String text) => jsonEncode({
      'ops': [
        {'insert': '$text\n'},
      ],
    });

/// Le texte d'un Delta, par ses `insert` de chaînes — les embeds sont
/// ignorés. `null` ou illisible : une chaîne vide.
String deltaJsonToPlain(String? json) {
  if (json == null) return '';
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map || decoded['ops'] is! List) return '';
    final buffer = StringBuffer();
    for (final op in decoded['ops'] as List) {
      if (op is Map && op['insert'] is String) buffer.write(op['insert']);
    }
    final text = buffer.toString();
    return text.endsWith('\n') ? text.substring(0, text.length - 1) : text;
  } on FormatException {
    return '';
  }
}
