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
# realisateur#1043: verb_set_declared moved from a local scan of
# $INSTALLE_PROJECTS to the same three live GitHub calls cut-verb-build.sh
# makes (gh repo list / git ls-remote / gh api trees). Sections A/B/B5 below
# are HERMETIC the same way bin/tests/cut-verb-build-test.sh is: a fake `gh`
# on PATH answers out of local fixture repos, and GIT_CONFIG_GLOBAL rewrites
# https://github.com/<owner>/ to file://<fixture>/ so `git ls-remote` reaches
# them too -- same fixture shape, because the two scripts now read the
# identical three calls. Sections C/D/F still build REAL local checkouts
# under $INSTALLE_PROJECTS: verb_set_worktree_of ("is it actually installed
# on THIS host") did not move and is still local, on purpose.
#
# B4 is GONE. Its assertion was that a linked worktree of the same repo must
# not double-declare -- a defect only possible because the old scan walked a
# directory tree that could contain the same repository twice. A remote
# enumeration via ls-remote + one tree read per sha has no worktree to see
# twice, so the scenario that test built cannot arise on this path any more.

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
export SCHEDULE_DIR="$WORK/schedule"
mkdir -p "$INSTALLE_PROJECTS" "$INSTALLE_BIN" "$SCHEDULE_DIR"
register() { printf 'PROJECT="%s"\n' "$1" > "$SCHEDULE_DIR/$1.conf"; }

# Hermetic, not the shipped lib/not-a-verb.tsv (same reasoning as cut-verb-build-test.sh's fixture file).
export VERB_NOT_A_VERB_FILE="$WORK/not-a-verb.tsv"
printf '#project\tname\twhy\n' > "$VERB_NOT_A_VERB_FILE"

G() { git -c user.email=t@t -c user.name=t -C "$1" "${@:2}"; }
g() { git -c init.defaultBranch=main -c user.email=t@t -c user.name=t "$@" >/dev/null 2>&1; }

# --- the remote fixture: answers "what does the estate declare" -----------
# Same three calls, same fixture shape, as bin/tests/cut-verb-build-test.sh.
OWNER=fixtureowner
export VERB_SET_OWNER="$OWNER"
FIX="$WORK/fix"           # <repo>.git fixtures, read via ls-remote / gh api trees
REPOLIST="$WORK/repolist"
mkdir -p "$FIX"

mkrepo() {   # mkrepo <repo> <verb>...  -- a bashified branch carrying bin/<verb>
  local repo="$1"; shift
  local d="$FIX/$repo.git" v
  rm -rf "$d"; mkdir -p "$d/bin"
  for v in "$@"; do
    printf '#!/bin/sh\necho %s\n' "$v" > "$d/bin/$v"; chmod 755 "$d/bin/$v"
  done
  g init "$d"
  g -C "$d" checkout -b bashified
  g -C "$d" add -A
  g -C "$d" commit -m "bashified $repo"
}
mkrepo_no_bashified() {   # a repo the estate lists that never bashified itself
  local repo="$1"
  local d="$FIX/$repo.git"
  rm -rf "$d"; mkdir -p "$d"
  g init "$d"
  echo x > "$d/README.md"; g -C "$d" add -A; g -C "$d" commit -m init
}

# The fake gh: `repo list` from $FIXTURE_REPOLIST, the tree API from a local
# git repo under $FIXTURE_DIR. Verbatim shape of cut-verb-build-test.sh's own
# stub, because verb_set_declared now reads the identical three calls.
mkdir -p "$WORK/stub"
cat > "$WORK/stub/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status") exit 0 ;;
  "repo list")   cat "$FIXTURE_REPOLIST"; exit 0 ;;
esac
if [ "$1" = api ]; then
  path="$2"
  repo="$(printf '%s' "$path" | awk -F/ '{print $3}')"
  sha="$(printf '%s' "$path" | sed 's#.*/trees/##; s#?.*##')"
  d="$FIXTURE_DIR/$repo.git"
  [ -d "$d" ] || exit 1
  git -C "$d" ls-tree -r "$sha" 2>/dev/null \
    | awk '{ p=$4; for(i=5;i<=NF;i++) p=p" "$i; print $1, p }'
  exit 0
fi
exit 1
STUB
chmod +x "$WORK/stub/gh"

cat > "$WORK/gitconfig" <<EOF
[url "file://$FIX/"]
    insteadOf = https://github.com/$OWNER/
EOF

