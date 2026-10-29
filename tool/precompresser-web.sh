#!/usr/bin/env bash
# Précompresse le bundle web en `.br`, à côté de chaque fichier.
#
# POURQUOI AU BUILD, ET NON DANS CADDY : le binaire Caddy standard ne sait
# compresser qu'en `zstd` et `gzip` — le brotli dynamique demande un greffon.
# `file_server { precompressed br … }` sert en revanche un `.br` posé à côté du
# fichier, sans aucun greffon. Et compresser une fois à `-q 11` au build vaut
# mieux que compresser à chaque requête : sur `main.dart.js`, 7 907 k → 1 593 k.
#
# BROTLI SEUL, PAS DE `.gz` : tout navigateur capable de faire tourner Flutter
# web parle brotli (Chrome 50, Safari 11, Firefox 44), et Caddy garde `encode
# gzip` en repli dynamique pour l'exception. Les `.gz` pesaient 12 Mo dans
# l'archive pour ne jamais être servis.
#
# Les images (`.webp`, `.png`) et les `.symbols` de CanvasKit sont écartés : les
# premières sont déjà compressées, les seconds ne sont jamais servis.
#
#   ./tool/precompresser-web.sh [dossier]      (défaut : build/web)
set -euo pipefail

dossier="${1:-build/web}"
[ -d "$dossier" ] || { echo "Dossier introuvable : $dossier" >&2; exit 1; }

# `-size +1k` : sous un kilo-octet, l'en-tête de compression coûte plus que le gain.
find "$dossier" -type f -size +1k \
  \( -name '*.js' -o -name '*.json' -o -name '*.html' -o -name '*.wasm' \
     -o -name '*.ttf' -o -name '*.otf' -o -name '*.css' -o -name '*.bin' \) \
  -exec brotli -f -q 11 {} \;

echo "précompressés : $(find "$dossier" -name '*.br' | wc -l | tr -d ' ') fichiers"
