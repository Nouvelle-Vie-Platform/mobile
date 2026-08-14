/// Rendu d'une [Branch] **dans une liste de choix**.
///
/// Le pendant mobile de `app/admin/support/branch_display.ts` côté serveur, et
/// pour la même raison : la composition d'un nom de branche doit être écrite
/// **une fois**. Deux sélecteurs l'affichent (`ProfileFormScreen`,
/// `ProfileSetupSheet`) ; les laisser composer chacun le leur, c'est deux
/// définitions libres de diverger au premier ajustement.
///
/// ## Pourquoi la ville seule
///
/// Toutes les branches appartiennent à la même église, et l'écran le dit déjà
/// (« Votre branche »). Répéter « Eglise Evangélique Nouvelle Vie » sur neuf
/// lignes consécutives n'apprend rien et pousse la seule information utile —
/// la ville — hors de l'écran sur un téléphone étroit.
///
/// ## Ce fichier ne découpe **jamais** une chaîne
///
/// `city` arrive du serveur, à côté de `name` (`BranchTransformer`), et c'est
/// délibéré de sa part : « le jour où le mobile voudra afficher la seule ville,
/// il l'aura sans recomposer ni découper une chaîne ». Retirer un préfixe de
/// [Branch.name] aurait marché jusqu'au jour où l'église se renomme, et aurait
/// alors affiché des noms tronqués sans que rien n'échoue.
///
/// ## Le profil, lui, garde le nom entier
///
/// L'en-tête de l'onglet Profil affiche `branch.name` tel quel. Ce n'est pas un
/// oubli : on y lit sa fiche d'identité, pas une liste où l'on choisit — d'où
/// le nom de {@link branchSelectionLabel}, qui dit à quoi il sert et donc à
/// quoi il ne sert pas.
library;

import '../l10n/app_localizations.dart';
import '../models/models.dart';

/// **Le libellé d'une branche dans un sélecteur** : la ville, et l'Église Mère
/// se nomme.
///
/// Deux règles, dans cet ordre :
///
/// - **la ville, sinon le nom composé.** `city` est nullable côté serveur (le
///   portail permet de vider le champ) ; se replier sur [Branch.name] rend une
///   ligne longue mais **jamais fausse**, là où une ligne vide serait
///   inchoisissable. C'est l'arbitrage que `branchDisplayName` tient déjà ;
/// - **l'Église Mère porte sa mention.** Le tri la met en tête
///   ({@link branchesForSelection}) et rien ne dirait pourquoi.
///
/// L'adresse n'entre **jamais** dans ce libellé. Elle y est entrée une fois —
/// « Eglise Evangélique Nouvelle Vie Lomé · Nyekonakpoè Togbato, Lomé » — et
/// un test la tient dehors depuis.
String branchSelectionLabel(Branch branch, AppLocalizations l) {
  final label = branch.city ?? branch.name;
  return branch.isMotherChurch ? '$label · ${l.branchMotherChurch}' : label;
}

/// **Les branches dans l'ordre où on les propose** : l'Église Mère, puis les
/// villes par ordre alphabétique.
///
/// ## Pourquoi trier ici plutôt que de garder l'ordre du serveur
///
/// `GET /sync/branches` est un **flux delta** : ses lignes sortent par curseur
/// composé `(updated_at, id)`, qui répond à « qu'est-ce qui a changé » et non à
/// « dans quel ordre afficher ». L'ordre paraît stable aujourd'hui — c'est
/// celui du seed — et il **bougera** : la prochaine branche corrigée au portail
/// remontera ou descendra dans la liste, sans que personne ne comprenne
/// pourquoi.
///
/// L'Église Mère en tête parce que c'est l'assemblée que le plus grand nombre
/// cherche. Le reste alphabétique parce qu'une liste de neuf villes se parcourt
/// à l'œil, et qu'un ordre prévisible est ce qui rend ce parcours court.
///
/// ## Le tri ignore les accents, et ce n'est pas un raffinement
///
/// `compareTo` compare des unités de code : « Tsévié » passerait **après**
/// « Zanzibar », et une ville accentuée se retrouverait reléguée en fin de
/// liste. `toLowerCase` ne corrige rien — c'est le `é` lui-même qui est au-delà
/// de `z`. La table ci-dessous couvre les diacritiques du français et de l'éwé
/// tels qu'on les rencontre dans les noms de villes togolaises.
List<Branch> branchesForSelection(List<Branch> branches, AppLocalizations l) {
  final sorted = [...branches];

  sorted.sort((a, b) {
    // Une seule Église Mère dans le référentiel, mais on ne s'y fie pas : si
    // deux lignes la portaient, elles se départageraient alphabétiquement au
    // lieu de s'échanger leur place d'un `build` à l'autre.
    if (a.isMotherChurch != b.isMotherChurch) return a.isMotherChurch ? -1 : 1;
    return _sortKey(branchSelectionLabel(a, l))
        .compareTo(_sortKey(branchSelectionLabel(b, l)));
  });

  return sorted;
}

/// Les diacritiques ramenés à leur lettre de base, pour le seul tri.
const Map<String, String> _foldedLetters = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'å': 'a',
  'ç': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ɛ': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ñ': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ɔ': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'ɖ': 'd',
  'ƒ': 'f',
  'ŋ': 'n',
  'ʋ': 'v',
};

/// La forme sous laquelle deux libellés se comparent : minuscules, sans
/// diacritique. Une lettre inconnue de la table passe telle quelle — on trie
/// alors comme avant, jamais moins bien.
String _sortKey(String label) {
  final buffer = StringBuffer();
  for (final rune in label.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_foldedLetters[char] ?? char);
  }
  return buffer.toString();
}
