#!/usr/bin/env bash
#
# SUBJECT: bin/carry.sh -- the actuator for the carries bin/tests/carry-drift.test.sh detects.
#
# THE DEFECT THIS PINS, 2026-08-25. The detector outlived its actuator:
# realisateur#511 deleted bin/carry-drift.sh and kept the test, so every carry
# since has been a hand fix. One of those hand fixes ran
# `git push origin main:bashified`, which is not a carry -- it made bashified
# EQUAL main and deleted the 13 files bashified carries that main does not
# have (lib/verb.sh, CONTRACT.md, GAPS.md, every man/*.1, the carried lints,
# runtime.yml). They were restored from 7c9ac0c.
#
# So the assertion that matters here is NEGATIVE: carrying moves the paths
# carries.tsv names and leaves every other path on the branch alone. Section C
# proves that against a real repo, because a grep of the source cannot.
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
C="$REPO/bin/carry.sh"
code() { grep -v '^[[:space:]]*#' "$1"; }   # comments are not wiring

echo "carry.test.sh"

section "A. it exists, and refuses rather than guessing"
[ -x "$C" ] && ok "bin/carry.sh is present and executable" \
  || bad "bin/carry.sh is present and executable" "missing -- the detector has no actuator again"
has "A1 --check is the default, so a bare run cannot write" "$(code "$C")" 'MODE=--check'
has "A2 an unknown flag is usage (2), not a finding" "$(code "$C")" 'usage "unknown argument'
has "A3 an unreadable ref is BLIND (6), never 'nothing to carry'" "$(code "$C")" 'blind "$r is not readable'
has "A4 an empty table is BLIND, not a clean run" "$(code "$C")" 'carries.tsv named zero carried files'
has "A5 a vanished source is a finding, not a silent skip" "$(code "$C")" 'Carrying nothing.'

section "B. one source: it reads the table the detector reads, from the same ref"
has "B1 the table comes from the main ref, not the working tree" \
  "$(code "$C")" 'git show "$REF_MAIN:bin/lib/carries.tsv"'
has "B2 same comment/blank filter as carry-drift.test.sh" \
  "$(code "$C")" "grep -v '^#' | grep -v"
hasnt "B3 it never pushes a branch onto a branch" "$(code "$C")" 'main:refs/heads/'
has "B4 it pushes a commit it built, under a lease on the sha it read" \
  "$(code "$C")" '--force-with-lease="refs/heads/$BRANCH:$OLD"'
has "B6 the repo is overridable, so this suite can use a fixture" "$(code "$C")" '${CARRY_REPO:-'
has "B5 the carried mode comes from the source, so a hook stays executable" \
  "$(code "$C")" 'git ls-tree "$REF_MAIN" -- "$src"'

