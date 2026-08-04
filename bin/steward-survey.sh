#!/usr/bin/env bash
# steward-survey.sh -- offline-first (zero AI) steward pass over the whole
# ecosystem: which organs are DARK, how long they have been dark, and how
# much undrained vision is stranded behind each one.
#
# WHY THIS EXISTS (the gap it closes, 2026-07-26):
# realisateur's four existing surveys all iterate `schedule/*.conf` and
# report on projects as if they were running. NONE of them reads the
# `enabled` flag in `schedule/_paced.conf`. So a project can be switched
# off and stay off indefinitely while `milestone-audit.sh` cheerfully
# reports its milestone as `in-progress` and `ecosystem-survey.sh` ranks
# its ideas as open vision debt -- with nothing anywhere saying "by the
# way, nothing has dispatched against this in N days."
#
# The exhibit that prompted it: on 2026-07-26, 9 of 18 paced participants
# were `enabled=0`, INCLUDING `crt` at weight 3 -- the single
# highest-weight project in the ecosystem was dark, and no survey said so.
#
# WHAT IT RETIRES: nothing yet, by design. It is a fifth survey, not a
# replacement -- it deliberately reports only the axis the other four are
# blind to (dispatch reality vs. declared intent) and defers milestone
# text to `milestone-audit.sh` and promotion signals to
# `precipitation-scan.sh`. If it ever starts restating those, fold it in.
#
# DOCTRINE: findings are SIGNALS, not verdicts (same stance as every
# sibling survey). A dark project is NOT a problem to auto-fix -- `crt`
# and `gardien` are both deliberately off, one on a hardware blocker.
# This script never writes, never re-enables, never reweights. It answers
# "what is stranded, and for how long" so a human/AI pass can judge.
# Law 2 (UNIVERSE.md): the reservoir growing is health. A reservoir behind
# a CLOSED valve is the thing worth surfacing.
#
# Usage:
#   steward-survey.sh                 all registered projects
#   steward-survey.sh <name>...       restrict to named projects
set -uo pipefail

SCHED_ROOT="${SCHED_ROOT:-${INSTALLE_PROJECTS:-$HOME/Documents/Projects}/scheduler}"
PACED_CONF="$SCHED_ROOT/schedule/_paced.conf"

[ -d "$SCHED_ROOT/schedule" ] || { echo "FATAL: scheduler schedule/ not found at $SCHED_ROOT" >&2; exit 2; }
[ -f "$PACED_CONF" ]          || { echo "FATAL: _paced.conf not found at $PACED_CONF" >&2; exit 2; }

CLI_NAME='steward-survey.sh'
CLI_SUMMARY='who is actually stewarding each project -- dispatch reality vs FOCUS activity'
CLI_USAGE='  steward-survey.sh            survey every registered project
  steward-survey.sh <name>...  survey only the named project(s)'
CLI_FLAGS=''
CLI_EXITS='  0  surveyed. Findings are SIGNALS, not verdicts -- a dark project is
     often deliberate.
  2  no registered project matched what was asked for'
CLI_POSITIONAL=any
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

today_epoch="$(date +%s)"
want=("$@")

echo "steward-survey -- $(date '+%Y-%m-%d %H:%M')"
echo "(offline-first: no claude calls -- findings are SIGNALS, not verdicts."
echo " A dark project is often deliberate. This script never writes.)"

# --- read the dispatch reality: _paced.conf's enabled/weight fields ---------
# Format: name|enabled|weight|command   (weight OPTIONAL -- 3 fields means
# weight defaults to 1, per _paced.conf's own header). Parsing both arities
# matters: chezz/wtul/quatre-vingt-douze use the 3-field form today, and
# reading field 3 as a weight there would silently read a COMMAND PATH as a
# number.
declare -A P_ENABLED P_WEIGHT
while IFS= read -r line; do
  line="${line%%#*}"                                  # strip trailing comment
  case "$line" in ''|[[:space:]]*) ;; esac
  [ -z "${line//[[:space:]]/}" ] && continue
  IFS='|' read -r pname pen pthird pfourth <<<"$line"
  [ -z "$pname" ] && continue
  case "$pname" in \#*) continue ;; esac
  if [ -n "${pfourth:-}" ]; then pw="$pthird"; else pw=1; fi
  case "$pw" in ''|*[!0-9]*) pw=1 ;; esac       # non-numeric => omitted field
  P_ENABLED["$pname"]="$pen"
  P_WEIGHT["$pname"]="$pw"
done < "$PACED_CONF"

# --- discover registered projects ------------------------------------------
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

