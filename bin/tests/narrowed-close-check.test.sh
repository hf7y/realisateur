#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$ROOT/narrowed-close-check.sh"
[ -x "$GUARD" ] || { echo "not executable: $GUARD"; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  PASS: %s\n' "$*"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL: %s\n' "$*"; }

grade() {  # grade <body> -> exit code, output in $OUT
  printf '%s\n' "$1" > "$TMP/body.md"
  OUT="$(bash "$GUARD" --body-file "$TMP/body.md" 2>&1)"
  return $?
}

echo "== the three bodies that caused this guard =="

grade "Closes #350's remaining scheduler-side gap. No change to bin/dose-project.sh was needed."
[ $? -eq 1 ] && ok "scheduler#634: \"Closes #350's remaining scheduler-side gap\" is a finding" \
             || bad "scheduler#634's body graded clean: $OUT"
case "$OUT" in *"(#350)"*) ok "names the bare-reference front door for #350" ;; *) bad "no front door named: $OUT" ;; esac

grade "Closes #575's build half; the status-page half stays open there."
[ $? -eq 1 ] && ok "scheduler#614: a possessive plus an explicit 'stays open' is a finding" \
             || bad "scheduler#614's body graded clean: $OUT"

grade "Closes #582 (the repo-scoped half; status-page display of MILESTONE-CHAIN stays)."
[ $? -eq 1 ] && ok "scheduler#628: a narrowing noun with no possessive is a finding" \
             || bad "scheduler#628's body graded clean: $OUT"

echo "== a whole close is not a finding, however much sentence follows =="

for whole in \
  "Closes #969" \
  "Fixes #997." \
  "Closes #926, closes #927, closes #928" \
  "Closes #969 and updates the man page to match, with a witness beside it." \
  "Resolves #101 -- the roster now reads from GitHub on every tick."
do
  grade "$whole"
  [ $? -eq 0 ] && ok "clean: $whole" || bad "false positive on: $whole -- $OUT"
done

echo "== a bare reference is never a finding, which is the remedy this names =="
for bare in "(#350)" "Part of #350, which stays open." "See #575's build half for context."; do
  grade "$bare"
  [ $? -eq 0 ] && ok "clean: $bare" || bad "false positive on a non-closing mention: $bare"
done

echo "== quoted is not claimed: a body that WRITES ABOUT the defect =="
grade "$(printf '%s\n' \
  '| PR | body | issue |' \
  '|---|---|---|' \
  '| scheduler#634 | `Closes #350'"'"'s remaining scheduler-side gap` | closed whole |' \
  '' \
  'Inline: the body said `Closes #575'"'"'s build half` and it closed anyway.' \
  '' \
  '```' \
  'Closes #582 (the repo-scoped half; status-page display stays)' \
  '```')"
[ $? -eq 0 ] && ok "a body QUOTING narrowed closes -- in a table, inline, and fenced -- is clean" \
             || bad "false positive on quoted text, which makes the defect unwritable-about: $OUT"

echo "== BLIND is never reported as clean =="
OUT="$(bash "$GUARD" --body-file "$TMP/does-not-exist.md" 2>&1)"; rc=$?
[ "$rc" -eq 6 ] && ok "an unreadable body exits 6" || bad "unreadable body exited $rc, want 6"
case "$OUT" in *BLIND*) ok "and says BLIND" ;; *) bad "exit 6 without saying BLIND: $OUT" ;; esac

: > "$TMP/empty.md"
OUT="$(bash "$GUARD" --body-file "$TMP/empty.md" 2>&1)"; rc=$?
[ "$rc" -eq 6 ] && ok "an EMPTY body is BLIND, not clean" || bad "empty body exited $rc, want 6"

echo "== no PR to grade is BLIND, not clean (guard-estate D2) =="
OUT="$(cd "$TMP" && bash "$GUARD" 2>&1)"; rc=$?
[ "$rc" -eq 6 ] && ok "bare, with no PR to infer, exits 6" || bad "bare run exited $rc, want 6: $OUT"
case "$OUT" in *BLIND*) ok "and says BLIND" ;; *) bad "exit 6 without BLIND: $OUT" ;; esac

echo
echo "narrowed-close-check.test.sh: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
