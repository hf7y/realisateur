#!/usr/bin/env bash
# HERMETICITY: builds its own scheduler registry and sets SCHED_ROOT, FOCUS_MD,
# BLOCKERS_MD and TODAY on every invocation, so it reads a fixture and never the
# live estate.
#
# WAS RED WHEN CI FIRST RAN IT (46/3, run 31217552355); CLOSED 2026-08-07, and
# there were TWO stale fixtures, not one. 957b8b8 (#65) gave closeout-lint.sh
# both an `on_a_remote` stale-pointer exemption and an `other-worktree` skip,
# and this suite was last touched before it. (a) `detached`'s `orphan` branch
# sat at main's tip, so its tip WAS reachable from a remote and the downgrade to
# `note [stale-pointer]` was correct -- A4 asked for a state the fixture stopped
# building. (b) E3's only host-only branch in `oldrepo` was `oldside`, which A9
# puts in a linked worktree, so the new skip correctly declined to examine it.
# The script was right both times. Fixed by giving `orphan` a commit on no
# remote and `oldrepo` a plain host-only branch. No assertion text changed.
#
# closeout-lint.test.sh -- witness for bin/closeout-lint.sh. Offline, zero AI,
# no network: builds a throwaway scheduler registry (schedule/*.conf), real
# bare remotes + clones, and a scratch FOCUS.md/BLOCKERS.md, then drives every
# check in both directions -- it must FLAG the bad state AND stay quiet on the
# good one (the crt/wtul verification bar).
#
# Cases:
#   A1 clean, pushed repo             -> no flag
#   A2 dirty working tree             -> FLAG [dirty-tree]
#   A3 commit ahead of upstream       -> FLAG [unpushed]
#   A4 branch with no origin/<branch> -> FLAG [host-only-branch]
#   A5 HEAD older than HOURS          -> not scanned at all (no flag, not listed)
#   A6 registered path does not exist -> FLAG [missing-repo]
#   B1 today's entry citing a sha     -> ok
#   B2 today's entry, no sha          -> FLAG [record-no-sha]
#   B3 no entry dated today           -> FLAG [no-record]
#   B4 FOCUS.md missing               -> FLAG [no-focus]
#   C1 BLOCKERS.md dated today        -> ok, no flag
#   C2 BLOCKERS.md with nothing today -> NOTE only, still no flag
#   D1 --strict, a FLAG is printed    -> exit 1
#   D2 --strict, nothing FLAGged      -> exit 0
#   D3 no --strict, a FLAG is printed -> exit 0 (bare invocation stays green)
#   E1 --repo on an UNREGISTERED tree -> audited anyway (registry bypassed)
#   E2 --repo                         -> sections B and C skipped
#   E3 --repo on a stale-HEAD repo    -> age gate ignored, branches checked
#   E4 --strict, BLIND and no FLAG    -> exit 6
#   E5 --strict --allow-blind, BLIND  -> exit 0 (warning, not a gate)
#   E6 --strict, a FLAG and no BLIND  -> exit 1 (FLAG outranks BLIND)
#   E7..E9 --repo misuse              -> exit 2
#   E10 --repo <subdir>               -> resolves to the work-tree root
#
# Negative-tested against an `exit 0` stub: 31 of the 49 assertions fail as
# they should. The 18 that survive are all `hasnt` (absence) or expect-exit-0
# assertions, which a silent stub passes vacuously -- so every one of those is
# deliberately paired with a positive assertion on the same fixture (A1, A5,
# C2, E1, E2), and no case rests on absence alone.
#
# Mutation-verified beyond that, each against the assertion that should catch
# it: remove the BLIND gate -> E4; ignore --allow-blind -> E5; restore the age
# gate in --repo mode -> E3; stop skipping B/C -> E2; remove the
# host-only-branch check -> A4; reword the unpushed count -> A3; remove BLIND
# worktree detection -> A8 and A9.
#
# Usage: bin/tests/closeout-lint.test.sh   (exit 0 = all pass)
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/closeout-lint.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
DAY="2026-07-26"

