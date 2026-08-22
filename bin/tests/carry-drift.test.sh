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
# THE MAIN SIDE IS HEAD, not origin/main: on a pull_request run,
# actions/checkout leaves HEAD at the PR's own proposed content, so a PR that
# edits a carried source without carrying it goes red before it merges,
# exactly where scheduler#222 puts the equivalent failure.
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

n=0
while IFS=$'\t' read -r carried src; do
  case "$carried" in ''|'#'*) continue ;; esac
  n=$((n + 1))
  a="$(git -C "$REPO" show "$REF_BASH:$carried" 2>/dev/null)"
  if [ -z "$a" ] && ! git -C "$REPO" cat-file -e "$REF_BASH:$carried" 2>/dev/null; then
    bad "$carried is declared in carries.tsv but does not exist on $REF_BASH"
    continue
  fi
  b="$(git -C "$REPO" show "HEAD:$src" 2>/dev/null)"
  if [ -z "$b" ] && ! git -C "$REPO" cat-file -e "HEAD:$src" 2>/dev/null; then
    bad "$src (source of $carried) does not exist at HEAD"
    continue
  fi
  if [ "$a" = "$b" ]; then
    ok "$carried matches its source $src"
  else
    bad "$carried DRIFTED from $src -- $REF_BASH ships a different file than HEAD develops"
  fi
done < <(grep -v '^#' "$TABLE" | grep -v '^[[:space:]]*$')

if [ "$n" -gt 0 ]; then
  ok "checked $n carried file(s) from bin/lib/carries.tsv"
else
  bad "carries.tsv named zero carried files"
fi

summary
