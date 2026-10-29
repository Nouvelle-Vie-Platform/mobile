# Une app web installable, pour les téléphones où l'application ne va pas

**Statut** : cadrage validé le 2026-10-28, **§1 corrigé le 2026-10-29 par le banc sur appareil**
(§3). Six tranches (T0 à T5), dépôts `mobile` et `context`. **Les six sont écrites, T2 la
dernière le 29/10** ; il ne reste d'elle que la **clé VAPID** à poser dans la console Firebase.
**Origine** : une demande de l'utilisateur — « pour les devices qui ne pourront pas avoir accès à
l'installation de l'application, que l'app web fonctionne chez eux, qu'ils l'installent facilement
et la retrouvent dans leurs apps, avec si possible la même expérience ».

## 1. Le mur est celui de l'APK, pas celui du web — mesuré des deux côtés

**La première version de ce plan se trompait, et c'est un téléphone emprunté qui l'a montré.** Elle
déclarait les Android ≤ 6 hors d'atteinte par tout moyen, app web comprise. La moitié est vraie, et
elle le reste :

- `minSdk = 24` (`android/app/build.gradle.kts:68`) n'est pas un choix du dépôt : **Flutter lui-même
  ne supporte plus Android < 24** depuis la 3.35, et la matrice de la 3.47 l'écrit (« Android 24 to
  37 »). `flutter_secure_storage` v11 a suivi pour la même raison. Descendre le plancher est
  impossible, pas coûteux : impossible. **L'APK ne descendra donc jamais sous Android 7.0.**
- Chrome est par ailleurs gelé à **106** sur Android 6 et à **119** sur Android 7 : ces téléphones ne
  recevront plus jamais de navigateur neuf.

L'autre moitié était une déduction, et elle était fausse. Flutter n'annonce de support que pour « les
2 dernières versions de Chrome » — mais c'est une **politique de support, pas une barrière
technique**. Mesuré le 2026-10-29 sur un **HUAWEI NXT-L29 (Mate 8), Android 6.0, Chrome
106.0.5249.126** : l'application web se dessine, se parcourt, enregistre un service worker et
termine un Background Fetch (§3).

