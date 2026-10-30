#!/usr/bin/env bash
#
# Lance la sonde du lecteur web (`tool/db_probe/main.dart`) dans un Chrome sans
# tête et imprime ce qu'elle a observé.
#
# Ce que ça prouve, et que rien d'autre ne prouve : que `sqlite3.wasm` et
# `drift_worker.js` s'instancient ensemble, que la base s'ouvre et qu'elle
# répond à une requête. `flutter test` tourne sur la VM — c'est l'implémentation
# NATIVE qui y répond — et `flutter build web` compile sans rien exécuter. Entre
# les deux il n'y avait que la console d'un fidèle : le 29/10/2026, un worker
# désaccordé du wasm a tenu le magasin fermé pendant six semaines sans qu'aucun
# garde-fou ne bronche.
#
# Exige **Chrome** (le réseau, non : tout est servi en local). Ne tourne pas en CI, et n'est pas un test.
#
# **Le harnais sert aussi d'autres sondes** : il compile le point d'entrée qu'on
# lui donne, le sert en local, et imprime ce que la page lui a posté. La sonde
# du magasin de la Bible (`tool/bible_probe/main.dart`) s'en sert telle quelle.
#
# Usage : make db-probe
#         make bible-probe
#         PROBE_TARGET=tool/<x>/main.dart ./tool/db_probe.sh

set -euo pipefail

cd "$(dirname "$0")/.."

PORT="${DB_PROBE_PORT:-8733}"
TARGET="${PROBE_TARGET:-tool/db_probe/main.dart}"
CHROME="${CHROME_BIN:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"

if [ ! -x "$CHROME" ]; then
  echo "✗ Chrome introuvable : $CHROME (surcharger par CHROME_BIN=…)" >&2
  exit 1
fi

echo "▶ Compilation de la sonde ($TARGET)…"
# `--no-web-resources-cdn` comme partout ailleurs : la sonde doit tourner sur
# le moteur que nous servons, pas sur celui de `gstatic.com`. Sans ce drapeau
# elle prouverait que `hls.js` joue dans un Chrome assisté par un CDN — ce que
# le fidèle n'a pas.
flutter build web -t "$TARGET" --no-wasm-dry-run \
  --no-web-resources-cdn >/dev/null

# Le navigateur sans tête ne vit que jusqu'à l'événement `load` de la page. La
# sonde, elle, écoute pendant une quinzaine de secondes. Cette image que le
# serveur fait attendre retient donc `load` — sans elle, Chrome fermerait la
# page avant le premier segment.
python3 - build/web/index.html <<'PY'
import sys
path = sys.argv[1]
page = open(path, encoding='utf-8').read()
if '/tenir' not in page:
    open(path, 'w', encoding='utf-8').write(
        page.replace('</body>', '<img src="/tenir" alt=""></body>')
    )
PY

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "▶ Chrome sans tête sur http://127.0.0.1:$PORT …"

python3 - "$PORT" <<'PY' &
import http.server, sys, threading, time

ROOT = 'build/web'
done = threading.Event()
result = []


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def log_message(self, *args):
        pass

    def do_GET(self):
        # L'image qui retient l'événement `load` le temps de la sonde.
        if self.path.startswith('/tenir'):
            done.wait(90)
            self.send_response(404)
            self.end_headers()
            return
        super().do_GET()

    def do_POST(self):
        size = int(self.headers.get('Content-Length', 0))
        result.append(self.rfile.read(size).decode('utf-8', 'replace'))
        self.send_response(204)
        self.end_headers()
        done.set()


server = http.server.ThreadingHTTPServer(('127.0.0.1', int(sys.argv[1])), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()

if done.wait(120):
    print('\n=== Ce que la sonde a observé ===')
    print(result[0])
else:
    print('\n✗ La sonde n\'a rien renvoyé (réseau ? Chrome ?)', file=sys.stderr)
    sys.exit(1)

time.sleep(1)
server.shutdown()
PY
SERVER_PID=$!

sleep 2
"$CHROME" --headless --disable-gpu --no-sandbox --mute-audio \
  --autoplay-policy=no-user-gesture-required \
  --user-data-dir="$TMP/chrome" \
  --dump-dom "http://127.0.0.1:$PORT/" >/dev/null 2>&1 &
CHROME_PID=$!

wait "$SERVER_PID"
kill "$CHROME_PID" 2>/dev/null || true
