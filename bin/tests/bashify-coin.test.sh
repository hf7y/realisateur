#!/usr/bin/env bash
# bashify-coin.test.sh -- `bashify coin` is the ONLY door for a new verb in
# this ecosystem, and on 2026-08-11 it was dead on every project from every
# host, for two independent reasons at once.
#
# 1. THE PATH WAS NEVER EXPANDED. coin read the registry with
#        grep -oP '^PROJECT_REPO_PATH=\K.*' | tr -d '"'
#    which returns the LITERAL characters `$HOME/Documents/...`. The next
#    line, `[ -d "$REPO/.git" ]`, was therefore false everywhere, and coin
#    answered:
#        coin: BLIND: scheduler has no git repository at $HOME/Documents/Projects/scheduler
#    That is hf7y/realisateur#143, filed 2026-08-09, naming six such readers in
#    bashify/. bin/tests/conf.test.sh's section C would have caught it, except
#    its population was `bin/*.sh` only -- a ratchet that stopped at a
#    directory boundary. That glob now includes bashify/.
#
# 2. IT REQUIRED A WORKTREE THAT NO LONGER EXISTS. coin located the bashified
#    branch by scanning `git worktree list` for it. PR #156 removed all 30
#    worktrees that morning and added bin/no-worktree-lint.sh so a
#    thirty-first cannot appear, so the scan returned empty and coin exited
#    BLIND -- with a message that was true, permanent, and unactionable.
#
# WHAT IT COST, so the test is not abstract: bin/consigne was written,
# reviewed and merged in #121, and reached NO host's PATH, because graduating
# it needs `bashify coin` (hf7y/realisateur#162 says so in as many words).
# A verb that cannot be coined is a verb that cannot ship, and this estate's
# entire distribution story runs through that one command.
#
# HERMETICITY: runs the REAL bashify/lib/coin.sh, but every path it can reach
# is redirected into a mktemp tree -- HOME, SCHEDULE_DIR and BASHIFY_WORK all
# point inside $TMP, and the "projects" are git repos this file creates and
# deletes. It touches no repo in ~/Documents/Projects, no registry, no network,
# and no worktree. The conf fixtures deliberately write `$HOME/...` rather than
# an absolute path: a fixture that hardcoded the resolved path would pass
# against the very defect case A exists to catch, which is the fixture bug this
# estate has already paid for (MEMORY.md, "guards scrape unexpanded $HOME").
set -uo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
COIN="$ROOT/bashify/lib/coin.sh"
[ -f "$COIN" ] || { echo "no coin.sh at $COIN"; exit 1; }

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL  %s -- %s\n' "$1" "${2:-}"; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# --- a throwaway project carrying a populated bashified branch --------------
mkproj() {  # $1 = path
  local p="$1"
  mkdir -p "$p"
  git -C "$p" init -q .
  git -C "$p" config user.email t@example.invalid
  git -C "$p" config user.name  t
  mkdir -p "$p/bin" "$p/lib"
  printf 'seed\n' > "$p/README"
  git -C "$p" add -A && git -C "$p" commit -qm seed
  git -C "$p" checkout -q -b bashified
  printf 'verb_refuse() { :; }\n' > "$p/lib/verb.sh"
  printf '#!/usr/bin/env bash\n' > "$p/bin/existant"
  chmod +x "$p/bin/existant"
  git -C "$p" add -A && git -C "$p" commit -qm "bashified base"
  git -C "$p" checkout -q master 2>/dev/null || git -C "$p" checkout -q main
}

PROJ="$TMP/proj"; mkproj "$PROJ"
mkdir -p "$TMP/sched"

# THE CONF WRITES `$HOME`, exactly as every real conf in scheduler's registry
# does. That is the whole point of case A: a fixture that hardcoded an absolute
# path would pass against the broken reader too, which is the fixture bug this
# estate has already paid for twice (see MEMORY.md, "guards scrape unexpanded
# $HOME"). So HOME is pointed at the project's parent and the conf uses $HOME.
printf 'PROJECT_REPO_PATH="$HOME/proj"\n' > "$TMP/sched/fixt.conf"

coin() {  # runs the real coin.sh with HOME redirected at the fixture
  HOME="$TMP" SCHEDULE_DIR="$TMP/sched" BASHIFY_WORK="$TMP/work" \
    bash "$COIN" "$@" 2>&1
}

