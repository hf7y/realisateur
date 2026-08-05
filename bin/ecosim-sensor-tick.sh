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

case "${1:-}" in
  -h|--help)
    printf 'ecosim-sensor-tick.sh -- run ecosim'"'"'s sensors on a tick and keep the log\n\n'
    printf 'usage:\n  ecosim-sensor-tick.sh    run the sensor once, append to the run log\n'
    printf '    ECOSIM_SENSOR_BIN=...  override the sensor binary path\n\n'
    printf 'flags: none accepted\n\n'
    printf 'exit codes (Monitoring Plugins convention -- the exit code IS the finding):\n'
    printf '  0  OK      2  CRIT\n'
    printf '  1  WARN    3  BLIND (could not read part of its domain -- beats CRIT)\n\n'
    printf 'this tool makes no AI calls and cannot spend: --summon is rejected.\n'
    exit 0 ;;
  "") ;;
  *)
    printf 'ecosim-sensor-tick.sh: takes no arguments, got: %s\n' "$1" >&2
    printf 'try `ecosim-sensor-tick.sh --help`\n' >&2
    exit 2 ;;
esac

SENSOR="${ECOSIM_SENSOR_BIN:-${INSTALLE_PROJECTS:-$HOME/Documents/Projects}/ecosim/bin/ecosim-sensor}"
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

OUT="$(mktemp)"; ERR="$(mktemp)"; AOUT="$(mktemp)"
trap 'rm -f "$OUT" "$ERR" "$AOUT"' EXIT

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

# --- the durable archive ------------------------------------------------
# $LOG is TRIMMED to 5000 lines before every run (line 57) -- about 2.6 days
# at this cadence -- and $LATEST keeps only the most recent run. NEITHER is a
# record. This is the one that is: append-only, never trimmed, JSONL.
#
# WHY IT LIVES HERE AND NOT IN ecosim/sensors/. The contract's own archival
# mode, `run --log`, appends into ecosim's repo. That is exactly the wrong
# place during a migration whose PURPOSE is deleting dev clones: the record
# would die with the thing it recorded. $STATE_DIR is realisateur's own, so
# nothing crosses a repo boundary -- ecosim still "writes only into
# ecosim/sensors/ and its own stdout" (SENSOR-CONTRACT.md section 5), and this
# wrapper owns what it chooses to keep.
#
# A SECOND PROBE, deliberately, not a reformat of $OUT. `run` emits line
# protocol and `run --json` emits JSONL; the contract does not promise the two
# are inter-convertible, and it explicitly refuses to stabilise the human prose
# ("Parse the symbol, never the prose"). Deriving one from the other would be
# parsing exactly what was declared unstable. Both probes are offline, ~10s,
# and cost no quota. They can observe slightly different states; that skew is
# the price, and it is smaller than the cost of parsing an unpromised format.
timeout 600 "$SENSOR" run --json > "$AOUT" 2>/dev/null
arc=$?
alines="$(wc -l < "$AOUT" 2>/dev/null || echo 0)"

# The run-boundary record is why a FAILED probe stays visible. Without it an
# empty archive block is indistinguishable from "no run happened" -- the same
# silence-is-not-success fault the missing-sensor branch above guards against.
#
# TWO exit codes, on purpose. Measured 2026-08-05 on identical state:
#   ecosim-sensor run          -> rc=3 (BLIND)
#   ecosim-sensor run --json   -> rc=0
# `--json` does not honour the exit-code half of SENSOR-CONTRACT v1 section 2
# (0 OK / 1 WARN / 2 CRIT / 3 BLIND, BLIND beats CRIT). Filed on ecosim. Until
# it is fixed, `rc` here is the AUTHORITATIVE line-protocol verdict and
# `json_rc` is what the archival mode claimed -- recorded rather than
# reconciled, so the discrepancy stays visible in the data instead of being
# quietly papered over by whichever one this wrapper happened to trust.
printf '{"ts": "%s", "record": "run", "rc": %s, "json_rc": %s, "lines": %s, "host": "%s"}\n' \
  "$(ts)" "$rc" "$arc" "${alines:-0}" "$(hostname -s)" >> "$STATE_DIR/archive.jsonl"
[ -s "$AOUT" ] && cat "$AOUT" >> "$STATE_DIR/archive.jsonl"

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
