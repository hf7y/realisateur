#!/usr/bin/env bash
# carry-drift.test.sh -- every file bin/lib/carries.tsv says `bashified`
# carries from `main` is still byte-identical to its source.
#
# HERMETIC. Reads this checkout's own git refs only -- no ssh, no sudo, no
# read of any live host. `origin/bashified` must be resolvable; tests.yml
# fetches it before this suite runs, and a fetch is attempted here too so a
# local run (or a shallower CI checkout) is BLIND, not silently green,
# instead of failing to find any carried pair.
#
# WHY THIS EXISTS. realisateur#511 deleted bin/carry-drift.sh (230 lines, six
# sampled guards found to produce zero findings) and moved the CARRIES table
# it held into bin/lib/carries.tsv -- but carried nothing forward that
# actually compared the two sides. #516: two carries the same day were done
# by hand, and this run found a THIRD, worse case while building this
# witness -- bin/lib/body-grammar.sh on bashified carried a change from
# realisateur#510 before that PR ever merged, and #510's premise (extending
# the delivery-audit.sh it depended on) was deleted by #511 twenty-five
# minutes later. bashified was accepting a claim kind main never shipped a
# verifier for. Modeled on scheduler's tests/carry-drift-witness.sh -- one
# assertion per carried file, no CLI, no ratchet -- not a resurrection of the
# deleted script.
#
# THE MAIN SIDE IS origin/main. It was HEAD until 2026-08-23; see the block
# above the REF_MAIN resolution below for what that cost and why it moved.
#
# usage: ./bin/tests/carry-drift.test.sh

set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TABLE="$REPO/bin/lib/carries.tsv"
[ -f "$TABLE" ] || { echo "FAIL: $TABLE missing"; exit 1; }

echo "carry-drift.test.sh"

# origin/bashified FIRST, and refreshed before it is read. A local
# `bashified` branch on a dev checkout is whatever that clone last fetched --
# preferring it made this suite report drift against a branch nobody ships
# (8 commits stale here on 2026-08-22), and would just as happily report
# clean against one. The local branch is a fallback for a clone with no
# remote at all, and says so when it is used.
REF_BASH=""
git -C "$REPO" fetch -q --depth=1 origin bashified:refs/remotes/origin/bashified 2>/dev/null || true
if git -C "$REPO" rev-parse --verify -q "origin/bashified^{commit}" >/dev/null 2>&1; then
  REF_BASH="origin/bashified"
elif git -C "$REPO" rev-parse --verify -q "bashified^{commit}" >/dev/null 2>&1; then
  REF_BASH="bashified"
  echo "  note  origin/bashified unreadable; comparing against the LOCAL bashified branch"
fi
if [ -z "$REF_BASH" ]; then
  bad "no bashified ref is readable here -- drift was NOT checked (BLIND, not clean)"
  summary; exit $?
fi

# THE MAIN SIDE IS origin/main, NOT HEAD -- changed 2026-08-23, hf7y/realisateur#578.
#
# It was HEAD, on the reasoning that "a PR that edits a carried source without
# carrying it goes red before it merges". That is incompatible with how this
# estate actually carries, and bin/lib/carries.tsv records why: carrying BEFORE
# the merge is what put a #510 change onto bashified before that PR landed, 25
# minutes before #511 deleted its premise. The carry is a SECOND STEP, AFTER
# the merge -- so under the old rule every branch touching a carried source was
# red for doing the right thing.
#
# MEASURED, and it was not theoretical: `suites` is a REQUIRED check, so this
# suite wedged every such PR. On 2026-08-23 that was #565, #571 and #579 at
# once -- three PRs that could never merge, one of them not even ours.
#
# origin/main answers the question this guard was built for (#516): is the
# CARRY behind, or has bashified been hand-edited? A PR cannot fail that, and
# a missing carry still goes red the moment it merges.
REF_MAIN=""
git -C "$REPO" fetch -q --depth=1 origin main:refs/remotes/origin/main 2>/dev/null || true
if git -C "$REPO" rev-parse --verify -q "origin/main^{commit}" >/dev/null 2>&1; then
  REF_MAIN="origin/main"
elif git -C "$REPO" rev-parse --verify -q "main^{commit}" >/dev/null 2>&1; then
  REF_MAIN="main"
  echo "  note  origin/main unreadable; comparing against the LOCAL main branch"
fi
if [ -z "$REF_MAIN" ]; then
  bad "no main ref is readable here -- drift was NOT checked (BLIND, not clean)"
  summary; exit $?
fi

n=0
while IFS=$'\t' read -r carried src; do
  case "$carried" in ''|'#'*) continue ;; esac
  n=$((n + 1))
  a="$(git -C "$REPO" show "$REF_BASH:$carried" 2>/dev/null)"
  if [ -z "$a" ] && ! git -C "$REPO" cat-file -e "$REF_BASH:$carried" 2>/dev/null; then
    bad "$carried is declared in carries.tsv but does not exist on $REF_BASH"
    continue
  fi
  b="$(git -C "$REPO" show "$REF_MAIN:$src" 2>/dev/null)"
  if [ -z "$b" ] && ! git -C "$REPO" cat-file -e "$REF_MAIN:$src" 2>/dev/null; then
    bad "$src (source of $carried) does not exist on $REF_MAIN"
    continue
  fi
  if [ "$a" = "$b" ]; then
    ok "$carried matches its source $src"
  else
    bad "$carried DRIFTED from $src -- $REF_BASH ships a different file than $REF_MAIN develops. The carry is owed, or bashified was hand-edited."
  fi
done < <(grep -v '^#' "$TABLE" | grep -v '^[[:space:]]*$')

if [ "$n" -gt 0 ]; then
  ok "checked $n carried file(s) from bin/lib/carries.tsv"
else
  bad "carries.tsv named zero carried files"
fi

summary