ok()   { echo "  ok   $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL $1"; fail=$((fail+1)); }
# has <name> <output> <pattern>   -- output must contain pattern
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing: $3)" ;; esac; }
# hasnt <name> <output> <pattern> -- output must NOT contain pattern
hasnt(){ case "$2" in *"$3"*) bad "$1 (unexpected: $3)" ;; *) ok "$1" ;; esac; }
# rc <name> <expected-exit> <actual-exit>
rc()   { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected exit $2, got $3)"; fi; }

mkdir -p "$T/sched/schedule"
reg() { # reg <name> <path>
  printf 'PROJECT_REPO_PATH="%s"\n' "$2" > "$T/sched/schedule/$1.conf"
}
# newrepo <name> -> a clone at $T/<name> with a bare upstream, one pushed commit
newrepo() {
  git init -q --bare "$T/$1.git"
  git clone -q "$T/$1.git" "$T/$1" 2>/dev/null
  git -C "$T/$1" config user.email t@test; git -C "$T/$1" config user.name T
  git -C "$T/$1" checkout -q -B main
  echo one > "$T/$1/f.txt"; git -C "$T/$1" add -A
  git -C "$T/$1" commit -qm init; git -C "$T/$1" push -q origin main
  git -C "$T/$1" branch -q --set-upstream-to=origin/main
  reg "$1" "$T/$1"
}

# --- fixtures --------------------------------------------------------------
newrepo clean
# strictclean: a SEPARATE pushed, untouched repo for the D-section --strict
# clean-exit case. A9 still adds a worktree on a host-only branch to
# "oldrepo" in place (correct for that case), and the general hazard is that
# any fixture mutated mid-file is no longer the thing a later case names. A
# dedicated repo per assertion is cheap; a shared one silently drifts.
# (A8 used to mutate "clean" the same way, which is what made A8 and C2 fail
# once the host-only-branch check landed -- it now uses its own "wtrepo".)
newrepo strictclean
newrepo dirtyrepo && echo scratch >> "$T/dirtyrepo/f.txt"
newrepo aheadrepo && { echo two > "$T/aheadrepo/g.txt"; git -C "$T/aheadrepo" add -A; \
                       git -C "$T/aheadrepo" commit -qm ahead; }
# `orphan` MUST CARRY A COMMIT THAT IS ON NO REMOTE. Branching it at main's
# tip -- which is what this fixture did until 2026-08-07 -- no longer builds a
# host-only branch: 957b8b8 gave closeout-lint.sh an `on_a_remote` exemption
# that correctly downgrades a branch whose tip is already reachable from a
# remote ref to `note [stale-pointer]`, since there is nothing unpushed about
# it. The script was right and the fixture had gone stale, so A4 failed
# describing a state the fixture no longer produced.
newrepo detached && git -C "$T/detached" checkout -q -B orphan
echo host-only > "$T/detached/only-here.txt"; git -C "$T/detached" add -A
git -C "$T/detached" commit -qm 'exists on no remote'
newrepo oldrepo
GIT_COMMITTER_DATE="2026-07-01T00:00:00" GIT_AUTHOR_DATE="2026-07-01T00:00:00" \
  git -C "$T/oldrepo" commit -q --amend --no-edit --date="2026-07-01T00:00:00" >/dev/null
reg ghostrepo "$T/does-not-exist"

printf '**%s (test): did a thing** in commit `abc1234`.\n\n---\n' "$DAY" > "$T/focus-ok.md"
printf '**%s (test): did a thing** with no sha at all.\n\n---\n' "$DAY" > "$T/focus-nosha.md"
printf '**2026-07-01 (test): old entry** `abc1234`.\n\n---\n' > "$T/focus-old.md"
printf '## wtul\n- something dated %s\n' "$DAY" > "$T/blockers-today.md"
printf '## wtul\n- something dated 2026-07-01\n' > "$T/blockers-old.md"

