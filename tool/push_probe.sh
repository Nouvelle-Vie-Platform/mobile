#!/usr/bin/env bash
#
# Lance la sonde du push web (`tool/push_probe/main.dart`) dans un Chrome sans
# tête et imprime ce qu'elle a observé.
#
# CE QU'ELLE PROUVE, ET QUE RIEN D'AUTRE NE PROUVE : que le SDK JS de Firebase
# se charge **depuis notre origine**, et que `Firebase.initializeApp()`
# n'injecte donc rien depuis `gstatic.com`. Deux contraintes rendent la preuve
# serrée :
#
#   · le serveur pose LA CSP DE PRODUCTION (`script-src 'self'
#     'wasm-unsafe-eval'`, le bloc Caddy du dépôt `context`) — un script injecté
#     depuis gstatic.com y serait refusé deux fois, par l'origine et parce que
#     le paquet l'injecte en ligne ;
#   · Chrome tourne avec `--host-resolver-rules` qui ne connaît que
#     `127.0.0.1` : TOUT hôte extérieur est injoignable. Si l'initialisation
#     réussit dans ces conditions, c'est que rien n'est venu du dehors.
#
# Le journal des requêtes servies est imprimé avec le relevé : on y voit les
# deux fichiers du SDK partir de chez nous.
#
# Exige **Chrome**. Ne tourne pas en CI, et n'est pas un test.
#
# Usage : make push-probe

set -euo pipefail

cd "$(dirname "$0")/.."

PORT="${PUSH_PROBE_PORT:-8733}"
CHROME="${CHROME_BIN:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"

if [ ! -x "$CHROME" ]; then
  echo "✗ Chrome introuvable : $CHROME (surcharger par CHROME_BIN=…)" >&2
  exit 1
fi

echo "▶ Compilation de la sonde…"
# Les trois drapeaux de production, et ils comptent tous ici :
# `--no-web-resources-cdn` (CanvasKit depuis notre origine), `--csp` (sans lui
# dart2js fabrique du code à l'exécution et la CSP ci-dessous tue la page),
# `--base-href /` (c'est contre lui que `importModule` résout `firebase/`).
flutter build web -t tool/push_probe/main.dart --no-wasm-dry-run \
  --no-web-resources-cdn --csp --base-href / >/dev/null

# Le navigateur sans tête ne vit que jusqu'à l'événement `load`. Cette image que
# le serveur fait attendre le retient le temps que la sonde parle.
python3 - build/web/index.html <<'PY'
import sys
path = sys.argv[1]
page = open(path, encoding='utf-8').read()
if '/tenir' not in page:
    open(path, 'w', encoding='utf-8').write(
        page.replace('</body>', '<img src="/tenir" alt=""></body>')
    )
PY

echo "▶ Chrome sans tête sur http://127.0.0.1:$PORT (réseau extérieur coupé)…"

python3 - "$PORT" <<'PY' &
import http.server, sys, threading, time

ROOT = 'build/web'
done = threading.Event()
result = []
served = []

# La CSP du bloc Caddy de l'app web (dépôt `context`,
# `infra/caddy/app-web.caddy`), recopiée telle quelle.
CSP = (
    "default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; "
    "style-src 'self' 'unsafe-inline'; font-src 'self' data:; "
    "img-src 'self' data: blob:; media-src 'self' blob: data:; "
    "connect-src 'self'; worker-src 'self' blob:; manifest-src 'self'; "
    "base-uri 'self'; object-src 'none'; frame-ancestors 'none'"
)


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def log_message(self, *args):
        pass

    def end_headers(self):
        self.send_header('Content-Security-Policy', CSP)
        super().end_headers()

    def do_GET(self):
        served.append(self.path)
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
    print('\n=== Ce que le serveur a servi (tout vient donc de notre origine) ===')
    for path in served:
        if path.startswith('/tenir'):
            continue
        print(' ', path)
else:
    print('\n✗ La sonde n\'a rien renvoyé (Chrome ?)', file=sys.stderr)
    sys.exit(1)

time.sleep(1)
server.shutdown()
PY
SERVER_PID=$!

sleep 2
# `--host-resolver-rules` : rien n'est résoluble hors de la boucle locale.
# C'est ce qui fait de cette sonde une **mesure** et non une observation.
"$CHROME" --headless --disable-gpu --no-sandbox \
  --host-resolver-rules="MAP * ~NOTFOUND, EXCLUDE 127.0.0.1" \
  --user-data-dir="$(mktemp -d)/chrome" \
  --dump-dom "http://127.0.0.1:$PORT/" >/dev/null 2>&1 &
CHROME_PID=$!

wait "$SERVER_PID"
kill "$CHROME_PID" 2>/dev/null || true
