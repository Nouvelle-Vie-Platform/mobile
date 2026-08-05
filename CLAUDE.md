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
  `PrayerRequest`, `SpiritualNote`, `ChatMessage`, `Announcement`).
- `lib/data/` — `sample_data.dart` (données fictives) + `repositories/` :
  - `church_repository.dart` (`ChurchRepository` abstrait + `InMemoryChurchRepository`)
    — **synchrone**, et il ne couvre que les domaines **encore fictifs**.
  - `auth_repository.dart` / `http_auth_repository.dart`, `branch_repository.dart` —
    repositories **dédiés et asynchrones**, chacun hors de `ChurchRepository`.
  - `local/` — **le magasin local Drift**, voir ci-dessous.

### Magasin local (`lib/data/local/`) — ADR-0026
Base SQLite embarquée qui **peint les écrans** des collections répliquées : la
synchronisation y écrit, elle ne rend rien. Le réseau ne peint jamais.

- `app_database.dart` — `AppDatabase`, `schemaVersion`, `MigrationStrategy`.
- `tables/sync_tables.dart` — plomberie : `sync_cursors` (un curseur **par
  collection**), `sync_state` (état **global**, une ligne), `resync_tokens`.
- `tables/mediatheque_tables.dart` — `branches`, `teaching_types`,
  `contributors`, `teachings`.
- `sync_dao.dart` — primitives transactionnelles. `mediatheque_dao.dart` —
  lectures.

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
6. **Jointures tolérantes** + **« pas d'enseignement, pas de section »** :
   un enseignement sans intervenant s'affiche quand même ; une rubrique sans
   enseignement local ne sort pas de l'accueil (c'est ce qui fait disparaître
   d'elle-même une rubrique supprimée côté serveur — elle n'a pas de tombstone).

Le curseur est **opaque** : on le stocke et on le rejoue, jamais on ne le décode
ni ne le construit.

### Moteur de synchronisation (`lib/data/sync/`) — ADR-0026 + ADR-0027
La boucle **manifeste → tirage → application**, qui écrit dans le magasin et
**ne rend rien**. Aucun écran n'en dépend : c'est l'étape 2 qui les branchera.

- `sync_protocol.dart` — `SyncManifest`, `ManifestEntry`, `DeltaPage`,
  `readsAsRetraction`. **`snake_case` uniquement** (enveloppe et protocole).
- `sync_rows.dart` — JSON → companions Drift. **`camelCase` uniquement**
  (lignes). Les deux conventions vivent dans deux fichiers exprès : un
  désérialiseur à convention unique se trompe sur la moitié des clés.
- `synced_collection.dart` — le registre local **ordonné** : `teaching_types`,
  `contributors`, `branches`, puis `teachings`.
- `sync_api.dart` — `GET /sync` et `GET /sync/{collection}`, sur le `Dio`
  d'`ApiClient`. Un **404** devient `UnknownSyncCollection`.
- `sync_engine.dart` — la boucle. `sync_scheduler.dart` — les déclencheurs.

**Six règles, en plus des six du magasin :**
1. **Référentiels avant contenu.** Ça ne ferme pas la fenêtre où un enseignement
   arrive sans son intervenant (la jointure de lecture reste tolérante), ça
   supprime le cas fréquent : la toute première synchronisation.
2. **La `scope_version` est retenue en mémoire pendant tout le cycle et
   persistée en dernier** (ADR-0027). Une valeur pour les treize collections.
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
    (`teachingsProvider`, `groupsProvider`, `prayersProvider`, `notesProvider`,
    `announcementsProvider`, `chatProvider.family`) et `eventsProvider` (hors
    `ChurchRepository`, cf. ci-dessous).
  - `sync_providers.dart` : `appDatabaseProvider` (à surcharger par une base en
    mémoire dans les tests), `syncDaoProvider`, `mediathequeDaoProvider`,
    `syncApiProvider`, `syncEngineProvider`, `syncSchedulerProvider`. **Aucun
    écran ne les lit encore** — étape 2.
  - `theme_provider.dart` : `themeModeProvider` (Notifier) + `isDarkModeActive`.

### Brancher un vrai backend : **un repository dédié asynchrone par domaine**
Surcharger `churchRepositoryProvider` **ne suffit pas** et n'est pas le motif :
son contrat est synchrone, alors qu'un appel HTTP est asynchrone. Passer toute
l'interface en `Future` pour le premier domaine branché casserait d'un coup les
cinq autres et tous leurs écrans.

Le motif réel, déjà suivi par `AuthRepository`/`HttpAuthRepository` et
`BranchRepository` : quand un domaine est servi par le back, il **sort** de
`ChurchRepository` vers sa propre abstraction `Future`-based, avec une
implémentation HTTP et une implémentation en mémoire (servie quand
`AppEnv.useBackend` est faux), et son propre provider. `ChurchRepository`
rétrécit à mesure — c'est voulu ; il finira par disparaître.

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
`/teaching/:id`, `teachingByIdProvider` et `TeachingDetailScreen`. Trois
raisons, dans l'ordre d'importance :

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
- `TeachingCover` — visuel d'un enseignement : image réseau **avec repli coloré**.
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
  piloté par les données (ex. `Teaching.color`).
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
Maquette UI riche et cohérente, **données fictives** + **auth factice**.
Prochaines grandes étapes : backend + auth réels, dons/paiement, notifications,
finir d'habiller les écrans restants (onboarding, login/register, live, dons,
notes, nouvelle requête).