printf 'A. the registry path is EXPANDED, not taken literally\n'
out="$(coin fixt alpha 'the first probe verb')"; rc=$?
case "$out" in
  *'$HOME'*) bad "A1  no literal \$HOME in the output" "$(printf '%s' "$out" | head -2)" ;;
  *)         ok  "A1  no literal \$HOME in the output" ;;
esac
if [ "$rc" -eq 0 ]; then ok "A2  coin exits 0 against a \$HOME-relative conf"
else bad "A2  coin exits 0 against a \$HOME-relative conf" "rc=$rc: $(printf '%s' "$out" | head -2)"; fi

printf '\nB. it works with NO worktree anywhere (PR #156 removed them all)\n'
wt="$(git -C "$PROJ" worktree list --porcelain | grep -c '^worktree ' || true)"
if [ "$wt" -le 1 ]; then ok "B1  the fixture has no linked worktree (baseline)"
else bad "B1  the fixture has no linked worktree (baseline)" "found $wt"; fi
if git -C "$PROJ" cat-file -e "bashified:bin/alpha" 2>/dev/null; then
  ok "B2  the coined verb is reachable on the project's bashified branch"
else
  bad "B2  the coined verb is reachable on the project's bashified branch" "not in the ref"
fi
if [ -z "$(git -C "$PROJ" status --porcelain 2>/dev/null)" ]; then
  ok "B3  the project's own working tree was never touched"
else
  bad "B3  the project's own working tree was never touched" "$(git -C "$PROJ" status --porcelain | head -2)"
fi
if git -C "$PROJ" cat-file -e "bashified:bin/existant" 2>/dev/null; then
  ok "B4  coin ADDED to the branch -- the verb already there survives"
else
  bad "B4  coin ADDED to the branch -- the verb already there survives" "existant is gone; this regenerated instead of appending"
fi

printf '\nC. the coined file declares its channel, or it kills the next build\n'
body="$(git -C "$PROJ" show bashified:bin/alpha 2>/dev/null)"
case "$body" in
  *'# KIND: verb'*) ok "C1  the template emits '# KIND: verb'" ;;
  *) bad "C1  the template emits '# KIND: verb'" "cut-verb-build.sh dies the whole cut on an undeclared command" ;;
esac
case "$body" in
  *'Coined 2026-08-01'*) bad "C2  the coin date is today's, not a frozen literal" "template carries a hardcoded 2026-08-01" ;;
  *) ok "C2  the coin date is today's, not a frozen literal" ;;
esac

printf '\nD. the refusals that still mean something\n'
out="$(coin fixt existant 'should be refused')"; rc=$?
if [ "$rc" -eq 7 ]; then ok "D1  coining over an existing verb REFUSES (exit 7)"
else bad "D1  coining over an existing verb REFUSES (exit 7)" "rc=$rc"; fi

NOBR="$TMP/nobranch"; mkdir -p "$NOBR"
git -C "$NOBR" init -q . && git -C "$NOBR" config user.email t@example.invalid \
  && git -C "$NOBR" config user.name t
printf 'x\n' > "$NOBR/README"; git -C "$NOBR" add -A; git -C "$NOBR" commit -qm seed
printf 'PROJECT_REPO_PATH="$HOME/nobranch"\n' > "$TMP/sched/nobr.conf"
out="$(coin nobr beta 'no branch to add to')"; rc=$?
if [ "$rc" -eq 7 ]; then ok "D2  a project with no bashified branch REFUSES (exit 7)"
else bad "D2  a project with no bashified branch REFUSES (exit 7)" "rc=$rc"; fi
case "$out" in
  *"bashify emit"*) ok "D3  and names its escalation (emit)" ;;
  *) bad "D3  and names its escalation (emit)" "refusal did not say what to do instead" ;;
esac

printf 'PROJECT_REPO_PATH="$HOME/does-not-exist"\n' > "$TMP/sched/gone.conf"
out="$(coin gone gamma 'no repo at all')"; rc=$?
if [ "$rc" -eq 6 ]; then ok "D4  a conf pointing at no repo is BLIND (exit 6), not a gap"
else bad "D4  a conf pointing at no repo is BLIND (exit 6), not a gap" "rc=$rc"; fi

printf '\nbashify-coin: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
