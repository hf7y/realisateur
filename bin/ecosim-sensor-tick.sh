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
#   2. The exit code IS the finding (0 OK / 8 WARN / 9 CRIT / 6 BLIND, the
#      sonde vocabulary). cron discards it, so it is recorded here.
#   3. BLIND BEATS CRIT in this contract. A run that could not read part of
#      its domain has not established the rest is fine, and the log has to
#      preserve that distinction rather than flatten it to "nonzero".
set -uo pipefail

case "${1:-}" in
  -h|--help)
    printf 'ecosim-sensor-tick.sh -- run ecosim'"'"'s sensors on a tick and keep the log\n\n'
    printf 'usage:\n  ecosim-sensor-tick.sh    run the sensor once, append to the run log\n'
    printf '    ECOSIM_SENSOR_BIN=...  override the sensor binary path\n'
    printf '    STATE_DIR=...          override the state/archive directory\n\n'
    printf 'flags: none accepted\n\n'
    printf 'reading the durable archive (rotated monthly, closed months gzipped,\n'
    printf 'nothing ever trimmed -- one command spans every month):\n'
    printf '  zcat -f "$STATE_DIR"/archive-*.jsonl.gz "$STATE_DIR"/archive-*.jsonl\n\n'
    printf 'exit codes (sonde vocabulary -- the exit code IS the finding):\n'
    printf '  0  OK      8  WARN     9  CRIT\n'
    printf '  6  BLIND (could not read part of its domain -- beats CRIT)\n'
    printf '  2  usage   4  GAP      5  BROKEN  (all reported as BLIND)\n\n'
    printf 'this tool makes no AI calls and cannot spend: --summon is rejected.\n'
    exit 0 ;;
  "") ;;
  *)
    printf 'ecosim-sensor-tick.sh: takes no arguments, got: %s\n' "$1" >&2
    printf 'try `ecosim-sensor-tick.sh --help`\n' >&2
    exit 2 ;;
esac

# THE BUILD, NOT A DEV CLONE.
#
# Until 2026-08-05 this defaulted to
# ${INSTALLE_PROJECTS:-$HOME/Documents/Projects}/ecosim/bin/ecosim-sensor --
# a development checkout. Two things were wrong with that, and only the
#   [rest of this note: vault:realisateur/guard-archaeology-20260817.md]
SENSOR="${ECOSIM_SENSOR_BIN:-${VERB_BUILD_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/verb-builds}/current/ecosim/bin/sonde}"
# Overridable so a test can point the whole state directory somewhere
# disposable. It used to be a bare $HOME path, which meant the only way to
# exercise the archive was against the live record.
STATE_DIR="${STATE_DIR:-$HOME/.local/share/ecosim-sensor}"
LOG="$STATE_DIR/run.log"
LATEST="$STATE_DIR/latest.txt"
mkdir -p "$STATE_DIR"

ts() { date -Is; }

# --- the durable archive: rotate by month, seal the closed ones -------------
# ROTATION, NOT A TRIM: #53 made never-trimmed the point (a rolling window
# cannot answer "what did the sensors say during the migration"), and nothing
# here drops a byte. What was wrong was ONE file forever -- 753,341 bytes over
# 45 runs on mandark, ~290 MB/year at the armed */30 cadence.
#   [rest of this note: vault:realisateur/guard-archaeology-20260817.md]
ARCHIVE="$STATE_DIR/archive-$(date -u +%Y-%m).jsonl"

# MIGRATION, one time. The pre-rotation archive is RENAMED -- not deleted, and
# not folded into the current month: this script cannot prove its records all
# fall inside one month, and filing a multi-month blob under a name claiming
# one month breaks the exact property rotation is for. The seal loop below
# then gzips it like any other closed file, and the reader glob covers it.
if [ -f "$STATE_DIR/archive.jsonl" ]; then
  if [ -e "$STATE_DIR/archive-unrotated.jsonl" ]; then
    cat "$STATE_DIR/archive.jsonl" >> "$STATE_DIR/archive-unrotated.jsonl" \
      && rm -f "$STATE_DIR/archive.jsonl"
  else
    mv "$STATE_DIR/archive.jsonl" "$STATE_DIR/archive-unrotated.jsonl"
  fi
