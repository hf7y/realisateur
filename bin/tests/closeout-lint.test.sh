#!/usr/bin/env bash
# HERMETICITY: builds its own scheduler registry and sets SCHED_ROOT,
# BLOCKERS_MD, TODAY, SESSION_START and GH_BIN every invocation, so it reads a
# fixture and never the live estate -- and $GH_BIN is always a stub in $T, so
# B's query resolves no hostname here.
#
# closeout-lint.test.sh -- witness for bin/closeout-lint.sh. Offline, zero AI:
# a throwaway registry (schedule/*.conf), real bare remotes and clones, a
# scratch BLOCKERS.md and stub `gh` binaries, driving every check in BOTH
# directions -- it must FLAG the bad state AND stay quiet on the good one. The
# case roster is the banners and assertion names below, which print on every
# run; a hand-maintained list restating them is the duplication tests.yml's
# per-suite ledger was deleted for, and had gone stale describing #139's check.
#
# A STALE FIXTURE READS AS A BROKEN SCRIPT: this suite was red on its first CI
# run (46/3, 2026-08-07) and the script was right both times -- two fixtures
# had stopped building the states A4 and E3 name. Fixed by changing FIXTURES,
# never an assertion. No case rests on absence alone either: every `hasnt` is
# paired with a positive assertion on the same fixture.
#
# Mutation-verified, each against the assertion that catches it: remove the
# BLIND gate -> E4; ignore --allow-blind -> E5; restore the age gate under
# --repo -> E3; stop skipping B/C -> E2; remove host-only-branch -> A4; reword
# the unpushed count -> A3; remove worktree detection -> A8/A9; exempt dirt
# unconditionally -> H2; call an unknown session start clean -> H3; FLAG only
# the current worktree's branches -> I4; let B FLAG unreached -> B3/B4/B7; drop the
# worktree-dirty mtime split -> G2b/G2c.
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
# newrepo <name> [<bare-root>] -> a clone at $T/<name>, bare upstream, one
# pushed commit. THE BARE ROOT CONTAINS github.com BY DEFAULT: B reads a slug
# off origin and calls a non-GitHub origin unaskable, so a bare at $T/<name>.git
# would send every registry case BLIND for a reason unrelated to what it asserts
# -- D2 included, which would exit 6. B7 passes one that does not, on purpose.
newrepo() {
  local root="${2:-$T/remotes/github.com/hf7y}"
  mkdir -p "$root"
  git init -q --bare "$root/$1.git"
  git clone -q "$root/$1.git" "$T/$1" 2>/dev/null
  git -C "$T/$1" config user.email t@test; git -C "$T/$1" config user.name T
  git -C "$T/$1" checkout -q -B main
  echo one > "$T/$1/f.txt"; git -C "$T/$1" add -A
  git -C "$T/$1" commit -qm init; git -C "$T/$1" push -q origin main
  git -C "$T/$1" branch -q --set-upstream-to=origin/main
  reg "$1" "$T/$1"
}

# --- fixtures --------------------------------------------------------------
newrepo clean
# strictclean: a SEPARATE pushed, untouched repo for D2's clean --strict exit. A
# fixture mutated mid-file stops being the thing a later case names -- A8 used to
# mutate "clean" and broke both A8 and C2 when host-only-branch landed.
newrepo strictclean
newrepo dirtyrepo && echo scratch >> "$T/dirtyrepo/f.txt"
newrepo aheadrepo && { echo two > "$T/aheadrepo/g.txt"; git -C "$T/aheadrepo" add -A; \
                       git -C "$T/aheadrepo" commit -qm ahead; }
# `orphan` MUST CARRY A COMMIT THAT IS ON NO REMOTE: branching it at main's tip
# stopped building a host-only branch once #65's `on_a_remote` exemption landed.
newrepo detached && git -C "$T/detached" checkout -q -B orphan
echo host-only > "$T/detached/only-here.txt"; git -C "$T/detached" add -A
git -C "$T/detached" commit -qm 'exists on no remote'
newrepo oldrepo
GIT_COMMITTER_DATE="2026-07-01T00:00:00" GIT_AUTHOR_DATE="2026-07-01T00:00:00" \
  git -C "$T/oldrepo" commit -q --amend --no-edit --date="2026-07-01T00:00:00" >/dev/null
