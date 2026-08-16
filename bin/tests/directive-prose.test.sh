#!/usr/bin/env bash
# directive-prose.test.sh -- witness for bin/directive-prose.sh.
#
#
# Cases:
#   A uncited decision prose added            -> exit 1, names file and line
#   B the same line citing #123               -> exit 0
#   C cited on an ADJACENT line (within 3)    -> exit 0
#   D a citation 6 lines away is too far      -> exit 1
#   E DELETING decision prose is free         -> exit 0
#   F rejected patterns do not fire ("for now", "deliberately", "TODO")
#   G owner/repo#123 counts as a citation     -> exit 0
#   H an unresolvable range exits 3, never 0  (silent-zero)
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/directive-prose.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

n=0
# newrepo -> prints a repo path with one empty commit on `base`
newrepo() {
  n=$((n+1)); local d="$T/r$n"
  mkdir -p "$d"; git -C "$d" init -q
  git -C "$d" config user.email t@t; git -C "$d" config user.name t
  : > "$d/f.md"; git -C "$d" add -A; git -C "$d" commit -qm base
  printf '%s' "$d"
}
# commit_file <repo> <file> <heredoc on stdin>
commit_file() { cat > "$1/$2"; git -C "$1" add -A; git -C "$1" commit -qm change; }
run() { (cd "$1" && bash "$SCRIPT" 'HEAD~1..HEAD' 2>&1); }

echo "directive-prose.test.sh"

echo "-- A. uncited decision prose"
r="$(newrepo)"; commit_file "$r" f.md <<'EOF'
Zach-directed: chezz stays paused until someone says otherwise.
EOF
out="$(run "$r")"; rc "A1 exits 1" 1 $?
has "A2 names the file" "$out" "f.md"
has "A3 names the pattern hit" "$out" "Zach-directed"

echo "-- B. the same line, citing an issue"
r="$(newrepo)"; commit_file "$r" f.md <<'EOF'
Zach-directed (#294): chezz stays paused until someone says otherwise.
EOF
out="$(run "$r")"; rc "B1 exits 0" 0 $?
has "B2 says what it read" "$out" "no added line records a decision"

echo "-- C. cited on an adjacent line"
r="$(newrepo)"; commit_file "$r" f.md <<'EOF'
Tracking in #294.

SUPERSEDED 2026-08-15: the earlier plan is off.
EOF
run "$r" >/dev/null; rc "C1 exits 0" 0 $?

echo "-- D. a citation six lines away is not adjacent"
r="$(newrepo)"; commit_file "$r" f.md <<'EOF'
Tracking in #294.
a
b
c
d
e
SUPERSEDED 2026-08-15: the earlier plan is off.
EOF
run "$r" >/dev/null; rc "D1 exits 1" 1 $?

echo "-- E. deleting decision prose is free"
r="$(newrepo)"; commit_file "$r" f.md <<'EOF'
Zach-directed: chezz stays paused.
keep me
EOF
commit_file "$r" f.md <<'EOF'
keep me
EOF
run "$r" >/dev/null; rc "E1 exits 0" 0 $?

echo "-- F. the rejected patterns do not fire"
r="$(newrepo)"; commit_file "$r" f.md <<'EOF'
This is fine for now; the reset is deliberately not automatic.
TODO: rename the six lights. We decided that on purpose.
EOF
run "$r" >/dev/null; rc "F1 exits 0" 0 $?

echo "-- G. owner/repo#123 counts"
r="$(newrepo)"; commit_file "$r" f.md <<'EOF'
un-pause on 2026-08-19 (hf7y/scheduler#189).
EOF
run "$r" >/dev/null; rc "G1 exits 0" 0 $?

echo "-- H. silent zero: an unresolvable range is 3, never 0"
r="$(newrepo)"
out="$( (cd "$r" && bash "$SCRIPT" 'nosuchref..HEAD' 2>&1) )"; rc "H1 exits 3" 3 $?

summary
