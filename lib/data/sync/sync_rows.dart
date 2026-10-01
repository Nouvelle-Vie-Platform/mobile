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

import '../../models/legal_document_view.dart';
import '../../models/teaching_download.dart';
import '../local/app_database.dart';
import '../local/converters/teaching_download_converter.dart';

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
    // Le contrat de téléchargement hors ligne (ADR-0038). Nul = fonds ancien,
    // « pas téléchargeable ». Additif à `playlistUrl`, il se pose en même temps.
    download: Value(_teachingDownload(item, 'download')),
    // Relatives : la résolution contre la base d'API appartient au client.
    imageLandscapeUrl: Value(_optionalText(item, 'imageLandscapeUrl')),
    imagePortraitUrl: Value(_optionalText(item, 'imagePortraitUrl')),
    imageSquareUrl: Value(_optionalText(item, 'imageSquareUrl')),
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

/// Le contrat de téléchargement (ADR-0038), ou `null` s'il est absent.
///
/// **Tolérant, à dessein.** À la différence des champs obligatoires, un
/// `download` mal formé ne coûte **pas** la page : il se lit « pas
/// téléchargeable » (aucune rendition), exactement comme son absence. Le
/// téléchargeable est additif — un enseignement s'écoute en ligne sans lui, et
/// rejeter la page entière parce qu'un objet accessoire est bancal punirait le
/// contenu principal. `null` explicite (fonds ancien) reste `null` ; seul un
/// objet présent est décodé, par le même lecteur que le convertisseur SQLite.
TeachingDownload? _teachingDownload(Map<String, Object?> item, String field) {
  final value = item[field];
  if (value == null) return null;
  return TeachingDownloadConverter.decodeMap(value);
}

/// `GET /sync/teaching_guests` — un **invité** d'un contenu de médiathèque
/// (#77).
///
/// Sept clés, relevées sur `app/mediatheque/transformers/
/// teaching_guest_transformer.ts` : `id`, `teachingId`, `contributorId`,
/// `position`, `createdAt`, `updatedAt`, `deletedAt`.
///
/// **Ni le nom de l'intervenant, ni le titre de l'enseignement** : le client
/// réplique `contributors` et `teachings` par ailleurs et joint contre ses
/// propres copies (ADR-0026, décision 3). Les servir ici les **figerait** —
/// renommer un intervenant n'écrit rien sur le pivot, donc ne bousculerait aucun
/// `updatedAt`, donc rien ne repasserait par le flux : le téléphone afficherait
/// l'ancien nom indéfiniment.
///
/// `id` est un **entier** (`increments` côté serveur), comme les référentiels —
/// pas l'UUIDv7 d'un contenu. `teachingId`, lui, est l'UUIDv7 du parent.
///
/// Les deux références sont **exigées** : un crédit sans contenu ni intervenant
/// ne désigne rien, et l'écrire à `null` occuperait la place sans jamais
/// s'afficher. `deletedAt` n'est pas lu ici — cette fonction ne voit jamais un
/// tombstone, `readsAsRetraction` a tranché avant (règle 3 de l'en-tête).
///
/// Le type de retour est **distinct** de celui de toutes les autres
/// collections, et c'est la barrière : un `Insertable<TeachingGuestRow>` n'est
/// ni un `Insertable<TeachingRow>` ni un `Insertable<ContributorRow>`, si bien
/// qu'un crédit ne peut structurellement pas se ranger dans la médiathèque ni
/// dans l'annuaire.
TeachingGuestsCompanion teachingGuestRowOf(Map<String, Object?> item) {
  const collection = 'teaching_guests';
  return TeachingGuestsCompanion.insert(
    id: Value(referenceId(collection, item)),
    teachingId: _text(collection, item, 'teachingId'),
    contributorId: _requiredInt(collection, item, 'contributorId'),
    // L'ordre **saisi**, 1-based. Une valeur absente ou d'un autre type vaut
    // `1` — le rang est un confort d'affichage, il ne coûte pas la page.
    position: Value(item['position'] is int ? item['position']! as int : 1),
    createdAt: Value(_instant(item, 'createdAt')),
    updatedAt: Value(_instant(item, 'updatedAt')),
  );
}

