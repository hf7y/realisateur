#!/usr/bin/env bash
# floor-check.sh -- is THE FLOOR met? Nine criteria, probed live, no AI.
#
# RUNNER: operator -- probes crontab, systemd, backups and every repo on this host
# GUARD-TEST: none -- every criterion is a live host probe; a fixture would assert only that the fixture was built
# GATE: none -- DEMOTED 2026-08-07 from gate to readout; see below
#
# TRAPS (the rest of this header is in the vault):
# It has never once reported MET. Today: 6 unmet, 2 unproven, 1 met. Several
# criteria are about a dispatch topology this repo has since moved off (gate
# 1.2 counts agent-dispatching cron lines; gate 3.1 counts armed agents), and
# the ones that are still right -- gate 2, two copies and a named backup set --
# are ecosystem operations, not anything a branch can affect.
# So: it keeps its exit code for an operator who asks it a direct question, and
# it gates nothing. What is given up is a hard stop on ecosystem stability
# regressions, which it was never delivering. What still covers the live half:
# bin/deploy-drift.sh (are dispatchers on the merged ref) and
# bin/thermostat-wiring.sh's ratchet (regression from the current standing
# fails the build, without requiring the vision to be fully realised first).
#
# usage:
# exit: 0 every criterion met   1 one or more unmet   2 usage error

set -uo pipefail

QUIET=0; DO_RESTORE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --quiet|-q) QUIET=1 ;;
    --restore)  DO_RESTORE=1 ;;
    -h|--help)  sed -n '2,/^set -/p' "$0" | sed 's/^# \{0,1\}//;$d'; exit 0 ;;
    *) printf 'floor-check: unknown flag: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

PROJECTS="${PROJECTS_ROOT:-$HOME/Documents/Projects}"
SCHED="$PROJECTS/scheduler"
unmet=0; unproven=0
say() { [ "$QUIET" = 1 ] || printf '%s\n' "$*"; }
met()      { say "  MET       $1"; }
notmet()   { say "  NOT MET   $1"; [ -n "${2:-}" ] && say "            -> $2"; unmet=$((unmet+1)); }
unprov()   { say "  UNPROVEN  $1"; [ -n "${2:-}" ] && say "            -> $2"; unproven=$((unproven+1)); }

say "THE FLOOR -- $(date '+%F %H:%M') on $(hostname -s)"
say ""
say "GATE 1 -- NO GHOSTS"

