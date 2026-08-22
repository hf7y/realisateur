#!/usr/bin/env bash
# defere-scan.test.sh -- witness for `defere.sh --scan` (#534).
#
# Two measured defects, both found by running the mandated pre-PR check
# (#523: "run defere --scan before every PR") exactly as instructed:
#
#   1. It compared base...HEAD, so a deletion only staged (or only in the
#      worktree) was invisible -- the scan reported clean at the one moment
#      it exists to catch, and only saw the dangle after `git commit`.
#   2. The retraction rule matched only the single line naming the deleted
#      file. Retraction prose is often a paragraph, so a comment block that
#      plainly narrates the deletion still tripped the scan when the keyword
#      ("deleted", "retired"...) landed a line or two away from the filename.
#
# HERMETIC. Builds its own throwaway git repo; touches nothing outside $T.
#
# usage: ./bin/tests/defere-scan.test.sh

set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/bin/defere.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

echo "defere-scan.test.sh"
harness_tmp

REPO="$T/repo"
mkdir -p "$REPO/bin"
git init -q -b main "$REPO"
git -C "$REPO" config user.email t@test
git -C "$REPO" config user.name T
cp -r "$ROOT/bin/lib" "$REPO/bin/lib"

echo hello > "$REPO/victim.txt"
printf 'line1\nthis references victim.txt in prose\nline3\n' > "$REPO/referrer.txt"
git -C "$REPO" add -A
git -C "$REPO" commit -q -m init

scan() { ( cd "$REPO" && DEFERE_BASE=main bash "$SCRIPT" --scan ) 2>&1; }

section "A. a staged, uncommitted deletion is not invisible (#534 bug 1)"

git -C "$REPO" checkout -q -b feature-a
rm "$REPO/victim.txt"
git -C "$REPO" add -A
A1_OUT="$(scan)"; A1_RC=$?
rc  "A1 staged deletion, no commit yet -> scan still finds the dangle" 1 "$A1_RC"
has "A1 names the real referrer" "$A1_OUT" "referrer.txt"

git -C "$REPO" commit -q -m "delete victim"
A2_OUT="$(scan)"; A2_RC=$?
rc  "A2 same finding survives the commit" 1 "$A2_RC"
has "A2 still names the referrer" "$A2_OUT" "referrer.txt"

section "B. a paragraph-level retraction is recognized (#534 bug 2)"

git -C "$REPO" checkout -q main
git -C "$REPO" checkout -q -b feature-b
rm "$REPO/victim.txt"
printf '# Note about victim.txt:\n# it used to hold config, referenced by loader.\n# it was deleted 2026-08-22 as part of the cleanup.\n' \
  > "$REPO/retraction.txt"
git -C "$REPO" add -A
git -C "$REPO" commit -q -m "delete victim, add multi-line retraction"
B1_OUT="$(scan)"; B1_RC=$?
rc   "B1 the real referrer is still caught" 1 "$B1_RC"
has  "B1 names referrer.txt" "$B1_OUT" "referrer.txt"
hasnt "B1 does not flag the paragraph retraction" "$B1_OUT" "retraction.txt"

section "C. a pure manifest line (no other referrer) is quiet"

git -C "$REPO" checkout -q main
git -C "$REPO" checkout -q -b feature-c
rm "$REPO/victim.txt"
rm "$REPO/referrer.txt"
printf 'victim.txt\n' > "$REPO/manifest.txt"
git -C "$REPO" add -A
git -C "$REPO" commit -q -m "delete victim, leave only a manifest row"
C1_OUT="$(scan)"; C1_RC=$?
rc "C1 clean: nothing left names victim.txt except its own manifest row" 0 "$C1_RC"

summary
