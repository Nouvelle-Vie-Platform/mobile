/// Charges utiles du **protocole de synchronisation delta**, écrites à la main.
///
/// Ces formes ne sont pas des inventions de test : chacune est **relevée dans
/// le code du serveur**. La table ci-dessous dit d'où vient quoi, pour que
/// personne ne les « corrige » plus tard sur une intuition. Avant de modifier
/// une clé, une casse ou un type ici, aller lire la source citée.
///
/// | Forme | Route serveur | Source |
/// |---|---|---|
/// | manifeste | `GET /sync` | `app/sync/transformers/sync_manifest_transformer.ts` (ADR-0016/0017/0027) |
/// | les 29 collections | `GET /sync` | `app/sync/descriptors/registry.ts` |
/// | `full_resync_required` | `GET /sync` | `app/sync/actions/build_manifest.ts` (issues serveur #48/#49) |
/// | tirage delta | `GET /sync/{collection}` | `app/sync/controllers/pull_collection_delta_controller.ts` |
/// | `next_cursor` / `has_more` / `full_resync` | `GET /sync/{collection}` | `app/sync/actions/pull_delta.ts` (ADR-0017) |
/// | curseur opaque | — | `app/sync/cursors/composite_cursor.ts` |
/// | 404 clé inconnue | `GET /sync/{collection}` | `app/common/exceptions/ressource_not_exists_exception.ts` |
/// | ligne `teachings` | `GET /sync/teachings` | `app/mediatheque/transformers/teaching_transformer.ts` |
/// | rétractation | `GET /sync/teachings` | `app/sync/descriptors/teachings_descriptor.ts` (ADR-0025) |
/// | ligne `teaching_types` | `GET /sync/teaching_types` | `app/mediatheque/transformers/teaching_type_transformer.ts` (ADR-0023) |
/// | ligne `contributors` | `GET /sync/contributors` | `app/mediatheque/transformers/contributor_transformer.ts` |
/// | ligne `teaching_guests` | `GET /sync/teaching_guests` | `app/mediatheque/transformers/teaching_guest_transformer.ts` + `app/sync/descriptors/teaching_guests_descriptor.ts` (issue serveur #436) |
/// | ligne `branches` | `GET /sync/branches` | `app/auth/transformers/branch_transformer.ts` |
/// | ligne `gatherings` | `GET /sync/gatherings` | `app/sync/descriptors/teaching_family_collection.ts` (issue serveur #133) |
/// | ligne `gathering_types` | `GET /sync/gathering_types` | idem — **le même transformer** que les deux collections d'enseignement |
/// | ligne `announcements` | `GET /sync/announcements` | PRD `annonces-comptes-officiels.md`, ADR-0029 |
/// | ligne `status_backgrounds` | `GET /sync/status_backgrounds` | ADR-0030 (les arrêts de dégradé et l'encre, dérivés à l'écriture) |
/// | ligne `official_accounts` | `GET /sync/official_accounts` | PRD `annonces-comptes-officiels.md` |
/// | ligne `official_account_memberships` | `GET /sync/official_account_memberships` | idem — collection **scoppée sur l'acteur** |
/// | ligne `legal_documents` | `GET /sync/legal_documents` | `app/legal/transformers/legal_document_transformer.ts` (ADR-0035 à ADR-0037) |
/// | ligne `presentation_vocabulary` | `GET /sync/presentation_vocabulary` | `app/presentation/transformers/vocabulary_transformer.ts` + `database/migrations/*_create_presentation_vocabulary_table.ts` (issue serveur #466) |
/// | clés du catalogue | — | `app/presentation/support/vocabulary_catalog.ts` |
/// | ligne `auth_channels` | `GET /sync/auth_channels` | `app/auth/transformers/auth_channels_transformer.ts` + `app/sync/descriptors/auth_channels_descriptor.ts` (issue serveur #468) |
/// | valeurs livrées des canaux | — | `database/migrations/*_create_auth_settings_table.ts` |
/// | ligne `menu_entries` | `GET /sync/menu_entries` | `app/presentation/transformers/menu_entry_transformer.ts` + `app/sync/descriptors/menu_entries_descriptor.ts` (issue serveur #480) |
/// | destinations et surfaces | — | `app/presentation/support/menu_catalog.ts` |
/// | entrées reprises (libellés, graine) | — | `app/presentation/support/menu_seed.ts` + `app/vitrine/support/public_nav_catalog.ts` |
/// | ligne `device_settings` | `GET /sync/device_settings` | `app/devices/transformers/device_settings_transformer.ts` + `app/sync/descriptors/device_settings_descriptor.ts` (issue serveur #475) |
/// | seuil livré du bandeau | — | `database/migrations/*_create_device_settings_table.ts` (`NULL`) |
///
/// ## Pourquoi ce fichier existe
///
/// Trois des quatre situations difficiles du socle de synchronisation **ne
/// peuvent structurellement pas se produire** sur un serveur de développement :
/// le garde-fou « droits changés » ne vise que les collections `branch` (donc
/// jamais un référentiel), la rétractation est spécifique à `teachings`, et le
/// garde-fou « curseur périmé » exige un curseur de plus de **90 jours**
/// (`config/sync.ts`, `tombstoneRetentionDays`) — que le client n'a pas le
/// droit de fabriquer (ADR-0026). À `limit=200` sur une poignée de lignes, il
/// n'y a par ailleurs jamais de seconde page. Ce sont des **formes de
/// réponse**, pas des états serveur : on les écrit à la main.
///
/// ## Deux règles de casse, et c'est voulu
///
/// - Enveloppe et protocole en **`snake_case`** : `scope_version`,
///   `current_cursor`, `has_changes`, `from_zero`, `full_resync_required`,
///   `next_cursor`, `has_more`, `full_resync`.
/// - Lignes en **`camelCase`** : `ownerId`, `branchId`, `contributorId`,
///   `teachingTypeId`, `imageLandscapeUrl`, `publishedAt`, `deletedAt`,
///   `visibleOnHome`…
///
/// Un désérialiseur qui applique une seule convention se trompe sur la moitié
/// des clés.
///
/// ## Sur les instants
///
/// Les instants sont sérialisés par Luxon côté serveur. L'**orthographe** du
/// décalage (`Z` ou `+00:00`) dépend du fuseau du processus serveur et ne fait
/// **pas** partie du contrat : le client doit *analyser* de l'ISO-8601, jamais
/// comparer des chaînes. Seul `recordedAt` échappe à la règle — c'est un
/// **jour** `YYYY-MM-DD`, délibérément : la date d'un culte ne se décale pas
/// d'un fuseau.
///
/// Toutes les valeurs ci-dessous vivent hors de l'enveloppe `data` : le double
/// ([FakeSyncServer]) la pose, et l'intercepteur d'`ApiClient` la déballe —
/// exactement comme en production.
library;

import 'dart:convert';

// ─────────────────────────────────────────────────────────────────────────────
// Curseurs
// ─────────────────────────────────────────────────────────────────────────────

/// Fabrique un curseur opaque **comme le serveur le fabrique** : base64url
/// (sans remplissage) d'un JSON compact `{u, i}` — `u` = `updated_at` en epoch
/// millisecondes, `i` = `id` de la dernière ligne livrée
/// (`app/sync/cursors/composite_cursor.ts`).
///
/// **Seul le serveur a le droit de fabriquer un curseur** (ADR-0026). Cette
/// fonction est donc ici, du côté du double, et nulle part dans `lib/` : un
/// client qui en aurait besoin serait déjà en faute. Elle sert à écrire des
/// fixtures lisibles — et à vérifier qu'un curseur *périmé* est bien à plus de
/// 90 jours, ce qu'aucun serveur de développement ne produira jamais.
String serverCursor({required String updatedAtIso, required Object id}) {
  final millis = DateTime.parse(updatedAtIso).toUtc().millisecondsSinceEpoch;
  final json = jsonEncode({'u': millis, 'i': id});
  return base64Url.encode(utf8.encode(json)).replaceAll('=', '');
}

/// Curseur de la première page de `teachings` (fin de la page 1).
final String teachingsCursorPage1 = serverCursor(
  updatedAtIso: '2026-04-05T18:00:00.000Z',
  id: '019f2c40-0000-7000-8000-000000000001',
);

/// Curseur de la deuxième page de `teachings`.
final String teachingsCursorPage2 = serverCursor(
  updatedAtIso: '2026-04-12T09:00:00.000Z',
  id: '019f2c40-0000-7000-8000-000000000002',
);

/// Curseur de la dernière page de `teachings`.
final String teachingsCursorPage3 = serverCursor(
  updatedAtIso: '2026-04-19T18:30:00.000Z',
  id: '019f2c40-0000-7000-8000-000000000003',
);

/// Curseur d'un référentiel — l'`id` y est un **entier** (PK SERIAL), pas une
/// chaîne, et le serveur préserve ce type de bout en bout pour ne jamais
/// comparer `'10' < '9'`.
final String branchesCursor = serverCursor(
  updatedAtIso: '2026-01-20T08:00:00.000Z',
  id: 3,
);

/// Curseur **périmé** : plus vieux que la fenêtre de rétention des tombstones
/// (90 jours, `config/sync.ts`). Le seul moyen d'obtenir un `full_resync` du
/// vrai serveur — et un curseur qu'aucun client n'a le droit de forger.
final String staleCursor = serverCursor(
  updatedAtIso: '2020-01-01T00:00:00.000Z',
  id: '019a0000-0000-7000-8000-000000000000',
);

// ─────────────────────────────────────────────────────────────────────────────
// `GET /sync` — le manifeste
// ─────────────────────────────────────────────────────────────────────────────

/// Les **vingt-neuf** collections du registre serveur (`app/sync/descriptors/
/// registry.ts`), **dans l'ordre du registre**, avec leur partition.
///
/// ⚠️ **Cette carte avait dérivé, et le test qui la gardait mentait.** Elle en
/// déclarait dix-neuf quand le registre en comptait vingt-cinq : `seasons`,
/// `decor`, `teaching_guests`, `group_members`, `profiles` et
/// `group_join_requests` y manquaient, toutes livrées côté serveur et quatre
/// d'entre elles répliquées par ce client. `sync_contract_test.dart` verrouillait
/// donc `hasLength(19)` — un contrat qui n'était plus celui du serveur, et qui
/// aurait rougi pour la mauvaise raison le jour d'un vrai désaccord. Remise
/// d'aplomb en #81, en relevant `registry.ts` descripteur par descripteur.
///
/// ⚠️ **Et l'en-tête du registre serveur a menti à son tour.** Il annonçait
/// « vingt-six collections » alors que la liste en portait déjà vingt-sept —
/// `auth_channels` y était fusionnée. La seule lecture qui vaille est de
/// **compter les descripteurs du tableau**, jamais de croire la phrase qui le
/// précède. Vingt-septième entrée ajoutée en #83, vingt-huitième en #91 —
/// `device_settings`, et le compte ci-dessous a de nouveau été relevé
/// **descripteur par descripteur** sur `registry.ts`, pas sur son en-tête.
/// Vingt-neuvième en #82 — `menu_entries` —, recomptée de la même façon : le
/// tableau `syncDescriptors` en porte **vingt-neuf**, et son en-tête dit
/// « vingt-neuf » ; les deux s'accordent cette fois, et c'est le tableau qui a
/// été cru.
///
/// La partition de chaque entrée est relevée sur le champ `partition:` de son
/// descripteur, jamais sur l'intuition de ce qu'une collection « devrait » être.
/// Deux surprises à ce titre, et ce sont celles qu'on corrigerait de travers :
///
/// - **`teaching_guests` est `reference`**, bien qu'elle ne porte que des
///   contenus : le pivot n'a pas de `branch_id`, le client n'a rien à ranger par
///   branche ;
/// - **`group_members`, `profiles` et `group_join_requests` sont `private`**, pas
///   `branch` : leur périmètre est **relationnel** (mes groupes, mes
///   interlocuteurs), et un changement de branche ne le remet pas en cause.
///
/// La partition n'est pas décorative : le garde-fou « droits changés » ne lève
/// `full_resync_required` que sur les collections `branch` — les privées
/// (`user_id = soi`) et les référentiels ne dépendent pas du périmètre.
///
/// Le manifeste les liste **toutes**, pas seulement celles qui ont bougé — et
/// toutes ne sont pas répliquées par ce client : `syncedCollections()` en tire
/// dix-neuf, les autres n'ont pas de table locale. Le manifeste les liste quand
/// même, le moteur les ignore.
const Map<String, String> kSyncCollections = {
  'announcements': 'branch',
  // Référentiels — aucun filtre de périmètre.
  'branches': 'reference',
  'roles': 'reference',
  'modules': 'reference',
  'contributors': 'reference',
  'teaching_types': 'reference',
  'gathering_types': 'reference',
  'status_backgrounds': 'reference',
  'legal_documents': 'reference',
  'seasons': 'reference',
  // Le vocabulaire réglé au portail (issue serveur #466, mobile #81) : rangé
  // **ici**, avec les référentiels, et pas après les contenus — un mot doit
  // arriver avant la liste qu'il intitule, et une collection sans filtre ni
  // jointure est la moins susceptible de couper le cycle.
  'presentation_vocabulary': 'reference',
  // Les entrées de menu (issue serveur #480, mobile #82) : rangées **ici**,
  // immédiatement après le vocabulaire et **avant `decor`** — un menu doit
  // arriver avant les listes qu'il intitule, puisque c'est lui qui dit quels
  // onglets existent et ce que chacun filtre. `servesAnonymous: true`, et ce
  // n'est pas un confort : la médiathèque et l'accueil sont les deux premiers
  // écrans qu'un porteur sans compte ouvre, et sans le drapeau il n'aurait
  // **aucun** onglet. `tombstoneColumn: null` — une entrée supprimée au portail
  // cesse simplement de paraître au flux.
  'menu_entries': 'reference',
  'decor': 'reference',
  // Par quelles portes on entre (issue serveur #468, mobile #83) : rangée
  // **ici**, avec les référentiels, et avant les contenus — c'est la première
  // chose qu'un porteur **sans compte** a besoin de savoir, puisque c'est tout
  // ce que son écran lui propose de faire. `servesAnonymous: true`, et ce n'est
  // pas un confort : sans ce drapeau l'écran de connexion n'apprendrait jamais
  // quels canaux sont ouverts.
  'auth_channels': 'reference',
  // Le réglage d'exploitation du parc (issue serveur #475, mobile #91) : rangé
  // **ici**, avec les référentiels, et avant les contenus — toute erreur autre
  // qu'un 404 coupe le cycle, donc toutes les collections rangées après. Un parc
  // d'appareils n'appartient à aucune branche, et la collection est servie
  // **sans compte** (`servesAnonymous: true`) : un invité ouvre l'application
  // avec un APK exactement aussi vieux que celui du membre assis à côté de lui.
  'device_settings': 'reference',
  // Privées — filtrées sur l'acteur, jamais sur une branche.
  'spiritual_notes': 'private',
  'playback_progress': 'private',
  'group_members': 'private',
  'profiles': 'private',
  'group_join_requests': 'private',
  // Ma position de lecture (serveur M1a, mobile #140) : privée — seule ma
  // lecture voyage, et seulement chez moi.
  'group_reads': 'private',
  'official_account_memberships': 'private',
  // Partagées cloisonnées — filtre « branches visibles ∪ national ».
  'events': 'branch',
  'teachings': 'branch',
  // Un pivot `reference` au milieu des contenus : il ne porte pas de
  // `branch_id`, mais il se tire après les deux collections qu'il relie.
  'teaching_guests': 'reference',
  'official_accounts': 'branch',
  'gatherings': 'branch',
  'prayer_wall': 'branch',
  'groups': 'branch',
  'group_messages': 'branch',
};