/// `GET /sync/gathering_types` — la rubrique de **rassemblement**.
///
/// Mêmes dix clés que `teaching_types`, servies par le même transformer côté
/// serveur : les deux familles partagent une table, et **seule la clé de
/// collection les sépare**. Les deux fonctions restent distinctes parce que
/// leurs destinations le sont — un `Insertable<TeachingTypeRow>` n'est pas un
/// `Insertable<GatheringTypeRow>`, et c'est cette barrière de type qui rend
/// impossible d'écrire une rubrique de concert dans le référentiel de la
/// médiathèque.
GatheringTypesCompanion gatheringTypeRowOf(Map<String, Object?> item) {
  const collection = 'gathering_types';
  return GatheringTypesCompanion.insert(
    id: Value(referenceId(collection, item)),
    label: _i18nMap(collection, item, 'label'),
    slug: _text(collection, item, 'slug'),
    icon: Value(_optionalText(item, 'icon')),
    color: Value(_optionalText(item, 'color')),
    position: Value(item['position'] is int ? item['position']! as int : 0),
    visibleOnHome: Value(item['visibleOnHome'] != false),
    layout: Value(_optionalText(item, 'layout')),
    createdAt: Value(_instant(item, 'createdAt')),
    updatedAt: Value(_instant(item, 'updatedAt')),
  );
}

/// `GET /sync/gatherings` — dix-huit clés, les mêmes que `teachings`.
///
/// **Ni `family`, ni durée, ni `mimeType`.** La famille ne voyage pas : la clé
/// de collection est le discriminant, et un champ dont le filtre garantit qu'il
/// vaut toujours la même valeur serait une constante déguisée en donnée.
///
/// La référence de rubrique s'appelle **`teachingTypeId`** — le nom de la
/// colonne FK de la table partagée côté serveur — et se joint sur
/// `gathering_types`. C'est une verrue assumée du protocole : la renommer aurait
/// cassé les consommateurs de `teachings`, qui la lisent déjà.
///
/// N'est appelée que sur un élément dont `readsAsRetraction` a dit qu'il n'en
/// était pas une : c'est ce qui l'autorise à exiger `title`.
GatheringsCompanion gatheringRowOf(Map<String, Object?> item) {
  const collection = 'gatherings';
  return GatheringsCompanion.insert(
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
    playlistUrl: Value(_optionalText(item, 'playlistUrl')),
    imageLandscapeUrl: Value(_optionalText(item, 'imageLandscapeUrl')),
    imagePortraitUrl: Value(_optionalText(item, 'imagePortraitUrl')),
    publishedAt: Value(_instant(item, 'publishedAt')),
    clientCreatedAt: Value(_instant(item, 'clientCreatedAt')),
    createdAt: Value(_instant(item, 'createdAt')),
    updatedAt: Value(_instant(item, 'updatedAt')),
    // Un **jour**, gardé en texte. Voir la règle 2 en tête de fichier.
    recordedAt: Value(_optionalText(item, 'recordedAt')),
    // Couleur **brute** : `null` = « hérite de ma rubrique ».
    color: Value(_optionalText(item, 'color')),
  );
}

/// `GET /sync/status_backgrounds` — le référentiel des **fonds de statut**.
///
/// Les trois arrêts du dégradé et l'encre sont écrits **tels que servis** : le
/// serveur les a dérivés à l'écriture (ADR-0030), et le client peint. Les
/// recalculer à partir de `baseColor` donnerait deux dégradés différents pour la
/// même annonce selon la version installée — sur un mur de statuts, ça se voit.
///
/// `isActive: false` est une **donnée**, pas un filtre : le fond cesse d'être
/// proposé à la composition, mais les annonces qui le portent gardent leur
/// habillage.
StatusBackgroundsCompanion statusBackgroundRowOf(Map<String, Object?> item) {
  const collection = 'status_backgrounds';
  return StatusBackgroundsCompanion.insert(
    id: Value(referenceId(collection, item)),
    // Carte de traduction, comme `teaching_types.label` : le serveur la déclare
    // en `jsonb` (ADR-0023). La lire en `_text` faisait lever sur **chaque**
    // ligne, et le cycle mourait là, avant les documents légaux.
    label: _i18nMap(collection, item, 'label'),
    baseColor: _text(collection, item, 'baseColor'),
    topColor: _text(collection, item, 'topColor'),
    bottomColor: _text(collection, item, 'bottomColor'),
    // `light` | `dark`, stocké tel quel. Une valeur inconnue se replie à
    // l'affichage plutôt que de coûter la page entière.
    ink: _text(collection, item, 'ink'),
    position: Value(item['position'] is int ? item['position']! as int : 0),
    isActive: Value(item['isActive'] != false),
    createdAt: Value(_instant(item, 'createdAt')),
    updatedAt: Value(_instant(item, 'updatedAt')),
  );
}

