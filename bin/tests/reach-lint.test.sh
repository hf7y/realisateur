#!/usr/bin/env bash
#
# reach-lint.test.sh -- witness for bin/reach-lint.sh's --strict /
# --strict-reach exit-code plumbing. reach-lint.sh's two checks (A scope
# declaration, B reach) and their exit-code wiring were already correct
# before this file existed -- confirmed by reading the script and by the
# fact that install-shims.sh already relies on `reach-lint.sh --strict-reach`
# exit status. This file closes the missing-negative-test gap: no test
# anywhere exercised either exit path before this.
#
# Offline, zero AI, no network: a fixture scheduler registry (schedule/*.conf)
# per case, plus fixture .claude/commands/*.md files. USER_CMD_DIR is pointed
# at a directory that deliberately does not exist, so a real ~/.claude/commands
# on the machine running this test can never leak in and make a case flaky.
#
# Cases:
#   A clean scan (scope: project, no named commands)
#       -> --strict AND --strict-reach both exit 0
#   B scope-undeclared only (no frontmatter, no fenced commands) -- check A
#     dirty, check B clean
#       -> --strict exits 1 (check A FLAGged)
#       -> --strict-reach STAYS exit 0 -- this is the documented split
#          (check A is a convention other repos haven't adopted; a caller
#          that only cares about reach must not be held hostage by it)
#   C unreachable command (scope: user, fenced block names a command that
#     resolves nowhere) -- check B dirty
#       -> --strict AND --strict-reach both exit 1
#   D scope: user file naming only a real, resolvable command -- clean
#       -> --strict AND --strict-reach both exit 0
#
# Usage: bin/tests/reach-lint.test.sh   (exit 0 = all pass)
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/reach-lint.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { echo "  ok   $1"; pass=$((pass+1)); }
bad() { echo "  FAIL $1"; fail=$((fail+1)); }
# has <name> <output> <pattern> -- output must contain pattern
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing: $3)" ;; esac; }
# rc <name> <expected-exit> <actual-exit>
rc()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected exit $2, got $3)"; fi; }

NO_USER_CMDS="$T/no-user-cmds"   # deliberately does not exist

# run <sched_root> [args...] -- sets RUN_OUT / RUN_RC
run() {
  local sched="$1"; shift
  RUN_OUT="$(SCHED_ROOT="$sched" USER_CMD_DIR="$NO_USER_CMDS" "$SCRIPT" "$@" 2>&1)"
  RUN_RC=$?
}

mkreg() { # mkreg <sched_root> <project_dir>
  mkdir -p "$1/schedule"
  printf 'PROJECT_REPO_PATH="%s"\n' "$2" > "$1/schedule/proj.conf"
}

echo "reach-lint.test.sh"

echo "-- A. clean scan"
mkdir -p "$T/A/proj/.claude/commands"
mkreg "$T/A/sched" "$T/A/proj"
cat > "$T/A/proj/.claude/commands/clean.md" <<'EOF'
---
scope: project
---
# clean command
Just prose. No fenced command blocks, nothing to resolve.
EOF
run "$T/A/sched"
has "A default run reports 0 FLAGs"      "$RUN_OUT" "== 0 FLAG(s) =="
run "$T/A/sched" --strict
rc  "A --strict exits 0 on a clean scan"  0 "$RUN_RC"
run "$T/A/sched" --strict-reach
rc  "A --strict-reach exits 0 too"        0 "$RUN_RC"

echo "-- B. scope-undeclared only (check A dirty, check B clean)"
mkdir -p "$T/B/proj/.claude/commands"
mkreg "$T/B/sched" "$T/B/proj"
cat > "$T/B/proj/.claude/commands/noscope.md" <<'EOF'
# a command file with no frontmatter at all
Nothing here declares scope: project or scope: user.
EOF
run "$T/B/sched"
has "B default run FLAGs scope-undeclared"   "$RUN_OUT" "FLAG [scope-undeclared]"
has "B reach check (B) itself stays clean"   "$RUN_OUT" "no scope:user command files and nothing installed"
run "$T/B/sched" --strict
rc  "B --strict exits 1 (check A FLAGged)"                1 "$RUN_RC"
run "$T/B/sched" --strict-reach
rc  "B --strict-reach STAYS 0 (check B clean, by design)" 0 "$RUN_RC"

echo "-- C. unreachable command (check B dirty)"
mkdir -p "$T/C/proj/.claude/commands"
mkreg "$T/C/sched" "$T/C/proj"
cat > "$T/C/proj/.claude/commands/unreach.md" <<'EOF'
---
scope: user
---
# names a command that does not exist anywhere on PATH
```
totally-fake-reach-lint-test-cmd-xyz --version
```
EOF
run "$T/C/sched"
has "C default run FLAGs unreachable"                     "$RUN_OUT" "FLAG [unreachable]"
run "$T/C/sched" --strict
rc  "C --strict exits 1"                                  1 "$RUN_RC"
run "$T/C/sched" --strict-reach
rc  "C --strict-reach ALSO exits 1 (check B FLAGged)"     1 "$RUN_RC"

echo "-- D. scope: user naming a real, resolvable command"
mkdir -p "$T/D/proj/.claude/commands"
mkreg "$T/D/sched" "$T/D/proj"
cat > "$T/D/proj/.claude/commands/reachable.md" <<'EOF'
---
scope: user
---
# names a command that resolves everywhere
```
ls -la
```
EOF
run "$T/D/sched"
has "D default run reports 0 FLAGs"          "$RUN_OUT" "== 0 FLAG(s) =="
run "$T/D/sched" --strict
rc  "D --strict exits 0"                     0 "$RUN_RC"
run "$T/D/sched" --strict-reach
rc  "D --strict-reach exits 0"               0 "$RUN_RC"

echo "-- E. a registry whose paths resolve to NOTHING is BLIND, not clean"
# The #73 shape: every conf readable, every path a literal `$HOME/...`, every
# match impossible. Before this guard, that produced "(no project command
# files found)", "== 0 FLAG(s) ==" and exit 0 -- a lint that scanned nothing
# and reported clean.
mkdir -p "$T/E/sched/schedule"
printf 'PROJECT_REPO_PATH="%s/E/does-not-exist"\n' "$T" > "$T/E/sched/schedule/proj.conf"
run "$T/E/sched"
rc  "E1 exits 3 BLIND when no conf resolves"   3 "$RUN_RC"
has "E2 and says BLIND in words, not only in a code" "$RUN_OUT" "BLIND"
run "$T/E/sched" --strict-reach
rc  "E3 --strict-reach is BLIND too, not 0"    3 "$RUN_RC"

echo "-- F. no registry AT ALL is not blind -- install-shims.sh depends on it"
# F is the negative that keeps E honest, and it is not hypothetical: the first
# version of E's guard tested `repos == 0` alone, which made every host with no
# scheduler registry blind. CI is such a host, and install-shims.sh runs
# `reach-lint.sh --strict-reach` and flags on any nonzero -- so that version
# turned install-shims.test.sh D5 red. Check B is still meaningful here: it
# reads ~/.claude/commands, which has nothing to do with the registry.
mkdir -p "$T/F/sched/schedule"     # exists, but holds no confs
run "$T/F/sched"
rc  "F1 a registry with no confs exits 0, not BLIND"  0 "$RUN_RC"
run "$T/F/nonexistent-sched"
rc  "F2 a missing registry directory exits 0 too"     0 "$RUN_RC"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
