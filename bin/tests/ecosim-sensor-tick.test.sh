#!/usr/bin/env bash
#
# ecosim-sensor-tick.test.sh -- witness for the monthly rotation of
# bin/ecosim-sensor-tick.sh's durable archive (#55).
#
# THE DEFECT. The wrapper appended every run to ONE never-rotated
# archive.jsonl. Measured on mandark 2026-08-11: 753,341 bytes over 45 runs,
# ~16.7 KB per run; at the armed cadence (*/30) that is ~800 KB/day and
# ~290 MB/year in a single file nothing can seek into.
#
# WHAT IS NOT BEING FIXED, and this is the point of case C. The archive is
# never TRIMMED -- that was the deliberate decision in #53, because a rolling
# window cannot answer "what did the sensors say during the migration" three
# months later, which is the only reason the archive exists. Every case here
# asserts bytes are MOVED, never dropped: C reads the whole record back after
# rotation and compares it line-for-line with what went in.
#
# Cases:
#   A  a run appends to archive-<YYYY-MM>.jsonl, not archive.jsonl
#   B  a closed month is gzipped; the open month is left alone
#   C  the pre-rotation archive.jsonl is migrated, not deleted, and every
#      line of it survives into the sealed set
#   D  the documented reader spans sealed and open months in one command
#   E  a closed month that reappears after its .gz exists is appended to the
#      seal, not dropped and not left colliding
#
# Usage: bash bin/tests/ecosim-sensor-tick.test.sh   (exit 0 = all pass)
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

TICK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/ecosim-sensor-tick.sh"
[ -f "$TICK" ] || { echo "FAIL: no $TICK"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# A fake sonde. The contract this stands in for is ecosim/SENSOR-CONTRACT.md
# v1: `run` emits line protocol, `run --json` emits JSONL. Nothing here needs
# the real one, and depending on it would make the suite need a verb build.
SENSOR="$T/sonde"
cat > "$SENSOR" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "run")        echo "probe-a OK nothing to report" ;;
  "run --json") echo '{"probe": "probe-a", "status": "OK"}' ;;
esac
exit 0
EOF
chmod +x "$SENSOR"

MONTH="$(date -u +%Y-%m)"
S="$T/state"

run_tick() { STATE_DIR="$S" ECOSIM_SENSOR_BIN="$SENSOR" bash "$TICK" >/dev/null 2>&1; }

echo "ecosim-sensor-tick.test.sh   (current UTC month: $MONTH)"

echo "-- A. a run appends to the month's file, not to archive.jsonl"
mkdir -p "$S"
run_tick
if [ -f "$S/archive-$MONTH.jsonl" ]; then
  ok "A1  archive-$MONTH.jsonl exists"
else bad "A1  archive-$MONTH.jsonl exists" "$(ls -1 "$S" 2>&1)"; fi
if [ -e "$S/archive.jsonl" ]; then
  bad "A2  no unrotated archive.jsonl is created"
else ok "A2  no unrotated archive.jsonl is created"; fi
if grep -q '"record": "run"' "$S/archive-$MONTH.jsonl" 2>/dev/null; then
  ok "A3  the run-boundary record is in it (runs stay individually addressable)"
else bad "A3  the run-boundary record is in it"; fi
if grep -q '"probe": "probe-a"' "$S/archive-$MONTH.jsonl" 2>/dev/null; then
  ok "A4  and the run's JSONL payload follows the boundary"
else bad "A4  and the run's JSONL payload follows the boundary"; fi

echo "-- B. a closed month is sealed; the open month is not"
printf '{"ts": "2026-07-01T00:00:00-05:00", "record": "run", "old": 1}\n' > "$S/archive-2026-07.jsonl"
run_tick
if [ -f "$S/archive-2026-07.jsonl.gz" ] && [ ! -e "$S/archive-2026-07.jsonl" ]; then
  ok "B1  the prior month is gzipped and the plain file is gone"
else bad "B1  the prior month is gzipped and the plain file is gone" "$(ls -1 "$S")"; fi
if [ -f "$S/archive-$MONTH.jsonl" ] && [ ! -e "$S/archive-$MONTH.jsonl.gz" ]; then
  ok "B2  the open month is left plain (still being appended to)"
else bad "B2  the open month is left plain" "$(ls -1 "$S")"; fi
eq  "B3  the sealed month still reads back" \
    "$(zcat "$S/archive-2026-07.jsonl.gz" 2>/dev/null | grep -c '"old": 1')" "1"

echo "-- C. the pre-rotation archive.jsonl is migrated, and NOTHING is lost"
S2="$T/state2"; mkdir -p "$S2"
for i in 1 2 3 4 5; do
  printf '{"ts": "2026-08-0%s", "record": "run", "legacy": %s}\n' "$i" "$i" >> "$S2/archive.jsonl"
done
before="$(cat "$S2/archive.jsonl")"
before_n="$(wc -l < "$S2/archive.jsonl")"
STATE_DIR="$S2" ECOSIM_SENSOR_BIN="$SENSOR" bash "$TICK" >/dev/null 2>&1
if [ -e "$S2/archive.jsonl" ]; then
  bad "C1  archive.jsonl is no longer appended to" "it is still there"
else ok "C1  archive.jsonl is no longer appended to"; fi
if [ -f "$S2/archive-unrotated.jsonl.gz" ]; then
  ok "C2  it was renamed and sealed, not deleted"
else bad "C2  it was renamed and sealed, not deleted" "$(ls -1 "$S2")"; fi
eq  "C3  every legacy line survived byte-for-byte" \
    "$(zcat "$S2/archive-unrotated.jsonl.gz" 2>/dev/null)" "$before"
# The seal must not have folded the old records into the current month, which
# would file possibly-multi-month data under a name claiming one month.
eq  "C4  and none of them leaked into the current month's file" \
    "$(grep -c 'legacy' "$S2/archive-$MONTH.jsonl" 2>/dev/null || true)" "0"

echo "-- D. the documented reader spans sealed and open months"
# This is the command in the script's --help and header.
total="$(zcat -f "$S2"/archive-*.jsonl.gz "$S2"/archive-*.jsonl 2>/dev/null | grep -c '"record": "run"')"
# 5 legacy boundary records + 1 from the run this case's tick performed
eq  "D1  one command reads every month" "$total" "$((before_n + 1))"

echo "-- E. a month that reappears after its seal exists is appended, not lost"
printf '{"ts": "2026-07-31T23:59:59-05:00", "record": "run", "late": 1}\n' > "$S/archive-2026-07.jsonl"
run_tick
if [ ! -e "$S/archive-2026-07.jsonl" ]; then
  ok "E1  the reappeared file was consumed"
else bad "E1  the reappeared file was consumed" "still present"; fi
eq  "E2  the seal now holds BOTH the old and the late record" \
    "$(zcat "$S/archive-2026-07.jsonl.gz" 2>/dev/null | grep -cE '"old": 1|"late": 1')" "2"

echo
summary
