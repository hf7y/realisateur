#!/usr/bin/env bash
# verb-set.test.sh -- the declared set, and the two defects it closes.
#
# THE LOAD-BEARING ASSERTION IS C1: a declared verb that is NOT installed makes
# install-verbs exit 1. Everything else is scaffolding.
#
# That case is precisely what scheduler/bin/deploy-drift-check.sh cannot see.
# It iterates its own bin/ and `continue`s when the installed file is absent,
# so a link that SHOULD exist but does not is never examined; with no overlap
# at all it prints "nothing to check" and exits 0. A version of this test that
# only checked "install-verbs runs and prints rows" would pass against an
# intersection check too, and would therefore prove nothing.
#
# The second defect is B2/B3: `bashify coin` asked `command -v` -- the HOST's
# PATH -- whether a verb name was free. Declarations live in repos, so on a
# host where nothing is installed every name reads as free. That is how `range`
# was assigned to both bibliothecaire and secretaire on 2026-07-30.
#
# Hermetic: builds its own project fixtures in a temp dir and overrides
# INSTALLE_PROJECTS / INSTALLE_BIN / INSTALLE_MANIFEST, so it never reads the
# live ecosystem and never writes to ~/.local/bin.
#
# usage: ./bin/tests/verb-set.test.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$REPO/bin/lib/verb-set.sh"
INSTALL_VERBS="$REPO/bin/install-verbs.sh"
COIN="$REPO/bashify/lib/coin.sh"

