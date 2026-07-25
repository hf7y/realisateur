#!/usr/bin/env bash
# weight-audit.sh -- offline, non-AI pass that keeps schedule/_paced.conf's
# per-project `weight` field dynamic without needing an interactive /ideate
# session every time. Mechanizes the manual reweight done 2026-07-24 (see
# DESIGN-NOTES.md same date, and realisateur/docs/priority-weight.md for the
# scheduler/realisateur division of labor this stays inside).
#
# Two outputs, deliberately asymmetric:
#
#   1. WEIGHT changes -- AUTO-APPLIED directly to _paced.conf (bounded,
#      logged inline, git-committed). A magnitude change within an already-
#      converging project is safe to mechanize: it's reversible, capped, and
#      the eligibility gate below stops it from rewarding raw activity that
#      isn't converging on anything.
#   2. PARK suggestions -- NEVER auto-applied. Going from any weight to
#      zero turns is a qualitatively different, harder-to-notice action (a
#      parked project produces no further signal to reconsider it by) --
#      same reasoning _paced.conf's own vkv-inventory/aedile comments
#      already encode ("do not re-enable without checking ... first").
#      Printed only, with a persistent streak counter so a human/realisateur
#      pass sees "flagged once" vs "flagged 5 runs running" instead of a
#      flat yes/no. See "IDEAS FOR SAFER AUTO-PARK" below for what would
#      need to exist before this could ever move to auto-apply.
#
# Metric: git commit count in the trailing 7 days (`git log --since="7 days
# ago"`), recomputed fresh every run -- deliberately NOT a single day's raw
# count, which is far too bursty (a project can go from 0 to 20 commits in
# one day and back). Matches what was actually used for the manual
# 2026-07-24 pass this script mechanizes.
#
# Eligibility gate for a WEIGHT bump: the project must have an `in-progress`
# stability milestone (per realisateur/bin/milestone-audit.sh's own
# detection, reimplemented inline below since neither repo exposes it as a
# library function -- if the two drift, milestone-audit.sh is canonical).
# High velocity with NO declared bar, or a REACHED milestone, does not earn
# more turns -- see the per-status handling below. This is deliberate: raw
# commit count alone can't distinguish real convergence from busywork, but
# "declared a bar + still building toward it" is a cheap, much harder to
# game proxy for "this project knows what it's converging on."
#
# CAVEATS (why this stays a SIGNAL, same discipline as its sibling audits
# ecosystem-survey.sh/hygiene-lint.sh/milestone-audit.sh/incubation-audit.sh):
#   - Commit count doesn't measure commit QUALITY. A project could inflate
#     velocity with trivial commits; nothing here detects that.
#   - A project blocked on something external (hardware arriving, a human
#     decision) shows LOW velocity while still being high-value -- this
#     script can't tell "thin idea" from "blocked idea" by commit count
#     alone. The `(waiting: ...)` FOCUS.md tag is a partial mitigation (see
#     below), not a full one.
#   - `realisateur` is excluded from weight changes by default (see
#     SKIP_PROJECTS) -- its own commit velocity is dominated by interactive
#     sessions like this one, not nightly-batch turns, and a project auto-
#     setting its own weight from a contaminated, self-reported signal is a
#     conflict of interest this script shouldn't paper over.
#   - This automates the ARITHMETIC of the 2026-07-24 pass, not the
#     accountability -- every change is still capped, inline-logged, and
#     git-committed exactly like a human/AI edit would be.
#
# IDEAS FOR SAFER AUTO-PARK (not implemented -- park stays print-only until
# these or something like them exist):
#   - Cooldown after unpark: suppress park-eligibility for N days after a
#     project's `enabled` flag last flipped 0->1, so a just-revived project
#     isn't immediately re-flagged by one quiet week. Needs a way to date
#     that transition (`git log -p -- schedule/_paced.conf` for the flip),
#     not tracked today.
#   - Per-project opt-in: a project could carry an explicit tag (e.g. a
#     `# auto-park: yes` comment on its _paced.conf line) marking it as
#     safe for mechanical parking, defaulting to opt-out for everything
#     else -- keeps the blast radius to projects a human has already
#     decided are fine to lose unattended.
#   - Corroborate with a second signal before ever auto-applying: e.g. also
#     require zero *interactive* touches (not just nightly-batch commits)
#     over the same window, to rule out "blocked, being discussed
#     elsewhere" rather than genuinely dormant.
#   - Ratio, not just streak: N-flagged-out-of-M-runs is more robust to a
#     single noisy week than a raw consecutive-streak count once history
#     accumulates.
#   - A stated minimum observation period before a freshly-registered
#     project is even park-eligible, so day-one thinness doesn't read as
#     abandonment.
# The runaway-suggestion guard below (RUNAWAY_MAX) is the one safeguard
# from this list actually implemented, because it protects against a
# script/git bug (not a real ecosystem-wide crash) producing a burst of
# false suggestions in one run -- "fails loud" per BUILD-DISCIPLINE.md,
# not "trust the majority signal."
set -uo pipefail

