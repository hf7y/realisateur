#!/usr/bin/env bash
#
# selfdev-permissions-provision.test.sh -- witness for
# bin/selfdev-permissions-provision.sh.
#
#
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
REPO_BIN="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_BIN/selfdev-permissions-provision.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# shellcheck disable=SC1007  # `SUDO= cmd` is a deliberate per-command env
# override setting SUDO to the empty string, not a mistyped assignment: it
# is what keeps every case in this file from invoking sudo.
WANT="$(SUDO= "$SCRIPT" --print)"

mkhome() { # $1 = root name, $2 = account, $3 = settings content ('' = no file)
  mkdir -p "$T/$1/$2/.claude"
  [ -n "$3" ] && printf '%s\n' "$3" > "$T/$1/$2/.claude/settings.json"
  return 0
}
correct() { jq -cn --argjson w "$WANT" --arg tmpdir "$T/$1/$2/tmp" \
  '{permissions:$w, env:{TMPDIR:$tmpdir}}'; }  # a fully-correct settings.json body for $1/$2
# shellcheck disable=SC1007  # see the note on WANT above: empty SUDO on purpose.
run() { local r="$1"; shift; HOME_ROOT="$T/$r" SUDO= "$SCRIPT" "$@" 2>&1; }

# --- A/B/C/D/E: one tree carrying every shape -------------------------------
mkhome h1 blank    '{"env":{"CLAUDE_CODE_OAUTH_TOKEN":"secret"},"enabledPlugins":["honey"]}'
mkhome h1 partial  '{"permissions":{"allow":["WebSearch","WebFetch"]}}'
mkhome h1 correct  "$(correct h1 correct)"
mkhome h1 broken   'this is not json {{{'
mkhome h1 zach     '{"env":{}}'
mkdir -p "$T/h1/correct/tmp"; chmod 700 "$T/h1/correct/tmp"

out="$(run h1)"; run h1 >/dev/null 2>&1; got=$?
has  "A: a missing permissions key is DRIFT"  "$out" "DRIFT blank"
has  "B: a partial permissions key is DRIFT"  "$out" "DRIFT partial"
hasnt "B: and is never reported ok"           "$out" "ok    partial"
has  "C: a correct account reports ok"        "$out" "ok    correct"
has  "D: unparseable settings is BLIND"       "$out" "BLIND broken"
has  "D: and says it is NOT overwriting it"   "$out" "NOT overwriting"
hasnt "E: the human's own account is never visited" "$out" "zach"
rc   "D: BLIND exits 6 even without --strict" 6 "$got"

# --- J: bare invocation changed nothing -------------------------------------
[ "$(jq -c '.permissions // "absent"' "$T/h1/blank/.claude/settings.json")" = '"absent"' ] \
  && ok "J: bare invocation wrote nothing" || bad "J: bare invocation wrote to an account"

# --- A/F/G: --apply, on a tree with no BLIND account ------------------------
mkhome h2 blank    '{"env":{"CLAUDE_CODE_OAUTH_TOKEN":"secret"},"enabledPlugins":["honey"]}'
mkhome h2 partial  '{"permissions":{"allow":["WebSearch"]}}'
mkhome h2 nofile   ''
out="$(run h2 --apply --strict)"; run h2 --strict >/dev/null 2>&1; got=$?
has "A: --apply reports the write"      "$out" "-> written"
has "A: an account with no settings.json is DRIFT, not BLIND" "$out" "DRIFT nofile"
rc  "A: --strict is green after --apply" 0 "$got"

got_perms="$(jq -c '.permissions' "$T/h2/blank/.claude/settings.json")"
[ "$got_perms" = "$(jq -c . <<<"$WANT")" ] \
  && ok "A: the block written matches --print exactly" \
  || bad "A: written block differs from --print"

has "F: env is preserved"            "$(cat "$T/h2/blank/.claude/settings.json")" "CLAUDE_CODE_OAUTH_TOKEN"
has "F: other keys are preserved"    "$(cat "$T/h2/blank/.claude/settings.json")" "enabledPlugins"
ls "$T/h2/blank/.claude/"settings.json.bak-* >/dev/null 2>&1 \
  && ok "G: --apply backed the file up first" || bad "G: no backup was made"
ls "$T/h2/nofile/.claude/"settings.json.bak-* >/dev/null 2>&1 \
  && bad "G: backed up a file that did not exist" \
  || ok "G: no spurious backup for an account that had no settings.json"

got_tmpdir="$(jq -r '.env.TMPDIR' "$T/h2/blank/.claude/settings.json")"
[ "$got_tmpdir" = "$T/h2/blank/tmp" ] \
  && ok "K: env.TMPDIR points at this account's own tmp dir" \
  || bad "K: env.TMPDIR is wrong: $got_tmpdir"
[ -d "$T/h2/blank/tmp" ] && ok "K: the tmp dir was created" || bad "K: no tmp dir created"
[ "$(stat -c%a "$T/h2/blank/tmp" 2>/dev/null)" = "700" ] \
  && ok "K: the tmp dir is 0700" || bad "K: tmp dir is not 0700"

mkhome h2 rightperms_wrongtmp "$(jq -cn --argjson w "$WANT" '{permissions:$w, env:{TMPDIR:"/tmp"}}')"
out="$(run h2)"
has "K: correct permissions but wrong TMPDIR is still DRIFT" "$out" "DRIFT rightperms_wrongtmp"

# --- C: --apply on an already-correct account rewrites nothing --------------
mkhome h3 correct "$(correct h3 correct)"
mkdir -p "$T/h3/correct/tmp"; chmod 700 "$T/h3/correct/tmp"
before="$(ls "$T/h3/correct/.claude/")"
out="$(run h3 --apply)"
has "C: --apply leaves a correct account alone" "$out" "ok    correct"
[ "$(ls "$T/h3/correct/.claude/")" = "$before" ] \
  && ok "C: and made no backup and no write" || bad "C: rewrote a correct account"

# --- H: an empty roster is BLIND, never a clean 0 ---------------------------
mkdir -p "$T/h4"
# shellcheck disable=SC1007  # empty SUDO on purpose, as above.
HOME_ROOT="$T/h4" SUDO= "$SCRIPT" >/dev/null 2>&1
rc "H: no account found exits 6 BLIND" 6 "$?"

# --- I: the block itself ----------------------------------------------------
printf '%s' "$WANT" | jq -e . >/dev/null 2>&1 && ok "I: --print emits valid JSON" \
                                              || bad "I: --print is not valid JSON"
[ "$(printf '%s' "$WANT" | jq -r '.defaultMode')" = "auto" ] \
  && ok "I: defaultMode is auto (the mode this fleet uses)" \
  || bad "I: defaultMode is not auto"
[ "$(printf '%s' "$WANT" | jq -r '.deny|length')" -ge 5 ] \
  && ok "I: the deny floor is not empty" || bad "I: the deny floor is empty"
has "I: force-push is denied"      "$WANT" "git push --force"
has "I: pushing main is denied"    "$WANT" "git push origin main"
has "I: --admin merging is denied" "$WANT" "gh pr merge --admin"
has "I: the App key is unreadable" "$WANT" "/etc/selfdev/app.pem"
for f in /etc/selfdev/claude-token \
         '/home/*/.claude/settings.json' \
         '/home/*/.claude/settings.json.bak-*' \
         '/home/*/.claude/.credentials.json'; do
  has "I: $f is unreadable" "$WANT" "$f"
done

echo
summary
