#!/usr/bin/env bash
#
# Re-télécharge les deux binaires que le magasin local exige sur le web, aux
# versions **verrouillées par `pubspec.lock`**, et réécrit le bloc de contrôle
# de `web/WEB_ASSETS.md`.
#
# Pourquoi une commande plutôt qu'une procédure écrite : les trois choses qui
# doivent rester d'accord — la version du paquet, le fichier téléchargé et ce
# que le dépôt en déclare — ne peuvent diverger que si on les bouge séparément.
# Ici elles sortent toutes de `pubspec.lock`, en un seul geste.
#
# Usage : make web-assets

set -euo pipefail

cd "$(dirname "$0")/.."

MANIFEST="web/WEB_ASSETS.md"

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

sha() { shasum -a 256 "$1" | cut -d' ' -f1; }

DRIFT_SHA="$(sha web/drift_worker.js)"
SQLITE_SHA="$(sha web/sqlite3.wasm)"

# Réécrit le bloc de contrôle entre les marqueurs, sans toucher au reste du
# document (qui explique le pourquoi, et qui s'édite à la main).
python3 - "$MANIFEST" <<PY
import re, sys

path = sys.argv[1]
block = """<!-- drift-web-assets
drift: $DRIFT_VERSION
drift_worker.js: sha256:$DRIFT_SHA
sqlite3: $SQLITE_VERSION
sqlite3.wasm: sha256:$SQLITE_SHA
-->"""

text = open(path, encoding='utf-8').read()
updated, count = re.subn(
    r'<!-- drift-web-assets.*?-->', lambda _: block, text, flags=re.DOTALL
)
if count != 1:
    sys.exit('Bloc « drift-web-assets » introuvable dans ' + path)
open(path, 'w', encoding='utf-8').write(updated)
PY

echo "✓ web/ à jour, $MANIFEST réécrit. Relancer : flutter test"
