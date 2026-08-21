#!/usr/bin/env bash
# no-worktree-lint.test.sh -- the witness for the guard that keeps
# `git worktree add` out of this repository's production paths.
#
#
# THE LOAD-BEARING ASSERTION IS A2: a production file that gains a
# `git worktree add` must turn the guard RED. Everything else is scaffolding.
# A version of this suite without A2 would pass against a guard whose scan had
# been deleted -- which is the exact regression it exists to catch. A2 is
# mutation-verified: with the FLAG line commented out of the guard, A2 (and
# only A2) goes red.
#
# The second load-bearing one is B1. An allowlist that cannot rot is the only
# reason this guard uses one instead of a .ratchet, and B1 is what makes that
# claim true rather than stated.
#
# usage: ./bin/tests/no-worktree-lint.test.sh
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LINT="$REPO/bin/no-worktree-lint.sh"

check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
G() { git -c user.email=t@t -c user.name=t -C "$1" "${@:2}"; }

# mkfixture <name> -- a git repo with one ordinary production script in bin/.
mkfixture() {
  local d="$WORK/$1"
  rm -rf "$d"; mkdir -p "$d/bin" "$d/bin/tests"
  G "$d" init -q -b main .
  printf '#!/usr/bin/env bash\necho ordinary\n' > "$d/bin/plain.sh"
  G "$d" add -A >/dev/null; G "$d" commit -qm init >/dev/null
  printf '%s' "$d"
}

# run <root> -> sets $out and $rc
run() { out="$(bash "$LINT" "$1" 2>&1)"; rc=$?; }

echo "== A. THE SCAN =="

# A1 -- a tree with no worktree creation anywhere is clean, and says so with a
# COUNT. A guard whose clean output is silence cannot be told from one that
# did not run.
d="$(mkfixture clean)"
run "$d"
check "A1 a clean tree exits 0" "$rc" "0"
has   "A1 and reports zero" "$out" "0 FLAG(s)"

# A2 -- THE REGRESSION. Adding one production creator turns it red.
d="$(mkfixture creator)"
printf '#!/usr/bin/env bash\ngit worktree add -b x "$T" main\n' > "$d/bin/creator.sh"
G "$d" add -A >/dev/null; G "$d" commit -qm creator >/dev/null
run "$d"
check "A2 a production creator exits 1" "$rc" "1"
has   "A2 and names the file and line" "$out" "bin/creator.sh:2"
has   "A2 and counts it" "$out" "1 FLAG(s)"

# A3 -- `git -C <dir> worktree add` is the form the real creators used; a
# pattern matching only bare `git worktree add` misses them.
d="$(mkfixture dashc)"
printf '#!/usr/bin/env bash\ngit -C "$R" worktree add -q "$W" bashified\n' > "$d/bin/creator.sh"
G "$d" add -A >/dev/null; G "$d" commit -qm creator >/dev/null
run "$d"
check "A3 'git -C <dir> worktree add' is caught" "$rc" "1"

# A4 -- removal is the FIX, not the defect, and must not be flagged. A guard
# that reddened on cleanup would push authors to delete their cleanup.
d="$(mkfixture remover)"
printf '#!/usr/bin/env bash\ngit -C "$R" worktree remove --force "$W"\ngit -C "$R" worktree prune\n' > "$d/bin/rm.sh"
G "$d" add -A >/dev/null; G "$d" commit -qm rm >/dev/null
run "$d"
check "A4 worktree remove/prune is not a finding" "$rc" "0"

# A5 -- a COMMENT describing the mechanism is not the mechanism. Both real
# scheduler scripts carry explanatory comments naming the command, and a guard
# that could not tell a comment from a call would have been un-passable
# without deleting the explanations.
d="$(mkfixture commented)"
printf '#!/usr/bin/env bash\n# it used to run: git worktree add -b x "$T" main\necho no\n' > "$d/bin/c.sh"
G "$d" add -A >/dev/null; G "$d" commit -qm c >/dev/null
run "$d"
check "A5 a comment naming the command is not a finding" "$rc" "0"

# A6 -- the test tree is EXEMPT. Hermetic worktrees under mktemp are correct
# usage; bin/tests/closeout-lint.test.sh needs them to have anything to assert
# about, and this guard must not make that suite unwritable.
d="$(mkfixture testtree)"
printf '#!/usr/bin/env bash\ngit -C "$T" worktree add -q "$T/side" side\n' > "$d/bin/tests/x.test.sh"
G "$d" add -A >/dev/null; G "$d" commit -qm t >/dev/null
run "$d"
check "A6 bin/tests/ is exempt" "$rc" "0"

