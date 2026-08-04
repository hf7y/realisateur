#!/usr/bin/env bash
# ecosystem-survey.sh -- offline-first ecosystem health check, realisateur's
# own equivalent of `scheduler status <project>` but scoped across every
# registered project at once. Zero AI cost: plain bash/git/awk, same
# discipline as scheduler's own docs/offline-first-checks.md pattern. Meant
# to be run at the top of every realisateur nightly-batch/ideate session,
# BEFORE any AI reasoning, so triage starts from real current state instead
# of a stale mental model.
#
# Reuses `bin/scheduler status <name>` per project (already offline-first)
# rather than reimplementing git-health/questions parsing here -- adds one
# thing scheduler's own per-project command doesn't: a lightweight,
# ecosystem-wide "oldest still-open dated idea" ranking, the concrete signal
# behind "vision debt" (see chezz/.claude/commands/ideate.md 4.5).
set -uo pipefail

CLI_NAME='ecosystem-survey.sh'
CLI_SUMMARY='offline-first ecosystem health check across every registered project'
CLI_USAGE='  ecosystem-survey.sh    survey every registered project, then rank open dated ideas'
CLI_FLAGS=''
CLI_POSITIONAL=none
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

SCHED_ROOT="${SCHED_ROOT:-${INSTALLE_PROJECTS:-$HOME/Documents/Projects}/scheduler}"
SCHED_BIN="$SCHED_ROOT/bin/scheduler"

echo "ecosystem-survey -- $(date '+%Y-%m-%d %H:%M')"
echo "(offline-first: no claude calls in this script -- see docs/offline-first-checks.md in the scheduler repo for the pattern)"

projects=()
for conf in "$SCHED_ROOT"/schedule/*.conf; do
  name="$(basename "$conf" .conf)"
  case "$name" in _*) continue ;; esac   # _paced/_batch/_runner/_sweep are not projects
  grep -q '^PROJECT_REPO_PATH=' "$conf" || continue
  projects+=("$name")
done

echo
echo "== registered projects: ${#projects[@]} =="
printf '%s\n' "${projects[@]}" | sort | paste -sd, -

for name in $(printf '%s\n' "${projects[@]}" | sort); do
  echo
  echo "############################################################"
  bash "$SCHED_BIN" status "$name" 2>&1
done

echo
echo "############################################################"
echo "== ecosystem-wide vision-debt scan (oldest open dated ideas) =="
echo "(a bullet counts as OPEN if it has no \`> \` reply line under it and"
echo " isn't tagged resolved/acknowledged -- same heuristic as scheduler's"
echo " own QUESTIONS.md unanswered-entry check, applied here to FOCUS.md's"
echo " dated backlog/idea entries instead)"
echo

for name in $(printf '%s\n' "${projects[@]}" | sort); do
  focus="$SCHED_ROOT/focus/$name.md"
  [ -f "$focus" ] || continue
  awk -v proj="$name" '
    function flush() {
      if (started && !is_resolved && !has_reply && date != "") print date " " proj ": " summary
    }
    /^\s*[-*]?\s*\*\*[0-9]{4}-[0-9]{2}-[0-9]{2}/ {
      flush()
      started = 1; has_reply = 0
      match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}/)
      date = substr($0, RSTART, RLENGTH)
      is_resolved = (tolower($0) ~ /resolved|acknowledged|done|built|shipped/) ? 1 : 0
      summary = $0
      sub(/^[ \t]*[-*]?[ \t]*/, "", summary)
      if (length(summary) > 100) summary = substr(summary, 1, 100) "..."
      next
    }
    started && /^[ \t]*>[ \t]?/ { has_reply = 1 }
    END { flush() }
  ' "$focus"
done | sort | head -20

echo
echo
echo "############################################################"
echo "== promotion signals stronger than age =="
echo "(oldest-first, above, is the WEAKEST signal in the ladder -- see"
echo " realisateur/PRECIPITATION.md. Re-arrival and interface clusters"
echo " outrank it; both are sensed by precipitation-scan.sh, run below.)"
echo
_pscan="$(dirname "$0")/precipitation-scan.sh"
if [ -x "$_pscan" ]; then
  bash "$_pscan"
else
  echo "WARNING: $_pscan missing or not executable -- the re-arrival and" >&2
  echo "cluster signals are NOT being sensed this run (age-only ranking)." >&2
fi

echo
echo "(oldest-first is a SIGNAL, not a rule -- realisateur may deliberately"
echo " promote a newer idea ahead of an older parked one when it's judged"
echo " more useful right now (e.g. it unblocks something active, or"
echo " synchronizes with another project's current direction); when doing"
echo " so, state why in the relevant FOCUS.md/weight change rather than"
echo " silently reordering -- see docs/priority-weight.md in the scheduler"
echo " repo.)"