/// Clé de collection **inconnue du registre** : le mobile pourrait la demander
/// et le serveur répond alors `404`. Un client doit **sauter la collection**,
/// pas échouer sa synchro.
///
/// C'était `gatherings` jusqu'à l'issue serveur #133 — elle est désormais
/// enregistrée, et il fallait donc une clé qui ne le soit pas. `gathering_type`
/// au **singulier** est celle que le serveur documente explicitement comme
/// inconnue : c'est la faute de frappe qu'un client commettra, pas une
/// collection imaginaire.
const String kUnregisteredCollection = 'gathering_type';

/// Une entrée de manifeste, clés en `snake_case`.
Map<String, Object?> manifestEntry(
  String key, {
  required String partition,
  String? currentCursor,
  bool hasChanges = false,
  bool fromZero = false,
  bool fullResyncRequired = false,
}) {
  return {
    'key': key,
    'partition': partition,
    'current_cursor': currentCursor,
    'has_changes': hasChanges,
    'from_zero': fromZero,
    'full_resync_required': fullResyncRequired,
  };
}

/// Manifeste complet : les vingt-neuf collections, dans l'ordre du registre.
///
/// [overrides] remplace, clé par clé, les champs d'une entrée — c'est ainsi
/// qu'on écrit un cas particulier sans réécrire les douze autres lignes.
///
/// Le `current_cursor` n'est nul que dans un seul cas : première ouverture sur
/// une collection **vide** (`fromZero` sans `hasChanges`). Partout ailleurs il
/// porte la borne haute du périmètre, y compris quand il n'y a rien à tirer.
Map<String, Object?> manifestPayload({
  int scopeVersion = 4,
  bool hasChanges = true,
  bool fromZero = false,
  Map<String, Map<String, Object?>> overrides = const {},
}) {
  final collections = <Map<String, Object?>>[];
  kSyncCollections.forEach((key, partition) {
    final entry = manifestEntry(
      key,
      partition: partition,
      currentCursor: fromZero && !hasChanges ? null : _cursorFor(key),
      hasChanges: hasChanges,
      fromZero: fromZero,
    );
    collections.add({...entry, ...?overrides[key]});
  });
  return {'scope_version': scopeVersion, 'collections': collections};
}

String _cursorFor(String key) => switch (key) {
      'teachings' => teachingsCursorPage3,
      'branches' => branchesCursor,
      _ => serverCursor(
          updatedAtIso: '2026-04-19T18:30:00.000Z',
          id: '019f2c40-0000-7000-8000-0000000000ff',
        ),
    };

/// **Cas nominal** : chaque collection a un curseur courant et du delta à tirer.
Map<String, Object?> manifestNominal({int scopeVersion = 4}) =>
    manifestPayload(scopeVersion: scopeVersion);

/// **Première ouverture** : le client n'a aucun curseur (`from_zero: true`), et
/// les collections ne sont pas vides (`has_changes: true`).
Map<String, Object?> manifestFromZero({int scopeVersion = 1}) =>
    manifestPayload(scopeVersion: scopeVersion, fromZero: true);

/// **Rien à tirer** : le client est à jour partout. Le curseur courant reste
/// servi — c'est la borne haute du périmètre, pas un accusé de réception.
Map<String, Object?> manifestNothingToPull({int scopeVersion = 4}) =>
    manifestPayload(scopeVersion: scopeVersion, hasChanges: false);

/// **Les droits ont changé** (issue serveur #49) : `full_resync_required` se
/// lève sur les **seules** collections `partition: 'branch'`.
///
/// Impossible à provoquer sur un référentiel — c'est précisément pourquoi
/// vérifier ce garde-fou sur `branches` n'aurait rien vérifié du tout. La
/// `scope_version` rendue est la **courante** de l'acteur, jamais l'écho de
/// celle reçue (ADR-0027) : un écho enfermerait le client dans une boucle de
/// resync perpétuelle.
Map<String, Object?> manifestScopeChanged({int scopeVersion = 5}) =>
    manifestPayload(
      scopeVersion: scopeVersion,
      overrides: {
        for (final entry in kSyncCollections.entries)
          if (entry.value == 'branch')
            entry.key: {'full_resync_required': true},
      },
    );

/// **Curseur périmé** (issue serveur #48) : plus vieux que la fenêtre de
/// rétention des tombstones. Vise **toutes** les partitions, référentiels
/// compris — l'appareil a pu rater une suppression déjà purgée.
Map<String, Object?> manifestStaleCursor({int scopeVersion = 4}) =>
    manifestPayload(
      scopeVersion: scopeVersion,
      overrides: {
        for (final key in kSyncCollections.keys)
          key: {'full_resync_required': true},
      },
    );

/// **La `scope_version` progresse d'un appel à l'autre.**
///
/// Trois manifestes successifs : le cas nominal en version 4 ; puis la Home
/// Branch change et la version **courante** passe à 5, en réclamant le resync
/// des seules collections `branch` ; puis, une fois le resync appliqué et la
/// version retenue, plus rien à tirer — toujours en version 5.
///
/// Le client doit retenir la version **après** avoir appliqué ce que le
/// manifeste demandait, jamais avant : sinon un cycle interrompu perd le
/// resync pour de bon. La version servie n'est jamais l'écho de celle reçue
/// (ADR-0027) — un écho enfermerait un client en retard dans une boucle de
/// resync perpétuelle.
List<Map<String, Object?>> manifestScopeVersionProgression() => [
      manifestNominal(),
      manifestScopeChanged(),
      manifestNothingToPull(scopeVersion: 5),
    ];

// ─────────────────────────────────────────────────────────────────────────────
// `GET /sync/{collection}` — le tirage delta
// ─────────────────────────────────────────────────────────────────────────────

/// Une page de tirage, clés en `snake_case`.
///
/// `next_cursor` = position de la **dernière ligne livrée** ; sur une page vide
/// il **conserve** le curseur entrant ; il vaut `null` si le client partait de
/// zéro et que la collection est vide **et** en cas de `full_resync`.
Map<String, Object?> deltaPage({
  List<Object?> items = const [],
  String? nextCursor,
  bool hasMore = false,
  bool fullResync = false,
}) {
  return {
    'items': items,
    'next_cursor': nextCursor,
    'has_more': hasMore,
    'full_resync': fullResync,
  };
}

/// **Le resync forcé — un `200`, jamais une erreur.**
///
/// `full_resync: true`, `items` vide, `next_cursor` nul. C'est le piège
/// central : un client qui ne lit que `items` conclut « rien de neuf », garde
/// indéfiniment un cache dont il a raté des suppressions, et **rien ne le
/// réveillera** — le serveur, lui, répondra la même chose au tour suivant.
Map<String, Object?> fullResyncPage() => deltaPage(fullResync: true);

/// **Page vide qui conserve le curseur entrant.** Le client reste en place ;
/// ne pas confondre avec le `next_cursor: null` du resync forcé.
Map<String, Object?> emptyPageKeepingCursor(String incomingCursor) =>
    deltaPage(nextCursor: incomingCursor);

/// **Page vide d'un tirage depuis zéro** sur une collection vide : le curseur
/// reste nul, il n'y avait pas de position à conserver.
Map<String, Object?> emptyPageFromZero() => deltaPage();

// ─────────────────────────────────────────────────────────────────────────────
// Lignes `teachings` — 19 clés, `camelCase` (dont `download`, ADR-0038)
// ─────────────────────────────────────────────────────────────────────────────

/// **Un enseignement complet.** Dix-neuf clés, ni une de plus ni une de moins.
///
/// Il n'y a **ni `family`, ni `deletedAt`, ni durée, ni `mimeType`** : la
/// famille filtre côté serveur (un rassemblement ne voyage pas dans cette
/// collection), et `teachings` ne porte aucune colonne de soft-delete.
///
/// `imageLandscapeUrl`, `imagePortraitUrl` et `imageSquareUrl` sont
/// **relatives** : l'hôte de l'API change d'un environnement à l'autre, c'est au
/// client de résoudre contre sa propre base. Trois cadrages parce que l'accueil
/// rend le même enseignement à des ratios opposés (large, haut, carré).
///
/// `color` est la couleur **déjà résolue** par le serveur (cascade choisie →
/// déduite de la photo → héritée de la rubrique) : le client n'a pas à
/// réimplémenter cette priorité.
const Map<String, Object?> fullTeachingPayload = {
  'id': '019f2c40-0000-7000-8000-000000000001',
  'ownerId': 'b6f0a1c2-0000-4000-8000-000000000001',
  'branchId': 3,
  'contributorId': 7,
  'teachingTypeId': 1,
  'title': 'La foi qui déplace les montagnes',
  'description': 'Message du dimanche, temple central.',
  'isLive': false,
  'isFullService': true,
  'playlistUrl': 'https://media.example.org/hls/019f2c40/master.m3u8',
  // **Le contrat de téléchargement hors ligne** (ADR-0038), relevé sur
  // `app/mediatheque/support/download_info.ts` : `{ version, duration,
  // renditions: { low:{url,bytes}, mid:…, high:… } }`. Additif à `playlistUrl`,
  // servi par le **même** transformer (donc pour les deux familles). Les `.aac`
  // sont versionnés par `transcodeId` = `version`.
  'download': {
    'version': '019f2c40-aac-0001',
    'duration': 3600,
    'renditions': {
      'low': {
        'url': 'https://media.example.org/dl/019f2c40-aac-0001/low.aac',
        'bytes': 28800000,
      },
      'mid': {
        'url': 'https://media.example.org/dl/019f2c40-aac-0001/mid.aac',
        'bytes': 57600000,
      },
      'high': {
        'url': 'https://media.example.org/dl/019f2c40-aac-0001/high.aac',
        'bytes': 86400000,
      },
    },
  },
  'imageLandscapeUrl': '/uploads/teachings/019f2c40-landscape.webp',
  'imagePortraitUrl': '/uploads/teachings/019f2c40-portrait.webp',
  'imageSquareUrl': '/uploads/teachings/019f2c40-square.webp',
  'publishedAt': '2026-04-05T18:00:00.000Z',
  'clientCreatedAt': '2026-04-05T17:42:00.000Z',
  'createdAt': '2026-04-05T17:42:03.000Z',
  'updatedAt': '2026-04-05T18:00:00.000Z',
  'recordedAt': '2026-04-05',
  'color': '#223B8C',
};

