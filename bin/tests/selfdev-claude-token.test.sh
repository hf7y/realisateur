#!/usr/bin/env bash
# selfdev-claude-token.test.sh -- offline. HERMETICITY: no network, no sudo, no
# real /home, no real /etc/selfdev. Every path is a fixture under $TMP, reached
# through the same SELFDEV_* overrides production leaves unset, so the code
# under test is the code that runs (exit 0 = all pass).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOL="$ROOT/selfdev-claude-token.sh"
PASS=0; FAIL=0
ok()  { printf '  ok    %s\n' "$*"; PASS=$((PASS+1)); }
bad() { printf '  FAIL  %s\n' "$*"; FAIL=$((FAIL+1)); }
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 -- no '$3' in output" ;; esac; }
rc()  { [ "$2" = "$3" ] && ok "$1 (exit $3)" || bad "$1 -- exit $3, want $2"; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FAKE_TOKEN='sk-ant-oat01-TESTFIXTURE-not-a-real-credential'

mkhome() {  # mkhome <acct> -- a home shaped as provision-selfdev-user.sh leaves it
  mkdir -p "$TMP/home/$1/.claude"
  printf '%s' "$FAKE_TOKEN" > "$TMP/home/$1/.claude-token"
  python3 - "$TMP/home/$1/.claude/settings.json" "$FAKE_TOKEN" <<'PY'
import json, sys, pathlib
pathlib.Path(sys.argv[1]).write_text(json.dumps(
    {"env": {"CLAUDE_CODE_OAUTH_TOKEN": sys.argv[2]}, "model": "opus"}, indent=2) + "\n")
PY
}
run() { SELFDEV_TOKEN_FILE="$TMP/etc/claude-token" SELFDEV_HOME_ROOT="$TMP/home" \
        SELFDEV_ACCOUNTS="alpha beta" bash "$TOOL" "$@" 2>&1; }

echo "selfdev-claude-token.test.sh"

echo "== 1. THE ARGUMENT CONTRACT =========================================="
O="$(bash "$TOOL" 2>&1)"; R=$?
rc  "no argument is a usage error, not a default action" 1 "$R"
O="$(bash "$TOOL" --nonsense 2>&1)"; R=$?
rc  "an unknown argument is refused" 1 "$R"
has "...and names the argument" "$O" "--nonsense"
O="$(bash "$TOOL" --help 2>&1)"; R=$?
rc  "--help exits 0" 0 "$R"
has "...and states the order that matters" "$O" "ORDER MATTERS"

echo "== 2. --check REPORTS THE GAP AND EVERY STALE COPY ==================="
mkdir -p "$TMP/etc"; mkhome alpha; mkhome beta
O="$(run --check)"; R=$?
has "an absent host-wide copy is a GAP" "$O" "has not been installed"
has "...and every per-account copy is named" "$O" "stale copy: $TMP/home/alpha/.claude-token"
rc  "...and a GAP alone exits 2" 2 "$R"

# ABSENT is a fact; UNREADABLE is a domain we did not read. Only the second
# is BLIND, and conflating them is how a survey reports clean by not looking.
O="$(SELFDEV_TOKEN_FILE="$TMP/etc/claude-token" SELFDEV_HOME_ROOT="$TMP/home" \
     SELFDEV_ACCOUNTS="ghost" bash "$TOOL" --check 2>&1)"; R=$?
has "an account with no home is a fact, not a blindness" "$O" "no copy to hold"
# Match a BLIND FINDING line, not the tally line, which names BLIND always.
if printf '%s\n' "$O" | grep -q '^  BLIND'; then
  bad "an absent home was reported as a BLIND finding"
else
  ok "...and no BLIND finding is raised"
fi

echo "== 3. --purge REFUSES WITHOUT A REPLACEMENT =========================="
O="$(run --purge)"; R=$?
has "purging with no host-wide copy is refused" "$O" "refusing to purge"
has "...and says what it would cost" "$O" "produce nothing, silently"
rc  "...and that is BAD, not a no-op" 4 "$R"
[ -e "$TMP/home/alpha/.claude-token" ] && ok "...and it deleted nothing" \
                                       || bad "the refusal still removed a file"

echo "== 4. --purge IS DRY RUN UNTIL --apply ==============================="
printf '%s\n' "$FAKE_TOKEN" > "$TMP/etc/claude-token"
O="$(run --purge)"; R=$?
has "a dry run says so" "$O" "DRY RUN"
has "...and names each file it would shred" "$O" "would shred $TMP/home/alpha/.claude-token"
has "...and the settings key it would strip" "$O" "would strip CLAUDE_CODE_OAUTH_TOKEN"
[ -e "$TMP/home/alpha/.claude-token" ] && ok "...and changed nothing on disk" \
                                       || bad "the DRY RUN deleted a file"
grep -q CLAUDE_CODE_OAUTH_TOKEN "$TMP/home/beta/.claude/settings.json" \
  && ok "...and left settings.json untouched" || bad "the DRY RUN edited settings.json"

echo "== 5. --purge --apply REMOVES THE COPY, NOT THE CONFIG ==============="
O="$(run --purge --apply)"; R=$?
[ -e "$TMP/home/alpha/.claude-token" ] && bad ".claude-token survived --apply" \
                                       || ok ".claude-token is gone"
grep -q CLAUDE_CODE_OAUTH_TOKEN "$TMP/home/alpha/.claude/settings.json" \
  && bad "the token key survived --apply" || ok "the token key is out of settings.json"
python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d.get('model')=='opus' else 1)" \
  "$TMP/home/alpha/.claude/settings.json" \
  && ok "...and every UNRELATED setting is still there (model)" \
  || bad "--apply destroyed unrelated config"
