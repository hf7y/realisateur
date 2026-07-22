#!/usr/bin/env bash
# incubation-audit.sh -- offline-first (zero AI) signals for judging which
# realisateur-scaffolded projects still belong in the incubator (still
# vision-shaped, low weight, close realisateur oversight) vs have graduated
# (stable core, fine to run at normal weight like any other registered
# project). Same discipline as bin/ecosystem-survey.sh and scheduler's own
# docs/offline-first-checks.md: gather real signals mechanically, leave the
# actual judgment to a human/AI reading the output -- this script does NOT
# decide "incubating" vs "graduated" itself, only surfaces the numbers that
# judgment should be based on.
#
# Usage:
#   incubation-audit.sh                 dry run: print signals + a naive
#                                        heuristic suggestion per project
#   incubation-audit.sh --apply FILE    apply real decisions from FILE
#                                        (name|status|weight, one per line,
#                                        status = incubating|graduated) --
#                                        writes schedule/_paced.conf's weight
#                                        field and prepends a dated STATUS
#                                        line to the project's own FOCUS.md.
#                                        Never invents the decisions itself.
set -uo pipefail

SCHED_ROOT="/home/zach/Documents/Project Archive/scheduler"
PACED_CONF="$SCHED_ROOT/schedule/_paced.conf"
today="$(date +%Y-%m-%d)"

