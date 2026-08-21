#!/usr/bin/env bash
# rot-ratchet.sh -- the rotting count may only ever go down.
#
# RUNNER: .github/workflows/rot-ratchet.yml -- daily
# GUARD-TEST: bin/tests/rot-ratchet.test.sh
# GATE: none -- it grades the ESTATE's issues, not this checkout, so CI would
#       depend on the network; same reason bin/decision-rot.sh is unwired.
#
# The predicate is bin/decision-rot.sh's, unchanged: this reads its `--json`
# summary. Nothing new is defined here -- only the ratchet idiom used in
# bin/thermostat-wiring.ratchet: `--accept` LOWERS a repo's baseline or
# refuses, and a repo above its baseline exits 1.
#
# usage:  rot-ratchet.sh [--accept]
# exit:   0  no repo is above its baseline
#         1  REGRESSION -- a repo grew rot, or --accept had nothing to lower
#         2  usage error (cli-guard.sh)
#         6  BLIND -- decision-rot.sh could not read a repo. NEVER "all clear"
set -uo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
RATCHET="${ROT_RATCHET_FILE:-$ROOT/bin/rot-ratchet.ratchet}"

CLI_NAME='rot-ratchet.sh'
CLI_SUMMARY='did this estate grow a new answered-but-still-open issue?'
CLI_USAGE='  rot-ratchet.sh            grade every repo against its baseline
  rot-ratchet.sh --accept   lower the baselines that have improved'
CLI_FLAGS='--accept'
CLI_EXITS='  0  no repo is above its baseline
  1  REGRESSION -- a repo grew rot (or --accept found nothing to lower)
  6  BLIND -- a repo could not be read; the count is NOT trustworthy'
CLI_POSITIONAL=none
. "$ROOT/bin/lib/cli-guard.sh"
cli_guard "$@"

ACCEPT=0
for a in "$@"; do case "$a" in --accept) ACCEPT=1 ;; esac; done

# ROT_RATCHET_SCAN exists for bin/tests/rot-ratchet.test.sh, which feeds
# fixture NDJSON in place of a live scan.
SCAN="${ROT_RATCHET_SCAN:-$ROOT/bin/decision-rot.sh --all --json}"

out="$($SCAN)"; rc=$?
# decision-rot.sh: 0 clean, 1 rot found, 3 unreadable. Only 3 is BLIND.
if [ "$rc" -eq 3 ]; then
  echo 'rot-ratchet.sh: decision-rot.sh could not read every repo -- BLIND, not clear' >&2
  exit 6
fi
if [ "$rc" -ne 0 ] && [ "$rc" -ne 1 ]; then
  echo "rot-ratchet.sh: scan exited $rc" >&2
  exit 6
fi

# Counted from the rotting rows, not from the summary total, so the per-repo
# number this file records is the same number a reader sees listed.
now="$(printf '%s\n' "$out" \
       | jq -r 'select(.kind == "rotting") | .repo' | sed 's|.*/||' | sort | uniq -c \
       | awk '{print $2"\t"$1}')"

[ -f "$RATCHET" ] || { echo "rot-ratchet.sh: no ratchet at $RATCHET -- run --accept to seed it" >&2; exit 6; }

base="$(grep -v '^#' "$RATCHET" | grep .)"

get() { printf '%s\n' "$2" | awk -F'\t' -v k="$1" '$1==k{print $2; f=1} END{if(!f) print 0}'; }

repos="$(printf '%s\n%s\n' "$now" "$base" | cut -f1 | grep . | sort -u)"
rcode=0
lowered=0
new_base=''
printf '%-18s %8s %9s\n' REPO ROTTING BASELINE
for r in $repos; do
  n="$(get "$r" "$now")"; b="$(get "$r" "$base")"
  if [ "$n" -gt "$b" ]; then
    printf '%-18s %8s %9s  REGRESSION +%d\n' "$r" "$n" "$b" "$((n - b))"
    rcode=1
  else
    printf '%-18s %8s %9s\n' "$r" "$n" "$b"
    [ "$n" -lt "$b" ] && lowered=$((lowered + 1))
  fi
  # --accept records the lower of the two. It never raises: a repo that grew
  # rot has to lose it, not have the number edited until the guard is green.
  [ "$n" -lt "$b" ] && b="$n"
  [ "$b" -gt 0 ] && new_base="$new_base$r"$'\t'"$b"$'\n'
done

if [ "$ACCEPT" = 1 ]; then
  if [ "$rcode" -ne 0 ]; then
    echo 'rot-ratchet.sh: --accept refuses while a repo is above its baseline' >&2
    exit 1
  fi
  if [ "$lowered" -eq 0 ]; then
    echo 'rot-ratchet.sh: nothing to lower' >&2
    exit 1
  fi
  { printf '# rot-ratchet.ratchet -- rotting issues (answered AND still open) per\n'
    printf '# repo when accepted. SHRINKS ONLY: --accept lowers or refuses.\n'
    printf '# Predicate and counts: bin/decision-rot.sh. Repos at zero are omitted.\n'
    printf '# accepted %s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)"
    printf '%s' "$new_base"
  } > "$RATCHET"
  printf 'rot-ratchet.sh: lowered %d repo(s)\n' "$lowered"
fi

exit "$rcode"