# 1.1  Nothing enabled points at a path that does not exist.
d_shim=0
for f in "$HOME"/.local/bin/*; do
  [ -L "$f" ] && [ ! -e "$f" ] && { d_shim=$((d_shim+1)); say "            dangling shim: $f"; }
done
d_unit="$(systemctl --user list-units --state=failed --no-legend 2>/dev/null | grep -c . || true)"
# Every crontab command must resolve. Field 6 onward is the command; take $6.
d_cron=0
while read -r line; do
  cmd="$(printf '%s' "$line" | awk '{for(i=6;i<=NF;i++){if($i ~ /^\//){print $i; exit}}}')"
  [ -n "$cmd" ] && [ ! -e "$cmd" ] && { d_cron=$((d_cron+1)); say "            cron path missing: $cmd"; }
done < <(crontab -l 2>/dev/null | grep -vE '^\s*(#|$)')
if [ "$d_shim" = 0 ] && [ "$d_unit" = 0 ] && [ "$d_cron" = 0 ]; then
  met "1.1 no enabled unit, shim or cron line names a missing path"
else
  notmet "1.1 no enabled unit, shim or cron line names a missing path" \
         "$d_shim dangling shim(s), $d_unit failed unit(s), $d_cron dead cron path(s)"
fi

# 1.2  Exactly one cron line dispatches agents. The sensor tick and the sweep
# tick are not agent dispatch: the first is an offline sensor, the second is
# pure git/bash. Counting "all cron lines" would fail for the wrong reason.
disp="$(crontab -l 2>/dev/null | grep -vE '^\s*(#|$)' | grep -c 'usage-paced-runner' || true)"
other="$(crontab -l 2>/dev/null | grep -vE '^\s*(#|$)' \
         | grep -vE 'usage-paced-runner|ecosim-sensor-tick|scheduler sweep' | grep -c . || true)"
if [ "$disp" = 1 ] && [ "$other" = 0 ]; then
  met "1.2 exactly one agent-dispatching cron line, no unaccounted lines"
else
  notmet "1.2 exactly one agent-dispatching cron line, no unaccounted lines" \
         "dispatchers=$disp unaccounted=$other"
fi

# 1.3  Every guard the propagated checklist names resolves and fails loud.
if [ -x "$SCHED/../realisateur/bin/install-shims.sh" ] || [ -x "$PROJECTS/realisateur/bin/install-shims.sh" ]; then
  if bash "$PROJECTS/realisateur/bin/install-shims.sh" --check >/dev/null 2>&1; then
    met "1.3 shims and user commands in sync with source"
  else
    notmet "1.3 shims and user commands in sync with source" "run: realisateur/bin/install-shims.sh"
  fi
else
  notmet "1.3 shims and user commands in sync with source" "install-shims.sh not found"
fi

say ""
say "GATE 2 -- TWO COPIES"

# 2.1  Every repo has a reachable non-local origin, is 0-ahead of it, and clean.
# A DIRTY tree is deliberately NOT a failure here. THE FLOOR gate 2 is about
# recoverability -- does this history exist anywhere but this disk -- and
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
bad=""; dirty_info=""
for d in "$PROJECTS"/*/; do
  [ -d "$d/.git" ] || continue
  n="$(basename "$d")"
  u="$(git -C "$d" remote get-url origin 2>/dev/null)" || { bad="$bad $n(no-origin)"; continue; }
  case "$u" in /*) bad="$bad $n(local-only)"; continue ;; esac
  b="$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  a="$(git -C "$d" rev-list --count "origin/$b..$b" 2>/dev/null || echo 0)"
  [ "$a" != 0 ] && bad="$bad $n(+$a unpushed)"
  [ -n "$(git -C "$d" status --porcelain 2>/dev/null)" ] && dirty_info="$dirty_info $n"
done
if [ -z "$bad" ]; then met "2.1 every repo has a non-local origin, nothing unpushed"
else notmet "2.1 every repo has a non-local origin, nothing unpushed" "$bad"; fi
[ -n "$dirty_info" ] && say "            (note, not a failure -- work in progress:$dirty_info)"

# 2.2  The backup completes AND a file restores. See the header note.
#
# `garde media list` exits 6 when no destination is reachable, and prints
# "BLIND: ... the REMOTE column above is unknown, not empty". Its PENDING rows
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
gl="$(garde media list 2>/dev/null)"; grc=$?
if [ "$grc" = 6 ]; then
  unprov "2.2 backup coverage is UNKNOWN -- garde is BLIND (exit 6)" \
         "no destination reachable; check garde.json host against \`ip -4 addr\` -- a hardcoded LAN IP goes stale when the subnet changes"
elif [ "$grc" != 0 ]; then
  unprov "2.2 backup coverage is UNKNOWN" "garde media list exited $grc"
elif [ "$DO_RESTORE" = 1 ]; then
  # PENDING is reported as drift, NOT as failure. On a machine anyone is
  # working on, files appear between the copy and the verify -- on 2026-08-01
  # three sets sat 1-4 files behind while a live session edited them, minutes
  #   [rest: vault:realisateur/guard-archaeology-20260817.md]
  npend="$(printf '%s' "$gl" | grep -c 'PENDING' || true)"
  # Pull one real file back off the destination and diff it. Chosen from a set
  # that is small and stable; the point is the round trip, not the file.
  # garde lays each SET DOWN UNDER ITS SET NAME at the destination root, not
  #   [rest: vault:realisateur/guard-archaeology-20260817.md]
  src="$HOME/Documents/Projects/realisateur/README.md"
  rem="/mnt/d/gardien-media/mandark/Projects/realisateur/README.md"
  tmp="$(mktemp)"
  err="$(timeout 60 scp -q "dexter:$rem" "$tmp" 2>&1)"; src_rc=$?
  if [ "$src_rc" != 0 ]; then
    notmet "2.2 a file restored and matched" "scp failed: ${err:-rc=$src_rc}"
  elif [ ! -s "$tmp" ]; then
    notmet "2.2 a file restored and matched" "restored file is empty: $rem"
  elif diff -q "$src" "$tmp" >/dev/null 2>&1; then
    met "2.2 destination readable AND a file restored byte-identical"
    say "            $rem -> md5 $(md5sum < "$tmp" | cut -c1-12) matches source"
    [ "${npend:-0}" != 0 ] && say "            (note: $npend set(s) drifting behind -- the nightly closes this)"
  else
    notmet "2.2 a file restored and matched" "restored $rem DIFFERS from source"
  fi
  rm -f "$tmp"
else
  unprov "2.2 RESTORE NOT EXERCISED" \
         "copy+md5 is not restore. re-run with --restore"
fi

# 2.3  The repos are actually inside a backup set.
if grep -q '"Projects"' "$PROJECTS/gardien-garde/garde.json" 2>/dev/null; then
  met "2.3 ~/Documents/Projects is a named backup set"
else
  notmet "2.3 ~/Documents/Projects is a named backup set" "no Projects set in gardien-garde/garde.json"
fi

say ""
say "GATE 3 -- ONE LOOP, WATCHED"

# 3.1  Generated crontab, exactly one enabled participant.
# 3.1 asked for "exactly one enabled participant" until 2026-08-01, when Zach
# drew the line this gate actually cares about: MECHANISMS RUN ON A CLOCK,
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
en="$(grep -cE '^[a-z][a-z-]*\|1\|' "$SCHED/schedule/_paced.conf" 2>/dev/null || true)"; en="${en:-0}"
frz=0; [ -e "$SCHED/schedule/FREEZE" ] && frz=1
if [ "$en" -le 1 ] && [ "$disp" = 1 ] && [ "$frz" = 0 ]; then
  if [ "$en" = 0 ]; then
    met "3.1 no agent armed (nothing pending); dispatcher installed, not frozen"
  else
    met "3.1 one agent armed, dispatcher installed, not frozen"
  fi
else
  notmet "3.1 at most one agent armed, dispatcher installed, not frozen" \
         "enabled=$en (ceiling 1) dispatcher=$disp FREEZE_present=$frz"
fi

# 3.2  The harness refuses a dirty exit and a push to main.
S="$HOME/.claude/settings.json"
hook="$(python3 -c "import json;d=json.load(open('$S'));print(1 if d.get('hooks',{}).get('SubagentStop') else 0)" 2>/dev/null || echo 0)"
deny="$(python3 -c "import json;d=json.load(open('$S'));print(len(d.get('permissions',{}).get('deny',[])))" 2>/dev/null || echo 0)"
hookx=0; [ -x "$HOME/.claude/hooks/subagent-closeout.sh" ] && hookx=1
if [ "$hook" = 1 ] && [ "$deny" -ge 1 ] && [ "$hookx" = 1 ]; then
  met "3.2 SubagentStop guard live and $deny deny rule(s) installed"
else
  notmet "3.2 harness refuses dirty exits and main pushes" \
         "SubagentStop=$hook deny_rules=$deny hook_executable=$hookx"
fi

# 3.3  One overnight run landed on a BRANCH, left the tree clean, broke nothing.
# The runner's own log is the witness that a tick actually dispatched -- an
# untouched log means the loop has not run yet, which is not the same as a
# loop that ran and failed. Report those differently.
RL="$HOME/.local/share/scheduler-paced-runner/run.log"
if [ ! -f "$RL" ]; then
  unprov "3.3 one clean run has completed" "no runner log yet"
elif [ -z "$(find "$RL" -newermt '-18 hours' 2>/dev/null)" ]; then
  unprov "3.3 one clean run has completed" \
         "runner has not ticked in 18h (last $(date -r "$RL" '+%F %H:%M')) -- the loop has not run yet"
else
  # The witness must be the RUNNER's own record that it dispatched, not the
  # mere existence of a non-main branch. An earlier version accepted any branch
  # with a recent commit and reported 3.3 MET on `bashified` -- a branch from
  # hand-driven bashify work -- on an evening when the 18:00 tick had SKIPped
  #   [rest: vault:realisateur/guard-archaeology-20260817.md]
  proj="$(grep -oE '^[a-z][a-z-]*(?=\|1\|)' "$SCHED/schedule/_paced.conf" 2>/dev/null \
          || grep -E '^[a-z][a-z-]*\|1\|' "$SCHED/schedule/_paced.conf" 2>/dev/null | cut -d'|' -f1 | head -1)"
  proj="${proj:-gardien}"
  dispatched="$(grep -c "DISPATCH .* $proj ->" "$RL" 2>/dev/null || true)"
  done_line="$(grep "DONE $proj rc=" "$RL" 2>/dev/null | tail -1)"
  skipped="$(grep "SKIP $proj" "$RL" 2>/dev/null | tail -1)"
  if [ "$dispatched" = 0 ] || [ -z "$done_line" ]; then
    notmet "3.3 one clean run has completed" \
           "runner ticked but never dispatched $proj"
    [ -n "$skipped" ] && say "            last: $(printf '%s' "$skipped" | sed 's/^[0-9T:+-]* //')"
  else
    # vault:realisateur/THE-FLOOR.md 3.3 as written asks for "a commit on a branch". That is the
    # WRONG criterion and this check deliberately does not enforce it.
    #
    #   [rest: vault:realisateur/guard-archaeology-20260817.md]
    dirty="$(git -C "$PROJECTS/$proj" status --porcelain 2>/dev/null | grep -c . || true)"
    fail="$(systemctl --user list-units --state=failed --no-legend 2>/dev/null | grep -c . || true)"
    # Window from when the run actually STARTED, not a flat 18h. A human
    # commit made earlier the same day is not the run's doing -- on 2026-08-01
    # a 17:10 FOCUS commit made this read new_commits_on_main=1 for a run that
    # began at 20:34 and committed nothing.
    since="$(printf '%s' "$done_line" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]+' || true)"
    dstart="$(grep "DISPATCH .* $proj ->" "$RL" 2>/dev/null | tail -1 | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:+-]+' || true)"
    onmain="$(git -C "$PROJECTS/$proj" log --oneline --since="${dstart:-${since:-18 hours ago}}" main 2>/dev/null | grep -c . || true)"
    report="$(find "$HOME/reports/$proj" -name '*.md' -newermt '-18 hours' 2>/dev/null | head -1)"
    if [ "$dirty" = 0 ] && [ "$fail" = 0 ] && [ "$onmain" = 0 ] && [ -n "$report" ]; then
      met "3.3 $proj ran safely: tree clean, nothing on main, 0 failed units, report written"
      say "            $done_line"
      say "            report: $report"
      case "$done_line" in *NOT-DONE*)
        say "            NOTE: outcome=NOT-DONE (no verdict written) -- the runner will"
        say "            re-dispatch it every tick. Safe, but it will spin until the"
        say "            project writes a verdict or is unpaced." ;;
      esac
    else
      notmet "3.3 one safe run has completed" \
             "dirty=$dirty failed_units=$fail new_commits_on_main=$onmain report=${report:-none}"
    fi
  fi
fi

say ""
if [ "$unmet" = 0 ] && [ "$unproven" = 0 ]; then
  say "THE FLOOR IS MET -- 9/9."
  exit 0
fi
say "NOT MET -- $unmet unmet, $unproven unproven."
[ "$unproven" != 0 ] && say "(unproven is not met: a criterion nobody has exercised is a claim, not a check.)"
exit 1
