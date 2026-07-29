#!/usr/bin/env bash
# ecosim-sensor-tick.sh -- run ecosim's sensors on a tick and keep the log.
#
# Wiring, owned by realisateur (which installs ecosystem-wide mechanisms),
# for a sensor suite owned by ecosim. realisateur is the CONSUMER end of
# ecosim/SENSOR-CONTRACT.md v1: ecosim states world-state, realisateur
# decides what is worth acting on. The contract explicitly promises no
# thresholds and no alerting policy -- that is this side's call.
#
# WHY A WRAPPER AND NOT A BARE CRON LINE
#   1. A bare line needs `2>&1 >> log`, and getting that order wrong
#      silences stderr. This ecosystem has a `silence-audit` check because
#      that keeps happening.
#   2. The exit code IS the finding (0 OK / 1 WARN / 2 CRIT / 3 BLIND, the
#      Monitoring Plugins codes). cron discards it, so it is recorded here.
#   3. BLIND BEATS CRIT in this contract. A run that could not read part of
#      its domain has not established the rest is fine, and the log has to
#      preserve that distinction rather than flatten it to "nonzero".
set -uo pipefail

SENSOR="${ECOSIM_SENSOR_BIN:-/home/zach/Documents/Projects/ecosim/bin/ecosim-sensor}"
STATE_DIR="$HOME/.local/share/ecosim-sensor"
LOG="$STATE_DIR/run.log"
LATEST="$STATE_DIR/latest.txt"
mkdir -p "$STATE_DIR"

ts() { date -Is; }

if [ ! -x "$SENSOR" ]; then
  # Fail LOUD: a missing sensor is a finding, not an inconvenience. Exiting 0
  # here would make "the suite is gone" indistinguishable from "all clear",
  # which is the exact fault the suite exists to detect.
  echo "$(ts) BLIND ecosim-sensor-tick.WRAPPER_NO_SENSOR path=$SENSOR | sensor binary missing or not executable" | tee -a "$LOG" >&2
  exit 3
fi

# Trim before each run rather than growing unbounded (same shape as
# usage-paced-runner.sh and weight-audit.sh).
[ -f "$LOG" ] && { tail -n 5000 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"; }

OUT="$(mktemp)"; ERR="$(mktemp)"
trap 'rm -f "$OUT" "$ERR"' EXIT

timeout 600 "$SENSOR" run > "$OUT" 2> "$ERR"
rc=$?

cp "$OUT" "$LATEST" 2>/dev/null || true

{
  echo "=== $(ts) ecosim-sensor run rc=$rc ==="
  # The histogram is the alphabet-closure view the contract recommends:
  # `cut -d' ' -f2 | sort | uniq -c`. Kept per-run so a symbol that STOPS
  # appearing is as visible as one that starts.
  if [ -s "$OUT" ]; then
    cut -d' ' -f2 "$OUT" | sort | uniq -c | sort -rn | sed 's/^/  hist /'
    awk '$1!="OK"' "$OUT" | sed 's/^/  /'
  else
    echo "  (no sensor output -- this is itself abnormal)"
  fi
  [ -s "$ERR" ] && sed 's/^/  stderr /' "$ERR"
} >> "$LOG" 2>&1

case "$rc" in
  0) verdict="OK" ;;
  1) verdict="WARN" ;;
  2) verdict="CRIT" ;;
  3) verdict="BLIND" ;;
  124) verdict="BLIND (wrapper timeout after 600s)" ;;
  *) verdict="BLIND (unexpected rc=$rc -- an unmapped code is not a pass)" ;;
esac
echo "$(ts) verdict=$verdict rc=$rc" >> "$LOG"

exit "$rc"