section "C. it carries the named paths and LEAVES THE REST OF THE BRANCH ALONE"
# The 2026-08-25 accident, reproduced in a throwaway repo. `only-on-bashified`
# stands in for lib/verb.sh and friends: a file the target branch has and the
# source branch does not. A carry must not notice it.
# harness_tmp SETS $T; it does not print it. `T="$(harness_tmp)"` captured empty
# stdout, `cd ""` is a silent no-op in bash, and this fixture ran `git init` and
# four commits INSIDE THE REPO UNDER TEST -- it moved the branch and overwrote
# bin/lib/carries.tsv. Caught 2026-08-25, before the guard below existed.
harness_tmp
case "$T" in
  ''|"$REPO"|"$REPO"/*)
    bad "C0 the fixture has a temp dir OUTSIDE the repo under test" \
        "T='$T' -- refusing to run git init against the repo this suite is testing"
    summary; exit $? ;;
esac
(
  set -e
  cd "$T"
  git init -q -b main .
  git config user.email t@t; git config user.name t
  mkdir -p bin/lib
  printf 'carried\tsource\n' > /dev/null
  printf '# table\nCARRIED.md\tSOURCE.md\n' > bin/lib/carries.tsv
  printf 'v1\n' > SOURCE.md
  git add -A; git commit -qm main1
  git checkout -q -b bashified
  printf 'v1\n' > CARRIED.md
  printf 'do not touch me\n' > only-on-bashified
  git rm -q --cached SOURCE.md; rm -f SOURCE.md
  git add -A; git commit -qm bashified1
  git checkout -q main
  printf 'v2 CHANGED\n' > SOURCE.md
  git add -A; git commit -qm main2
  # A bare "remote" that is this same repo, so push has somewhere to land.
  git clone -q --bare . "$T/remote.git"
  git remote add origin "$T/remote.git"
  git push -q origin main bashified
  git fetch -q origin
) >/dev/null 2>&1 || { bad "C0 fixture repo built" "setup failed"; summary; exit $?; }
ok "C0 fixture repo built (bashified holds a file main does not)"

run_carry() { ( cd "$T" && CARRY_REPO="$T" CARRY_REMOTE=origin CARRY_BRANCH=bashified \
   CARRY_REF_MAIN=origin/main CARRY_REF_BASH=origin/bashified CARRY_PROJECT_NAME=fixtureproj \
   bash "$C" "$@" 2>&1 ); }

out="$(run_carry --check)"
case "$out" in *"CARRIED.md"*) ok "C1 --check names the drifted carried file" ;;
  *) bad "C1 --check names the drifted carried file" "got: $out" ;; esac
case "$out" in *"NOT carried"*) ok "C2 --check says it wrote nothing" ;;
  *) bad "C2 --check says it wrote nothing" "got: $out" ;; esac
before="$( cd "$T" && git rev-parse origin/bashified )"
after="$( cd "$T" && git fetch -q origin && git rev-parse origin/bashified )"
eq "C3 --check moved the branch not at all" "$before" "$after"

out="$(run_carry --apply)"
( cd "$T" && git fetch -q origin ) >/dev/null 2>&1
got="$( cd "$T" && git show origin/bashified:CARRIED.md 2>/dev/null )"
eq "C4 --apply carried the new content" "$got" "v2 CHANGED"
if ( cd "$T" && git cat-file -e origin/bashified:only-on-bashified 2>/dev/null ); then
  ok "C5 the file only bashified had SURVIVED the carry"
else
  bad "C5 the file only bashified had SURVIVED the carry" \
      "carry deleted it -- this is the 2026-08-25 accident, reproduced"
fi
if ( cd "$T" && git cat-file -e origin/bashified:SOURCE.md 2>/dev/null ); then
  bad "C6 the carry did not drag main's own path onto the branch" "SOURCE.md appeared on bashified"
else
  ok "C6 the carry did not drag main's own path onto the branch"
fi

out="$(run_carry --check)"
case "$out" in *"none drifted"*) ok "C7 a second --check is clean: the carry took" ;;
  *) bad "C7 a second --check is clean: the carry took" "got: $out" ;; esac

section "E. a DECLARED retirement deletes bin/<verb> and man/<verb>.1 from bashified, and nothing else"
( cd "$T" \
  && git fetch -q origin \
  && git checkout -q main && git reset -q --hard origin/main \
  && printf '#project\tverb\twhy\nfixtureproj\tzeta\ttest retirement\nother\teta\tanother project'"'"'s row -- must not fire here\n' \
       > bin/lib/retired-verbs.tsv \
  && git add -A && git commit -qm main-retired-verbs \
  && git checkout -q bashified && git reset -q --hard origin/bashified \
  && mkdir -p bin man \
  && printf '#!/usr/bin/env bash\necho zeta\n' > bin/zeta && chmod +x bin/zeta \
  && printf '.TH ZETA 1\n' > man/zeta.1 \
  && printf '#!/usr/bin/env bash\necho eta\n' > bin/eta && chmod +x bin/eta \
  && printf '.TH ETA 1\n' > man/eta.1 \
  && git add -A && git commit -qm bashified-zeta-eta \
  && git checkout -q main \
  && git push -q origin main bashified \
  && git fetch -q origin \
) >/dev/null 2>&1 || bad "E0 fixture extended with a retiree verb" "setup failed"

out="$(run_carry --check)"
case "$out" in *"RETIRE"*"bin/zeta"*) ok "E1 --check names the file staged for retirement" ;;
  *) bad "E1 --check names the file staged for retirement" "got: $out" ;; esac
case "$out" in *"man/zeta.1"*) ok "E2 --check names the man page too" ;;
  *) bad "E2 --check names the man page too" "got: $out" ;; esac
case "$out" in *"NOT carried"*) ok "E3 --check writes nothing" ;;
  *) bad "E3 --check writes nothing" "got: $out" ;; esac
before="$( cd "$T" && git rev-parse origin/bashified )"
after="$( cd "$T" && git fetch -q origin && git rev-parse origin/bashified )"
eq "E4 --check moved the branch not at all" "$before" "$after"

out="$(run_carry --apply)"
( cd "$T" && git fetch -q origin ) >/dev/null 2>&1
if ( cd "$T" && git cat-file -e origin/bashified:bin/zeta 2>/dev/null ); then
  bad "E5 bin/zeta is gone from bashified after --apply" "it is still there"
else
  ok "E5 bin/zeta is gone from bashified after --apply"
fi
if ( cd "$T" && git cat-file -e origin/bashified:man/zeta.1 2>/dev/null ); then
  bad "E6 man/zeta.1 is gone from bashified after --apply" "it is still there"
else
  ok "E6 man/zeta.1 is gone from bashified after --apply"
fi
if ( cd "$T" && git cat-file -e origin/bashified:bin/eta 2>/dev/null ); then
  ok "E7 a retirement row naming a DIFFERENT project does not fire here"
else
  bad "E7 a retirement row naming a DIFFERENT project does not fire here" "bin/eta was deleted too"
fi
if ( cd "$T" && git cat-file -e origin/bashified:CARRIED.md 2>/dev/null ); then
  ok "E8 an unrelated carried file survives a retirement-only commit"
else
  bad "E8 an unrelated carried file survives a retirement-only commit" "CARRIED.md is gone too"
fi
if ( cd "$T" && git cat-file -e origin/bashified:only-on-bashified 2>/dev/null ); then
  ok "E9 an untracked bashified-only file survives too"
else
  bad "E9 an untracked bashified-only file survives too" "only-on-bashified is gone"
fi

out="$(run_carry --check)"
case "$out" in *"no declared retirement pending"*) ok "E10 idempotent: a second run finds nothing left to retire" ;;
  *) bad "E10 idempotent: a second run finds nothing left to retire" "got: $out" ;; esac

section "D2. overriding where to read without where to write is a usage error"
# The 2026-08-25 accident: this suite handed carry.sh a fixture's refs while
# CARRY_REPO was unset, so it resolved the REAL repo and pushed a REAL carry to
# origin/bashified. Correct content, from a test run. Now it refuses.
out="$( CARRY_BRANCH=nope bash "$C" --check 2>&1 )"; rc=$?
rc "D2a a lone ref override exits 2 (usage), not 0" 2 "$rc"
case "$out" in *"CARRY_REPO is not"*) ok "D2b it names the missing half" ;;
  *) bad "D2b it names the missing half" "got: $out" ;; esac
for v in CARRY_REMOTE CARRY_REF_MAIN CARRY_REF_BASH; do
  ( env "$v=nope" bash "$C" --check >/dev/null 2>&1 ); r=$?
  [ "$r" = 2 ] && ok "D2c $v alone is refused too" \
    || bad "D2c $v alone is refused too" "exit $r, so this half is ungraded"
done

section "D. a row whose source is gone is a finding, and carries nothing"
( cd "$T" && git checkout -q main \
  && printf '# table\nCARRIED.md\tSOURCE.md\nGONE.md\tNOPE.md\n' > bin/lib/carries.tsv \
  && git add -A && git commit -qm main3 && git push -q origin main && git fetch -q origin ) >/dev/null 2>&1
before="$( cd "$T" && git rev-parse origin/bashified )"
out="$(run_carry --apply)"; rc=$?
rc "D1 exits 1 (a finding), not 0" 1 "$rc"
case "$out" in *"NOPE.md"*) ok "D2 it names the row whose source is gone" ;;
  *) bad "D2 it names the row whose source is gone" "got: $out" ;; esac
( cd "$T" && git fetch -q origin ) >/dev/null 2>&1
eq "D3 and it carried NOTHING while refusing" "$before" "$( cd "$T" && git rev-parse origin/bashified )"

summary