run() { # run <FOCUS_MD> <BLOCKERS_MD> [projects...]
  local f="$1" b="$2"; shift 2
  TODAY="$DAY" SCHED_ROOT="$T/sched" FOCUS_MD="$f" BLOCKERS_MD="$b" HOURS=12 \
    "$SCRIPT" "$@" 2>&1
}
# run_rc <FOCUS_MD> <BLOCKERS_MD> [args...] -- same, but sets RUN_OUT/RUN_RC
# instead of only printing output, so a case can assert the exit code too.
run_rc() {
  local f="$1" b="$2"; shift 2
  RUN_OUT="$(TODAY="$DAY" SCHED_ROOT="$T/sched" FOCUS_MD="$f" BLOCKERS_MD="$b" HOURS=12 \
    "$SCRIPT" "$@" 2>&1)"
  RUN_RC=$?
}

echo "closeout-lint.test.sh"
echo "-- A. recently touched repos"
out="$(run "$T/focus-ok.md" "$T/blockers-today.md" clean)"
hasnt "A1 clean repo raises no flag"           "$out" "FLAG ["
has   "A1 clean repo counted as touched"       "$out" "0 FLAG(s) across 1"

out="$(run "$T/focus-ok.md" "$T/blockers-today.md" dirtyrepo)"
has   "A2 dirty tree flagged"                  "$out" "FLAG [dirty-tree] dirtyrepo"

out="$(run "$T/focus-ok.md" "$T/blockers-today.md" aheadrepo)"
has   "A3 unpushed commit flagged"             "$out" "FLAG [unpushed] aheadrepo"
has   "A3 names the count"                     "$out" "1 commit(s) on main not on origin/main"

# A4 was written against a [no-upstream] check that the host-only-branch
# doctrine (2026-08-01, BUILD-DISCIPLINE.md "Settled definition: pushed")
# replaced. A branch with no origin/<branch> is not merely untracked -- it
# exists ONLY on this host, which is a blocker, and `fauche`/`transplante`
# refuse on it. The fixture's `orphan` branch is exactly that case.
out="$(run "$T/focus-ok.md" "$T/blockers-today.md" detached)"
has   "A4 host-only branch flagged"            "$out" "FLAG [host-only-branch] detached"
has   "A4 names the branch it would strand"    "$out" "branch 'orphan' has no origin/orphan"

out="$(run "$T/focus-ok.md" "$T/blockers-today.md" oldrepo)"
hasnt "A5 stale repo not flagged"              "$out" "FLAG ["
has   "A5 stale repo not even scanned"         "$out" "no registered repo has a commit younger"

out="$(run "$T/focus-ok.md" "$T/blockers-today.md" ghostrepo)"
has   "A6 missing repo path flagged"           "$out" "FLAG [missing-repo] ghostrepo"

# A7/A8: linked worktrees are a domain section A does not read. It must say
# so (BLIND) rather than stay quiet -- and it must say so even when the
# registered repo's own HEAD is too old to be scanned, since that gate is
# precisely what hid two unpushed commits on 2026-07-28.
hasnt "A7 no worktrees means no BLIND line"    "$out" "BLIND [worktrees]"
out="$(run "$T/focus-ok.md" "$T/blockers-today.md" clean)"
hasnt "A7 clean repo likewise silent"          "$out" "BLIND [worktrees]"

