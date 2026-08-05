/// **La désérialisation des lignes — `camelCase`, et rien d'autre.**
///
/// L'enveloppe et le protocole parlent `snake_case` (`sync_protocol.dart`), les
/// lignes parlent `camelCase`. Les deux conventions restent dans deux fichiers
/// pour qu'aucune fonction commune ne vienne un jour « normaliser » les noms :
/// un désérialiseur à convention unique se trompe sur la moitié des clés.
///
/// Trois règles gouvernent ce fichier, toutes issues d'ADR-0026 (décision 3) :
///
/// 1. **On stocke ce que le serveur envoie** — la carte de traduction entière
///    et non la langue choisie, la couleur **brute** (`null` = « hérite de ma
///    rubrique ») et non la couleur résolue, toutes les rubriques y compris
///    masquées. Ce qui dépend d'autre chose se joint à la lecture.
/// 2. **Un jour n'est pas un instant** : `recordedAt` reste la chaîne
///    `YYYY-MM-DD`. La lire en `DateTime` l'ancrerait à un instant que le fuseau
///    du lecteur afficherait un jour trop tôt — la date d'un culte ne se décale
///    pas.
/// 3. **Aucune de ces fonctions ne voit jamais une rétractation** : le tri est
///    fait en amont par `readsAsRetraction`. Elles ont donc le droit d'exiger
///    les champs obligatoires, et c'est le seul endroit du moteur qui en a le
///    droit.
library;

import 'package:drift/drift.dart';

import '../local/app_database.dart';

/// Une ligne du flux qui ne porte pas ce que sa collection exige.
///
/// Elle ne devrait jamais arriver — le serveur sert des lignes complètes. Si
/// elle arrive, échouer bruyamment vaut mieux qu'écrire une ligne mutilée dans
/// le magasin qui peint les écrans : la page entière est alors rejetée, curseur
/// compris, et le tirage se rejoue au tour suivant.
class MalformedSyncRow implements Exception {
  const MalformedSyncRow(this.collection, this.field, this.value);

  /// Clé de collection du protocole.
  final String collection;

  /// Nom du champ fautif, en `camelCase` comme sur le fil.
  final String field;

  final Object? value;

  @override
  String toString() =>
      'MalformedSyncRow: « $collection » attend « $field », reçu $value';
}

// ─────────────────────────────────────────────────────────────────────────────
// Identifiants
// ─────────────────────────────────────────────────────────────────────────────

/// Identifiant **entier** d'un référentiel (PK SERIAL côté serveur).
int referenceId(String collection, Map<String, Object?> item) {
  final id = item['id'];
  if (id is int) return id;
  throw MalformedSyncRow(collection, 'id', id);
}

/// Identifiant **chaîne** d'un contenu (UUIDv7 côté serveur).
///
/// Le protocole préserve le type natif de l'identifiant de bout en bout, pour
/// ne jamais comparer `'10' < '9'` : un référentiel rend un entier, un contenu
/// rend une chaîne, et il n'y a pas de troisième forme.
String contentId(String collection, Map<String, Object?> item) {
  final id = item['id'];
  if (id is String) return id;
  throw MalformedSyncRow(collection, 'id', id);
}

// ─────────────────────────────────────────────────────────────────────────────
// Lignes
// ─────────────────────────────────────────────────────────────────────────────

/// `GET /sync/branches` — neuf clés, ni `timezone` ni `pastorId`.
BranchesCompanion branchRowOf(Map<String, Object?> item) {
  const collection = 'branches';
  return BranchesCompanion.insert(
    id: Value(referenceId(collection, item)),
    name: _text(collection, item, 'name'),
    isMotherChurch: Value(item['isMotherChurch'] == true),
    address: Value(_optionalText(item, 'address')),
    email: Value(_optionalText(item, 'email')),
    phone: Value(_optionalText(item, 'phone')),
    postalBox: Value(_optionalText(item, 'postalBox')),
    createdAt: Value(_instant(item, 'createdAt')),
    updatedAt: Value(_instant(item, 'updatedAt')),
  );
}

/// `GET /sync/teaching_types` — la rubrique.
///
/// Le `label` est écrit **entier** : c'est `utils/i18n_text.dart` → `pick` qui
/// choisit la langue à la lecture. Stocker `label['fr']` laisserait un fidèle
/// qui bascule en éwé avec des libellés français jusqu'à une resynchronisation
/// complète que rien ne déclencherait.
///
/// `visibleOnHome: false` est une **donnée**, pas un filtre : c'est ce drapeau
/// qui apprend au client qu'une rubrique a quitté l'accueil.
TeachingTypesCompanion teachingTypeRowOf(Map<String, Object?> item) {
  const collection = 'teaching_types';
  return TeachingTypesCompanion.insert(
    id: Value(referenceId(collection, item)),
    label: _i18nMap(collection, item, 'label'),
    slug: _text(collection, item, 'slug'),
    icon: Value(_optionalText(item, 'icon')),
    color: Value(_optionalText(item, 'color')),
    position: Value(item['position'] is int ? item['position']! as int : 0),
    visibleOnHome: Value(item['visibleOnHome'] != false),
    // Stocké tel quel, jamais en enum : le référentiel est administrable, et un
    // enum est une décision figée à l'écriture. Un gabarit inconnu se replie à
    // l'affichage.
    layout: Value(_optionalText(item, 'layout')),
    createdAt: Value(_instant(item, 'createdAt')),
    updatedAt: Value(_instant(item, 'updatedAt')),
  );
}