/// **Un enseignement sans média.** `playlistUrl` nul : un enseignement existe
/// avant son média (PRD §5 ter). Un écran qui l'affiche doit prévoir l'absence
/// de lecteur, pas la supposer impossible.
///
/// Il est aussi **en direct** (`isLive: true`) : la bascule live → replay est
/// une modification de la même ligne, elle voyage dans le flux delta.
const Map<String, Object?> teachingWithoutPlaylistPayload = {
  'id': '019f2c40-0000-7000-8000-000000000002',
  'ownerId': 'b6f0a1c2-0000-4000-8000-000000000001',
  'branchId': 3,
  'contributorId': 7,
  'teachingTypeId': 2,
  'title': 'Étude biblique — Romains 8',
  'description': null,
  'isLive': true,
  'isFullService': false,
  'playlistUrl': null,
  // Pas de média, donc **pas téléchargeable** : `download` nul, comme le fonds
  // ancien jamais re-transcodé (ADR-0038). Le mobile le lit « pas de fichier ».
  'download': null,
  'imageLandscapeUrl': '/uploads/teachings/019f2c41-landscape.webp',
  'imagePortraitUrl': '/uploads/teachings/019f2c41-portrait.webp',
  'imageSquareUrl': '/uploads/teachings/019f2c41-square.webp',
  'publishedAt': '2026-04-12T09:00:00.000Z',
  'clientCreatedAt': null,
  'createdAt': '2026-04-11T20:15:00.000Z',
  'updatedAt': '2026-04-12T09:00:00.000Z',
  'recordedAt': '2026-04-12',
  'color': '#7A1F3D',
};

/// **Un enseignement à `color` nulle et à portée nationale.**
///
/// - `color: null` = « hérite de ma rubrique » (issue serveur #130, en cours).
///   Aujourd'hui le serveur résout toujours la cascade et sert une couleur ;
///   demain il servira `null`. Les deux cas sont prévus **maintenant**, pour
///   que la bascule serveur ne casse pas un désérialiseur strict déployé.
/// - `branchId: null` = **national**, pas « inconnu ». Un client qui traite le
///   nul comme une absence de branche filtrerait l'enseignement hors de toutes
///   les vues de branche.
const Map<String, Object?> teachingWithoutColorPayload = {
  'id': '019f2c40-0000-7000-8000-000000000003',
  'ownerId': 'b6f0a1c2-0000-4000-8000-000000000002',
  'branchId': null,
  'contributorId': 4,
  'teachingTypeId': 3,
  'title': 'Veillée de prière nationale',
  'description': 'Retransmission depuis la Maison du Miracle.',
  'isLive': false,
  'isFullService': false,
  'playlistUrl': 'https://media.example.org/hls/019f2c42/master.m3u8',
  // Un enseignement en ligne **pas encore téléchargeable** (fonds ancien, HLS
  // mais pas de `.aac`) : `playlistUrl` non nul, `download` nul. Le
  // téléchargeable est additif — il n'accompagne pas forcément le HLS.
  'download': null,
  'imageLandscapeUrl': '/uploads/teachings/019f2c42-landscape.webp',
  'imagePortraitUrl': '/uploads/teachings/019f2c42-portrait.webp',
  'imageSquareUrl': '/uploads/teachings/019f2c42-square.webp',
  'publishedAt': '2026-04-19T18:30:00.000Z',
  'clientCreatedAt': null,
  'createdAt': '2026-04-18T11:00:00.000Z',
  'updatedAt': '2026-04-19T18:30:00.000Z',
  'recordedAt': '2026-04-19',
  'color': null,
};

/// **Une rétractation — deux clés, pas une de plus** (ADR-0025).
///
/// Délibérément plus pauvre que les tombstones des autres collections : la
/// ligne existe toujours côté serveur et **n'a pas le droit d'être vue**.
/// Servir son titre après l'avoir dépubliée annulerait le geste. `id` suffit à
/// retirer, et ne dit rien.
///
/// `deletedAt` est le mot que le protocole emploie déjà et que le client sait
/// lire : « retire-la de ton cache ». L'instant porté est celui de l'écriture
/// qui l'a sortie du périmètre.
const Map<String, Object?> retractedTeachingPayload = {
  'id': '019f2c40-0000-7000-8000-000000000009',
  'deletedAt': '2026-04-12T09:00:00.000Z',
};

/// Une seconde rétractation, pour que la page mixte en contienne deux — dont
/// une **en dernière position**, là où un désérialiseur tolérant au premier
/// élément se fait quand même prendre.
const Map<String, Object?> otherRetractedTeachingPayload = {
  'id': '019f2c40-0000-7000-8000-00000000000a',
  'deletedAt': '2026-04-19T18:30:00.000Z',
};

/// **La page qui casse un désérialiseur strict.**
///
/// Enseignements complets et rétractations **mélangés dans le même tableau** —
/// c'est ainsi que le serveur les sert : le `transform` du descripteur choisit
/// ligne par ligne. Le flux se lit donc « rétractation ou ligne », décidé
/// **avant** toute construction d'objet. Un `fromJson` qui exige `title`,
/// `recordedAt` et `color` lèvera sur la première rétractation reçue — et
/// emportera toute la page, enseignements valides compris.
Map<String, Object?> mixedTeachingsPage({String? nextCursor}) => deltaPage(
      items: const [
        fullTeachingPayload,
        retractedTeachingPayload,
        teachingWithoutPlaylistPayload,
        teachingWithoutColorPayload,
        otherRetractedTeachingPayload,
      ],
      nextCursor: nextCursor ?? teachingsCursorPage3,
    );

/// **Scénario de pagination à `limit=1`.**
///
/// Le vrai serveur ne produira jamais de seconde page sur une poignée de
/// lignes à `limit=200` : la boucle de rattrapage du client ne serait donc
/// **jamais** exercée. À `limit=1`, elle l'est trois fois.
///
/// Chaque page rend le curseur de sa **dernière ligne livrée** ; le client le
/// rejoue tel quel en `?since=`. La dernière page porte `has_more: false` —
/// c'est ce drapeau qui arrête la boucle, pas un tableau vide.
List<Map<String, Object?>> teachingsPagesAtLimitOne() => [
      deltaPage(
        items: const [fullTeachingPayload],
        nextCursor: teachingsCursorPage1,
        hasMore: true,
      ),
      deltaPage(
        items: const [retractedTeachingPayload],
        nextCursor: teachingsCursorPage2,
        hasMore: true,
      ),
      deltaPage(
        items: const [teachingWithoutColorPayload],
        nextCursor: teachingsCursorPage3,
      ),
    ];

// ─────────────────────────────────────────────────────────────────────────────
// Lignes des référentiels
// ─────────────────────────────────────────────────────────────────────────────

/// Les trois gabarits d'affichage d'une rubrique (`TEACHING_TYPE_LAYOUTS`,
/// jeu fermé garanti par un CHECK en base).
const List<String> kTeachingTypeLayouts = ['hero', 'carousel', 'list'];

/// **Une rubrique mise en avant.** Le `label` part en **carte de traduction
/// complète** `{fr, en, ee}` (ADR-0023) : le serveur n'ose pas choisir la
/// langue à la place du client, qui replie lui-même (`fr` est la cible
/// garantie). Le `slug` est la clé stable que le mobile reconnaît — il survit
/// au renommage du libellé.
const Map<String, Object?> heroTeachingTypePayload = {
  'id': 1,
  'label': {
    'fr': 'Message du dimanche',
    'en': 'Sunday message',
    'ee': 'Kɔsiɖagbe ƒe nya',
  },
  'slug': 'dimanche',
  'icon': 'church',
  'color': '#223B8C',
  'position': 1,
  'visibleOnHome': true,
  'layout': 'hero',
  'createdAt': '2026-01-10T08:00:00.000Z',
  'updatedAt': '2026-03-02T08:00:00.000Z',
};

/// **Une rubrique en carrousel.**
const Map<String, Object?> carouselTeachingTypePayload = {
  'id': 2,
  'label': {
    'fr': 'Étude biblique',
    'en': 'Bible study',
    'ee': 'Biblia nusɔsrɔ̃'
  },
  'slug': 'etude',
  'icon': 'book',
  'color': '#7A1F3D',
  'position': 2,
  'visibleOnHome': true,
  'layout': 'carousel',
  'createdAt': '2026-01-10T08:00:00.000Z',
  'updatedAt': '2026-01-10T08:00:00.000Z',
};

/// **Une rubrique retirée de l'accueil** (`visibleOnHome: false`).
///
/// Elle voyage quand même : le flux sert le référentiel **entier**, masquées
/// comprises, et c'est ce drapeau qui apprend au client qu'une rubrique a
/// quitté l'accueil. La filtrer côté serveur ferait disparaître la ligne du
/// delta au lieu de propager le changement — le client garderait à l'écran une
/// rubrique retirée.
const Map<String, Object?> hiddenTeachingTypePayload = {
  'id': 3,
  'label': {'fr': 'Prière', 'en': 'Prayer', 'ee': 'Gbedodoɖa'},
  'slug': 'priere',
  'icon': 'hands',
  'color': '#0F6E5C',
  'position': 3,
  'visibleOnHome': false,
  'layout': 'list',
  'createdAt': '2026-01-10T08:00:00.000Z',
  'updatedAt': '2026-04-01T09:30:00.000Z',
};

/// Page complète du référentiel des rubriques.
Map<String, Object?> teachingTypesPage() => deltaPage(
      items: const [
        heroTeachingTypePayload,
        carouselTeachingTypePayload,
        hiddenTeachingTypePayload,
      ],
      nextCursor: serverCursor(
        updatedAtIso: '2026-04-01T09:30:00.000Z',
        id: 3,
      ),
    );

/// **Un contributeur.** Cinq clés seulement : le transformer ne sert ni
/// `prefix` ni `category`. `id` est un **entier** (PK SERIAL du référentiel).
const Map<String, Object?> contributorPayload = {
  'id': 7,
  'name': 'Pasteur Komla Anani',
  'bio': 'Berger de la Maison du Miracle depuis 2011.',
  'createdAt': '2026-01-05T08:00:00.000Z',
  'updatedAt': '2026-02-11T14:20:00.000Z',
};

/// Un contributeur sans biographie (`bio` nulle).
const Map<String, Object?> contributorWithoutBioPayload = {
  'id': 4,
  'name': 'Chorale Nouvelle Vie',
  'bio': null,
  'createdAt': '2026-01-05T08:00:00.000Z',
  'updatedAt': '2026-01-05T08:00:00.000Z',
};

/// Page du référentiel des contributeurs.
Map<String, Object?> contributorsPage() => deltaPage(
      items: const [contributorPayload, contributorWithoutBioPayload],
      nextCursor: serverCursor(
        updatedAtIso: '2026-02-11T14:20:00.000Z',
        id: 7,
      ),
    );

/// **Une branche.** Métadonnées publiques ; ni `timezone` ni `pastorId` ne
/// voyagent (le transformer ne les sert pas).
const Map<String, Object?> branchPayload = {
  'id': 3,
  'name': 'Maison du Miracle — Bè Kpota',
  'isMotherChurch': false,
  'address': 'Rue des Palmiers, Lomé',
  'email': 'bekpota@example.org',
  'phone': '+22890123456',
  'postalBox': 'BP 1234',
  'createdAt': '2025-11-02T08:00:00.000Z',
  'updatedAt': '2026-01-20T08:00:00.000Z',
};

/// L'église mère, aux champs facultatifs absents (`null`).
const Map<String, Object?> motherBranchPayload = {
  'id': 1,
  'name': 'Maison du Miracle — Temple Central',
  'isMotherChurch': true,
  'address': null,
  'email': null,
  'phone': null,
  'postalBox': null,
  'createdAt': '2025-11-02T08:00:00.000Z',
  'updatedAt': '2025-11-02T08:00:00.000Z',
};

/// Page du référentiel des branches — la collection sur laquelle **aucune** des
/// trois situations difficiles ne peut se produire, et c'est tout le propos.
Map<String, Object?> branchesPage() => deltaPage(
      items: const [motherBranchPayload, branchPayload],
      nextCursor: branchesCursor,
    );

// ─────────────────────────────────────────────────────────────────────────────
// Lignes des rassemblements — issue serveur #133
// ─────────────────────────────────────────────────────────────────────────────

/// **Un rassemblement complet.** Les mêmes dix-neuf clés qu'un enseignement, et
/// ce n'est pas une coïncidence : les deux familles vivent dans la même table
/// côté serveur et passent par le **même transformer**
/// (`teaching_family_collection.ts`).
///
/// Trois choses n'y sont **pas**, et chacune est une décision :
///
/// - **`family`** — la clé de collection est déjà le discriminant, et le filtre
///   garantit que le champ vaudrait toujours `'gathering'`. Une constante
///   déguisée en donnée installerait chez le client l'idée qu'il lui revient de
///   trier ce qui arrive par un canal.
/// - **`deletedAt`** — un rassemblement complet n'en porte pas ; c'est la
///   rétractation qui l'apporte, et elle n'a que deux clés.
/// - une durée, un `mimeType` — le serveur n'en sert pour aucune des deux
///   familles.
///
/// > **La verrue** : la référence de rubrique s'appelle `teachingTypeId` — le
/// > nom de la colonne FK de la table partagée — et se joint sur
/// > `gathering_types`. La renommer aurait cassé les consommateurs de
/// > `teachings`, qui la lisent déjà.
const Map<String, Object?> fullGatheringPayload = {
  'id': '019f3a10-0000-7000-8000-000000000001',
  'ownerId': 'b6f0a1c2-0000-4000-8000-000000000001',
  'branchId': 3,
  'contributorId': 4,
  'teachingTypeId': 11,
  'title': 'Concert de louange — Nuit de gloire',
  'description': 'Soirée de louange au temple central.',
  'isLive': false,
  'isFullService': false,
  'playlistUrl': 'https://media.example.org/hls/019f3a10/master.m3u8',
  // Le **même** transformer sert la clé pour les deux familles (ADR-0038), mais
  // les rassemblements ne sont **pas** téléchargeables en v1 : `download` nul.
  // Le mobile ne le parse d'ailleurs pas côté `gatherings` (hors périmètre).
  'download': null,
  'imageLandscapeUrl': '/uploads/teachings/019f3a10-landscape.webp',
  'imagePortraitUrl': '/uploads/teachings/019f3a10-portrait.webp',
  'imageSquareUrl': '/uploads/teachings/019f3a10-square.webp',
  'publishedAt': '2026-05-03T20:00:00.000Z',
  'clientCreatedAt': null,
  'createdAt': '2026-05-02T09:00:00.000Z',
  'updatedAt': '2026-05-03T20:00:00.000Z',
  'recordedAt': '2026-05-02',
  'color': '#0F6E5C',
};

