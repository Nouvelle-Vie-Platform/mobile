#!/usr/bin/env bash
#
# Re-télécharge les trois actifs que le web exige et que `pub.dev` ne sert pas —
# les deux binaires du magasin local, et le lecteur HLS —, puis réécrit les
# blocs de contrôle de `web/WEB_ASSETS.md`.
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

sha() { shasum -a 256 "$1" | cut -d' ' -f1; }

DRIFT_SHA="$(sha web/drift_worker.js)"
SQLITE_SHA="$(sha web/sqlite3.wasm)"
HLS_SHA="$(sha web/hls.min.js)"

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