reg ghostrepo "$T/does-not-exist"

printf '## wtul\n- something dated %s\n' "$DAY" > "$T/blockers-today.md"
printf '## wtul\n- something dated 2026-07-01\n' > "$T/blockers-old.md"

# --- gh stubs: section B asks a REMOTE, and this suite never does -----------
# B's query is `gh api ... --jq '<fmt>'`, so the script reads only gh's post-jq
# stdout and its exit status -- a stub printing the formatted line is the whole
# contract. $GH_BIN defaults to FOUND, so non-B cases cannot be perturbed.
mkdir -p "$T/gh-found" "$T/gh-empty" "$T/gh-down"
printf '#!/bin/sh\necho "hf7y/stub#42 a record this session left on the remote"\n' > "$T/gh-found/gh"
printf '#!/bin/sh\nexit 0\n' > "$T/gh-empty/gh"
printf '#!/bin/sh\necho "gh: could not resolve host github.com" >&2\nexit 1\n' > "$T/gh-down/gh"
chmod +x "$T/gh-found/gh" "$T/gh-empty/gh" "$T/gh-down/gh"
GH_DEFAULT="$T/gh-found/gh"

run() { # run <BLOCKERS_MD> [projects...]   ($GH_BIN/$SESSION_START overridable)
  local b="$1"; shift
  TODAY="$DAY" SCHED_ROOT="$T/sched" BLOCKERS_MD="$b" HOURS=12 \
    GH_BIN="${GH_BIN:-$GH_DEFAULT}" SESSION_START="${SESSION_START:-}" \
    "$SCRIPT" "$@" 2>&1
}
# run_rc <BLOCKERS_MD> [args...] -- same, but sets RUN_OUT/RUN_RC instead of
# only printing output, so a case can assert the exit code too.
run_rc() {
  local b="$1"; shift
  RUN_OUT="$(TODAY="$DAY" SCHED_ROOT="$T/sched" BLOCKERS_MD="$b" HOURS=12 \
    GH_BIN="${GH_BIN:-$GH_DEFAULT}" SESSION_START="${SESSION_START:-}" \
    "$SCRIPT" "$@" 2>&1)"
  RUN_RC=$?
}
# count <name> <output> <pattern> <expected> -- pattern must appear N times
count() {
  local n; n="$(printf '%s\n' "$2" | grep -cF -- "$3")"
  if [ "$n" = "$4" ]; then ok "$1"; else bad "$1 (expected $4 occurrence(s) of '$3', got $n)"; fi
}

echo "closeout-lint.test.sh"
echo "-- A. recently touched repos"
out="$(run "$T/blockers-today.md" clean)"
hasnt "A1 clean repo raises no flag"           "$out" "FLAG ["
has   "A1 clean repo counted as touched"       "$out" "0 FLAG(s) across 1"

out="$(run "$T/blockers-today.md" dirtyrepo)"
has   "A2 dirty tree flagged"                  "$out" "FLAG [dirty-tree] dirtyrepo"

out="$(run "$T/blockers-today.md" aheadrepo)"
has   "A3 unpushed commit flagged"             "$out" "FLAG [unpushed] aheadrepo"
has   "A3 names the count"                     "$out" "1 commit(s) on main not on origin/main"

# A4: a branch with no origin/<branch> is not merely untracked -- it exists ONLY
# on this host, a blocker `fauche` and `transplante` refuse a repo for.
out="$(run "$T/blockers-today.md" detached)"
has   "A4 host-only branch flagged"            "$out" "FLAG [host-only-branch] detached"
has   "A4 names the branch it would strand"    "$out" "branch 'orphan' has no origin/orphan"

out="$(run "$T/blockers-today.md" oldrepo)"
hasnt "A5 stale repo not flagged"              "$out" "FLAG ["
has   "A5 stale repo not even scanned"         "$out" "no registered repo has a commit younger"

out="$(run "$T/blockers-today.md" ghostrepo)"
has   "A6 missing repo path flagged"           "$out" "FLAG [missing-repo] ghostrepo"

# A7: a repo with no linked worktree emits no worktree line at all.
hasnt "A7 no worktrees means no BLIND line"    "$out" "BLIND [worktrees]"
out="$(run "$T/blockers-today.md" clean)"
hasnt "A7 clean repo likewise silent"          "$out" "BLIND [worktrees]"