# A8 gets its OWN repo, and its branch is PUSHED WITHOUT an upstream being
# configured. Both halves matter:
#   - `git worktree add -b side` on `clean` created a branch with no
#     origin/side, so the (correct) host-only-branch FLAG fired and broke
#     A8's "a BLIND raises no FLAG" assertion -- and, because `clean` stayed
#     contaminated, C2's as well. Isolating the fixture fixes both.
#   - `git push origin side` WITHOUT --set-upstream is the case
#     BUILD-DISCIPLINE.md's settled definition calls out by name: `@{u}` is
#     the WRONG question, and asking it over-reported by two on the first
#     propagation pass. A8 therefore doubles as the regression test for it.
newrepo wtrepo
git -C "$T/wtrepo" branch -q side && git -C "$T/wtrepo" push -q origin side
git -C "$T/wtrepo" worktree add -q "$T/wtrepo-side" side >/dev/null 2>&1
out="$(run "$T/focus-ok.md" "$T/blockers-today.md" wtrepo)"
# A8 REVERSED 2026-08-07, and the old assertion was itself a false alarm.
#
# This case used to assert `BLIND [worktrees] wtrepo: 1 linked worktree(s)` --
# the 2026-07-28 decision (option b) to emit "did not look" rather than grow
# section A to read them. The measurement that overturned it: on the real
# realisateur checkout the same rule printed ONE BLIND line covering 13 linked
# worktrees, sitting ABOVE twelve loud FLAG lines that were all false. A guard
# for stranded work was noisy about 12 resolved things and quiet about 13
# places it had not looked -- and agents in this estate work almost
# exclusively IN worktrees, so the unread domain is where the stranded work
# disproportionately IS.
#
# Probing all 13 for real: every one clean, none ahead. So the BLIND was not
# protecting anything -- reading them costs ZERO new FLAGs and removes 13
# unread domains. wtrepo here is the same shape: clean, and `side` is pushed.
# There was never anything to be blind about, and saying BLIND about a domain
# you could have read in 3ms is the "found nothing / did not look" conflation
# pointed the other way.
#
# The old wording also violated what Zach restated today -- "if your answer
# includes 'and then the human runs X', it is not finished". Its remedy line
# was literally "run closeout-lint against them by hand".
hasnt "A8 a readable worktree is READ, not declared BLIND" "$out" "BLIND [worktrees]"
has   "A8 and it is named, so it is visibly examined"      "$out" "[side]"
hasnt "A8 a clean, pushed worktree raises no FLAG"         "$out" "FLAG ["
hasnt "A8 pushed-but-no-upstream not host-only" "$out" "FLAG [host-only-branch]"

git -C "$T/oldrepo" worktree add -q -b oldside "$T/oldrepo-side" >/dev/null 2>&1
out="$(run "$T/focus-ok.md" "$T/blockers-today.md" oldrepo)"
# A9's PROPERTY IS UNCHANGED; only the verb is. Worktrees are examined BEFORE
# the age gate, so a registered repo whose own HEAD is too old to scan does not
# hide the worktrees hanging off it -- that gate is precisely what hid two
# unpushed commits on 2026-07-28. What changed on 2026-08-07 is that the
# worktree is now READ rather than declared unread, so the surviving evidence
# is a `read [worktree]` line instead of a `BLIND [worktrees]` one.
has   "A9 worktrees survive the stale-HEAD gate" "$out" "read [worktree] oldrepo"
has   "A9 and the worktree branch is named"      "$out" "[oldside]"
has   "A9 stale repo still not scanned"        "$out" "no registered repo has a commit younger"

echo "-- B. today's session record"
out="$(run "$T/focus-ok.md" "$T/blockers-today.md" clean)"
has   "B1 dated entry with a sha passes"       "$out" "ok -- entry dated $DAY cites"

out="$(run "$T/focus-nosha.md" "$T/blockers-today.md" clean)"
has   "B2 entry citing no sha flagged"         "$out" "FLAG [record-no-sha]"

out="$(run "$T/focus-old.md" "$T/blockers-today.md" clean)"
has   "B3 no entry dated today flagged"        "$out" "FLAG [no-record]"

out="$(run "$T/nope.md" "$T/blockers-today.md" clean)"
has   "B4 absent FOCUS.md flagged"             "$out" "FLAG [no-focus]"

echo "-- C. decision residue (never flags, by design)"
out="$(run "$T/focus-ok.md" "$T/blockers-today.md" clean)"
has   "C1 today-dated BLOCKERS block passes"   "$out" "ok -- BLOCKERS.md carries"