/// `GET /sync/official_accounts` — les **comptes officiels d'église**.
///
/// C'est ce référentiel qui porte l'en-tête d'un statut (`shortName ?? name`),
/// résolu **à la lecture** : une annonce ne porte que l'identifiant du compte.
OfficialAccountsCompanion officialAccountRowOf(Map<String, Object?> item) {
  const collection = 'official_accounts';
  return OfficialAccountsCompanion.insert(
    id: Value(referenceId(collection, item)),
    name: _text(collection, item, 'name'),
    shortName: Value(_optionalText(item, 'shortName')),
    // `null` = **national**, jamais « inconnu ».
    branchId: Value(_optionalInt(item, 'branchId')),
    // Relative : la résolution contre la base d'API appartient au client.
    avatarUrl: Value(_optionalText(item, 'avatarUrl')),
    // Entier nu, sans clé étrangère : la cible n'a pas à exister.
    backgroundId: Value(_optionalInt(item, 'backgroundId')),
    isActive: Value(item['isActive'] != false),
    createdAt: Value(_instant(item, 'createdAt')),
    updatedAt: Value(_instant(item, 'updatedAt')),
  );
}

/// `GET /sync/official_account_memberships` — **mes** appartenances.
///
/// La collection est scoppée sur l'acteur : le serveur n'y sert jamais
/// l'appartenance de quelqu'un d'autre. Le client n'a donc personne à écarter,
/// et `userId` n'est stocké que pour le diagnostic.
OfficialAccountMembershipsCompanion officialAccountMembershipRowOf(
  Map<String, Object?> item,
) {
  const collection = 'official_account_memberships';
  return OfficialAccountMembershipsCompanion.insert(
    id: Value(referenceId(collection, item)),
    accountId: _requiredInt(collection, item, 'accountId'),
    userId: _text(collection, item, 'userId'),
    createdAt: Value(_instant(item, 'createdAt')),
    updatedAt: Value(_instant(item, 'updatedAt')),
  );
}

/// `GET /sync/announcements` — les statuts de l'onglet Annonces.
///
/// **Ni `author`, ni `tag`, ni `backgroundColor`, ni durée d'affichage** : le
/// serveur sert `accountId` et `backgroundId`, qui se **joignent**. Une valeur
/// résolue à l'écriture est une valeur figée qu'aucun renommage ne viendrait
/// rafraîchir (ADR-0026, décision 3).
///
/// `expiresAt` est écrit **brut** : le serveur ne retire jamais une annonce
/// expirée du flux, et c'est la lecture qui la fait disparaître — à la seconde,
/// y compris hors-ligne.
///
/// N'est appelée que sur un élément dont `readsAsRetraction` a dit qu'il n'en
/// était pas un : c'est ce qui l'autorise à exiger `accountId` et `publishedAt`.
AnnouncementsCompanion announcementRowOf(Map<String, Object?> item) {
  const collection = 'announcements';
  return AnnouncementsCompanion.insert(
    id: contentId(collection, item),
    // Entier nu, sans clé étrangère : le compte n'a pas à être déjà arrivé.
    accountId: _requiredInt(collection, item, 'accountId'),
    branchId: Value(_optionalInt(item, 'branchId')),
    title: Value(_optionalText(item, 'title')),
    body: Value(_optionalText(item, 'body')),
    // Exigée : c'est la clé de tri du mur, une annonce sans date n'a pas de
    // place où aller.
    publishedAt: _requiredInstant(collection, item, 'publishedAt'),
    expiresAt: Value(_instant(item, 'expiresAt')),
    backgroundId: Value(_optionalInt(item, 'backgroundId')),
    backgroundImageUrl: Value(_optionalText(item, 'backgroundImageUrl')),
    isPinned: Value(item['isPinned'] == true),
    ownerId: Value(_optionalText(item, 'ownerId')),
    createdAt: Value(_instant(item, 'createdAt')),
    updatedAt: Value(_instant(item, 'updatedAt')),
  );
}