# A8 gets its OWN repo, and its branch is PUSHED WITHOUT --set-upstream: the
# case BUILD-DISCIPLINE.md calls out by name, where `@{u}` is the wrong
# question and over-reported by two on the first propagation pass.
newrepo wtrepo
git -C "$T/wtrepo" branch -q side && git -C "$T/wtrepo" push -q origin side
git -C "$T/wtrepo" worktree add -q "$T/wtrepo-side" side >/dev/null 2>&1
out="$(run "$T/blockers-today.md" wtrepo)"
# A8 REVERSED 2026-08-07: this used to assert `BLIND [worktrees]`. On the real
# checkout that line covered 13 worktrees, above 12 false FLAGs, and all 13 were
# clean -- BLIND about a domain readable in 3ms is the conflation reversed.
hasnt "A8 a readable worktree is READ, not declared BLIND" "$out" "BLIND [worktrees]"
has   "A8 and it is named, so it is visibly examined"      "$out" "[side]"
hasnt "A8 a clean, pushed worktree raises no FLAG"         "$out" "FLAG ["
hasnt "A8 pushed-but-no-upstream not host-only" "$out" "FLAG [host-only-branch]"

git -C "$T/oldrepo" worktree add -q -b oldside "$T/oldrepo-side" >/dev/null 2>&1
out="$(run "$T/blockers-today.md" oldrepo)"
# A9: worktrees are examined BEFORE the age gate, so a repo whose HEAD is too
# old to scan does not hide the worktrees hanging off it -- that gate is
# precisely what hid two unpushed commits on 2026-07-28.
has   "A9 worktrees survive the stale-HEAD gate" "$out" "read [worktree] oldrepo"
has   "A9 and the worktree branch is named"      "$out" "[oldside]"
has   "A9 stale repo still not scanned"        "$out" "no registered repo has a commit younger"

echo "-- B. today's session record (issues/PRs, not a FOCUS.md row)"
# B1..B4 used to drive a FOCUS.md check (a dated entry citing a sha, else
# [no-record]/[record-no-sha]/[no-focus]) that `/cloture` §3, revised
# 2026-08-10, forbids writing -- and `/cloture` is what RUNS closeout-lint, so
# clearing the FLAG meant doing the forbidden thing (#139). Not a test weakened
# to let a change pass: doctrine retired what it measured, and B6 pins the old
# check gone rather than quiet. $GH_BIN is set ON ITS OWN LINE, never as
# `GH_BIN=x run ...`: a bash prefix assignment to a FUNCTION persists.
GH_BIN="$T/gh-found/gh"
run_rc "$T/blockers-today.md" clean
has   "B1 a record on the remote passes"       "$RUN_OUT" "ok -- 1 issue(s)/PR(s) created $DAY"
hasnt "B1 and raises no flag"                  "$RUN_OUT" "FLAG ["
rc    "B1 clean scan still exits 0"            0 "$RUN_RC"

GH_BIN="$T/gh-empty/gh"
out="$(run "$T/blockers-today.md" clean)"
has   "B2 GitHub reached and said nothing today -> FLAG" "$out" "FLAG [no-record]"

# B3/B4 ARE THE POINT OF THE REWRITE. B now depends on a network it may not
# have, and FLAGging because it could not look is #139's false alarm by another
# route: unreachable is a counted BLIND.
GH_BIN="$T/gh-down/gh"
out="$(run "$T/blockers-today.md" clean)"
has   "B3 unreachable GitHub is BLIND"         "$out" "BLIND [session-record]"
hasnt "B3 and never a FLAG"                    "$out" "FLAG ["

GH_BIN="$T/nope/gh"
out="$(run "$T/blockers-today.md" clean)"
has   "B4 no gh on PATH is BLIND"              "$out" "BLIND [session-record]"
hasnt "B4 and never a FLAG"                    "$out" "FLAG ["

# B5: and it must gate as BLIND (6), not as a FLAG (1). A caller that cannot
# tell "you filed nothing" from "I could not ask" will eventually treat both
# as noise.
GH_BIN="$T/gh-down/gh"
run_rc "$T/blockers-today.md" --strict strictclean
rc    "B5 --strict on an unaskable remote exits 6, not 1" 6 "$RUN_RC"