# --- discover realisateur-scaffolded child projects -------------------------
# A project counts as "scaffolded by realisateur" if its own schedule/<name>.conf
# says so in a comment -- the same marker every realisateur-written conf uses
# (see e.g. schedule/gardien.conf's header). realisateur.conf itself is
# excluded (it's about realisateur, not a child realisateur scaffolded).
children=()
for conf in "$SCHED_ROOT"/schedule/*.conf; do
  name="$(basename "$conf" .conf)"
  case "$name" in _*|realisateur) continue ;; esac
  grep -qi "realisateur" "$conf" 2>/dev/null && children+=("$name")
done

if [ "${1:-}" = "--apply" ]; then
  decisions_file="${2:?usage: incubation-audit.sh --apply DECISIONS_FILE}"
  [ -f "$decisions_file" ] || { echo "no such file: $decisions_file" >&2; exit 1; }
  while IFS='|' read -r name status weight; do
    case "$name" in ''|\#*) continue ;; esac
    name="${name// /}"; status="${status// /}"; weight="${weight// /}"
    [[ "$weight" =~ ^[0-9]+$ ]] || weight=1
    conf="$SCHED_ROOT/schedule/$name.conf"
    if [ ! -f "$conf" ]; then
      echo "SKIP $name -- no schedule/$name.conf found"
      continue
    fi
    repo_path="$(grep -oP '(?<=PROJECT_REPO_PATH=")[^"]*' "$conf")"

    # -- update weight in _paced.conf (insert as 3rd field if not already present) --
    if grep -qE "^${name}\|" "$PACED_CONF"; then
      python3 - "$PACED_CONF" "$name" "$weight" <<'PYEOF'
import re, sys
conf_path, target, weight = sys.argv[1], sys.argv[2], sys.argv[3]
with open(conf_path) as f:
    lines = f.readlines()
out = []
for line in lines:
    stripped = line.rstrip("\n")
    if stripped.startswith(target + "|"):
        parts = stripped.split("|")
        # name|enabled|command  or  name|enabled|weight|command
        if len(parts) >= 4 and parts[2].strip().isdigit():
            parts[2] = weight
        else:
            parts = [parts[0], parts[1], weight] + parts[2:]
        stripped = "|".join(parts)
    out.append(stripped + "\n")
with open(conf_path, "w") as f:
    f.writelines(out)
PYEOF
      echo "APPLIED $name -- weight=$weight in $PACED_CONF"
    else
      echo "SKIP $name -- not found in $PACED_CONF"
    fi

    # -- prepend a dated STATUS line to the project's own FOCUS.md --
    if [ -n "$repo_path" ] && [ -f "$repo_path/.claude/FOCUS.md" ]; then
      focus="$repo_path/.claude/FOCUS.md"
      tmp="$(mktemp)"
      {
        echo "**INCUBATION STATUS ($today, via realisateur's incubation-audit.sh): $status (weight=$weight).**"
        echo
        cat "$focus"
      } > "$tmp"
      mv "$tmp" "$focus"
      echo "APPLIED $name -- status line prepended to $focus"
    else
      echo "SKIP $name -- no FOCUS.md at $repo_path (weight still applied above if it happened)"
    fi
  done < "$decisions_file"
  exit 0
fi

# --- dry run: signals + naive heuristic suggestion --------------------------
echo "incubation-audit (DRY RUN) -- $(date '+%Y-%m-%d %H:%M')"
echo "(no AI, no writes -- rerun with --apply DECISIONS_FILE once a real"
echo " judgment call has been made; this script never decides on its own)"
echo
printf '%-14s %8s %8s %8s %10s %8s %8s  %s\n' \
  "project" "commits" "age(d)" "last(d)" "weight" "forks" "openQs" "self-flagged"

for name in "${children[@]}"; do
  conf="$SCHED_ROOT/schedule/$name.conf"
  repo_path="$(grep -oP '(?<=PROJECT_REPO_PATH=")[^"]*' "$conf")"
  [ -d "$repo_path/.git" ] || { echo "$name: no repo at $repo_path"; continue; }

  commits="$(git -C "$repo_path" rev-list --count HEAD 2>/dev/null || echo 0)"
  first_date="$(git -C "$repo_path" log --reverse --format=%cd --date=short 2>/dev/null | head -1)"
  last_date="$(git -C "$repo_path" log -1 --format=%cd --date=short 2>/dev/null)"
  age_days=0; last_days=0
  if [ -n "$first_date" ]; then
    age_days=$(( ( $(date -d "$today" +%s 2>/dev/null || date +%s) - $(date -d "$first_date" +%s 2>/dev/null || echo 0) ) / 86400 ))
  fi
  if [ -n "$last_date" ]; then
    last_days=$(( ( $(date +%s) - $(date -d "$last_date" +%s 2>/dev/null || echo 0) ) / 86400 ))
  fi

  weight="$(grep -E "^${name}\|" "$PACED_CONF" | awk -F'|' '{if ($3 ~ /^[0-9]+$/) print $3; else print 1}')"
  [ -z "$weight" ] && weight=1

  focus_file="$SCHED_ROOT/focus/$name.md"
  forks=0
  if [ -f "$focus_file" ]; then
    forks="$(grep -ciE 'design fork|not (yet )?(built|started|implemented)' "$focus_file" 2>/dev/null)"
    [ -z "$forks" ] && forks=0
  fi

  qfile="$SCHED_ROOT/questions/$name.md"
  openqs=0
  if [ -f "$qfile" ]; then
    openqs="$(awk '
      function flush() { if (started && !is_resolved && !has_reply) n++ }
      /^- \*\*/ {
        flush(); started=1
        is_resolved = (tolower($0) ~ /resolved|acknowledged/) ? 1 : 0
        has_reply=0; next
      }
      started && /^[ \t]*>[ \t]?/ {
        line=$0; sub(/^[ \t]*>[ \t]?/, "", line)
        if (line !~ /^\(answer inline here\)/) has_reply=1
      }
      END { flush(); print n+0 }
    ' "$qfile")"
  fi

  # Deliberately specific phrasing, not generic words like "judgment call" or
  # "experiment" -- those also appear in this file's own boilerplate header
  # (the "How to answer" contract every project's QUESTIONS.md carries) and
  # would false-positive on every project otherwise. Checked against both
  # FOCUS.md and QUESTIONS.md -- self-flags have landed in either so far.
  self_flag="-"
  if grep -qiE \
    'whether it should be autonomously iterated at all|developed by hand instead of autonomously|deliberate experiment in how|design fork.*needs a (proposal|concrete design)' \
    "$focus_file" "$qfile" 2>/dev/null; then
    self_flag="yes"
  fi

  printf '%-14s %8s %8s %8s %10s %8s %8s  %s\n' \
    "$name" "$commits" "$age_days" "$last_days" "$weight" "$forks" "$openqs" "$self_flag"
done

echo
echo "Heuristic only -- NOT authoritative. Rough read: commits<=2 and/or"
echo "forks>0 and/or self-flagged=yes suggests still-incubating (lower"
echo "weight, keep under realisateur's watch); everything else is a"
echo "graduation CANDIDATE, not an automatic graduation -- a real judgment"
echo "pass (a human, or an /ideate session) should confirm before writing"
echo "a decisions file for --apply."
