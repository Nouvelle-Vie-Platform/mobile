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
/// | les 13 collections | `GET /sync` | `app/sync/descriptors/registry.ts` |
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

/// Les **treize** collections du registre serveur (`app/sync/descriptors/
/// registry.ts`), dans l'ordre du registre, avec leur partition.
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
  'spiritual_notes': 'private',
  'playback_progress': 'private',
  'events': 'branch',
  'teachings': 'branch',
  'prayer_wall': 'branch',
  'groups': 'branch',
  'group_messages': 'branch',
};

/// Clé de collection **inconnue du registre** : le mobile pourrait la demander
/// (les rassemblements sont prévus, PRD §5 sexies) et le serveur répond alors
/// `404`. Un client doit **sauter la collection**, pas échouer sa synchro.
const String kUnregisteredCollection = 'gatherings';

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