# B6: the retired FOCUS.md check is GONE, not silent. If any of these strings
# came back, a closing session that obeyed /cloture §3 would fail again.
GH_BIN="$T/gh-found/gh"
out="$(run "$T/blockers-today.md" clean)"
for gone in no-focus record-no-sha FOCUS.md; do
  hasnt "B6 the retired FOCUS.md check leaves no '$gone'" "$out" "$gone"
done

# B7: a repo whose origin is not on GitHub cannot be asked at all, which is the
# same unanswered question as being offline -- BLIND, never a FLAG.
newrepo elsewhere "$T/remotes/somewhere-else"
out="$(run "$T/blockers-today.md" elsewhere)"
has   "B7 a non-GitHub origin is reported, not guessed at" "$out" "origin is not a GitHub remote"
has   "B7 and counts as BLIND"                 "$out" "BLIND [session-record]"
hasnt "B7 and never a FLAG"                    "$out" "FLAG ["
GH_BIN="$GH_DEFAULT"

echo "-- C. decision residue (never flags, by design)"
out="$(run "$T/blockers-today.md" clean)"
has   "C1 today-dated BLOCKERS block passes"   "$out" "ok -- BLOCKERS.md carries"

out="$(run "$T/blockers-old.md" clean)"
has   "C2 stale BLOCKERS reported as NOTE"     "$out" "NOTE BLOCKERS.md has nothing dated"
hasnt "C2 and NOT as a flag"                   "$out" "FLAG ["

echo "-- D. --strict exit code (exit-code plumbing, not a new FLAG type)"
run_rc "$T/blockers-today.md" --strict dirtyrepo
rc    "D1 --strict exits nonzero when a FLAG was printed" 1 "$RUN_RC"
has   "D1 output still shows the FLAG"                    "$RUN_OUT" "FLAG [dirty-tree]"

run_rc "$T/blockers-today.md" --strict strictclean
rc    "D2 --strict exits 0 on an all-clean scan"          0 "$RUN_RC"
hasnt "D2 no FLAG in a clean --strict run"                "$RUN_OUT" "FLAG ["

run_rc "$T/blockers-today.md" dirtyrepo
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

run_rc "$T/blockers-today.md" --repo "$T/loose"
rc    "E1 --repo audits an UNREGISTERED tree"             0 "$RUN_RC"
has   "E1 names the tree it audited"                      "$RUN_OUT" "single tree: $T/loose"
hasnt "E1 registry mode could never have reached it"      "$RUN_OUT" "recently-touched repo(s)"

# B and C are session-wide, so --repo skips them -- which since 2026-08-11 also
# keeps the SubagentStop path offline. Hence the OFFLINE stub here: if --repo
# stopped skipping B, this would exit 6, not 0.
GH_BIN="$T/gh-down/gh"
run_rc "$T/blockers-old.md" --repo "$T/loose"
hasnt "E2 --repo skips section B"                         "$RUN_OUT" "B. TODAY'S SESSION RECORD"
hasnt "E2 --repo skips section C"                         "$RUN_OUT" "C. DECISION RESIDUE"
rc    "E2 so a session-wide question cannot gate one tree" 0 "$RUN_RC"
GH_BIN="$GH_DEFAULT"

# The age gate asks "did this session touch it", the wrong question when the
# caller named the tree: oldrepo's HEAD is 2026-07-01, so registry mode never
# scans it and --repo must. E3's branch must be one the audit examines, and
# `oldside` is in a worktree and correctly skipped -- so, a plain one.
git -C "$T/oldrepo" branch -q oldhostonly
out="$(run "$T/blockers-today.md" oldrepo)"
has   "E3 registry mode skips a stale repo"    "$out" "no registered repo has a commit younger"
run_rc "$T/blockers-today.md" --repo "$T/oldrepo"
hasnt "E3 --repo ignores the age gate"                    "$RUN_OUT" "no registered repo has a commit younger"
has   "E3 and actually checks its branches"               "$RUN_OUT" "FLAG [host-only-branch]"