/// **Un rassemblement à couleur nulle et à portée nationale.** `color: null` =
/// « hérite de ma rubrique » ; `branchId: null` = **national**, pas « inconnu ».
const Map<String, Object?> gatheringWithoutColorPayload = {
  'id': '019f3a10-0000-7000-8000-000000000002',
  'ownerId': 'b6f0a1c2-0000-4000-8000-000000000002',
  'branchId': null,
  'contributorId': 7,
  'teachingTypeId': 12,
  'title': 'Convention nationale 2026',
  'description': null,
  'isLive': false,
  'isFullService': false,
  'playlistUrl': null,
  // Rassemblement non téléchargeable (v1) : `download` nul, comme partout.
  'download': null,
  'imageLandscapeUrl': '/uploads/teachings/019f3a11-landscape.webp',
  'imagePortraitUrl': null,
  'imageSquareUrl': '/uploads/teachings/019f3a11-square.webp',
  'publishedAt': '2026-05-10T08:00:00.000Z',
  'clientCreatedAt': null,
  'createdAt': '2026-05-09T18:00:00.000Z',
  'updatedAt': '2026-05-10T08:00:00.000Z',
  'recordedAt': '2026-05-09',
  'color': null,
};

/// **Une rétractation de rassemblement — deux clés, pas une de plus**
/// (ADR-0025). Exactement la forme de `teachings` : c'est le même descripteur.
const Map<String, Object?> retractedGatheringPayload = {
  'id': '019f3a10-0000-7000-8000-000000000009',
  'deletedAt': '2026-05-10T08:00:00.000Z',
};

/// Page mixte de `gatherings` : lignes complètes et rétractation **dans le même
/// tableau**, la rétractation en dernier — là où un désérialiseur tolérant au
/// premier élément se fait quand même prendre.
Map<String, Object?> mixedGatheringsPage({String? nextCursor}) => deltaPage(
      items: const [
        fullGatheringPayload,
        gatheringWithoutColorPayload,
        retractedGatheringPayload,
      ],
      nextCursor: nextCursor ??
          serverCursor(
            updatedAtIso: '2026-05-10T08:00:00.000Z',
            id: '019f3a10-0000-7000-8000-000000000009',
          ),
    );

/// **Une rubrique de rassemblement mise en avant.**
///
/// Le référentiel `gathering_types` a la même forme que `teaching_types` — même
/// table, même transformer — mais il ne se mélange **jamais** avec lui : le
/// serveur ne livre à chacun que les rubriques de sa famille. Les identifiants
/// des deux référentiels n'ont aucune raison d'être disjoints ; ici on les prend
/// distincts pour la lisibilité, et `gathering_dao_test.dart` couvre exprès le
/// cas où ils se recouvrent.
const Map<String, Object?> heroGatheringTypePayload = {
  'id': 11,
  'label': {'fr': 'Concerts', 'en': 'Concerts', 'ee': 'Hadzidzi'},
  'slug': 'concerts',
  'icon': 'music',
  'color': '#0F6E5C',
  'position': 1,
  'visibleOnHome': true,
  'layout': 'hero',
  'createdAt': '2026-02-01T08:00:00.000Z',
  'updatedAt': '2026-04-20T08:00:00.000Z',
};

/// **Une rubrique de rassemblement en liste.**
const Map<String, Object?> listGatheringTypePayload = {
  'id': 12,
  'label': {'fr': 'Conventions', 'en': 'Conventions', 'ee': 'Takpekpewo'},
  'slug': 'conventions',
  'icon': 'groups',
  'color': null,
  'position': 2,
  'visibleOnHome': true,
  'layout': 'list',
  'createdAt': '2026-02-01T08:00:00.000Z',
  'updatedAt': '2026-02-01T08:00:00.000Z',
};