/// `GET /sync/contributors` — cinq clés, ni `prefix` ni `category`.
ContributorsCompanion contributorRowOf(Map<String, Object?> item) {
  const collection = 'contributors';
  return ContributorsCompanion.insert(
    id: Value(referenceId(collection, item)),
    name: _text(collection, item, 'name'),
    bio: Value(_optionalText(item, 'bio')),
    createdAt: Value(_instant(item, 'createdAt')),
    updatedAt: Value(_instant(item, 'updatedAt')),
  );
}

/// `GET /sync/teachings` — dix-huit clés, ni `family`, ni durée, ni `mimeType`.
///
/// N'est appelée que sur un élément dont `readsAsRetraction` a dit qu'il n'en
/// était pas une : c'est ce qui l'autorise à exiger `title`.
TeachingsCompanion teachingRowOf(Map<String, Object?> item) {
  const collection = 'teachings';
  return TeachingsCompanion.insert(
    id: contentId(collection, item),
    ownerId: Value(_optionalText(item, 'ownerId')),
    // `null` = **national**, jamais « inconnu ».
    branchId: Value(_optionalInt(item, 'branchId')),
    // Entiers nus, sans clé étrangère : la cible n'a pas à exister.
    contributorId: Value(_optionalInt(item, 'contributorId')),
    teachingTypeId: Value(_optionalInt(item, 'teachingTypeId')),
    title: _text(collection, item, 'title'),
    description: Value(_optionalText(item, 'description')),
    isLive: Value(item['isLive'] == true),
    isFullService: Value(item['isFullService'] == true),
    // Nul = l'enseignement précède son média. Une absence à dessiner, pas un
    // cas impossible.
    playlistUrl: Value(_optionalText(item, 'playlistUrl')),
    // Relatives : la résolution contre la base d'API appartient au client.
    imageLandscapeUrl: Value(_optionalText(item, 'imageLandscapeUrl')),
    imagePortraitUrl: Value(_optionalText(item, 'imagePortraitUrl')),
    publishedAt: Value(_instant(item, 'publishedAt')),
    clientCreatedAt: Value(_instant(item, 'clientCreatedAt')),
    createdAt: Value(_instant(item, 'createdAt')),
    updatedAt: Value(_instant(item, 'updatedAt')),
    // Un **jour**, gardé en texte. Voir la règle 2 en tête de fichier.
    recordedAt: Value(_optionalText(item, 'recordedAt')),
    // Couleur **brute** : `null` = « hérite de ma rubrique », et la cascade se
    // termine à la lecture (`TeachingWithRefs.color`).
    color: Value(_optionalText(item, 'color')),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Rouages
// ─────────────────────────────────────────────────────────────────────────────

String _text(String collection, Map<String, Object?> item, String field) {
  final value = item[field];
  if (value is String) return value;
  throw MalformedSyncRow(collection, field, value);
}

String? _optionalText(Map<String, Object?> item, String field) {
  final value = item[field];
  return value is String ? value : null;
}

int? _optionalInt(Map<String, Object?> item, String field) {
  final value = item[field];
  return value is int ? value : null;
}

/// Analyse un instant ISO-8601 et l'**ancre en UTC**.
///
/// L'orthographe du décalage (`Z` ou `+00:00`) dépend du fuseau du processus
/// serveur et ne fait pas partie du contrat : on analyse, on ne compare jamais
/// des chaînes. Une valeur illisible vaut absente — une date de création
/// mal formée ne doit pas coûter la page entière.
DateTime? _instant(Map<String, Object?> item, String field) {
  final value = item[field];
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toUtc();
}

/// Lit une carte de traduction `{fr, en, ee}` **entière**.
///
/// Les langues inconnues de l'application sont conservées telles quelles : le
/// choix et le repli appartiennent à `pick`, pas au stockage.
Map<String, String> _i18nMap(
  String collection,
  Map<String, Object?> item,
  String field,
) {
  final value = item[field];
  if (value is! Map) throw MalformedSyncRow(collection, field, value);
  return {
    for (final entry in value.entries)
      if (entry.value is String) entry.key.toString(): entry.value! as String,
  };
}
