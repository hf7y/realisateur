#!/usr/bin/env bash
# check-project-busy.sh <project> -- offline-first concurrency guard.
#
# Answers one narrow question: is a scheduler-dispatched job (nightly-batch,
# bug-sweep, or a project's own oddly-named batch job) actively running
# against <project> RIGHT NOW? Realisateur's own half of the 2026-07-24
# push-race/concurrency finding (see FOCUS.md) -- scheduler owns making the
# dedicated-clone-vs-working-checkout sync itself robust; this script is
# realisateur's job: don't cross-write into a project's own FOCUS.md/
# QUESTIONS.md while that project's own automation is mid-run against the
# same files, in the same spirit as STABILITY-MILESTONES.md's "a dirty tree
# is a stop" rule for crt.
#
# Mechanism: every scheduler job dir at ~/.local/share/<job-name>/ holds a
# sweep.lock (or run.lock) taken via `flock` for the run's duration (see
# scheduler's lib/sweep-loop-common.sh). A non-blocking flock probe on that
# same file tells us, with zero AI cost and zero race window, whether a job
# currently holds it -- no PID files, no guessing from mtimes.
#
# Usage: bin/check-project-busy.sh <project>
# Exit 0 + "free" if no matching job dir's lock is currently held.
# Exit 1 + "BUSY: <job-name>" (one line per busy job) if any is held.
set -uo pipefail

project="${1:?usage: check-project-busy.sh <project>}"
share_dir="$HOME/.local/share"

# Shared scheduler INFRASTRUCTURE job dirs, not any one project's own
# automation -- these happen to share the "scheduler-*" prefix with
# scheduler's own real jobs (scheduler-nightly-batch, scheduler-paced-dev)
# purely by naming coincidence, but being "busy" here means "the shared
# dispatcher loop is currently taking its turn" (could be running ANY
# paced participant), not "scheduler's own repo is being edited right
# now." Hit for real 2026-07-24: `check-project-busy.sh scheduler`
# false-positived on `scheduler-paced-runner` while it was dispatching
# wtul's cycle, not scheduler's own. Excluded so the check answers the
# question it's actually meant to.
declare -A INFRA_EXCLUDE=( [scheduler-paced-runner]=1 [scheduler-registry]=1 [scheduler-glance]=1 )

busy=0
shopt -s nullglob
for dir in "$share_dir/$project"-*/; do
  job="$(basename "$dir")"
  [ -n "${INFRA_EXCLUDE[$job]:-}" ] && continue
  lock="$dir/sweep.lock"
  [ -f "$lock" ] || lock="$dir/run.lock"
  [ -f "$lock" ] || continue
  if ! flock -n "$lock" -c true 2>/dev/null; then
    echo "BUSY: $job"
    busy=1
  fi
done

if [ "$busy" -eq 0 ]; then
  echo "free"
  exit 0
fi
exit 1
