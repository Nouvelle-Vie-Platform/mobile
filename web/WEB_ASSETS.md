# Les actifs du web, versionnés dans le dépôt

Trois fichiers que `pub.dev` ne sert pas et sans lesquels l'application web
compile, se lance, et **ne marche pas** :

- `sqlite3.wasm` et `drift_worker.js` — le magasin local (Drift) ;
- `hls.min.js` — le lecteur HLS de la médiathèque (#46).

Tous trois se téléchargent depuis un dépôt tiers et se **versionnent ici**,
comme les polices et les images.

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

Cette commande lit les versions **verrouillées par `pubspec.lock`** (Drift), la
version **épinglée dans `tool/web_assets.sh`** (`hls.js`, qui n'est pas un
paquet Dart), télécharge les trois fichiers et réécrit les blocs de contrôle
ci-dessous. Ce qui doit rester d'accord — la version, les octets téléchargés et
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

`hls.min.js` n'a pas de version à confronter au `pubspec.lock` : elle est
épinglée dans `tool/web_assets.sh`, et le test vérifie que le fichier présent
est bien celui que ce bloc déclare.

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
## L'outil qui manquait : `make db-probe`

Entre `flutter test` — qui tourne sur la **VM**, où c'est l'implémentation
**native** qui répond — et `flutter build web` — qui compile sans rien exécuter
—, **rien n'ouvrait jamais cette base dans un navigateur**. Ce document le
disait depuis le début (« ils n'ouvrent aucune base »), et personne n'en avait
tiré l'outil ; il a fallu la console d'un fidèle pour voir le défaut.

`make db-probe` ouvre `AppDatabase.defaults()` dans un Chrome sans tête, lui
demande `select sqlite_version()`, lit les curseurs et imprime son verdict. Tout
est servi en local, le réseau n'est pas requis. Ce n'est **pas un test** et la
CI ne le lance pas — mais c'est ce qu'on lance après toute montée de `drift`,
`sqlite3` ou `drift_flutter`, avant de croire une suite verte.

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