# A7 -- and so is archive/, on bin/shellcheck-lint.sh's stated reasoning:
# retired code is kept as evidence, and a guard that demands evidence be
# maintained is a guard that gets switched off.
d="$(mkfixture archived)"
mkdir -p "$d/archive/old"
printf '#!/usr/bin/env bash\ngit worktree add -b x "$T" main\n' > "$d/archive/old/loop.sh"
G "$d" add -A >/dev/null; G "$d" commit -qm a >/dev/null
run "$d"
check "A7 archive/ is exempt" "$rc" "0"

# A8 -- an UNTRACKED creator is not a finding. Same rule as
# bin/shellcheck-lint.sh: a scratch file in someone's working tree must not be
# able to redden a shared gate.
d="$(mkfixture untracked)"
printf '#!/usr/bin/env bash\ngit worktree add -b x "$T" main\n' > "$d/bin/scratch.sh"
run "$d"
check "A8 an untracked creator is not a finding" "$rc" "0"

echo
echo "== B. THE ALLOWLIST CANNOT ROT =="

# B1 -- THE OTHER LOAD-BEARING ONE. The guard's allowlist is compiled in, so
# this asserts the property against the real guard and the real tree: every
# allowlisted path must still exist AND still match. An entry that has stopped
# earning its place is a FLAG, not a silent pass -- which is what a .ratchet's
# --accept gives you and what an inline list would otherwise lack.
run "$REPO"
has   "B1 the real tree reports on its allowlist" "$out" "EVERY ALLOWLIST ENTRY STILL EARNS ITS PLACE"
hasnt "B1 and no entry is stale" "$out" "stale allowlist"

# B2 -- an allowlisted path that has stopped matching is a FLAG. This is the
# rot the compiled list would otherwise accumulate: a file gets fixed, the
# entry excusing it stays, and the next real violation in that file is
# pre-forgiven by a line nobody re-read. Exercised through
# NO_WORKTREE_ALLOW_FILE so the assertion does not require breaking the tree.
d="$(mkfixture rotted)"
printf '#!/usr/bin/env bash\necho no worktrees here\n' > "$d/bin/was-a-creator.sh"
G "$d" add -A >/dev/null; G "$d" commit -qm fixed >/dev/null
printf 'bin/was-a-creator.sh\tfixed long ago, entry never removed\n' > "$WORK/allow-rotted.tsv"
out="$(NO_WORKTREE_ALLOW_FILE="$WORK/allow-rotted.tsv" bash "$LINT" "$d" 2>&1)"; rc=$?
check "B2 an entry that no longer matches is a finding" "$rc" "1"
has   "B2 and is named as stale" "$out" "stale allowlist"

# B3 -- an entry naming a file that no longer exists is equally stale. Deleting
# the file is the commonest way an excuse outlives its subject.
printf 'bin/deleted-creator.sh\tthe file is gone\n' > "$WORK/allow-gone.tsv"
out="$(NO_WORKTREE_ALLOW_FILE="$WORK/allow-gone.tsv" bash "$LINT" "$d" 2>&1)"; rc=$?
check "B3 an entry for a missing file is a finding" "$rc" "1"
has   "B3 and is named as stale" "$out" "does not exist"

# B4 -- and a LIVE entry suppresses the finding it was written for, which is
# the half that makes the list useful rather than decorative.
d="$(mkfixture excused)"
printf '#!/usr/bin/env bash\necho "run: git worktree add -b x \$T main" >&2\n' > "$d/bin/advice.sh"
G "$d" add -A >/dev/null; G "$d" commit -qm advice >/dev/null
out="$(bash "$LINT" "$d" 2>&1)"; rc=$?
check "B4 without an entry the mention is a finding" "$rc" "1"
printf 'bin/advice.sh\tprints the command, executes nothing\n' > "$WORK/allow-live.tsv"
out="$(NO_WORKTREE_ALLOW_FILE="$WORK/allow-live.tsv" bash "$LINT" "$d" 2>&1)"; rc=$?
check "B4 with an entry it is excused" "$rc" "0"
has   "B4 and the reason is printed, not hidden" "$out" "executes nothing"

echo
echo "== C. NO STRAY WORKTREE IS ACTUALLY REGISTERED NOW =="