/// `GET /sync/playback_progress` — **la reprise de lecture**, partition
/// `private`.
///
/// Huit clés, relevées sur `playback_progress_transformer.ts` : `id`, `userId`,
/// `teachingId`, `positionSeconds`, `completed`, `clientCreatedAt`,
/// `createdAt`, `updatedAt`. Le descripteur y ré-expose `deletedAt`, que le
/// transformer n'expose pas — c'est le tombstone, et il est trié en amont par
/// `readsAsRetraction` : cette fonction ne le voit jamais.
///
/// **Ni durée, ni titre, ni rien du contenu.** Le serveur n'a de durée nulle
/// part, et c'est la raison pour laquelle `completed` est décidé par le client
/// et seulement stocké ici.
///
/// `teachingId` est **exigé** : une progression sans contenu à rejoindre n'a
/// aucun sens, et l'écrire à `null` la rendrait invisible tout en occupant la
/// place. `positionSeconds` l'est aussi — c'est la donnée elle-même.
///
/// **`teachingId` désigne un enseignement *ou* un rassemblement** : les deux
/// familles partagent la table côté serveur, discriminée par `family`. Le nom
/// de la clé est celui de la colonne partagée, comme la verrue déjà connue de
/// `gatherings.teachingTypeId`.
PlaybackProgressCompanion playbackProgressRowOf(Map<String, Object?> item) {
  const collection = 'playback_progress';
  return PlaybackProgressCompanion.insert(
    id: contentId(collection, item),
    // Moi, par construction : la collection est scoppée sur l'acteur. Stocké
    // pour le diagnostic, jamais pour filtrer.
    userId: Value(_optionalText(item, 'userId')),
    teachingId: _text(collection, item, 'teachingId'),
    positionSeconds: _requiredInt(collection, item, 'positionSeconds'),
    // Le serveur stocke le booléen qu'on lui a envoyé ; il n'a pas de
    // dénominateur pour en décider lui-même.
    completed: Value(item['completed'] == true),
    clientCreatedAt: Value(_instant(item, 'clientCreatedAt')),
    createdAt: Value(_instant(item, 'createdAt')),
    updatedAt: Value(_instant(item, 'updatedAt')),
  );
}

/// `GET /sync/legal_documents` — CGU, confidentialité, « à propos ».
///
/// Huit clés, relevées sur `legal_document_transformer.ts` : `id`, `kind`,
/// `version`, `lastMandatoryVersion`, `sections`, `publishedAt`, `createdAt`,
/// `updatedAt`.
///
/// **Ni `publishedBy`, ni `requiresReacceptance`** : le premier est une
/// responsabilité interne (motif d'ADR-0029), le second n'a aucun usage
/// client — c'est `lastMandatoryVersion` qui décide de la barrière, un entier
/// contre un entier, et servir le drapeau inviterait à recoder la règle ici, et
/// à la recoder faux.
///
/// Les `sections` sont écrites **entières**, cartes de traduction comprises :
/// la langue d'un document légal se décide sur le document entier, à la
/// lecture (`resolveLegalLocale`, ADR-0035). Il faut les voir toutes pour la
/// trancher — en figer une à l'écriture rendrait la règle inapplicable.
LegalDocumentsCompanion legalDocumentRowOf(Map<String, Object?> item) {
  const collection = 'legal_documents';
  return LegalDocumentsCompanion.insert(
    id: Value(referenceId(collection, item)),
    // Exigé : un document sans genre n'a aucun écran où aller. Stocké tel
    // quel, jamais refermé sur un enum — le magasin n'a pas à refuser une
    // ligne dont il ne connaîtrait pas le genre.
    kind: _text(collection, item, 'kind'),
    version: Value(item['version'] is int ? item['version']! as int : 1),
    // `null` = aucune acceptation exigée. C'est toujours le cas d'`about`.
    lastMandatoryVersion: Value(_optionalInt(item, 'lastMandatoryVersion')),
    sections: _legalSections(collection, item),
    publishedAt: Value(_instant(item, 'publishedAt')),
    createdAt: Value(_instant(item, 'createdAt')),
    updatedAt: Value(_instant(item, 'updatedAt')),
  );
}

