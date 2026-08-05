# Binaires du magasin local sur le web

`sqlite3.wasm` et `drift_worker.js` sont les deux seules pièces que le magasin
local (Drift) ne peut pas obtenir depuis `pub.dev` : elles se téléchargent
depuis les releases GitHub et se **versionnent dans le dépôt**, comme les
polices et les images.

Sans elles — ou avec la mauvaise version —, l'application compile, se lance, et
**lève à la première ouverture de base**. La panne ne se voit qu'à l'exécution,
et seulement sur le web : ni `flutter analyze` ni `flutter build web` ne peuvent
l'attraper, puisqu'il n'y a rien à compiler. C'est exactement l'oubli qu'une
montée de version de `drift` provoque sans rien dire.

## Ne rien mettre à jour à la main

```bash
make web-assets
```

Cette commande lit les versions **verrouillées par `pubspec.lock`**, télécharge
les deux fichiers correspondants et réécrit le bloc de contrôle ci-dessous. Les
trois choses qui doivent rester d'accord — la version du paquet, les octets
téléchargés et ce que le dépôt en déclare — sortent ainsi d'une seule source, en
un seul geste. Relancer `flutter test` ensuite.

## Bloc de contrôle

Vérifié par `test/data/local/web_assets_test.dart`, qui compare ces versions à
`pubspec.lock` et ces empreintes aux fichiers réellement présents.

<!-- drift-web-assets
drift: 2.34.0
drift_worker.js: sha256:b8b9f88cdfa0582eedacf3b55f6133b7d9bea7c8e74d4dc019a380da9976a7a8
sqlite3: 3.5.1
sqlite3.wasm: sha256:13d3f11d05b39ba0618a7115fb41640a5d48b6300f5d3f325f554b42bd6688a4
-->

## Ce que ce garde-fou ne couvre pas

Il vérifie que les fichiers présents sont ceux que le dépôt déclare, et que ces
versions sont celles du `pubspec.lock`. Il **n'ouvre aucune base dans un
navigateur** : tant qu'aucun écran ne lit le magasin, ce chemin d'exécution
n'est vérifié nulle part. Il le sera au premier écran branché.
