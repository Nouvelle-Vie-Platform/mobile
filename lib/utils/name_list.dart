/// **La jonction d'une liste de noms**, en Dart et non dans l'ARB.
///
/// Un ARB sait dire « Avec {noms} » ; il ne sait pas énumérer. Les formes
/// `{plural}` de l'ICU comptent des éléments, elles ne les assemblent pas, et
/// écrire une clé par cardinalité (« Avec {a} et {b} », « Avec {a}, {b} et
/// {c} », …) plafonnerait le nombre d'invités à ce que le fichier de traduction
/// a prévu. La liste s'assemble donc ici, et la phrase qui l'accueille reste
/// dans les ARB.
///
/// La forme retenue est **la plus simple qui se lise** : virgules entre tous les
/// noms sauf les deux derniers, que la conjonction sépare — « Y », « Y et Z »,
/// « Y, Z et W ». Pas de virgule avant la conjonction (elle est fautive en
/// français), et aucune ponctuation finale : l'appelant décide de la phrase.
library;

/// Assemble [names] en une énumération lisible, [and] servant de conjonction.
///
/// [and] arrive **traduit** (`context.l10n.listAnd`) : c'est un mot de la
/// langue de l'interface, pas un séparateur technique, et le coder en dur ici
/// donnerait un « et » français au milieu d'une phrase anglaise.
///
/// Rend la chaîne vide sur une liste vide, et c'est ce que l'appelant doit
/// tester : **pas d'invité, aucune ligne ne se rend** — jamais un libellé de
/// remplacement.
String joinNames(List<String> names, {required String and}) {
  if (names.isEmpty) return '';
  if (names.length == 1) return names.first;
  final head = names.sublist(0, names.length - 1).join(', ');
  return '$head $and ${names.last}';
}
