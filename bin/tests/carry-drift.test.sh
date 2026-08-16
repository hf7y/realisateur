#!/usr/bin/env bash
#
# Contract test for bin/carry-drift.sh: a carried file that stops matching its
# home on main is a finding, and could-not-look is never clean.
#
# HERMETICITY: full. Every case builds its own repository with its own
# `bashified` branch under $T -- check F of guard-estate.test.sh, and the bug
# this suite would have caught while the guard was being written: it preferred
# the LOCAL `bashified` ref, which was five carries stale here, and reported
# "0 carried files" and exit 0 against a branch carrying six.
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

CD="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/carry-drift.sh"
harness_tmp

# A repository with a main worktree and a `bashified` branch carrying two
# files: one replica, one drifted.
mk_repo() {
  local r="$T/$1"; shift
  mkdir -p "$r/bin/lib"
  git -C "$r" init -q 2>/dev/null || git init -q "$r"
  git -C "$r" config user.email t@t; git -C "$r" config user.name t
  printf 'same\n'    > "$r/bin/lib/cli-guard.sh"
  printf 'main v2\n' > "$r/bin/reach-lint.sh"
  printf '#!/usr/bin/env bash\necho shim\n' > "$r/bin/gh-sign.sh"
  printf 'grammar\n' > "$r/bin/lib/body-grammar.sh"
  git -C "$r" add -A >/dev/null; git -C "$r" commit -qm main
  git -C "$r" checkout -q --orphan bashified
  git -C "$r" rm -q -rf . >/dev/null 2>&1 || :
  mkdir -p "$r/bin/lib"
  printf 'same\n'    > "$r/bin/lib/cli-guard.sh"
  printf 'main v1\n' > "$r/bin/reach-lint.sh"   # the drift
  printf 'native\n'  > "$r/bin/arpente"          # branch-native: never graded
  # the two DECLARED carries, present and matching, so the cases below are
  # about one property each
  printf '#!/usr/bin/env bash\necho shim\n' > "$r/bin/gh"
  printf 'grammar\n' > "$r/bin/lib/body-grammar.sh"
  git -C "$r" add -A >/dev/null; git -C "$r" commit -qm carry
  git -C "$r" checkout -q master 2>/dev/null || git -C "$r" checkout -q main
  printf '%s' "$r"
}

REPO="$(mk_repo repo)"
EMPTY_RATCHET="$T/empty.ratchet"; : > "$EMPTY_RATCHET"

echo "carry-drift contract"

section "A. a carried file that stopped matching is a finding"
out="$(bash "$CD" --repo "$REPO" --ratchet "$EMPTY_RATCHET" 2>&1)"; rc=$?
rc  "A1 exit 1 when a carry has drifted" 1 "$rc"
has "A2 it names the drifted file"  "$out" "DRIFT     bin/reach-lint.sh"
has "A3 the replica is reported ok" "$out" "ok        bin/lib/cli-guard.sh"

section "B. what is not a carry is not graded"
# bin/arpente exists only on bashified. Grading it would demand a file on main
# that is not supposed to exist, which would make every real verb a finding.
hasnt "B1 a branch-native file produces no row" "$out" "arpente"

section "C. the ratchet forgives, and only what it names"
printf 'pair bin/reach-lint.sh bin/reach-lint.sh\n' > "$T/r.ratchet"
out="$(bash "$CD" --repo "$REPO" --ratchet "$T/r.ratchet" 2>&1)"; rc=$?
rc  "C1 a ratcheted pair exits 0"  0 "$rc"
has "C2 ...and still says so"      "$out" "RATCHETED bin/reach-lint.sh"

section "D. --carry writes the replica, and closes the finding"
mkdir -p "$T/wt/bin"
cp "$REPO/bin/lib/cli-guard.sh" "$T/wt/bin/"
printf 'main v1\n' > "$T/wt/bin/reach-lint.sh"
out="$(bash "$CD" --repo "$REPO" --ratchet "$EMPTY_RATCHET" --carry "$T/wt" 2>&1)"
eq  "D1 the drifted file is overwritten with main's" "$(cat "$T/wt/bin/reach-lint.sh")" "main v2"
has "D2 ...and it says what it wrote" "$out" "carried  bin/reach-lint.sh"

section "E. a rename is followed"
# bin/gh on bashified is bin/gh-sign.sh on main -- the one pair that cannot be
# derived from the tree, and the reason the guard has a RENAMES table at all.
has "E1 bin/gh is paired with bin/gh-sign.sh" "$out" "bin/gh                     bin/gh-sign.sh"
git -C "$REPO" checkout -q bashified
printf '#!/usr/bin/env bash\necho EDITED IN PLACE\n' > "$REPO/bin/gh"
git -C "$REPO" commit -qam 'edit the replica' >/dev/null
git -C "$REPO" checkout -q master 2>/dev/null || git -C "$REPO" checkout -q main
out="$(bash "$CD" --repo "$REPO" --ratchet "$EMPTY_RATCHET" 2>&1)"; rc=$?
rc  "E2 editing the shipped copy in place is caught" 1 "$rc"
has "E3 ...and named"  "$out" "DRIFT     bin/gh"

section "F. BLIND is not clean"
mkdir -p "$T/nobranch"; git -C "$T/nobranch" init -q 2>/dev/null || git init -q "$T/nobranch"
out="$(bash "$CD" --repo "$T/nobranch" --ratchet "$EMPTY_RATCHET" 2>&1)"; rc=$?
rc  "F1 no bashified ref exits 3, not 0" 3 "$rc"
has "F2 ...and says it could not look"   "$out" "BLIND"
out="$(bash "$CD" --repo "$T/does-not-exist" 2>&1)"; rc=$?
rc  "F3 an absent repo is BLIND too" 3 "$rc"

section "H. a DECLARED carry that was never made is a finding, not silence"
# The shape of hf7y/realisateur#327: the shim merged, nothing carried it, and
# every check stayed green because nothing knew it was supposed to be there.
git -C "$REPO" checkout -q bashified
git -C "$REPO" rm -q bin/gh; git -C "$REPO" commit -qm 'drop the carry' >/dev/null
git -C "$REPO" checkout -q master 2>/dev/null || git -C "$REPO" checkout -q main
out="$(bash "$CD" --repo "$REPO" --ratchet "$EMPTY_RATCHET" 2>&1)"; rc=$?
rc  "H1 a declared carry that is absent exits 1" 1 "$rc"
has "H2 ...and is named MISSING, not omitted" "$out" "MISSING   bin/gh"
rm -rf "$T/wt2"; mkdir -p "$T/wt2"
bash "$CD" --repo "$REPO" --ratchet "$EMPTY_RATCHET" --carry "$T/wt2" >/dev/null 2>&1
eq  "H3 --carry creates the file that was never there" \
    "$(cat "$T/wt2/bin/gh" 2>/dev/null)" "$(cat "$REPO/bin/gh-sign.sh")"

section "G. it honours where it is pointed"
# The guard resolves its own checkout by default. Pointed at $T it must grade
# $T -- 9 of 11 guards probed on 2026-08-07 ignored this.
out="$(bash "$CD" --repo "$REPO" --ratchet "$EMPTY_RATCHET" 2>&1)"
has "G1 the report names the repo it was pointed at" "$out" "$REPO"
hasnt "G2 ...and not this checkout" "$out" "$(cd "$(dirname "$CD")/.." && pwd)/bin"

summary
