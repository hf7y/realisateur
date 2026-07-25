#!/usr/bin/env bash
# liveness-audit.sh — every ENABLED participant must show recent life, or shout.
#
# The guard whose absence cost the most: aedile + vkv-inventory were disabled
# for a migration on 2026-07-20 that never completed; zero dispatch for 4 days,
# and nothing noticed, because "no report" produces no signal anywhere.
# BUILD-DISCIPLINE.md rule 1: prefer a mechanical guard over a reminder.
#
# Offline-first: pure bash/stat, zero AI cost. Signals, not verdicts.
# Wire: one cron line in the scheduler-managed block, output prepended to the
# morning glance. Exits 1 if any enabled project is dark (fails LOUD).
set -euo pipefail

SCHED_ROOT="${SCHED_ROOT:-$HOME/Documents/Projects/scheduler}"
REPORTS="${REPORTS:-$HOME/reports}"
FRESHNESS_DAYS="${FRESHNESS_DAYS:-2}"

dark=0
now=$(date +%s)

for conf in "$SCHED_ROOT"/schedule/[!_]*.conf; do
  name=$(basename "$conf" .conf)

  # A project counts as enabled if any host rotation file enables it,
  # OR its conf declares its own BATCH_JOB_NAME (self-dispatching).
  enabled=0
  for paced in "$SCHED_ROOT"/schedule/_paced*.conf; do
    [ -f "$paced" ] || continue
    if awk -F'|' -v p="$name" '$1==p && $2==1 {found=1} END {exit !found}' "$paced"; then
      enabled=1; break
    fi
  done
  # Externally-dispatched projects (e.g. svc-vaporwave's own crontab) declare
  # EXTERNAL_DISPATCH=1 in their conf — they are still checked. That is the
  # point: "someone else runs it" is exactly where silence hides.
  grep -q '^EXTERNAL_DISPATCH=1' "$conf" 2>/dev/null && enabled=1
  [ "$enabled" -eq 1 ] || continue

  latest="$REPORTS/$name/LATEST.md"
  if [ ! -e "$latest" ]; then
    echo "DARK  $name  never reported"
    dark=$((dark + 1))
    continue
  fi
  age_days=$(( (now - $(stat -Lc %Y "$latest")) / 86400 ))
  if [ "$age_days" -gt "$FRESHNESS_DAYS" ]; then
    echo "DARK  $name  last report ${age_days}d ago ($(stat -Lc %y "$latest" | cut -d' ' -f1))"
    dark=$((dark + 1))
  else
    echo "ok    $name  ${age_days}d"
  fi
done

if [ "$dark" -gt 0 ]; then
  echo "LIVENESS: $dark enabled project(s) dark >${FRESHNESS_DAYS}d — see above" >&2
  exit 1
fi