/// `GET /sync/seasons` — la saison, dont le fond vertical habille les deux
/// lecteurs.
///
/// Huit clés, relevées sur `season_transformer.ts` : `id`, `name`,
/// `backgroundUrl`, `backgroundVerticalUrl`, `startsOn`, `endsOn`, `createdAt`,
/// `updatedAt`.
///
/// **Les deux jours restent des chaînes** (`YYYY-MM-DD`), par la règle 2 de
/// l'en-tête : les lire en `DateTime` les ancrerait à un instant, et la saison
/// changerait de jour selon le fuseau du téléphone. La comparaison reste exacte
/// — en ISO, l'ordre lexicographique est l'ordre chronologique.
///
/// **Les deux fonds sont écrits bruts**, le vertical `null` compris : c'est
/// l'absence de vertical qui apprend au lecteur qu'il doit retomber sur le
/// paysage. Résoudre ici laquelle des deux images sert reviendrait à figer à
/// l'écriture une décision de présentation (ADR-0026, décision 3).
SeasonsCompanion seasonRowOf(Map<String, Object?> item) {
  const collection = 'seasons';
  return SeasonsCompanion.insert(
    id: Value(referenceId(collection, item)),
    // Exigés : une saison sans nom, sans fond paysage ou sans bornes n'a rien
    // à habiller ni aucun jour où le faire.
    name: _text(collection, item, 'name'),
    backgroundUrl: _text(collection, item, 'backgroundUrl'),
    backgroundVerticalUrl: Value(_optionalText(item, 'backgroundVerticalUrl')),
    startsOn: _text(collection, item, 'startsOn'),
    endsOn: _text(collection, item, 'endsOn'),
    createdAt: Value(_instant(item, 'createdAt')),
    updatedAt: Value(_instant(item, 'updatedAt')),
  );
}

/// `GET /sync/presentation_vocabulary` — un **mot réglé** au portail (#81).
///
/// Sept clés, relevées sur `app/presentation/transformers/vocabulary_transformer.ts`
/// et sur la migration `*_create_presentation_vocabulary_table.ts` : `id`,
/// `kind`, `singular`, `plural`, `label`, `createdAt`, `updatedAt`.
///
/// ⚠️ **L'identifiant est une chaîne**, et c'est la seule surprise de cette
/// ligne : c'est la **clé du catalogue** (`teaching`, `sectionLatestTeachings`),
/// pas un `SERIAL`. La colonne s'appelle quand même `id` côté serveur parce que
/// le curseur composé l'exige — une PK nommée autrement y produirait un `500`,
/// c'est-à-dire un cycle coupé et toutes les collections rangées après celle-ci
/// sautées. D'où [contentId] et non [referenceId], qui lèverait sur chaque
/// ligne.
///
/// **Les trois cartes sont nullables, et `null` est une information** : c'est
/// « reviens au mot du dépôt ». Le serveur les sert explicitement plutôt que de
/// les omettre, parce qu'une clé absente laisserait le client deviner s'il doit
/// garder sa surcharge locale ou l'oublier. Une carte **vide** dit la même
/// chose, et c'est la résolution (`l10n/vocabulary.dart`) qui le tranche — pas
/// le magasin, qui stocke ce que le serveur envoie.
///
/// **`kind` est stocké tel quel**, bien qu'il se déduise du catalogue : le
/// client n'a pas le catalogue, et le déduire de la forme de la clé —
/// « contient-elle un point ? » — serait une convention qu'un seul renommage
/// casserait, en silence.
PresentationVocabularyCompanion presentationVocabularyRowOf(
  Map<String, Object?> item,
) {
  const collection = 'presentation_vocabulary';
  return PresentationVocabularyCompanion.insert(
    id: contentId(collection, item),
    // Exigé : une ligne sans nature n'est ni un terme ni une surcharge, et le
    // client ne saurait ni la ranger ni l'ignorer.
    kind: _text(collection, item, 'kind'),
    singular: Value(_optionalI18nMap(item, 'singular')),
    plural: Value(_optionalI18nMap(item, 'plural')),
    label: Value(_optionalI18nMap(item, 'label')),
    createdAt: Value(_instant(item, 'createdAt')),
    updatedAt: Value(_instant(item, 'updatedAt')),
  );
}