SCHED_ROOT="/home/zach/Documents/Project Archive/scheduler"
PACED_CONF="$SCHED_ROOT/schedule/_paced.conf"
[ -f "$PACED_CONF" ] || { echo "FATAL: $PACED_CONF not found" >&2; exit 2; }

STATE_DIR="$HOME/.local/share/weight-audit"
STREAK_DIR="$STATE_DIR/park-streak"
mkdir -p "$STREAK_DIR"

# Env knobs:
DRY_RUN="${WEIGHT_AUDIT_DRY_RUN:-0}"       # 1 = compute + print, touch nothing
APPLY="${WEIGHT_AUDIT_APPLY:-1}"           # 0 = skip _paced.conf rewrite/commit entirely
PUSH="${WEIGHT_AUDIT_PUSH:-0}"             # 1 = push the commit too (default: leave for a reviewed pass)
SKIP_PROJECTS="${WEIGHT_AUDIT_SKIP:-realisateur}"   # space-separated, see caveats above
TIER2_MIN="${WEIGHT_AUDIT_TIER2_MIN:-35}"  # commits/7d at/above this -> target weight 2
TIER3_MIN="${WEIGHT_AUDIT_TIER3_MIN:-120}" # commits/7d at/above this -> target weight 3
MAX_WEIGHT="${WEIGHT_AUDIT_MAX_WEIGHT:-3}"
MAX_DELTA=1                                 # hard cap: never move more than 1 tier/run
PARK_MAX_COMMITS="${WEIGHT_AUDIT_PARK_MAX:-15}"     # commits/7d at/below this -> park-eligible
RUNAWAY_MAX="${WEIGHT_AUDIT_RUNAWAY_MAX:-4}"        # more suggestions than this in one run = suspect the script, not the ecosystem

is_skipped() {
  local name="$1" s
  for s in $SKIP_PROJECTS; do [ "$s" = "$name" ] && return 0; done
  return 1
}

echo "weight-audit -- $(date '+%Y-%m-%d %H:%M') (dry_run=$DRY_RUN apply=$APPLY push=$PUSH)"
echo "(offline-first: no claude calls -- WEIGHT changes are bounded+auto-applied,"
echo " PARK suggestions are signals only. See this script's own header for the"
echo " full eligibility/caveat writeup.)"
echo

WORK="$(mktemp)"
cp "$PACED_CONF" "$WORK"
changed=0
declare -a park_lines=()

