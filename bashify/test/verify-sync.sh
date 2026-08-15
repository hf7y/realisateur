#!/usr/bin/env bash
# verify-sync.sh -- the two guards that keep the runtime de-forked.
#
#   lib/runtime-check.sh   does any branch's lib/verb.sh differ from the skel?
#   lib/sync-runtime.sh    adopt the skel onto one branch -- refusing first if
#                          the branch's verbs need something the skel lacks
#
# THE LOAD-BEARING ASSERTIONS ARE B4 AND C1.
#
# B4: a project name that matches nothing must EXIT 1, not 0. A checker that
# reports clean about something it never looked at is this ecosystem's
# most-recorded failure, and a filter is where it hides best.
#
# C1: sync must REFUSE when a verb calls a function the skeleton does not
# define. Without it, adopting the union silently deletes that function and the
# verb breaks at a call site in a repo nobody opened. This is the guard that
# mechanically catches gardien -- whose `garde` calls `verb_gap_or_summon` four
# times, a function the skeleton deliberately omits because it calls `claude -p`
# directly in violation of the skeleton's own Law 3.
#
# gardien is NOT on an exemption list anywhere. C1 proves the refusal is
# DERIVED from the code, which is what makes it survive the day gardien is
# fixed -- and the day some other repo does the same thing.
#
# Hermetic: builds fixture repos in a temp dir, overrides INSTALLE_PROJECTS.
# Never reads the live ecosystem, never writes outside its temp dir.
set -uo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"   # bashify/
CHECK="$ROOT/lib/runtime-check.sh"
SYNC="$ROOT/lib/sync-runtime.sh"
SKEL="$ROOT/skel/lib/verb.sh"

