#!/usr/bin/env bash
# HERMETICITY: builds bare remotes and clones in a temp dir, so the concurrent-
# writer race it drives is a real one against fixtures and never touches origin.
#
# focus-commit.test.sh -- witness for bin/focus-commit.sh. Offline, zero AI,
# no network: builds a throwaway bare remote + two clones in a temp dir and
# drives a real concurrent-writer race through the script.
#
# Seven cases, both directions (it must do the right thing AND refuse the
# wrong thing -- the crt/wtul verification bar):
#   1 happy path pushes
#   2 no-op commit refused loudly
#   3 unrelated staged file refused loudly (nothing rides along)
#   4 race on a DIFFERENT file -> auto fetch/rebase/verify/push
#   5 race rewriting a file we never named -> our commit still means the same
#   6 true same-file conflict -> abort, work preserved, nothing pushed
#   7 upstream RENAMES the file we edited -> the manifest check catches our
#     edit landing on a path we never named (the 2026-07-26 archive/ incident
#     shape), rebase undone, nothing pushed
#
# Usage: bin/tests/focus-commit.test.sh   (exit 0 = all pass)
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/focus-commit.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
check() { # <name> <expected-exit> <actual-exit>
  if [ "$2" = "$3" ]; then echo "  ok   $1"; pass=$((pass+1))
  else echo "  FAIL $1 (expected exit $2, got $3)"; fail=$((fail+1)); fi
}

cd "$T"
git init -q --bare remote.git
git clone -q remote.git a 2>/dev/null; git clone -q remote.git b 2>/dev/null
for r in a b; do git -C $r config user.email t@test; git -C $r config user.name T; done
cd a; git checkout -q -B main; mkdir archive
printf 'line1\n' > FOCUS.md; printf 'orig content\n' > archive/x.idea
git add -A; git commit -qm init; git push -q origin main
git branch -q --set-upstream-to=origin/main; cd ..
git -C b fetch -q; git -C b checkout -q -B main origin/main; git -C b branch -q --set-upstream-to=origin/main
printf 'test message\n' > "$T/msg.txt"

# other-writer helper: <commit-msg> <shell to mutate repo b>
upstream_writes() { git -C b pull -q --rebase; ( cd b && eval "$2" && git add -A && git commit -qm "$1" && git push -q ); }

echo "focus-commit.sh:"
cd a
printf 'line2\n' >> FOCUS.md
"$SCRIPT" . "$T/msg.txt" FOCUS.md >/dev/null 2>&1; check "happy path pushes" 0 $?

"$SCRIPT" . "$T/msg.txt" FOCUS.md >/dev/null 2>&1; check "no-op refused" 1 $?

printf 'sneaky\n' >> archive/x.idea; git add archive/x.idea; printf 'line3\n' >> FOCUS.md
"$SCRIPT" . "$T/msg.txt" FOCUS.md >/dev/null 2>&1; check "unrelated staged file refused" 1 $?
git reset -q --hard

cd ..; upstream_writes "other file" "printf 'other\n' > OTHER.md"; cd a
printf 'line4\n' >> FOCUS.md
"$SCRIPT" . "$T/msg.txt" FOCUS.md >/dev/null 2>&1; check "race on different file: rebase+push" 0 $?

cd ..; upstream_writes "archive rewrite" "printf 'upstream rewrote\n' > archive/x.idea"; cd a
printf 'line5\n' >> FOCUS.md
"$SCRIPT" . "$T/msg.txt" FOCUS.md >/dev/null 2>&1; check "race rewriting unnamed file: still clean" 0 $?

cd ..; upstream_writes "upstream focus" "printf 'UPSTREAM\n' >> FOCUS.md"; cd a
printf 'line6\n' >> FOCUS.md
"$SCRIPT" . "$T/msg.txt" FOCUS.md >/dev/null 2>&1; check "same-file conflict refused" 1 $?
grep -q 'line6' FOCUS.md; check "  ...and our work survives" 0 $?
git reset -q --hard origin/main

cd ..; upstream_writes "upstream renames" "git mv FOCUS.md RENAMED.md"; cd a
git reset -q --hard; printf 'line7\n' >> FOCUS.md
"$SCRIPT" . "$T/msg.txt" FOCUS.md >/dev/null 2>&1; check "rename-follow caught by manifest" 1 $?
remote_tip="$(git -C "$T/remote.git" log --oneline -1 main | grep -c 'upstream renames')"
check "  ...and nothing was pushed" 1 "$remote_tip"

echo "  $pass passed, $fail failed"
[ "$fail" -eq 0 ]