while IFS= read -r line; do
  case "$line" in ''|'#'*) continue ;; esac
  name="$(printf '%s' "$line" | cut -d'|' -f1 | xargs)"
  enabled="$(printf '%s' "$line" | cut -d'|' -f2 | xargs)"
  [ "$enabled" = "1" ] || continue   # never touch a currently-parked line here

  rest="$(printf '%s' "$line" | cut -d'|' -f3-)"
  rest="${rest#"${rest%%[![:space:]]*}"}"
  weight=1
  case "$rest" in
    [0-9]*'|'*)
      maybe_w="${rest%%|*}"
      if [[ "$maybe_w" =~ ^[0-9]+$ ]]; then weight="$maybe_w"; fi
      ;;
  esac

  echo "-- $name (current weight=$weight) --"

  if is_skipped "$name"; then
    echo "  SKIP: in WEIGHT_AUDIT_SKIP (self-weighting / contaminated-signal exclusion)"
    echo
    continue
  fi

  pconf="$SCHED_ROOT/schedule/$name.conf"
  if [ ! -f "$pconf" ]; then
    echo "  SKIP: no schedule/$name.conf, can't resolve a repo to measure"
    echo
    continue
  fi
  repo="$(grep -oP '(?<=PROJECT_REPO_PATH=")[^"]*' "$pconf" || true)"
  if [ -z "$repo" ] || [ ! -d "$repo" ]; then
    echo "  SKIP: PROJECT_REPO_PATH not found/resolvable ($repo)"
    echo
    continue
  fi

  commits_7d=$(git -C "$repo" log --since="7 days ago" --oneline 2>/dev/null | wc -l)

  subdir="$(grep -v '^[[:space:]]*#' "$pconf" | grep -m1 -oP '(?<=SCHEDULER_SUBDIR=")[^"]*' || true)"
  [ -z "$subdir" ] && subdir=".claude"
  focus="$repo/$subdir/FOCUS.md"

  status="no-focus"
  if [ -f "$focus" ]; then
    if grep -qiE '^##[[:space:]]+Stability milestone' "$focus"; then
      mline="$(grep -m1 -iE '^\*\*Current:\*\*' "$focus" || true)"
      status="$(printf '%s' "$mline" | grep -oiE 'status:[[:space:]]*(not-started|in-progress|reached)' \
                | grep -oiE '(not-started|in-progress|reached)' | head -1 | tr 'A-Z' 'a-z')"
      [ -z "$status" ] && status="unrecognized"
    else
      status="missing"
    fi
  fi

  echo "  commits_7d=$commits_7d  milestone=$status"

  # -- WEIGHT logic: auto-apply, gated + capped --
  if [ "$status" = "in-progress" ]; then
    if   [ "$commits_7d" -ge "$TIER3_MIN" ]; then target=3
    elif [ "$commits_7d" -ge "$TIER2_MIN" ]; then target=2
    else target=1
    fi
    [ "$target" -gt "$MAX_WEIGHT" ] && target="$MAX_WEIGHT"

    delta=$(( target - weight ))
    if   [ "$delta" -gt "$MAX_DELTA" ]; then delta="$MAX_DELTA"
    elif [ "$delta" -lt "-$MAX_DELTA" ]; then delta="-$MAX_DELTA"
    fi
    new_weight=$(( weight + delta ))
    [ "$new_weight" -lt 1 ] && new_weight=1
    [ "$new_weight" -gt "$MAX_WEIGHT" ] && new_weight="$MAX_WEIGHT"

    if [ "$new_weight" -ne "$weight" ]; then
      echo "  WEIGHT $weight -> $new_weight (target=$target, capped to +/-$MAX_DELTA/run)"
      today="$(date +%Y-%m-%d)"
      awk -v n="$name" -v w="$new_weight" -v today="$today" -v old="$weight" -v c="$commits_7d" '
        BEGIN{FS="|"}
        $1==n {
          rest=$0
          sub(/^[^|]*\|[^|]*\|/, "", rest)
          if (rest ~ /^[0-9]+\|/) { sub(/^[0-9]+\|/, "", rest) }
          printf "%s|1|%s|%s  # weight-audit.sh %s: %s->%s (commits_7d=%s, milestone in-progress)\n", n, w, rest, today, old, w, c
          next
        }
        { print }
      ' "$WORK" > "$WORK.new" && mv "$WORK.new" "$WORK"
      changed=$((changed+1))
    else
      echo "  no change (target=$target already matches or within cap)"
    fi
  elif [ "$status" = "reached" ]; then
    echo "  FLAG: milestone REACHED -- set a new one or graduate (drop weight) per"
    echo "        STABILITY-MILESTONES.md \"Lifecycle\". Not auto-changed -- that's"
    echo "        a deliberate re-admission decision, not a mechanical one."
  fi

  # -- PARK suggestion: never auto-applied, streak-tracked --
  if [ "$status" = "missing" ] || [ "$status" = "no-focus" ] || [ "$status" = "unrecognized" ]; then
    waiting_tag=0
    [ -f "$focus" ] && grep -qE '\(waiting[^)]*\)' "$focus" && waiting_tag=1
    streak_file="$STREAK_DIR/$name"
    if [ "$commits_7d" -le "$PARK_MAX_COMMITS" ] && [ "$waiting_tag" -eq 0 ]; then
      streak=0
      [ -f "$streak_file" ] && streak="$(cat "$streak_file" 2>/dev/null || echo 0)"
      streak=$((streak+1))
      [ "$DRY_RUN" = "1" ] || echo "$streak" > "$streak_file"
      park_lines+=("$name (commits_7d=$commits_7d, milestone=$status, flagged ${streak}x consecutive run(s))")
    else
      rm -f "$streak_file" 2>/dev/null || true
      if [ "$waiting_tag" -eq 1 ] && [ "$commits_7d" -le "$PARK_MAX_COMMITS" ]; then
        echo "  park-suggestion SUPPRESSED: low velocity but tagged (waiting: ...) in FOCUS.md -- blocked, not thin"
      fi
    fi
  fi
  echo
done < <(grep -v '^[[:space:]]*#' "$PACED_CONF" | grep -v '^[[:space:]]*$')

echo "############################################################"
if [ "${#park_lines[@]}" -gt "$RUNAWAY_MAX" ]; then
  echo "SUSPICIOUSLY MANY PARK SUGGESTIONS (${#park_lines[@]}, > RUNAWAY_MAX=$RUNAWAY_MAX)."
  echo "This far more likely means a script/git bug (e.g. git log failing silently"
  echo "across many repos at once) than an ecosystem-wide velocity crash in one"
  echo "week. Suppressing all park suggestions this run -- investigate before"
  echo "trusting any of them:"
  printf '  - %s\n' "${park_lines[@]}"
elif [ "${#park_lines[@]}" -gt 0 ]; then
  echo "PARK SUGGESTIONS (signals only, NOT applied -- needs realisateur/human review):"
  printf '  - %s\n' "${park_lines[@]}"
else
  echo "No park suggestions this run."
fi

echo
if [ "$changed" -eq 0 ]; then
  echo "No weight changes this run."
  rm -f "$WORK"
  exit 0
fi

if [ "$DRY_RUN" = "1" ] || [ "$APPLY" = "0" ]; then
  echo "$changed weight change(s) computed but NOT applied (dry_run=$DRY_RUN apply=$APPLY)."
  echo "--- diff ---"
  diff -u "$PACED_CONF" "$WORK" || true
  rm -f "$WORK"
  exit 0
fi

cp "$WORK" "$PACED_CONF"
rm -f "$WORK"
echo "$changed weight change(s) applied to $PACED_CONF."

cd "$SCHED_ROOT" || exit 1
if ! git diff --quiet -- schedule/_paced.conf; then
  git add schedule/_paced.conf
  git commit -m "$(cat <<EOF
_paced.conf: weight-audit.sh auto-reweight ($(date +%Y-%m-%d))

$changed project(s) reweighted from commit velocity (7d trailing) against
an in-progress stability milestone -- see this script's own header for
the eligibility gate, cap, and caveats. Mechanical pass, no AI/judgment
involved; revert with git revert if a number looks wrong.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)" >/dev/null
  echo "Committed: $(git log -1 --format=%H)"
  if [ "$PUSH" = "1" ]; then
    git push origin main && echo "Pushed."
  else
    echo "Not pushed (WEIGHT_AUDIT_PUSH=0 by default) -- left for the next reviewed pass."
  fi
fi