/// `GET /sync/decor` — le fond par défaut, quand aucune saison ne couvre le
/// jour.
///
/// Cinq clés, relevées sur `decor_transformer.ts` : `id`, `backgroundUrl`,
/// `backgroundVerticalUrl`, `createdAt`, `updatedAt`.
///
/// **Les deux adresses sont nullables**, et c'est le seul point à retenir : la
/// ligne part même quand rien n'a été déposé au portail. Traiter ce cas comme
/// une ligne mutilée coûterait la page entière, alors que « pas de décor » est
/// l'état normal d'une installation qui n'en a jamais posé.
DecorCompanion decorRowOf(Map<String, Object?> item) {
  const collection = 'decor';
  return DecorCompanion.insert(
    id: Value(referenceId(collection, item)),
    backgroundUrl: Value(_optionalText(item, 'backgroundUrl')),
    backgroundVerticalUrl: Value(_optionalText(item, 'backgroundVerticalUrl')),
    createdAt: Value(_instant(item, 'createdAt')),
    updatedAt: Value(_instant(item, 'updatedAt')),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Rouages
// ─────────────────────────────────────────────────────────────────────────────

/// Lit les sections d'un document légal, **dans l'ordre servi**.
///
/// L'ordre n'est pas une préférence d'affichage : un texte légal se lit en
/// séquence et ses articles se référencent. Une entrée sans `key` exploitable
/// est **sautée** plutôt que de coûter la page entière — la clé identifie une
/// section à travers les éditions, une section qui n'en a pas n'est rattachable
/// à rien.
List<LegalSection> _legalSections(
  String collection,
  Map<String, Object?> item,
) {
  final value = item['sections'];
  if (value is! List) throw MalformedSyncRow(collection, 'sections', value);

  final sections = <LegalSection>[];
  for (final entry in value) {
    if (entry is! Map) continue;
    final key = entry['key'];
    if (key is! String) continue;
    sections.add(
      LegalSection(
        key: key,
        heading: _localizedText(entry['heading']),
        body: _localizedText(entry['body']),
      ),
    );
  }
  return sections;
}

/// Une carte de traduction `{fr, en, ee}` **entière**, tolérante à l'absence.
///
/// À la différence d'[_i18nMap], elle ne lève pas : une section sans `heading`
/// est un trou de contenu que le rendu dessine comme un trou, pas une raison de
/// rejeter la page qui portait tout le document.
Map<String, String> _localizedText(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries)
      if (entry.value is String) entry.key.toString(): entry.value! as String,
  };
}

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

/// Entier **exigé** — un `accountId` d'annonce, une cible d'appartenance.
///
/// Comme [_text], et pour la même raison : une ligne qui ne porte pas ce que sa
/// collection exige ne devrait jamais arriver, et échouer bruyamment vaut mieux
/// que d'écrire une ligne mutilée dans le magasin qui peint les écrans.
int _requiredInt(String collection, Map<String, Object?> item, String field) {
  final value = item[field];
  if (value is int) return value;
  throw MalformedSyncRow(collection, field, value);
}

/// Instant **exigé** et ancré en UTC — la date de mise à disposition d'une
/// annonce, qui est aussi sa clé de tri.
///
/// À la différence d'[_instant], une valeur illisible lève : une annonce sans
/// date de publication n'a pas de place où aller sur le mur, et la ranger
/// arbitrairement serait pire que de rejeter la page et la rejouer.
DateTime _requiredInstant(
  String collection,
  Map<String, Object?> item,
  String field,
) {
  final parsed = _instant(item, field);
  if (parsed == null) throw MalformedSyncRow(collection, field, item[field]);
  return parsed;
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

/// Une carte de traduction **nullable**, où `null` est une valeur.
///
/// À la différence d'[_i18nMap], elle ne lève pas sur l'absence : la surcharge
/// du vocabulaire (#81) part explicitement à `null` quand le portail n'a rien
/// réglé, et ce `null` veut dire « garde le mot du dépôt ». Le traiter comme
/// une ligne mutilée coûterait la page entière, alors que c'est l'état normal
/// de presque toutes les lignes.
///
/// Une carte **vide** est rendue telle quelle plutôt que convertie en `null` :
/// le magasin stocke ce que le serveur envoie, et les deux formes se résolvent
/// de toute façon pareil à la lecture.
Map<String, String>? _optionalI18nMap(
  Map<String, Object?> item,
  String field,
) {
  final value = item[field];
  if (value is! Map) return null;
  return {
    for (final entry in value.entries)
      if (entry.value is String) entry.key.toString(): entry.value! as String,
  };
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
