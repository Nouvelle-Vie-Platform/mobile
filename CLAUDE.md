# CLAUDE.md — Maison du Miracle (app mobile)

Application Flutter de l'**Église Évangélique Nouvelle Vie – Maison du Miracle**.
Ce fichier résume ce qu'il faut savoir pour travailler efficacement sur ce
dépôt. Le respecter prime sur les habitudes par défaut.

## Stack & versions
- **Flutter 3.44.2** / Dart `>=3.6.0 <4.0.0`. Material 3.
- **flutter_riverpod ^3.x** (gestion d'état), **go_router ^17.x** (navigation),
  **flutter_localizations** + `gen-l10n` (i18n). `flutter_lints ^6`.
- **drift 2.34.0** (épinglé) + `drift_flutter` — magasin local SQLite, voir
  « Magasin local » plus bas. Premier générateur de code du dépôt
  (`build_runner`, `drift_dev`).
- **Le web reste une cible**, mais ce n'est plus gratuit. La règle précédente
  (« aucune dépendance native/plugin ») était déjà fausse — `flutter_secure_storage`
  a des implémentations natives — et Drift la retire pour de bon : il embarque
  `sqlite3` en natif, et sur le web il exige `web/sqlite3.wasm` et
  `web/drift_worker.js`, **versionnés dans le dépôt** et appariés à
  `pubspec.lock`. Après toute montée de version de `drift` ou `sqlite3` :
  `make web-assets`. Voir `web/WEB_ASSETS.md`.
- **image_picker ^1.2.3** (#36) — dépôt d'image du composeur d'annonces. Lu
  uniquement derrière `StatusImagePicker` (`lib/data/pickers/`). iOS exige
  `NSPhotoLibraryUsageDescription` dans `ios/Runner/Info.plist` : sans elle, le
  système **tue** l'application à l'ouverture du sélecteur.

## Commandes
```bash
flutter run -d <device>      # macos | chrome | <id simulateur/emulateur>
flutter analyze              # doit rester à 0 problème
flutter test                 # tests (smoke) — doivent rester verts
flutter test --run-skipped test/integration/   # exige un vrai serveur (voir plus bas)
flutter gen-l10n             # OBLIGATOIRE après toute édition d'un .arb
dart format lib/ test/       # formatage (CI le vérifie)
make gen                     # OBLIGATOIRE après tout changement de table Drift
make migrations              # + après un changement de schemaVersion
make web-assets              # après une montée de drift / sqlite3
```
La CI (`.github/workflows/flutter-ci.yml`) lance format + analyze + test.
**Elle ne lance pas `build_runner`** : les `.g.dart` et `drift_schemas/` sont
**versionnés**. Oublier `make gen` fait passer la CI sur du code périmé.

### `test/integration/` — contre un **vrai** serveur
Les tests qui parlent en HTTP à une instance `new-life-server` en marche, sans
aucun double d'`HttpClientAdapter` : ils vérifient ce qu'une fixture ne peut pas
prouver — que le serveur se comporte comme l'ADR le décrit, et que le moteur
s'accorde avec lui. Étiquetés `live-server` (`dart_test.yaml`) et **sautés par
défaut**, donc en CI, qui n'a pas de serveur. Marche à suivre (monter le
serveur, amorcer la base) : `test/integration/README.md`.

## Architecture (à respecter)
Couches claires, pensées pour brancher un backend sans toucher l'UI :

- `lib/models/` — modèles immuables (`ChurchEvent`, `Teaching`, `CommunityGroup`,
  `PrayerRequest`, `SpiritualNote`, `ChatMessage` — **fictif**, voir « La
  messagerie de groupe ») et **modèles de lecture** (`content_view.dart`,
  `mediatheque_view.dart`, `gathering_view.dart`, `announcement_view.dart`).
- `lib/data/` — `sample_data.dart` (données fictives) + `repositories/` :
  - `church_repository.dart` (`ChurchRepository` abstrait + `InMemoryChurchRepository`)
    — **synchrone**, et il ne couvre que les domaines **encore fictifs**.
  - `auth_repository.dart` / `http_auth_repository.dart`, `branch_repository.dart`,
    `calendar_repository.dart`, `mediatheque_repository.dart` /
    `store_mediatheque_repository.dart`, `gathering_repository.dart` /
    `store_gathering_repository.dart`, `announcement_repository.dart` /
    `store_announcement_repository.dart` — repositories **dédiés et asynchrones**,
    chacun hors de `ChurchRepository`.
  - `announcement_composer.dart` / `http_announcement_composer.dart` —
    **l'écriture** des annonces (#36), séparée de leur lecture ; voir « L'onglet
    Annonces ».
  - `local/` — **le magasin local Drift**, voir ci-dessous.
  - `pickers/status_image_picker.dart` — le choix d'une image de fond, derrière
    une abstraction (les tests injectent un sélecteur inerte).

### Le **modèle de lecture** de la médiathèque (`lib/models/content_view.dart`)
`ContentView` / `SectionView` : ce qu'un écran affiche, et rien de plus. Les
quatre règles de présentation y sont écrites **une fois pour les deux familles**
(ADR-0026, décision 3 — *le magasin stocke ce que le serveur envoie ; la
présentation se calcule à la lecture*) :

1. **La cascade de couleur s'y termine** : `teaching.color` sinon `type.color`
   sinon le bleu de marque (`kBrandFallbackColor`, `#223B8C`). Le serveur ne
   résout plus rien : s'il le faisait, changer la couleur d'une rubrique
   laisserait les téléphones sur l'ancienne teinte indéfiniment et en silence
   (ça ne bouscule l'`updated_at` d'aucun enseignement).
2. **Le libellé se replie par `pick`** — jamais de `?? label['fr']` ailleurs.
3. **Les URL d'image se résolvent par `resolveMediaUrl`** — le back les sert
   relatives, l'hôte change d'un environnement à l'autre.
4. **L'absence s'affiche comme une absence** : `authorName` reste `null` et la
   ligne ne se rend pas. **Jamais d'« Auteur inconnu »** — ça ressemble à une
   donnée et sera pris pour une erreur de saisie.

Un widget qui reçoit un `ContentView` n'a plus aucune règle à appliquer, donc
plus aucune occasion d'en appliquer une variante. `TeachingRubric` (enum à trois
valeurs) a disparu avec lui : la rubrique est une table SERIAL éditable depuis
le portail, et un enum est une décision figée à l'écriture. Le modèle porte
`teachingTypeId`, la rubrique se **joint**.