**Le public de ce chantier est donc tout fidèle que l'APK n'atteint pas** — Android 6 compris, quelle
que soit la raison du blocage (pas de Play Store utilisable, stockage saturé, OS trop ancien, ou
refus d'une application de plus). L'APK que le portail sert sur `/application` reste la bonne réponse
pour ceux qui peuvent l'installer ; l'app web est désormais le **repli universel**, et non un
rattrapage pour une poignée d'appareils.

**Le plancher annoncé est celui qui a été mesuré : Chrome 106.** Les briques utilisées sont toutes
plus anciennes (service worker depuis Chrome 40, WebGL 2 depuis 56, Background Fetch depuis 74), donc
plus bas est plausible — mais **rien ne le prouve**, et ce plan ne le promet pas. À mesurer le jour où
un fidèle apporte un téléphone plus ancien, avec le banc de `§6`.

## 2. Ce qui est déjà acquis — ne pas le refaire

- **Le web est une cible maintenue**, pas une expérience : `HlsContentPlayer` + `hls.min.js` versionné
  (`web/WEB_ASSETS.md`), Drift sur `sqlite3.wasm`, `flutter_secure_storage` web, et `devicePlatform()`
  qui rend déjà `'web'` (`lib/data/push/push_transport.dart:129`).
- **La CI construit déjà le web à chaque poussée** (`flutter-ci.yml`, étape « Build web ») — le
  garde-fou contre un `dart:io` glissé dans `lib/`. Il ne manque que la publication.
- **Le serveur n'a rien à faire pour le push** : `DEVICE_PLATFORMS = ['ios', 'android', 'web']`
  (`server-portal/app/devices/support/device_platform.ts:11`), et le contrat de
  `POST /devices/tokens` dit que `fcm` sert « iOS, Android with Play Services, **web** ».
- `flutter_service_worker.js` **est** généré par le build : le critère d'installation de Chrome est
  donc rempli. ⚠️ **Corrigé le 29/10 par la lecture du SDK (T5)** : la suite de cette ligne était
  fausse. Le worker de Flutter 3.47.4 **ne met plus rien en cache** — 31 lignes, `skipWaiting()` à
  l'installation puis `registration.unregister()` à l'activation, et il renavigue ses clients ;
  `--pwa-strategy` ne choisit plus que « le générer ou pas »
  (`packages/flutter_tools/lib/src/web/file_generators/js/flutter_service_worker.js`). Il n'y a donc
  **ni coquille hors ligne ni versionnement des actifs** acquis. **T4 doit l'écrire lui-même**, et ne
  peut pas s'appuyer sur ce qui n'existe pas.
- **Le téléchargement est déjà cousu** : `DownloadBackend` est la porte unique du moteur de transfert,
  et `dart:io` n'apparaît qu'à deux endroits du chemin (`File(path)` dans le manager, le canal natif
  de `disk_space`). Un backend web s'y branche sans toucher aux états ni à la réconciliation.
- Le lecteur web **dit déjà ce qu'il faudrait pour le direct** (`hls_content_player.dart:155-162`) :
  `xhrSetup` + `withCredentials` côté client, en-têtes CORS côté antenne. Ce n'est pas à redécouvrir.
- Les fonctions déjà écartées proprement sur le web, avec leur raison écrite : `audio_service`,
  le lecteur de statuts, `gal` (`MediaSaveError.unsupported`), les notifications de lecture Android.

## 3. Les mesures du 2026-10-28

### Le poids du premier lancement — remesuré le 29/10 sur le bundle de T0

`flutter build web --release --no-web-resources-cdn --csp --base-href /`, Flutter 3.47.4, brotli
`-q 11` posé à côté de chaque fichier :

| Ce qu'il faut avant le premier écran | brut | **servi (brotli)** |
| --- | --- | --- |
| `main.dart.js` | 7 907 k | **1 593 k** |
| `canvaskit/chromium/canvaskit.wasm` | 5 301 k | **1 504 k** |
| `canvaskit/canvaskit.js` | 84 k | **23 k** |
| `hls.min.js` | 602 k | **149 k** |
| `flutter_bootstrap.js` | 12 k | **4 k** |
| **premier écran** | — | **≈ 3,2 Mo** |
| `sqlite3.wasm` + `drift_worker.js` (ouverture du magasin) | 1 073 k | **393 k** |
| **total** | — | **≈ 3,6 Mo** |

**Et non 4,35 Mo comme écrit le 28/10** : la première mesure comptait la variante **générique** de
CanvasKit (2 204 k en brotli), alors que Chrome télécharge la variante `chromium/` (1 504 k), qui
délègue les codecs au navigateur. Sur Firefox et Safari, c'est bien la générique, donc ~700 k de
plus.

`assets/images/live_bg.png` pèse en plus **1,5 Mo brut** sur l'écran radio (~150 k en webp).
Les lancements suivants ne coûtent presque rien, mais **par le cache HTTP et non par le service
worker** (voir la correction du §2) : Caddy sert les quatre fichiers d'amorçage en `no-cache` et tout
le reste est versionné par son nom, donc immuable.

### Le banc sur appareil du 2026-10-29 — HUAWEI Mate 8, Android 6.0, Chrome 106.0.5249.126

Servi depuis un poste de développement par `adb reverse tcp:8000 tcp:8000`, donc sur
`http://localhost:8000` — **la seule origine insecure que les navigateurs traitent comme sûre**, ce
qui évite un tunnel et un certificat. Première tentative en wifi sur `http://192.168.1.68:8000` :
inutilisable, `isSecureContext` y est faux et service worker, Cache, `navigator.storage` et
Background Fetch y sont **absents de l'objet global** — ils répondaient « non » sans rien dire du
téléphone. Le drapeau `chrome://flags#unsafely-treat-insecure-origin-as-secure` n'a pas pris ; `adb`
a réglé la question en une commande.

| Essai — traversé, pas détecté | Résultat |
| --- | --- |
| L'application se dessine et se parcourt | ✅ `main.dart.js`, `FontManifest.json`, Atkinson/Playfair/Literata, `home_header_church.webp`, puis `live_bg.png` (écran radio) dans le journal du serveur |
| Service worker enregistré | ✅ |
| Background Fetch de 600 ko, relu dans le Cache | ✅ |
| « Installer l'application » proposé par Chrome | ✅ (et non « Ajouter à l'écran d'accueil ») |
| `navigator.storage.persist()` **avant** installation | ❌ non |
| `navigator.storage.persist()` **après** installation | ✅ **oui** |
| Quota annoncé | 14,8 Go |
| Media Session, PushManager, Notification (`default`), Cache, IndexedDB, Workers, WebGL 2, MediaSource, AAC-LC, HE-AAC | ✅ tous |

**Ce que le banc n'a pas pu prouver, et qui attend T0 :** aucun paquet WebAPK n'a été fabriqué
(Play Services est pourtant présent en 26.26.34 — Chrome ne forge pas d'application pour une origine
`localhost`), `sqlite3.wasm` n'a jamais été demandé donc le magasin Drift n'a pas été ouvert, et ni
le push ni la radio n'étaient testables sans la vraie origine.

### Le moteur de rendu venait de chez Google, et personne ne le voyait

Le banc l'a révélé par son journal : **aucun `.wasm` n'a été téléchargé depuis notre origine**, alors
que l'application se dessinait. Vérification dans les artefacts du build :

```
build/web/flutter.js : useLocalCanvasKit ? … : "https://www.gstatic.com/flutter-canvaskit"
flutter build web    : --[no-]web-resources-cdn   (defaults to on)
```

`build/web/canvaskit/` existe — c'est pourquoi tout avait l'air auto-hébergé — mais ce n'est qu'un
repli : **par défaut, le build de release va chercher CanvasKit sur `gstatic.com`**. C'est
exactement ce que `web/WEB_ASSETS.md` interdit en toutes lettres (« Aucun CDN… une dépendance réseau
tierce au démarrage est une panne de plus, et un point de confiance de plus ») : la règle a été
appliquée aux trois actifs versionnés, et le moteur lui-même est passé entre les mailles. Un fidèle
dont le réseau n'atteint pas `gstatic.com` n'obtient **rien**, pas même un écran dégradé.

Correctif : **`--no-web-resources-cdn`** sur tout build web — CI, job de release et `make web`
(T5). Les mesures de poids ci-dessus comptaient déjà le CanvasKit local : le tableau reste juste.

### Les sondes en production

```
stream.eenv.brainsial.com/antenne/index.m3u8
  Origin: https://eenv.brainsial.com      → access-control-allow-origin: https://eenv.brainsial.com
  Origin: https://app.eenv.brainsial.com  → AUCUN en-tête CORS
  et dans les deux cas : set-cookie: cookieCheck=1; …SameSite=None; Partitioned
                         mais AUCUN access-control-allow-credentials

eenv.brainsial.com/partage/decor/marque-d269a574.jpg
  Origin: https://app.eenv.brainsial.com  → 200, AUCUN en-tête CORS
```

Trois conséquences, et ce sont elles qui dessinent T0 :

1. l'antenne refusera la nouvelle origine tant que rien ne l'autorise ;
2. **sans `Access-Control-Allow-Credentials`, une requête `withCredentials` est rejetée même quand
   l'origine est autorisée** — et `mediamtx.yml` ne sait pas émettre cet en-tête (il n'a que
   `hlsAllowOrigins`). Il viendra donc de Caddy, dans tous les cas de figure ;