# The BLIND gate. What changed on 2026-08-07 is what EARNS one: a readable
# worktree is read, and a worktree whose directory has been removed underneath
# git is the genuine "a domain existed and was not read".
newrepo blindrepo
git -C "$T/blindrepo" branch -q ghostside
git -C "$T/blindrepo" worktree add -q "$T/blindrepo-gone" ghostside >/dev/null 2>&1
rm -rf "$T/blindrepo-gone"
run_rc "$T/blockers-today.md" --strict --repo "$T/blindrepo"
rc    "E4 an UNREADABLE worktree is BLIND and exits 6"    6 "$RUN_RC"
hasnt "E4 and it really was BLIND-not-FLAG"               "$RUN_OUT" "FLAG ["
has   "E4 names the unreadable worktree"                  "$RUN_OUT" "BLIND [worktree]"

run_rc "$T/blockers-today.md" --strict --allow-blind --repo "$T/blindrepo"
rc    "E5 --allow-blind downgrades BLIND to a warning"    0 "$RUN_RC"

# A FLAG is something we DID see; BLIND is something we could not. dirtyrepo
# has no worktree, so this also pins that a plain FLAG still exits 1 and not 6.
run_rc "$T/blockers-today.md" --strict --repo "$T/dirtyrepo"
rc    "E6 a FLAG still exits 1, not 6"                    1 "$RUN_RC"

# Usage errors. Two selectors that disagree is a usage error, not something
# to resolve by precedence and silently honour one of.
run_rc "$T/blockers-today.md" --repo "$T/loose" clean
rc    "E7 --repo plus a project name is rejected"         2 "$RUN_RC"
run_rc "$T/blockers-today.md" --repo "$T/sched"
rc    "E8 --repo on a non-git directory is rejected"      2 "$RUN_RC"
run_rc "$T/blockers-today.md" --repo
rc    "E9 --repo with no path is rejected"                2 "$RUN_RC"

# A subdirectory argument must still name the repo, or a hook whose cwd is
# nested would audit nothing and report clean.
run_rc "$T/blockers-today.md" --repo "$T/loose/.git/.."
has   "E10 --repo resolves to the work-tree root"         "$RUN_OUT" "single tree: $T/loose"

echo
echo "-- F. squash-merged branches (the 12-out-of-12 false alarm)"
# THE NUMBERS (#99 carries the full reconciliation): 12
# [host-only-branch] FLAGs on 2026-08-07, all twelve squash-merged PRs with
# deleted upstreams, zero true positives. F2 is the teeth.
newrepo squashed
git -C "$T/squashed" checkout -q -b feature
echo alpha > "$T/squashed/a.txt"; git -C "$T/squashed" add -A
git -C "$T/squashed" commit -qm 'first half'
echo beta > "$T/squashed/b.txt"; git -C "$T/squashed" add -A
git -C "$T/squashed" commit -qm 'second half'
git -C "$T/squashed" push -q origin feature
# ...and now GitHub's squash-merge reproduced exactly: one new commit on main
# with the branch's content, upstream branch deleted, local `feature` still
# pointing at the ORIGINAL two commits -- the state all 12 were in.
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

out="$(run "$T/blockers-today.md" squashed)"
hasnt "F1 squash-merged branch is NOT flagged as host-only" "$out" "FLAG [host-only-branch] squashed: branch 'feature'"
has   "F1 it is reported as landed, not as lost"            "$out" "note [landed] squashed: 'feature'"
has   "F2 a genuinely unmerged branch STILL flags"          "$out" "FLAG [host-only-branch] squashed: branch 'lost'"

# F3: the downgrade must not need the network. F1 passing at all is already the
# offline proof, but pin it explicitly -- a guard that hard-requires a network
# is its own failure mode. Prepending a nonexistent directory to PATH does not
# remove the real `gh` already earlier on it, so this used to not exercise the
# no-gh case it claimed to; use the same GH_BIN-pointed-at-nothing stub B4
# uses instead, which `command -v` genuinely cannot resolve.
GH_BIN="$T/nope/gh"
out="$(run "$T/blockers-today.md" squashed)"
GH_BIN="$GH_DEFAULT"
hasnt "F3 offline (no gh on PATH) still declines to flag"   "$out" "FLAG [host-only-branch] squashed: branch 'feature'"
has   "F3 and still flags the genuinely unmerged one"       "$out" "FLAG [host-only-branch] squashed: branch 'lost'"