**Deux familles, deux types** (#34). `mediatheque_view.dart` porte
`TeachingView` / `HomeSectionView`, `gathering_view.dart` porte `GatheringView`
/ `GatheringSectionView` ; chacun descend du type commun sans s'y confondre.
C'est voulu, et c'est la règle qui gouverne tout le lot : **la clé de collection
est le discriminant, jamais un champ de ligne** (ADR-0026, décision 1). Un
enseignement et un rassemblement sont deux types, alimentés par deux
collections, rendus par deux écrans ; ce qu'ils partagent — la forme de la
charge utile, la couleur de repli, les deux cadrages d'image — se partage **par
composition**. Ni l'un ni l'autre ne porte de **champ de famille**, et n'en
portera : le serveur ne le sert pas, et ce n'est pas un oubli.

La langue du contenu vient de `contentLocaleProvider`
(`lib/state/locale_providers.dart`), recopiée par `app.dart` depuis la locale
que `MaterialApp` a réellement résolue : le repli se fait hors de l'arbre de
widgets, là où il n'y a pas de `BuildContext`.

### Magasin local (`lib/data/local/`) — ADR-0026
Base SQLite embarquée qui **peint les écrans** des collections répliquées : la
synchronisation y écrit, elle ne rend rien. Le réseau ne peint jamais.

- `app_database.dart` — `AppDatabase`, `schemaVersion`, `MigrationStrategy`.
- `tables/sync_tables.dart` — plomberie : `sync_cursors` (un curseur **par
  collection**), `sync_state` (état **global**, une ligne), `resync_tokens`.
- `tables/mediatheque_tables.dart` — `branches`, `teaching_types`,
  `contributors`, `teachings`. `tables/gathering_tables.dart` —
  `gathering_types`, `gatherings` (la seconde famille, #34).
  `tables/announcement_tables.dart` — `status_backgrounds`, `official_accounts`,
  `official_account_memberships`, `announcements` (le mur de statuts, #35).
- `sync_dao.dart` — primitives transactionnelles. `mediatheque_dao.dart`,
  `gathering_dao.dart` et `announcement_dao.dart` — lectures, **un DAO par
  domaine**.

**Six règles qui ne se renégocient pas** (ADR-0026 en donne le *pourquoi*) :
1. **Une page appliquée = une transaction** : ses lignes **et** son curseur, ou
   ni l'un ni l'autre. Un curseur avancé sur des lignes jamais appliquées est un
   trou permanent que rien ne refermera.
2. **La `scope_version` n'est PAS dans la table des curseurs** : un curseur
   appartient à une collection, elle est globale. Persistée **en dernier**.
3. **Resync = remplacement atomique**, jamais purger-puis-remplir : poser un
   jeton, re-tirer sans rien effacer, balayer à la fin ce que le cycle n'a pas
   revu.
4. **Aucune clé étrangère entre collections** : `contributorId` et
   `teachingTypeId` sont des entiers nus. Une contrainte ferait échouer une page
   valide entière.
5. **On stocke ce que le serveur envoie** : la carte `{fr,en,ee}` entière, la
   couleur **brute** (`null` = hérite de la rubrique), toutes les rubriques y
   compris masquées. Ce qui dépend d'autre chose se joint à la lecture.
6. **Jointures tolérantes** + **« pas de contenu, pas de section »** :
   un contenu sans intervenant s'affiche quand même ; une rubrique sans contenu
   local ne sort pas de l'accueil (c'est ce qui fait disparaître d'elle-même une
   rubrique supprimée côté serveur — ni `teaching_types` ni `gathering_types`
   n'a de tombstone).

Les deux familles n'ont **aucun invariant en propre** : les six règles valent
mot pour mot. Une verrue à connaître, en revanche : un élément de `gatherings`
porte **`teachingTypeId`** — le nom de la colonne FK de la table partagée côté
serveur — et se joint sur **`gathering_types`**. Le champ n'a pas été renommé
pour ne pas casser les consommateurs de `teachings` ; ne pas le « corriger ».

Le curseur est **opaque** : on le stocke et on le rejoue, jamais on ne le décode
ni ne le construit.

### Moteur de synchronisation (`lib/data/sync/`) — ADR-0026 + ADR-0027
La boucle **manifeste → tirage → application**, qui écrit dans le magasin et
**ne rend rien**. Aucun écran n'en dépend directement — ils lisent le magasin,
qu'elle remplit. Le réseau ne peint jamais.

- `sync_protocol.dart` — `SyncManifest`, `ManifestEntry`, `DeltaPage`,
  `readsAsRetraction`. **`snake_case` uniquement** (enveloppe et protocole).
- `sync_rows.dart` — JSON → companions Drift. **`camelCase` uniquement**
  (lignes). Les deux conventions vivent dans deux fichiers exprès : un
  désérialiseur à convention unique se trompe sur la moitié des clés.
- `synced_collection.dart` — le registre local **ordonné** : `teaching_types`,
  `gathering_types`, `status_backgrounds`, `official_accounts`,
  `official_account_memberships`, `contributors`, `branches`, puis `teachings`,
  `gatherings`, `announcements`.
- `sync_api.dart` — `GET /sync` et `GET /sync/{collection}`, sur le `Dio`
  d'`ApiClient`. Un **404** devient `UnknownSyncCollection`.
- `sync_engine.dart` — la boucle. `sync_scheduler.dart` — les déclencheurs.

**Six règles, en plus des six du magasin :**
1. **Référentiels avant contenu.** Ça ne ferme pas la fenêtre où un enseignement
   arrive sans son intervenant (la jointure de lecture reste tolérante), ça
   supprime le cas fréquent : la toute première synchronisation.
2. **La `scope_version` est retenue en mémoire pendant tout le cycle et
   persistée en dernier** (ADR-0027). Une valeur pour les dix-huit collections.
   Persistée trop tôt, elle éteint un resync qui n'a pas eu lieu — et le
   manifeste ne le redemandera **jamais**. Un cycle interrompu ne persiste rien.
3. **« Rétractation ou ligne », décidé avant toute construction d'objet** :
   `deletedAt` non nul → la ligne quitte le magasin, rien n'est désérialisé.
4. **Le client n'efface jamais de sa propre initiative** une ligne d'une
   collection répliquée — `playback_progress` en particulier, qui **est** une
   collection synchronisée et non de l'état local.
5. **Un resync forcé se lit dans un `200`** (`full_resync` / `full_resync_required`),
   jamais dans une erreur — et il **remplace**, il ne purge pas d'abord.
6. **Un `404` de collection n'est pas fatal** : collection sautée, synchro
   poursuivie.

Déclenchement : **ouverture, foreground, tirer-pour-rafraîchir**. *Jamais de
polling* — aucun `Timer` dans `lib/data/sync/`, et un test le vérifie.
Le curseur du manifeste (`current_cursor`) est la **borne haute du périmètre**,
pas un accusé de réception : il ne devient jamais le curseur local.
- `lib/state/` — providers Riverpod :
  - `repository_providers.dart` : `churchRepositoryProvider` + providers de données
    (`groupsProvider`, `prayersProvider`, `notesProvider`,
    `chatProvider.family`) et `eventsProvider` (hors `ChurchRepository`, cf.
    ci-dessous).
  - `announcement_providers.dart` : `announcementRepositoryProvider`,
    `announcementsProvider` et `canComposeAnnouncementProvider`. **C'est là que
    vivent les deux règles que le serveur ne prend pas** — le filtre
    d'expiration et le tri —, et le § « L'onglet Annonces » plus bas dit
    pourquoi. Côté **écriture** (#36) : `announcementComposerProvider` (le seul
    provider de cet onglet qui parle au réseau), `composerOptionsProvider` (mes
    comptes + les fonds actifs, lus du magasin) et
    `announcementDraftProvider.family` (la ligne **brute** d'une annonce à
    modifier), plus `statusImagePickerProvider`.
  - `mediatheque_providers.dart` : `mediathequeRepositoryProvider` (magasin avec
    backend, double en mémoire sinon) + `latestTeachingsProvider`,
    `allTeachingsProvider`, `teachingsOfTypeProvider.family`,
    `teachingByIdProvider.family`, `homeSectionsProvider` — tous des
    `StreamProvider`, donc des `AsyncValue` côté écran. **Pas de réessai
    automatique** (`retry: _noAutomaticRetry`), même raison que l'agenda.
  - `gathering_providers.dart` : le pendant strict du précédent pour la
    seconde famille — `gatheringRepositoryProvider`, `allGatheringsProvider`,
    `gatheringsOfTypeProvider.family`, `gatheringByIdProvider.family`,
    `gatheringSectionsProvider`. Deux jeux de providers et non un paramétré par
    une famille : c'est ce qui rend impossible qu'un rassemblement se glisse
    dans une liste d'enseignements.
  - `locale_providers.dart` : `contentLocaleProvider` — la langue de repli des
    **contenus** servis par le back, distincte de celle de l'interface.
  - `sync_providers.dart` : `appDatabaseProvider` (à surcharger par une base en
    mémoire dans les tests), `syncDaoProvider`, `mediathequeDaoProvider`,
    `syncApiProvider`, `syncEngineProvider`, `syncSchedulerProvider`,
    `gatheringDaoProvider`, `announcementDaoProvider`, `pullToRefreshProvider`.
    Les trois DAO de lecture sont lus par les trois repositories de magasin.
    **Les trois déclencheurs d'ADR-0017 sont câblés** : `app.dart` appelle
    `SyncScheduler.start()` au premier frame sous `AppEnv.useBackend` (et c'est ce même appel qui abonne le planificateur au
    cycle de vie, donc au **retour au premier plan**) ; la médiathèque passe
    `pullToRefreshProvider` à son `RefreshIndicator`. Jamais de polling.
    `test/state/cold_start_test.dart` parcourt la chaîne entière — sans lui,
    une rupture entre synchronisation et magasin donnerait une application
    **muette**, pas une erreur : un magasin vide ne se plaint pas.
  - `theme_provider.dart` : `themeModeProvider` (Notifier) + `isDarkModeActive`.

### L'onglet Annonces — trois responsabilités que le serveur ne prend pas
Le mur de statuts est peint par le magasin (#35), comme la médiathèque. Sa
spécification de **rendu** est `docs/statuts-annonces.md` ; son contrat de
**donnée** vient du serveur (PRD `annonces-comptes-officiels.md`, ADR-0029 à
ADR-0031). Trois règles vivent côté client, et aucune n'est un choix de confort :

1. **L'expiration se filtre à la lecture** (`announcementsProvider`). Le serveur
   sert `expiresAt` brut et ne retire jamais une annonce expirée du flux delta :
   un statut « valable jusqu'à ce soir » doit disparaître **à la seconde**, y
   compris hors-ligne. Ni le serveur ni une requête SQL ne peuvent le tenir — une
   requête est évaluée quand la table change, pas quand l'heure passe.
2. **Le tri est écrit une fois** : épinglés, `publishedAt` décroissant, `id` en
   départage (`List.sort` n'est pas stable en Dart).
3. **Les deux jointures** : `accountId` → `official_accounts` (l'en-tête est
   `shortName ?? name`), `backgroundId` → `status_backgrounds`. Tolérantes : une
   annonce dont le compte manque s'affiche quand même, **sans en-tête inventé**.

**Interdit : recalculer un dégradé ou un contraste.** Le serveur a dérivé
`topColor`, `bottomColor` et `ink` à l'écriture (ADR-0030) ; le rendu peint.
`statusGradient` / `statusForegroundOn` / `statusBaseColor`
(`lib/theme/status_palette.dart`) ne servent plus **que de repli** quand aucun
fond n'est servi — teinte dérivée du hash de l'`id`. `statusPalette` a disparu.

Le client ne re-teste pas `publishedAt` : le serveur ne sert au mobile ni
brouillon ni annonce programmée. **L'écriture exige le réseau** (ADR-0031, pas de
file d'envoi ni de brouillon local) et son affordance n'existe que si
`official_account_memberships` est non vide — un **confort d'affichage, jamais
une autorisation** : le serveur revérifie à chaque écriture, et un membre retiré
du bureau verra encore le bouton et recevra un 403.

#### L'écriture (#36) — le seul endroit de l'onglet qui parle au réseau
`AnnouncementComposer` (`data/repositories/announcement_composer.dart`,
implémentation HTTP à côté) est **séparé** d'`AnnouncementRepository`, et pas par
commodité : les deux n'ont ni la même source (serveur / magasin), ni la même
forme (`Future` / `Stream`), ni le même régime hors-ligne (**impossible** /
normal). Les fondre donnerait un objet dont la moitié des méthodes marchent en
avion. `models/announcement_draft.dart` porte le modèle d'**écriture** —
identifiants bruts et octets d'image — face au modèle de **lecture**.

Six règles, toutes vérifiées par des tests :

1. **Le corps est en `camelCase`** (`accountId`, `publishedAt`…), et le champ de
   fichier s'appelle `backgroundImage`. Le **`snake_case` de ce serveur ne
   concerne que les query strings** (`?branch_id=`) et l'enveloppe `/sync` : ses
   corps REST sont en `camelCase` de bout en bout, `HttpAuthRepository` y poste
   déjà `firstName` / `branchId`. Ne pas « corriger » vers `snake_case` — le
   validateur VineJS refuserait chaque clé.
2. **Quatre champs ne partent jamais** : `branchId` (dérivé du compte),
   `audienceId`, `isPinned`, `notify` — refusés en 422 pour un membre de
   compte. Le composeur n'a donc **pas de sélecteur de branche** : choisir le
   compte *est* choisir la portée.
3. **Trois modes de publication, un seul champ `publishedAt`** : omis =
   maintenant (l'horloge est celle du serveur), `null` explicite = brouillon,
   instant futur = programmé. La nuance « clé absente / clé nulle » décide si
   l'annonce paraît. En multipart, où l'on ne peut pas écrire `null`, **la chaîne
   vide vaut `null`** — règle du contrat (PRD §18, étendue à `publishedAt`,
   `expiresAt` et `backgroundId`), et non un booléen `draft` de plus qui ferait
   diverger le mobile du portail.
4. **Le composeur n'écrit pas dans le magasin.** Après un envoi réussi il
   déclenche un cycle de synchronisation et rend la main ; le flux delta ramène
   l'annonce. Le réseau ne peint jamais.
5. **Modifier et supprimer se décident sur `accountId`, pas sur `ownerId`** : un
   compte officiel est un espace éditorial **collectif**, et un comité doit
   pouvoir se corriger. C'est la seule raison pour laquelle `AnnouncementView`
   porte `accountId`, un champ qui ne s'affiche pas.
6. **Aucun refus ne sort en brut.** `AnnouncementWriteErrorCode` distingue
   réseau / 401 / 403 / 422 / 404 / 5xx, l'écran choisit la phrase, et **la
   saisie reste à l'écran** dans tous les cas. Hors ligne et 403 sont les deux
   chemins **normaux** de cet écran, pas des cas exotiques.

Le contrat détaillé, le nom du champ de fichier (`backgroundImage`) et la limite
assumée (on ne sait pas retirer une image déjà publiée) sont dans
`docs/statuts-annonces.md` §11.

### La messagerie de groupe — l'origine se lit sur `(authorId, isSystem)`
**Encore fictive** (`ChatMessage`, `chatProvider`, `InMemoryChurchRepository`) :
le modèle mobile ne porte aujourd'hui **ni `authorId` ni `isSystem`**. Le
contrat de branchement est écrit d'avance dans `docs/messagerie-groupe.md`, et
il tient en une règle :

| `authorId` | `isSystem` | origine |
| --- | --- | --- |
| uuid | `false` | un membre |
| `null` | `true` | message **système** (serveur) |
| `null` | `false` | **auteur retiré** — compte supprimé (ADR-0032) |

**Ne jamais tester `authorId == null` pour décider « c'est un message
système ».** Le nul a deux sens depuis la suppression de compte
(`miracle-house-server#128`) : un client qui teste le nul seul affiche les
messages d'un membre parti comme des annonces du serveur — centrés, en gris,
sans bulle. Rien ne plante, aucun test ne rougit.

Deux corollaires qui se ratent aussi en silence : le détachement arrive **sur
une ligne déjà stockée** (`author_id → NULL` avec `updated_at` bumpé, donc dans
le flux delta), l'écriture du magasin doit donc **remplacer** et non fusionner —
`Value(_optionalText(…))` + `InsertMode.insertOrReplace`, le patron existant ; et
le mobile n'a **aucune source de nom de membre** (pas de collection `users`,
ADR-0029), ce qui est un prérequis de branchement, pas un détail d'habillage
(§6 du document).

### Brancher un vrai backend : **un repository dédié asynchrone par domaine**
Surcharger `churchRepositoryProvider` **ne suffit pas** et n'est pas le motif :
son contrat est synchrone, alors qu'un appel HTTP est asynchrone. Passer toute
l'interface en `Future` pour le premier domaine branché casserait d'un coup les
cinq autres et tous leurs écrans.

Le motif réel, déjà suivi par `AuthRepository`/`HttpAuthRepository`,
`BranchRepository`, `CalendarRepository` et `MediathequeRepository` : quand un
domaine est servi par le back, il **sort** de `ChurchRepository` vers sa propre
abstraction `Future`/`Stream`-based, avec une implémentation réelle (HTTP, ou
**le magasin local** pour les collections répliquées) et une implémentation en
mémoire (servie quand `AppEnv.useBackend` est faux), et son propre provider.
`ChurchRepository` rétrécit à mesure — c'est voulu ; il finira par disparaître.

Le double en mémoire n'est pas un bouchon : il doit appliquer **les mêmes règles
de lecture** que l'implémentation réelle. Un double qui construirait ses modèles
autrement laisserait les bugs de cascade et de repli de langue invisibles
pendant tout le développement (`test/data/mediatheque_repository_test.dart`
vérifie la parité).

Un domaine adossé au magasin se lit en **`Stream`**, jamais en `Future` : la
synchronisation réécrit sous les pieds des écrans, et une rétractation reçue
pendant qu'un fidèle écoute doit retirer le contenu de l'écran ouvert. Un
`Future` livrerait une photographie prise au moment du clic.

Les écrans du domaine migré changent, eux : ils passent d'une lecture
synchrone à un `AsyncValue` (chargement / vide / erreur). C'est le coût réel de
la bascule, à ne pas sous-estimer dans les estimations.

**Modèles** : ce que sert le back est une **donnée**, jamais du texte
pré-formaté — un instant UTC (`ChurchEvent.startsAt`) et non « Dimanche 26 Mai »,
une `Map<String,String>` multilingue et non un libellé. Le formatage vit dans la
vue : `utils/i18n_text.dart` (`pick`, repli de langue) et `utils/event_time.dart`
(dates et heures). Ces helpers sont l'**unique** endroit où ces règles sont
écrites — ne pas disséminer de `?? title['fr']` dans les widgets.

- `lib/router/app_router.dart` — `routerProvider` (GoRouter), noms dans `AppRoute`.
  Voir « Navigation : l'identifiant, jamais l'objet ».
- `lib/theme/` — `app_colors.dart` (couleurs de marque + dégradés),
  `app_palette.dart` (palette adaptative clair/sombre via `ThemeExtension`,
  accès `context.palette`), `app_typography.dart` (police **Atkinson Hyperlegible**),
  `app_spacing.dart` (`AppSpacing`, `AppRadius`, `AppShadows`), `app_theme.dart`.
- `lib/screens/` — un écran par fichier. `lib/widgets/` — composants partagés
  (`cards/`, `chat/`).
- `lib/l10n/` — voir i18n.
- `main.dart` → `ProviderScope(MaisonDuMiracleApp)` ; `app.dart` → `MaterialApp.router`.

### Navigation : **l'identifiant, jamais l'objet** (domaines branchés)
Convention **abandonnée** (#27) : « les écrans de détail reçoivent leur objet
via `extra`, avec repli sur le 1er élément si accès direct ». Elle survit
seulement là où le domaine est encore fictif et sans identité (`/group-chat`,
`/event`), et doit tomber avec chacun d'eux.

La règle pour tout domaine porteur d'un `id` : **la route porte l'identifiant
en `pathParameter`, l'écran résout la donnée depuis son provider** — voir
`/teaching/:id`, `teachingByIdProvider` et `TeachingDetailScreen`, et son jumeau
`/gathering/:id`. **Une route par famille**, jamais `/content/:famille/:id` : le
chemin dirait alors au client qu'il lui revient de trancher entre deux
collections, exactement ce que la clé de collection sert à ne pas avoir à faire.
Trois raisons, dans l'ordre d'importance :

1. **Un objet passé par `extra` est une copie hors du magasin**, figée au
   moment du clic. Le serveur peut rétracter (dépublication ou
   reprogrammation : `{ id, deletedAt }` dans le flux delta, ADR-0025) ; l'écran
   qui tient sa copie continue d'afficher — lecteur compris — un contenu retiré,
   et l'utilisateur le retrouve disparu de la liste au retour. Résoudre à chaque
   build, c'est rester branché sur la source de vérité.
2. **Sans identifiant, rien n'est désignable de l'extérieur.** Une notification
   FCM (ADR-0017) ou un lien partagé n'a qu'une chaîne à transmettre. Le repli
   `.first` n'était pas un garde-fou : c'était l'aveu qu'`/teaching` ne pouvait
   désigner *aucun* enseignement en particulier — et il levait de toute façon
   sur un magasin vide.
3. Un identifiant est **présent ou absent**, il n'y a rien à quoi se replier.
   Un identifiant qui ne résout rien n'est pas une erreur technique : c'est un
   contenu retiré, et ça s'affiche (ci-dessous).

### Les **quatre absences** — `widgets/content_absence.dart`
Un contenu ouvert peut n'avoir rien à montrer pour quatre raisons distinctes,
qui se ressemblent à l'écran et répondent à des questions différentes :
`retracted` (retiré, définitif), `notSynced` (pas encore reçu par le magasin
local), `noMedia` (publié, fichier pas encore attaché), `offlineMedia` (média
non téléchargé, appareil hors ligne). `ContentAbsence` porte les quatre textes,
`ContentAbsenceView` les rend toutes — **ne pas écrire un écran d'absence de
plus**, ajouter une variante.

Partis pris valables pour les quatre : on **n'éjecte pas** l'utilisateur de
l'écran qu'il avait ouvert (il croirait à un bug), on **ne fige pas** la
dernière copie connue (ça ment), la lecture en cours **s'arrête**, et il y a
toujours une porte de sortie.

À ne pas confondre avec les états de liste : `AppErrorState` (teinté,
« Réessayer ») dit « je n'ai pas pu charger » ; `AppEmptyState` est une carte
dans une liste. Une absence, elle, occupe l'écran entier.

### Navigation principale
`HomeShell` = `IndexedStack` de 4 onglets **Accueil · Annonces · Communauté ·
Profil** + `BottomAppBar` à encoche + **FAB central** (→ médiathèque, route
poussée). Le FAB n'est PAS un onglet.

### Composants réutilisables clés
- `BrandAppBar` — en-tête au dégradé bleu de marque (`gradientPrimary`), texte
  blanc. **Tous les écrans à app bar l'utilisent** (sauf accueil/médiathèque/
  lecteur qui ont un en-tête immersif propre).
- `AppCard` — carte **verre dépoli** (translucide + `BackdropFilter` + liseré).
- `AppBackground` — dégradé « glass » global, **posé par route** (les `Scaffold`
  sont transparents). Indispensable : peindre le fond par écran garde les
  transitions opaques (sinon on voit la page sortante à travers).
- `ContentCover` — visuel d'un `ContentView` (les deux familles) : image réseau
  **avec repli coloré**. Il ne résout plus rien (URL et couleur arrivent déjà
  résolues), il choisit un cadrage et dessine.
- `ContentPlayerView` — le lecteur plein écran, partagé par les deux écrans de
  détail. Il reçoit le **provider** (et non sa valeur) pour pouvoir l'écouter :
  une rétractation immédiatement suivie d'une resynchronisation ne produirait
  qu'une reconstruction, et le son aurait continué sur un contenu retiré.
- `home/home_content_section.dart` — le dessin d'une section d'accueil, sans la
  famille ; `home_teaching_section.dart` et `home_gathering_section.dart` le
  câblent, chacun à son provider et à sa route.
- `widgets/chat/` — `ChatAppBar`, `ChatBubble`, `ChatDatePill`,
  `ChatInfoBanner`, `MessageInputBar`.

## Conventions de code
- **État éphémère local** (onglet courant, champ de formulaire, lecteur) →
  `StatefulWidget` / `ConsumerStatefulWidget`. **Jamais** un `ValueNotifier`
  créé dans `build()` (bug historique corrigé), ni un provider global pour de
  l'état purement local. Riverpod = état **partagé** (thème, données, routeur).
- **Images réseau** : toujours `Image.network(..., errorBuilder: …)` avec repli
  (sinon échec hors-ligne **et** en test — `flutter test` renvoie 400 sur tout
  réseau).
- Couleurs/espacements/typo : passer par `AppColors` / `context.palette` /
  `AppSpacing` / `AppTypography`. Ne pas coder de couleurs en dur sauf habillage
  piloté par les données (ex. `ContentView.color`, **déjà résolue**).
- Textes destinés à l'utilisateur : **toujours via l10n** (`context.l10n.xxx`),
  jamais en dur.

## i18n
- `gen-l10n` configuré (`l10n.yaml`). Langue **modèle = `app_fr.arb`**.
  `app_en.arb` complet ; `app_ee.arb` (éwé) **partiel** → repli français
  automatique pour les clés manquantes (délégués dans `l10n_setup.dart`).
- Workflow : éditer les `.arb` (au moins `fr`) → `flutter gen-l10n` → utiliser
  `context.l10n.maCle`. Ne pas éditer à la main les `app_localizations*.dart`
  (générés).

## Git
- **Commits canoniques** : un commit par fonctionnalité, atomique, préfixes
  conventionnels (`feat/fix/chore/refactor(scope)`), corps en français.
- **Ne PAS ajouter de trailer `Co-Authored-By`** (commits attribués à l'auteur).
- **Ne pas pousser à la place de l'utilisateur** : il fait `git push` lui-même
  (souvent `git push --force-with-lease`, la branche distante ayant divergé).

## Environnement (cette machine)
- **Android** : **OpenJDK 21** installé (`brew install openjdk@21`) et configuré
  via `flutter config --jdk-dir /usr/local/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home`.
  Le JDK 26 (système) faisait échouer Gradle ; ne pas y revenir. Build OK.
- **Web (`flutter run -d chrome`)**, **simulateur iOS** et **émulateur Android**
  fonctionnent. Raccourcis dans le `Makefile` (`make ios` / `make android` / `make web`).
- Le premier build iOS/Android est long ; relances suivantes rapides.

## Statut
Maquette UI riche et cohérente, **données fictives** + **auth factice** pour ce
qui reste dans `ChurchRepository` (groupes, prières, notes, discussions).
Prochaines grandes étapes : backend + auth réels, dons/paiement, notifications,
finir d'habiller les écrans restants (onboarding, login/register, live, dons,
notes, nouvelle requête).