3. Flutter web en CanvasKit récupère les images par `fetch` avant de les peindre : sans en-tête CORS
   sur les médias, **toutes les affiches sont vides** — la panne classique d'une app Flutter servie
   depuis une autre origine, et elle ne se voit sur aucun test.

### Le reste du relevé

- `config/cors.ts` en production : `origin: []`, `credentials: true`. Aucune origine autorisée.
- Session : token opaque `oat_…` en `Bearer`, **sans rafraîchissement ni rotation**, 90 jours
  d'inactivité (`docs/auth-contract.md:213`).
- Push : un refus de permission ne coûte au natif que l'affichage, le réveil silencieux passe
  (`fcm_push_transport.dart:89-95`). **Sur le web il n'y a pas de jeton sans permission** : le refus
  y emporte aussi la synchronisation réveillée.
- Stockage : sous pression, Chrome évince **tout le stockage d'une origine d'un coup** (Cache et
  IndexedDB, donc les enseignements téléchargés *et* le magasin Drift). `navigator.storage.persist()`
  exempte l'origine, et Chrome l'accorde silencieusement à un site **installé** ou dont la permission
  de notification est accordée.
- Background Fetch : Chrome et Chrome Android **74+** (donc présent jusque sur le Chrome 119 d'un
  Android 7), absent de Firefox et de Safari.