fi

# Seal every archive file that is not the one THIS run appends to. gzip members
# concatenate legally and zcat reads them transparently, so a closed file that
# reappears after its .gz exists (clock skew, a restored backup, a host back
# from a long park) is APPENDED to the seal, not dropped and not left
# colliding. A failed seal is reported, never swallowed.
for _a in "$STATE_DIR"/archive-*.jsonl; do
  [ -e "$_a" ] || continue                 # nullglob is not set; skip the literal
  [ "$_a" = "$ARCHIVE" ] && continue       # the open month
  _sealed=0
  if [ -e "$_a.gz" ]; then
    gzip -c -- "$_a" >> "$_a.gz" && rm -f "$_a" && _sealed=1
  else
    gzip -n -- "$_a" && _sealed=1
  fi
  [ "$_sealed" -eq 1 ] || \
    echo "$(ts) BLIND ecosim-sensor-tick.SEAL_FAILED path=$_a | could not gzip a closed archive" | tee -a "$LOG" >&2
done
unset _a _sealed

if [ ! -x "$SENSOR" ]; then
  # Fail LOUD: a missing sensor is a finding, not an inconvenience. Exiting 0
  # here would make "the suite is gone" indistinguishable from "all clear",
  # which is the exact fault the suite exists to detect.
  echo "$(ts) BLIND ecosim-sensor-tick.WRAPPER_NO_SENSOR path=$SENSOR | sensor binary missing or not executable" | tee -a "$LOG" >&2
  exit 3
fi

# Trim before each run rather than growing unbounded (same shape as
# usage-paced-runner.sh).
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
# $LOG is TRIMMED to 5000 lines before every run -- about 2.6 days at this
# cadence -- and $LATEST keeps only the most recent run. NEITHER is a record.
# This is the one that is: append-only, never trimmed, JSONL. It is rotated
# monthly and closed months are gzipped (see $ARCHIVE above); rotation moves
#   [rest of this note: vault:realisateur/guard-archaeology-20260817.md]
timeout 600 "$SENSOR" run --json > "$AOUT" 2>/dev/null
arc=$?
alines="$(wc -l < "$AOUT" 2>/dev/null || echo 0)"

# The run-boundary record is why a FAILED probe stays visible. Without it an
# empty archive block is indistinguishable from "no run happened" -- the same
# silence-is-not-success fault the missing-sensor branch above guards against.
#
# It is ALSO what already makes a run individually addressable -- which is why
#   [rest of this note: vault:realisateur/guard-archaeology-20260817.md]
printf '{"ts": "%s", "record": "run", "rc": %s, "json_rc": %s, "lines": %s, "host": "%s"}\n' \
  "$(ts)" "$rc" "$arc" "${alines:-0}" "$(hostname -s)" >> "$ARCHIVE"
[ -s "$AOUT" ] && cat "$AOUT" >> "$ARCHIVE"

# sonde's vocabulary, NOT the Monitoring Plugins one. sonde translates the
# legacy codes on purpose: raw 3 means BLIND upstream but needs-summon here,
# so passing them through would report a read failure as a request for money
# (man/sonde.1, EXIT STATUS). Code 3 is deliberately unreachable from sonde.
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
case "$rc" in
  0) verdict="OK" ;;
  8) verdict="WARN" ;;
  9) verdict="CRIT" ;;
  6) verdict="BLIND" ;;
  4) verdict="BLIND (GAP -- the tooling sonde fronts is absent or not executable)" ;;
  5) verdict="BLIND (BROKEN -- underlying tool exited a code its contract does not define)" ;;
  2) verdict="BLIND (usage error -- this wrapper called sonde wrongly)" ;;
  124) verdict="BLIND (wrapper timeout after 600s)" ;;
  *) verdict="BLIND (unexpected rc=$rc -- an unmapped code is not a pass)" ;;
esac
echo "$(ts) verdict=$verdict rc=$rc" >> "$LOG"

exit "$rc"
