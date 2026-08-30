#!/usr/bin/env bash
# run-suites.sh -- run every suite handed to it; a quarantined failure (see
# run-suites.quarantine) still prints loud but does not fail the exit code.
# Gives a suite gone red under time pressure a one-line lever instead of
# dropping the whole `suites` required check, which is what #125 did (#316).
# Caller globs, not this file.
#
# usage:  run-suites.sh <suite-path>...
# exit 0  ran; nothing failed, or every failure was quarantined
# exit 1  a non-quarantined suite failed
# exit 6  BLIND -- no suite paths given
set -uo pipefail

QFILE="${RUN_SUITES_QUARANTINE:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run-suites.quarantine}"

[ $# -gt 0 ] || { echo "run-suites: BLIND -- no suite paths given, nothing was run" >&2; exit 6; }

declare -A QUARANTINED=()
if [ -f "$QFILE" ]; then
  while IFS=$'\t' read -r qpath qissue qreason || [ -n "$qpath" ]; do
    case "$qpath" in ''|'#'*) continue ;; esac
    QUARANTINED["$qpath"]="${qissue:-<no issue cited>} ${qreason:-}"
  done < "$QFILE"
fi

failed=""
quarantined_failed=""
for t in "$@"; do
  echo "::group::$t"
  rc=0
  # STDIN CLOSED. A suite must never read stdin; one that does HANGS FOREVER
  # under any runner without a tty (cron, a background job, CI). Found
  # 2026-08-15: bin/tests/selfdev-credentials.test.sh sources its subject,
  bash "$t" </dev/null || rc=$?
  echo "::endgroup::"
  if [ "$rc" -ne 0 ]; then
    if [ -n "${QUARANTINED[$t]+set}" ]; then
      echo "::warning file=$t::QUARANTINED (${QUARANTINED[$t]}) -- still failing, exit $rc, not gating"
      quarantined_failed="$quarantined_failed $t"
    else
      echo "::error file=$t::suite failed (exit $rc)"
      failed="$failed $t"
    fi
  elif [ -n "${QUARANTINED[$t]+set}" ]; then
    echo "::notice file=$t::quarantine entry is stale -- $t passed. Remove its line from $QFILE."
  fi
done

echo
echo "ran $# suite(s)."
[ -n "$quarantined_failed" ] && echo "quarantined, not gating:$quarantined_failed"
if [ -n "$failed" ]; then
  echo "FAILED:$failed"
  exit 1
fi
echo "all non-quarantined suite(s) passed."