# F4: no git identity must not break the probe. Reconstructing a squash commit
# needs an author and a CI runner has no global one, so the script must supply
# its own rather than inherit ("empty ident name").
out="$(HOME="$T/no-identity" GIT_CONFIG_GLOBAL=/dev/null \
       run "$T/blockers-today.md" squashed)"
hasnt "F4 no git identity -> probe still works"             "$out" "FLAG [host-only-branch] squashed: branch 'feature'"

echo
echo "-- G. linked worktrees are READ, not declared unread"
# One `BLIND [worktrees] ... 13 NOT examined` line sat above section F's twelve
# false FLAGs, and every agent here works IN a worktree. G1 is load-bearing: an
# unpushed COMMIT in a linked worktree is now FOUND, previously unrepresentable.

# G1: committed work inside a linked worktree, not on its upstream -> FLAG.
newrepo wt_unpushed
git -C "$T/wt_unpushed" branch -q feat
git -C "$T/wt_unpushed" push -q origin feat
git -C "$T/wt_unpushed" worktree add -q "$T/wt_unpushed-side" feat >/dev/null 2>&1
echo stranded > "$T/wt_unpushed-side/s.txt"
git -C "$T/wt_unpushed-side" add -A
git -C "$T/wt_unpushed-side" commit -qm 'committed here and never pushed'
out="$(run "$T/blockers-today.md" wt_unpushed)"
has   "G1 unpushed commit IN a worktree is FLAGged"  "$out" "FLAG [worktree-unpushed]"
has   "G1 and it names the worktree branch"          "$out" "feat"
hasnt "G1 and it is no longer merely BLIND"          "$out" "BLIND [worktrees]"
# G5: the branch audit still skips a branch checked out in a linked worktree,
# but its message used to cite a "BLIND above" that #99 deleted -- a dangling
# cross-reference misleads exactly the reader who goes looking.
has   "G5 a worktree-checked-out branch is still skipped" "$out" "skip [other-worktree]"
hasnt "G5 and the skip cites no BLIND that no longer exists" "$out" "BLIND above"

# G2: a DIRTY worktree is reported but does NOT gate -- a concurrent agent's
# tree is dirty by construction while it runs, and gating would make this guard
# red during every parallel session. A note, never silence.
newrepo wt_dirty
git -C "$T/wt_dirty" branch -q scratch
git -C "$T/wt_dirty" push -q origin scratch
git -C "$T/wt_dirty" worktree add -q "$T/wt_dirty-side" scratch >/dev/null 2>&1
echo mid-run >> "$T/wt_dirty-side/f.txt"
run_rc "$T/blockers-today.md" --strict --repo "$T/wt_dirty"
has   "G2 a dirty worktree is reported"              "$RUN_OUT" "note [worktree-dirty]"
hasnt "G2 but it is not a FLAG"                      "$RUN_OUT" "FLAG [worktree"
rc    "G2 and it does not gate a concurrent run"     0 "$RUN_RC"

# G2b/G2c: mtime-split the worktree note the way #137 split the main checkout
# (#150). An anchor an hour in the future makes the fixture's dirt unambiguously
# OLDER than this session -- the agent that used the worktree already exited
# before this run began, so it FLAGs instead of reading as a live concurrent
# run. Same tree, anchor moved to 1970: every path now postdates the session
# start, and the original note-only behaviour is preserved.
SESSION_START="$(( $(date +%s) + 3600 ))"
run_rc "$T/blockers-today.md" --strict --repo "$T/wt_dirty"
has   "G2b abandoned worktree dirt FLAGs"            "$RUN_OUT" "FLAG [worktree-dirty-abandoned]"
has   "G2b names the worktree path"                  "$RUN_OUT" "$T/wt_dirty-side"
rc    "G2b and it gates"                             1 "$RUN_RC"

SESSION_START=1
run_rc "$T/blockers-today.md" --strict --repo "$T/wt_dirty"
has   "G2c dirt modified during the session is still just a note" "$RUN_OUT" "note [worktree-dirty]"
hasnt "G2c and still not a FLAG"                     "$RUN_OUT" "FLAG [worktree"
rc    "G2c and it still does not gate"               0 "$RUN_RC"
SESSION_START=""