d="$(mkfixture strayed)"
G "$d" branch other >/dev/null
G "$d" worktree add -q "$WORK/strayed-side" other >/dev/null
run "$d"
check "C1 a registered linked worktree is a finding" "$rc" "1"
has   "C1 and names the path" "$out" "$WORK/strayed-side"
has   "C1 and counts it" "$out" "1 FLAG(s)"
G "$d" worktree remove --force "$WORK/strayed-side" >/dev/null 2>&1

d="$(mkfixture solo)"
run "$d"
check "C2 a tree with only the main worktree is clean" "$rc" "0"
hasnt "C2 and names no stray worktree" "$out" "stray worktree"

d="$(mkfixture excusedwt)"
G "$d" branch other >/dev/null
G "$d" worktree add -q "$WORK/excusedwt-side" other >/dev/null
printf '%s\t%s\n' "$WORK/excusedwt-side" "review copy, removed after use" > "$WORK/allow-wt.tsv"
out="$(NO_WORKTREE_WT_ALLOW_FILE="$WORK/allow-wt.tsv" bash "$LINT" "$d" 2>&1)"; rc=$?
check "C3 an allowlisted worktree path is excused" "$rc" "0"
has   "C3 and the reason is printed" "$out" "review copy, removed after use"
G "$d" worktree remove --force "$WORK/excusedwt-side" >/dev/null 2>&1

# C4 -- once that worktree is gone, the entry excusing it is a FLAG (B2's rule).
d="$(mkfixture rottedwt)"
out="$(NO_WORKTREE_WT_ALLOW_FILE="$WORK/allow-wt.tsv" bash "$LINT" "$d" 2>&1)"; rc=$?
check "C4 an entry with no matching worktree is a finding" "$rc" "1"
has   "C4 and is named as stale" "$out" "stale worktree allowlist"

# C5 -- THE REGRESSION (#505): the live guard flagged its OWN main checkout
# as a stray worktree of itself. Reproduced here by invoking through a
# SYMLINKED alias of the checkout: `git worktree list --porcelain` always
# prints the canonical (symlink-resolved) path for the main worktree, but
# $ROOT can be the symlink path itself (a bare `pwd` after `cd`ing through
# one keeps it, unlike `git rev-parse --show-toplevel`) -- same directory,
# two spellings. Comparing them by STRING equality made the main checkout
# fail to recognize itself. The fix identifies "main" by POSITION (git
# worktree list always lists it first), not by string-matching $ROOT.
d="$(mkfixture symlinked)"
alias_path="$WORK/symlinked-alias"
ln -s "$d" "$alias_path"
out="$(bash "$LINT" "$alias_path" 2>&1)"; rc=$?
check "C5 a symlinked alias of the main checkout is not a stray worktree of itself" "$rc" "0"
hasnt "C5 and does not flag itself as a stray worktree" "$out" "stray worktree"
rm -f "$alias_path"

echo
echo "== D. IT REFUSES RATHER THAN REPORTS CLEAN =="

# D1 -- a directory that is not a git tree is BLIND, exit 2. "Could not look"
# reported as "nothing wrong" is the pathology this estate has paid for
# repeatedly; a scan of zero files must never grade as green.
mkdir -p "$WORK/notarepo"
out="$(cd "$WORK/notarepo" && bash "$LINT" 2>&1)"; rc=$?
check "D1 a non-repo is BLIND (6), not clean" "$rc" "6"
has   "D1 and says BLIND" "$out" "BLIND"

# D2 -- a git repo with no tracked shell at all is BLIND too, for the same
# reason: `bin/tests/*.sh matched nothing` was a real CI defect here, and a
# lint that lints nothing is its twin.
d="$WORK/emptyrepo"; mkdir -p "$d"
G "$d" init -q -b main . >/dev/null
printf 'x\n' > "$d/README.md"; G "$d" add -A >/dev/null; G "$d" commit -qm init >/dev/null
run "$d"
check "D2 a repo with no shell to scan is BLIND (6)" "$rc" "6"
has   "D2 and says BLIND" "$out" "BLIND"

echo
echo "== R. THE REAL TREE =="

# R1 -- the assertion the pull request is actually making. Not a fixture: this
# checkout, today. If a later change reintroduces a creator, this is the line
# that goes red in the `suites` check.
run "$REPO"
check "R1 this checkout has no production worktree creator" "$rc" "0"
has   "R1 and the scan was not empty" "$out" "tracked shell file(s)"

echo
summary
exit $(( fail > 0 ? 1 : 0 ))
