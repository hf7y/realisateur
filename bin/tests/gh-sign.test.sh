#!/usr/bin/env bash
#
# Contract test for gh-sign.sh: an agent gets signed WITHOUT calling anything
# special, and a shim standing in front of `gh` never costs a write.
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected [$3] got [$2]"; fi; }
contains(){ case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected to contain [$3], got [$2]" ;; esac; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GS="$HERE/../gh-sign.sh"
BASH_BIN="$(command -v bash)"      # resolved BEFORE any test narrows PATH
TIMEOUT_BIN="$(command -v timeout)" # same reason: the recursion tests run on an empty PATH
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- the fake gh -----------------------------------------------------------
# Logs argv and captures the body whichever way it arrives.
mkdir -p "$TMP/stub"
cat > "$TMP/stub/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
: > "$GH_LAST_BODY"
prev=''
for a in "$@"; do
  case "$prev" in --comment|--body) printf '%s' "$a" > "$GH_LAST_BODY" ;; esac
  prev="$a"
done
printf '%s\n' "$*" | grep -q -- '--body-file -' && cat > "$GH_LAST_BODY"
exit "${GH_EXIT:-0}"
STUB
chmod +x "$TMP/stub/gh"

run() {
  GH_LOG="$TMP/gh.log" GH_LAST_BODY="$TMP/gh.body" GH_EXIT="${GH_EXIT:-0}" \
  PATH="$TMP/stub:$PATH" "$BASH_BIN" "$GS" "$@"
}
lastline() { grep -v '^[[:space:]]*$' "$TMP/gh.body" | tail -1; }
reset() { : > "$TMP/gh.log"; : > "$TMP/gh.body"; }

echo "gh-sign contract"

# --- 1. the ordinary agent call is signed with no wrapper and no argument ---
reset
run issue comment 7 --repo hf7y/widget --body 'landed in abc123' >/dev/null 2>&1
check "an unmodified \`gh issue comment\` exits 0" "$?" "0"
contains "...the original body survives" "$(cat "$TMP/gh.body")" "landed in abc123"
case "$(lastline)" in
  '<!-- agent: '*'@'*' -->') ok "...and it is signed, with no --job/--project argument to forget" ;;
  *) bad "signed" "last non-blank line: $(lastline)" ;;
esac

# --- 2. the identity is READ, not accepted from the caller -----------------
contains "the stamp names this account" "$(lastline)" "$(id -un)@"
stamp_date="$(lastline | sed -E 's/.*@[^ ]+ ([0-9TZ:-]+) -->/\1/')"
case "$stamp_date" in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z)
    ok "the stamp is dated ISO8601 UTC, second precision" ;;
  *) bad "ISO8601 UTC" "got: $stamp_date" ;;
esac

reset
# `issue create` is grammar-gated (lib/body-grammar.sh), so the fixture is
# well-formed. The case is about the TRAILING BLANK LINES, not the grammar:
# bin/tests/body-grammar.test.sh owns the refusal itself.
printf 'NO-DECISION: @zach nothing to weigh\nline\n\n<!-- DEFERRED -->\n- none\n<!-- /DEFERRED -->\n\n\n' > "$TMP/body.txt"
run issue create --repo hf7y/widget --title t --body-file "$TMP/body.txt" >/dev/null 2>&1
case "$(lastline)" in
  '<!-- agent: '*) ok "trailing blank lines do not push the marker off the end" ;;
  *) bad "marker last" "got: $(lastline)" ;;
esac

reset
run issue comment 7 --repo hf7y/widget --body "$(printf 'already done\n\n<!-- agent: someone@somewhere 2026-08-15T00:00:00Z -->')" >/dev/null 2>&1
check "an already-signed body is passed through untouched" \
      "$(grep -c 'someone@somewhere' "$TMP/gh.body")" "1"

reset
run issue close 7 --repo hf7y/widget --comment 'closing this out' >/dev/null 2>&1
contains "\`issue close --comment\` keeps its body" "$(cat "$TMP/gh.body")" "closing this out"
case "$(lastline)" in
  '<!-- agent: '*) ok "...and is signed, without being rewritten to --body-file" ;;
  *) bad "close signed" "got: $(lastline)" ;;
esac

reset
run issue list --repo hf7y/widget --state open >/dev/null 2>&1
check "a read passes through with argv intact" \
      "$(cat "$TMP/gh.log")" "issue list --repo hf7y/widget --state open"

reset
run pr merge 3 --repo hf7y/widget --squash >/dev/null 2>&1
check "a non-body write passes through with argv intact" \
      "$(cat "$TMP/gh.log")" "pr merge 3 --repo hf7y/widget --squash"

# --- 7. FAIL OPEN: a signature is never worth a lost write ----------------
reset
run issue comment 7 --repo hf7y/widget --body-file "$TMP/no-such-file" >/dev/null 2>&1
check "an unreadable --body-file still reaches gh (unsigned beats dropped)" \
      "$(grep -c 'no-such-file' "$TMP/gh.log")" "1"

reset
run issue comment 7 --repo hf7y/widget >/dev/null 2>&1
check "a body-less (interactive) call is left alone" \
      "$(cat "$TMP/gh.log")" "issue comment 7 --repo hf7y/widget"

check "a gh refusal surfaces, not swallowed" \
      "$(GH_EXIT=1 run issue comment 7 --repo hf7y/widget --body hi >/dev/null 2>&1; echo $?)" "1"

# --- 9. the shim must never resolve to ITSELF ------------------------------
mkdir -p "$TMP/loop"
ln -sf "$GS" "$TMP/loop/gh"
out="$(PATH="$TMP/loop" "$TIMEOUT_BIN" 10 "$BASH_BIN" "$GS" --self-check 2>&1)"; rc=$?
check "a shim that is the only gh on PATH reports BLIND (exit 6), never recurses" "$rc" "6"
contains "...and says so out loud" "$out" "BLIND"

out="$(PATH="$TMP/loop:$TMP/stub" "$TIMEOUT_BIN" 10 "$BASH_BIN" "$GS" --self-check 2>&1)"
contains "--self-check resolves past the shim to the real gh" "$out" "$TMP/stub/gh"

echo
summary