# G3: an UNREADABLE worktree is still BLIND. Removing the audit's ability to
# say "I could not look" would trade one conflation for another.
run_rc "$T/blockers-today.md" --repo "$T/blindrepo"
has   "G3 unreadable worktree still says BLIND"      "$RUN_OUT" "BLIND [worktree]"

# G4: BLIND LEADS THE SUMMARY. The defect was not only that 13 worktrees went
# unread -- the line saying so was buried above twelve louder FLAGs and skipped.
run_rc "$T/blockers-today.md" --repo "$T/blindrepo"
case "$RUN_OUT" in
  *"BLIND: "*"domain(s) existed and were NOT read"*) ok "G4 summary leads with BLIND" ;;
  *) bad "G4 summary leads with BLIND (no leading BLIND banner in summary)" ;;
esac

echo
echo "-- H. a shared checkout's PRE-EXISTING dirt is not this run's (#137)"
# THE INCIDENT (#137). On 2026-08-11 a subagent was blocked at close over two
# paths already in its session-start `git status` snapshot, and every remedy
# offered was wrong: committing adopts another session's work under your name,
# reverting destroys it, and it had nothing to push. H1..H3 pin the
# [worktree-dirty] carve-out for the main checkout as a MEASUREMENT (mtime vs
# session start), not a blanket exemption. $SESSION_START on its own line, same
# bash reason as $GH_BIN.
newrepo sharedtree && echo 'another session was here' >> "$T/sharedtree/f.txt"

# H1: an anchor an hour from now is unambiguously later than a file written a
# moment ago, so nothing in this tree can be this run's.
SESSION_START="$(( $(date +%s) + 3600 ))"
run_rc "$T/blockers-today.md" --strict --repo "$T/sharedtree"
has   "H1 pre-existing dirt is a note"         "$RUN_OUT" "note [pre-existing-dirty] sharedtree"
hasnt "H1 and NOT a FLAG"                      "$RUN_OUT" "FLAG [dirty-tree]"
has   "H1 the paths are still printed, never silent" "$RUN_OUT" "f.txt"
rc    "H1 and it does not block the closing run" 0 "$RUN_RC"

# H2: THE TEETH. Same tree, same dirt, anchor moved to 1970 -- every path now
# postdates the session start, which is what "this run modified it" means.
SESSION_START=1
run_rc "$T/blockers-today.md" --strict --repo "$T/sharedtree"
has   "H2 dirt modified during the session still FLAGs" "$RUN_OUT" "FLAG [dirty-tree] sharedtree"
has   "H2 and it counts what is this run's"    "$RUN_OUT" "1 of 1 modified since this session started"
rc    "H2 and it gates"                        1 "$RUN_RC"

# H3: UNKNOWN IS NOT CLEAN. An unparseable anchor stands in for the no-anchor
# case (cron, CI), which a suite that may itself run under a claude ancestor
# cannot produce deterministically.
SESSION_START="not a time at all"
run_rc "$T/blockers-today.md" --strict --repo "$T/sharedtree"
has   "H3 an unknowable session start still FLAGs" "$RUN_OUT" "FLAG [dirty-tree] sharedtree"
has   "H3 and says the anchor is what it lacked"   "$RUN_OUT" "session start is unknown here"
rc    "H3 and it gates"                        1 "$RUN_RC"
SESSION_START=""

echo
echo "-- I. other worktrees' branches are attributed and COUNTED (#106)"
# 12 OF 12 WAS THE FLAG RATE; THE LINE RATE OUTLIVED IT. #99 removed the false
# FLAGs, but each other-worktree branch still printed a ~180-character `skip`
# line -- 20 in a 99-line report whose only finding was one. So: ONE counted
# line, not dropped (I2 pins the names still on screen).
newrepo attribrepo
git -C "$T/attribrepo" branch -q sideA && git -C "$T/attribrepo" push -q origin sideA
git -C "$T/attribrepo" branch -q sideB && git -C "$T/attribrepo" push -q origin sideB
git -C "$T/attribrepo" worktree add -q "$T/attribrepo-A" sideA >/dev/null 2>&1
git -C "$T/attribrepo" worktree add -q "$T/attribrepo-B" sideB >/dev/null 2>&1
out="$(run "$T/blockers-today.md" attribrepo)"
count "I1 two other-worktree branches produce ONE line" "$out" "skip [other-worktree]" 1
has   "I1 and it counts the branches"          "$out" "2 branch(es) are checked out in 2 linked worktree(s)"
has   "I2 sideA is still named"                "$out" "sideA"
has   "I2 sideB is still named"                "$out" "sideB"
hasnt "I3 and none of them is a finding"       "$out" "FLAG [host-only-branch]"