out="$(run "$T/focus-ok.md" "$T/blockers-old.md" clean)"
has   "C2 stale BLOCKERS reported as NOTE"     "$out" "NOTE BLOCKERS.md has nothing dated"
hasnt "C2 and NOT as a flag"                   "$out" "FLAG ["

echo "-- D. --strict exit code (exit-code plumbing, not a new FLAG type)"
run_rc "$T/focus-ok.md" "$T/blockers-today.md" --strict dirtyrepo
rc    "D1 --strict exits nonzero when a FLAG was printed" 1 "$RUN_RC"
has   "D1 output still shows the FLAG"                    "$RUN_OUT" "FLAG [dirty-tree]"

run_rc "$T/focus-ok.md" "$T/blockers-today.md" --strict strictclean
rc    "D2 --strict exits 0 on an all-clean scan"          0 "$RUN_RC"
hasnt "D2 no FLAG in a clean --strict run"                "$RUN_OUT" "FLAG ["

run_rc "$T/focus-ok.md" "$T/blockers-today.md" dirtyrepo
rc    "D3 bare invocation stays exit 0 despite a FLAG"    0 "$RUN_RC"
has   "D3 the FLAG is still printed (signal, not silence)" "$RUN_OUT" "FLAG [dirty-tree]"

echo "-- E. --repo (one tree) and the BLIND gate"
# An UNREGISTERED repo: nothing in the scratch registry names it. Registry
# mode cannot reach it at all, so this proves --repo bypasses discovery
# rather than merely filtering it.
git init -q --bare "$T/loose.git"
git clone -q "$T/loose.git" "$T/loose" 2>/dev/null
git -C "$T/loose" config user.email t@test; git -C "$T/loose" config user.name T
git -C "$T/loose" checkout -q -B main
echo one > "$T/loose/f.txt"; git -C "$T/loose" add -A
git -C "$T/loose" commit -qm init; git -C "$T/loose" push -q origin main
git -C "$T/loose" branch -q --set-upstream-to=origin/main

run_rc "$T/focus-ok.md" "$T/blockers-today.md" --repo "$T/loose"
rc    "E1 --repo audits an UNREGISTERED tree"             0 "$RUN_RC"
has   "E1 names the tree it audited"                      "$RUN_OUT" "single tree: $T/loose"
hasnt "E1 registry mode could never have reached it"      "$RUN_OUT" "recently-touched repo(s)"

# Sections B and C are session-wide. A hook auditing one worktree must not be
# blocked by realisateur's FOCUS.md lacking today's entry, so --repo skips
# them -- note this uses focus-OLD, which would FLAG [no-record] in registry mode.
run_rc "$T/focus-old.md" "$T/blockers-old.md" --repo "$T/loose"
hasnt "E2 --repo skips section B"                         "$RUN_OUT" "B. TODAY'S SESSION RECORD"
hasnt "E2 --repo skips section C"                         "$RUN_OUT" "C. DECISION RESIDUE"
rc    "E2 so a stale FOCUS.md cannot gate one tree"       0 "$RUN_RC"

# The age gate answers "did this session touch it", which is the wrong
# question when the caller named the tree. oldrepo's HEAD is 2026-07-01 and
# HOURS=12, so registry mode never scans it; --repo must.
#
# The host-only branch E3 names has to be one closeout-lint will actually
# examine. `oldside` is not: A9 above puts it in a LINKED WORKTREE, and
# 957b8b8 made the branch audit `skip [other-worktree]` those -- correctly,
# they are not this run's to push. So from 957b8b8 onward oldrepo's only
# examined branch was `main`, which has an origin/main and reports
# [unpushed], and E3 failed asking for a string the fixture no longer
# produced. A plain branch at oldrepo's amended HEAD (not on any remote, not
# checked out anywhere) is the state E3 has always been about.
git -C "$T/oldrepo" branch -q oldhostonly
out="$(run "$T/focus-ok.md" "$T/blockers-today.md" oldrepo)"
has   "E3 registry mode skips a stale repo"    "$out" "no registered repo has a commit younger"
run_rc "$T/focus-ok.md" "$T/blockers-today.md" --repo "$T/oldrepo"
hasnt "E3 --repo ignores the age gate"                    "$RUN_OUT" "no registered repo has a commit younger"
has   "E3 and actually checks its branches"               "$RUN_OUT" "FLAG [host-only-branch]"