export PATH="$WORK/stub:$PATH"
export FIXTURE_REPOLIST="$REPOLIST" FIXTURE_DIR="$FIX"
export GIT_CONFIG_GLOBAL="$WORK/gitconfig" GIT_CONFIG_NOSYSTEM=1

# --- the local fixture: answers "is it actually installed on THIS host" ---
# verb_set_worktree_of never moved (realisateur#1043 only moved the DECLARED
# question) -- install-verbs.sh still needs a real checkout to resolve a
# declared verb's bin/<v> to a target it can compare a symlink against.
make_local_checkout() {
  local name="$1"; shift
  local d="$INSTALLE_PROJECTS/$name" v
  mkdir -p "$d"; G "$d" init -q -b main
  echo x > "$d/README.md"; G "$d" add -A; G "$d" commit -qm init
  G "$d" checkout -q -b bashified
  mkdir -p "$d/bin"
  for v in "$@"; do
    printf '#!/bin/sh\necho %s\n' "$v" > "$d/bin/$v"; chmod 755 "$d/bin/$v"
  done
  G "$d" add -A; G "$d" commit -qm verbs
  G "$d" checkout -q main
  G "$d" worktree add -q "$INSTALLE_PROJECTS/$name-verbs" bashified 2>/dev/null
}

mkrepo alpha aaa bbb
mkrepo beta  aaa                 # deliberate collision with alpha
mkrepo_no_bashified gamma
printf 'alpha\nbeta\ngamma\n' > "$REPOLIST"
register alpha; register beta    # so section F contributes no finding here

make_local_checkout alpha aaa bbb   # gives verb_set_worktree_of something to point at

# shellcheck source=../lib/verb-set.sh
. "$LIB"

printf -- '-- A. the declaration rule (now: three live GitHub calls, fixture-backed)\n'
decl="$(verb_set_declared)"
has "A1 alpha declares aaa"                                     "$decl" $'alpha\taaa'
has "A2 alpha declares bbb"                                     "$decl" $'alpha\tbbb'
has "A3 beta declares aaa"                                      "$decl" $'beta\taaa'
hasnt "A5 a project with no bashified branch declares nothing"  "$decl" 'gamma'
check "A6 three declarations in total" "$(printf '%s\n' "$decl" | grep -c .)" "3"
# (A4 -- "an executable with no man page is still a verb", #891 -- is
# dropped, not weakened: verb_set_declared never looked at man/ at all, even
# before #1043; the manifest-cutter's own man-page rules live in
# cut-verb-build.sh and are its suite's job, not this one's.)

printf 'alpha\tbbb\tfixture: not a door\n' > "$VERB_NOT_A_VERB_FILE"
decl_exempt="$(verb_set_declared)"
hasnt "A7 a name in lib/not-a-verb.tsv is not declared"            "$decl_exempt" $'alpha\tbbb'
has   "A8 ...and an unexempted name in the same project still is" "$decl_exempt" $'alpha\taaa'
printf '#project\tname\twhy\n' > "$VERB_NOT_A_VERB_FILE"   # restore for the sections below

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

printf -- '-- B5. BLIND is not empty (the caveat #1043 names by name) ------------\n'
# Every failure path below must return 6 (lib/registry-set.sh's own
# convention for "could not look") with NOTHING on stdout: a network hiccup
# or a bad credential must never look like "the estate declares nothing" to
# a caller that reads stdout alone.
authfail="$WORK/stub-authfail"; mkdir -p "$authfail"
cat > "$authfail/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in "auth status") exit 1 ;; esac
exit 1
STUB
chmod +x "$authfail/gh"
out="$(PATH="$authfail:$PATH" verb_set_declared 2>/dev/null)"; rc=$?
check "B5a gh unauthenticated returns 6, not 0"  "$rc"  "6"
check "B5b ...and prints nothing to stdout"      "$out" ""

listfail="$WORK/stub-listfail"; mkdir -p "$listfail"
cat > "$listfail/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status") exit 0 ;;
  "repo list")   exit 1 ;;
esac
exit 1
STUB
chmod +x "$listfail/gh"
out="$(PATH="$listfail:$PATH" verb_set_declared 2>/dev/null)"; rc=$?
check "B5c a failing repo list returns 6, not 0" "$rc"  "6"
check "B5d ...and prints nothing to stdout"      "$out" ""

listempty="$WORK/stub-listempty"; mkdir -p "$listempty"
cat > "$listempty/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status") exit 0 ;;
  "repo list")   exit 0 ;;   # prints nothing: an empty, READABLE list
