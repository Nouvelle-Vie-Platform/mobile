#!/usr/bin/env bash
#
# Lance la sonde du lecteur web (`tool/hls_probe/main.dart`) dans un Chrome sans
# tête et imprime ce qu'elle a observé.
#
# Ce que ça prouve, et que rien d'autre ne prouve : que `web/hls.min.js` se
# charge, que `HlsContentPlayer` ouvre un vrai `.m3u8`, que la position avance,
# que la durée arrive, que le déplacement se borne à la fin du média. Ni
# `flutter test` (VM, pas de DOM) ni `flutter build web` (ça compile, ça ne joue
# pas) ne peuvent le dire.
#
# Exige **Chrome et le réseau**. Ne tourne pas en CI, et n'est pas un test.
#
# Usage : make hls-probe

set -euo pipefail

cd "$(dirname "$0")/.."

PORT="${HLS_PROBE_PORT:-8732}"
CHROME="${CHROME_BIN:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"

if [ ! -x "$CHROME" ]; then
  echo "✗ Chrome introuvable : $CHROME (surcharger par CHROME_BIN=…)" >&2
  exit 1
fi

echo "▶ Compilation de la sonde…"
flutter build web -t tool/hls_probe/main.dart --no-wasm-dry-run >/dev/null

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
