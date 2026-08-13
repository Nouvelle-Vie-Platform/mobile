/// Choix de la langue d'un champ **multilingue servi par le back**.
library;

/// Langue de repli du contenu servi par le back.
///
/// Le français est la langue modèle de l'application (`app_fr.arb`) comme du
/// contenu : c'est la seule dont on est certain qu'elle est toujours remplie.
const String kContentFallbackLocale = 'fr';

/// Valeur de [map] pour [locale], avec repli sur le français.
///
/// **Unique endroit** où la règle de repli est écrite — c'est le miroir Dart du
/// helper serveur. Le jour où elle change (ex. `ee` → `fr` → `en`), elle change
/// ici et nulle part ailleurs : pas de `?? title['fr']` disséminé dans les
/// widgets.
///
/// [locale] accepte aussi bien `fr` que `fr_FR` ou `fr-FR` : seule la
/// sous-étiquette de langue compte, le back ne régionalise pas ses contenus.
///
/// Une valeur **vide ou blanche** compte comme absente : une traduction
/// partielle (`ee` amorcé mais non rempli) doit se replier comme une clé
/// manquante, sinon l'écran affiche du vide.
///
/// Renvoie `''` si rien n'est exploitable — jamais `null` : un intitulé absent
/// est un trou de contenu, pas une erreur à gérer dans chaque widget.
String pick(Map<String, String> map, String locale) {
  final requested = _language(locale);

  final exact = _valueFor(map, requested);
  if (exact != null) return exact;

  final fallback = _valueFor(map, kContentFallbackLocale);
  if (fallback != null) return fallback;

  // Dernier recours : n'importe quelle langue remplie vaut mieux qu'un blanc.
  for (final value in map.values) {
    if (value.trim().isNotEmpty) return value;
  }
  return '';
}

/// Sous-étiquette de langue d'un identifiant de locale (`fr_FR` → `fr`).
///
/// Purement **mécanique** : elle découpe une chaîne, elle ne choisit aucune
/// valeur et n'applique aucun repli. C'est ce qui permet à
/// `resolveLegalLocale` (`models/legal_document_view.dart`, ADR-0035) de s'en
/// servir sans passer par [pick] — la dérogation porte sur la **règle de
/// repli**, pas sur la lecture d'une étiquette de locale.
String languageSubtag(String locale) {
  final cut = locale.indexOf(RegExp('[_-]'));
  return (cut == -1 ? locale : locale.substring(0, cut)).toLowerCase();
}

String _language(String locale) => languageSubtag(locale);

/// Valeur non blanche de [map] pour la langue [language], sinon `null`.
String? _valueFor(Map<String, String> map, String language) {
  for (final entry in map.entries) {
    if (_language(entry.key) != language) continue;
    if (entry.value.trim().isEmpty) continue;
    return entry.value;
  }
  return null;
}
