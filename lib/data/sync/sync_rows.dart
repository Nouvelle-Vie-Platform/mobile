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
import '../local/converters/waveform_converter.dart';

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
    // **Le média, à plat et brut** (#130). Rien n'est décidé ici : un
    // `mediaKind` inconnu ou sans URL se stocke tel quel et se lit « pas de
    // média » (`readStatusMedia`) — une valeur que ce client ne connaît pas
    // encore ne doit pas coûter la page entière.
    mediaKind: Value(_optionalText(item, 'mediaKind')),
    mediaUrl: Value(_optionalText(item, 'mediaUrl')),
    mediaPosterUrl: Value(_optionalText(item, 'mediaPosterUrl')),
    mediaDurationMs: Value(_optionalInt(item, 'mediaDurationMs')),
    mediaWaveform: Value(WaveformConverter.decode(item['mediaWaveform'])),
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

/// `GET /sync/my_interactions` — **mes requêtes** (#148).
///
/// Quatorze clés servies, relevées sur `interaction_transformer.ts` (via
/// `InteractionPresenter.forViewer`, le lecteur étant l'auteur) et le
/// descripteur `my_interactions_descriptor.ts` : `id`, `type`, `status`,
/// `visibility`, `isAnonymous`, `branchId`, `title`, `content`, `authorId`,
/// `revealed`, `clientCreatedAt`, `createdAt`, `updatedAt`, `deletedAt`.
///
/// **Ni `branchId`, ni `revealed`** : le premier dit où la requête a été
/// routée, ce qu'aucun écran ne montre ; le second vaut toujours `false` pour
/// l'auteur (un démasquage n'a de sens que pour un autre lecteur). `authorId`
/// est gardé, et c'est le seul qui serve à filtrer : voir `MyInteractions`.
///
/// Les trois énumérations sont **exigées** et stockées brutes : une requête
/// sans type ni statut n'a rien à montrer, et l'écrire vide la rendrait
/// illisible tout en occupant la place.
MyInteractionsCompanion myInteractionRowOf(Map<String, Object?> item) {
  const collection = 'my_interactions';
  return MyInteractionsCompanion.insert(
    id: contentId(collection, item),
    type: _text(collection, item, 'type'),
    status: _text(collection, item, 'status'),
    visibility: _text(collection, item, 'visibility'),
    isAnonymous: Value(item['isAnonymous'] == true),
    title: _text(collection, item, 'title'),
    content: _text(collection, item, 'content'),
    authorId: Value(_optionalText(item, 'authorId')),
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

/// `GET /sync/auth_channels` — **par quelles portes on entre**, et ce que
/// l'application annonce (#83).
///
/// Six clés, relevées sur `app/auth/transformers/auth_channels_transformer.ts` :
/// `id`, `emailOpen`, `phoneOpen`, `loginNotice`, `createdAt`, `updatedAt`.
///
/// **Deux booléens, et non une liste de canaux** : le jeu est fermé (le contrat
/// mobile nomme deux canaux, et ADR-0019 range SMS, WhatsApp et Telegram du côté
/// des *fournisseurs* du canal téléphone). Une liste aurait laissé croire au
/// client qu'il peut en découvrir un troisième, qu'il ne saurait de toute façon
/// pas afficher.
///
/// **`loginNotice` est nullable, et `null` est une valeur** : il dit « il n'y a
/// pas d'annonce » plutôt que « je n'ai pas encore reçu les réglages », ce qui
/// autorise l'écran à retomber tout de suite sur le libellé du dépôt. La carte
/// part **entière**, jamais résolue (ADR-0023) : figer une langue ici
/// l'arrêterait à celle du moment de la synchronisation.
///
/// Les deux booléens se lisent `== true`, comme partout dans ce fichier. Un
/// champ absent vaut donc « fermé » — et cette ligne-là ne ferme rien pour
/// autant : `AuthChannelOffer.resolve` remet l'état « tous fermés » sur
/// l'e-mail seul, à la lecture, parce qu'une porte fermée ne se rouvre pas
/// depuis l'application.
AuthChannelsCompanion authChannelsRowOf(Map<String, Object?> item) {
  const collection = 'auth_channels';
  return AuthChannelsCompanion.insert(
    id: Value(referenceId(collection, item)),
    emailOpen: Value(item['emailOpen'] == true),
    phoneOpen: Value(item['phoneOpen'] == true),
    loginNotice: Value(_optionalI18nMap(item, 'loginNotice')),
    createdAt: Value(_instant(item, 'createdAt')),
    updatedAt: Value(_instant(item, 'updatedAt')),
  );
}

/// `GET /sync/device_settings` — le **réglage d'exploitation du parc**, et par
/// lui le seuil du bandeau de mise à jour (#91).
///
/// Quatre clés, relevées sur
/// `app/devices/transformers/device_settings_transformer.ts` : `id`,
/// `updateBannerMinVersion`, `createdAt`, `updatedAt`. Le transformer les
/// **énumère** une à une, et c'est ce qui l'empêche d'en porter d'autres par
/// accident : `device_settings` est la table des réglages d'exploitation,
/// c'est-à-dire l'endroit où l'on rangera demain ce qui n'a aucune vocation à
/// descendre sur un téléphone.
///
/// **Le nom du champ est celui du portail, du schéma et du PRD** :
/// `updateBannerMinVersion`, et non un `threshold` ou un `minVersion` abrégé. Un
/// seul nom du CHECK de la migration serveur jusqu'au provider Flutter est tout
/// ce qu'on attend d'un réglage unique.
///
/// **Le seuil est nullable, et `null` est une valeur** : il dit « aucun seuil
/// réglé », donc aucun bandeau pour personne. La ligne part quand même avec son
/// `null` — traiter ce cas comme une ligne mutilée coûterait la page entière,
/// alors que c'est l'état livré par la migration serveur.
///
/// ⚠️ `_optionalText` rend `null` sur tout ce qui n'est pas une chaîne, et c'est
/// le bon comportement ici : une valeur mal typée vaut « pas de seuil », jamais
/// « seuil à zéro ».
DeviceSettingsCompanion deviceSettingsRowOf(Map<String, Object?> item) {
  const collection = 'device_settings';
  return DeviceSettingsCompanion.insert(
    id: Value(referenceId(collection, item)),
    updateBannerMinVersion:
        Value(_optionalText(item, 'updateBannerMinVersion')),
    createdAt: Value(_instant(item, 'createdAt')),
    updatedAt: Value(_instant(item, 'updatedAt')),
  );
}

/// `GET /sync/profiles` — **quatre clés** : `id`, `displayName`, `avatarUrl`,
/// `updatedAt` (#96).
///
/// Relevées sur le `transform` **inline** de
/// `app/sync/descriptors/profiles_descriptor.ts` — il n'y a pas de classe
/// transformer pour cette collection. **Il n'y a pas de `createdAt`** : l'attendre
/// laisserait une colonne nulle pour toujours.
///
/// `displayName` est nullable **par contrat** : `displayNameOf` rend « Prénom
/// Nom » élagué, à défaut le titre, à défaut `null`. Un compte qui n'a jamais
/// rempli son profil n'a pas de nom, et c'est un cas courant — pas une ligne
/// mutilée. `avatarUrl` est, lui, **toujours** nul aujourd'hui : `users` ne porte
/// aucune colonne d'avatar.
ProfilesCompanion profileRowOf(Map<String, Object?> item) {
  const collection = 'profiles';
  return ProfilesCompanion.insert(
    id: contentId(collection, item),
    displayName: Value(_optionalText(item, 'displayName')),
    avatarUrl: Value(_optionalText(item, 'avatarUrl')),
    updatedAt: Value(_instant(item, 'updatedAt')),
  );
}

/// `GET /sync/groups` — **seize clés servies, quinze stockées** (#96).
///
/// Relevées sur `app/groups/transformers/group_transformer.ts` : `id`, `name`,
/// `description`, `joinPolicy`, `postPolicy`, `isWriteLocked`, `isActive`,
/// `isDirect`, `ownerId`, `ownerKind`, `ownerOfficialAccountId`,
/// `ownerContributorId`, `memberCount`, `branchIds`, `createdAt`, `updatedAt`.
///
/// **`branchIds` n'est pas stocké**, et c'est le patron de `branchRowOf` (« neuf
/// clés, ni `timezone` ni `pastorId` ») et de `teachingRowOf` (« ni `family`, ni
/// durée, ni `mimeType` ») : on ne range pas une clé que rien ne lit. Le ciblage
/// d'un groupe est déjà appliqué **par le serveur** dans le périmètre qu'il sert
/// — `applyVisibleGroupsScope` —, et aucun écran ne montre la portée d'un groupe.
/// Le jour où l'un la montrera, la colonne s'ajoutera avec son lecteur.
///
/// ⚠️ **`ownerId` est `groups.owner_user_id`**, renommé par le transformer : il
/// n'y a pas de clé `ownerUserId` sur le fil, et il est nul pour un groupe
/// institutionnel. Les trois `owner*` sont gardés tous les trois parce que
/// `ownerKind` dit **où joindre le nom de l'animateur** — `profiles`,
/// `official_accounts` ou `contributors`, les trois déjà répliquées.
///
/// `joinPolicy`, `postPolicy` et `ownerKind` sont stockés **en chaîne brute**,
/// jamais en enum : ce sont des `varchar` côté serveur, et une valeur ajoutée là
/// ferait **lever** un enum ici — donc couper le cycle, donc emporter toutes les
/// collections rangées après celle-ci. Une chaîne inconnue se replie à
/// l'affichage.
GroupsCompanion groupRowOf(Map<String, Object?> item) {
  const collection = 'groups';
  return GroupsCompanion.insert(
    id: contentId(collection, item),
    name: _text(collection, item, 'name'),
    description: Value(_optionalText(item, 'description')),
    joinPolicy: _text(collection, item, 'joinPolicy'),
    postPolicy: _text(collection, item, 'postPolicy'),
    isWriteLocked: Value(item['isWriteLocked'] == true),
    // `!= false` et non `== true` : l'activité et la direction ont des défauts
    // opposés côté serveur (`is_active` vrai, `is_direct` faux), et c'est le
    // défaut qu'on reproduit quand la clé manque.
    isActive: Value(item['isActive'] != false),
    isDirect: Value(item['isDirect'] == true),
    ownerId: Value(_optionalText(item, 'ownerId')),
    ownerKind: _text(collection, item, 'ownerKind'),
    ownerOfficialAccountId: Value(_optionalInt(item, 'ownerOfficialAccountId')),
    ownerContributorId: Value(_optionalInt(item, 'ownerContributorId')),
    memberCount: Value(_optionalInt(item, 'memberCount') ?? 0),
    createdAt: Value(_instant(item, 'createdAt')),
    updatedAt: Value(_instant(item, 'updatedAt')),
  );
}

/// `GET /sync/group_members` — **sept clés** : `id`, `groupId`, `userId`, `role`,
/// `createdAt`, `updatedAt`, `deletedAt` (#96).
///
/// `deletedAt` ne figure pas ci-dessous : `readsAsRetraction` a déjà trié en
/// amont, et une ligne tombstonée ne traverse jamais cette fonction (règle 3 du
/// moteur).
///
/// **`id` est un entier** (`increments` côté serveur), donc `referenceId` et non
/// `contentId` — seuls `groupId` et `userId`, qu'il porte, sont des UUID.
GroupMembersCompanion groupMemberRowOf(Map<String, Object?> item) {
  const collection = 'group_members';
  return GroupMembersCompanion.insert(
    id: Value(referenceId(collection, item)),
    groupId: _text(collection, item, 'groupId'),
    userId: _text(collection, item, 'userId'),
    role: _text(collection, item, 'role'),
    createdAt: Value(_instant(item, 'createdAt')),
    updatedAt: Value(_instant(item, 'updatedAt')),
  );
}

/// `GET /sync/group_join_requests` — **sept clés** : `id`, `groupId`, `userId`,
/// `status`, `createdAt`, `updatedAt`, `deletedAt` (#96).
///
/// `decidedBy` et `decidedAt` existent en base et **ne sont pas servis** : le
/// mobile n'a rien à dire de qui a tranché.
///
/// **`id` est un entier**, comme pour `group_members`.
GroupJoinRequestsCompanion groupJoinRequestRowOf(Map<String, Object?> item) {
  const collection = 'group_join_requests';
  return GroupJoinRequestsCompanion.insert(
    id: Value(referenceId(collection, item)),
    groupId: _text(collection, item, 'groupId'),
    userId: _text(collection, item, 'userId'),
    status: _text(collection, item, 'status'),
    createdAt: Value(_instant(item, 'createdAt')),
    updatedAt: Value(_instant(item, 'updatedAt')),
  );
}

/// `GET /sync/group_messages` — **neuf clés servies, huit stockées** (#96).
///
/// Relevées sur `app/groups/transformers/group_message_transformer.ts` : `id`,
/// `groupId`, `authorId`, `isSystem`, `body`, `clientMessageId`,
/// `clientCreatedAt`, `createdAt`, `deletedAt`. La neuvième est le tombstone, que
/// `readsAsRetraction` a déjà traité. **Il n'y a pas d'`updatedAt`** sur le fil,
/// bien que la colonne existe en base et porte le curseur composé.
///
/// ## ⚠️ Les deux lignes qui portent tout le contrat
///
/// ```dart
/// authorId: Value(_optionalText(item, 'authorId')),
/// isSystem: Value(item['isSystem'] == true),
/// ```
///
/// Un **nul explicite**, jamais une absence — et c'est ce qui rend le
/// **détachement** d'auteur vrai sur les téléphones déjà synchronisés. ADR-0032
/// écrit `author_id = NULL` et bouscule `updated_at` à la main, exprès pour que
/// la ligne reparte dans le flux : le mobile ne reçoit pas un message neuf, il
/// reçoit **la mise à jour d'un message qu'il a déjà**. Un `Value.absentIfNull`,
/// un `COALESCE` ou un « ne pas écraser par du vide » laisserait l'ancien uuid en
/// place, et la seule promesse qui compte — « vos messages ne vous sont plus
/// attribués » — ne serait tenue que côté serveur. `sync_dao.applyPage` applique
/// en `InsertMode.insertOrReplace` : **ne pas y déroger pour cette collection**.
///
/// Et `isSystem` est lu **séparément**, parce que le nul d'`authorId` a deux sens
/// depuis la suppression de compte : `(null, true)` = le serveur parle,
/// `(null, false)` = un auteur retiré. Le déduire d'`authorId` afficherait les
/// messages d'un membre parti comme des annonces du serveur — et rien ne
/// planterait.
GroupMessagesCompanion groupMessageRowOf(Map<String, Object?> item) {
  const collection = 'group_messages';
  return GroupMessagesCompanion.insert(
    id: contentId(collection, item),
    groupId: _text(collection, item, 'groupId'),
    // Nul **explicite** : voir l'en-tête. Ces deux lignes-ci sont le contrat.
    authorId: Value(_optionalText(item, 'authorId')),
    isSystem: Value(item['isSystem'] == true),
    // **Nullable** (#140, piège 1) : un message-média arrive avec `body: null`,
    // et l'exiger ici rejetait la page — donc coupait le cycle à chaque tour.
    body: Value(_optionalText(item, 'body')),
    clientMessageId: Value(_optionalText(item, 'clientMessageId')),
    clientCreatedAt: Value(_instant(item, 'clientCreatedAt')),
    createdAt: Value(_instant(item, 'createdAt')),
  );
}

/// `GET /sync/group_reads` — **quatre clés** : `id`, `groupId`,
/// `lastReadMessageId`, `lastReadAt` (#140, serveur M1a, `groupReadSyncRow`).
///
/// La même fonction range la ligne venue du tirage, celle du canal
/// (`read.advanced`) et celle que rend `POST /groups/:id/read` — dont la réponse
/// porte une cinquième clé, `advanced`, qui n'est pas stockée.
///
/// **Rangée par `groupId`**, exigé : c'est la clé locale. `id` est l'entier de
/// l'appartenance, gardé tel quel et toléré absent. Les deux colonnes de lecture
/// sont nulles ou renseignées ensemble côté serveur (`CHECK`) ; on n'en suppose
/// rien ici.
GroupReadsCompanion groupReadRowOf(Map<String, Object?> item) {
  const collection = 'group_reads';
  return GroupReadsCompanion.insert(
    groupId: _text(collection, item, 'groupId'),
    membershipId: Value(_optionalInt(item, 'id')),
    lastReadMessageId: Value(_optionalText(item, 'lastReadMessageId')),
    lastReadAt: Value(_instant(item, 'lastReadAt')),
  );
}

/// L'identifiant **local** d'une ligne `group_reads` : son `groupId`, et non son
/// `id` serveur. Sert au tri « rétractation ou ligne » du moteur — la collection
/// n'a pas de tombstone, il n'est donc jamais réellement employé à supprimer.
String groupReadKey(Map<String, Object?> item) {
  final id = item['groupId'];
  if (id is String) return id;
  throw MalformedSyncRow('group_reads', 'groupId', id);
}

/// `GET /sync/group_arrangements` — **cinq clés** : `id`, `groupId`,
/// `archivedAt`, `pinnedAt`, `arrangedAt` (#146, M8, `groupArrangementSyncRow`).
///
/// La même fonction range la ligne du tirage, celle du canal
/// (`arrangement.changed`) et celle que rend `PUT /groups/:id/arrangement` —
/// dont la réponse porte une sixième clé, `changed`, qui n'est pas stockée.
///
/// **Rangée par `groupId`**, exigé. Les trois instants sont tolérés absents :
/// une discussion désarchivée revient avec `archivedAt: null`.
GroupArrangementsCompanion groupArrangementRowOf(Map<String, Object?> item) {
  const collection = 'group_arrangements';
  return GroupArrangementsCompanion.insert(
    groupId: _text(collection, item, 'groupId'),
    membershipId: Value(_optionalInt(item, 'id')),
    archivedAt: Value(_instant(item, 'archivedAt')),
    pinnedAt: Value(_instant(item, 'pinnedAt')),
    arrangedAt: Value(_instant(item, 'arrangedAt')),
  );
}

/// L'identifiant **local** d'une ligne `group_arrangements` : son `groupId`.
String groupArrangementKey(Map<String, Object?> item) {
  final id = item['groupId'];
  if (id is String) return id;
  throw MalformedSyncRow('group_arrangements', 'groupId', id);
}

/// `GET /sync/message_receipts` — **l'accusé d'un de mes messages** (#142,
/// serveur M3, `messageReceiptSyncRow`) : `id` (celui du message), `groupId`,
/// `deliveredAt`, `readAt`, `updatedAt`.
///
/// La même fonction range la ligne du tirage et celle du canal
/// (`receipt.updated`). Les deux instants sont nullables et ne reculent jamais
/// côté serveur ; on stocke ce qu'il envoie, remplacé en entier. Le « lu » a
/// déjà été filtré par la réciprocité : rien n'est décidé ici.
MessageReceiptsCompanion messageReceiptRowOf(Map<String, Object?> item) {
  const collection = 'message_receipts';
  return MessageReceiptsCompanion.insert(
    id: _text(collection, item, 'id'),
    groupId: _text(collection, item, 'groupId'),
    deliveredAt: Value(_instant(item, 'deliveredAt')),
    readAt: Value(_instant(item, 'readAt')),
    updatedAt: Value(_instant(item, 'updatedAt')),
  );
}

/// `GET /sync/menu_entries` — **une entrée de menu** (#82).
///
/// **Trente et une clés**, relevées une à une sur
/// `app/presentation/transformers/menu_entry_transformer.ts`, qui les énumère
/// explicitement : `id`, `parentId`, `labelKey`, `label`, `icon`, `featured`,
/// `divided`, les **neuf** colonnes de destination, les **quatre** cases de
/// filtre, les deux colonnes de la surface médiathèque, les trois de la surface
/// accueil, les deux bornes de publication, `pageTitle`, `pageDescription`,
/// `createdAt`, `updatedAt`.
///
/// La table serveur en porte **trente-neuf** : huit ne descendent
/// **délibérément** pas — `headerVisible`/`headerPosition`,
/// `footerVisible`/`footerPosition` (les deux surfaces du site),
/// `shareTitle`/`shareDescription` (des balises `og:`), `heroImageUrl` (stocké,
/// rendu par aucune page) et `locked` (un garde-fou de l'écran
/// d'administration). L'énumération côté serveur est le garde-fou : le jour où
/// quelqu'un ajoute une colonne pour la vitrine, elle ne partira pas sur cinq
/// mille appareils par accident.
///
/// Quatre points qui se ratent en silence :
///
/// 1. **`destinationKind` est exigé, et stocké tel quel.** C'est la seule clé
///    sans laquelle la ligne ne veut rien dire. Mais elle n'est **pas** refermée
///    sur un enum : un type inconnu doit faire disparaître l'entrée **à la
///    lecture**, en silence et sans repli (décision 13 du cadrage). La refuser
///    ici coûterait la page entière, donc les entrées que ce binaire sait rendre.
/// 2. **`label` et `labelKey` sont indissociables**, et `label = null` est une
///    **valeur** : il dit « le libellé du dépôt », porté par `labelKey`. D'où
///    `_optionalI18nMap`, qui ne lève pas — c'est l'état de toutes les entrées
///    reprises de l'ancienne barre.
/// 3. **`parentId` est un entier nu, sans contrainte** (règle 4 du magasin) :
///    une sous-entrée dont le parent n'est pas encore arrivé ne doit pas faire
///    échouer `applyPage`. Elle paraîtra au cycle suivant.
/// 4. **Les deux bornes de publication sont des instants**, pas des jours — à la
///    différence de `seasons`, dont les bornes restent des chaînes `YYYY-MM-DD`.
///    Le serveur sert des `timestamp` et `ReadMenu` les compare à l'heure
///    courante : `_instant` est donc le bon lecteur ici, et ce serait le mauvais
///    là-bas.
MenuEntriesCompanion menuEntryRowOf(Map<String, Object?> item) {
  const collection = 'menu_entries';
  return MenuEntriesCompanion.insert(
    id: Value(referenceId(collection, item)),
    parentId: Value(_optionalInt(item, 'parentId')),
    labelKey: Value(_optionalText(item, 'labelKey')),
    label: Value(_optionalI18nMap(item, 'label')),
    icon: Value(_optionalText(item, 'icon')),
    featured: Value(item['featured'] == true),
    divided: Value(item['divided'] == true),
    destinationKind: _text(collection, item, 'destinationKind'),
    destinationPage: Value(_optionalText(item, 'destinationPage')),
    destinationFamily: Value(_optionalText(item, 'destinationFamily')),
    destinationRubric: Value(_optionalText(item, 'destinationRubric')),
    destinationBranch: Value(_optionalText(item, 'destinationBranch')),
    destinationSearch: Value(_optionalText(item, 'destinationSearch')),
    destinationSeriesId: Value(_optionalText(item, 'destinationSeriesId')),
    destinationContributorId:
        Value(_optionalInt(item, 'destinationContributorId')),
    destinationUrl: Value(_optionalText(item, 'destinationUrl')),
    filterRubric: Value(item['filterRubric'] == true),
    filterBranch: Value(item['filterBranch'] == true),
    filterFamily: Value(item['filterFamily'] == true),
    filterSearch: Value(item['filterSearch'] == true),
    mediaVisible: Value(item['mediaVisible'] == true),
    mediaPosition: Value(_optionalInt(item, 'mediaPosition') ?? 0),
    homeVisible: Value(item['homeVisible'] == true),
    homePosition: Value(_optionalInt(item, 'homePosition') ?? 0),
    homeLayout: Value(_optionalText(item, 'homeLayout')),
    publishedFrom: Value(_instant(item, 'publishedFrom')),
    publishedUntil: Value(_instant(item, 'publishedUntil')),
    pageTitle: Value(_optionalI18nMap(item, 'pageTitle')),
    pageDescription: Value(_optionalI18nMap(item, 'pageDescription')),
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
