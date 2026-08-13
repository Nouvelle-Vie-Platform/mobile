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
drift: 2.34.0
drift_worker.js: sha256:b8b9f88cdfa0582eedacf3b55f6133b7d9bea7c8e74d4dc019a380da9976a7a8
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

## Ce que ces garde-fous ne couvrent pas

Ils vérifient que les fichiers présents sont ceux que le dépôt déclare, et que
les versions Drift sont celles du `pubspec.lock`. Ils **n'ouvrent aucune base et
ne lisent aucun flux dans un navigateur** : que `hls.js` joue réellement un
`.m3u8` ne se prouve que dans Chrome, à la main
(`flutter run -d chrome`). Voir `lib/data/players/media_element_playback.dart`
pour la part du lecteur web qui, elle, se teste sans navigateur.