pass=0; fail=0
ok()   { printf '  ok   %s\n' "$*"; pass=$((pass+1)); }
bad()  { printf '  FAIL %s\n' "$*"; fail=$((fail+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
export INSTALLE_PROJECTS="$WORK/projects"
mkdir -p "$INSTALLE_PROJECTS"
G() { git -c user.email=t@t -c user.name=t -C "$1" "${@:2}"; }

# mkproj <name> <runtime-file> [extra-line-in-verb]
mkproj() {
  local name="$1" runtime="$2" extra="${3:-}"
  local d="$INSTALLE_PROJECTS/$name"
  mkdir -p "$d"; G "$d" init -q -b main
  echo x > "$d/README.md"; G "$d" add -A; G "$d" commit -qm init
  G "$d" checkout -q -b bashified
  mkdir -p "$d/bin" "$d/man" "$d/lib"
  cp "$runtime" "$d/lib/verb.sh"
  { printf '#!/usr/bin/env bash\nSELF="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"\n'
    printf 'VERB_NAME=%s\nVERB_SUMMARY="x"\nVERB_CAN_SUMMON=0\n. "$SELF/lib/verb.sh"\n' "$name"
    [ -n "$extra" ] && printf '%s\n' "$extra"
    printf 'verb_parse "$@"\n'
  } > "$d/bin/$name"
  chmod 755 "$d/bin/$name"
  printf '.TH %s 1\n' "$name" > "$d/man/$name.1"
  G "$d" add -A; G "$d" commit -qm verbs
  # Leave bashified CHECKED OUT in a worktree, which is what sync writes into.
  G "$d" checkout -q main
  G "$d" worktree add -q "$INSTALLE_PROJECTS/$name-wt" bashified
}

# mkproj_bare <name> <runtime-file> [extra-line-in-verb] -- same as mkproj, but
# bashified is left committed and UNCHECKED-OUT anywhere: no <name>-wt worktree.
# This is the shape every project is in today, now that installe stopped
# leaving one lying around (2026-08-05) -- see hf7y/realisateur#158.
mkproj_bare() {
  local name="$1" runtime="$2" extra="${3:-}"
  local d="$INSTALLE_PROJECTS/$name"
  mkdir -p "$d"; G "$d" init -q -b main
  echo x > "$d/README.md"; G "$d" add -A; G "$d" commit -qm init
  G "$d" checkout -q -b bashified
  mkdir -p "$d/bin" "$d/man" "$d/lib"
  cp "$runtime" "$d/lib/verb.sh"
  { printf '#!/usr/bin/env bash\nSELF="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"\n'
    printf 'VERB_NAME=%s\nVERB_SUMMARY="x"\nVERB_CAN_SUMMON=0\n. "$SELF/lib/verb.sh"\n' "$name"
    [ -n "$extra" ] && printf '%s\n' "$extra"
    printf 'verb_parse "$@"\n'
  } > "$d/bin/$name"
  chmod 755 "$d/bin/$name"
  printf '.TH %s 1\n' "$name" > "$d/man/$name.1"
  G "$d" add -A; G "$d" commit -qm verbs
  G "$d" checkout -q main
}

OLD="$WORK/old-runtime.sh"
{ grep -v 'verb_refuse()' "$SKEL" | head -n -0; } > /dev/null 2>&1
# An "older" runtime: the skeleton minus verb_refuse, standing in for a dialect.
sed '/^verb_refuse() {/,+2d' "$SKEL" > "$OLD"

printf -- '-- A. runtime-check reports drift\n'
mkproj current "$SKEL"
mkproj stale   "$OLD"
out="$("$CHECK" 2>&1)"; rc=$?
check "A1 a drifted branch makes it exit 1" "$rc" "1"
printf '%s' "$out" | grep -qE '^  OK +current' && ok "A2 an identical branch is OK" || bad "A2 an identical branch is OK"
printf '%s' "$out" | grep -qE '^  DRIFT +stale' && ok "A3 the drifted branch is named" || bad "A3 the drifted branch is named"

printf -- '-- B. it cannot report clean about what it did not look at\n'
out="$("$CHECK" current 2>&1)"; rc=$?
check "B1 filtering to a clean project exits 0" "$rc" "0"
out="$("$CHECK" stale 2>&1)"; rc=$?
check "B2 filtering to the drifted one exits 1" "$rc" "1"
printf '%s' "$out" | grep -qE '^  OK +current' \
  && bad "B3 a filter really filters (current not checked)" \
  || ok "B3 a filter really filters (current not checked)"
# B4 IS LOAD-BEARING.
out="$("$CHECK" nosuchproject 2>&1)"; rc=$?
check "B4 a name matching nothing exits 1, NOT 0" "$rc" "1"
printf '%s' "$out" | grep -q 'refusing to exit 0' \
  && ok "B5 and it says why rather than printing an empty clean report" \
  || bad "B5 and it says why"

printf -- '-- C. sync REFUSES before it can break a verb\n'
# A verb calling a function the skeleton does not define. Adopting the skeleton
# would delete it. This is gardien's shape, reproduced without naming gardien.
mkproj needy "$OLD" 'verb_gap_or_summon() { :; }
_unused() { verb_needs_something_absent "x"; }'
out="$("$SYNC" needy 2>&1)"; rc=$?
check "C1 sync refuses when the skeleton lacks a called function" "$rc" "1"
printf '%s' "$out" | grep -q 'MISSING FUNCTION' && ok "C2 it names what is missing" || bad "C2 it names what is missing"
printf '%s' "$out" | grep -q 'verb_needs_something_absent' \
  && ok "C3 it names the specific function, not just 'something'" \
  || bad "C3 it names the specific function"
# And it must NOT have written anything on a refusal.
cmp -s "$INSTALLE_PROJECTS/needy-wt/lib/verb.sh" "$SKEL" \
  && bad "C4 a refused sync wrote the runtime anyway" \
  || ok "C4 a refused sync wrote nothing"
# A function the verb DEFINES ITSELF is not the skeleton's problem.
printf '%s' "$out" | grep -q 'verb_gap_or_summon' \
  && bad "C5 a locally-defined function is not reported missing" \
  || ok "C5 a locally-defined function is not reported missing"

printf -- '-- D. preflight writes nothing; --apply writes and does not commit\n'
before="$(md5sum < "$INSTALLE_PROJECTS/stale-wt/lib/verb.sh")"
"$SYNC" stale >/dev/null 2>&1
check "D1 preflight left the runtime byte-identical" \
  "$(md5sum < "$INSTALLE_PROJECTS/stale-wt/lib/verb.sh")" "$before"
"$SYNC" stale --apply >/dev/null 2>&1
if cmp -s "$INSTALLE_PROJECTS/stale-wt/lib/verb.sh" "$SKEL"; then ok "D2 --apply adopted the skeleton"
else bad "D2 --apply adopted the skeleton"; fi
# Left in the working tree so it can be read before it becomes history.
if [ -n "$(G "$INSTALLE_PROJECTS/stale-wt" status --porcelain)" ]; then
  ok "D3 --apply did NOT commit -- the change is readable first"
else bad "D3 --apply committed on its own"; fi
# And a dirty tree must now block a second sync.
out="$("$SYNC" stale 2>&1)"
printf '%s' "$out" | grep -q 'already byte-identical' \
  && ok "D4 a synced branch reports already-identical" || bad "D4 a synced branch reports already-identical"

printf -- '-- E. the guard and the sync agree about what a BRANCH is\n'
# A branch is its COMMITTED state. sync --apply deliberately does not commit,
# so between apply and commit the guard must neither report plain DRIFT (which
# reads as "the sync failed") nor report OK (which would be a lie -- the branch
# has not adopted it). It reports UNCOMMITTED and still exits 1.
out="$("$CHECK" stale 2>&1)"; rc=$?
check "E1 an applied-but-uncommitted sync still exits 1" "$rc" "1"
printf '%s' "$out" | grep -qE '^  UNCOMMITTED +stale' \
  && ok "E2 and it says UNCOMMITTED, not DRIFT" || bad "E2 and it says UNCOMMITTED, not DRIFT"
printf '%s' "$out" | grep -qE '^  DRIFT +stale' \
  && bad "E3 it does not read as a failed sync" || ok "E3 it does not read as a failed sync"
# Commit it, and only then is the branch clean.
G "$INSTALLE_PROJECTS/stale-wt" add lib/verb.sh
G "$INSTALLE_PROJECTS/stale-wt" commit -qm 'adopt skeleton runtime'
out="$("$CHECK" stale 2>&1)"; rc=$?
check "E4 once COMMITTED the branch is clean" "$rc" "0"

printf -- '-- F. no worktree at all: sync reads the committed branch directly\n'
# F. hf7y/realisateur#158: sync used to REFUSE outright when nothing had
# checked bashified out into a worktree, and print advice to hand-create one --
# advice that named exactly the mechanism installe stopped producing on
# 2026-08-05, so it fired for every project, always. Preflight must now work
# with no worktree at all, and --apply must create one rather than ask a human
# to.
mkproj_bare current-bare "$SKEL"
mkproj_bare stale-bare   "$OLD"
[ -e "$INSTALLE_PROJECTS/current-bare-verbs" ] \
  && bad "F0 no worktree exists yet for current-bare" \
  || ok "F0 no worktree exists yet for current-bare"

out="$("$SYNC" current-bare 2>&1)"; rc=$?
check "F1 preflight on an identical, worktree-less branch exits 0" "$rc" "0"
printf '%s' "$out" | grep -q 'already byte-identical' \
  && ok "F2 and reports already-identical, reading the commit" \
  || bad "F2 and reports already-identical"
[ -e "$INSTALLE_PROJECTS/current-bare-verbs" ] \
  && bad "F3 preflight must not create a worktree as a side effect" \
  || ok "F3 preflight must not create a worktree as a side effect"

out="$("$SYNC" stale-bare 2>&1)"; rc=$?
check "F4 preflight on a drifted, worktree-less branch exits 0 (report only)" "$rc" "0"
printf '%s' "$out" | grep -q 'would replace lib/verb.sh' \
  && ok "F5 and it reports what would change, read via git show" \
  || bad "F5 and it reports what would change"
[ -e "$INSTALLE_PROJECTS/stale-bare-verbs" ] \
  && bad "F6 preflight must not create a worktree here either" \
  || ok "F6 preflight must not create a worktree here either"

# A missing-function refusal must also work with no worktree: reading `bin/*`
# out of the commit, not a checkout.
mkproj_bare needy-bare "$OLD" 'verb_gap_or_summon() { :; }
_unused() { verb_needs_something_absent "x"; }'
out="$("$SYNC" needy-bare 2>&1)"; rc=$?
check "F7 sync refuses a missing function with no worktree present" "$rc" "1"
printf '%s' "$out" | grep -q 'verb_needs_something_absent' \
  && ok "F8 and still names the specific function" \
  || bad "F8 and still names the specific function"
[ -e "$INSTALLE_PROJECTS/needy-bare-verbs" ] \
  && bad "F9 a refused sync must not leave a worktree behind" \
  || ok "F9 a refused sync must not leave a worktree behind"

# --apply is the one path allowed to create the worktree, at the conventional
# <project>-verbs path -- the same path the old refusal used to print as advice.
"$SYNC" stale-bare --apply >/dev/null 2>&1
wt="$INSTALLE_PROJECTS/stale-bare-verbs"
[ -d "$wt" ] && ok "F10 --apply created the worktree at <project>-verbs" \
  || bad "F10 --apply created the worktree at <project>-verbs"
if cmp -s "$wt/lib/verb.sh" "$SKEL"; then ok "F11 --apply wrote the skeleton into it"
else bad "F11 --apply wrote the skeleton into it"; fi
branch="$(G "$wt" branch --show-current 2>/dev/null)"
check "F12 the created worktree is ON the bashified branch, not detached" "$branch" "bashified"
if [ -n "$(G "$wt" status --porcelain)" ]; then
  ok "F13 --apply did not commit -- the worktree it just made is left dirty to read"
else bad "F13 --apply did not commit"; fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
