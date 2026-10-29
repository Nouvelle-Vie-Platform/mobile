# Les actifs du web, versionnés dans le dépôt

Cinq fichiers que `pub.dev` ne sert pas et sans lesquels l'application web
compile, se lance, et **ne marche pas** :

- `sqlite3.wasm` et `drift_worker.js` — le magasin local (Drift) ;
- `hls.min.js` — le lecteur HLS de la médiathèque (#46) ;
- `firebase/firebase-app.js` et `firebase/firebase-messaging.js` — le SDK JS de
  Firebase, dont dépendent les annonces poussées (#283).

Tous se téléchargent depuis un dépôt tiers et se **versionnent ici**, comme les
polices et les images.

Sans eux — ou avec la mauvaise version —, la panne ne se voit qu'à l'exécution,
et seulement sur le web : ni `flutter analyze` ni `flutter build web` ne peuvent
l'attraper, puisqu'il n'y a rien à compiler. C'est exactement l'oubli qu'une
montée de version de `drift` provoque sans rien dire.

**Aucun CDN.** Une dépendance réseau tierce au démarrage est une panne de plus,
et un point de confiance de plus — sur du code qui s'exécute chez le fidèle.

## Ne rien mettre à jour à la main

```bash
make web-assets
```

Cette commande lit les versions **verrouillées par `pubspec.lock`** (Drift) et
celles **épinglées dans `tool/web_assets.sh`** (`hls.js` et le SDK Firebase, qui
ne sont pas des paquets Dart), télécharge les cinq fichiers et réécrit les blocs
de contrôle ci-dessous. Ce qui doit rester d'accord — la version, les octets téléchargés et
ce que le dépôt en déclare — sort ainsi d'une seule source, en un seul geste.
Relancer `flutter test` ensuite.

Monter `hls.js` de version se fait en changeant `HLS_VERSION` dans
`tool/web_assets.sh`, puis en relançant la commande.

## Blocs de contrôle

Vérifiés par `test/data/local/web_assets_test.dart`, qui compare ces versions à
`pubspec.lock` et ces empreintes aux fichiers réellement présents.

<!-- drift-web-assets
drift: 2.34.4
drift_worker.js: sha256:104bc207d4a3a0b70fc249fcd91d72b558cf7a8677fe49b41cafffe22a5144f4
sqlite3: 3.5.1
sqlite3.wasm: sha256:13d3f11d05b39ba0618a7115fb41640a5d48b6300f5d3f325f554b42bd6688a4
-->

<!-- hls-web-asset
hls.js: 1.7.0
hls.min.js: sha256:1f28c6a43deedddbd59aea4c119bd788f5e2347772c19da1f6f92f8d0032d9dc
-->

<!-- firebase-web-asset
firebase-js-sdk: 12.19.0
firebase/firebase-app.js: sha256:39a50952b5def557337b2290069c7d7371f3515ad46c44a43b9c520f734d8d14
firebase/firebase-messaging.js: sha256:61812e6268be19a6b26ff8322202d058f94b1083af6e46cc1e42d58c98bdf683
-->

`hls.min.js` n'a pas de version à confronter au `pubspec.lock` : elle est
épinglée dans `tool/web_assets.sh`, et le test vérifie que le fichier présent
est bien celui que ce bloc déclare.

## ⚠️ Le SDK de Firebase est servi depuis notre origine — et c'est une mesure

`firebase_core_web` **injecte** `firebase-app.js` et `firebase-messaging.js`
depuis `https://www.gstatic.com/firebasejs/<version>/` dès
`Firebase.initializeApp()`. C'est exactement ce que la règle ci-dessus interdit,
et la CSP de l'origine (`script-src 'self'`) le refuserait de toute façon —
**deux fois**, car le paquet charge ces modules par un `<script>` **en ligne**
qu'il fabrique lui-même : ouvrir la CSP à `www.gstatic.com` n'aurait donc même
pas suffi, il aurait fallu y ajouter `'unsafe-inline'`.

L'injection a une porte de sortie, et elle est dans le code du paquet
(`firebase_core_web-3.12.0`, `lib/src/firebase_core_web.dart`) :

```dart
Future<void> _initializeCore() async {
  // If Firebase is already available, core has already been initialized
  // (or the user has added the scripts to their html file).
  if (globalContext.getProperty('firebase_core'.toJS) != null) {
    return;
  }
```

`lib/data/push/web_push_transport.dart` importe donc les deux modules **depuis
notre origine** et les pose sur `window.firebase_core` et
`window.firebase_messaging` — les deux noms que les `@JS('firebase_core')` et
`@JS('firebase_messaging')` des paquets lisent — **avant** d'appeler
`Firebase.initializeApp()`. Rien n'est alors injecté, et rien ne sort de
l'origine. Mesuré par `make push-probe` : zéro requête vers `gstatic.com`, SDK
`12.19.0` lu, application Firebase initialisée.

Deux conséquences à connaître :

1. **La version est contrainte**, pas choisie : elle doit valoir
   `supportedFirebaseJsSdkVersion` du paquet. Le test lit la constante dans le
   paquet résolu et rougit à la prochaine montée de `firebase_core`.
2. **`firebase-messaging.js` est retouché d'une chaîne**, parce qu'il importe le
   cœur par une URL `gstatic.com` écrite dans ses octets (le paquet npm porte la
   même). `tool/web_assets.sh` la remplace par `./firebase-app.js`, échoue si
   elle n'apparaît pas exactement une fois, et l'empreinte ci-dessus couvre le
   fichier retouché. Un test interdit par ailleurs toute URL de CDN survivante
   dans `web/`.

## ⚠️ Le worker et le wasm doivent s'accorder — et ce n'est pas la même question

`drift_worker.js` n'est **pas** compilé par nous : c'est un artefact **publié par
drift**, qui embarque **sa propre** version du paquet `sqlite3`. `sqlite3.wasm`,
lui, vient de la version que notre `pubspec.lock` a résolue. Les deux peuvent
donc être parfaitement « à jour » chacun de son côté **et ne pas s'accorder**.

C'est arrivé le 29/10/2026, et ça a coûté une journée : `drift 2.34.0` publiait
un worker bâti sur un `sqlite3` antérieur à **3.4.0**, donc sans l'import
`xFileControl` — que notre wasm 3.5.1 réclame. Dans le navigateur :

```
LinkError: WebAssembly.instantiate(): Import #10 "dart" "xFileControl":
function import requires a callable
```

**Et nulle part ailleurs** : sur mobile, ce wasm ne sert pas. Tous les écrans
adossés au magasin tombaient, en annonçant au fidèle de vérifier sa connexion.

Les deux blocs de contrôle ci-dessous ne pouvaient pas le voir : ils comparent
des **versions déclarées** et des **empreintes**, jamais des symboles.
`test/data/local/drift_worker_imports_test.dart` tient désormais l'accord — il
lit les imports du module `dart` dans la section d'imports du wasm, et exige que
le worker les porte tous. Remède quand il rougit : monter `drift` jusqu'à une
version dont le worker les fournit, puis `make web-assets`.

## Ce que ces garde-fous ne couvrent pas

> **Et ce n'est pas une précaution de style — ça s'est payé.** Du 14/09 au
> 29/10/2026, `sqlite3.wasm` et `drift_worker.js` étaient présents, à la bonne
> version, avec la bonne empreinte… et **le magasin local n'a jamais ouvert dans
> un navigateur** : `AppDatabase.defaults()` appelait `driftDatabase()` sans son
> paramètre `web:`, que `drift_flutter` exige sur cette cible. La base levait
> **avant** d'aller chercher ces fichiers — mesuré : `sqlite3.wasm` n'a jamais
> été demandé une seule fois. Les tests ci-dessous étaient verts tout du long,
> et ils avaient raison : ils vérifient des octets, pas une ouverture.
> `test/data/local/drift_web_options_test.dart` garde désormais l'appel.



Ils vérifient que les fichiers présents sont ceux que le dépôt déclare, et que
les versions Drift sont celles du `pubspec.lock`. Ils **n'ouvrent aucune base et
ne lisent aucun flux dans un navigateur** : que `hls.js` joue réellement un
`.m3u8` ne se prouve que dans Chrome, à la main
(`flutter run -d chrome`). Voir `lib/data/players/media_element_playback.dart`
pour la part du lecteur web qui, elle, se teste sans navigateur.
