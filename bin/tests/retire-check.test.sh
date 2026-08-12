#!/usr/bin/env bash
# retire-check.test.sh -- witness for bin/retire-check.sh (#166).
#
# HERMETICITY: fully offline. Every case pipes fixture text at the script or
# hands it a fixture file under a temp dir; nothing reads the live ecosystem.
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/retire-check.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { printf '  PASS: %s\n' "$*"; pass=$((pass+1)); }
bad() { printf '  FAIL: %s\n' "$*"; fail=$((fail+1)); }
rc()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected exit $2, got $3)"; fi; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing: $3)" ;; esac; }

echo "retire-check.test.sh"

echo "-- A. a clean close (every problem-shaped line has a URL) passes"
OUT="$(printf 'Fixed the bug in module X.\nFiled https://github.com/hf7y/realisateur/issues/999 for the drift.\n' | "$SCRIPT")"
RC=$?
rc  "A1 exits 0" 0 "$RC"
[ -z "$OUT" ] && ok "A2 prints nothing" || bad "A2 printed something on a clean close: $OUT"

echo "-- B. realisateur#165's own shape: a problem named with no URL fails"
OUT="$(printf 'Not something I fixed -- flagging it.\n' | "$SCRIPT")"
RC=$?
rc  "B1 exits 1" 1 "$RC"
has "B2 prints the offending line" "$OUT" "Not something I fixed -- flagging it."

echo "-- C. each floor phrase is caught on its own"
for phrase in "deferred the write" "reports BUSY on the second repo" "left undone for tonight" \
              "next session should pick this up" "didn't get to the second half" \
              "out of scope for now" "worth doing later"; do
  OUT="$(printf '%s\n' "$phrase" | "$SCRIPT")"; RC=$?
  rc "C ${phrase%% *}... exits 1" 1 "$RC"
done

echo "-- D. a URL on the line clears the same phrase"
OUT="$(printf 'Deferred to https://github.com/hf7y/realisateur/issues/1 for a decision.\n' | "$SCRIPT")"
rc  "D1 exits 0" 0 "$?"
echo "-- D. 'documented exception' clears it too, without a URL"
OUT="$(printf 'Left undone as a documented exception (branch parked mid-experiment).\n' | "$SCRIPT")"
rc  "D2 exits 0" 0 "$?"

echo "-- E. reads a named file, not just stdin"
printf 'Flagging this -- worth doing, no link attached.\n' > "$T/close.txt"
OUT="$("$SCRIPT" "$T/close.txt")"; RC=$?
rc  "E1 exits 1 reading a file argument" 1 "$RC"
has "E2 prints the file's offending line" "$OUT" "worth doing"

echo "-- F. usage errors"
"$SCRIPT" "$T/close.txt" "$T/close.txt" >/dev/null 2>&1
rc  "F1 two positional arguments exits 2" 2 "$?"
"$SCRIPT" --not-a-real-flag >/dev/null 2>&1
rc  "F2 an unknown flag exits 2, not a silent full run" 2 "$?"
"$SCRIPT" "$T/does-not-exist.txt" >/dev/null 2>&1
rc  "F3 an unreadable file exits 2" 2 "$?"

printf '\nretire-check.test.sh: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
