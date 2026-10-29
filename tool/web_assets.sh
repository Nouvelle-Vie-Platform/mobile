#!/usr/bin/env bash
#
# Re-télécharge les actifs que le web exige et que `pub.dev` ne sert pas — les
# deux binaires du magasin local, le lecteur HLS, et le SDK JS de Firebase —,
# puis réécrit les blocs de contrôle de `web/WEB_ASSETS.md`.
#
# Pourquoi une commande plutôt qu'une procédure écrite : les trois choses qui
# doivent rester d'accord — la version, le fichier téléchargé et ce que le dépôt
# en déclare — ne peuvent diverger que si on les bouge séparément. Ici elles
# sortent d'un seul geste.
#
# Usage : make web-assets

set -euo pipefail

cd "$(dirname "$0")/.."

MANIFEST="web/WEB_ASSETS.md"

# `hls.js` n'est pas un paquet Dart : sa version ne se lit dans aucun
# `pubspec.lock`, elle s'épingle **ici**. Monter de version se fait en changeant
# cette ligne et en relançant `make web-assets` — le bloc de contrôle et le test
# suivent tout seuls.
HLS_VERSION="1.7.0"

# Le SDK JS de Firebase (#283). Sa version ne s'épingle pas librement : elle
# doit être celle que `firebase_core_web` attend
# (`supportedFirebaseJsSdkVersion`), sans quoi le paquet imprime un
# avertissement et plus personne ne sait ce qui est testé contre quoi. C'est
# `test/data/local/web_assets_test.dart` qui tient cet accord — il lit la
# constante dans le paquet résolu, et rougira donc à la prochaine montée de
# `firebase_core`. Remède : changer cette ligne, relancer `make web-assets`.
FIREBASE_SDK_VERSION="12.19.0"

