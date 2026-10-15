/// **La palette fermée des notes** (N3, #191) — le bout client de la
/// validation serveur du Delta (plan « Notes et Bible » §4, « Validation de
/// `content` »).
///
/// Deux listes, et **rien d'autre n'entre** :
///
/// - [noteTextColors] : les huit couleurs de texte (`color`), en hexadécimal
///   minuscule `#rrggbb`, telles que flutter_quill les écrit dans le Delta.
/// - [noteHighlight] : la **seule** valeur de `background`, le jaune d'accent
///   de la marque (`AppColors.accent`).
///
/// Le serveur refuse (422) toute autre valeur : ce fichier doit rester aligné
/// avec sa liste, et c'est pour cela qu'il ne dépend de rien — ni de Flutter,
/// ni de flutter_quill — et qu'un test le lit tel quel.
library;

/// Les huit couleurs de texte offertes par la pastille de la feuille Format.
///
/// Choisies pour rester lisibles sur fond clair **et** sombre : pas de noir ni
/// de blanc (le texte sans `color` suit déjà le thème), des teintes moyennes.
const List<String> noteTextColors = [
  '#223b8c', // bleu de la marque
  '#00a693', // vert-bleu de la marque
  '#e53935', // rouge
  '#e6a100', // orange
  '#1fa971', // vert
  '#8e44ad', // violet
  '#d81b60', // rose
  '#6b7280', // gris
];

/// La seule valeur admise pour `background` : le jaune d'accent de la marque.
const String noteHighlight = '#f8d05e';

/// `true` si [hex] est l'une des huit couleurs de texte.
bool isNoteTextColor(String? hex) =>
    hex != null && noteTextColors.contains(hex.toLowerCase());

/// `true` si [hex] est le surlignage de la marque.
bool isNoteHighlight(String? hex) =>
    hex != null && hex.toLowerCase() == noteHighlight;