[ "${#projects[@]}" -eq 0 ] && { echo "FATAL: no registered projects matched" >&2; exit 2; }

# --- per-project signal gathering ------------------------------------------
# Emits one pipe-joined record per project so the report sections below can
# sort/filter without re-walking every repo.
records=()
for name in $(printf '%s\n' "${projects[@]}" | sort); do
  conf="$SCHED_ROOT/schedule/$name.conf"
  repo="$(grep -oP '(?<=PROJECT_REPO_PATH=")[^"]*' "$conf")"

  # Same SCHEDULER_SUBDIR handling as milestone-audit.sh -- hardcoding
  # .claude/ there once misread scheduler as having no FOCUS.md at all.
  subdir="$(grep -v '^[[:space:]]*#' "$conf" | grep -m1 -oP '(?<=SCHEDULER_SUBDIR=")[^"]*' || true)"
  [ -z "$subdir" ] && subdir=".claude"
  focus="$repo/$subdir/FOCUS.md"

  enabled="${P_ENABLED[$name]:-}"
  weight="${P_WEIGHT[$name]:-}"
  if [ -z "$enabled" ]; then
    paced="UNPACED"          # registered but not a _paced.conf participant
    weight="-"
  elif [ "$enabled" = "0" ]; then
    paced="DARK"
  else
    paced="LIVE"
  fi

  # Days since the repo's last commit. This is the honest "how long has
  # nothing happened here" number -- deliberately NOT a guess at when the
  # enabled flag flipped, which git can only tell us for the _paced.conf
  # line, not for the intent behind it.
  if [ -d "$repo/.git" ]; then
    last="$(git -C "$repo" log -1 --format=%ct 2>&1)"
    case "$last" in
      ''|*[!0-9]*) days="?"; lastdate="(git log failed: ${last:-empty})" ;;
      *) days=$(( (today_epoch - last) / 86400 ))
         lastdate="$(git -C "$repo" log -1 --format=%as)" ;;
    esac
  else
    days="?"; lastdate="(no git repo at $repo)"
  fi

  # Vision backlog: dated bullets in FOCUS.md with no `> ` reply and no
  # resolved/DONE marker beneath them, plus the oldest such date. Same
  # open-ness heuristic ecosystem-survey.sh uses, counted per project here
  # so a stranded reservoir is attributable to one organ.
  if [ -f "$focus" ]; then
    read -r openct oldest <<<"$(awk '
      function flush() {
        if (pending && !answered) {
          open++
          if (od == "" || pd < od) od = pd
        }
        pending = 0; answered = 0
      }
      /^[[:space:]]*[-*][[:space:]]/ {
        flush()
        if (match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}/)) {
          pending = 1; pd = substr($0, RSTART, 10)
        }
        if (tolower($0) ~ /resolved|\*\*done|retracted|acknowledged/) answered = 1
        next
      }
      /^[[:space:]]*>[[:space:]]/ { if (pending) answered = 1 }
      tolower($0) ~ /resolved|\*\*done|retracted/ { if (pending) answered = 1 }
      END { flush(); printf "%d %s", open, (od == "" ? "-" : od) }
    ' "$focus")"
  else
    openct=0; oldest="-"
  fi

  # Milestone presence only -- the TEXT is milestone-audit.sh's job and
  # restating it here would be the surface accretion Law 3 warns about.
  if [ ! -f "$focus" ]; then
    ms="no-focus"
  elif ! grep -qiE '^##[[:space:]]+Stability milestone' "$focus"; then
    ms="missing"
  else
    ms="$(grep -m1 -iE '^\*\*Current:\*\*' "$focus" \
          | grep -oiE '(not-started|in-progress|reached)' | head -1 | tr 'A-Z' 'a-z')"
    [ -z "$ms" ] && ms="unrecognized"
  fi

  records+=("$paced|$name|$weight|$days|$openct|$oldest|$ms|$lastdate")
done

# --- A. dark participants ---------------------------------------------------
echo
echo "############################################################"
echo "== A. DARK -- registered + paced but enabled=0 =="
echo "(nothing dispatches against these. Often deliberate -- the signal is"
echo " WEIGHT and STRANDED backlog: a high weight or a big reservoir behind"
echo " a closed valve is intent that stopped being acted on.)"
echo
darkct=0
printf '  %-22s %6s %7s %8s %-14s %s\n' PROJECT WEIGHT QUIET STRANDED MILESTONE OLDEST-OPEN
# NB: `while read` on a pipeline, never `for r in $(...)` -- the records
# carry a free-text lastdate field ("(no git repo at /path with spaces)"),
# and unquoted word-splitting shredded those into phantom rows, inflating
# the paced count from 18 to 22 on this script's first run.
while IFS='|' read -r _ name weight days openct oldest ms _; do
  [ -z "$name" ] && continue
  printf '  %-22s %6s %7s %8s %-14s %s\n' "$name" "$weight" "${days}d" "$openct" "$ms" "$oldest"
  darkct=$((darkct+1))
