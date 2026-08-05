import 'dart:convert';

import 'package:drift/drift.dart';

/// Stocke une **carte de traduction entière** (`{fr, en, ee}`) dans une colonne
/// texte, telle que le serveur l'envoie.
///
/// On stocke la carte, **jamais la langue retenue** (ADR-0026, « le magasin
/// stocke ce que le serveur envoie »). Figer `label['fr']` à l'écriture rendrait
/// un basculement de l'application en éwé sans effet sur les libellés déjà
/// reçus, jusqu'à une resynchronisation complète que rien ne déclencherait.
///
/// Le choix de la langue se fait **à la lecture**, et il est écrit à un seul
/// endroit : `utils/i18n_text.dart` → `pick(map, locale)`. Ce convertisseur ne
/// le réimplémente pas et ne doit jamais le faire.
///
/// La lecture est **tolérante** : une valeur illisible (JSON corrompu, forme
/// inattendue, valeur non textuelle) rend une carte vide plutôt qu'une
/// exception. Un intitulé absent est un trou de contenu ; il ne doit pas faire
/// échouer la requête qui rendait tout un écran.
class I18nMapConverter extends TypeConverter<Map<String, String>, String> {
  const I18nMapConverter();

  @override
  Map<String, String> fromSql(String fromDb) {
    Object? decoded;
    try {
      decoded = jsonDecode(fromDb);
    } on FormatException {
      return const {};
    }
    if (decoded is! Map) return const {};

    final values = <String, String>{};
    for (final entry in decoded.entries) {
      final value = entry.value;
      // Une langue inconnue de l'app est conservée telle quelle : c'est `pick`
      // qui choisit et qui se replie, pas le stockage.
      if (value is String) values[entry.key.toString()] = value;
    }
    return Map<String, String>.unmodifiable(values);
  }

  @override
  String toSql(Map<String, String> value) => jsonEncode(value);
}