# The BLIND gate itself. It still exists and still exits 6 -- what changed on
# 2026-08-07 is what EARNS a BLIND. A worktree that can be read is read; a
# worktree that CANNOT is the genuine "a domain existed and was not read", and
# that is what this fixture now builds: a registered worktree whose directory
# has been removed underneath git, so `git worktree list` still names it and
# nothing can be learned about it.
newrepo blindrepo
git -C "$T/blindrepo" branch -q ghostside
git -C "$T/blindrepo" worktree add -q "$T/blindrepo-gone" ghostside >/dev/null 2>&1
rm -rf "$T/blindrepo-gone"
run_rc "$T/focus-ok.md" "$T/blockers-today.md" --strict --repo "$T/blindrepo"
rc    "E4 an UNREADABLE worktree is BLIND and exits 6"    6 "$RUN_RC"
hasnt "E4 and it really was BLIND-not-FLAG"               "$RUN_OUT" "FLAG ["
has   "E4 names the unreadable worktree"                  "$RUN_OUT" "BLIND [worktree]"

run_rc "$T/focus-ok.md" "$T/blockers-today.md" --strict --allow-blind --repo "$T/blindrepo"
rc    "E5 --allow-blind downgrades BLIND to a warning"    0 "$RUN_RC"

# A FLAG is something we DID see; BLIND is something we could not. dirtyrepo
# has no worktree, so this also pins that a plain FLAG still exits 1 and not 6.
run_rc "$T/focus-ok.md" "$T/blockers-today.md" --strict --repo "$T/dirtyrepo"
rc    "E6 a FLAG still exits 1, not 6"                    1 "$RUN_RC"

# Usage errors. Two selectors that disagree is a usage error, not something
# to resolve by precedence and silently honour one of.
run_rc "$T/focus-ok.md" "$T/blockers-today.md" --repo "$T/loose" clean
rc    "E7 --repo plus a project name is rejected"         2 "$RUN_RC"
run_rc "$T/focus-ok.md" "$T/blockers-today.md" --repo "$T/sched"
rc    "E8 --repo on a non-git directory is rejected"      2 "$RUN_RC"
run_rc "$T/focus-ok.md" "$T/blockers-today.md" --repo
rc    "E9 --repo with no path is rejected"                2 "$RUN_RC"

# A subdirectory argument must still name the repo, or a hook whose cwd is
# nested would audit nothing and report clean.
run_rc "$T/focus-ok.md" "$T/blockers-today.md" --repo "$T/loose/.git/.."
has   "E10 --repo resolves to the work-tree root"         "$RUN_OUT" "single tree: $T/loose"