- La CI épingle Flutter `3.44.2`, la machine de développement est en `3.47.4`.

## 4. Décisions (grilling du 2026-10-28) et leur raison

| Décision | Raison |
| --- | --- |
| Un **sous-domaine dédié**, `app.eenv.brainsial.com`. | Une adresse qui se dit à l'oral et s'écrit sur une affiche, et un service worker qui a tout le domaine pour portée. Le prix est connu : une entrée DNS, un bloc Caddy, et l'origine à déclarer dans l'allowlist CORS du portail. |
| **Parité totale**, téléchargement hors ligne compris. | Demandé explicitement. Le coût a été nommé avant d'être accepté : le hors-ligne web est la tranche la plus lourde et n'existera jamais sur iPhone. |
| **Brotli précompressé au build + `live_bg` en webp**, et on s'arrête là. | **Le binaire Caddy standard ne sait pas compresser en brotli** (greffon requis) — mais `file_server { precompressed br }` sert un `.br` posé à côté du fichier, sans greffon. `tool/precompresser-web.sh` le fait à `-q 11` une fois au build, ce qui est de toute façon meilleur qu'à chaque requête. Pas de `.gz` dans l'archive : tout navigateur qui fait tourner Flutter web parle brotli, et `encode gzip` reste en repli dynamique. Plus 1,35 Mo gagnés sur l'écran radio par le webp. Le build `--wasm` a été écarté : il exige **WasmGC**, arrivé précisément à Chrome 119 — on gagnerait des octets en perdant le public visé. |
| Hors ligne par **Background Fetch**, pas par `fetch` + `Range` dans OPFS. | Le navigateur ne donne pas les deux : soit le transfert survit à la fermeture de l'onglet, soit il se met en pause à l'octet. Un fidèle lance un enseignement de deux heures et range son téléphone — c'est ce cas-là qui compte. **Le bouton Pause n'existe donc pas sur le web** (annuler, oui ; reprendre où l'on était, non). |
| **Le téléchargement demande l'installation ; tout le reste marche dans un onglet.** *(confirmé par la mesure du 29/10 : `persist()` a répondu non avant l'installation, oui après.)* | `navigator.storage.persist()` ne rend `true` qu'à un site installé. Lancer un transfert de 80 Mo que Chrome peut évincer sans prévenir serait faire payer des données pour rien — sur des appareils dont le stockage saturé est précisément le problème. |
| Installation par un **bandeau `beforeinstallprompt`** dans l'appli ; sur iPhone, le geste Partager → Sur l'écran d'accueil **expliqué**. | Chrome a rangé « Installer l'application » dans son menu ⋮, que personne n'ouvre — et l'installation porte désormais le hors-ligne et la durabilité du stockage. La laisser au hasard du menu serait la laisser mourir. iOS n'a aucun événement à écouter : il ne reste que l'explication. |
| **iPhone traité à égalité de soin**, en assumant qu'il n'y a **pas** de hors-ligne sur Safari. | Safari n'a pas Background Fetch, quel que soit le code. L'écran se masque là où la fonction n'existe pas, exactement comme pour un onglet non installé : un écran masqué vaut mieux qu'un bouton qui ment. |
| **90 jours comme au natif**, plus une **CSP stricte** servie par Caddy. | C'est le seul endroit où le web est strictement moins sûr que le natif, et ça ne se rattrape pas en Dart : le token dort dans le stockage du site, lisible par tout script injecté sur l'origine. La défense est donc l'en-tête, et elle est cohérente avec la règle du dépôt (aucun CDN, `web/WEB_ASSETS.md`). |
| L'antenne : **tout dans Caddy**, `mediamtx.yml` intact. | ⚠️ *Correction du 29/10 : j'avais justifié ce choix par un silence de l'antenne au redémarrage de MediaMTX. C'est faux — `mediamtx-service/deploy/caddy/mediamtx.caddy` dit que resserrer `hlsAllowOrigins` « est un `mtx.sh recharger`, donc sans coupure ». Le choix tient pour la raison suivante, qui est la vraie.* Comme `Allow-Credentials` doit venir de Caddy de toute façon, y mettre aussi l'`Allow-Origin` de la nouvelle origine ne crée aucun doublon — MediaMTX n'en émet aucun pour elle (mesuré). |
| Push : permission demandée **dans la foulée de l'installation**. | C'est l'instant de plus forte intention, un refus web est quasi définitif, et la permission accordée renforce en prime la durabilité du stockage. Au natif elle est demandée au démarrage ; sur le web ce serait le pic de refus, et le refus y emporte tout. |
| **`Access-Control-Allow-Origin: *` sur les routes de médias**, et elles seules. — **déjà en place, vérifié le 29/10 : rien à faire.** `stream.…` porte `ACAO *`, `Allow-Headers Range` et `Expose-Headers Content-Range, Accept-Ranges` sur `/hls/*`, `/dl/*` et `/radio/*` ; `eenv.…/media/visuals/*` et `/media/uploads/*` portent `ACAO *`. L'application ne tire ses médias que de là. | Ces fichiers sont déjà publics, immuables (`max-age=31536000, immutable`) et ne portent aucun cookie : les lire depuis une autre origine ne donne accès à rien de plus que les ouvrir dans un onglet. L'origine exacte aurait été à maintenir à trois endroits, et un oubli se manifeste par des affiches vides sans message lisible. |
| **Trois service workers à portées distinctes** ; le fichier généré par Flutter n'est jamais modifié. | Tout ce qu'on écrirait dans `flutter_service_worker.js` disparaît au prochain build. Celui de Flutter garde la coquille, celui de Firebase le push (il s'enregistre seul sur sa propre portée), et un `sw-offline.js` à nous reçoit `backgroundfetchsuccess`. Le Cache est partagé par origine : l'appli y lit sans rien de plus. |
| Mises à jour : **le bandeau existant**, bouton « Recharger » sur le web. | `update_banner_min_version` est déjà réglable depuis l'écran *Appareils* du portail et déjà répliqué par la synchronisation (`server-portal#475`). Seule l'action change (`skipWaiting` + rechargement au lieu d'ouvrir le magasin). Un rechargement d'office a été écarté : il tomberait en pleine écoute. |
| Publication : **`.tar.gz` joint à la Release sur tag `v*`**, posé sur le VPS à la main, bascule par lien symbolique. | Le dépôt `mobile` est public : ses Releases se téléchargent sans jeton, donc `curl | tar` suffit — aucun secret, aucun chemin entrant nouveau, et un retour arrière instantané vers la version précédente. Une route de dépôt automatique aurait signifié **extraire une archive** derrière une route authentifiée, soit une frontière de confiance à soigner pour économiser deux commandes. |
| **Même tag et même numéro que l'APK**, publiés ensemble. | Le bandeau de mise à jour compare la version de l'appli à **un seul** seuil : une numérotation web séparée rendrait ce seuil ininterprétable. Un correctif web seul coûte un tag et un APK reconstruit — gratuit en CI, le dépôt étant public. |
| **`--no-web-resources-cdn` sur tout build web** — CI, release et `make web`. | Sans ce drapeau, CanvasKit arrive de `gstatic.com` et non de notre origine (§3) : une dépendance réseau tierce au démarrage, que `web/WEB_ASSETS.md` interdit déjà pour les trois actifs versionnés, et une panne totale — pas dégradée — pour un fidèle dont le réseau ne l'atteint pas. |
| **Monter la CI à Flutter 3.47.4** dans T5, APK compris. | Le bundle servi est celui de la CI. Un écart de version de Flutter sur une cible web est exactement le genre de panne qu'aucune compilation ne voit — et c'est le dépôt lui-même qui l'a déjà écrit à propos des actifs web. |
| Le plan ici, les issues T1-T5 dans `mobile`, **T0 dans `context`**. | `mobile` est public depuis le 14/10 : une issue qui détaille le bloc Caddy, la CSP et les origines serait une carte offerte. Le démontage de la CI est suivi de la même façon (`context#7`). |

## 5. Les tranches

**T0 bloque tout le reste** : sans l'adresse, rien n'est joignable — et c'est un état sûr, exactement
comme pour l'antenne (`mediamtx-service/README.md`).

- **T0 — l'adresse** (`context` + `server-portal`). **Écrite le 29/10** :
  `infra/caddy/app-web.caddy` (le bloc du domaine, `root` sur `/opt/eenv-app-web/current`,
  `encode zstd gzip`, `file_server { precompressed br }`, CSP stricte, `no-cache` sur les quatre
  fichiers d'amorçage), `infra/caddy/antenne-cors.caddy` (le `handle /antenne/*` remplacé, avec
  `Allow-Credentials` et l'`Allow-Origin` posés **sous matcher d'origine** pour ne pas doubler
  celui que MediaMTX émet déjà au portail), la branche `feat/cors-app-web` du portail
  (`CORS_ALLOWED_ORIGINS`, typecheck vert), et la section de pose dans `docs/RUNBOOK.md` du dépôt
  `context` — DNS, bundle, dossier, version, portail, Caddy, vérifications, retour arrière.
  **Les en-têtes CORS des médias n'en font pas partie : ils existaient déjà.**
- **T1 — l'installation** (`mobile`). `web/manifest.json` réel (nom, description, thème et fond de
  la marque, icônes déjà présentes), `live_bg` en webp, bandeau `beforeinstallprompt` qui disparaît
  en `display-mode: standalone`, et l'explication du geste iOS. Après T1, la médiathèque, les
  échanges, la Bible et les notes fonctionnent — ils ne demandent aucun des quatre rattrapages.
- **T5 — la publication** (`mobile`). **Écrite le 29/10** (mobile#271) : les deux workflows montés à
  Flutter `3.47.4`, les trois drapeaux sur les quatre endroits qui construisent le web
  (`flutter-ci.yml`, le job `web` de `android-release.yml`, `make web` et `tool/hls_probe.sh` —
  `flutter run` n'accepte que `--no-web-resources-cdn`, `--csp` n'existant que sur `flutter build
  web`), job `web` (`needs: apk`) qui joint `app-web-X.Y.Z.tar.gz` à la Release avec ses quatre
  contrôles d'archive, et le bouton « Recharger » par `appReloaderProvider`. **Deux choses ajoutées
  en route** : `--build-name` / `--build-number` sur le build web (sans eux `version.json` dit
  `1.0.0`, et le bandeau paraît pour tout seuil), et la correction du §2 sur le service worker.
  Restent les commandes de pose et de retour arrière (`context`, `docs/RUNBOOK.md`).
- **T2 — les annonces** (`mobile`). **Écrite le 29/10** (mobile#283) :
  `web_push_transport.dart` derrière la porte `web_push.dart` (seconde implémentation de
  `PushTransport`, **une addition** — registraire, enrôlement, lecture de charge utile et handler
  n'ont pas bougé), l'entrée `web` de `firebase_options.dart`, `web/firebase-messaging-sw.js` sur la
  portée que le SDK enregistre lui-même, et la permission demandée par
  `installThenAskForNotifications` **seulement si l'installation a été acceptée** (d'où
  `InstallPrompt.show()` qui rend un booléen). Aucun travail serveur.
  **La décision de la tranche est tranchée, et dans le bon sens** : le SDK JS de Firebase est
  **servi depuis notre origine** (`web/firebase/`, versionné et empreinté par
  `tool/web_assets.sh`), la CSP de `context` n'a donc **pas** eu à gagner `gstatic.com`. La porte
  de sortie est dans `firebase_core_web` lui-même : si `window.firebase_core` est déjà posé, il
  n'injecte rien. Mesuré par `make push-probe` — CSP de production **et réseau extérieur coupé**
  (`--host-resolver-rules`) : SDK 12.19.0 chargé depuis `/firebase/*`, `[DEFAULT]` initialisé sur
  `nouvelle-vie-25eb5`. **Deux choses ajoutées en route** : `firebase-messaging.js` est retouché
  d'une chaîne (il importe le cœur par une URL `gstatic.com` écrite dans ses octets, le paquet npm
  aussi), et la version du SDK est désormais **contrainte** par
  `supportedFirebaseJsSdkVersion`, qu'un test lit dans le paquet résolu.
  **Reste la clé VAPID** (console Firebase → Cloud Messaging → Certificats push web), seule
  constante vide du chantier : sans elle aucun jeton n'est demandé et **aucune permission non
  plus**, par choix. Et **qu'une notification arrive ne se prouve que dans un navigateur**, après
  la pose de cette clé.
- **T3 — l'antenne** (`mobile`). `xhrSetup` + `withCredentials` dans `HlsContentPlayer`, et la
  **Media Session API** pour les contrôles sur l'écran verrouillé — `title`, `author` et `artUrl`
  sont déjà portés par `ContentRequest`, personne ne les lit sur le web.
- **T4 — le hors-ligne** (`mobile`). `BackgroundFetchDownloadBackend` derrière l'interface existante,
  rangement dans le Cache par `sw-offline.js`, `navigator.storage.persist()` et
  `navigator.storage.estimate()` à la place du canal natif de `disk_space`, lecture locale par URL
  de blob, et l'invitation à installer là où le bouton Télécharger refuse.

**Ordre de livraison** : T0 + T1 + T5, puis T2, puis T3, puis T4.

## 6. Ce qui ne s'automatisera pas

- **Le téléphone emprunté : fait le 2026-10-29** (§3), et il a renversé le §1 au lieu de le
  confirmer. Le banc est reproductible et tient en trois gestes — `python3 serveur.py` dans un
  dossier contenant la page de diagnostic et un lien vers `build/web`, `adb reverse tcp:8000
  tcp:8000`, puis `adb shell am start -a android.intent.action.VIEW -d http://localhost:8000`. **Ne
  jamais mesurer les capacités sur une origine en wifi** : sur `http://`, service worker, Cache,
  `navigator.storage` et Background Fetch sont absents de l'objet global et répondent « non » sans
  rien dire de l'appareil. À ajouter au protocole `docs/verification-sur-appareil.md`.
- **Trois inconnues restent, et elles attendent la vraie origine de T0** : la fabrication d'un paquet
  WebAPK (Chrome n'en forge pas pour `localhost`), l'ouverture du magasin Drift sur Chrome 106
  (`sqlite3.wasm` n'a jamais été demandé au banc), et la livraison réelle d'un push. Le même
  téléphone, une seconde fois, après T0.
- **Un téléphone plus ancien, si un fidèle en apporte un.** Le plancher annoncé est celui qui a été
  mesuré ; plus bas est plausible et non prouvé.
- La création de l'application web dans le projet Firebase (**faite**) et la sortie de la **clé
  VAPID** (console → *Cloud Messaging* → *Certificats push web*) : elle est la dernière chose qui
  manque à T2, et `kWebPushVapidKey` l'attend, vide et documentée. Puis, sur la vraie origine et
  avec un vrai appareil : **qu'une notification arrive**.
- L'entrée DNS, les gestes Caddy, la pose du bundle et le retour arrière sur le VPS.
- Ce que Chrome fait réellement quand il réclame de la place sur un téléphone saturé, et la survie
  d'un transfert Background Fetch à une mise en veille prolongée.