# Version résolue d'un paquet dans pubspec.lock.
locked_version() {
  awk -v pkg="  $1:" '
    $0 == pkg { found = 1; next }
    found && /^    version:/ { gsub(/[",]/, "", $2); print $2; exit }
    found && /^  [a-z_]+:/ { exit }
  ' pubspec.lock
}

DRIFT_VERSION="$(locked_version drift)"
SQLITE_VERSION="$(locked_version sqlite3)"

if [ -z "$DRIFT_VERSION" ] || [ -z "$SQLITE_VERSION" ]; then
  echo "✗ Impossible de lire les versions de drift/sqlite3 dans pubspec.lock." >&2
  exit 1
fi

echo "▶ drift $DRIFT_VERSION · sqlite3 $SQLITE_VERSION"

download() {
  local url="$1" dest="$2"
  echo "  ↓ $dest"
  if ! curl -fsSL --retry 2 -o "$dest.tmp" "$url"; then
    rm -f "$dest.tmp"
    echo "✗ Téléchargement impossible : $url" >&2
    echo "  Cette version publie-t-elle bien cet asset ?" >&2
    exit 1
  fi
  mv "$dest.tmp" "$dest"
}

download \
  "https://github.com/simolus3/drift/releases/download/drift-$DRIFT_VERSION/drift_worker.js" \
  web/drift_worker.js

download \
  "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-$SQLITE_VERSION/sqlite3.wasm" \
  web/sqlite3.wasm

echo "▶ hls.js $HLS_VERSION"

# La build **complète**, pas `hls.light` : celle-ci laisse de côté les pistes
# audio alternées, et un enseignement peut en porter (traduction).
download \
  "https://cdn.jsdelivr.net/npm/hls.js@$HLS_VERSION/dist/hls.min.js" \
  web/hls.min.js

echo "▶ SDK JS de Firebase $FIREBASE_SDK_VERSION"

# **Servi depuis notre origine, et c'est tout l'objet de la mesure de T2.**
# Sans ces deux fichiers, `firebase_core_web` les injecte depuis `gstatic.com` à
# l'appel de `Firebase.initializeApp()` — ce que `web/WEB_ASSETS.md` interdit, et
# ce que la CSP de l'origine refuse de toute façon (`script-src 'self'`).
mkdir -p web/firebase

download \
  "https://www.gstatic.com/firebasejs/$FIREBASE_SDK_VERSION/firebase-app.js" \
  web/firebase/firebase-app.js

download \
  "https://www.gstatic.com/firebasejs/$FIREBASE_SDK_VERSION/firebase-messaging.js" \
  web/firebase/firebase-messaging.js

# ⚠️ **La seule retouche faite à un actif tiers de ce dépôt, et elle est
# indispensable.** `firebase-messaging.js` importe `firebase-app.js` par une URL
# `https://www.gstatic.com/…` **écrite en dur dans ses octets** — et le paquet
# npm porte exactement les mêmes (octet pour octet : il n'existe pas de variante
# auto-hébergeable). Servir le fichier tel quel depuis chez nous ne déplacerait
# donc que ses 37 ko : le navigateur irait quand même chercher les 106 ko du
# cœur chez Google.
#
# La substitution est unique et vérifiée (tout autre compte échoue), et
# l'empreinte du bloc de contrôle couvre le fichier retouché. Le chemin relatif
# résout vers la même URL absolue que celle par laquelle Dart importe le cœur :
# les deux modules n'existent ainsi qu'une fois dans la carte du navigateur,
# condition pour que le module de messagerie voie l'application initialisée.
python3 - "$FIREBASE_SDK_VERSION" <<'PY'
import sys

version = sys.argv[1]
path = 'web/firebase/firebase-messaging.js'
cdn = 'https://www.gstatic.com/firebasejs/%s/firebase-app.js' % version
code = open(path, encoding='utf-8').read()
count = code.count(cdn)
if count != 1:
    sys.exit(
        'firebase-messaging.js : %d import(s) de « %s » au lieu d\'un seul. '
        'Le bundle a changé de forme — relire ses imports avant de republier.'
        % (count, cdn)
    )
open(path, 'w', encoding='utf-8').write(code.replace(cdn, './firebase-app.js'))
PY

sha() { shasum -a 256 "$1" | cut -d' ' -f1; }

DRIFT_SHA="$(sha web/drift_worker.js)"
SQLITE_SHA="$(sha web/sqlite3.wasm)"
HLS_SHA="$(sha web/hls.min.js)"
FB_APP_SHA="$(sha web/firebase/firebase-app.js)"
FB_MSG_SHA="$(sha web/firebase/firebase-messaging.js)"

# Réécrit le bloc de contrôle entre les marqueurs, sans toucher au reste du
# document (qui explique le pourquoi, et qui s'édite à la main).
python3 - "$MANIFEST" <<PY
import re, sys

path = sys.argv[1]
blocks = {
    'drift-web-assets': """<!-- drift-web-assets
drift: $DRIFT_VERSION
drift_worker.js: sha256:$DRIFT_SHA
sqlite3: $SQLITE_VERSION
sqlite3.wasm: sha256:$SQLITE_SHA
-->""",
    'hls-web-asset': """<!-- hls-web-asset
hls.js: $HLS_VERSION
hls.min.js: sha256:$HLS_SHA
-->""",
    'firebase-web-asset': """<!-- firebase-web-asset
firebase-js-sdk: $FIREBASE_SDK_VERSION
firebase/firebase-app.js: sha256:$FB_APP_SHA
firebase/firebase-messaging.js: sha256:$FB_MSG_SHA
-->""",
}

text = open(path, encoding='utf-8').read()
for marker, block in blocks.items():
    text, count = re.subn(
        r'<!-- ' + marker + r'.*?-->', lambda _: block, text, flags=re.DOTALL
    )
    if count != 1:
        sys.exit('Bloc « ' + marker + ' » introuvable dans ' + path)
open(path, 'w', encoding='utf-8').write(text)
PY

echo "✓ web/ à jour, $MANIFEST réécrit. Relancer : flutter test"
