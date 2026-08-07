#!/usr/bin/env bash
# hardcoded-home-lint.test.sh -- the guard, and the shape it used to miss.
#
# WHY THIS FILE EXISTS. bin/hardcoded-home-lint.sh was written on 2026-08-07
# (#91) to refuse an absolute path into a named user's home, after
# `SCHED="/home/zach/Documents/Projects/scheduler"` in bashify/lib/coin.sh was
# found to make `coin` blind on every account that is not zach. It landed with
# no test and no runner: nothing in bin/tests/ and nothing in
# .github/workflows/ ever executed it, so its only witness was a green line
# printed by hand, once.
#
# It was wrong. It selected `git ls-files -- '*.sh' 'bin/*'`, which does not
# match an extensionless executable outside the repo-root bin/ --  and
# `bashify/bin/bashify`, the front door of the very family the guard was
# written about, carried the SAME two hardcoded paths the whole time. The lint
# printed "72 tracked files, no hardcoded home in code" over a set that
# excluded the defect. That is the more expensive failure mode of the two: a
# guard reporting clean retires the worry that would otherwise find the bug.
#
# THE LOAD-BEARING ASSERTION IS H5: an extensionless executable in a NESTED
# bin/ is scanned. Everything else is scaffolding. A version of this file
# without H5 would pass against the selection that shipped the blind spot.
#
# usage: ./bin/tests/hardcoded-home-lint.test.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LINT="$REPO/bin/hardcoded-home-lint.sh"
pass=0; fail=0
ok()   { printf '  ok   %s\n' "$*"; pass=$((pass+1)); }
bad()  { printf '  FAIL %s\n' "$*"; fail=$((fail+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (output lacked '$3')" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1 (output contained '$3')" ;; *) ok "$1" ;; esac; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

G() { git -c user.email=t@t -c user.name=t -C "$WORK/fix" "$@"; }

# One fixture repo carrying every shape at once, so a selection change cannot
# fix one case by dropping another.
mkdir -p "$WORK/fix/bin" "$WORK/fix/nested/bin" "$WORK/fix/archive"
G init -q -b main

# The path is assembled at runtime so that THIS test file does not itself trip
# the lint when the lint is run over this repository (H9 below runs it here).
H='/home/someuser/Documents/Projects'

# H1: a plain .sh with a hardcoded home, in code.
printf '#!/bin/sh\nP="%s/scheduler"\necho "$P"\n' "$H" > "$WORK/fix/bin/guilty.sh"

# H2: the same path, but in a full-line comment. Exempt on purpose -- every
# fix for this defect records the old path in a comment above the new line,
# and flagging those makes the guard fire loudest on its own successes.
printf '#!/bin/sh\n# was %s/scheduler\nP="$HOME/x"\n' "$H" > "$WORK/fix/bin/commented.sh"

# H3/H4: the opt-out must state a reason, so it cannot be pasted as a silencer.
printf '#!/bin/sh\nP="%s/x" # hardcoded-home-ok: a real reason\n' "$H" > "$WORK/fix/bin/optout.sh"
printf '#!/bin/sh\nP="%s/x" # hardcoded-home-ok:\n' "$H" > "$WORK/fix/bin/bareoptout.sh"

# H5: THE BLIND SPOT. No .sh, not under the repo-root bin/. This is exactly
# bashify/bin/bashify, which the shipped selection never looked at.
printf '#!/usr/bin/env bash\nSCHED="%s/scheduler"\n' "$H" > "$WORK/fix/nested/bin/frontdoor"
chmod +x "$WORK/fix/nested/bin/frontdoor"

# H6: tracked, contains the path, but is not code -- no shebang, no .sh. Notes
# and records must not be scanned, or the guard drowns in its own filing.
printf 'a note mentioning %s/scheduler\n' "$H" > "$WORK/fix/note.idea"

# H7: archive/ is a graveyard. Code that does not run cannot resolve a path
# wrongly.
printf '#!/bin/sh\nP="%s/scheduler"\n' "$H" > "$WORK/fix/archive/retired.sh"

G add -A >/dev/null; G commit -qm fixtures

out="$(bash "$LINT" "$WORK/fix" 2>&1)"; rc=$?

printf -- '-- H. what the guard looks at\n'
check "H1 a hardcoded home in a .sh is a finding (exit 1)" "$rc" "1"
has   "H1 and it names the file and line"        "$out" "bin/guilty.sh:2"
hasnt "H2 a full-line comment is exempt"         "$out" "commented.sh"
hasnt "H3 an opt-out WITH a reason is honoured"  "$out" "bin/optout.sh"
has   "H4 an opt-out with no reason is not"      "$out" "bareoptout.sh"
has   "H5 an extensionless executable in a NESTED bin/ is scanned" \
      "$out" "nested/bin/frontdoor"
hasnt "H6 a tracked non-code file is not scanned" "$out" "note.idea"
hasnt "H7 archive/ is exempt"                     "$out" "archive/retired.sh"

printf -- '\n-- I. clean, blind, and this repository\n'
# The negative. Without it, a lint that flagged every line would pass H1..H5.
rm -f "$WORK/fix/bin/guilty.sh" "$WORK/fix/bin/bareoptout.sh" \
      "$WORK/fix/nested/bin/frontdoor"
G add -A >/dev/null; G commit -qm 'clear the findings'
out="$(bash "$LINT" "$WORK/fix" 2>&1)"; rc=$?
check "I1 a repo with nothing to find exits 0" "$rc" "0"
has   "I1 and says how many files it read"     "$out" "tracked files, no hardcoded home"

# BLIND is exit 2 and must never be 0. "Found nothing" and "nothing is wrong"
# are different answers, and a directory that is not a repository yields the
# first.
mkdir -p "$WORK/notarepo"
out="$(bash "$LINT" "$WORK/notarepo" 2>&1)"; rc=$?
check "I2 a directory that is no repo is BLIND (exit 2), not 0" "$rc" "2"
has   "I2 and says so in those words"          "$out" "BLIND"

# The guard, run where it is meant to run. This is the assertion that would
# have gone red on 2026-08-07 the moment the selection was widened, and it is
# what keeps bashify/bin/bashify from quietly reacquiring the defect.
out="$(bash "$LINT" "$REPO" 2>&1)"; rc=$?
check "I3 THIS repository has no hardcoded home in code" "$rc" "0"
[ "$rc" = 0 ] || printf '%s\n' "$out" | sed 's/^/       /'

printf -- '\n--- hardcoded-home-lint: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
