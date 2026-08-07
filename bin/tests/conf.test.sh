#!/usr/bin/env bash
# HERMETICITY: overrides HOME and SCHED_ROOT into a temp dir, so nothing it
# reads or writes is the live registry.
#
# conf.test.sh -- the defect that made propagation reach zero projects.
#
# THE LOAD-BEARING ASSERTIONS ARE A1 AND B1. A1: a conf written the way EVERY
# registered project writes it -- PROJECT_REPO_PATH="$HOME/..." -- resolves to
# a real directory. The raw `grep -oP` this replaces returned the literal
# characters `$HOME/...`, so `[ -d "$repo/.git" ]` was false for every project
# on every host and restamp-discipline.sh propagated the baseline to NOBODY
# while printing a tidy summary and exiting 0.
#
# B1: a run that reached nothing exits nonzero. Without it the fix is one bad
# conf away from silently regressing to the same shape, and the shape is the
# point: thirteen SKIP lines and exit 0 is what the defect looked like for as
# long as it lasted.
#
# Hermetic: builds its own scheduler root and its own target repos in a temp
# dir, overrides HOME and SCHED_ROOT, and never touches the live ecosystem.
#
# usage: ./bin/tests/conf.test.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$REPO/bin/lib/conf.sh"

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok    %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL  %s\n' "$1"; [ $# -gt 1 ] && printf '        %s\n' "$2"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "want [$3] got [$2]"; fi; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
printf 'conf.sh -- test\n\n'

# --- A: expansion -------------------------------------------------------------
printf 'A. the path a real conf carries resolves (A1 is the whole defect)\n'
printf 'PROJECT_REPO_PATH="$HOME/Documents/Projects/demo"\n' > "$T/a.conf"
got="$(HOME=/tmp/fakehome conf_repo_path "$T/a.conf")"
eq "A1  \$HOME is expanded"        "$got" "/tmp/fakehome/Documents/Projects/demo"
printf 'PROJECT_REPO_PATH="${HOME}/x"\n' > "$T/b.conf"
got="$(HOME=/tmp/fakehome conf_repo_path "$T/b.conf")"
eq "A2  \${HOME} is expanded too"  "$got" "/tmp/fakehome/x"
printf 'PROJECT_REPO_PATH="/opt/absolute"\n' > "$T/c.conf"
eq "A3  an absolute path is untouched" "$(conf_repo_path "$T/c.conf")" "/opt/absolute"
# A conf is a file this repo does not own. Expansion is by name, not by eval.
printf 'PROJECT_REPO_PATH="$(touch %s/PWNED)/x"\n' "$T" > "$T/d.conf"
conf_repo_path "$T/d.conf" >/dev/null 2>&1
if [ -e "$T/PWNED" ]; then bad "A4  a conf cannot execute code through this"
else ok "A4  a conf cannot execute code through this"; fi
printf 'OTHER="x"\n' > "$T/e.conf"
conf_repo_path "$T/e.conf" >/dev/null 2>&1
eq "A5  no PROJECT_REPO_PATH returns 1" "$?" "1"

# --- B: restamp-discipline, end to end ---------------------------------------
printf '\nB. restamp-discipline.sh against a fixture ecosystem\n'
H="$T/home"; mkdir -p "$H/Documents/Projects/demo" "$T/sched/schedule"
printf 'PROJECT_REPO_PATH="$HOME/Documents/Projects/demo"\n' > "$T/sched/schedule/demo.conf"
git -C "$H/Documents/Projects/demo" init -q
printf '# demo\n' > "$H/Documents/Projects/demo/CLAUDE.md"

out="$(HOME="$H" SCHED_ROOT="$T/sched" "$REPO/bin/restamp-discipline.sh" demo 2>&1)"; rc=$?
if printf '%s' "$out" | grep -q 'SKIP -- no git repo'; then
  bad "B1  a real checkout is not skipped" "$(printf '%s' "$out" | grep SKIP)"
else ok "B1  a real checkout is not skipped"; fi
if printf '%s' "$out" | grep -q '\$HOME'; then
  bad "B2  no literal \$HOME survives into the report"
else ok "B2  no literal \$HOME survives into the report"; fi
eq "B3  drift in a dry run exits 1" "$rc" "1"

# The regression guard: every project skipped must NOT be a clean pass.
rm -rf "$H/Documents/Projects/demo"
out="$(HOME="$H" SCHED_ROOT="$T/sched" "$REPO/bin/restamp-discipline.sh" demo 2>&1)"; rc=$?
eq "B4  a pass that reached nothing exits nonzero" "$rc" "1"
if printf '%s' "$out" | grep -q 'NOTHING WAS REACHED'; then
  ok "B4b and says so in words, not only in a code"
else bad "B4b and says so in words, not only in a code"; fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