# I4: attribution is by CHECKOUT, so a branch checked out nowhere is
# attributable to nobody and still FLAGs -- refusing #106's other suggestion,
# FLAG only the current worktree's, which would restore a measured blindness.
git -C "$T/attribrepo" branch -q nobodys-branch
echo more > "$T/attribrepo/h.txt"; git -C "$T/attribrepo" add -A
git -C "$T/attribrepo" commit -qm 'a commit on no remote'
git -C "$T/attribrepo" branch -qf nobodys-branch HEAD
git -C "$T/attribrepo" reset -q --hard origin/main
out="$(run "$T/blockers-today.md" attribrepo)"
has   "I4 a branch owned by no worktree still FLAGs" "$out" "FLAG [host-only-branch] attribrepo: branch 'nobodys-branch'"
count "I4 and the counted skip line is still one" "$out" "skip [other-worktree]" 1

echo "-- J. an unreadable/absent registry is BLIND, not clean (#232)"
# A full sweep (no --repo, no explicit names) against a SCHED_ROOT whose
# schedule/ directory does not exist must not read as "zero repos touched" --
# that is indistinguishable from "looked at everything, found nothing", the
# exact conflation E4's BLIND gate exists for elsewhere in this suite.
# mandark lost its scheduler checkout entirely (hf7y/realisateur#232); this
# fixture is that state, reached with no fixture registry at all.
EMPTY="$T/no-such-sched"
J_OUT="$(TODAY="$DAY" SCHED_ROOT="$EMPTY" BLOCKERS_MD="$T/blockers-today.md" HOURS=12 \
  GH_BIN="$GH_DEFAULT" SESSION_START="" "$SCRIPT" 2>&1)"; J_RC=$?
rc    "J1 absent registry sweep exits 0 without --strict" 0 "$J_RC"
has   "J1 but still reports BLIND"             "$J_OUT" "BLIND [registry]"
hasnt "J1 and never claims a clean scan"       "$J_OUT" "0 FLAG(s) across 0 recently-touched repo(s); 0 BLIND"

J2_OUT="$(TODAY="$DAY" SCHED_ROOT="$EMPTY" BLOCKERS_MD="$T/blockers-today.md" HOURS=12 \
  GH_BIN="$GH_DEFAULT" SESSION_START="" "$SCRIPT" --strict 2>&1)"; J2_RC=$?
rc    "J2 --strict against an absent registry gates as BLIND (6)" 6 "$J2_RC"
has   "J2 names the registry path"             "$J2_OUT" "$EMPTY/schedule/"

# hf7y/realisateur#245: an unreadable registry also empties touched_paths, so
# Section B's "no repo touched" branch fired even when this session HAD
# committed and pushed real work -- a blind enumerator phrasing its own
# blindness as a finding about the subject. Must read BLIND, not NOTE.
has   "J2 Section B is BLIND too, not a false 'no work' claim" "$J_OUT" \
  "BLIND [session-record] registry was unreadable"
hasnt "J2 and never claims there was no work to record"       "$J_OUT" \
  "no work to have recorded"

J3_OUT="$(TODAY="$DAY" SCHED_ROOT="$EMPTY" BLOCKERS_MD="$T/blockers-today.md" HOURS=12 \
  GH_BIN="$GH_DEFAULT" SESSION_START="" "$SCRIPT" --strict --allow-blind 2>&1)"; J3_RC=$?
rc    "J3 --allow-blind downgrades it to a warning" 0 "$J3_RC"

# A registry that DOES exist and has real projects must not regress into
# reporting BLIND [registry] just because nothing was touched recently --
# that path is A1's "(no registered repo has a commit younger than...)" note,
# a different and older signal this change must not shadow.
J4_OUT="$(run "$T/blockers-old.md" oldrepo)"
hasnt "J4 a real, merely-stale registry is not BLIND [registry]" "$J4_OUT" "BLIND [registry]"
has   "J4 it still reports the stale-repo note"                  "$J4_OUT" "no registered repo has a commit younger"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