python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$TMP/home/alpha/.claude/settings.json" \
  && ok "...and the file is still valid JSON" || bad "--apply left invalid JSON"
rc  "a completed purge exits 0" 0 "$R"

echo "== 6. IT NEVER PRINTS THE VALUE ======================================"
ALL="$(run --check; run --purge; run --purge --apply)"
case "$ALL" in
  *"$FAKE_TOKEN"*) bad "the token VALUE appeared in output -- this tool's output is quoted into issues" ;;
  *) ok "no mode printed the token value" ;;
esac

echo "== 7. THE RESOLVER IS ONE ANSWER ====================================="
# shellcheck source=../lib/selfdev-claude-token.sh
( . "$ROOT/lib/selfdev-claude-token.sh"
  [ "$(selfdev_token_path)" = "/etc/selfdev/claude-token" ] || exit 1 ) \
  && ok "the default path is /etc/selfdev/claude-token" || bad "default path moved"
( SELFDEV_TOKEN_FILE=/x/y; . "$ROOT/lib/selfdev-claude-token.sh"
  [ "$(selfdev_token_path)" = "/x/y" ] || exit 1 ) \
  && ok "SELFDEV_TOKEN_FILE overrides it" || bad "the override does not take"
( . "$ROOT/lib/selfdev-claude-token.sh"
  SELFDEV_TOKEN_FILE="$TMP/etc/claude-token" selfdev_token_export || exit 1
  [ "$CLAUDE_CODE_OAUTH_TOKEN" = "$FAKE_TOKEN" ] || exit 1 ) \
  && ok "selfdev_token_export puts it in the ENVIRONMENT, leaving no file" \
  || bad "selfdev_token_export did not export the value"
printf 'not-a-token\n' > "$TMP/etc/bogus"
( . "$ROOT/lib/selfdev-claude-token.sh"
  SELFDEV_TOKEN_FILE="$TMP/etc/bogus" selfdev_token_export; [ $? -eq 3 ] ) \
  && ok "a file that is not an oat01 token is rc 3, not a silent export" \
  || bad "a malformed token was exported anyway"
( . "$ROOT/lib/selfdev-claude-token.sh"
  SELFDEV_TOKEN_FILE="$TMP/etc/absent" selfdev_token_export; [ $? -eq 1 ] ) \
  && ok "an absent file is rc 1" || bad "an absent file did not report rc 1"

echo
printf 'selfdev-claude-token.test.sh: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