echo
echo "-- F. squash-merged branches (the 12-out-of-12 false alarm)"
# WHAT THIS SECTION IS FOR, with the numbers that produced it.
#
# On 2026-08-07 closeout-lint reported 12 [host-only-branch] FLAGs against the
# realisateur checkout -- "unmerged work at risk" -- and ALL TWELVE were PRs
# that had been squash-merged and had their upstream branch deleted weeks or
# hours earlier. Zero true positives. A guard that is wrong twelve times out of
# twelve trains its reader to skip the section, and then a real one is skipped
# too; that is exactly how three red suites sat on main long enough to become
# furniture.
#
# The cause is that squash-merge REWRITES. GitHub lands one new commit with the
# branch's content and a different sha, so `on_a_remote`'s question -- "is this
# exact commit reachable from a remote ref?" -- is legitimately answered no for
# work that landed. The question cannot be answered correctly under squash.
#
# The question that CAN be is "is this branch's content already on the default
# branch?", and it is answerable offline with a patch-id compare against a
# reconstructed squash commit. F1 pins that; F2 is the teeth.
newrepo squashed
git -C "$T/squashed" checkout -q -b feature
echo alpha > "$T/squashed/a.txt"; git -C "$T/squashed" add -A
git -C "$T/squashed" commit -qm 'first half'
echo beta > "$T/squashed/b.txt"; git -C "$T/squashed" add -A
git -C "$T/squashed" commit -qm 'second half'
git -C "$T/squashed" push -q origin feature
# ...and now GitHub's squash-merge, reproduced exactly: one new commit on main
# carrying the branch's content, then the upstream branch deleted. The local
# `feature` ref survives, pointing at the ORIGINAL two commits, which is the
# state every one of the 12 was in.
git -C "$T/squashed" checkout -q main
git -C "$T/squashed" merge -q --squash feature
git -C "$T/squashed" commit -qm 'feature (#1)'
git -C "$T/squashed" push -q origin main
git -C "$T/squashed" push -q origin --delete feature
git -C "$T/squashed" fetch -q --prune origin

# A branch REALLY unmerged, in the same repo, so F2 cannot pass by the fix
# simply exempting everything. This is the assertion that keeps the teeth.
git -C "$T/squashed" checkout -q -b lost main
echo gamma > "$T/squashed/c.txt"; git -C "$T/squashed" add -A
git -C "$T/squashed" commit -qm 'on no remote, in no squash'
git -C "$T/squashed" checkout -q main

out="$(run "$T/focus-ok.md" "$T/blockers-today.md" squashed)"
hasnt "F1 squash-merged branch is NOT flagged as host-only" "$out" "FLAG [host-only-branch] squashed: branch 'feature'"
has   "F1 it is reported as landed, not as lost"            "$out" "note [landed] squashed: 'feature'"
has   "F2 a genuinely unmerged branch STILL flags"          "$out" "FLAG [host-only-branch] squashed: branch 'lost'"

# F3: the downgrade must not need the network. Every case in this file runs
# with no remote but a file:// bare and no `gh` on the fixture's behalf, so F1
# passing at all is the offline proof -- but pin it explicitly, because a guard
# that hard-requires a network is its own failure mode (it goes BLIND on a
# plane and FLAGs everything, which is the same noise by another route).
out="$(PATH="/nonexistent-bin:$PATH" run "$T/focus-ok.md" "$T/blockers-today.md" squashed)"
hasnt "F3 offline (no gh on PATH) still declines to flag"   "$out" "FLAG [host-only-branch] squashed: branch 'feature'"
has   "F3 and still flags the genuinely unmerged one"       "$out" "FLAG [host-only-branch] squashed: branch 'lost'"

# F4: no git identity configured must not break the probe. Reconstructing a
# squash commit needs an author, and a fresh container or a CI runner has no
# global one -- the exact "empty ident name" failure the workflow sets an
# identity to avoid. The script must supply its own rather than inherit.
out="$(HOME="$T/no-identity" GIT_CONFIG_GLOBAL=/dev/null \
       run "$T/focus-ok.md" "$T/blockers-today.md" squashed)"
hasnt "F4 no git identity -> probe still works"             "$out" "FLAG [host-only-branch] squashed: branch 'feature'"

echo
echo "-- G. linked worktrees are READ, not declared unread"
# THE MEASUREMENT THAT PRODUCED THIS SECTION. On the realisateur checkout,
# closeout-lint printed one `BLIND [worktrees] ... 13 linked worktree(s) NOT
# examined` line ABOVE twelve FLAG lines, all twelve false (section F). A guard
# whose whole purpose is catching stranded work was loud about 12 resolved
# things and quiet about 13 places it had not looked -- and every agent in this
# estate works IN a worktree, so the unread domain is exactly where stranded
# work lives. Signal-to-noise, precisely inverted.
#
# Probing all 13 for real: all clean, none ahead. Reading them costs zero new
# FLAGs. So the blindness was never protecting anyone from noise; it was just
# not looking, and telling the human to look by hand.
#
# G1 is the load-bearing case: an unpushed COMMIT inside a linked worktree is
# now FOUND. That is the state the old code could not represent at all.

