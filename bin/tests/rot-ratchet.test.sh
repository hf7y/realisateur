#!/usr/bin/env bash
# rot-ratchet.test.sh -- witness for bin/rot-ratchet.sh.
#
# HERMETICITY: fully offline. ROT_RATCHET_SCAN points at a stub that prints
# fixture NDJSON in bin/decision-rot.sh's `--json` shape and exits as it does
# (1 when rot exists, 3 when a repo was unreadable), so no network, no token,
# and no dependence on the state of Zach's inbox.
#
# Cases:
#   A at baseline                      -> exit 0
#   B a repo above baseline            -> exit 1, names it as REGRESSION
#   C a repo below baseline            -> exit 0; --accept lowers it
#   D --accept refuses a regression    -> exit 1, ratchet unchanged
#   E --accept with nothing to lower   -> exit 1 (never a silent rewrite)
#   F the scan exiting 3 is BLIND      -> exit 3, never 0
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/rot-ratchet.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { printf '  PASS: %s\n' "$*"; pass=$((pass+1)); }
bad() { printf '  FAIL: %s\n' "$*"; fail=$((fail+1)); }
rc()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected exit $2, got $3)"; fi; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing: $3)" ;; esac; }

cat > "$T/scan" <<'EOF'
#!/usr/bin/env bash
cat "$SCAN_FIXTURE"
exit "${SCAN_RC:-1}"
EOF
chmod +x "$T/scan"
export ROT_RATCHET_SCAN="$T/scan"
export ROT_RATCHET_FILE="$T/ratchet"

fixture() { : > "$T/f.ndjson"; for r in "$@"; do
    printf '{"kind":"rotting","repo":"hf7y/%s","number":1,"answered_at":"2026-08-01","age_days":9,"title":"t"}\n' "$r" >> "$T/f.ndjson"
  done
  printf '{"kind":"summary","repos":2,"answered":9,"rotting":%d,"errors":0}\n' "$#" >> "$T/f.ndjson"
  export SCAN_FIXTURE="$T/f.ndjson"; }
baseline() { printf '# t\n' > "$T/ratchet"; printf '%s\n' "$@" >> "$T/ratchet"; }

echo "rot-ratchet.test.sh"

echo "-- A. at baseline"
fixture chezz chezz; baseline "chezz	2"
out="$(bash "$SCRIPT")"; rc "A1 exits 0" 0 $?
has "A2 prints the row" "$out" "chezz"

echo "-- B. above baseline"
fixture chezz chezz chezz; baseline "chezz	2"
out="$(bash "$SCRIPT")"; rc "B1 exits 1" 1 $?
has "B2 names the regression" "$out" "REGRESSION +1"

echo "-- C. below baseline, and --accept lowers"
fixture chezz; baseline "chezz	2"
bash "$SCRIPT" >/dev/null; rc "C1 exits 0" 0 $?
bash "$SCRIPT" --accept >/dev/null 2>&1; rc "C2 --accept exits 0" 0 $?
has "C3 ratchet lowered to 1" "$(grep chezz "$T/ratchet")" "chezz	1"

echo "-- D. --accept refuses while above baseline"
fixture chezz chezz chezz; baseline "chezz	2"
bash "$SCRIPT" --accept >/dev/null 2>&1; rc "D1 exits 1" 1 $?
has "D2 ratchet untouched" "$(grep chezz "$T/ratchet")" "chezz	2"

echo "-- E. --accept with nothing to lower"
fixture chezz chezz; baseline "chezz	2"
bash "$SCRIPT" --accept >/dev/null 2>&1; rc "E1 exits 1" 1 $?

echo "-- F. an unreadable repo is BLIND, never all-clear"
fixture chezz; baseline "chezz	2"
out="$(SCAN_RC=3 bash "$SCRIPT" 2>&1)"; rc "F1 exits 3" 3 $?
has "F2 says BLIND" "$out" "BLIND"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
