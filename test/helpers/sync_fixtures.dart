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
/// | les 15 collections | `GET /sync` | `app/sync/descriptors/registry.ts` |
/// | `full_resync_required` | `GET /sync` | `app/sync/actions/build_manifest.ts` (issues serveur #48/#49) |
/// | tirage delta | `GET /sync/{collection}` | `app/sync/controllers/pull_collection_delta_controller.ts` |
/// | `next_cursor` / `has_more` / `full_resync` | `GET /sync/{collection}` | `app/sync/actions/pull_delta.ts` (ADR-0017) |
/// | curseur opaque | — | `app/sync/cursors/composite_cursor.ts` |
/// | 404 clé inconnue | `GET /sync/{collection}` | `app/common/exceptions/ressource_not_exists_exception.ts` |
/// | ligne `teachings` | `GET /sync/teachings` | `app/mediatheque/transformers/teaching_transformer.ts` |
/// | rétractation | `GET /sync/teachings` | `app/sync/descriptors/teachings_descriptor.ts` (ADR-0025) |
/// | ligne `teaching_types` | `GET /sync/teaching_types` | `app/mediatheque/transformers/teaching_type_transformer.ts` (ADR-0023) |
/// | ligne `contributors` | `GET /sync/contributors` | `app/mediatheque/transformers/contributor_transformer.ts` |
/// | ligne `branches` | `GET /sync/branches` | `app/auth/transformers/branch_transformer.ts` |
/// | ligne `gatherings` | `GET /sync/gatherings` | `app/sync/descriptors/teaching_family_collection.ts` (issue serveur #133) |
/// | ligne `gathering_types` | `GET /sync/gathering_types` | idem — **le même transformer** que les deux collections d'enseignement |
/// | ligne `announcements` | `GET /sync/announcements` | PRD `annonces-comptes-officiels.md`, ADR-0029 |
/// | ligne `status_backgrounds` | `GET /sync/status_backgrounds` | ADR-0030 (les arrêts de dégradé et l'encre, dérivés à l'écriture) |
/// | ligne `official_accounts` | `GET /sync/official_accounts` | PRD `annonces-comptes-officiels.md` |
/// | ligne `official_account_memberships` | `GET /sync/official_account_memberships` | idem — collection **scoppée sur l'acteur** |
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

/// Les **dix-huit** collections du registre serveur (`app/sync/descriptors/
/// registry.ts`), dans l'ordre du registre, avec leur partition.
///
/// Treize jusqu'à l'issue serveur #133, qui y a ajouté la seconde famille de la
/// médiathèque — `gathering_types` (référentiel) juste après `teaching_types`,
/// et `gatherings` (contenu) juste après `teachings`. Une **collection neuve**
/// et non un élargissement : une collection neuve est ignorée par un client qui
/// ne la demande pas, là où une collection élargie contamine ceux qui ne savent
/// pas la lire.
///
/// Trois de plus avec la refonte des annonces (PRD serveur
/// `annonces-comptes-officiels.md`, ADR-0029 à ADR-0031) : `status_backgrounds`
/// est un référentiel partagé, `official_accounts` est cloisonnée par branche —
/// donc soumise au garde-fou « périmètre modifié », un fidèle qui change de
/// branche ne doit pas garder en magasin les comptes de l'ancienne —, et
/// `official_account_memberships` est **scoppée sur l'acteur** : le serveur n'y
/// sert jamais l'appartenance de quelqu'un d'autre, d'où la partition `private`.
/// `announcements`, elle, était déjà au registre.
///
/// Le manifeste les liste **toutes**, pas seulement celles qui ont bougé. La
/// partition n'est pas décorative : le garde-fou « droits changés » ne lève
/// `full_resync_required` que sur les collections `branch` — les privées
/// (`user_id = soi`) et les référentiels ne dépendent pas du périmètre.
const Map<String, String> kSyncCollections = {
  'announcements': 'branch',
  'branches': 'reference',
  'roles': 'reference',
  'modules': 'reference',
  'contributors': 'reference',
  'teaching_types': 'reference',
  'gathering_types': 'reference',
  'status_backgrounds': 'reference',
  'official_accounts': 'branch',
  'official_account_memberships': 'private',
  'spiritual_notes': 'private',
  'playback_progress': 'private',
  'events': 'branch',
  'teachings': 'branch',
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

/// Manifeste complet : les treize collections, dans l'ordre du registre.
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
// Lignes `teachings` — 18 clés, `camelCase`
// ─────────────────────────────────────────────────────────────────────────────

/// **Un enseignement complet.** Dix-huit clés, ni une de plus ni une de moins.
///
/// Il n'y a **ni `family`, ni `deletedAt`, ni durée, ni `mimeType`** : la
/// famille filtre côté serveur (un rassemblement ne voyage pas dans cette
/// collection), et `teachings` ne porte aucune colonne de soft-delete.
///
/// `imageLandscapeUrl` et `imagePortraitUrl` sont **relatives** : l'hôte de
/// l'API change d'un environnement à l'autre, c'est au client de résoudre
/// contre sa propre base. Deux images parce que l'accueil rend le même
/// enseignement à deux ratios opposés.
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
  'imageLandscapeUrl': '/uploads/teachings/019f2c40-landscape.webp',
  'imagePortraitUrl': '/uploads/teachings/019f2c40-portrait.webp',
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
  'imageLandscapeUrl': '/uploads/teachings/019f2c41-landscape.webp',
  'imagePortraitUrl': '/uploads/teachings/019f2c41-portrait.webp',
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
  'imageLandscapeUrl': '/uploads/teachings/019f2c42-landscape.webp',
  'imagePortraitUrl': '/uploads/teachings/019f2c42-portrait.webp',
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

/// **Un rassemblement complet.** Les mêmes dix-huit clés qu'un enseignement, et
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
  'imageLandscapeUrl': '/uploads/teachings/019f3a10-landscape.webp',
  'imagePortraitUrl': '/uploads/teachings/019f3a10-portrait.webp',
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
  'imageLandscapeUrl': '/uploads/teachings/019f3a11-landscape.webp',
  'imagePortraitUrl': null,
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
  'label': 'Bleu de marque',
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
  'label': 'Or accent',
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
  'label': 'Nuit profonde',
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
/// Il n'y a pas davantage de durée d'affichage, de libellé d'action, de piste
/// audio ni de vidéo : le serveur n'en sert aucun (les médias sont la phase 2).
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
  'isPinned': false,
  'ownerId': 'b6f0a1c2-0000-4000-8000-000000000002',
  'createdAt': '2026-05-21T06:58:00.000Z',
  'updatedAt': '2026-05-21T07:00:00.000Z',
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
