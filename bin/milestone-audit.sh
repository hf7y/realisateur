#!/usr/bin/env bash
# milestone-audit.sh -- offline-first stability-milestone check across every
# registered project. Realisateur's third survey alongside
# ecosystem-survey.sh and hygiene-lint.sh; zero AI cost (plain bash/grep/awk),
# same discipline as scheduler's docs/offline-first-checks.md. Run it at the
# top of every /ideate and /nightly-batch pass.
#
# It answers: does each project declare a current stability milestone (the
# canonical `## Stability milestone` section documented in
# realisateur/STABILITY-MILESTONES.md), what's its bar + status, and a rough
# active-vs-reservoir signal (count of (parked)/(waiting)-tagged ideas). Like
# the sibling surveys, its findings are SIGNALS, not verdicts -- a human/AI
# confirms each before acting.
#
# Supersedes incubation-audit.sh's graduation-candidate framing as the
# canonical project-status signal (status: in-progress == incubating,
# status: reached == graduated). See STABILITY-MILESTONES.md "Relationships".
set -uo pipefail

CLI_NAME='milestone-audit.sh'
CLI_SUMMARY='report each project'"'"'s STABILITY-MILESTONES progress'
CLI_USAGE='  milestone-audit.sh            audit every registered project
  milestone-audit.sh <name>...  audit only the named project(s)'
CLI_FLAGS=''
CLI_POSITIONAL=any
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

SCHED_ROOT="${SCHED_ROOT:-${INSTALLE_PROJECTS:-$HOME/Documents/Projects}/scheduler}"
[ -d "$SCHED_ROOT/schedule" ] || { echo "FATAL: scheduler schedule/ not found at $SCHED_ROOT" >&2; exit 2; }

# Optional args: restrict to named projects (same shape as hygiene-lint.sh).
want=("$@")

projects=()
for conf in "$SCHED_ROOT"/schedule/*.conf; do
  name="$(basename "$conf" .conf)"
  case "$name" in _*) continue ;; esac
  grep -q '^PROJECT_REPO_PATH=' "$conf" || continue
  if [ "${#want[@]}" -gt 0 ]; then
    skip=1; for w in "${want[@]}"; do [ "$w" = "$name" ] && skip=0; done
    [ "$skip" -eq 1 ] && continue
  fi
  projects+=("$name")
done
cli_require_matched want projects

echo "milestone-audit -- $(date '+%Y-%m-%d %H:%M')"
echo "(offline-first: no claude calls -- findings are SIGNALS, not verdicts."
echo " Canonical convention: realisateur/STABILITY-MILESTONES.md.)"
echo
echo "== scanning ${#projects[@]} project(s): $(printf '%s,' "${projects[@]}" | sed 's/,$//') =="

declared=0; missing=0; nofocus=0; reached=0

for name in $(printf '%s\n' "${projects[@]}" | sort); do
  conf="$SCHED_ROOT/schedule/$name.conf"
  repo="$(grep -oP '(?<=PROJECT_REPO_PATH=")[^"]*' "$conf")"
  # Respect SCHEDULER_SUBDIR same as sync-crontab.sh/bin/scheduler already
  # do (default ".claude" when unset) -- scheduler itself, and any future
  # project migrated onto the self-contained-folder model, keeps FOCUS.md
  # outside .claude/ deliberately (see .scheduler/FOCUS.md "Permission
  # gate" note). Hardcoding .claude/ here misread scheduler as no-focus.
  subdir="$(grep -v '^[[:space:]]*#' "$conf" | grep -m1 -oP '(?<=SCHEDULER_SUBDIR=")[^"]*' || true)"
  [ -z "$subdir" ] && subdir=".claude"
  focus="$repo/$subdir/FOCUS.md"
  echo
  echo "############################################################"
  echo "# $name  ($repo)"

  if [ ! -f "$focus" ]; then
    echo "  FOCUS: none (no $subdir/FOCUS.md) -- see FOCUS-md-formatting-compliance"
    nofocus=$((nofocus+1))
    continue
  fi

  if ! grep -qiE '^##[[:space:]]+Stability milestone' "$focus"; then
    echo "  milestone: MISSING (no \`## Stability milestone\` section)"
    missing=$((missing+1))
    continue
  fi

  line="$(grep -m1 -iE '^\*\*Current:\*\*' "$focus" || true)"
  status="$(printf '%s' "$line" | grep -oiE 'status:[[:space:]]*(not-started|in-progress|reached)' \
            | grep -oiE '(not-started|in-progress|reached)' | head -1 | tr 'A-Z' 'a-z')"
  bar="$(printf '%s' "$line" | sed -E 's/^\*\*Current:\*\*[[:space:]]*//; s/[[:space:]]*[—–-]+[[:space:]]*status:.*$//I')"
  [ -z "$status" ] && status="UNRECOGNIZED (Current line lacks a status: token)"
  [ -z "$bar" ] && bar="(no bar text on Current line)"

  # grep -c already prints 0 on no-match (and exits 1); `|| true` swallows the
  # exit without appending a second 0. Count only DATED bullet lines so the
  # convention-explanation prose ("...are (parked)") doesn't self-inflate this.
  parked="$(grep -cE '^\s*[-*].*\(parked\)' "$focus" 2>/dev/null || true)"
  waiting="$(grep -cE '^\s*[-*].*\(waiting[^)]*\)' "$focus" 2>/dev/null || true)"

  echo "  milestone: DECLARED -- \"$bar\" [$status]"
  echo "  reservoir signal: $parked (parked), $waiting (waiting)"
  declared=$((declared+1))
  case "$status" in reached) reached=$((reached+1)) ;; esac
done

echo
echo "############################################################"
echo "== summary: $declared declared ($reached reached) / $missing missing / $nofocus no-focus =="
echo "A 'reached' milestone is the trigger to set a new one or graduate the"
echo "project to slow iteration (drop its _paced.conf weight) -- see"
echo "STABILITY-MILESTONES.md 'Lifecycle'. Missing/no-focus are candidates for"
echo "a milestone-setting pass, not failures."
