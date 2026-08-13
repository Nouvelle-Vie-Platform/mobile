import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../models/legal_document_view.dart';

/// Stocke les **sections brutes** d'un document légal dans une colonne texte,
/// telles que le serveur les envoie : chacune avec ses deux cartes de
/// traduction `{fr, en, ee}` **entières**.
///
/// On stocke la carte, **jamais la langue retenue** (ADR-0026, « le magasin
/// stocke ce que le serveur envoie »). Et ici plus qu'ailleurs : la langue d'un
/// document légal ne se décide pas section par section mais sur le document
/// entier, à la lecture, par `resolveLegalLocale` (ADR-0035). Figer une langue
/// à l'écriture rendrait cette règle inapplicable — il faut voir **toutes** les
/// sections pour la trancher.
///
/// **L'ordre du tableau est préservé** : un texte légal se lit en séquence, ses
/// articles se référencent. Le rang fait partie du document.
///
/// La lecture est **tolérante** : un JSON corrompu ou une forme inattendue rend
/// une liste vide plutôt qu'une exception. Un document illisible s'affiche
/// alors comme un document pas encore synchronisé, ce qui est faux mais sans
/// danger ; une exception ferait échouer la requête qui rendait tout l'écran.
class LegalSectionsConverter extends TypeConverter<List<LegalSection>, String> {
  const LegalSectionsConverter();

  @override
  List<LegalSection> fromSql(String fromDb) {
    Object? decoded;
    try {
      decoded = jsonDecode(fromDb);
    } on FormatException {
      return const [];
    }
    if (decoded is! List) return const [];

    final sections = <LegalSection>[];
    for (final entry in decoded) {
      if (entry is! Map) continue;
      final key = entry['key'];
      if (key is! String) continue;
      sections.add(
        LegalSection(
          key: key,
          heading: _texts(entry['heading']),
          body: _texts(entry['body']),
        ),
      );
    }
    return List<LegalSection>.unmodifiable(sections);
  }

  @override
  String toSql(List<LegalSection> value) => jsonEncode([
        for (final section in value)
          {
            'key': section.key,
            'heading': section.heading,
            'body': section.body,
          },
      ]);

  /// Une carte de traduction, **entière**. Une langue inconnue de l'application
  /// est conservée telle quelle : c'est la lecture qui choisit.
  static Map<String, String> _texts(Object? raw) {
    if (raw is! Map) return const {};
    return Map<String, String>.unmodifiable({
      for (final entry in raw.entries)
        if (entry.value is String) entry.key.toString(): entry.value! as String,
    });
  }
}