pass=0; fail=0
ok()   { printf '  ok   %s\n' "$*"; pass=$((pass+1)); }
bad()  { printf '  FAIL %s\n' "$*"; fail=$((fail+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }
has()  { if printf '%s' "$2" | grep -q -- "$3"; then ok "$1"; else bad "$1 (output lacked '$3')"; fi; }
hasnt(){ if printf '%s' "$2" | grep -q -- "$3"; then bad "$1 (output contained '$3')"; else ok "$1"; fi; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

export INSTALLE_PROJECTS="$WORK/projects"
export INSTALLE_BIN="$WORK/bin"
export INSTALLE_MANIFEST="$WORK/manifest.tsv"
mkdir -p "$INSTALLE_PROJECTS" "$INSTALLE_BIN"

G() { git -c user.email=t@t -c user.name=t -C "$1" "${@:2}"; }

# A project whose bashified branch declares <verbs>, plus one executable with
# NO man page (which must therefore not count as a verb).
make_project() {
  local name="$1"; shift
  local d="$INSTALLE_PROJECTS/$name" v
  mkdir -p "$d"; G "$d" init -q -b main
  echo x > "$d/README.md"; G "$d" add -A; G "$d" commit -qm init
  G "$d" checkout -q -b bashified
  mkdir -p "$d/bin" "$d/man"
  for v in "$@"; do
    printf '#!/bin/sh\necho %s\n' "$v" > "$d/bin/$v"; chmod 755 "$d/bin/$v"
    printf '.TH %s 1\n' "$v" > "$d/man/$v.1"
  done
  printf '#!/bin/sh\necho nope\n' > "$d/bin/noman"; chmod 755 "$d/bin/noman"
  G "$d" add -A; G "$d" commit -qm verbs
  G "$d" checkout -q main
}

make_project alpha aaa bbb
make_project beta  aaa           # deliberate collision with alpha
mkdir -p "$INSTALLE_PROJECTS/gamma"; G "$INSTALLE_PROJECTS/gamma" init -q -b main
echo x > "$INSTALLE_PROJECTS/gamma/README.md"
G "$INSTALLE_PROJECTS/gamma" add -A; G "$INSTALLE_PROJECTS/gamma" commit -qm init

# shellcheck source=../lib/verb-set.sh
. "$LIB"

printf -- '-- A. the declaration rule\n'
decl="$(verb_set_declared)"
has "A1 alpha declares aaa"                "$decl" 'alpha	aaa'
has "A2 alpha declares bbb"                "$decl" 'alpha	bbb'
has "A3 beta declares aaa"                 "$decl" 'beta	aaa'
hasnt "A4 an executable with no man page is not a verb" "$decl" 'noman'
hasnt "A5 a project with no bashified branch declares nothing" "$decl" 'gamma'
check "A6 three declarations in total" "$(printf '%s\n' "$decl" | grep -c .)" "3"

printf -- '-- B. claimants (the check `command -v` was standing in for)\n'
check "B1 aaa is claimed by both projects" "$(verb_set_claimants aaa | sort | tr '\n' ' ')" "alpha beta "
check "B2 an unused name is unclaimed"     "$(verb_set_claimants zzz)" ""
# The regression itself: nothing is installed in $INSTALLE_BIN, so `command -v`
# finds nothing, yet the name is plainly taken.
if command -v aaa >/dev/null 2>&1; then
  bad "B3 fixture precondition: 'aaa' must not be on the real PATH"
else
  check "B3 a declared-but-uninstalled name is still claimed" "$(verb_set_claimants aaa | head -1)" "alpha"
fi

# Linked worktrees are the same repository. Counting one twice would read as a
# collision with itself.
G "$INSTALLE_PROJECTS/alpha" worktree add -q "$INSTALLE_PROJECTS/alpha-verbs" bashified 2>/dev/null
decl2="$(verb_set_declared)"
check "B4 a checked-out worktree does not double-declare" \
  "$(printf '%s\n' "$decl2" | grep -c 'aaa')" "2"

printf -- '-- C. absence fails loud (the intersection defect)\n'
# C1 IS THE POINT OF THIS FILE, so it gets a fixture in which ABSENCE IS THE
# ONLY POSSIBLE FINDING. Run against the main fixture it would pass on the
# collision alone -- exit 1 for a reason that has nothing to do with absence --
# and an intersection check would score green. That is the "PASS text, not the
# count" trap this ecosystem already recorded against `bashify check` row 6.
SOLO="$WORK/solo"
mkdir -p "$SOLO/projects" "$SOLO/bin"
(
  export INSTALLE_PROJECTS="$SOLO/projects" INSTALLE_BIN="$SOLO/bin" INSTALLE_MANIFEST="$SOLO/manifest.tsv"
  d="$INSTALLE_PROJECTS/solo"
  mkdir -p "$d"; G "$d" init -q -b main
  echo x > "$d/README.md"; G "$d" add -A; G "$d" commit -qm init
  G "$d" checkout -q -b bashified
  mkdir -p "$d/bin" "$d/man"
  printf '#!/bin/sh\necho only\n' > "$d/bin/only"; chmod 755 "$d/bin/only"
  printf '.TH only 1\n' > "$d/man/only.1"
  G "$d" add -A; G "$d" commit -qm verbs; G "$d" checkout -q main
  solo_out="$("$INSTALL_VERBS" 2>&1)"; solo_rc=$?
  # One project, one verb, no collision, nothing installed. The ONLY thing
  # that can make this exit nonzero is noticing the absence.
  if [ "$solo_rc" = 1 ]; then printf '  ok   C1 absence ALONE exits 1 (no collision to hide behind)\n'
  else printf '  FAIL C1 absence ALONE exits 1 (got %s)\n' "$solo_rc"; exit 1; fi
  if printf '%s' "$solo_out" | grep -qE '^ABSENT +only'; then printf '  ok   C1b the absent verb is named ABSENT\n'
  else printf '  FAIL C1b the absent verb is named ABSENT\n'; exit 1; fi
  if printf '%s' "$solo_out" | grep -q 'COLLISION'; then printf '  FAIL C1c no collision is invented\n'; exit 1
  else printf '  ok   C1c no collision is invented\n'; fi
) || fail=$((fail+1))
pass=$((pass+3))

out="$("$INSTALL_VERBS" 2>&1)"; rc=$?
check "C2 the mixed fixture also exits 1" "$rc" "1"
# ANCHORED TO THE ROW, not to the word. The standing footer says "Re-run with
# --apply to install the ABSENT rows", so a bare `grep ABSENT` matches the
# prose and passes even when no verb was reported absent at all -- which is how
# this assertion first scored green against an intersection mutant. Same shape
# as `bashify check` row 6, recorded in bashify/GAPS.md: the row's PASS text
# said one thing while the page said the opposite, and only reading the text
# rather than the count caught it.
has   "C3 an ABSENT ROW exists for bbb"  "$out" '^ABSENT  *bbb'
has   "C4 the ABSENT row names the declaring project" "$out" '^ABSENT  *bbb  *alpha'
has   "C5 a COLLISION ROW exists for aaa" "$out" '^COLLISION  *aaa'
has   "C6 preflight says it wrote nothing" "$out" 'Nothing was written'

printf -- '-- D. a satisfied declaration reports OK\n'
ln -sfn "$INSTALLE_PROJECTS/alpha-verbs/bin/bbb" "$INSTALLE_BIN/bbb"
printf 'bbb\t%s\t2026-08-02\n' "$INSTALLE_PROJECTS/alpha-verbs/bin/bbb" > "$INSTALLE_MANIFEST"
out="$("$INSTALL_VERBS" 2>&1)"
if printf '%s' "$out" | grep -qE '^OK +bbb'; then ok "D1 an installed, manifested verb is OK"
else bad "D1 an installed, manifested verb is OK"; fi

# A link at the right target that installe did not make is still a finding:
# `installe retire` will refuse it, and it is the shape of the hand-made
# symlink whose deletion caused the 2026-07-29 dispatch outage.
printf '' > "$INSTALLE_MANIFEST"
out="$("$INSTALL_VERBS" 2>&1)"
has "D2 a hand-made link with the right target is UNOWNED" "$out" '^UNOWNED  *bbb'

# A dangling link must not read as present.
ln -sfn "$WORK/gone" "$INSTALLE_BIN/bbb"
out="$("$INSTALL_VERBS" 2>&1)"
has "D3 a dangling link is BROKEN" "$out" '^BROKEN  *bbb'

# A regular file at a verb's name is a human's, and is never touched.
rm -f "$INSTALLE_BIN/bbb"; printf '#!/bin/sh\n' > "$INSTALLE_BIN/bbb"; chmod 755 "$INSTALLE_BIN/bbb"
before="$(md5sum < "$INSTALLE_BIN/bbb")"
out="$("$INSTALL_VERBS" 2>&1)"
has   "D4 a regular file is FOREIGN" "$out" '^FOREIGN  *bbb'
check "D5 the foreign file is untouched" "$(md5sum < "$INSTALLE_BIN/bbb")" "$before"

printf -- '-- E. the generator refuses a name another project declares\n'
# coin resolves the project through scheduler's registry, so use a registered
# one and point it at a throwaway repo via BASHIFY_REPO. The claim check runs
# BEFORE any refusal that could write, so nothing is created either way.
SCRATCH="$WORK/scratch"; mkdir -p "$SCRATCH"; G "$SCRATCH" init -q -b main
echo x > "$SCRATCH/README.md"; G "$SCRATCH" add -A; G "$SCRATCH" commit -qm init

coin_out="$(BASHIFY_REPO="$SCRATCH" "$COIN" scheduler aaa 'a colliding name' 2>&1)"; coin_rc=$?
check "E1 coining a declared name exits 2" "$coin_rc" "2"
has   "E2 the refusal names the claiming project" "$coin_out" 'alpha'
has   "E3 the refusal explains what declared means" "$coin_out" 'whether or not it is installed here'

# The negative: a free name must pass the claim check and fail LATER, at the
# refusal about there being no branch to coin onto. Same command, different
# verb -- so a claim check that refused everything would be caught here.
free_out="$(BASHIFY_REPO="$SCRATCH" "$COIN" scheduler zzz 'a free name' 2>&1)"; free_rc=$?
check "E4 a free name is not refused by the claim check" "$free_rc" "7"
has   "E5 it got as far as the no-branch refusal" "$free_out" 'no '"'"'bashified'"'"' branch'
hasnt "E6 the free name was never called claimed" "$free_out" 'already declared'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
