#!/usr/bin/env bash
# run-suites.test.sh -- witness for bin/run-suites.sh (#316).
#
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/run-suites.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { printf '  PASS: %s\n' "$*"; pass=$((pass+1)); }
bad() { printf '  FAIL: %s\n' "$*"; fail=$((fail+1)); }
rc()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected exit $2, got $3)"; fi; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing: $3)" ;; esac; }
hasnot() { case "$2" in *"$3"*) bad "$1 (should not contain: $3)" ;; *) ok "$1" ;; esac; }

echo "run-suites.test.sh"

good() { printf '#!/usr/bin/env bash\nexit 0\n' > "$1"; chmod +x "$1"; }
bang() { printf '#!/usr/bin/env bash\necho "boom from %s"\nexit 1\n' "$(basename "$1")" > "$1"; chmod +x "$1"; }

echo "-- A. no arguments is BLIND, not a silent clean run"
"$SCRIPT" >/dev/null 2>&1
rc "A1 exits 2 with no suite paths" 2 "$?"

echo "-- B. all suites pass -> exit 0"
good "$T/b1.sh"; good "$T/b2.sh"
OUT="$(RUN_SUITES_QUARANTINE="$T/no-such-file" "$SCRIPT" "$T/b1.sh" "$T/b2.sh")"; RC=$?
rc  "B1 exits 0" 0 "$RC"
has "B2 reports both ran" "$OUT" "ran 2 suite(s)"
has "B3 says all passed" "$OUT" "all non-quarantined suite(s) passed."

echo "-- C. an un-quarantined failure fails the gate"
good "$T/c1.sh"; bang "$T/c2.sh"
OUT="$(RUN_SUITES_QUARANTINE="$T/no-such-file" "$SCRIPT" "$T/c1.sh" "$T/c2.sh")"; RC=$?
rc  "C1 exits 1" 1 "$RC"
has "C2 names the failed suite" "$OUT" "FAILED: $T/c2.sh"
has "C3 the suite's own output still appears" "$OUT" "boom from c2.sh"

echo "-- D. a quarantined failure does not fail the gate"
bang "$T/d1.sh"
printf '%s\t#999\ttest fixture\n' "$T/d1.sh" > "$T/quarantine"
OUT="$(RUN_SUITES_QUARANTINE="$T/quarantine" "$SCRIPT" "$T/d1.sh")"; RC=$?
rc  "D1 exits 0" 0 "$RC"
has "D2 still prints the failure loudly" "$OUT" "QUARANTINED"
has "D3 cites the quarantine reason" "$OUT" "#999"
hasnot "D4 does not claim FAILED (unquoted, unmatched by the FAILED: line)" "$OUT" "FAILED:$T/d1.sh"

echo "-- E. a mix: one real failure still fails the gate even with a quarantined one"
good "$T/e1.sh"; bang "$T/e2.sh"; bang "$T/e3.sh"
printf '%s\t#999\ttest fixture\n' "$T/e2.sh" > "$T/quarantine2"
OUT="$(RUN_SUITES_QUARANTINE="$T/quarantine2" "$SCRIPT" "$T/e1.sh" "$T/e2.sh" "$T/e3.sh")"; RC=$?
rc  "E1 exits 1" 1 "$RC"
has "E2 names only the real failure" "$OUT" "FAILED: $T/e3.sh"
hasnot "E3 the quarantined one is not in the FAILED line" "$OUT" "FAILED: $T/e2.sh $T/e3.sh"

echo "-- F. a stale quarantine entry (suite now passes) is flagged, not silent"
good "$T/f1.sh"
printf '%s\t#1\tstale by now\n' "$T/f1.sh" > "$T/quarantine3"
OUT="$(RUN_SUITES_QUARANTINE="$T/quarantine3" "$SCRIPT" "$T/f1.sh")"; RC=$?
rc  "F1 still exits 0" 0 "$RC"
has "F2 flags the stale entry" "$OUT" "quarantine entry is stale"

echo "-- G. comments and blank lines in the quarantine file are ignored"
bang "$T/g1.sh"
printf '# a comment\n\n%s\t#2\treal entry\n' "$T/g1.sh" > "$T/quarantine4"
OUT="$(RUN_SUITES_QUARANTINE="$T/quarantine4" "$SCRIPT" "$T/g1.sh")"; RC=$?
rc  "G1 exits 0 -- the real entry after the comment/blank still parsed" 0 "$RC"
has "G2 quarantined the suite" "$OUT" "QUARANTINED"

echo "-- H. a suite that reads stdin fails fast instead of hanging the run"
# The real instance: bin/tests/selfdev-credentials.test.sh sources its subject,
# whose `while IFS=: read -r acct ...` loop consumed stdin and blocked a full
# run for 20 minutes with no output. `timeout` is the witness -- if stdin is
# not closed this case does not fail, it never returns.
cat > "$T/h1.sh" <<'SUITE'
#!/usr/bin/env bash
while IFS=: read -r _line; do :; done
echo "reached the end"
SUITE
chmod +x "$T/h1.sh"
# stdin must be a pipe that STAYS OPEN, or this case cannot tell the two
# behaviours apart: the runner inherits whatever this suite was given, and a
# suite invoked with `</dev/null` hands its child an already-closed stdin, so
# the case passes with or without the fix. Verified by removing the fix and
# watching it still pass -- a guessed predicate is not a witness.
OUT="$(timeout 20 "$SCRIPT" "$T/h1.sh" 2>&1 < <(sleep 45))"; RC=$?
rc  "H1 the run completes rather than blocking on stdin" 0 "$RC"
has "H2 the stdin-reading suite still ran to its end" "$OUT" "reached the end"

printf '\nrun-suites.test.sh: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