esac
exit 1
STUB
chmod +x "$listempty/gh"
out="$(PATH="$listempty:$PATH" verb_set_declared 2>/dev/null)"; rc=$?
check "B5e a readable-but-empty repo list returns 6, not a clean zero" "$rc"  "6"
check "B5f ...and prints nothing to stdout"                            "$out" ""

# A repo GitHub lists but this credential/host cannot read (git ls-remote
# fails) is the exact case cut-verb-build.sh calls BLIND, not verbless.
printf 'alpha\nbeta\nghost\n' > "$REPOLIST"
out="$(verb_set_declared 2>/dev/null)"; rc=$?
check "B5g a listed-but-unreadable repo returns 6"     "$rc"  "6"
check "B5h ...and prints nothing, not a partial set"   "$out" ""
check "B5i ...and verb_set_claimants propagates 6, not \"unclaimed\"" \
      "$(verb_set_claimants aaa >/dev/null 2>&1; echo $?)" "6"
printf 'alpha\nbeta\ngamma\n' > "$REPOLIST"   # restore for the sections below

printf -- '-- C. absence fails loud (the intersection defect)\n'
# C1 IS THE POINT OF THIS FILE, so it gets a fixture in which ABSENCE IS THE
# ONLY POSSIBLE FINDING. Run against the main fixture it would pass on the
# collision alone -- exit 1 for a reason that has nothing to do with absence --
# and an intersection check would score green.
SOLO="$WORK/solo"
mkdir -p "$SOLO/projects" "$SOLO/bin" "$SOLO/schedule"
(
  export INSTALLE_PROJECTS="$SOLO/projects" INSTALLE_BIN="$SOLO/bin" INSTALLE_MANIFEST="$SOLO/manifest.tsv"
  # Registered, so ABSENCE really is the only thing that can flag here.
  export SCHEDULE_DIR="$SOLO/schedule"
  printf 'PROJECT="solo"\n' > "$SCHEDULE_DIR/solo.conf"

  # This subshell's ESTATE is just "solo" -- its own repolist, so the outer
  # alpha/beta/gamma fixture never leaks into it.
  mkrepo solo only
  printf 'solo\n' > "$SOLO/repolist"
  export FIXTURE_REPOLIST="$SOLO/repolist"

  d="$INSTALLE_PROJECTS/solo"
  mkdir -p "$d"; G "$d" init -q -b main
  echo x > "$d/README.md"; G "$d" add -A; G "$d" commit -qm init
  G "$d" checkout -q -b bashified
  mkdir -p "$d/bin"
  printf '#!/bin/sh\necho only\n' > "$d/bin/only"; chmod 755 "$d/bin/only"
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
# prose and passes even when no verb was reported absent at all.
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
REGWORK="$WORK/reg"
mkdir -p "$REGWORK/projects" "$REGWORK/bin" "$REGWORK/schedule"
(
  export INSTALLE_PROJECTS="$REGWORK/projects" INSTALLE_BIN="$REGWORK/bin" \
         INSTALLE_MANIFEST="$REGWORK/manifest.tsv" SCHEDULE_DIR="$REGWORK/schedule"

  mkrepo prod pverb
  printf 'prod\n' > "$REGWORK/repolist"
  export FIXTURE_REPOLIST="$REGWORK/repolist"

  d="$INSTALLE_PROJECTS/prod"
  mkdir -p "$d"; G "$d" init -q -b main
  echo x > "$d/README.md"; G "$d" add -A; G "$d" commit -qm init
  G "$d" checkout -q -b bashified
  mkdir -p "$d/bin"
  printf '#!/bin/sh\n' > "$d/bin/pverb"; chmod 755 "$d/bin/pverb"
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

  # F4/F5: an UNREADABLE registry is BLIND, never "nothing is a utility" --
  # reporting every project UNREGISTERED from an absence is the strong claim
  # made from a failure to look.
  o="$(SCHEDULE_DIR="$REGWORK/nosuchdir" "$INSTALL_VERBS" 2>&1)"
  if printf '%s' "$o" | grep -q 'BLIND: cannot read the registry'; then printf '  ok   F4 an unreadable registry reports BLIND\n'
  else printf '  FAIL F4 an unreadable registry reports BLIND\n'; exit 1; fi
  if printf '%s' "$o" | grep -qE '^  UNREGISTERED'; then printf '  FAIL F5 BLIND does not accuse every project of being unregistered\n'; exit 1
  else printf '  ok   F5 BLIND does not accuse every project of being unregistered\n'; fi
) || fail=$((fail+1))
pass=$((pass+5))

summary
