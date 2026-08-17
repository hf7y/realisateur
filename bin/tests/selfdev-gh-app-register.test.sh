#!/usr/bin/env bash
#
# Usage: bin/tests/selfdev-gh-app-register.test.sh   (exit 0 = all pass)

set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/selfdev-gh-app-register.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }
command -v python3 >/dev/null || { echo "SKIP: python3 absent"; exit 0; }

T="$(mktemp -d)"; trap 'rm -rf "$T"; kill %1 2>/dev/null' EXIT
no()  { case "$2" in *"$3"*) bad "$1 (unexpected: $3)" ;; *) ok "$1" ;; esac; }

# Ports picked high and per-run-ish to avoid colliding with a real service.
CBPORT=18731; STUBPORT=18732
run() { env HOME="$T/home" TMPDIR="$T/tmp" "$@"; }
mkdir -p "$T/home" "$T/tmp"

echo "== selfdev-gh-app-register.test.sh =="

# --- A/B/C/D: the manifest, no network at all ---------------------------------
outA="$(run "$SCRIPT" ecosim --manifest-only --port "$CBPORT" 2>&1)"
has "A writer grants contents:write" "$outA" '"contents":"write"'
has "A nothing was created"          "$outA" "Nothing was created"
formA="$(printf '%s' "$outA" | sed -n 's/^  form: //p')"
has "A form posts to the personal endpoint" "$(cat "$formA")" 'action="https://github.com/settings/apps/new"'

outB="$(run "$SCRIPT" shared --reader --manifest-only --port "$CBPORT" 2>&1)"
has "B reader grants contents:read" "$outB" '"contents":"read"'
no  "B reader grants no write on contents" "$outB" '"contents":"write"'
no  "B reader has no pull_requests" "$outB" 'pull_requests'

outC="$(run "$SCRIPT" ecosim --org --owner acme --manifest-only --port "$CBPORT" 2>&1)"
formC="$(printf '%s' "$outC" | sed -n 's/^  form: //p')"
has "C org form posts to the org endpoint" "$(cat "$formC")" \
    'action="https://github.com/organizations/acme/settings/apps/new"'

# D: the manifest is a JSON document embedded as a JS string literal inside an
# HTML attribute. Two layers of quoting; parse both back.
manifest="$(python3 - "$formA" <<'PY'
import re, json, sys
h = open(sys.argv[1]).read()
m = re.search(r'\.value=("(?:[^"\\]|\\.)*");document', h, re.S)
print(m.group(1) if m else "", end="")
PY
)"
if inner="$(printf '%s' "$manifest" | jq -r . 2>/dev/null)" && printf '%s' "$inner" | jq -e . >/dev/null 2>&1; then
  ok "D embedded manifest survives both quoting layers"
  eq "D redirect_url points at the callback" \
     "$(printf '%s' "$inner" | jq -r .redirect_url)" "http://127.0.0.1:$CBPORT/cb"
  eq "D app is private" "$(printf '%s' "$inner" | jq -r .public)" "false"
else
  bad "D embedded manifest is not parseable JSON"
  bad "D redirect_url (skipped)"; bad "D app is private (skipped)"
fi

# --- the stub ------------------------------------------------------------------
# Serves POST /app-manifests/<code>/conversions. Reads its reply from a file so
# a case can flip it between success and error without a restart.
cat > "$T/stub.py" <<'PY'
import http.server, socketserver, sys, json
PORT = int(sys.argv[1]); REPLY = sys.argv[2]
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        mode = open(REPLY).read().strip()
        if mode == "ok":
            body = json.dumps({"id": 4520255, "slug": "ecosim-self-dev",
                               "client_id": "Iv23liTEST",
                               "pem": "-----BEGIN RSA PRIVATE KEY-----\nSTUBKEY\n-----END RSA PRIVATE KEY-----\n",
                               "webhook_secret": "s3cr3t"}).encode()
            self.send_response(201)
        else:
            body = json.dumps({"message": "Not Found"}).encode()
            self.send_response(404)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers(); self.wfile.write(body)
    def log_message(self, *a): pass
socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("127.0.0.1", PORT), H) as s:
    s.serve_forever()
PY
echo ok > "$T/reply"
python3 "$T/stub.py" "$STUBPORT" "$T/reply" &
for _ in 1 2 3 4 5 6 7 8 9 10; do
  curl -s -o /dev/null -X POST "http://127.0.0.1:$STUBPORT/x" && break
  sleep 0.2
done

# drive <port> -- plays the browser: waits for the callback to listen, then hits
# it with a code, exactly as GitHub's redirect would.
drive() {
  ( for _ in $(seq 1 60); do
      if curl -s -o /dev/null "http://127.0.0.1:$1/cb?code=TESTCODE"; then break; fi
      sleep 0.25
    done ) >/dev/null 2>&1 &
}

# --- E: the full flow ----------------------------------------------------------
echo ok > "$T/reply"
drive "$CBPORT"
outE="$(run env SELFDEV_GH_API="http://127.0.0.1:$STUBPORT" BROWSER=true \
        "$SCRIPT" ecosim --port "$CBPORT" --out "$T/outE" 2>&1)"; rcE=$?
eq  "E exits 0" "$rcE" "0"
has "E reports the app id" "$outE" "app id : 4520255"
has "E says NOT INSTALLED" "$outE" "NOT INSTALLED YET"
has "E prints an install URL" "$outE" "settings/apps/ecosim-self-dev/installations"
has "E scopes the install to one repo" "$outE" "hf7y/ecosim ONLY"
if [ -f "$T/outE/ecosim-self-dev.pem" ]; then
  ok "E wrote the pem"
  eq "E pem is mode 600" "$(stat -c %a "$T/outE/ecosim-self-dev.pem")" "600"
  has "E pem has the key body" "$(cat "$T/outE/ecosim-self-dev.pem")" "STUBKEY"
  has "E conf carries the app id" "$(cat "$T/outE/gh-app.conf")" "SELFDEV_APP_ID=4520255"
  eq "E conf is mode 600" "$(stat -c %a "$T/outE/gh-app.conf")" "600"
else
  bad "E wrote the pem"; bad "E pem is mode 600"; bad "E pem has the key body"
  bad "E conf carries the app id"; bad "E conf is mode 600"
fi

# --- F: the exchange fails ------------------------------------------------------
echo err > "$T/reply"
drive "$CBPORT"
outF="$(run env SELFDEV_GH_API="http://127.0.0.1:$STUBPORT" BROWSER=true \
        "$SCRIPT" ecosim --port "$CBPORT" --out "$T/outF" 2>&1)"; rcF=$?
eq  "F exits 5 on a failed exchange" "$rcF" "5"
has "F warns the App may exist keyless" "$outF" "may exist"
[ -f "$T/outF/ecosim-self-dev.pem" ] && bad "F wrote no key" || ok "F wrote no key"

# --- G: no code ever arrives ----------------------------------------------------
# Nothing drives the callback. The script's OWN --timeout is what expires here,
# not an external one: `timeout 4 <script>` kills the script but leaves its
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
outG="$(run env SELFDEV_GH_API="http://127.0.0.1:$STUBPORT" BROWSER=true \
        "$SCRIPT" ecosim --port 18799 --timeout 2 --out "$T/outG" 2>&1)"; rcG=$?
[ "$rcG" -ne 0 ] && ok "G exits non-zero when no code arrives" \
                 || bad "G exits non-zero when no code arrives (got 0)"
[ -f "$T/outG/gh-app.conf" ] && bad "G wrote nothing" || ok "G wrote nothing"

echo
summary
[ "$fail" -eq 0 ] || exit 1
exit 0
