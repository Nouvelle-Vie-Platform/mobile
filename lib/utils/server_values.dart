/// **Lire les scalaires que le serveur envoie** — une couleur en `#RRGGBB`, un
/// jour de calendrier en `YYYY-MM-DD`.
///
/// C'est la **forme** des valeurs, pas les **règles** de présentation : la
/// cascade de couleur, le repli de langue et la résolution des URL vivent dans
/// le modèle de lecture (`models/content_view.dart`). Ici on se contente de
/// transformer une chaîne du fil en valeur Dart.
///
/// Les deux fonctions sont **tolérantes**, et pour la même raison : une valeur
/// illisible rend `null` et ne lève jamais. Le magasin peint des écrans — une
/// faute de frappe dans le portail ne doit pas faire disparaître un contenu.
///
/// Partagées par les deux familles de la médiathèque (`teachings`,
/// `gatherings`) : le fil est le même, les règles de lecture aussi.
library;

/// Lit une couleur servie par le serveur (`#RRGGBB`, `#AARRGGBB`, ou sans `#`)
/// et rend son ARGB.
///
/// **Une valeur illisible rend `null`, et ne lève pas.** Une couleur est un
/// habillage : `null` laisse simplement la cascade continuer vers la rubrique,
/// puis vers le bleu de marque.
///
/// L'opacité est ajoutée quand elle manque : le serveur sert des couleurs
/// pleines, `0x223B8C` sans alpha serait transparent.
int? parseHexColor(String? source) {
  var raw = source?.trim();
  if (raw == null || raw.isEmpty) return null;
  if (raw.startsWith('#')) raw = raw.substring(1);
  if (raw.length != 6 && raw.length != 8) return null;
  final value = int.tryParse(raw, radix: 16);
  if (value == null) return null;
  return raw.length == 6 ? 0xFF000000 | value : value;
}

/// Lit le **jour** d'enregistrement stocké en texte (`YYYY-MM-DD`).
///
/// Ancré à minuit **UTC** non pour désigner un instant, mais pour qu'aucun
/// appareil ne puisse le déplacer : `DateTime.parse('2026-04-12')` seul rend
/// minuit en heure **locale**, et un téléphone à l'est du serveur afficherait
/// « samedi 11 » un contenu du dimanche 12.
///
/// Tolérant comme [parseHexColor], et pour la même raison : une date illisible
/// vaut « pas de date », jamais un écran qui plante.
DateTime? parseCalendarDayOrNull(String? source) {
  final raw = source?.trim();
  if (raw == null || raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}
