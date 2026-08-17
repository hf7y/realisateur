#!/usr/bin/env bash
# selfdev-gh-app-register.sh -- register a self-dev GitHub App from a manifest
# and capture its private key, without anyone typing into a settings form.
#
# TRAPS (the rest of this header is in the vault):
# THE CODE EXPIRES IN ONE HOUR and is single-use. If the exchange fails, the
# App still EXISTS on GitHub with no key you hold -- delete it and re-run
# rather than trying to recover it, because a key cannot be re-minted.

set -uo pipefail

ACCOUNT=""; REPO=""; ROLE="writer"; PORT="8721"; OUT=""; MANIFEST_ONLY=0; IS_ORG=0; NO_OPEN=0
# Matches GitHub's OWN one-hour manifest-code lifetime, deliberately. A shorter
# wait is the worst possible setting: the server dies, the human clicks anyway
# on a code that is still valid, GitHub creates the App, and the pem goes to a
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
WAIT="3600"
OWNER="${SELFDEV_GH_OWNER:-hf7y}"
# Overridable so the test suite can point the exchange at a local stub. A
# hardcoded api.github.com would make the one step that handles the private key
# the one step no test can reach.
API="${SELFDEV_GH_API:-https://api.github.com}"
WEB="${SELFDEV_GH_WEB:-https://github.com}"
while [ $# -gt 0 ]; do
  case "$1" in
    --repo)   REPO="${2:-}"; shift ;;
    --org)    IS_ORG=1 ;;
    --owner)  OWNER="${2:-}"; shift ;;
    --port)   PORT="${2:-}"; shift ;;
    --timeout) WAIT="${2:-}"; shift ;;
    --out)    OUT="${2:-}"; shift ;;
    --reader) ROLE="reader" ;;
    --manifest-only) MANIFEST_ONLY=1 ;;
    --no-open) NO_OPEN=1 ;;
    -h|--help) sed -n '2,/^set -/p' "$0" | sed 's/^# \{0,1\}//;$d'; exit 0 ;;
    -*) echo "usage: $0 <account> [--repo R] [--reader] [--owner O] [--port N] [--out DIR] [--manifest-only]" >&2; exit 2 ;;
    *)  [ -z "$ACCOUNT" ] && ACCOUNT="$1" || { echo "usage: $0 <account> ..." >&2; exit 2; } ;;
  esac
  shift
done
[ -n "$ACCOUNT" ] || { echo "usage: $0 <account> [--repo R] [--reader] ..." >&2; exit 2; }
[ -n "$REPO" ] || REPO="$ACCOUNT"
OUT="${OUT:-$HOME/.config/selfdev}"

for c in python3 curl jq; do
  command -v "$c" >/dev/null || { echo "${0##*/}: FATAL: $c is required and not on PATH" >&2; exit 5; }
done

# The permission split from vault:realisateur/MONKEY.md §11. A WRITER is installed on the
# account's own repo alone; a READER is installed across the shared repos. The
# two cannot be one App: permissions are per-App, so a single App installed
# everywhere with Contents:write is write EVERYWHERE.
if [ "$ROLE" = reader ]; then
  APP_NAME="$ACCOUNT selfdev reader"
  PERMS='{"contents":"read","issues":"write","metadata":"read"}'
else
  APP_NAME="$ACCOUNT self-dev"
  PERMS='{"contents":"write","pull_requests":"write","issues":"write","metadata":"read"}'
fi

REDIRECT="http://127.0.0.1:$PORT/cb"
MANIFEST="$(jq -cn --arg name "$APP_NAME" --arg redir "$REDIRECT" \
  --arg url "https://github.com/$OWNER/realisateur" --argjson perms "$PERMS" '
  { name: $name,
    url: $url,
    redirect_url: $redir,
    public: false,
    default_events: [],
    default_permissions: $perms }')"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
FORM="$T/register.html"

# An auto-submitting form, because the manifest must arrive as a POST BODY --
# it cannot be a query string, and a human cannot paste it into a settings page.
{
  printf '<!doctype html><meta charset=utf-8><title>Register %s</title>\n' "$APP_NAME"
  printf '<body style="font:16px system-ui;margin:3em">\n'
  printf '<p>Creating GitHub App <b>%s</b> under <b>@%s</b>&hellip;</p>\n' "$APP_NAME" "$OWNER"
  # A personal account and an organization take DIFFERENT creation URLs, and
  # the wrong one is a 404 after the human has already clicked.
  if [ "$IS_ORG" -eq 1 ]; then
    printf '<form id=f method=post action="%s/organizations/%s/settings/apps/new">\n' "$WEB" "$OWNER"
  else
    printf '<form id=f method=post action="%s/settings/apps/new">\n' "$WEB"
  fi
  printf '<input type=hidden name=manifest id=m>\n'
  printf '<button type=submit>Continue to GitHub</button></form>\n'
  printf '<script>document.getElementById("m").value=%s;document.getElementById("f").submit()</script>\n' \
    "$(printf '%s' "$MANIFEST" | jq -Rs .)"
} > "$FORM"
# Survives the trap: the browser needs it after this script's temp dir would go.
#
# Under $HOME and NOT /tmp, deliberately. /tmp is not reliably the same
# directory for the script and for the browser -- a sandboxed or namespaced
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
KEEPDIR="${XDG_CACHE_HOME:-$HOME/.cache}/selfdev"
mkdir -p "$KEEPDIR"
KEEP="$KEEPDIR/register-$ACCOUNT-$$.html"
cp "$FORM" "$KEEP"

