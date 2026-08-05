# Binaires du magasin local sur le web

`sqlite3.wasm` et `drift_worker.js` sont les deux seules pièces que le magasin
local (Drift) ne peut pas obtenir depuis `pub.dev` : elles se téléchargent
depuis les releases GitHub et se **versionnent dans le dépôt**, comme les
polices et les images.

Sans elles, l'application compile et se lance sur le web, puis **lève à la
première ouverture de base** — une panne qui ne se voit qu'à l'exécution, et
seulement sur le web. C'est pour cela que leurs versions sont appariées à
`pubspec.lock` par un test (`test/data/local/web_assets_test.dart`).

## Versions embarquées

Elles doivent correspondre **exactement** aux versions verrouillées dans
`pubspec.lock`. Un `drift_worker.js` d'une autre version que le paquet `drift`
ne s'entend pas avec lui.

<!-- drift-web-assets
drift: 2.34.0
sqlite3: 3.5.1
-->

- `drift_worker.js` → `drift` **2.34.0**
- `sqlite3.wasm` → `sqlite3` **3.5.1**

## Les remplacer

Après toute montée de version de `drift` ou de `sqlite3` :

```bash
make web-assets     # re-télécharge les deux aux versions de pubspec.lock
```

puis mettre à jour le bloc `drift-web-assets` ci-dessus, et relancer
`flutter test`.