# G1: committed work inside a linked worktree, not on its upstream -> FLAG.
newrepo wt_unpushed
git -C "$T/wt_unpushed" branch -q feat
git -C "$T/wt_unpushed" push -q origin feat
git -C "$T/wt_unpushed" worktree add -q "$T/wt_unpushed-side" feat >/dev/null 2>&1
echo stranded > "$T/wt_unpushed-side/s.txt"
git -C "$T/wt_unpushed-side" add -A
git -C "$T/wt_unpushed-side" commit -qm 'committed here and never pushed'
out="$(run "$T/focus-ok.md" "$T/blockers-today.md" wt_unpushed)"
has   "G1 unpushed commit IN a worktree is FLAGged"  "$out" "FLAG [worktree-unpushed]"
has   "G1 and it names the worktree branch"          "$out" "feat"
hasnt "G1 and it is no longer merely BLIND"          "$out" "BLIND [worktrees]"
# G5: the branch audit skips a branch that is checked out in a linked
# worktree -- still correct, it is not this run's to push. But its message
# said "(BLIND above -- not this run's to push)", pointing the reader at a
# BLIND line that this branch just deleted. A dangling cross-reference to a
# removed symbol is how prose decays into a lie one commit at a time, and the
# reader it misleads is the one who went looking for the BLIND and found
# nothing. The worktree is now READ, so the line must say so.
has   "G5 a worktree-checked-out branch is still skipped" "$out" "skip [other-worktree]"
hasnt "G5 and the skip cites no BLIND that no longer exists" "$out" "BLIND above"

# G2: a DIRTY worktree is reported but does NOT gate. A concurrent agent's
# worktree is dirty by construction while it is running, and gating on that
# would make this guard red during every parallel session -- which is the
# noise-becomes-furniture failure section F exists to undo. It must be
# impossible to overlook and wrong to act on automatically: a note, never
# silence.
newrepo wt_dirty
git -C "$T/wt_dirty" branch -q scratch
git -C "$T/wt_dirty" push -q origin scratch
git -C "$T/wt_dirty" worktree add -q "$T/wt_dirty-side" scratch >/dev/null 2>&1
echo mid-run >> "$T/wt_dirty-side/f.txt"
run_rc "$T/focus-ok.md" "$T/blockers-today.md" --strict --repo "$T/wt_dirty"
has   "G2 a dirty worktree is reported"              "$RUN_OUT" "note [worktree-dirty]"
hasnt "G2 but it is not a FLAG"                      "$RUN_OUT" "FLAG [worktree"
rc    "G2 and it does not gate a concurrent run"     0 "$RUN_RC"

# G3: an UNREADABLE worktree is still BLIND. Removing the audit's ability to
# say "I could not look" would trade one conflation for another.
run_rc "$T/focus-ok.md" "$T/blockers-today.md" --repo "$T/blindrepo"
has   "G3 unreadable worktree still says BLIND"      "$RUN_OUT" "BLIND [worktree]"

# G4: BLIND LEADS THE SUMMARY. The original defect was not only that 13
# worktrees went unread -- it was that the one line saying so was buried above
# twelve louder FLAG lines and got skipped. An admission of not having looked
# must be the first thing the summary says, not a trailing clause.
run_rc "$T/focus-ok.md" "$T/blockers-today.md" --repo "$T/blindrepo"
case "$RUN_OUT" in
  *"BLIND: "*"domain(s) existed and were NOT read"*) ok "G4 summary leads with BLIND" ;;
  *) bad "G4 summary leads with BLIND (no leading BLIND banner in summary)" ;;
esac

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