/// Page complète du référentiel des rubriques de rassemblement.
Map<String, Object?> gatheringTypesPage() => deltaPage(
      items: const [heroGatheringTypePayload, listGatheringTypePayload],
      nextCursor: serverCursor(
        updatedAtIso: '2026-04-20T08:00:00.000Z',
        id: 11,
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Lignes des annonces — PRD serveur `annonces-comptes-officiels.md`
// ─────────────────────────────────────────────────────────────────────────────

/// **Un fond de statut**, tel que le référentiel partagé le sert.
///
/// Les trois arrêts du dégradé arrivent **déjà dérivés** de `baseColor`, et
/// `ink` dit quelle encre reste lisible dessus (ADR-0030). Le client peint ; il
/// ne recalcule ni la variation ni le contraste. Un client qui dériverait ses
/// propres arrêts rendrait deux dégradés différents pour la même annonce selon
/// la version installée — sur un mur de statuts, ça se voit.
const Map<String, Object?> brandStatusBackgroundPayload = {
  'id': 1,
  // **Carte de traduction**, comme le serveur la sert (`jsonb`, ADR-0023, sur
  // le patron de `teaching_types.label`). Ce fixture a porté une chaîne nue
  // jusqu'à la v6 du schéma, et c'est ce qui a rendu le bug invisible : le
  // client la lisait en `_text`, tout passait ici, et **chaque** ligne réelle
  // faisait lever — ce qui coupait le cycle de synchronisation avant les six
  // collections rangées après celle-ci. Un fixture qui ment sur la forme du
  // contrat ne teste plus le contrat.
  'label': {'fr': 'Bleu de marque'},
  'baseColor': '#223B8C',
  'topColor': '#2E4CAE',
  'bottomColor': '#16265C',
  'ink': 'light',
  'position': 1,
  'isActive': true,
  'createdAt': '2026-02-01T08:00:00.000Z',
  'updatedAt': '2026-02-01T08:00:00.000Z',
};

/// **Un fond clair** — `ink: 'dark'`. C'est le cas qui prouve que l'encre est
/// une donnée et non une déduction : sur un or pâle, un texte blanc devient
/// illisible, et personne ne s'en aperçoit avant les utilisateurs.
const Map<String, Object?> lightStatusBackgroundPayload = {
  'id': 2,
  'label': {'fr': 'Or accent'},
  'baseColor': '#F8D05E',
  'topColor': '#FBE08F',
  'bottomColor': '#D6A92F',
  'ink': 'dark',
  'position': 2,
  'isActive': true,
  'createdAt': '2026-02-01T08:00:00.000Z',
  'updatedAt': '2026-02-01T08:00:00.000Z',
};

/// **Un fond retiré du catalogue** (`isActive: false`).
///
/// Il voyage quand même, et c'est le même motif que `visibleOnHome` d'une
/// rubrique : le drapeau apprend au client que le fond n'est plus proposé à la
/// composition, alors que les annonces qui le portent déjà gardent leur
/// habillage. Le filtrer côté serveur ferait perdre leur dégradé à des statuts
/// parfaitement valides.
const Map<String, Object?> retiredStatusBackgroundPayload = {
  'id': 3,
  'label': {'fr': 'Nuit profonde'},
  'baseColor': '#0C1422',
  'topColor': '#16223A',
  'bottomColor': '#050810',
  'ink': 'light',
  'position': 3,
  'isActive': false,
  'createdAt': '2026-02-01T08:00:00.000Z',
  'updatedAt': '2026-04-02T08:00:00.000Z',
};

/// Page complète du référentiel des fonds.
Map<String, Object?> statusBackgroundsPage() => deltaPage(
      items: const [
        brandStatusBackgroundPayload,
        lightStatusBackgroundPayload,
        retiredStatusBackgroundPayload,
      ],
      nextCursor: serverCursor(
        updatedAtIso: '2026-04-02T08:00:00.000Z',
        id: 3,
      ),
    );

/// **Les CGU**, complètes dans les trois langues (`legal_document_transformer.ts`).
///
/// Huit clés, et surtout **ni `publishedBy` ni `requiresReacceptance`** : le
/// premier est une responsabilité interne, le second n'a aucun usage client —
/// c'est `lastMandatoryVersion` qui décide de la barrière, un entier contre un
/// entier.
///
/// Les `sections` arrivent **entières**, cartes de traduction comprises : la
/// langue se décide à la lecture et sur le document entier (ADR-0035). Le corps
/// est en **Markdown restreint** — quatre constructions et rien d'autre.
const Map<String, Object?> termsDocumentPayload = {
  'id': 1,
  'kind': 'cgu',
  'version': 3,
  'lastMandatoryVersion': 3,
  'sections': [
    {
      'key': 'objet',
      'heading': {'fr': 'Objet', 'en': 'Purpose', 'ee': 'Taɖodzinu'},
      'body': {
        'fr': 'L\'application est éditée par l\'**Église Évangélique '
            'Nouvelle Vie**.',
        'en': 'The app is published by **Église Évangélique Nouvelle Vie**.',
        'ee': 'Sɔlemeha **Église Évangélique Nouvelle Vie** ye tsɔ dɔwɔna sia.',
      },
    },
    {
      'key': 'contact',
      'heading': {'fr': 'Contact', 'en': 'Contact', 'ee': 'Kadodo'},
      'body': {
        'fr':
            'Écrivez à [contact@nouvelle-vie.tg](mailto:contact@nouvelle-vie.tg).',
        'en':
            'Write to [contact@nouvelle-vie.tg](mailto:contact@nouvelle-vie.tg).',
        'ee':
            'Ŋlɔ na [contact@nouvelle-vie.tg](mailto:contact@nouvelle-vie.tg).',
      },
    },
  ],
  'publishedAt': '2026-03-09T09:00:00.000Z',
  'createdAt': '2026-01-04T09:00:00.000Z',
  'updatedAt': '2026-03-09T09:00:00.000Z',
};

/// **La politique de confidentialité**, dont **une seule** section manque en
/// éwé.
///
/// C'est la fixture qui rend visible la dérogation d'ADR-0035 : appliqué champ
/// par champ, `pick` rendrait ce document en éwé avec un article en français.
/// Le repli en bloc le fait sortir **intégralement** en français.
const Map<String, Object?> privacyDocumentPayload = {
  'id': 2,
  'kind': 'privacy',
  'version': 2,
  'lastMandatoryVersion': 2,
  'sections': [
    {
      'key': 'donnees',
      'heading': {
        'fr': 'Vos données',
        'en': 'Your data',
        'ee': 'Wò nyatakakawo'
      },
      'body': {
        'fr': 'Nous collectons :\n- votre nom\n- votre adresse e-mail',
        'en': 'We collect:\n- your name\n- your e-mail address',
        'ee': 'Míeƒoa nu siawo nu ƒu :\n- wò ŋkɔ\n- wò e-mail',
      },
    },
    {
      'key': 'conservation',
      'heading': {'fr': 'Conservation', 'en': 'Retention'},
      'body': {
        'fr': 'Vos données sont conservées *trois ans*.',
        'en': 'Your data is kept for *three years*.',
      },
    },
  ],
  'publishedAt': '2026-02-14T09:00:00.000Z',
  'createdAt': '2026-01-04T09:00:00.000Z',
  'updatedAt': '2026-02-14T09:00:00.000Z',
};

/// **« À propos »** — le genre qui n'entre **jamais** dans la barrière :
/// `lastMandatoryVersion` y est nul, accepter une présentation n'a pas de sens.
const Map<String, Object?> aboutDocumentPayload = {
  'id': 3,
  'kind': 'about',
  'version': 1,
  'lastMandatoryVersion': null,
  'sections': [
    {
      'key': 'presentation',
      'heading': {
        'fr': 'Notre église',
        'en': 'Our church',
        'ee': 'Míaƒe sɔleme'
      },
      'body': {
        'fr': 'Une église de la Maison du Miracle.',
        'en': 'A Maison du Miracle church.',
        'ee': 'Maison du Miracle ƒe sɔleme.',
      },
    },
  ],
  'publishedAt': '2026-01-04T09:00:00.000Z',
  'createdAt': '2026-01-04T09:00:00.000Z',
  'updatedAt': '2026-01-04T09:00:00.000Z',
};

/// Page complète du référentiel des documents légaux. Les trois genres arrivent
/// d'un coup : la collection n'a **aucun filtre de périmètre**.
Map<String, Object?> legalDocumentsPage() => deltaPage(
      items: const [
        termsDocumentPayload,
        privacyDocumentPayload,
        aboutDocumentPayload,
      ],
      nextCursor: serverCursor(
        updatedAtIso: '2026-03-09T09:00:00.000Z',
        id: 3,
      ),
    );

/// **Un compte officiel d'église.** C'est lui qui signe un statut : l'annonce ne
/// porte que son identifiant, et l'en-tête se joint (`shortName ?? name`).
///
/// `avatarUrl` est **relative**, comme toutes les URL de média du protocole.
const Map<String, Object?> officialAccountPayload = {
  'id': 1,
  'name': 'Maison du Miracle — Temple Central',
  'shortName': 'Maison du Miracle',
  'branchId': 1,
  'avatarUrl': '/uploads/accounts/temple-central.webp',
  'backgroundId': 1,
  'isActive': true,
  'createdAt': '2026-02-01T08:00:00.000Z',
  'updatedAt': '2026-02-01T08:00:00.000Z',
};

/// **Un compte sans nom court ni avatar**, à portée nationale (`branchId` nul).
const Map<String, Object?> minimalOfficialAccountPayload = {
  'id': 2,
  'name': 'Diaconat',
  'shortName': null,
  'branchId': null,
  'avatarUrl': null,
  'backgroundId': null,
  'isActive': true,
  'createdAt': '2026-02-01T08:00:00.000Z',
  'updatedAt': '2026-02-01T08:00:00.000Z',
};

/// Page du référentiel des comptes officiels.
Map<String, Object?> officialAccountsPage() => deltaPage(
      items: const [officialAccountPayload, minimalOfficialAccountPayload],
      nextCursor: serverCursor(
        updatedAtIso: '2026-02-01T08:00:00.000Z',
        id: 2,
      ),
    );

/// **Une appartenance — la mienne.** La collection est scoppée sur l'acteur : le
/// serveur n'y sert jamais celle de quelqu'un d'autre, `userId` est donc
/// toujours le porteur du jeton.
const Map<String, Object?> membershipPayload = {
  'id': 10,
  'accountId': 2,
  'userId': 'b6f0a1c2-0000-4000-8000-000000000001',
  'createdAt': '2026-03-01T08:00:00.000Z',
  'updatedAt': '2026-03-01T08:00:00.000Z',
};

/// Page des appartenances.
Map<String, Object?> membershipsPage() => deltaPage(
      items: const [membershipPayload],
      nextCursor: serverCursor(
        updatedAtIso: '2026-03-01T08:00:00.000Z',
        id: 10,
      ),
    );

/// **Une annonce complète.**
///
/// Trois champs qu'un lecteur du modèle mobile d'avant chercherait n'y sont
/// **pas**, et chacun est une décision :
///
/// - **`author`** — remplacé par `accountId`, qui se joint sur
///   `official_accounts`. Une chaîne d'auteur recopiée dans chaque annonce est
///   une valeur figée : renommer le compte laisserait les téléphones sur
///   l'ancien nom, indéfiniment et en silence ;
/// - **`backgroundColor`** — remplacé par `backgroundId`, qui se joint sur
///   `status_backgrounds` ;
/// - **`tag`** — abandonné : le compte occupe déjà l'en-tête, « COE » en auteur
///   *et* en pastille serait la même information dite deux fois.
///
/// Il n'y a pas davantage de durée d'affichage ni de libellé d'action. Les cinq
/// champs `media*` sont là, **nuls** : `announcement_transformer.ts` les énumère
/// sur toute annonce, et une annonce texte les sert à `null`.
const Map<String, Object?> fullAnnouncementPayload = {
  'id': '019f5a00-0000-7000-8000-000000000001',
  'accountId': 1,
  'branchId': 1,
  'title': 'Veillée de prière',
  'body': 'Vendredi de 20h à minuit au Temple Central.',
  'publishedAt': '2026-05-20T18:00:00.000Z',
  'expiresAt': null,
  'backgroundId': 1,
  'backgroundImageUrl': null,
  'mediaKind': null,
  'mediaUrl': null,
  'mediaPosterUrl': null,
  'mediaDurationMs': null,
  'mediaWaveform': null,
  'isPinned': true,
  'ownerId': 'b6f0a1c2-0000-4000-8000-000000000001',
  'createdAt': '2026-05-20T17:55:00.000Z',
  'updatedAt': '2026-05-20T18:00:00.000Z',
};

/// **Une annonce qui expire.**
///
/// `expiresAt` voyage **brut**, et le serveur ne retirera jamais cette ligne du
/// flux une fois la date passée : un statut « valable jusqu'à ce soir » doit
/// disparaître **à la seconde**, y compris hors-ligne, ce qu'un filtrage serveur
/// ne peut pas tenir — il la laisserait affichée jusqu'à la synchronisation
/// suivante. Le filtre appartient donc au client, et à lui seul.
const Map<String, Object?> expiringAnnouncementPayload = {
  'id': '019f5a00-0000-7000-8000-000000000002',
  'accountId': 2,
  'branchId': null,
  'title': null,
  'body': 'Collecte de vivres jusqu\'à ce soir, salle paroissiale.',
  'publishedAt': '2026-05-21T07:00:00.000Z',
  'expiresAt': '2026-05-21T20:00:00.000Z',
  'backgroundId': null,
  'backgroundImageUrl': '/uploads/announcements/collecte.webp',
  'mediaKind': null,
  'mediaUrl': null,
  'mediaPosterUrl': null,
  'mediaDurationMs': null,
  'mediaWaveform': null,
  'isPinned': false,
  'ownerId': 'b6f0a1c2-0000-4000-8000-000000000002',
  'createdAt': '2026-05-21T06:58:00.000Z',
  'updatedAt': '2026-05-21T07:00:00.000Z',
};

/// **Une annonce audio** (#130) — relevée sur `announcement_transformer.ts` et
/// `publish_announcement_media.ts` : la playlist **maître** du profil `sparks`,
/// la durée mesurée par le transcodeur, et **trente-six** hauteurs de 0 à 100
/// tirées de la passe de normalisation. Pas d'affiche : elle est réservée à la
/// vidéo, et l'image de fond reste celle de l'annonce.
const Map<String, Object?> audioAnnouncementPayload = {
  'id': '019f5a00-0000-7000-8000-000000000003',
  'accountId': 1,
  'branchId': 1,
  'title': null,
  'body': 'Un mot du pasteur pour la semaine.',
  'publishedAt': '2026-10-02T08:00:00.000Z',
  'expiresAt': null,
  'backgroundId': 1,
  'backgroundImageUrl': null,
  'mediaKind': 'audio',
  'mediaUrl': 'https://media.example.test/sparks/019f5a00/master.m3u8',
  'mediaPosterUrl': null,
  'mediaDurationMs': 42000,
  'mediaWaveform': [
    12, 30, 55, 80, 64, 41, 22, 18, 35, 60, 77, 90, //
    85, 70, 52, 33, 20, 15, 28, 46, 68, 82, 95, 88, //
    73, 59, 40, 26, 19, 31, 50, 66, 79, 61, 38, 14,
  ],
  'isPinned': false,
  'createdAt': '2026-10-02T07:40:00.000Z',
  'updatedAt': '2026-10-02T08:00:00.000Z',
};

/// **Une annonce vidéo** (#130). L'affiche est **relative** — le serveur sert
/// ses chemins d'image ainsi —, et la forme d'onde est absente : elle ne
/// concerne que l'audio.
const Map<String, Object?> videoAnnouncementPayload = {
  'id': '019f5a00-0000-7000-8000-000000000004',
  'accountId': 2,
  'branchId': null,
  'title': 'Convention 2026',
  'body': null,
  'publishedAt': '2026-10-03T08:00:00.000Z',
  'expiresAt': null,
  'backgroundId': null,
  'backgroundImageUrl': null,
  'mediaKind': 'video',
  'mediaUrl': 'https://media.example.test/sparks/019f5a01/master.m3u8',
  'mediaPosterUrl': '/uploads/announcements/convention-affiche.webp',
  'mediaDurationMs': 58000,
  'mediaWaveform': null,
  'isPinned': false,
  'createdAt': '2026-10-03T07:40:00.000Z',
  'updatedAt': '2026-10-03T08:00:00.000Z',
};

/// **Une rétractation d'annonce.** Le tombstone porte `deletedAt` ; c'est la
/// seule question posée à un élément avant de le désérialiser.
const Map<String, Object?> retractedAnnouncementPayload = {
  'id': '019f5a00-0000-7000-8000-000000000009',
  'deletedAt': '2026-05-22T09:00:00.000Z',
};

/// Page mixte de `announcements` : annonces complètes et rétractation **dans le
/// même tableau**, la rétractation en dernier.
Map<String, Object?> mixedAnnouncementsPage({String? nextCursor}) => deltaPage(
      items: const [
        fullAnnouncementPayload,
        expiringAnnouncementPayload,
        retractedAnnouncementPayload,
      ],
      nextCursor: nextCursor ??
          serverCursor(
            updatedAtIso: '2026-05-22T09:00:00.000Z',
            id: '019f5a00-0000-7000-8000-000000000009',
          ),
    );

// ─────────────────────────────────────────────────────────────────────────────
// `playback_progress` — la reprise de lecture (partition `private`)
// ─────────────────────────────────────────────────────────────────────────────

/// **Une progression de lecture complète.**
///
/// Huit clés, relevées sur
/// `app/mediatheque/transformers/playback_progress_transformer.ts` : `id`,
/// `userId`, `teachingId`, `positionSeconds`, `completed`, `clientCreatedAt`,
/// `createdAt`, `updatedAt`.
///
/// **Aucune durée, et ce n'est pas un oubli** : le serveur n'en a nulle part —
/// ni ici, ni sur `teachings`. Il n'a donc pas de dénominateur et **ne peut
/// pas** décider qu'un contenu est terminé ; il stocke le `completed` que le
/// client lui a envoyé. Le seuil est une décision application.
///
/// `teachingId` pointe l'enseignement de [fullTeachingPayload] — mais il
/// pourrait tout aussi bien pointer un **rassemblement** : les deux familles
/// sont la même table côté serveur, discriminée par `family`, et la route de
/// rapport est la même. Le nom de la clé est celui de la colonne partagée,
/// comme la verrue déjà connue de `gatherings.teachingTypeId`.
const Map<String, Object?> playbackProgressPayload = {
  'id': '019f6b00-0000-7000-8000-000000000001',
  'userId': 'b6f0a1c2-0000-4000-8000-000000000001',
  'teachingId': '019f2c40-0000-7000-8000-000000000001',
  'positionSeconds': 942,
  'completed': false,
  'clientCreatedAt': '2026-05-24T14:00:00.000Z',
  'createdAt': '2026-05-24T14:00:00.000Z',
  'updatedAt': '2026-05-24T14:31:00.000Z',
};

/// **Une progression terminée.** `completed: true` est arrivé là parce qu'un
/// client l'a décidé et envoyé, jamais parce que le serveur l'a calculé.
const Map<String, Object?> completedPlaybackProgressPayload = {
  'id': '019f6b00-0000-7000-8000-000000000002',
  'userId': 'b6f0a1c2-0000-4000-8000-000000000001',
  'teachingId': '019f2c40-0000-7000-8000-000000000002',
  'positionSeconds': 3600,
  'completed': true,
  'clientCreatedAt': null,
  'createdAt': '2026-05-20T09:00:00.000Z',
  'updatedAt': '2026-05-20T10:00:00.000Z',
};

/// La page nominale de `playback_progress`.
Map<String, Object?> playbackProgressPage() => deltaPage(
      items: const [
        playbackProgressPayload,
        completedPlaybackProgressPayload,
      ],
      nextCursor: serverCursor(
        updatedAtIso: '2026-05-24T14:31:00.000Z',
        id: '019f6b00-0000-7000-8000-000000000001',
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────
// `teaching_guests` — les invités d'un contenu (partition `reference`)
// ─────────────────────────────────────────────────────────────────────────────

/// **Un crédit d'invité.**
///
/// Sept clés, relevées sur
/// `app/mediatheque/transformers/teaching_guest_transformer.ts` (issue serveur
/// #436) : `id`, `teachingId`, `contributorId`, `position`, `createdAt`,
/// `updatedAt`, `deletedAt`.
///
/// **Rien de dénormalisé** : ni le nom de l'intervenant, ni le titre de
/// l'enseignement. Le client réplique `contributors` et `teachings` par ailleurs
/// et joint contre ses propres copies (ADR-0026, décision 3). Les servir ici les
/// **figerait** — renommer un intervenant n'écrit rien sur le pivot, donc ne
/// bouscule aucun `updatedAt`, donc rien ne repasserait jamais dans le flux : le
/// téléphone afficherait l'ancien nom indéfiniment.
///
/// `id` est un **entier** (`increments` côté serveur), comme les référentiels ;
/// `teachingId` est l'UUIDv7 du parent. Le protocole préserve les deux types de
/// bout en bout.
///
/// `position` voyage parce que l'ordre des invités est une **donnée saisie**, pas
/// un tri que le client pourrait recalculer : le générique d'un enseignement à
/// plusieurs voix n'est pas une liste alphabétique. Il est **1-based**.
///
/// `deletedAt` voyage **toujours**, `null` compris : c'est le drapeau tombstone
/// que le client lit pour retirer un crédit de son cache (ADR-0017). C'est ce qui
/// distingue cette collection de `official_account_memberships`, qui assume la
/// suppression franche — là-bas une ligne périmée est un bouton offert qui mène à
/// un 403, ici c'est **un nom affiché sur un écran**.
const Map<String, Object?> teachingGuestPayload = {
  'id': 1,
  'teachingId': '019f2c40-0000-7000-8000-000000000001',
  'contributorId': 7,
  'position': 1,
  'createdAt': '2026-06-01T09:00:00.000Z',
  'updatedAt': '2026-06-01T09:00:00.000Z',
  'deletedAt': null,
};

/// **Le second invité du même enseignement**, au rang suivant.
///
/// Deux lignes plutôt qu'une suffisent à exercer ce qui compte : l'ordre saisi,
/// et le fait que deux crédits du même contenu sont deux lignes indépendantes —
/// l'une peut être retirée sans l'autre.
const Map<String, Object?> secondTeachingGuestPayload = {
  'id': 2,
  'teachingId': '019f2c40-0000-7000-8000-000000000001',
  'contributorId': 4,
  'position': 2,
  'createdAt': '2026-06-01T09:00:00.000Z',
  'updatedAt': '2026-06-01T09:00:00.000Z',
  'deletedAt': null,
};

/// **Un crédit sur un autre enseignement**, pour qu'un test puisse constater
/// qu'une lecture par contenu ne ramasse pas les crédits du voisin.
const Map<String, Object?> otherTeachingGuestPayload = {
  'id': 3,
  'teachingId': '019f2c40-0000-7000-8000-000000000002',
  'contributorId': 7,
  'position': 1,
  'createdAt': '2026-06-02T09:00:00.000Z',
  'updatedAt': '2026-06-02T09:00:00.000Z',
  'deletedAt': null,
};

/// **Le retrait d'un invité — un tombstone, pas une rétractation.**
///
/// La différence avec `teachings` compte : une rétractation d'enseignement est
/// réduite à `{ id, deletedAt }` parce que la ligne **n'a pas le droit d'être
/// vue**. Ici la ligne part **entière**, `deletedAt` en plus — un crédit ne dit
/// rien qu'il faille cacher, et le serveur sert le même transformer pour les
/// deux états.
///
/// C'est la **même ligne** que [secondTeachingGuestPayload], `id` compris :
/// l'unicité serveur porte sur la paire tombstones comprise, précisément pour
/// qu'un invité retiré puis remis réanime cette ligne-ci (`deleted_at → NULL`) et
/// non une seconde. Un client qui recevrait deux `id` différents verrait l'ordre
/// d'arrivée décider de ce qu'il affiche.
const Map<String, Object?> retractedTeachingGuestPayload = {
  'id': 2,
  'teachingId': '019f2c40-0000-7000-8000-000000000001',
  'contributorId': 4,
  'position': 2,
  'createdAt': '2026-06-01T09:00:00.000Z',
  'updatedAt': '2026-06-10T11:00:00.000Z',
  'deletedAt': '2026-06-10T11:00:00.000Z',
};

/// Curseur de la page nominale de `teaching_guests` — l'`id` y est un **entier**,
/// comme sur les référentiels.
final String teachingGuestsCursor = serverCursor(
  updatedAtIso: '2026-06-02T09:00:00.000Z',
  id: 3,
);

/// Curseur de la page qui porte le **retrait**.
final String teachingGuestsCursorAfterRetraction = serverCursor(
  updatedAtIso: '2026-06-10T11:00:00.000Z',
  id: 2,
);

/// La page nominale : trois crédits, dont deux sur le même enseignement.
Map<String, Object?> teachingGuestsPage() => deltaPage(
      items: const [
        teachingGuestPayload,
        secondTeachingGuestPayload,
        otherTeachingGuestPayload,
      ],
      nextCursor: teachingGuestsCursor,
    );

/// La page suivante : **le retrait d'un invité voyage**.
///
/// Un seul élément, portant son `deletedAt`. C'est ce que le client doit lire
/// pour faire disparaître le nom de l'écran sans attendre une resynchronisation
/// complète — soit, avec la fenêtre de rétention du serveur, potentiellement des
/// semaines.
Map<String, Object?> teachingGuestRetractionPage() => deltaPage(
      items: const [retractedTeachingGuestPayload],
      nextCursor: teachingGuestsCursorAfterRetraction,
    );

// ─────────────────────────────────────────────────────────────────────────────
// Lignes `presentation_vocabulary` — **sept clés**, `camelCase` (issue #81)
// ─────────────────────────────────────────────────────────────────────────────

/// **Une surcharge de libellé.** Sept clés, relevées sur
/// `app/presentation/transformers/vocabulary_transformer.ts` : `id`, `kind`,
/// `singular`, `plural`, `label`, `createdAt`, `updatedAt`.
///
/// ⚠️ **`id` est une chaîne** — la **clé du catalogue**, pas un `SERIAL`. La
/// colonne serveur s'appelle quand même `id`, parce que le curseur composé
/// l'exige de toute collection synchronisable ; une PK nommée autrement
/// produirait un `column "id" does not exist` au premier tirage, c'est-à-dire un
/// `500` qui coupe le cycle.
///
/// **Les trois cartes partent toujours, `null` compris** : le transformer les
/// sert explicitement plutôt que de les omettre. Un terme porte `label: null`,
/// une surcharge porte `singular: null` et `plural: null` — la contrainte
/// `presentation_vocabulary_shape` rend l'autre moitié impossible à écrire.
///
/// **Aucun `deletedAt`** : `tombstoneColumn: null`, et la ligne ne se supprime
/// jamais. Effacer une surcharge y écrit `null`.
const Map<String, Object?> vocabularyLabelPayload = {
  'id': 'sectionLatestTeachings',
  'kind': 'label',
  'singular': null,
  'plural': null,
  'label': {'fr': 'Derniers messages', 'en': 'Latest messages'},
  'createdAt': '2026-09-01T09:00:00.000Z',
  'updatedAt': '2026-09-20T10:00:00.000Z',
};

/// **Un terme**, ses deux formes écrites à la main. Aucun accord n'est calculé.
const Map<String, Object?> vocabularyTermPayload = {
  'id': 'teaching',
  'kind': 'term',
  'singular': {'fr': 'message', 'en': 'message'},
  'plural': {'fr': 'messages', 'en': 'messages'},
  'label': null,
  'createdAt': '2026-09-01T09:00:00.000Z',
  'updatedAt': '2026-09-20T10:05:00.000Z',
};

/// **La non-décision, telle qu'elle voyage.** Les trois cartes à `null` : le
/// portail a réglé ce mot puis l'a effacé, et c'est cette ligne-là — jamais une
/// suppression — qui apprend au téléphone de revenir à son `.arb`.
const Map<String, Object?> vocabularyClearedPayload = {
  'id': 'filterTeachings',
  'kind': 'label',
  'singular': null,
  'plural': null,
  'label': null,
  'createdAt': '2026-09-01T09:00:00.000Z',
  'updatedAt': '2026-09-20T10:10:00.000Z',
};

/// **Une surcharge vide**, et ce n'est pas la même chose qu'une chaîne vide à
/// l'écran : une carte sans aucune langue remplie veut dire « garde le mot du
/// dépôt ». Le serveur la normalise en `null` à l'écriture, mais le magasin n'a
/// pas à le supposer — et le client doit se comporter pareil dans les deux cas.
const Map<String, Object?> vocabularyBlankPayload = {
  'id': 'downloadsEmptyMessage',
  'kind': 'label',
  'singular': null,
  'plural': null,
  'label': <String, Object?>{'fr': '   ', 'en': ''},
  'createdAt': '2026-09-01T09:00:00.000Z',
  'updatedAt': '2026-09-20T10:15:00.000Z',
};

/// Curseur de la page nominale de `presentation_vocabulary`.
///
/// ⚠️ L'`id` y est une **chaîne**, contrairement à tous les autres référentiels :
/// c'est le premier du registre dont la PK est textuelle. Le tri
/// `(updated_at, id)` y reste total et déterministe.
final String presentationVocabularyCursor = serverCursor(
  updatedAtIso: '2026-09-20T10:15:00.000Z',
  id: 'downloadsEmptyMessage',
);

/// La page nominale : une surcharge, un terme, une non-décision, une carte vide.
Map<String, Object?> presentationVocabularyPage() => deltaPage(
      items: const [
        vocabularyLabelPayload,
        vocabularyTermPayload,
        vocabularyClearedPayload,
        vocabularyBlankPayload,
      ],
      nextCursor: presentationVocabularyCursor,
    );

// ─────────────────────────────────────────────────────────────────────────────
// Lignes `auth_channels` — **six clés**, `camelCase` (issue #83)
// ─────────────────────────────────────────────────────────────────────────────

/// **Les canaux tels que le serveur les livre.** Six clés, relevées sur
/// `app/auth/transformers/auth_channels_transformer.ts` : `id`, `emailOpen`,
/// `phoneOpen`, `loginNotice`, `createdAt`, `updatedAt`.
///
/// ⚠️ **`id` est un entier, et il vaut `1`** : `auth_settings` est un singleton
/// (`integer` et non `SERIAL`, un `CHECK` interdit toute autre valeur). La
/// collection ne portera jamais qu'une ligne.
///
/// **Les valeurs sont celles de la migration livrée** (`database/migrations/
/// *_create_auth_settings_table.ts`) : `email_channel_open = true`,
/// `phone_channel_open = **false**`. Ce n'est pas un défaut prudent, c'est
/// l'état réel du serveur — `MailOtpSender` part en SMTP, le canal téléphone
/// suit `OTP_PHONE_DRIVER`, dont le défaut est `log` et n'envoie rien.
///
/// **`loginNotice` part à `null` et ne se filtre pas** : c'est ce qui dit « il
/// n'y a pas d'annonce » plutôt que « je n'ai pas encore reçu les réglages », et
/// autorise le client à retomber tout de suite sur le libellé du dépôt.
///
/// **Aucun `deletedAt`** : `tombstoneColumn: null`. Fermer un canal met un
/// booléen à `false`, et c'est cette ligne-là qui voyage.
const Map<String, Object?> authChannelsEmailOnlyPayload = {
  'id': 1,
  'emailOpen': true,
  'phoneOpen': false,
  'loginNotice': null,
  'createdAt': '2026-09-01T09:00:00.000Z',
  'updatedAt': '2026-09-20T10:00:00.000Z',
};

/// **Les deux canaux ouverts, avec l'annonce du portail.** La carte de
/// traduction part **entière**, jamais résolue (ADR-0023) : le client choisit sa
/// langue et replie.
const Map<String, Object?> authChannelsBothOpenPayload = {
  'id': 1,
  'emailOpen': true,
  'phoneOpen': true,
  'loginNotice': {
    'fr': 'Le code arrive par SMS ou par email, à vous de choisir.',
    'en': 'Your code comes by text or email — your call.',
  },
  'createdAt': '2026-09-01T09:00:00.000Z',
  'updatedAt': '2026-09-20T10:05:00.000Z',
};

/// **Un seul canal, et le portail dit pourquoi.** C'est la forme que cette
/// tranche existe pour afficher.
const Map<String, Object?> authChannelsNoticedPayload = {
  'id': 1,
  'emailOpen': true,
  'phoneOpen': false,
  'loginNotice': {
    'fr': 'La connexion par téléphone rouvrira bientôt.',
    'en': 'Phone sign-in will reopen soon.',
  },
  'createdAt': '2026-09-01T09:00:00.000Z',
  'updatedAt': '2026-09-20T10:10:00.000Z',
};

/// **Une annonce vide**, et ce n'est pas la même chose qu'un bandeau blanc : une
/// carte sans aucune langue remplie veut dire « garde le libellé du dépôt ». Le
/// serveur écrit `null` plutôt que cette forme, mais le magasin n'a pas à le
/// supposer — et le client doit se comporter pareil dans les deux cas.
const Map<String, Object?> authChannelsBlankNoticePayload = {
  'id': 1,
  'emailOpen': true,
  'phoneOpen': false,
  'loginNotice': <String, Object?>{'fr': '   ', 'en': ''},
  'createdAt': '2026-09-01T09:00:00.000Z',
  'updatedAt': '2026-09-20T10:15:00.000Z',
};

/// Curseur de la page de `auth_channels`. L'`id` y est un **entier**, comme
/// pour les autres référentiels.
final String authChannelsCursor = serverCursor(
  updatedAtIso: '2026-09-20T10:00:00.000Z',
  id: 1,
);

/// La page nominale : l'unique ligne du singleton, telle que livrée.
Map<String, Object?> authChannelsPage({
  Map<String, Object?> row = authChannelsEmailOnlyPayload,
}) =>
    deltaPage(items: [row], nextCursor: authChannelsCursor);

// ─────────────────────────────────────────────────────────────────────────────
// `device_settings` — le réglage d'exploitation du parc (#91)
// ─────────────────────────────────────────────────────────────────────────────

/// **La ligne livrée** : le singleton existe, et son seuil est `null`.
///
/// Quatre clés, relevées sur
/// `app/devices/transformers/device_settings_transformer.ts` : `id`,
/// `updateBannerMinVersion`, `createdAt`, `updatedAt`. Rien d'autre ne descend —
/// le transformer les énumère exprès, parce que `device_settings` est la table
/// des réglages d'**exploitation**, c'est-à-dire l'endroit où l'on rangera demain
/// ce qui n'a aucune vocation à voyager jusqu'à un téléphone.
///
/// `null` est la valeur posée par la migration serveur
/// (`*_create_device_settings_table.ts`), et la seule honnête tant que
/// l'application n'a jamais été publiée : **aucun seuil, donc aucun bandeau pour
/// personne**. La ligne part quand même, avec son `null`.
const Map<String, Object?> deviceSettingsNoThresholdPayload = {
  'id': 1,
  'updateBannerMinVersion': null,
  'createdAt': '2026-09-01T09:00:00.000Z',
  'updatedAt': '2026-09-20T10:00:00.000Z',
};

/// **Un seuil réglé au portail.** La forme que cette tranche existe pour faire
/// descendre.
///
/// Une **chaîne**, et pas trois entiers : c'est la version que l'application
/// annonce. La comparer est l'affaire de qui la lit.
const Map<String, Object?> deviceSettingsThresholdPayload = {
  'id': 1,
  'updateBannerMinVersion': '1.4.0',
  'createdAt': '2026-09-01T09:00:00.000Z',
  'updatedAt': '2026-09-20T10:05:00.000Z',
};

/// **Un seuil retiré.** Le singleton ne se supprime pas : retirer le seuil
/// remet la colonne à `null`, et c'est **cette ligne-là** qui voyage — d'où un
/// `updatedAt` postérieur à celui du seuil posé.
const Map<String, Object?> deviceSettingsClearedPayload = {
  'id': 1,
  'updateBannerMinVersion': null,
  'createdAt': '2026-09-01T09:00:00.000Z',
  'updatedAt': '2026-09-20T10:10:00.000Z',
};

/// Curseur de la page de `device_settings`. L'`id` y est un **entier**, comme
/// pour les autres référentiels.
final String deviceSettingsCursor = serverCursor(
  updatedAtIso: '2026-09-20T10:00:00.000Z',
  id: 1,
);

/// La page nominale : l'unique ligne du singleton, telle que livrée.
Map<String, Object?> deviceSettingsPage({
  Map<String, Object?> row = deviceSettingsNoThresholdPayload,
}) =>
    deltaPage(items: [row], nextCursor: deviceSettingsCursor);

// ─────────────────────────────────────────────────────────────────────────────
// Lignes `menu_entries` — **trente et une clés**, `camelCase` (issue #82)
// ─────────────────────────────────────────────────────────────────────────────

/// Les trente et une clés qu'une entrée porte, relevées **une à une** sur
/// `app/presentation/transformers/menu_entry_transformer.ts`.
///
/// ⚠️ La table serveur en compte **trente-neuf** : huit ne descendent
/// délibérément pas (`headerVisible`/`headerPosition`,
/// `footerVisible`/`footerPosition`, `shareTitle`/`shareDescription`,
/// `heroImageUrl`, `locked`). En ajouter une ici ferait tester une forme que le
/// serveur n'envoie pas.
Map<String, Object?> menuEntryPayload({
  required int id,
  int? parentId,
  String? labelKey,
  Map<String, Object?>? label,
  String? icon,
  bool featured = false,
  bool divided = false,
  String destinationKind = 'catalogue',
  String? destinationPage,
  String? destinationFamily = 'teaching',
  String? destinationRubric,
  String? destinationBranch,
  String? destinationSearch,
  String? destinationSeriesId,
  int? destinationContributorId,
  String? destinationUrl,
  bool filterRubric = false,
  bool filterBranch = false,
  bool filterFamily = false,
  bool filterSearch = false,
  bool mediaVisible = true,
  int mediaPosition = 1,
  bool homeVisible = false,
  int homePosition = 0,
  String? homeLayout,
  String? publishedFrom,
  String? publishedUntil,
  Map<String, Object?>? pageTitle,
  Map<String, Object?>? pageDescription,
  String updatedAt = '2026-09-20T10:00:00.000Z',
}) =>
    {
      'id': id,
      'parentId': parentId,
      'labelKey': labelKey,
      'label': label,
      'icon': icon,
      'featured': featured,
      'divided': divided,
      'destinationKind': destinationKind,
      'destinationPage': destinationPage,
      'destinationFamily': destinationFamily,
      'destinationRubric': destinationRubric,
      'destinationBranch': destinationBranch,
      'destinationSearch': destinationSearch,
      'destinationSeriesId': destinationSeriesId,
      'destinationContributorId': destinationContributorId,
      'destinationUrl': destinationUrl,
      'filterRubric': filterRubric,
      'filterBranch': filterBranch,
      'filterFamily': filterFamily,
      'filterSearch': filterSearch,
      'mediaVisible': mediaVisible,
      'mediaPosition': mediaPosition,
      'homeVisible': homeVisible,
      'homePosition': homePosition,
      'homeLayout': homeLayout,
      'publishedFrom': publishedFrom,
      'publishedUntil': publishedUntil,
      'pageTitle': pageTitle,
      'pageDescription': pageDescription,
      'createdAt': '2026-09-01T09:00:00.000Z',
      'updatedAt': updatedAt,
    };

/// **L'entrée livrée par la graine** (`menu_seed.ts`) : la médiathèque mobile
/// naît avec **une** entrée, celle qui ne filtre rien.
///
/// Trois choses s'y lisent, et aucune n'est une invention de test :
/// `destination_kind = 'page'` avec `destination_page = 'mediatheque'` (le
/// garde-fou 2 du cadrage verrouille cette entrée-là), `label = null` avec
/// `labelKey = 'public.nav.mediatheque'` — la clé **de la vitrine**, pas une clé
/// `.arb` —, et les **quatre** cases de filtre cochées, reprises de ce que la
/// page `/mediatheque` offrait déjà.
final Map<String, Object?> menuSeededMediathequePayload = menuEntryPayload(
  id: 5,
  labelKey: 'public.nav.mediatheque',
  destinationKind: 'page',
  destinationPage: 'mediatheque',
  destinationFamily: null,
  filterRubric: true,
  filterBranch: true,
  filterFamily: true,
  filterSearch: true,
  mediaPosition: 1,
);

/// Curseur de la page de `menu_entries`. L'`id` y est un **entier** (PK SERIAL),
/// comme pour les autres référentiels — et non une chaîne comme pour
/// `presentation_vocabulary`.
final String menuEntriesCursor = serverCursor(
  updatedAtIso: '2026-09-20T10:00:00.000Z',
  id: 5,
);

/// La page nominale : l'entrée livrée, seule.
Map<String, Object?> menuEntriesPage({List<Map<String, Object?>>? rows}) =>
    deltaPage(
      items: rows ?? [menuSeededMediathequePayload],
      nextCursor: menuEntriesCursor,
    );

// ─────────────────────────────────────────────────────────────────────────────
// Ligne `decor` — **cinq clés**, `camelCase`
// ─────────────────────────────────────────────────────────────────────────────

/// Le décor par défaut, tel que le serveur le livre. Cinq clés, relevées sur
/// `app/vitrine/transformers/decor_transformer.ts` : `id`, `backgroundUrl`,
/// `backgroundVerticalUrl`, `createdAt`, `updatedAt`.
///
/// **Les deux adresses sont nullables**, et la ligne part quand même : « le
/// portail n'a déposé aucun décor » n'est pas une absence de ligne.
const Map<String, Object?> decorPayload = {
  'id': 1,
  'backgroundUrl': null,
  'backgroundVerticalUrl': null,
  'createdAt': '2026-09-01T09:00:00.000Z',
  'updatedAt': '2026-09-20T10:00:00.000Z',
};

/// Curseur de la page de `decor`. L'`id` y est un **entier** (singleton `id = 1`).
final String decorCursor = serverCursor(
  updatedAtIso: '2026-09-20T10:00:00.000Z',
  id: 1,
);

/// La page nominale : l'unique ligne du singleton.
Map<String, Object?> decorPage() =>
    deltaPage(items: const [decorPayload], nextCursor: decorCursor);

// ─────────────────────────────────────────────────────────────────────────────
// « Échanges » — les cinq collections de la messagerie de groupe (#96)
// ─────────────────────────────────────────────────────────────────────────────

/// Les identifiants qui servent de décor à tout ce bloc, nommés une fois.
///
/// [kMeId] est **moi** : c'est l'identifiant que les tests passent à
/// `StoreEchangesRepository`, et celui sur lequel le `mine` d'une bulle se
/// compare.
const String kMeId = '019a1000-0000-7000-8000-00000000me01';
const String kPeerId = '019a1000-0000-7000-8000-0000000peer1';
const String kGoneId = '019a1000-0000-7000-8000-0000000gone1';
const String kGroupId = '019a2000-0000-7000-8000-000000grp001';
const String kOpenGroupId = '019a2000-0000-7000-8000-000000grp002';
const String kDirectGroupId = '019a2000-0000-7000-8000-000000grp003';

// --- `profiles` : **quatre clés**, et pas de `createdAt` ---------------------

/// **Mon propre profil.** Quatre clés, relevées sur le `transform` **inline** de
/// `app/sync/descriptors/profiles_descriptor.ts` : `id`, `displayName`,
/// `avatarUrl`, `updatedAt`.
///
/// ⚠️ **Il n'y a pas de `createdAt`** — le transformer ne l'émet pas. Un client
/// qui l'attendrait garderait une colonne nulle pour toujours.
///
/// ⚠️ **`avatarUrl` est toujours `null`** : `users` ne porte aucune colonne
/// d'avatar. Ce n'est pas une omission de fixture, c'est la valeur servie.
const Map<String, Object?> myProfilePayload = {
  'id': kMeId,
  'displayName': 'Kossi Amavi',
  'avatarUrl': null,
  'updatedAt': '2026-09-01T08:00:00.000Z',
};

/// **Le profil d'un co-membre** — ce qui donne un nom à ses bulles.
const Map<String, Object?> peerProfilePayload = {
  'id': kPeerId,
  'displayName': 'Estelle Adjo',
  'avatarUrl': null,
  'updatedAt': '2026-09-01T08:05:00.000Z',
};

/// **Un profil sans nom.** Cas **légitime** et courant : `displayNameOf` rend
/// `null` quand ni prénom, ni nom, ni titre n'est renseigné. Le client doit le
/// rendre par une absence — jamais par un « Utilisateur inconnu ».
const Map<String, Object?> namelessProfilePayload = {
  'id': kGoneId,
  'displayName': null,
  'avatarUrl': null,
  'updatedAt': '2026-09-01T08:10:00.000Z',
};

final String profilesCursor = serverCursor(
  updatedAtIso: '2026-09-01T08:10:00.000Z',
  id: kGoneId,
);

Map<String, Object?> profilesPage() => deltaPage(
      items: const [
        myProfilePayload,
        peerProfilePayload,
        namelessProfilePayload,
      ],
      nextCursor: profilesCursor,
    );

// --- `groups` : **seize clés**, aucun tombstone ------------------------------

/// **Un groupe dont je suis membre.** Seize clés, relevées sur
/// `app/groups/transformers/group_transformer.ts`.
///
/// ⚠️ **`ownerId` est `groups.owner_user_id`**, renommé par le transformer : il
/// n'y a **pas** de clé `ownerUserId` sur le fil. Et `branchIds` est un tableau
/// d'entiers, `[]` valant « portée nationale » — jamais `null`.
///
/// ⚠️ **Il n'y a pas de `deletedAt`** : la table `groups` n'a pas de
/// soft-delete. Retirer un groupe met `isActive` à `false`, et c'est cette
/// ligne-là qui voyage.
const Map<String, Object?> myGroupPayload = {
  'id': kGroupId,
  'name': 'Chorale Harmonie',
  'description': 'Répétitions le samedi, service à chaque culte.',
  'joinPolicy': 'invite_only',
  'postPolicy': 'all',
  'isWriteLocked': false,
  'isActive': true,
  'isDirect': false,
  'ownerId': kPeerId,
  'ownerKind': 'user',
  'ownerOfficialAccountId': null,
  'ownerContributorId': null,
  'memberCount': 3,
  'branchIds': [3],
  'createdAt': '2026-08-01T09:00:00.000Z',
  'updatedAt': '2026-09-01T09:00:00.000Z',
};

/// **Un groupe à rejoindre**, politique ouverte, dont je ne suis pas membre —
/// propriété d'un **compte officiel**, ce qui fait joindre son nom ailleurs que
/// dans `profiles`.
const Map<String, Object?> openGroupPayload = {
  'id': kOpenGroupId,
  'name': 'Étude biblique du mardi',
  'description': 'Ouvert à tous, chaque mardi à 18h.',
  'joinPolicy': 'open',
  'postPolicy': 'all',
  'isWriteLocked': false,
  'isActive': true,
  'isDirect': false,
  'ownerId': null,
  'ownerKind': 'official_account',
  'ownerOfficialAccountId': 1,
  'ownerContributorId': null,
  'memberCount': 24,
  'branchIds': [],
  'createdAt': '2026-08-02T09:00:00.000Z',
  'updatedAt': '2026-09-01T09:05:00.000Z',
};

/// **Un tête-à-tête.** Le serveur en fait un groupe comme un autre : c'est ce qui
/// donne gratuitement le fil, le tombstone de modération et le curseur.
/// `isDirect: true`, et son `name` **n'a pas été écrit pour être lu** — le client
/// affiche le nom de l'autre.
const Map<String, Object?> directGroupPayload = {
  'id': kDirectGroupId,
  'name': 'direct:019a1000-019a1000',
  'description': null,
  'joinPolicy': 'invite_only',
  'postPolicy': 'all',
  'isWriteLocked': false,
  'isActive': true,
  'isDirect': true,
  'ownerId': kMeId,
  'ownerKind': 'user',
  'ownerOfficialAccountId': null,
  'ownerContributorId': null,
  'memberCount': 2,
  'branchIds': [],
  'createdAt': '2026-08-03T09:00:00.000Z',
  'updatedAt': '2026-09-01T09:10:00.000Z',
};

/// **Un groupe en diffusion** : `postPolicy: 'admins'`. Un simple membre n'y
/// écrit pas, et le client ne doit pas lui offrir la barre de saisie.
///
/// Écrit **en entier** et non par recopie d'une autre fixture : une carte
/// constante dont une clé en recouvrirait une autre ne compile pas en Dart, et
/// l'écrire au long rend de toute façon lisible la seule différence qui compte.
const Map<String, Object?> broadcastGroupPayload = {
  'id': '019a2000-0000-7000-8000-000000grp004',
  'name': 'Annonces du bureau',
  'description': 'Les communications du bureau exécutif.',
  'joinPolicy': 'invite_only',
  'postPolicy': 'admins',
  'isWriteLocked': false,
  'isActive': true,
  'isDirect': false,
  'ownerId': kPeerId,
  'ownerKind': 'user',
  'ownerOfficialAccountId': null,
  'ownerContributorId': null,
  'memberCount': 3,
  'branchIds': [3],
  'createdAt': '2026-08-01T09:00:00.000Z',
  'updatedAt': '2026-09-01T09:15:00.000Z',
};

final String groupsCursor = serverCursor(
  updatedAtIso: '2026-09-01T09:10:00.000Z',
  id: kDirectGroupId,
);

Map<String, Object?> groupsPage({List<Object?>? items}) => deltaPage(
      items:
          items ?? const [myGroupPayload, openGroupPayload, directGroupPayload],
      nextCursor: groupsCursor,
    );

// --- `group_members` : **sept clés**, `id` **entier**, avec tombstone --------

/// **Mon appartenance** au groupe. `id` est un **entier** (`increments`), là où
/// `groupId` et `userId` sont des UUID.
const Map<String, Object?> myMembershipPayload = {
  'id': 1,
  'groupId': kGroupId,
  'userId': kMeId,
  'role': 'member',
  'createdAt': '2026-08-01T09:00:00.000Z',
  'updatedAt': '2026-08-01T09:00:00.000Z',
  'deletedAt': null,
};

/// L'appartenance d'un **co-membre**, animateur du groupe.
const Map<String, Object?> peerMembershipPayload = {
  'id': 2,
  'groupId': kGroupId,
  'userId': kPeerId,
  'role': 'leader',
  'createdAt': '2026-08-01T09:00:00.000Z',
  'updatedAt': '2026-08-01T09:00:00.000Z',
  'deletedAt': null,
};

/// Les deux lignes du **tête-à-tête** : la mienne et celle de l'autre.
const Map<String, Object?> myDirectMembershipPayload = {
  'id': 3,
  'groupId': kDirectGroupId,
  'userId': kMeId,
  'role': 'member',
  'createdAt': '2026-08-03T09:00:00.000Z',
  'updatedAt': '2026-08-03T09:00:00.000Z',
  'deletedAt': null,
};

const Map<String, Object?> peerDirectMembershipPayload = {
  'id': 4,
  'groupId': kDirectGroupId,
  'userId': kPeerId,
  'role': 'member',
  'createdAt': '2026-08-03T09:00:00.000Z',
  'updatedAt': '2026-08-03T09:00:00.000Z',
  'deletedAt': null,
};

/// **Mon départ du groupe** — un tombstone, et c'est lui qui retire la
/// conversation de mon téléphone.
///
/// C'est la **même ligne** que [myMembershipPayload], `id` compris : l'unicité
/// `(group_id, user_id)` n'étant pas partielle, une ré-adhésion réanime cet
/// `id`-ci (`deleted_at → NULL`) plutôt que d'en créer un second.
const Map<String, Object?> myMembershipRetractedPayload = {
  'id': 1,
  'groupId': kGroupId,
  'userId': kMeId,
  'role': 'member',
  'createdAt': '2026-08-01T09:00:00.000Z',
  'updatedAt': '2026-09-05T10:00:00.000Z',
  'deletedAt': '2026-09-05T10:00:00.000Z',
};

final String groupMembersCursor = serverCursor(
  updatedAtIso: '2026-08-03T09:00:00.000Z',
  id: 4,
);

final String groupMembersCursorAfterRetraction = serverCursor(
  updatedAtIso: '2026-09-05T10:00:00.000Z',
  id: 1,
);

Map<String, Object?> groupMembersPage({List<Object?>? items}) => deltaPage(
      items: items ??
          const [
            myMembershipPayload,
            peerMembershipPayload,
            myDirectMembershipPayload,
            peerDirectMembershipPayload,
          ],
      nextCursor: groupMembersCursor,
    );

/// La page qui porte **mon départ**.
Map<String, Object?> groupMembersRetractionPage() => deltaPage(
      items: const [myMembershipRetractedPayload],
      nextCursor: groupMembersCursorAfterRetraction,
    );

// --- `group_join_requests` : **sept clés**, `id` **entier** ------------------

/// **Ma demande d'adhésion**, en attente.
///
/// ⚠️ `decidedBy` et `decidedAt` existent en base et **ne sont pas servis**. Et
/// le `deletedAt` n'est **pas** le canal de la décision : un verdict voyage par
/// le changement de `status` et le bump d'`updated_at`.
const Map<String, Object?> pendingJoinRequestPayload = {
  'id': 1,
  'groupId': kOpenGroupId,
  'userId': kMeId,
  'status': 'pending',
  'createdAt': '2026-09-02T09:00:00.000Z',
  'updatedAt': '2026-09-02T09:00:00.000Z',
  'deletedAt': null,
};

final String groupJoinRequestsCursor = serverCursor(
  updatedAtIso: '2026-09-02T09:00:00.000Z',
  id: 1,
);

Map<String, Object?> groupJoinRequestsPage({List<Object?>? items}) => deltaPage(
      items: items ?? const [pendingJoinRequestPayload],
      nextCursor: groupJoinRequestsCursor,
    );

// --- `group_messages` : **neuf clés**, et les trois origines -----------------

/// **Un membre parle** — `(authorId, isSystem) = (uuid, false)`. Une **bulle**.
///
/// Neuf clés, relevées sur
/// `app/groups/transformers/group_message_transformer.ts`. ⚠️ **Il n'y a pas
/// d'`updatedAt`** sur le fil, bien que la colonne existe en base et porte le
/// curseur composé.
const Map<String, Object?> memberMessagePayload = {
  'id': '019a3000-0000-7000-8000-00000000msg1',
  'groupId': kGroupId,
  'authorId': kPeerId,
  'isSystem': false,
  'body': 'Répétition samedi à 16h, salle du fond.',
  'clientMessageId': null,
  'clientCreatedAt': null,
  'createdAt': '2026-09-03T10:30:00.000Z',
  'deletedAt': null,
};

/// **Mon propre message** — même origine, mais `mine` se **dérive** en comparant
/// `authorId` à l'identifiant de session. Il ne se sert pas.
const Map<String, Object?> myMessagePayload = {
  'id': '019a3000-0000-7000-8000-00000000msg2',
  'groupId': kGroupId,
  'authorId': kMeId,
  'isSystem': false,
  'body': 'Amen, j\'y serai.',
  'clientMessageId': '019a4000-0000-7000-8000-0000000echo1',
  'clientCreatedAt': '2026-09-03T10:31:58.000Z',
  'createdAt': '2026-09-03T10:32:00.000Z',
  'deletedAt': null,
};

/// **Le serveur parle** — `(null, true)`. Un **bandeau**, centré, sans bulle.
///
/// ⚠️ Son `body` est de la **prose française en dur** : le serveur les écrit
/// ainsi (`post_group_system_message.ts`), pas comme des clés à traduire. Un
/// membre anglophone ou éwéphone les lira en français, et le mobile n'a rien pour
/// y remédier — limite serveur acceptée telle quelle par le cadrage.
const Map<String, Object?> systemMessagePayload = {
  'id': '019a3000-0000-7000-8000-00000000msg3',
  'groupId': kGroupId,
  'authorId': null,
  'isSystem': true,
  'body': 'Un nouveau membre a rejoint le groupe.',
  'clientMessageId': null,
  'clientCreatedAt': null,
  'createdAt': '2026-09-03T10:35:00.000Z',
  'deletedAt': null,
};

/// **UN AUTEUR RETIRÉ** — `(null, false)`. **Une bulle**, jamais un bandeau.
///
/// C'est la ligne que le contrat existe pour défendre (ADR-0032) : la personne a
/// supprimé son compte, `author_id` est passé à `NULL`, et `is_system` est resté
/// `false`. Un client qui testerait le nul seul afficherait cette phrase — celle
/// d'un fidèle — comme une annonce du serveur. Rien ne planterait, aucun test ne
/// rougirait.
const Map<String, Object?> removedAuthorMessagePayload = {
  'id': '019a3000-0000-7000-8000-00000000msg4',
  'groupId': kGroupId,
  'authorId': null,
  'isSystem': false,
  'body': 'Que Dieu vous bénisse tous.',
  'clientMessageId': null,
  'clientCreatedAt': null,
  'createdAt': '2026-09-03T10:40:00.000Z',
  'deletedAt': null,
};

/// **Le même message qu'avant son détachement** : il portait un `authorId`.
///
/// C'est la **même ligne** que [removedAuthorMessagePayload], `id` compris. Le
/// couple de fixtures sert le cas qui ne s'obtient qu'en deux temps — le magasin
/// doit avoir **perdu** l'uuid après la seconde page.
const Map<String, Object?> attachedAuthorMessagePayload = {
  'id': '019a3000-0000-7000-8000-00000000msg4',
  'groupId': kGroupId,
  'authorId': kGoneId,
  'isSystem': false,
  'body': 'Que Dieu vous bénisse tous.',
  'clientMessageId': null,
  'clientCreatedAt': null,
  'createdAt': '2026-09-03T10:40:00.000Z',
  'deletedAt': null,
};

/// **Un message supprimé par modération** — le tombstone du fil.
///
/// La ligne part **entière**, `deletedAt` en plus : `readsAsRetraction` tranche
/// avant toute désérialisation, et la ligne quitte le magasin.
const Map<String, Object?> deletedMessagePayload = {
  'id': '019a3000-0000-7000-8000-00000000msg1',
  'groupId': kGroupId,
  'authorId': kPeerId,
  'isSystem': false,
  'body': 'Répétition samedi à 16h, salle du fond.',
  'clientMessageId': null,
  'clientCreatedAt': null,
  'createdAt': '2026-09-03T10:30:00.000Z',
  'deletedAt': '2026-09-04T11:00:00.000Z',
};

final String groupMessagesCursor = serverCursor(
  updatedAtIso: '2026-09-03T10:40:00.000Z',
  id: '019a3000-0000-7000-8000-00000000msg4',
);

final String groupMessagesCursorAfterChange = serverCursor(
  updatedAtIso: '2026-09-06T12:00:00.000Z',
  id: '019a3000-0000-7000-8000-00000000msg4',
);

/// **La page nominale, et elle porte un exemplaire de chaque origine** — membre,
/// serveur, et **auteur retiré**.
///
/// Sans ce dernier dans les fixtures, le cas d'ADR-0032 n'existerait que dans un
/// test unitaire et aucun écran ne le montrerait jamais à personne.
Map<String, Object?> groupMessagesPage({List<Object?>? items}) => deltaPage(
      items: items ??
          const [
            memberMessagePayload,
            myMessagePayload,
            systemMessagePayload,
            removedAuthorMessagePayload,
          ],
      nextCursor: groupMessagesCursor,
    );

/// La page **avant** le détachement : le quatrième message porte encore son
/// auteur.
Map<String, Object?> groupMessagesPageAttached() => groupMessagesPage(
      items: const [
        memberMessagePayload,
        myMessagePayload,
        systemMessagePayload,
        attachedAuthorMessagePayload,
      ],
    );

/// La page **du détachement** : la même ligne revient, `authorId` à `null` et
/// `isSystem` toujours `false`.
Map<String, Object?> groupMessagesDetachPage() => deltaPage(
      items: const [removedAuthorMessagePayload],
      nextCursor: groupMessagesCursorAfterChange,
    );

/// La page qui porte la **suppression de modération**.
Map<String, Object?> groupMessagesDeletionPage() => deltaPage(
      items: const [deletedMessagePayload],
      nextCursor: groupMessagesCursorAfterChange,
    );