echo "== register $APP_NAME ($ROLE) under @$OWNER =="
echo "  manifest permissions: $PERMS"
echo "  form: $KEEP"

if [ "$MANIFEST_ONLY" -eq 1 ]; then
  echo
  echo "manifest-only: open that file in a browser on a host that can reach"
  echo "127.0.0.1:$PORT, or POST the manifest yourself. Nothing was created."
  exit 0
fi

# --- the callback ------------------------------------------------------------
cat > "$T/cb.py" <<'PY'
import http.server, socketserver, sys, urllib.parse
PORT = int(sys.argv[1])
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        code = (q.get("code") or [""])[0]
        body = b"<h2>Registered. You can close this tab.</h2>" if code \
               else b"<h2>No code in the redirect. Check the terminal.</h2>"
        self.send_response(200 if code else 400)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers(); self.wfile.write(body)
        if code:
            print(code, flush=True)
            # Exit only AFTER the browser has the response, or the tab errors
            # and the human cannot tell a success from a crash.
            raise SystemExit(0)
    def log_message(self, *a): pass
socketserver.TCPServer.allow_reuse_address = True
try:
    with socketserver.TCPServer(("127.0.0.1", PORT), H) as s:
        s.handle_request(); s.handle_request()
except SystemExit:
    pass
PY

# Open a browser ONLY on an interactive run. A script that hijacks the desktop
# from a non-tty context is wrong in every direction: cron, CI, a background
# job, and -- measured 2026-08-07 -- this script's OWN TEST SUITE, which runs it
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
if [ "$NO_OPEN" -eq 0 ] && [ -t 1 ] && command -v xdg-open >/dev/null; then
  xdg-open "$KEEP" >/dev/null 2>&1 &
fi
echo
echo "  Waiting on http://127.0.0.1:$PORT ... open the form above if it did not"
echo "  open itself, then click Create GitHub App. Ctrl-C to abandon."
CODE="$(timeout "$WAIT" python3 "$T/cb.py" "$PORT" | head -1)"
if [ -z "$CODE" ]; then
  echo "  FATAL: no code received (timed out after ${WAIT}s, or the port was busy)." >&2
  echo "  If GitHub DID create the App, delete it -- its key can never be minted." >&2
  exit 5
fi
echo "  got a manifest code."

# --- the exchange ------------------------------------------------------------
RESP="$(curl -sS -X POST -H "Accept: application/vnd.github+json" \
  "$API/app-manifests/$CODE/conversions")" || {
  echo "  FATAL: the conversion call did not complete. The App may exist without a key you hold." >&2; exit 5; }

PEM="$(printf '%s' "$RESP" | jq -r '.pem // empty')"
APP_ID="$(printf '%s' "$RESP" | jq -r '.id // empty')"
SLUG="$(printf '%s' "$RESP" | jq -r '.slug // empty')"
if [ -z "$PEM" ] || [ -z "$APP_ID" ]; then
  echo "  FATAL: no pem in the conversion response: $(printf '%s' "$RESP" | jq -r '.message // .' | head -3)" >&2
  echo "  The App may exist on GitHub with a key nobody holds -- the manifest code is" >&2
  echo "  single-use, expires in an hour, and NO endpoint mints a key for an existing App." >&2
  echo "  Check https://github.com/settings/apps, DELETE it if it is there, and re-run." >&2
  exit 5
fi

mkdir -p "$OUT" && chmod 700 "$OUT"
KEYFILE="$OUT/$SLUG.pem"
# umask BEFORE the write, not chmod after: a world-readable instant is a leak.
( umask 077; printf '%s' "$PEM" > "$KEYFILE" )
CONF="$OUT/gh-app.conf"
( umask 077; { printf '# written by selfdev-gh-app-register.sh for %s\n' "$ACCOUNT"
  printf 'SELFDEV_APP_ID=%s\n' "$APP_ID"
  printf 'SELFDEV_APP_KEY=%s\n' "$KEYFILE"
  printf 'SELFDEV_GH_OWNER=%s\n' "$OWNER"; } > "$CONF" )

echo
echo "  app id : $APP_ID"
echo "  slug   : $SLUG"
echo "  key    : $KEYFILE (mode 600)"
echo "  conf   : $CONF"
echo
echo "NOT INSTALLED YET -- and no API can do it. One human click:"
if [ "$ROLE" = reader ]; then
  echo "  https://github.com/settings/apps/$SLUG/installations"
  echo "  -> Only select repositories -> the SHARED repos (realisateur, scheduler, senechal)"
else
  echo "  https://github.com/settings/apps/$SLUG/installations"
  echo "  -> Only select repositories -> $OWNER/$REPO ONLY"
fi
echo
echo "Then, on $ACCOUNT's host:  selfdev-gh-app.sh --check"
exit 0
