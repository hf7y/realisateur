#!/usr/bin/env bash
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
#   A4 branch tracking nothing        -> FLAG [no-upstream]
#   A5 HEAD older than HOURS          -> not scanned at all (no flag, not listed)
#   A6 registered path does not exist -> FLAG [missing-repo]
#   B1 today's entry citing a sha     -> ok
#   B2 today's entry, no sha          -> FLAG [record-no-sha]
#   B3 no entry dated today           -> FLAG [no-record]
#   B4 FOCUS.md missing               -> FLAG [no-focus]
#   C1 BLOCKERS.md dated today        -> ok, no flag
#   C2 BLOCKERS.md with nothing today -> NOTE only, still no flag
#
# Negative-tested against an `exit 0` stub: 13 of the 16 assertions fail as
# they should. The 3 that survive are all `hasnt` (absence) assertions, which
# a silent stub passes vacuously -- so every `hasnt` case here is deliberately
# paired with a positive assertion on the same fixture (A1, A5, C2), and no
# case rests on absence alone.
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
newrepo dirtyrepo && echo scratch >> "$T/dirtyrepo/f.txt"
newrepo aheadrepo && { echo two > "$T/aheadrepo/g.txt"; git -C "$T/aheadrepo" add -A; \
                       git -C "$T/aheadrepo" commit -qm ahead; }
newrepo detached && git -C "$T/detached" checkout -q -B orphan
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

echo "closeout-lint.test.sh"
echo "-- A. recently touched repos"
out="$(run "$T/focus-ok.md" "$T/blockers-today.md" clean)"
hasnt "A1 clean repo raises no flag"           "$out" "FLAG ["
has   "A1 clean repo counted as touched"       "$out" "0 FLAG(s) across 1"

out="$(run "$T/focus-ok.md" "$T/blockers-today.md" dirtyrepo)"
has   "A2 dirty tree flagged"                  "$out" "FLAG [dirty-tree] dirtyrepo"

out="$(run "$T/focus-ok.md" "$T/blockers-today.md" aheadrepo)"
has   "A3 unpushed commit flagged"             "$out" "FLAG [unpushed] aheadrepo"
has   "A3 names the count"                     "$out" "1 commit(s) on main not pushed"

out="$(run "$T/focus-ok.md" "$T/blockers-today.md" detached)"
has   "A4 untracked branch flagged"            "$out" "FLAG [no-upstream] detached"

out="$(run "$T/focus-ok.md" "$T/blockers-today.md" oldrepo)"
hasnt "A5 stale repo not flagged"              "$out" "FLAG ["
has   "A5 stale repo not even scanned"         "$out" "no registered repo has a commit younger"

out="$(run "$T/focus-ok.md" "$T/blockers-today.md" ghostrepo)"
has   "A6 missing repo path flagged"           "$out" "FLAG [missing-repo] ghostrepo"

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

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
