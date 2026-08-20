#!/usr/bin/env bash
#
# TRAPS (the rest of this header is in the vault):
# WAS RED WHEN CI FIRST RAN IT (30/4, run 31217552355); CLOSED 2026-08-07, and
# the first diagnosis was REFUTED, which is the lesson. The hardcoded
# `SCHED="/home/zach/Documents/Projects/scheduler"` was real, but c8fc45e (#89)
# had ALREADY fixed it and said in its own message that it did not fix E2..E5.
# The remaining red was the HARNESS: section E drives `coin scheduler ...` and
# never registered `scheduler` in its own fixture registry -- it relied on the
# live one, which is exactly why it was green only on zach's box, and #89 is
# what stopped that working. `register scheduler` fixes it; no assertion
# bin/install-verbs.sh reads, instead of retyping the registry join, and reports
# BLIND rather than "no registered project" when the registry is absent.
#
# usage: ./bin/tests/verb-set.test.sh

set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$REPO/bin/lib/verb-set.sh"
INSTALL_VERBS="$REPO/bin/install-verbs.sh"

check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }
has()  { if printf '%s' "$2" | grep -q -- "$3"; then ok "$1"; else bad "$1 (output lacked '$3')"; fi; }
hasnt(){ if printf '%s' "$2" | grep -q -- "$3"; then bad "$1 (output contained '$3')"; else ok "$1"; fi; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

export INSTALLE_PROJECTS="$WORK/projects"
export INSTALLE_BIN="$WORK/bin"
export INSTALLE_MANIFEST="$WORK/manifest.tsv"
# The registry. Set EXPLICITLY, and every fixture project is registered in it,
# so the registration check (section F) contributes no finding to sections C/D.
# Left at its default it would resolve inside the fixture, find nothing, and
export SCHEDULE_DIR="$WORK/schedule"
mkdir -p "$INSTALLE_PROJECTS" "$INSTALLE_BIN" "$SCHEDULE_DIR"
register() { printf 'PROJECT="%s"\n' "$1" > "$SCHEDULE_DIR/$1.conf"; }

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
register alpha; register beta    # so section F contributes no finding here
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
SOLO="$WORK/solo"
mkdir -p "$SOLO/projects" "$SOLO/bin" "$SOLO/schedule"
(
  export INSTALLE_PROJECTS="$SOLO/projects" INSTALLE_BIN="$SOLO/bin" INSTALLE_MANIFEST="$SOLO/manifest.tsv"
  # Registered, so ABSENCE really is the only thing that can flag here.
  export SCHEDULE_DIR="$SOLO/schedule"
  printf 'PROJECT="solo"\n' > "$SCHEDULE_DIR/solo.conf"
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

printf -- '-- F. registration: the classification, re-checked every run\n'
# A verb is a UTILITY's finished form. The registry is what "utility" means
# here. A project deregistered after being bashified keeps its verb forever
# unless something re-checks; these assertions are that re-check.
FIX="$WORK/reg"
mkdir -p "$FIX/projects" "$FIX/bin" "$FIX/schedule"
(
  export INSTALLE_PROJECTS="$FIX/projects" INSTALLE_BIN="$FIX/bin" \
         INSTALLE_MANIFEST="$FIX/manifest.tsv" SCHEDULE_DIR="$FIX/schedule"
  d="$INSTALLE_PROJECTS/prod"
  mkdir -p "$d"; G "$d" init -q -b main
  echo x > "$d/README.md"; G "$d" add -A; G "$d" commit -qm init
  G "$d" checkout -q -b bashified
  mkdir -p "$d/bin" "$d/man"
  printf '#!/bin/sh\n' > "$d/bin/pverb"; chmod 755 "$d/bin/pverb"
  printf '.TH pverb 1\n' > "$d/man/pverb.1"
  G "$d" add -A; G "$d" commit -qm verbs; G "$d" checkout -q main

  # F1/F2: unregistered project declaring a verb.
  o="$("$INSTALL_VERBS" 2>&1)"; r=$?
  if printf '%s' "$o" | grep -qE '^  UNREGISTERED  *prod'; then printf '  ok   F1 an unregistered project is named UNREGISTERED\n'
  else printf '  FAIL F1 an unregistered project is named UNREGISTERED\n'; exit 1; fi
  if [ "$r" = 1 ]; then printf '  ok   F2 and it makes the run exit 1\n'
  else printf '  FAIL F2 and it makes the run exit 1 (got %s)\n' "$r"; exit 1; fi

  # F3: registering it clears the finding -- the check reads the registry, it
  # does not carry a hardcoded list of projects.
  printf 'PROJECT="prod"\n' > "$SCHEDULE_DIR/prod.conf"
  o="$("$INSTALL_VERBS" 2>&1)"
  if printf '%s' "$o" | grep -qE '^  UNREGISTERED'; then printf '  FAIL F3 registering clears the finding\n'; exit 1
  else printf '  ok   F3 registering clears the finding\n'; fi

  # F4/F5: an UNREADABLE registry is BLIND, never "nothing is a utility".
  # Reporting every project UNREGISTERED because the registry could not be read
  # would be the strong claim made from an absence -- BUILD-DISCIPLINE #1.
  o="$(SCHEDULE_DIR="$FIX/nosuchdir" "$INSTALL_VERBS" 2>&1)"
  if printf '%s' "$o" | grep -q 'BLIND: cannot read the registry'; then printf '  ok   F4 an unreadable registry reports BLIND\n'
  else printf '  FAIL F4 an unreadable registry reports BLIND\n'; exit 1; fi
  if printf '%s' "$o" | grep -qE '^  UNREGISTERED'; then printf '  FAIL F5 BLIND does not accuse every project of being unregistered\n'; exit 1
  else printf '  ok   F5 BLIND does not accuse every project of being unregistered\n'; fi
) || fail=$((fail+1))
pass=$((pass+5))

summary