done < <(printf '%s\n' "${records[@]}" | grep '^DARK|' | sort -t'|' -k3,3nr -k5,5nr)
[ "$darkct" -eq 0 ] && echo "  (none -- every paced participant is enabled)"

# --- B. live participants ---------------------------------------------------
echo
echo "############################################################"
echo "== B. LIVE -- enabled, ordered by stranded backlog =="
echo "(Law 2: a growing reservoir is HEALTH, not debt. What to read here is"
echo " the OLDEST-OPEN column against weight -- vision arriving faster than"
echo " a low-weight organ can drain it is the reweight/park conversation.)"
echo
livect=0
printf '  %-22s %6s %7s %8s %-14s %s\n' PROJECT WEIGHT QUIET STRANDED MILESTONE OLDEST-OPEN
while IFS='|' read -r _ name weight days openct oldest ms _; do
  [ -z "$name" ] && continue
  printf '  %-22s %6s %7s %8s %-14s %s\n' "$name" "$weight" "${days}d" "$openct" "$ms" "$oldest"
  livect=$((livect+1))
done < <(printf '%s\n' "${records[@]}" | grep '^LIVE|' | sort -t'|' -k5,5nr)
[ "$livect" -eq 0 ] && echo "  (none)"

# --- C. registered but unpaced ---------------------------------------------
unpaced="$(printf '%s\n' "${records[@]}" | grep '^UNPACED|' || true)"
if [ -n "$unpaced" ]; then
  echo
  echo "############################################################"
  echo "== C. UNPACED -- has a schedule/<name>.conf but no _paced.conf row =="
  echo "(registered, so surveys report on it, but it is in no rotation at all."
  echo " Usually an incomplete registration rather than a decision.)"
  echo
  while IFS='|' read -r _ name _ days openct oldest ms _; do
    printf '  %-22s quiet %-6s stranded %-4s %-14s oldest %s\n' \
      "$name" "${days}d" "$openct" "$ms" "$oldest"
  done <<<"$unpaced"
fi

# --- D. probe failures ------------------------------------------------------
# A repo we could not read is NOT a quiet project -- it is an unknown, and
# collapsing the two is exactly the "silent failure" signature
# BUILD-DISCIPLINE names. Surfaced separately, with the real reason.
probefail="$(printf '%s\n' "${records[@]}" | awk -F'|' '$4=="?"' || true)"
if [ -n "$probefail" ]; then
  echo
  echo "############################################################"
  echo "== D. NOT PROBEABLE -- registered, but the repo could not be read =="
  echo "(an unknown, not a quiet project. Usually a conf pointing at a path"
  echo " that moved or was never created.)"
  echo
  while IFS='|' read -r paced name _ _ _ _ _ why; do
    [ -z "$name" ] && continue
    printf '  %-22s [%s] %s\n' "$name" "$paced" "$why"
  done <<<"$probefail"
fi

# --- summary ----------------------------------------------------------------
total=$(( darkct + livect ))
stranded_dark="$(printf '%s\n' "${records[@]}" | awk -F'|' '$1=="DARK" {s+=$5} END {print s+0}')"
echo
echo "############################################################"
echo "== summary: $livect live / $darkct dark (of $total paced) -- $stranded_dark open ideas stranded behind a closed valve =="
echo
echo "Steward reading, in order:"
echo "  1. A DARK row with a HIGH WEIGHT is the loudest signal here -- weight"
echo "     is stated intent, enabled=0 is actual dispatch. They disagree."
echo "  2. A DARK row with a large STRANDED count is vision accumulating"
echo "     where nothing can drain it. Re-enable, or park the ideas honestly"
echo "     -- but do not leave the reservoir filling behind a shut valve."
echo "  3. A LIVE row whose OLDEST-OPEN is weeks old at weight 1 is the"
echo "     reweight conversation (bin/weight-audit.sh has the commit-rate half)."
echo "  4. 'missing'/'no-focus' milestones are a milestone-setting pass."
echo
echo "None of the above is a verdict. Confirm each against the project's own"
echo "FOCUS.md before acting -- and per BUILD-DISCIPLINE, re-probe rather than"
echo "quoting this output back later as if it were still true."
