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
  `pubspec.lock`. Le lecteur de la médiathèque y ajoute `web/hls.min.js` (#46),
  versionné de la même façon mais épinglé dans `tool/web_assets.sh` — `hls.js`
  n'est pas un paquet Dart. Après toute montée de `drift`, `sqlite3` ou
  `hls.js` : `make web-assets`. Voir `web/WEB_ASSETS.md`. **Aucun CDN.**
- **`flutter_secure_storage ^10.3.1`** — le coffre du **token d'accès**
  (`ApiClient`), et rien d'autre qui compte : sous ADR-0020 il n'y a pas de mot
  de passe, le token *est* la session, et le seul moyen d'en obtenir un est un
  OTP. Le stocker en clair rendrait un vol de fichier — sauvegarde iTunes,
  appareil rooté — équivalent à un accès au compte **sans OTP**. `UserCache` s'y
  appuie aussi, mais pour du non-secret et par accident historique (voir son
  en-tête) ; ce cache-là a vocation à rejoindre Drift.

  **La v10 a mis fin à CocoaPods dans ce dépôt** (voir plus bas). Ne pas monter
  en **v11** aujourd'hui : son module Android code en dur `compileSdk = 37`, or
  Google a renommé ses plateformes en versions mineures (`android-36.1`,
  `android-37.0`) et il n'existe plus de paquet `platforms;android-37` — AGP
  cherche un répertoire qui ne peut pas exister. La v11 exige par ailleurs
  `minSdk 24`, déjà pris.
- **image_picker ^1.2.3** (#36) — dépôt d'image du composeur d'annonces. Lu
  uniquement derrière `StatusImagePicker` (`lib/data/pickers/`). iOS exige
  `NSPhotoLibraryUsageDescription` dans `ios/Runner/Info.plist` : sans elle, le
  système **tue** l'application à l'ouverture du sélecteur.
- **just_audio ^0.10 + audio_service ^0.18 + audio_session ^0.2** (#39) — le
  lecteur de la médiathèque. `audio_service` est pris **en direct** :
  `just_audio_background` ne permet pas de choisir les boutons de la
  notification, et « −30 s / +30 s » est une exigence produit. Voir « Le lecteur
  de la médiathèque » plus bas — configuration native obligatoire des deux
  côtés. **Aucun des trois ne sert sur le web** (#46) : `just_audio_web` ne joue
  rien hors Safari, et `audio_service` y est un no-op.
- **flutter_zoom_drawer ^3.2.0** (#54) — le **menu latéral** de l'accueil. Pur
  Dart, aucune configuration native, la cible web reste tenue. Voir « Le menu
  latéral » plus bas : il se construit dans `HomeShell.build()`, son
  `mainScreen` est le `Scaffold` entier **et repeint `AppBackground`**, son
  inclinaison est à **zéro**, et son geste de glissement est **coupé**.
- **package_info_plus ^9.0.1** (#57) — la **version et le build du binaire
  installé**, dans « À propos ». Plugin natif, après `flutter_secure_storage`,
  `drift`, `image_picker`, `flutter_zoom_drawer` et les trois du lecteur, mais
  le seul qui **n'exige aucune permission sur aucune plateforme** :
  rien à ajouter à `Info.plist` ni à `AndroidManifest.xml` (manifeste Android
  du greffon vide, `PrivacyInfo.xcprivacy` embarqué côté iOS). Le web est
  couvert. Lu **uniquement** derrière `AppVersionReader`
  (`lib/data/app_version.dart`), et voir « À propos » plus bas : sous
  `flutter test`, un canal de plugin lève `MissingPluginException`.
- **connectivity_plus ^7.3.1** — le **type de transport** (wifi / données
  mobiles), et rien d'autre. Il alimente le seul mode « Automatique » de la
  qualité d'écoute : plafond à 64 kbps hors wifi.

  **La réserve écrite plus bas reste valable là où elle a été écrite**, et il ne
  faut pas la lire comme une contradiction : pour savoir si l'appareil a
  vraiment *internet*, ce paquet ment — il répond « connecté » derrière un
  portail captif, c'est-à-dire exactement quand sa réponse compterait. La panne
  d'écoute continue donc de se déduire de l'échec lui-même. Lire *par quel
  tuyau* on passe est une autre question, et il y est fiable : c'est l'OS qui
  répond, sans aller-retour réseau. **Aucune permission** sur aucune
  plateforme ; le web est couvert en mode dégradé (le navigateur rend souvent
  `unknown`, traité comme « pas de cellulaire », donc sans bridage — le bon
  défaut sur un ordinateur). Lu **uniquement** derrière `NetworkTransport`
  (`lib/data/network/`).
- **path_provider ^2.1.6** — le **dossier de cache du fond des lecteurs**, et
  rien d'autre. Déjà présent en transitif (`drift_flutter`,
  `background_downloader`, `just_audio`) ; déclaré parce qu'on l'importe
  soi-même, comme `web`. **Aucune permission** sur aucune plateforme. Lu
  uniquement derrière `SeasonBackgroundStore` (`lib/data/backgrounds/`), qui
  rattrape tout — sous `flutter test` le canal de plugin n'existe pas, et un
  lecteur monté dans un test ne doit pas rougir pour un décor.
- **`web ^1.1.1`** (#46) — l'interop DOM du lecteur web, successeur de
  `dart:html` (retiré du jeu en Dart 3.12, comme `package:js`). Déjà présent en
  transitif ; déclaré parce qu'on l'importe soi-même. **Un seul fichier de
  `lib/` l'importe**, `hls_content_player.dart`.

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
make web-assets              # après une montée de drift / sqlite3 / hls.js
make icons                   # après tout changement de brand_logo.webp / live_bg.png
make hls-probe               # prouve dans Chrome que le lecteur web joue (réseau requis)
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
  `mediatheque_view.dart`, `gathering_view.dart`, `announcement_view.dart`,
  `legal_document_view.dart`).
- `lib/data/` — `sample_data.dart` (données fictives) + `repositories/` :
  - `church_repository.dart` (`ChurchRepository` abstrait + `InMemoryChurchRepository`)
    — **synchrone**, et il ne couvre que les domaines **encore fictifs**.
  - `auth_repository.dart` / `http_auth_repository.dart`, `branch_repository.dart`,
    `calendar_repository.dart`, `mediatheque_repository.dart` /
    `store_mediatheque_repository.dart`, `gathering_repository.dart` /
    `store_gathering_repository.dart`, `announcement_repository.dart` /
    `store_announcement_repository.dart`, `legal_repository.dart` /
    `store_legal_repository.dart` — repositories **dédiés et asynchrones**,
    chacun hors de `ChurchRepository`.
  - `announcement_composer.dart` / `http_announcement_composer.dart` —
    **l'écriture** des annonces (#36), séparée de leur lecture ; voir « L'onglet
    Annonces ».
  - `legal_acceptance_recorder.dart` / `http_legal_acceptance_recorder.dart` —
    **l'écriture du consentement** (#56, `POST /legal/accept`), séparée de la
    lecture des documents pour les mêmes trois raisons que le composeur
    d'annonces : autre source, autre forme, autre régime hors-ligne.
  - `playback_progress_reporter.dart` / `http_playback_progress_reporter.dart`
    / `playback_progress_recorder.dart` — **la reprise de lecture** (#43) :
    le contrat de rapport, son implémentation HTTP muette, et les cinq
    déclencheurs. Voir « La reprise de lecture » plus bas.
  - `local/` — **le magasin local Drift**, voir ci-dessous.
  - `pickers/status_image_picker.dart` — le choix d'une image de fond, derrière
    une abstraction (les tests injectent un sélecteur inerte).
  - `app_version.dart` — `AppVersionReader` : la version et le build du binaire,
    derrière une abstraction pour la même raison (#57). L'implémentation réelle
    ne lève **jamais** ; l'inconnu se rend en `null`.
  - `players/` — les lecteurs, derrière une abstraction. Voir ci-dessous.

### Le lecteur de la médiathèque (`lib/data/players/`) — #39, #46
`ContentPlayer` / `ContentPlayback` : le contrat, et la valeur immuable que
l'UI observe. **Trois** implémentations vivent derrière lui, et **aucun écran ne
sait laquelle tourne** — c'est `main.dart` qui choisit, par `kIsWeb` :

- `JustAudioContentPlayer` (+ `ContentAudioHandler`) — la réelle, mobile. **Le
  seul fichier de `lib/` qui importe `just_audio`**, et un test de source le
  vérifie (`test/data/content_player_test.dart`), comme le garde-fou « jamais
  de polling » du moteur de synchronisation ;
- `InertContentPlayer` — celle des tests, et le **défaut** du provider :
  aucune minuterie, aucun canal de plugin, la position ne bouge pas d'elle-même ;
- `HlsContentPlayer` — celle du **web** (#46) : `hls.js` par interop JS, **sans
  aucun des trois paquets audio**. Voir « Le lecteur web » juste après.

**Le lecteur ne peut pas vivre dans un widget.** Sous `flutter test`, un
`AudioPlayer` se construit, mais `setUrl` et `dispose` lèvent
`MissingPluginException`, et `AudioService.init()` produit une **erreur
asynchrone non rattrapée** qui traverse le `try/catch` qui l'entoure et fait
rougir des tests qui n'ont rien demandé.

**`audio_service` en direct, pas `just_audio_background`** : celui-ci n'expose
que des intervalles et ne permet pas de **choisir les boutons** de la
notification, or « −30 s / +30 s » est une exigence produit. Le pas unique est
`kContentSkipInterval`, lu par le handler *et* par l'`AudioServiceConfig` *et*
par l'écran — donc aussi sur le web, où il n'y a que l'écran.

**Ce que ce choix n'a PAS évité — l'application embarque deux moteurs SQLite.**
Le raisonnement ci-dessus laisse croire qu'écarter `just_audio_background`
écarte aussi sa chaîne de dépendances. C'est faux, et la chaîne est courte :

```
audio_service 0.18.19 → flutter_cache_manager 3.4.1 → sqflite 2.4.3
drift_flutter 0.3.1   → sqlite3 + sqlite3_flutter_libs
```

`just_audio` n'y est pour rien — c'est `audio_service` seul qui tire
`flutter_cache_manager`. `sqflite` arrive donc avec ses implémentations natives
(`sqflite_android`, `sqflite_darwin`) **à côté** du `sqlite3` de Drift.

Ce n'est pas un bug et rien n'est à corriger : les deux moteurs ne se
rencontrent jamais, Drift ne connaît que le sien. C'est écrit ici pour la
personne qui auditera un jour la taille du binaire, ou qui s'étonnera de voir
`sqflite` dans `pubspec.lock` alors qu'aucun `pubspec.yaml` ne le demande —
sans quoi elle refera l'enquête, et pourrait « corriger » en retirant
`audio_service`. Vérifier avec `flutter pub deps --style=compact`.

**Le HLS est natif des deux côtés** : `just_audio` tire
`androidx.media3:media3-exoplayer-hls` sur Android et s'appuie sur `AVPlayer`
sur iOS. Aucun décodage logiciel, aucun greffon JS — c'est le web, sans
`just_audio`, qui est le cas particulier.

**Les cibles de déploiement ont de la marge** : le projet est à `minSdk 24`
(Android) et `IPHONEOS_DEPLOYMENT_TARGET 13.0` (iOS), contre 19 et 12 exigés
par la pile audio. Rien n'a eu à bouger pour l'ajouter, et rien n'a à bouger
pour la faire évoluer.

`minSdk` valait 23 jusqu'à la montée de `flutter_secure_storage` en v10. Ce 23
était une portée **nominale** : Flutter 3.35 a relevé son propre minimum à 24
(`FlutterExtension.minSdkVersion = 24`), ce qui rend API 23 invérifiable sous
toute version supportée — on annonçait un support qu'aucune chaîne d'outils ne
pouvait éprouver, et Gradle en avertissait à chaque build.

Cinq points qui se ratent en silence :

1. **`contentPlayerProvider` n'est pas `autoDispose`** : la lecture doit
   survivre au `context.pop()`, et un second `AudioPlayer` fait lever le
   service audio.
2. **La position émet plusieurs fois par seconde** : passer par
   `contentPlaybackProvider.select((p) => …)`, jamais par la valeur entière.
3. **`ContentPlayback.duration` est nullable** : en HLS elle arrive après le
   manifeste et, sur iOS, peut ne jamais arriver. `progress` rend `null` et non
   `0` — une barre indéterminée, pas une lecture figée au début.
4. **`androidStopForegroundOnPause: false`** dans `main()` : le défaut `true`
   lève `ForegroundServiceStartNotAllowedException` à la reprise sur
   Android 12+, c'est-à-dire au geste le plus banal d'un fidèle.
5. **La session audio se configure APRÈS `AudioService.init()`**, en profil
   `speech()` — les plugins audio s'écrasent mutuellement, et le profil
   « musique » baisse le volume à chaque instruction du GPS.

#### Le lecteur **web** (`hls_content_player.dart`) — #46
`just_audio_web` pose l'URL `.m3u8` dans un `<audio>` **sans lecteur HLS** : sa
classe de source HLS est une sous-classe vide. Chrome répond
`MEDIA_ERR_SRC_NOT_SUPPORTED` et rejette `play()` — l'application tourne et ne
joue rien. Le correctif amont n'a jamais été fusionné (issue ouverte depuis
2020) ; on ne met pas un fork non maintenu sur le chemin critique de l'écoute.

Cinq points qui se ratent en silence, eux aussi :

1. **Ne jamais interroger `canPlayType` en premier.** Chrome répond `"maybe"` à
   `canPlayType('application/vnd.apple.mpegurl')` et échoue quand même — mesuré,
   pas supposé. L'ordre est celui que `hls.js` documente : `Hls.isSupported()`
   d'abord (il teste `MediaSource`), le natif seulement en repli, pour Safari
   iOS. **Aucun reniflage d'agent utilisateur.**
2. **`main()` n'appelle pas `AudioService.init()` sur le web** : notification et
   écran verrouillé n'y existent pas. Un échec de démarrage du lecteur web ne
   doit jamais empêcher l'application de s'ouvrir — même `try` que sur mobile.
3. **Deux fichiers, une porte.** Les décisions vivent dans
   `media_element_playback.dart`, qui ne connaît **ni le DOM ni
   `dart:js_interop`** et se teste donc sous `flutter test` ;
   `hls_content_player.dart` n'a que des câbles et n'est **jamais compilé pour
   la VM** — `web_content_player.dart` est l'import conditionnel qui l'isole
   (`if (dart.library.js_interop)`). Sans cette porte, `flutter test` et les
   builds mobiles ne compileraient plus.
4. **`duration` d'un `<audio>` vaut `NaN`** avant les métadonnées et `Infinity`
   sur un flux live : les deux restent `null`, jamais `0`. Et une durée
   redevenue `NaN` (détachement de source) **n'efface pas** la durée connue.
5. **`load` rend la main dès la source attachée**, sans attendre les
   métadonnées : attendre `loadedmetadata` donnerait un `Future` qui ne se
   résout jamais si le manifeste ne répond pas. Les pannes arrivent par
   `value.error`, comme sur mobile.

Ce que `flutter test` ne peut pas dire — que `hls.js` se charge et qu'un `.m3u8`
avance — se prouve par **`make hls-probe`** : un point d'entrée web jetable
(`tool/hls_probe/`) qui pilote le vrai lecteur contre un flux HLS public dans un
Chrome sans tête. À relancer après toute montée de version de `hls.js`. Ce n'est
pas un test : réseau et Chrome requis, jamais en CI.

#### La panne **en cours d'écoute** (#42) — deux phrases, un chien de garde
Un décrochage réseau au milieu d'un prêche d'une heure n'est pas la même chose
qu'une ouverture qui n'a jamais joué, et le dépôt ne savait dire ni l'un ni
l'autre. Quatre points, tous valables pour les **deux** implémentations
réelles :

1. **`ContentPlayback.hasStarted` départage les deux phrases.** Vrai dès que le
   média a été prêt à jouer une fois (`ProcessingState.ready` côté `just_audio`,
   `canplay`/`playing` côté web). Échec **sans** qu'il ait jamais été vrai → il
   n'y a rien à reprendre, l'écran affiche `ContentAbsence.offlineMedia` (« il
   faut du réseau »). Échec **après** → « Lecture interrompue », avec une
   position à défendre. `isBuffering` ne pouvait pas servir de test : les deux
   implémentations le posent **dès le chargement**, avant tout aller-retour.
2. **Aucune bibliothèque de connectivité, et ce n'est pas un oubli.**
   `connectivity_plus` répond « connecté » derrière un portail captif — hôtel,
   wifi d'église mal configuré — c'est-à-dire exactement quand sa réponse
   compterait. La distinction se déduit de l'échec lui-même.
3. **`ContentPlayer.resume()` reprend à la position, jamais au début** — c'est
   ce que promet le mot « Reprendre » (`playerErrorRetry`), et « Réessayer »
   aurait fait craindre un retour à zéro suffisant pour que personne ne touche
   au bouton. Sur `just_audio` : après une panne fatale la plateforme repasse en
   `idle`, le lecteur bascule sur un lecteur **inactif qui capture position et
   source**, et `play()` recharge tout seul là où on en était — **vérifié dans
   le source de la 0.10.6, documenté nulle part**, d'où le **repli explicite**
   (rouvrir la source avec `initialPosition`) dès que `audioSource` est nul. Sur
   le web, aucun équivalent : reprendre y est **toujours** une réouverture, et
   la position s'y repose sur `loadedmetadata` — l'écrire avant est sans effet.
4. **Le chien de garde (`playback_watchdog.dart`) vit dans le lecteur**, jamais
   dans le `State` d'un widget (même raison que `StatusPlayer` : « pending
   timer »). Règle : lecture demandée + tampon en attente + position immobile
   pendant `kPlaybackStallTimeout` (**25 s**, nommé à un seul endroit, **valeur
   à confirmer**) → rouvrir la source à la position courante, indéfiniment. Il
   existe pour **iOS**, où un décrochage ne remonte *aucune* erreur vers Dart et
   où il n'y a *pas* de reconnexion native (contrairement à ExoPlayer) : sans
   lui, l'écoute meurt en silence et rien n'en porte la trace. Une panne déjà
   déclarée le désarme — l'écran affiche « Reprendre », recharger dans son dos
   ferait repartir le son sans que personne ne l'ait demandé. `MediaElementPlayback`
   ne l'arme **pas** d'elle-même (`armStallWatchdog`) : une minuterie d'office
   ferait rougir tous les tests qui l'instancient pour une traduction
   d'événement.

Configuration native : Android exige quatre permissions (dont
`POST_NOTIFICATIONS`, **demandée à l'exécution** par un canal de méthode vers
`MainActivity` — `audio_service` ne la demande pas et son manifeste est vide),
le service `mediaPlayback`, le `MediaButtonReceiver`, et `MainActivity extends
AudioServiceActivity`. iOS exige `UIBackgroundModes: audio` — et **surtout pas**
`NSAppTransportSecurity` : l'URL HLS est HTTPS publique, et
`NSAllowsArbitraryLoads` déclencherait une justification à l'App Review pour
rien.

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
  `contributors`, `teachings`, `teaching_guests` (le pivot des **invités**,
  #77 : un enseignement à plusieurs voix, **aucune nouvelle famille de
  contenu** ; **avec** tombstone — une ligne périmée y est un nom affiché sur un
  écran). `tables/gathering_tables.dart` —
  `gathering_types`, `gatherings` (la seconde famille, #34).
  `tables/announcement_tables.dart` — `status_backgrounds`, `official_accounts`,
  `official_account_memberships`, `announcements` (le mur de statuts, #35).
  `tables/playback_tables.dart` — `playback_progress` (collection **répliquée**)
  et `local_playback_positions` (**locale seule**, #43).
  `tables/legal_tables.dart` — `legal_documents` (#55) : **une ligne courante
  par genre** (`cgu`, `privacy`, `about`), sections brutes en JSON,
  **sans tombstone** — un document ne se supprime pas, il s'édite.
  `tables/season_tables.dart` — `seasons` : la période datée dont le **fond
  vertical** habille les lecteurs et l'écran de démarrage. **Sans tombstone**
  non plus, et celui-ci a un coût — voir « Le fond de l'application » plus bas.
  `tables/decor_tables.dart` — `decor` : **une seule ligne**, le fond par défaut
  quand aucune saison ne couvre le jour.
  `tables/vocabulary_tables.dart` — `presentation_vocabulary` (#81) : les mots
  réglés au portail. **Sans tombstone** — la ligne ne se supprime jamais côté
  serveur, effacer une surcharge y écrit `null`, et c'est ce `null` qui porte le
  retour au mot du dépôt jusqu'au téléphone. **PK textuelle** (la clé du
  catalogue), seule du registre dans ce cas.
  `tables/auth_tables.dart` — `auth_channels` (#83) : **une seule ligne**, par
  quelles portes l'application propose d'entrer, et ce qu'elle annonce. **Sans
  tombstone** — fermer un canal met un booléen à `false`, et c'est cette
  ligne-là qui voyage. Une table **vide** veut dire « pas encore reçu les
  réglages », jamais « aucun canal » : le repli est l'**e-mail seul**, et
  `AuthChannelsDao` est le seul endroit qui en décide.
- `sync_dao.dart` — primitives transactionnelles. `mediatheque_dao.dart`,
  `gathering_dao.dart`, `announcement_dao.dart`, `playback_dao.dart` et
  `legal_dao.dart` — lectures, **un DAO par domaine**. `playback_dao` est le
  seul qui **écrive**, et seulement dans la table locale seule.

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
  `official_account_memberships`, `legal_documents`, `seasons`,
  `presentation_vocabulary`, `auth_channels`, `decor`,
  `contributors`,
  `branches`, puis `teachings`, `teaching_guests`, `gatherings`,
  `announcements`, `playback_progress`.
- `sync_api.dart` — `GET /sync` et `GET /sync/{collection}`, sur le `Dio`
  d'`ApiClient`. Un **404** devient `UnknownSyncCollection`.
- `sync_engine.dart` — la boucle. `sync_scheduler.dart` — les déclencheurs.

**Six règles, en plus des six du magasin :**
1. **Référentiels avant contenu.** Ça ne ferme pas la fenêtre où un enseignement
   arrive sans son intervenant (la jointure de lecture reste tolérante), ça
   supprime le cas fréquent : la toute première synchronisation.
2. **La `scope_version` est retenue en mémoire pendant tout le cycle et
   persistée en dernier** (ADR-0027). Une valeur pour toutes les collections.
   Persistée trop tôt, elle éteint un resync qui n'a pas eu lieu — et le
   manifeste ne le redemandera **jamais**. Un cycle interrompu ne persiste rien.
3. **« Rétractation ou ligne », décidé avant toute construction d'objet** :
   `deletedAt` non nul → la ligne quitte le magasin, rien n'est désérialisé.
4. **Le client n'efface jamais de sa propre initiative** une ligne d'une
   collection répliquée — `playback_progress` en particulier, qui **est** une
   collection synchronisée et non de l'état local. Depuis #43 la règle est
   **vérifiée** et non plus structurelle : `test/sync/sync_engine_test.dart`
   prouve qu'une rétractation d'enseignement laisse la progression intacte, et
   un garde-fou de source interdit `delete(playbackProgress)`,
   `into(playbackProgress)` et `update(playbackProgress)` dans tout `lib/`.
5. **Un resync forcé se lit dans un `200`** (`full_resync` / `full_resync_required`),
   jamais dans une erreur — et il **remplace**, il ne purge pas d'abord.
6. **Un `404` de collection n'est pas fatal** : collection sautée, synchro
   poursuivie.

**Le corollaire de la règle 6 est le piège le plus coûteux du moteur, et il a
déjà mordu.** Le `404` est la *seule* erreur non fatale : toute autre remonte et
**coupe le cycle**, donc toutes les collections rangées **après** la fautive
dans `synced_collection.dart`. Et `SyncScheduler` la range dans `lastFailure`
que personne ne lit — l'application reste muette, exactement comme un magasin
vide. Un désaccord d'une seule clé sur une seule ligne suffit : `status_backgrounds.label`
était lu en `_text` alors que le serveur le sert en `jsonb` (ADR-0023), ce qui a
tenu **six collections** hors du magasin — documents légaux, intervenants,
branches, enseignements, rassemblements, annonces — sans un seul message
d'erreur, et sans qu'aucun test rougisse : le fixture portait la mauvaise forme.
Deux réflexes en découlent. D'abord, devant un écran vide, **regarder
`SyncScheduler.lastFailure` avant de soupçonner la donnée** — un `print` dans
son `catch` donne la réponse en une exécution. Ensuite, **un fixture de
`sync_fixtures.dart` se relève dans le code du serveur, jamais dans le code du
client** : un fixture qui recopie l'hypothèse du client ne teste plus rien
(l'en-tête du fichier donne la source de chaque forme, colonne par colonne).

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
  - `legal_providers.dart` : `legalRepositoryProvider` (magasin avec backend,
    double en mémoire sinon) et `legalDocumentProvider.family` (par genre) —
    `StreamProvider`, `retry: _noAutomaticRetry`. **Le repli de langue n'y
    passe pas par `pick`** : voir la section i18n plus bas. Depuis #56 s'y
    ajoutent `legalAcceptanceRecorderProvider` (le seul de ce domaine qui parle
    au réseau), `mandatoryLegalVersionsProvider` et
    `pendingLegalAcceptancesProvider` — la **lecture synchrone** dont vit la
    barrière, voir plus bas.
  - `locale_providers.dart` : `contentLocaleProvider` — la langue de repli des
    **contenus** servis par le back, distincte de celle de l'interface.
  - `sync_providers.dart` : `appDatabaseProvider` (à surcharger par une base en
    mémoire dans les tests), `syncDaoProvider`, `mediathequeDaoProvider`,
    `syncApiProvider`, `syncEngineProvider`, `syncSchedulerProvider`,
    `gatheringDaoProvider`, `announcementDaoProvider`, `playbackDaoProvider`,
    `legalDaoProvider`, `seasonDaoProvider`, `vocabularyDaoProvider`,
    `authChannelsDaoProvider`, `pullToRefreshProvider`.
    Les trois DAO de lecture sont lus par les trois repositories de magasin.
    **Les trois déclencheurs d'ADR-0017 sont câblés** : `app.dart` appelle
    `SyncScheduler.start()` au premier frame sous `AppEnv.useBackend` (et c'est ce même appel qui abonne le planificateur au
    cycle de vie, donc au **retour au premier plan**) ; la médiathèque passe
    `pullToRefreshProvider` à son `RefreshIndicator`. Jamais de polling.
    `test/state/cold_start_test.dart` parcourt la chaîne entière — sans lui,
    une rupture entre synchronisation et magasin donnerait une application
    **muette**, pas une erreur : un magasin vide ne se plaint pas.
  - `app_version_providers.dart` : `appVersionReaderProvider` (à surcharger par
    un `FixedAppVersionReader` dans les tests d'écran) et `appVersionProvider`
    — `FutureProvider`, `retry: _noAutomaticRetry`. Voir « À propos ».
  - `theme_provider.dart` : `themePreferencesProvider` (lecture du magasin),
    `nowProvider` (**l'horloge, injectable** — sans elle la règle horaire serait
    intestable), `themeModeProvider` (le `ThemeMode` résolu) et
    `isDarkModeActive`. `settingsDaoProvider` y vit aussi : les réglages
    d'apparence et les réglages média partagent la même table.

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

### Le fond de l'application — une saison, un décor, un fichier sur le disque

Les deux lecteurs — enseignement et direct — **et l'écran de démarrage** posent
le **même** fond : le « fond vertical (téléphone) » de la saison active, déposé
au portail, celui-là même que le site public sert aux écrans étroits. Ce n'est
pas un fond par contenu : un direct n'a pas de fiche où en déposer un.

**La cascade a cinq étages**, et les quatre premiers sont écrits une fois, dans
`seasonBackgroundUrlProvider` :

1. le **vertical de la saison** du jour ;
2. son **paysage**, si elle n'a pas déposé de vertical ;
3. le **vertical du décor** par défaut (`decor`, le singleton des réglages de la
   vitrine), hors saison ;
4. son **paysage** ;
5. l'image du dépôt (`kAppBackgroundAsset`, `assets/images/live_bg.png`) — le
   cinquième étage vit à **deux** endroits, parce qu'il y a deux chemins :
   `ContentPlayerView._background()` pour les lecteurs (par
   `fallbackBackgroundAsset`, que seul l'écran du direct fournit aujourd'hui),
   et `startupBackgroundProvider` pour l'écran de démarrage. C'est la même
   image, et c'est aussi celle du splash **natif** (voir juste après).

Rien des cinq → l'aplat de couleur du contenu, exactement comme avant. C'est la
cascade du site public, à ceci près que son premier étage à lui est le fond de
l'enseignement — que le mobile ne sert pas, parce que le direct n'aurait rien à
y mettre. **Le paysage en secours plutôt que l'étage suivant** : une image mal
cadrée reste plus informative qu'un fond qui n'est pas celui de la saison en
cours.

#### L'écran de démarrage lit le disque, jamais la base

Il dure le temps de résoudre une session. Y déclencher une lecture Drift ou une
descente d'image donnerait un fond qui apparaît après que l'écran a disparu —
ou, pire, qui retarde l'ouverture. La lecture est donc remontée dans `main()`
(`readStartupBackground`), **avant `runApp`**, et passée en surcharge de
`startupCachedBackgroundProvider` : exactement le motif de `readStartupVault`.

Elle ne connaît pas l'adresse du fond et n'en a pas besoin : le dossier de cache
ne contient **qu'un** fichier — la purge s'en charge —, et `cachedFile()` le
rend sans réseau ni magasin. **Le premier lancement n'a donc pas le décor du
portail**, et c'est le contrat : on descend pendant que l'application tourne, on
s'en sert à l'ouverture suivante.

**Deux providers, et c'est la cascade qui l'exige** (#86) :
`startupCachedBackgroundProvider` porte ce que le disque avait (`null` au
premier lancement), `startupBackgroundProvider` applique le dernier étage —
`?? const AssetImage(kAppBackgroundAsset)`. ⚠️ **L'ordre ne s'inverse pas** :
ce que le portail a réglé passe devant, l'image du dépôt ne paraît que quand
rien n'est réglé. L'inverser annulerait en silence un décor déposé, et ça
s'afficherait parfaitement.

L'écran n'a donc **plus de cas « sans image »** : le dégradé de marque n'y est
plus qu'un repli d'`errorBuilder`, et le **voile sombre** est peint dans tous
les cas. Sans lui, un fond clair rendrait l'emblème blanc, le nom de l'église et
le témoin de chargement illisibles — et ça ne se verrait qu'avec ce fond-là,
c'est-à-dire un jour, chez quelqu'un d'autre.

#### Le démarrage **natif** porte la même image (#86)

`android/app/src/main/res/drawable{,-v21}/launch_background.xml` et le
`LaunchScreen.storyboard` d'iOS peignent `live_bg.png`, celle-là même que
l'écran Dart pose juste après. Les deux étages portent la même image **exprès** :
le fidèle en voit une seule, du premier pixel jusqu'à l'accueil. Le blanc uni du
gabarit d'origine faisait un clignotement qui donnait l'application pour lente à
ouvrir.

Côté Android, le bitmap est en `drawable-nodpi/launch_image.png` (la définition
native du décor) et posé en `android:gravity="fill"` : une image unique ne peut
pas couvrir sans déformer les deux formats du parc, et toute autre gravité
laisserait des bandes. Le socle `@color/launch_background` est le bleu nuit du
décor, pas le blanc du gabarit — c'est lui qu'on voit le temps du décodage.

⚠️ **Le splash natif est un fichier de ressources, pas un asset Flutter** : la
même image vit donc deux fois dans le binaire, et un changement de décor se
répercute par `make icons`.

Cinq points qui se ratent en silence :

1. **C'est le téléphone qui élit la saison du jour**, pas le serveur
   (`SeasonDao.seasonOfDay`). Lui seul sait quel jour on est **hors ligne**, et
   lui seul peut basculer à minuit sans réseau. Le serveur sert la table
   entière, saisons passées et futures comprises ; filtrer côté serveur
   rendrait le décor dépendant du réseau.
2. **Les deux bornes sont des chaînes `YYYY-MM-DD`**, comparées comme des
   chaînes — la règle 2 de `sync_rows.dart`, celle de `recordedAt`. En ISO,
   l'ordre lexicographique *est* l'ordre chronologique ; convertir en
   `DateTime` poserait un instant, donc un fuseau, donc un décalage d'un jour.
   Les deux bornes sont **incluses**.
3. **Le décor par défaut n'est pas une saison sans dates.** C'est une
   collection à part (`decor`, une seule ligne), et la tentation de le servir
   comme une saison couvrant tous les jours ferait dépendre la cascade d'un
   départage d'identifiants au lieu d'une règle écrite. Une ligne dont les deux
   adresses sont nulles **n'est pas une absence** : c'est « le portail n'a
   déposé aucun décor », ce qui autorise à retomber tout de suite sur l'image du
   dépôt au lieu d'attendre une ligne qui ne viendra pas.
4. **Le fond est descendu une fois, puis lu sur le disque**
   (`SeasonBackgroundStore`). Le cache de `NetworkImage` est *en mémoire* : il
   repartirait sur le réseau à chaque lancement. Un cache HTTP générique
   revaliderait au bout de sept jours, ce qui est faux ici — l'adresse d'un
   fond **change quand le fond change**, elle est donc déjà sa propre version.
   Le fichier vit dans le dossier de **support**, jamais dans les documents :
   un cache n'a rien à faire dans la sauvegarde iCloud d'un fidèle.
5. **`ensureLocal` ne lève jamais** — réseau absent, disque plein, canal de
   plugin inexistant sous `flutter test` : tout rend `null`. Un décor n'est pas
   une donnée. C'est aussi ce qui permet aux tests d'écran de monter le lecteur
   sans rien surcharger.
6. **Le téléchargement passe par un `Dio` nu**, jamais celui d'`ApiClient` : un
   fond est un fichier public de `/uploads/`. Y envoyer le jeton du porteur, et
   faire traverser la réponse à l'intercepteur de 401, donnerait à un
   téléchargement d'image le pouvoir de déconnecter quelqu'un.

⚠️ **`seasons` n'a pas de tombstone**, et la limite se paie côté client : une
saison supprimée au portail continue d'habiller les appareils qui l'avaient
déjà reçue, jusqu'à sa date de fin. `SeasonDao` en borne le coût — à égalité de
dates, **le plus grand `id` gagne**, donc la saison *recréée* l'emporte sur
celle qu'on venait d'effacer, ce qui est le geste qui suit une suppression par
erreur.

### La reprise de lecture (#43) — **deux tables, et c'est délibéré**

Où en était un fidèle dans un enseignement. Contrat serveur : écriture par
`POST /teachings/:teachingId/progress` (corps **camelCase**
`{ id, positionSeconds, completed? }`, `id` = **UUIDv7 fabriqué par le
client**), lecture **uniquement** par `GET /sync/playback_progress` — il n'y a
**aucun endpoint REST de lecture**, on ne peut pas demander « où en étais-je ? ».

**Deux tables, et n'en faire qu'une serait la faute :**

- **`playback_progress`** — collection **répliquée** (`private`, la première de
  ce registre), remplie *uniquement* par la synchronisation. C'est elle qui
  donne la reprise **multi-appareils** et **après réinstallation**. L'application
  n'y écrit **jamais**.
- **`local_playback_positions`** — **locale seule**, jamais synchronisée, écrite
  en continu par le lecteur. C'est la seule qui marche en avion et qui survit à
  une application tuée par le système.

Suivre à la lettre le précédent du composeur d'annonces (« le réseau ne peint
jamais, le flux delta ramène la ligne ») donnerait une position en retard de
plusieurs secondes sur une donnée qui bouge toutes les dix, et **rien du tout
hors ligne**. Les fondre ferait écrire l'application dans une collection
répliquée — la règle à ne pas tordre. `PlaybackDao.resumeFor` départage : **la
plus récente gagne**, jamais la plus grande position (ça renverrait à la fin
quelqu'un qui réécoute depuis le début). L'**identifiant**, lui, ne se départage
pas à l'horloge : dès que le serveur connaît une ligne, c'est son `id` qui
repart — c'est ce qui fait de chaque rapport suivant un rejeu idempotent.

**Cinq déclencheurs, jamais un sondage** (`PlaybackProgressRecorder`) : pause,
sortie de l'écran, complétion, ~30 s de temps **joué** *et* plus de 5 s de
déplacement, et `AppLifecycleState.paused` — **sans arrêter la lecture**, c'est
le cas le plus fréquent (le fidèle éteint son écran, il ne quitte pas). Le temps
joué se mesure sur l'avancée de la tête de lecture : aucun `Timer`, l'horloge
appartient au lecteur. **L'écriture locale est continue et gratuite ; seul
l'appel réseau est espacé.**

**Le rapport est MUET.** Hors ligne, 401, 409, 5xx : rien ne s'affiche, rien ne
bloque l'écoute, l'échec se retente au déclencheur suivant. `report` rend un
booléen — *parti* / *pas parti* — et rien de plus : de quoi retenter, jamais de
quoi composer une phrase à l'écran. Une progression perdue est un désagrément ;
une erreur affichée pendant un prêche est une panne.

**Le seuil de « terminé » est une décision _application_** : le serveur n'a de
durée nulle part et n'a donc pas de dénominateur. `kPlaybackCompletionSlack`
(**30 s**, constante nommée à un seul endroit, **valeur à confirmer**) —
`completed` si `position ≥ durée − 30 s`, **ou** sur l'état terminal du lecteur,
et **jamais** si la durée est inconnue, nulle ou plus courte que le seuil. En
HLS sur iOS, `duration` est peu fiable et souvent nulle : mieux vaut
sous-déclarer que faire disparaître de la liste « à reprendre » un prêche dont
quelqu'un n'a entendu que dix minutes. Une fois `completed`, la position n'est
plus **rapportée** — elle continue d'être tenue localement, pour une réécoute.

Deux points **encore ouverts** : le seuil de 30 s n'a pas été validé par le
produit ; et qu'un **rassemblement** rapporte par la même route (`teachings` et
`gatherings` sont la même table serveur, discriminée par `family`) est démontré
par le code serveur mais **prouvé par aucun test serveur** — à faire épingler
(PRD `miracle-house-server#151`).

### Les réglages média (`app_settings`, schéma v7)
Trois usages réglables — écoute, direct, téléchargement — sur quatre paliers :
`auto` (défaut), `low` 64k, `mid` 128k, `high` 192k. Les trois débits sont
**recopiés de l'échelle du transcodeur** (`streaming-service/app/transcodes/
support/hls.ts`) ; en ajouter un ici sans l'ajouter là-bas donnerait un plafond
qu'aucun rendu ne peut satisfaire.

**Ce que le panneau montre est plus large que ce qu'il fait**, et c'est un choix
produit explicite, pas un oubli :

| réglage | effet réel |
| --- | --- |
| écoute, iOS | ✅ `AVPlayer.preferredPeakBitRate` |
| écoute, web | ✅ `hls.js`, `autoLevelCapping` |
| écoute, **Android** | ✅ **par l'URL**, pas par le plafond — voir ci-dessous |
| direct | ❌ `LiveScreen` n'a pas de lecteur |
| téléchargement | ❌ n'existe pas, et c'est un **refus documenté** (`docs/mediatheque-en-ligne.md` §2) |

Les trois se règlent et s'enregistrent quand même : le jour où la fonction
existera, la préférence sera déjà là.

**Deux leviers, et le second existe pour Android.** `setPreferredPeakBitRate`
est reçu et **ignoré** par `just_audio` côté Android (`AudioPlayer.java`,
`case "setPreferredPeakBitRate"` → `success` vide) ; ExoPlayer saurait le faire,
le greffon ne l'expose pas. Le contournement ne dépend d'aucun greffon : le
transcodeur écrit, à côté de `master.m3u8`, **une liste de lecture par rendu**
(`low/index.m3u8`, `mid/index.m3u8`, `high/index.m3u8`), et `RustfsStorage`
publie tout le dossier. Charger l'une d'elles **au lieu** du master, c'est
choisir la qualité par l'URL — ce qui marche sur les trois plateformes.

- **palier explicite** → URL de rendu (`variantPlaylistUrl`), partout et quel
  que soit le réseau : l'avoir choisi est une décision qu'on ne corrige pas dans
  le dos de qui l'a prise ;
- **`auto` en wifi** → master, donc adaptation libre — c'est ce que ce mode
  promet ;
- **`auto` en données mobiles** → rendu `low` **par l'URL**, ce qui donne à
  Android l'économie que son plafond ignoré ne sait pas lui donner. Sur iOS et
  le web le plafond fait déjà le travail et ce rendu ne le contredit pas.

**Le seul cas qu'Android ne couvre toujours pas** : un prêche ouvert en wifi et
poursuivi en marchant. L'URL se choisit à l'ouverture ; suivre la bascule
demanderait de rouvrir la source, donc de couper le son. Sur iOS et le web, le
plafond s'en charge sans coupure.

`MediaQuality.key` reprend **mot pour mot** les noms de `RENDITIONS[].name` du
serveur : les désaccorder donnerait un 404. Et la dérivation **échoue du bon
côté** — une URL qui ne finit pas par `/master.m3u8` est rendue intacte, donc le
pire cas est « pas de bridage », jamais « plus de lecture ».

Quatre points qui se ratent en silence :

1. **La table naît vide et le reste** jusqu'au premier choix. L'absence de ligne
   *est* le défaut : une valeur écrite d'office serait indiscernable d'une
   décision du fidèle, et changer le défaut plus tard ne toucherait plus
   personne.
2. **Le mode automatique est asymétrique.** Le plafond **descend** dès la
   bascule vers les données mobiles — l'effet arrive au segment suivant (~6 s),
   sans réouverture donc sans coupure. Il **ne remonte pas** au retour du wifi
   tant que le contenu joue : remonter coûterait une remise en tampon au milieu
   d'un prêche. Le cliquet vit dans `StreamingBitrateCap`, et
   `ContentPlayerView` le relâche à l'ouverture du contenu suivant — l'oublier
   briderait à vie quelqu'un qui a écouté une fois dehors.
3. **Un palier choisi s'applique partout**, réseau compris. Le corriger dans le
   dos de qui l'a choisi serait le pire ressenti possible pour un réglage.
4. **Le plafond se repose après chaque `load`** : les implémentations qui
   rouvrent une source l'oublient en même temps qu'elles la remplacent.
5. **Il s'applique depuis `BitrateCapController`, câblé dans `main.dart`, et
   jamais depuis `ContentPlayerView`.** Ce n'est pas un choix esthétique : c'est
   ce qui a été essayé d'abord, et dès que l'écran de lecture touchait la chaîne
   des réglages, son montage sous `flutter test` se bloquait — processus à
   **0 % de CPU pendant dix minutes**, donc une attente de ressource et non une
   boucle. Le poser dans `main()` le sort du chemin des tests d'écran, que le
   harnais n'exécute jamais. Cela ne déroge qu'en apparence à
   « `ContentPlayerView` est le seul endroit qui pilote le lecteur » : cette
   règle vise le **transport** — jouer, pause, déplacement, arrêt — pour que
   deux endroits ne se disputent pas la lecture ; un plafond ne fait que
   contraindre la qualité, sans effet audible immédiat.

**Ce n'est pas une collection synchronisée** : le serveur ne la sert pas, ne la
reçoit pas. Une préférence de débit décrit *le forfait de cet appareil-ci*, pas
la personne. Elle vit donc dans le fichier de base — et part avec lui à la
suppression de compte, sans qu'on ait rien à écrire.

### L'apparence — quatre positions, dont une **maison**
`Clair · Système · Auto · Sombre`, persistées dans `app_settings` (aucune
migration : la table est clé/valeur, c'est pour cela qu'elle l'est). Le thème se
perdait à chaque lancement avant cela — `themeModeProvider` n'était qu'un état
en mémoire.

**Le réglage vit dans une feuille modale** (`showThemeSheet`), ouverte par
l'icône `brightness_6` de l'en-tête du Profil — et **là seulement**. Trois
conséquences à connaître :

- **L'icône est neutre, jamais un soleil ou une lune.** Elle *ouvre un panneau*,
  elle ne bascule pas : afficher l'état courant sur un bouton qui ne le change
  pas ferait presser la lune en s'attendant à passer en clair, et en mode `Auto`
  elle donnerait à croire qu'on a choisi « Sombre ».
- **La feuille ne se ferme pas quand on choisit.** Elle vit dans le
  `MaterialApp`, donc changer le mode la repeint elle-même : on compare les
  quatre positions sous ses doigts. Se refermer obligerait à rouvrir pour faire
  ce qu'on était venu faire.
- **Aucun engrenage interne.** Il n'existait que tant que ce réglage occupait une
  ligne de liste, où deux heures de plus ne tenaient pas. En feuille, les heures
  s'affichent dès que `Auto` est choisi.

Le coût assumé : un réglage rangé derrière une icône d'en-tête se trouve moins
bien qu'une ligne de liste qu'on parcourt. `brightness_6` est ce qui limite le
risque — c'est le glyphe que les gens associent à ce réglage.

**`Système` et `Auto` se ressemblent et ne font pas la même chose**, et c'est le
piège du réglage : `Système` suit le téléphone, `Auto` suit une **règle horaire
de l'application** que le téléphone ignore. Les deux peuvent donc se contredire
— un téléphone jamais programmé restera clair la nuit sous `Système`. C'est
pourquoi le résumé « Sombre de 19:00 à 06:00 » s'affiche sous le sélecteur en
mode `Auto` : sans lui, rien ne les distingue à l'œil.

Quatre points qui se ratent en silence :

1. **La règle accepte les deux sens.** « Sombre entre `darkFrom` et
   `lightFrom` », en passant minuit si besoin : `19:00 → 06:00` est le cas
   courant, `06:00 → 19:00` est un réglage **valide** pour qui veille la nuit.
   Ce n'est pas un cas particulier, c'est la même comparaison retournée. Deux
   heures **identiques** donnent un intervalle vide, donc toujours clair —
   `Sombre` existe déjà en un geste pour l'autre besoin.
2. **Une minuterie unique, armée sur la prochaine bascule**, jamais un sondage.
   Elle se réveille une fois par bascule et se réarme ; rien ne tourne entre
   deux. Elle porte **une seconde de marge** : sans elle, un réveil au dernier
   instant *avant* l'heure ne verrait rien changer et se réarmerait sur un délai
   nul — une boucle serrée jusqu'à la seconde suivante.
3. **Doublée d'une réévaluation au retour au premier plan.** Ce n'est pas une
   ceinture de plus : un téléphone en veille ne garantit rien à ses minuteries,
   et le cas visé est exactement celui-là — l'app ouverte pendant le culte du
   soir, l'écran éteint puis rallumé.
4. **`themePreferencesProvider` est surchargé par `pumpScreen`.** Il lit un flux
   Drift, et l'onglet Profil le lit : tout test montant la coquille ouvrirait
   donc ce flux. Voir le paragraphe sur les flux Drift sous horloge factice, qui
   a déjà coûté deux enquêtes.

### La suppression de compte (`DELETE /auth/me`)
Exigence d'entrée à l'App Store (5.1.1(v)) : une app qui crée des comptes doit
permettre de les supprimer **dans l'app**. Écran dédié `/profile/delete`, jamais
un dialogue — la déconnexion se confirme deux lignes plus haut dans la même
liste, et donner la même apparence aux deux ferait de la ressemblance un piège.

**L'ordre serveur-puis-local n'est pas négociable** (`AuthController.deleteAccount`) :
une panne réseau laisse le compte vivant et l'écran garde la main. Vider le
téléphone d'abord laisserait quelqu'un convaincu d'avoir disparu alors qu'il est
toujours inscrit.

**Un `401` compte comme un succès** : le serveur révoque tous les tokens dans sa
transaction, et il n'existe pas d'état « déjà supprimé » à distinguer.

**`AppDatabase.eraseEverything()` est la contrepartie locale, et elle est
obligatoire.** `signOut()` n'a jamais touché au magasin — défendable pour une
déconnexion, faux ici : le serveur a effacé la progression d'écoute, il
n'enverra donc **jamais** de rétraction pour la retirer d'ici, et l'email libéré
permet de créer un compte **neuf** dans la minute sur ce téléphone-ci. Sans cet
effacement, la personne suivante reprendrait un prêche là où la précédente
s'était arrêtée. La méthode boucle sur `allTables` — elle ne **nomme** donc pas
`playbackProgress`, ce que le garde-fou de source interdit — et n'efface pas le
fichier : sur le web il n'y en a pas.

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
local), `noMedia` (publié, fichier pas encore attaché), `offlineMedia`
(appareil hors ligne — le média existe, mais **la médiathèque s'écoute en ligne
seulement**, `docs/mediatheque-en-ligne.md` ; il n'y a pas de téléchargement, et
son libellé ne doit **jamais** en promettre un). `ContentAbsence` porte les
quatre textes,
`ContentAbsenceView` les rend toutes — **ne pas écrire un écran d'absence de
plus**, ajouter une variante.

Partis pris valables pour les quatre : on **n'éjecte pas** l'utilisateur de
l'écran qu'il avait ouvert (il croirait à un bug), on **ne fige pas** la
dernière copie connue (ça ment), la lecture en cours **s'arrête**, et il y a
toujours une porte de sortie.

Deux sont câblées, toutes deux dans `ContentPlayerView` : `retracted` quand
l'identifiant ne résout plus rien, et `noMedia` quand `playlistUrl` est nul
(#41). **`noMedia` n'est pas une branche défensive** : la portée de publication
du serveur ne teste aujourd'hui que `published_at` (ADR-0034 vit sur une branche
serveur non fusionnée), un contenu publié sans média est donc un état courant.
Elle est rendue **avec la couleur du contenu**, là où `retracted` retombe sur le
bleu de marque — le contenu existe, son habillage aussi ; seul son
enregistrement manque. Et **jamais `retracted` à sa place** : « pas encore
disponible » n'est pas « contenu retiré », et confondre les deux ferait croire à
une suppression.

À ne pas confondre avec les états de liste : `AppErrorState` (teinté,
« Réessayer ») dit « je n'ai pas pu charger » ; `AppEmptyState` est une carte
dans une liste. Une absence, elle, occupe l'écran entier.

### Navigation principale
`HomeShell` = `IndexedStack` de 4 onglets **Accueil · Annonces · Communauté ·
Bible** + `BottomAppBar` à encoche + **FAB central** (→ médiathèque, route
poussée). Le FAB n'est PAS un onglet.

**Le profil a quitté la barre** : c'est une route **poussée** (`/profile`), donc
la barre du bas disparaît et une flèche de retour ramène à l'accueil — au lieu
d'un onglet dont on ne sortait que par un autre onglet. L'onglet libéré est
devenu **Bible**, avec un écran provisoire.

⚠️ **L'index d'onglet reste un numéro nu**, et c'est un contrat partagé :
`AppDrawerMenu.homeTab`, `AppBottomNav.currentIndex` et
`test/screens/drawer_menu_test.dart` (« Accueil » depuis l'onglet **3**) en
dépendent. Une barre à géométrie variable — un onglet qui disparaîtrait selon
l'état de session — casserait ce vocabulaire. C'est l'une des raisons pour
lesquelles l'onglet Communauté **reste visible** en mode invité (voir plus bas).

### Le mode invité (issue #398 côté serveur, ADR-0040/0041)

L'application **ne s'ouvre plus sur l'écran d'authentification**. On peut venir
uniquement pour écouter les enseignements.

#### Deux régimes de démarrage, et le coffre décide

`AuthController.build()` n'est pas asynchrone : il **ne peut pas** lire le
coffre. La lecture est donc remontée dans `main()` (`readStartupVault`), avant
`runApp`, et passée en surcharge de provider.

- **Coffre vide, ou portant un jeton d'appareil seul** ⇒ l'état part de `guest`,
  et la garde réécrit `/` en `/home` **à sa première évaluation** : le splash ne
  se peint pas d'une seule image. C'est la différence entre « pas de splash » et
  « un splash très court », et c'était l'exigence du client.
- **Coffre portant un jeton de membre** — ou sans marqueur, une installation
  d'avant cette version ⇒ `unknown`, splash, résolution : **à la lettre comme
  avant**. Contrainte du client, littérale : « quand la personne s'est déjà
  connectée, tout se passe exactement comme présentement ».

Corollaire : sans session de membre, **pas de `GET /auth/me` au démarrage**.
Sinon la requête partirait avec le jeton d'appareil, prendrait un 401,
déclencherait un renouvellement silencieux et un rejeu — deux requêtes par
ouverture pour apprendre ce qu'on savait déjà.

#### `AuthStatus.guest` est un **renommage**, pas un ajout

`unauthenticated` **n'existe plus**. C'était le point de décision : ajouter
`guest` à côté aurait laissé vivre un état qui veut dire « pas de compte, donc
rien n'est permis », et le compilateur n'aurait rien attrapé. Ne dérive **jamais**
« invité » de `!isAuthenticated` : c'est vrai aussi pendant `unknown`, donc
pendant le démarrage. `isGuest` est un getter distinct, exprès.

#### La garde est **inversée** : public par défaut

`app_router.dart` porte `memberOnlyRoutes` (une courte liste) et `redirectFor()`,
fonction pure. Tout le reste est ouvert, et un écran réservé ramène à **l'accueil
invité**, jamais vers `/auth` — y renvoyer serait remettre le verrou par la porte
de service.

⚠️ **Les clés sont des motifs de route** (`GoRouterState.fullPath`), jamais des
chemins concrets : `/announcement/:id/edit` ne se reconnaîtrait pas dans
`/announcement/42/edit`, et la garde laisserait passer exactement l'écran qu'elle
croit fermer.

#### Ce qu'une garde de route ne peut pas fermer

**Les onglets ne sont pas des routes.** Le hub Communauté est fermé par la
coquille elle-même (`_selectTab` → `requireSession`), et l'onglet **reste
visible** : un onglet retiré est une fermeture invisible, et personne ne réclame
un écran qu'il n'a jamais vu. La barre devient l'endroit où l'on découvre qu'un
compte existe.

#### `requireSession()` — le geste, pas l'écran

Extension sur `WidgetRef` (`lib/state/session_gate.dart`). Mémorise l'intention,
**pousse** le parcours d'authentification, et **rejoue le geste** au succès.

Trois pièges, tous payés une fois :

1. **Une seule ligne d'`app.dart` tient le mécanisme** :
   `ref.listenManual(sessionGateProvider, …)`. Riverpod met en pause les
   abonnements d'un provider que personne n'écoute — sans elle, le geste serait
   mis de côté et **jamais repris, sans erreur ni trace**.
2. **La reprise est reportée d'une image.** L'écran du code navigue dès que la
   vérification lui rend la main, dans le même tour de boucle que le changement
   d'état : naviguer tout de suite ferait perdre la course.
3. **Lis la `GoRouter` au moment de l'appui** (`ref.read(routerProvider)`),
   jamais un `BuildContext` capturé : après un détour par la connexion, il n'a
   plus rien à garantir. Un test de source le verrouille.

**Application tuée ⇒ l'intention est perdue, et c'est la décision** : un geste
rejoué après un redémarrage agirait dans le dos de la personne.

#### Deux gestes, deux destinations — ne les unifie pas

- **Déconnexion explicite** ⇒ accueil invité, **rien d'effacé** : ni les
  téléchargements, ni la progression, qui redevient locale.
- **Session expirée (401 sur un jeton de membre)** ⇒ **écran de connexion**,
  comme avant. La personne n'a rien choisi, et l'éjection lui *dit* quelque chose
  que le silence ne dit pas.

C'est une décision explicite du client. Ce n'est pas une incohérence à lisser.

#### Le porteur d'appareil (`lib/data/devices/`)

`POST /devices/anonymous` échange un UUID d'appareil contre un jeton opaque, qui
porte **toutes** les requêtes, invité comme membre. Le coffre porte **un seul
jeton à la fois**, plus un **marqueur de nature** (`auth_token_kind`).

⚠️ **L'intercepteur 401 juge l'estampille posée sur la requête, jamais le coffre
au retour** : une connexion qui aboutit pendant qu'une requête d'invité est en
vol ferait juger cette requête sur un coffre qui n'est plus le sien.

Les deux erreurs n'ont pas le même coût, et le code le dit : appareil pris pour
membre = éjection visible et rattrapable ; **membre pris pour appareil = jeton de
membre écrasé en silence**, quelqu'un déconnecté sans le savoir. D'où une lecture
prudente (tout ce qui n'est pas explicitement `device` vaut `member`) et un ordre
d'écriture délibéré — le coffre n'a pas de transaction.

**L'identifiant d'appareil est falsifiable** : il sert à compter et à révoquer
côté serveur, jamais à autoriser.

#### La préférence d'assemblée, et le contrat que le serveur ne tient pas

`GET /sync` accepte un `branch_id` : filtre d'affichage, **jamais** une
autorisation — une branche inconnue rend 422, jamais 403.

⚠️ **Quand la préférence change, c'est le client qui remet ses curseurs à zéro**,
sur les quatre collections de `kBranchScopedCollections`. Le serveur ne peut pas
détecter une préférence changée sans nettoyage, et **rien ne le rattrapera**.

Et ce n'est **pas** un effacement de curseur : effacer fait re-tirer, donc
ré-écrire, mais n'efface **rien** — les lignes sorties du périmètre resteraient.
On pose le **jeton de remplacement**, et c'est la transaction finale qui balaie.

**La préférence n'est pas observable en direct** : `watch()` a été retiré du
magasin et du DAO. Un `QueryStream` Drift, à son annulation, programme un `Timer`
qui reste pendant sous horloge factice — et fige les tests d'écran. Si un futur
écran a besoin du direct, il le rétablira **en sachant** qu'il devra surcharger
le provider dans ses tests.

#### La mesure d'écoute est séparée de la reprise de lecture

`POST /teachings/:id/plays`, au **seuil de 30 s de temps joué**, une fois par
ouverture. Un déplacement n'est **pas** une écoute (au-delà de 2 s d'écart entre
deux poussées, l'avancée est un saut) — c'est l'inverse exact du rapport de
progression, qui compte délibérément un saut comme du temps joué.

Hors ligne, l'événement est **mis en file** (50 entrées, 7 jours) : le
téléchargement existe *pour* écouter sans réseau, et la population qui télécharge
est celle dont le réseau est le plus mauvais. Contrepartie : la route ne prend
aucun horodatage, donc une écoute de mardi remise en ligne jeudi compte pour
jeudi.

C'est de la **télémétrie** : un échec ne se voit jamais et n'interrompt rien.

#### La fusion de progression à la connexion

La progression accumulée en invité part vers le compte, et **la position la plus
avancée gagne**.

⚠️ **Le serveur arbitre désormais, et cet arbitrage-ci reste quand même
nécessaire.** Ce paragraphe disait l'inverse, et c'était vrai au moment où il a
été écrit : `upsertOwned` (ADR-0018) réécrivait **tout champ qui diffère**, donc
une position inférieure était écrite, et `completed` pouvait revenir à faux.
`server-portal#421` a fermé les deux — `position_seconds` garde le maximum,
`completed` est collant — et `server-portal#422` a fermé le trou qui restait,
la course des **deux premières** écritures simultanées, qui rendait 500.

Ce qui **ne change pas** : on **lit** ce que le compte porte
(`GET /sync/playback_progress`) avant de pousser, et **si le cycle échoue, rien
ne part**. Deux raisons, dont une seule tenait à la lacune serveur :

- la fusion **relève aussi la ligne locale** quand le compte est devant. C'est
  la raison qui demeure, et elle est côté client par nature — sans elle,
  l'enregistreur rapporterait ensuite une position en retard, que le serveur
  ignorerait désormais, mais qui laisserait l'appareil afficher un recul que le
  compte ne porte pas ;
- pousser à l'aveugle n'abîme plus la donnée du compte. **Ne pas en conclure que
  la lecture préalable est devenue gratuite à retirer** : la première raison
  suffit à la garder, et la retirer se ferait sans qu'aucun test ne rougisse.

La règle diffère de celle de `resumeFor`, qui prend **la plus récente** : c'est
pourquoi la fusion **relève aussi la ligne locale** quand le compte est devant —
sans quoi l'enregistreur rapporterait ensuite une position en retard qui
écraserait le compte.

#### Le bandeau légal du premier lancement

Non bloquant, invités seulement, **une seule fois** (`legal_notice_seen` dans
`app_settings`). Il existe parce que l'application pose un **identifiant
d'appareil** — donnée personnelle — dès avant tout compte, et qu'un invité ne
voit jamais la barrière de consentement. Ce n'est pas une décoration.

Il dit **« j'ai compris », pas « j'accepte »** : rien n'est envoyé ni tracé, et
prétendre recueillir un consentement ici serait faux.

#### Le menu latéral (#54) — `flutter_zoom_drawer`, quatre entrées
Spécification de rendu : `docs/documents-legaux.md` §1. Six points qui se
ratent en silence :

1. **Le `ZoomDrawer` se construit dans `HomeShell.build()`**, jamais dans la
   route `/home` : c'est ce qui garde `_index` en `State` **local**. Le menu le
   change par un simple rappel — remonter l'onglet courant dans un provider
   global est interdit (« Riverpod = état **partagé** »).
2. **Le `mainScreen` est le `Scaffold` entier** : les quatre onglets, la barre à
   encoche et le FAB rétrécissent ensemble. N'envelopper que `HomeScreen`
   laisserait la barre du bas et le FAB **fixes** pendant que le contenu
   s'écarte — le composant aurait l'air cassé, pas animé.
3. **Le `mainScreen` repeint `AppBackground`, et il n'a pas le choix.** Celui
   posé par la route est *parent* du `ZoomDrawer`, donc peint **avant** lui,
   alors que le tiroir recouvre l'écran entier d'un
   `ColoredBox(menuBackgroundColor)` avant de poser l'écran principal — dont les
   `Scaffold` sont transparents dans tout le dépôt. Sans ce second fond, le
   dégradé de l'application est intégralement masqué et tout ce que le contenu
   ne peint pas opaquement laisse voir le bleu de marque.
4. **`angle: 0`** — le défaut du paquet (`-12°`) pivote la coquille entière
   autour de son bord gauche. On garde le rétrécissement et le glissement, on
   retire l'inclinaison. Zéro se propage aux deux couches d'ombre
   (`StyleDefaultWidget` teste `angle == 0`), qui partiraient sinon à −8° et −4°.
   **Piège du paquet, à connaître avant de toucher à `showShadow`** : dans
   `_applyDefaultStyle`, translation, rotation, rayon et marge sont tous
   multipliés par la valeur d'animation — **l'échelle ne l'est pas**. Les deux
   couches d'ombre restent donc à 0,9 et 0,95 **tiroir fermé**. Elles ne se
   voient que parce que le point 3 les recouvre ; le retirer les fait
   réapparaître en bandeau sur les bords.
5. **`disableDragGesture: true`, sans négociation.** Le geste par défaut capte le
   glissement horizontal sur tout l'écran principal, où vivent trois carrousels
   et surtout le `PageView` de la visionneuse de statuts, dont l'en-tête prévient
   déjà que l'imbrication des gestes y est « critique ». **L'icône de l'accueil
   est la seule ouverture** — et elle n'existe sur aucun des trois autres
   onglets.
6. **Quatre entrées, rien d'autre** — Accueil · CGU · Confidentialité · À propos.
   Ni mode sombre, ni aide, ni déconnexion (l'écran Profil les porte déjà, en
   route poussée), ni
   entête utilisateur (`_ProfileHeader` fait cela). L'entête du menu porte la
   **marque**, et rien qu'elle : l'emblème seul (`BrandLogo.inverse`, à demi
   effacé), sans le nom de l'église qui y figurait — un bloc de marque qui
   concurrence quatre entrées leur vole la première seconde.

Le menu **se ferme avant toute navigation** (sinon le retour repop sur une
coquille rétrécie), et le bouton retour Android le ferme au lieu de dépiler la
route — par un `PopScope` **du dépôt** : celui du paquet
(`androidCloseOnBackTap`) évalue sa garde pendant le `build` et referme donc le
tiroir à la moindre reconstruction.

`/legal/:kind` est servie depuis #55 par `LegalDocumentScreen` : `BrandAppBar`,
`LegalDocumentBody` dans un `ListView`, et `ContentAbsence.notSynced` devant un
magasin qui n'a pas encore reçu le document. L'enveloppe provisoire de #54
(`LegalPlaceholderScreen`) a disparu avec #57, qui en était le dernier usage.

#### « À propos » (#57) — `/about`, entête local et corps servi
Spécification de rendu : `docs/documents-legaux.md` §5. Quatre points, et
l'écran entier tient dedans :

1. **Une route distincte de `/legal/:kind`, délibérément.** Ranger « À propos »
   sous `/legal/` mentirait sur sa nature — ni contrat ni politique — et
   l'écran ne se réduit de toute façon pas au document servi.
2. **Le partage local / servi tient à une chose** : le numéro de version décrit
   le **binaire installé**, le serveur ne peut pas le connaître. C'est toute la
   raison de l'entête local (emblème, nom de l'église, version et build). Tout
   ce qui doit rester corrigeable **sans publier une version de l'application**
   — présentation, mission, contact — vit au portail et arrive par le corps
   servi, rendu par `LegalDocumentBody` en genre `about`.
3. **Magasin sans document `about` → l'entête s'affiche quand même.** Seul le
   corps manque, et il manque en silence : **aucune `ContentAbsenceView` ici**,
   contrairement à `LegalDocumentScreen`. C'est le seul des trois écrans
   documentaires qui ait quelque chose à montrer sans le serveur — « pas de
   contenu, pas de section », jamais « pas de contenu, pas d'écran ».
4. **`about` n'entre jamais dans la barrière** (#56) : pas de case, pas de
   version exigée, pas de `requires_reacceptance`.

La version se lit derrière `AppVersionReader` (`lib/data/app_version.dart`,
`appVersionProvider`), jamais `PackageInfo` en direct. Deux raisons qui se
ratent en silence : sous `flutter test` le canal de plugin n'existe pas — d'où
l'implémentation réelle qui **rattrape et rend `null`** au lieu de laisser
remonter `MissingPluginException`, et `FixedAppVersionReader` pour les tests
d'écran ; et le provider **ne réessaie pas** (`retry`), un binaire ne changeant
pas de version pendant qu'il tourne. Version inconnaissable → **la ligne
disparaît**, jamais « Version inconnue » : ça ressemblerait à une donnée.

#### La connaissance du parc (#80, #87) — les en-têtes de présentation et le bandeau

Deux choses distinctes, livrées ensemble, et qui ne se mélangent pas.

**Les en-têtes sont posés par l'intercepteur, jamais par un appelant.**
`AppVersionHeaderInterceptor` (`lib/core/network/app_version_header.dart`) est
le **premier** de la chaîne d'`ApiClient`, avant le Bearer, le déballage
d'enveloppe et le 401. Il pose **trois** en-têtes, dont la forme est relevée du
plan serveur (`server-portal`, `docs/presentation-menus-vocabulaire-plan.md`
§9) :

```
X-App-Version: 1.4.0+12
X-App-Platform: android 14
X-Device-Id: 7c9e6679-7425-40de-944b-e07fc1f90ae7
```

Ils partent sur **toutes** les requêtes d'`ApiClient.instance` — synchronisation
comprise, et y compris `POST /devices/anonymous`, qui part pourtant sans porteur
et qui est précisément la requête par laquelle le serveur découvre l'appareil.
Un dépôt qui poserait l'en-tête lui-même créerait une seconde vérité, libre de
diverger ; **ne pas en ajouter un seul ailleurs**.

Six points qui se ratent en silence :

1. **Purement additif, sans exception.** Toute la lecture est dans un `try` qui
   n'a rien à dire, et `handler.next` est appelé dans tous les cas. Version
   illisible ⇒ **en-tête absent**, jamais d'exception : côté serveur, un en-tête
   absent donne « version inconnue », jamais un refus. Deux tests le verrouillent,
   dont un avec un lecteur qui **lève**.
2. **Les lecteurs sont des champs mutables d'`ApiClient`** (`appVersion`,
   `appPlatform`, `deviceIdentity`), comme `onUnauthorized` et `deviceSession`, et pour la même
   raison : le singleton naît avant tout câblage. Ce n'est pas une seconde vérité
   face à `appVersionReaderProvider` — même classe, même binaire ; ils sont
   séparés parce que la couche réseau ignore Riverpod.
3. **La lecture est retenue**, attachée à l'identité des lecteurs (changer de
   lecteur la périme, ce que font les tests). Un échec, lui, **ne se met pas en
   cache**.
4. **L'identifiant d'appareil (#87) a son propre `try`**, et c'est tout
   l'intérêt : un coffre illisible fait disparaître **ce seul** en-tête, la
   version et la plateforme restent — et l'inverse. Les trois sont indépendants,
   aucun ne tombe avec un autre.
5. **`ApiClient.deviceIdentity` est le seul exemplaire de `DeviceIdentity`** de
   l'application : l'en-tête le lit, et `HttpDeviceRepository` le prend **par
   défaut** pour ouvrir une session. Deux instances pourraient, à la première
   ouverture, fabriquer deux identifiants dont un seul serait rangé — le corps de
   `POST /devices/anonymous` ne dirait alors pas la même chose que son en-tête.
   L'intercepteur ne remet rien en cache de son côté : `DeviceIdentity.current()`
   retient déjà un succès et jamais un échec.
6. **`AppPlatformReader` passe par une importation conditionnelle**
   (`app_platform_io.dart` / `app_platform_web.dart`) — `dart:io` n'existe pas
   sur le web. `shortOsVersion` ne garde du système que son numéro : `dart:io`
   rend « 14 (API 34) » et « Version 17.0 (Build 21A329) ». Sur le web, **pas de
   version de système** : la lire serait une empreinte d'appareil.

⚠️ **L'identifiant d'appareil mesure, il n'autorise rien** (ADR-0040). Il part
**aussi quand un membre est connecté** — c'est tout l'objet de #87 : sans lui le
serveur dérive une fiche *synthétique* du compte, et un membre à deux téléphones
ne compte que pour un. Il voyage **à côté** du porteur, jamais à sa place : le
jeton d'accès reste la seule preuve d'identité, et rien ne doit se mettre à
traiter cette valeur comme un secret ni à décider d'une permission dessus.

**Rien d'autre ne part** : ni identifiant publicitaire, ni empreinte dérivée du
matériel ou de l'agent utilisateur. On transporte la valeur qui existait déjà
dans le coffre, et rien d'autre. Un test vérifie positivement que le client
n'ajoute que ces trois `X-`, ni plus ni moins.

**Le bandeau ne bloque jamais** (`lib/widgets/app_update_banner.dart`). Il
informe, renvoie au magasin, se ferme, et l'application continue. Ni « mise à
jour forcée », ni « version minimale », ni « kill switch ». Il est posé dans la
même pile que `LegalNoticeBanner`, au-dessus de la barre d'onglets, les deux dans
une `Column` — ils peuvent paraître en même temps. La seule différence qui
compte entre eux est la **mémoire** : la mention légale se retient pour toujours
(`app_settings`), le bandeau de mise à jour **pour la session seulement** (aucune
écriture) — l'invitation porte sur une version, qui change.

⚠️ **Il n'y a pas de seuil aujourd'hui, et la tranche 3 n'a pas pu refermer ce
repli.** `appUpdateThresholdProvider` rend `null`, donc le bandeau **ne s'affiche
pour personne**. Le texte précédent annonçait que le seuil voyagerait avec les
réglages de #81 ; il ne voyage pas, et pour une raison qui est côté serveur :

- le seuil vit dans `device_settings.update_banner_min_version`
  (`server-portal#465`), une table d'une seule ligne **qui n'a pas de descripteur
  de synchronisation** — `app/sync/descriptors/registry.ts` en compte vingt-sept
  depuis #83, aucune ne la touche. Elle ne se lit que par l'écran d'administration ;
- `presentation_vocabulary`, la collection livrée par #81, ne pouvait pas le
  porter : `SaveVocabulary` **ignore en silence** toute clé absente de
  `vocabulary_catalog.ts`, qui ne nomme que des termes et des clés de
  dictionnaire. Une ligne `update_banner_min_version` n'y naîtrait jamais.

Le descendre demande donc une décision serveur, hors périmètre d'une tranche
mobile. Et c'est de toute façon le bon comportement d'ici là : l'application n'a
jamais été publiée, un bandeau sur la toute première version serait le plus
mauvais premier contact possible. **La seule ligne à changer est celle du
provider.**

⚠️ **`UnavailableStoreLauncher` n'ouvre rien**, et c'est assumé pour la même
fenêtre : il n'y a ni fiche App Store ni fiche Play Store à ouvrir, et le dépôt
n'a pas `url_launcher` (greffon natif de plus, `<queries>` dans le manifeste
Android). Les deux se câblent **à la première soumission au magasin** — le
chemin complet est écrit et testé, seule la dernière ligne attend, exactement
comme `BestEffortDiskSpace` attend sa mesure.

Le bandeau se tait dans trois cas de plus, et ils penchent tous du même côté :
version locale inconnaissable, seuil illisible (`compareAppVersions` rend `null`
sur `1.0.0-rc1`), bandeau déjà fermé. **La comparaison est numérique, segment par
segment** — `1.10.0` est postérieure à `1.9.0`, alors que l'ordre alphabétique
dit l'inverse — et le `+build` est ignoré des deux côtés.

Hors périmètre, et dans l'autre dépôt (`server-portal#465`) : la table `devices`,
l'écran *Appareils*, le comptage du parc.

#### Les canaux de connexion (#83) — une **offre**, jamais une préférence

L'écran d'identifiant promettait un code que personne n'enverrait : il affichait
un sélecteur **Téléphone / Email** alors que seul l'e-mail part réellement
(`OTP_PHONE_DRIVER` vaut `log` côté serveur). La collection `auth_channels`
(jumelle serveur #468) est ce par quoi l'application l'apprend — un singleton
servi **sans compte**, deux booléens et une annonce en carte de traduction.

Cinq points qui se ratent en silence :

1. **Un seul canal ⇒ pas de sélecteur du tout.** On ne grise pas une option, on
   ne la propose pas : une option désactivée reste une option offerte, donc une
   promesse que personne ne tiendra. Le test le vérifie comme tel — absence, pas
   grisage (`test/screens/identifier_channels_test.dart`).
2. **Le repli est l'e-mail seul** (`AuthChannelOffer.emailOnly`), et il compte
   plus qu'il n'en a l'air : avant le premier cycle de synchronisation
   l'application ne sait rien, et c'est précisément le moment où quelqu'un ouvre
   l'application pour la première fois. **Jamais « tous les canaux »** — un repli
   permissif remettrait le sélecteur menteur qu'on retire — et jamais « aucun
   canal », qui fermerait la porte. Le repli vit à **deux endroits qui nomment la
   même constante** : `AuthChannelsDao` (table vide) et `authChannelOfferProvider`
   (pas encore chargé, ou en erreur).
3. **Le canal retenu se dérive à chaque `build`**, jamais d'un drapeau d'état
   seul : une synchronisation peut fermer, sous les yeux du fidèle, le canal
   qu'il venait de sélectionner. `_channelOf` est le seul endroit qui tranche, et
   `_submit` le relit au moment du tap.
4. **L'annonce du portail prend la place du sous-titre** quand il n'y a rien à
   choisir : « Entrez votre numéro ou votre email » nommerait sinon un canal que
   l'écran ne propose pas. Vide ou blanche, elle retombe sur le `.arb`
   (`authNoticeEmailOnly` / `authNoticePhoneOnly`) — même règle que le
   vocabulaire, et pour la même raison : un bandeau blanc ressemble à une donnée
   perdue.
5. **`authOrContinueWith` et `SocialButton` restent endormis.** Les boutons
   sociaux sont hors périmètre par décision écrite (`docs/auth-contract.md`), et
   n'offrir que l'e-mail **ne déclenche pas** la règle App Store 4.8 : c'est
   *ajouter* Google qui *crée* l'obligation d'offrir « Sign in with Apple ».

Comme le vocabulaire, `pumpScreen` pose un **flux nu** (`authChannelsProvider`)
et les tests passent par le paramètre nommé `authChannels:` — Riverpod 3 refuse
deux surcharges du même provider.

#### La barrière de consentement (#56) — `/legal/accept`, ADR-0036
Spécification : `docs/documents-legaux.md` §4. **Une garde de route, pas une
case de formulaire** : le parcours d'authentification est unifié et le
formulaire de profil est skippable, il n'existe aucun écran d'inscription où
poser une case — et aucun des trois emplacements « évidents » ne sait traiter la
**re-acceptation** d'un fidèle connecté depuis deux ans.

Cinq points qui se ratent en silence :

1. **La garde est SYNCHRONE.** Elle lit `AuthState.user` (le résumé
   `acceptedLegal` voyage avec la session, jamais dans le magasin) et la ligne
   courante du magasin par `AsyncValue.value` — jamais un `Future`, jamais un
   `AsyncValue` en chargement. Une garde qui attend, c'est un écran blanc au
   démarrage.
2. **Une absence de document NE BLOQUE PAS ; une absence d'acceptation BLOQUE.**
   Pas de `lastMandatoryVersion` → pas de barrière (sinon le premier lancement
   est un écran mort). `acceptedLegal` ne porte **pas de `0`** : un genre jamais
   accepté est *absent* de la carte, et cette absence-là bloque. `about` n'entre
   jamais dans le calcul (`LegalDocumentKind.acceptable`).
3. **`pendingLegalAcceptancesProvider` lit les planchers AVANT l'utilisateur.**
   Un `return` anticipé sur l'utilisateur nul le laisserait sans dépendance vers
   le magasin pendant tout le démarrage — la session s'ouvre après —, et la
   barrière n'apparaîtrait qu'à la navigation suivante. Corollaire : le routeur
   doit être **écouté** (`app.dart` en fait un `ref.watch`), un provider inactif
   voyant ses abonnements mis en pause par Riverpod 3.
4. **`/legal/accept` se déclare AVANT `/legal/:kind`** — go_router essaie les
   routes dans l'ordre —, et la garde renvoie `/home` depuis `/legal/accept` dès
   que plus rien n'est exigé. C'est ce qui retire l'écran **de lui-même** après
   un accord (l'écran ne navigue jamais, motif de la déconnexion) et ce qui
   empêche la route d'être un cul-de-sac : `PopScope(canPop: false)` n'en laisse
   sortir personne.
5. **Hors ligne : lisible, mais bloquant.** Le texte vient du magasin ; l'accord
   exige le réseau, comme l'écriture d'une annonce (ADR-0031) — pas de file
   d'envoi, pas d'état « accepté, non confirmé ». Quatre refus, quatre phrases
   (réseau / 401 / 422 → **recharger**, jamais réessayer / 5xx), **les cases
   restent cochées** dans les quatre, et l'application reste inaccessible tant
   que le `POST` n'a pas abouti.

Le succès applique le résumé rendu par la réponse (`applyAcceptedLegal`) **et le
redescend au cache local** : sans cela, le prochain démarrage hors ligne
rouvrirait une barrière que seul le réseau peut refermer.

`registerTermsPrefix` / `registerTermsLink` ont été **réécrites** avant d'être
câblées sur l'écran du code : « En créant un compte, vous acceptez nos… » est la
formule de l'acceptation *implicite*, fausse sous consentement explicite tracé.
Elles y annoncent désormais la barrière au lieu de prétendre l'avoir remplacée,
et ne sont **pas cliquables** — `/legal/:kind` est hors des emplacements
autorisés avant authentification.

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
  détail, et **le seul endroit qui pilote le lecteur** (#40). Il reçoit le
  **provider** (et non sa valeur) pour pouvoir l'écouter : une rétractation
  immédiatement suivie d'une resynchronisation ne produirait qu'une
  reconstruction, et le son aurait continué sur un contenu retiré. Cinq points
  s'y ratent en silence :
  1. **la rétractation appelle `stop()`**, pas un `setState` : couper l'état du
     widget n'arrête pas le son, et un enseignement retiré continuerait de
     jouer, écran éteint, son titre sur l'écran verrouillé. Le déclencheur est
     la **valeur**, jamais l'`AsyncValue` — un rechargement ne coupe rien ;
  2. **`load()` est gardé** par « ce contenu est déjà chargé » (`_requested` +
     `ContentPlayback.contentId`) : sans quoi chaque reconstruction relance le
     prêche depuis le début, et un contenu qui réapparaît après rétractation
     repart tout seul ;
  3. **seuls `_ProgressLine` et `_PlayButton` s'abonnent au lecteur**, par
     `select`. La position émet plusieurs fois par seconde : la faire descendre
     en paramètre reconstruirait le dégradé, le `Hero` et l'image au même
     rythme ;
  4. **l'ouverture charge le média et ne joue pas** — sauf le direct. Cette
     règle a **changé**, et son ancienne version était écrite ici : « l'auto-
     lecture à l'ouverture est un choix assumé — ouvrir la fiche d'un prêche
     est, ici, l'acte d'aller l'écouter ». Ce n'en est plus un. Le son, le
     réseau et la batterie d'un prêche d'une heure ne partent plus sur un coup
     d'œil à une fiche ; le geste les demande. Le **direct** est la seule
     exception (`isLive`), parce qu'un flux qu'on ouvre sans le suivre n'a pas
     de sens : il n'y a ni position à reprendre ni durée à parcourir.
     Mécanique : `_open(content, {required bool autoplay})`, et `autoplay` n'a
     que deux appelants — `_loadOnce` (donc `widget.isLive`) et
     `_togglePlayback` (**toujours vrai**). Ce second cas n'est pas un détail :
     le bouton passe par `_open` chaque fois que le lecteur ne tient plus ce
     contenu (rétracté puis republié, arrêté depuis la notification, ou fiche
     simplement ouverte), et si la demande s'y perd le premier appui recharge
     en silence — il faut **appuyer deux fois** pour entendre quelque chose.
     C'est arrivé, `test/widgets/content_player_view_test.dart` le verrouille
     désormais (« un seul appui suffit, même quand il faut rouvrir le média ») ;
  5. **les cinq déclencheurs de #43 sont câblés ici** : position poussée,
     pause, sortie d'écran, `AppLifecycleState.paused` (**sans arrêter la
     lecture**) et état terminal — qui exige `pause()` **et** `seek(zero)`,
     `just_audio` restant `playing == true`, curseur en fin, sans son ;
  6. **le visuel central est carré, et il le reste.** Sans contrainte, l'image
     prenait tout l'espace central — un rectangle haut — et `BoxFit.cover` la
     rognait **à gauche et à droite** : un sujet centré sortait du cadre des
     deux côtés, ce qui se lit à l'œil comme une image déformée (mesuré : sur un
     cadre de 390 × 495, un carré de 600 px perdait 52 px de chaque bord).
     `AspectRatio` se replie seul sur la hauteur quand le cadre est plus haut
     que large, et un visuel non carré — le repli paysage ou portrait — est
     recadré au centre, ce qui reste plus informatif qu'un aplat ;
  7. **l'espace central (`_PlayerStage`) porte quatre réponses** (#42) —
     visuel, mise en tampon **par-dessus** le visuel, « Lecture interrompue »
     et « il faut du réseau » — et **aucune ne remplace l'écran** : le titre,
     le compteur et les commandes restent dans les quatre. Il s'y abonne par
     `select` sur un état dérivé, pour la raison du point 3.

  Corollaire pour les tests : tout test qui monte un écran de lecture doit
  poser un **magasin en mémoire** (`appDatabaseProvider`) et un **rapporteur
  muet** (`playbackProgressReporterProvider`) — le premier écrirait un fichier
  de base sur la machine, le second posterait sur une socket que `flutter test`
  refuse, et laisserait la minuterie de Dio derrière lui. `pumpScreen` et
  `test/helpers/playback_doubles.dart` s'en chargent.
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

### Le vocabulaire réglé au portail (#81) — `context.words`, et **lui seul**

**Le mot réglé dans le portail l'emporte sur le mot compilé dans le binaire.**
C'est tout l'intérêt du réglage : sans cette précédence, il ne sert à rien.

**Mais le `.arb` n'est pas un repli honteux.** Avant son premier cycle de
synchronisation l'application montre ce qu'elle a compilé, et le `.arb` reste la
vérité de toute clé que le portail ne surcharge pas — la grande majorité d'entre
elles. Un écran vide ou une clé technique au premier lancement serait pire que le
mot du dépôt.

Un seul endroit décide, et il est **à côté** de `context.l10n` :
`context.words` (`lib/l10n/l10n_extension.dart` → `AppWords`, `lib/l10n/
vocabulary.dart`). Un widget qui déciderait lui-même créerait une seconde
vérité. Choisir entre les deux accesseurs, c'est **nommer une clé** — le
catalogue des clés surchargeables est curé côté serveur
(`app/presentation/support/vocabulary_catalog.ts`, entrées `surface: 'mobile'`) —,
jamais décider d'une précédence.

Cinq points qui se ratent en silence :

1. **Une surcharge vide n'est pas une chaîne vide.** Le serveur n'efface jamais
   la ligne : effacer une surcharge y écrit `null`, et c'est ce `null` qui porte
   le retour au mot du dépôt jusqu'au téléphone. Une carte sans aucune langue
   remplie — ou remplie de blancs — veut dire « garde le mot du dépôt », jamais
   « affiche rien ». Un titre blanc ne ressemble pas à un bug, il ressemble à une
   donnée perdue.
2. **Aucune composition, aucun accord calculé.** Un terme porte son singulier et
   son pluriel, écrits à la main au portail ; une phrase composée est **sa propre
   clé**, surchargée entière. Décision de cadrage, pas un report : « Derniers
   enseignements » → « Dernières publications » change le genre *et* l'accord.
3. **Le repli de langue reste `pick`** (`utils/i18n_text.dart`), avec la locale
   **d'interface** et non celle du contenu. C'est pourquoi `VocabularyBoundary`
   vit **sous** `MaterialApp` (`app.dart`, à côté de `_ContentLocaleSync`) :
   `Localizations` n'existe pas au-dessus.
4. **Sans scope, tout se lit sur le `.arb`.** `VocabularyScope.of` rend
   `VocabularyOverrides.empty` quand personne ne l'a posé — l'état d'un test monté
   sans frontière, et le même que la toute première ouverture.
5. **`pumpScreen` pose un flux nu** (`vocabularyProvider`), comme pour les
   réglages d'apparence et pour la même raison : un flux Drift attendu sous
   l'horloge factice fige le montage. Les surcharges d'un test passent par le
   **paramètre nommé** `vocabulary:` — Riverpod 3 refuse deux surcharges du même
   provider.

À ne pas confondre avec `LocalizedText` / `parseI18nMap`, qui portent le repli
`fr/en/ee` du **contenu** (le titre d'une rubrique, le nom d'un compte officiel).
Ici il s'agit de l'**interface**.

### La **seule dérogation** à `pick` — les documents légaux (ADR-0035)
`pick` est l'unique autorité du repli de langue des **contenus** (ADR-0023), et
il se replie **par champ**. `legal_documents` en sort, et c'est la seule
collection qui en sorte : **la langue d'un document légal se décide une fois,
pour le document entier** — `resolveLegalLocale`
(`models/legal_document_view.dart`). La locale demandée n'est retenue que si
**toutes** les sections la portent, `heading` **et** `body` ; une seule absence
bascule le document **entier** sur le français. Le résultat est binaire.

Le motif n'est pas esthétique : un document en éwé dont trois articles sortent
en français est **impossible à accepter** — on demande de cocher « j'ai lu et
j'accepte » un texte dont une partie est illisible, et le serveur en garde une
trace horodatée. Et ça s'affiche parfaitement, sans faire rougir un test.

Trois garde-fous, et la redondance est voulue : la fonction porte le nom du
**motif** (jamais `pickAll` ni `pickSections`) ; un test prouve qu'**une seule**
section manquante bascule tout — pas « la majorité »
(`test/models/legal_document_view_test.dart`) ; et un garde-fou de **source**
interdit `pick(` dans tout fichier de `lib/` dont le chemin porte « legal ».

`languageSubtag` (`utils/i18n_text.dart`) est public pour cette fonction-là :
découper `fr_FR` en `fr` est mécanique, la dérogation porte sur la **règle de
repli**, pas sur la lecture d'une étiquette.

## L'identité de l'application (#86) — **trois noms, et deux ne bougent pas**

| ce que c'est | où | valeur | change ? |
| --- | --- | --- | --- |
| **nom affiché** — ce que le fidèle lit sous l'icône | `android:label`, `CFBundleDisplayName` (+ `CFBundleName`, le nom court) | « Nouvelle Vie » | oui, c'est le seul |
| **nom du paquet Dart** | `pubspec.yaml`, chaque `import 'package:maison_du_miracle/…'` | `maison_du_miracle` | **non** — personne ne le voit |
| **identifiant d'application** | `applicationId`, `PRODUCT_BUNDLE_IDENTIFIER` | `com.maisondumiracle.*` | **non** — c'est l'identité auprès des magasins et de la signature |

⚠️ *Éviter* « renommer l'app » tout court : trois choses portent un nom ici, et
deux ne doivent pas bouger. Changer l'identifiant après une soumission rend
l'application introuvable pour qui l'a déjà installée ; avant, il oblige à
refaire les fiches.

**Les icônes et le splash natif se régénèrent, ils ne s'éditent pas** :
`make icons` (`tool/app_icons.swift`, macOS) les reconstruit depuis
`assets/images/brand_logo.webp` et `assets/images/live_bg.png`. Les fichiers
produits sont **versionnés** ; ni le build ni la CI ne lancent le script.

Trois contraintes y sont tenues, et chacune se raterait en silence :

1. **Les icônes iOS n'ont aucun canal alpha** — un PNG transparent fait rejeter
   la soumission. Elles sont peintes sur un fond blanc opaque, dans un contexte
   `noneSkipLast` ; vérification : `sips -g hasAlpha` doit répondre « no » sur
   les quinze.
2. **Aucun coin arrondi n'est dessiné** : iOS applique son propre masque, et les
   dessiner les doublerait.
3. **La couche `monochrome`** (Android 13+) n'est pas le premier plan recopié.
   Le système n'en garde que l'alpha ; l'écusson étant opaque de bord à bord, il
   donnerait un disque plein. Elle est dérivée de la **luminance inversée** —
   l'encre bleue devient la matière, le blanc des lettres devient le vide.

`flutter_launcher_icons` n'a **pas** été ajouté : il ne sait faire ni le point 1
ni le point 3, et le script maison ne met rien dans le binaire (il ne produit
que des fichiers). Le `description:` du `pubspec.yaml` n'a pas été touché — il
n'est lu par personne sur un téléphone, et le corriger est un autre sujet.

## Git
- **Commits canoniques** : un commit par fonctionnalité, atomique, préfixes
  conventionnels (`feat/fix/chore/refactor(scope)`), corps en français.
- **Ne PAS ajouter de trailer `Co-Authored-By`** (commits attribués à l'auteur).
- **Ne pas pousser à la place de l'utilisateur** : il fait `git push` lui-même
  (souvent `git push --force-with-lease`, la branche distante ayant divergé).

## iOS : **plus de CocoaPods**, tout passe par Swift Package Manager

`ios/` n'a **ni `Podfile`, ni `Podfile.lock`, ni `Pods/`**, et c'est un état à
tenir. Les huit plugins iOS sont des Swift Packages ; le dernier qui ne l'était
pas, `flutter_secure_storage`, l'est devenu en v10 (implémentation fédérée
`flutter_secure_storage_darwin`, qui porte un `Package.swift`). Flutter le
confirme de lui-même au build — *« All plugins found for ios are Swift
Packages »* — et le `pod install` a disparu du cycle.

Ce qui a été retiré, dans cet ordre : `pod deintegrate`, suppression du
`Podfile` et du `Podfile.lock`, retrait des deux `#include?` de
`Pods/Target Support Files/…` dans `ios/Flutter/Debug.xcconfig` et
`Release.xcconfig`, et de la `FileRef` vers `Pods/Pods.xcodeproj` dans
`ios/Runner.xcworkspace/contents.xcworkspacedata`.

**Ajouter un plugin qui n'a pas de `Package.swift` ressusciterait CocoaPods**
pour tout le projet — Flutter régénère alors un `Podfile`. Vérifier avant :
`find $(dart pub cache list … )` ou, plus simplement, lire l'avertissement du
premier `flutter build ios` (« The following plugins do not support Swift
Package Manager »). Ce n'est pas un interdit, c'est un coût à décider.

### Les deux pannes CocoaPods qu'on a connues, pour mémoire

Elles ne peuvent plus arriver ici, mais le même diagnostic sert ailleurs :

- **« The sandbox is not in sync with the Podfile.lock »** — le contrôle Xcode
  est un `diff` entre `ios/Podfile.lock` et `ios/Pods/Manifest.lock`. Un
  `Manifest.lock` **absent** le fait échouer, et un `Pods/` à moitié écrit
  suffit. Remède : `rm -rf ios/Pods ios/.symlinks && flutter pub get && (cd ios
  && pod install)`.
- **`Unicode Normalization not appropriate for ASCII-8BIT`** — CocoaPods 1.17
  sur le Ruby 4.0 de Homebrew, lancé depuis un shell sans locale UTF-8. Ne
  touche pas `flutter build`, qui pose la locale lui-même. Remède si on appelle
  `pod` à la main : `LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install`.

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
