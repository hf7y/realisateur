#!/usr/bin/env bash
# sync-runtime.sh -- adopt the skeleton runtime onto one bashified branch.
#
# WHY THIS IS A COMMAND AND NOT A HAND-COPY
# -----------------------------------------
# The runtime forked into four dialects because propagating it was always a
# hand-copy: something a session did once and no code in any repo performed.
# That is the exact shape of the 2026-07-29 dispatch outage -- one symlink a
# human made once, that nothing could recreate. Copying the file by hand to fix
# a fork caused by copying the file by hand would be the same mistake twice.
#
# THE GUARD THIS EXISTS FOR, and it is the whole point.
# Overwriting a branch's runtime DELETES any function that runtime provided and
# the skeleton does not. If a verb on that branch calls one, the verb breaks the
# moment the file lands -- and it breaks at a call site nobody is looking at,
# in a repo nobody opened. So before writing anything, this compares:
#
#   functions the branch's verbs CALL   vs   functions the skeleton DEFINES
#
# and REFUSES if the skeleton is missing any. A verb that defines the function
# itself is fine and is not counted.
#
# That check is what mechanically catches gardien: its `bin/garde` calls
# `verb_gap_or_summon` at four sites, and the skeleton deliberately does not
# carry it (it calls `claude -p` directly, which the skeleton's own line 32
# forbids). gardien is not on an exemption list here -- the guard derives the
# refusal from the code every run, so the day `garde` stops calling it, sync
# starts working with no list to remember to edit.
#
# PREFLIGHT BY DEFAULT. Writes nothing without --apply, and never commits: the
# change is left in the working tree so it can be read before it becomes
# history. Same reasoning as coin.sh.
set -uo pipefail

CLI_NAME='sync-runtime.sh'
CLI_SUMMARY='adopt the skeleton lib/verb.sh onto one bashified branch'
CLI_USAGE='  sync-runtime.sh <project>           preflight: report what would change
  sync-runtime.sh <project> --apply   write it (does not commit)'
CLI_FLAGS='--apply'
CLI_POSITIONAL=any
CLI_EXITS='  0  synced, or already identical
  1  nothing was written (refused, dirty, or a verb needs a function the skeleton lacks)
  2  usage error'

SELF="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"   # bashify/
ROOT="$(cd "$SELF/.." && pwd)"                                             # realisateur/
SKEL="$SELF/skel/lib/verb.sh"

. "$ROOT/bin/lib/cli-guard.sh"
cli_guard "$@"
. "$ROOT/bin/lib/verb-set.sh"

APPLY=0
PROJECT=""
for a in "$@"; do
  case "$a" in
    --apply) APPLY=1 ;;
    *) [ -n "$PROJECT" ] && { echo "$CLI_NAME: one project at a time (got '$PROJECT' and '$a')" >&2; exit 2; }
       PROJECT="$a" ;;
  esac
done
[ -n "$PROJECT" ] || { echo "$CLI_NAME: needs a project name" >&2; exit 2; }
[ -f "$SKEL" ] || { echo "$CLI_NAME: FATAL: no skeleton at $SKEL" >&2; exit 1; }

PROJECTS="${INSTALLE_PROJECTS:-$HOME/Documents/Projects}"
repo="$PROJECTS/$PROJECT"

verb_set_declared | cut -f1 | sort -u | grep -qx "$PROJECT" \
  || { echo "$CLI_NAME: '$PROJECT' declares no verb -- nothing to sync." >&2
       echo "(refusing to exit 0 about a name that matches nothing)" >&2; exit 1; }

tree="$(verb_set_worktree_of "$repo")"
[ -n "$tree" ] || { echo "$CLI_NAME: $PROJECT's bashified branch is not checked out in any worktree." >&2
                    echo "  sync writes into a working copy. Check it out first:" >&2
                    echo "  git -C $repo worktree add ../$PROJECT-verbs bashified" >&2; exit 1; }

echo "sync-runtime -- $PROJECT"
echo "  worktree: $tree"
echo "  skeleton: $SKEL"
echo "  mode:     $( ((APPLY)) && echo APPLY || echo 'preflight (nothing is written)')"
echo

live="$tree/lib/verb.sh"
if [ -f "$live" ] && cmp -s "$live" "$SKEL"; then
  echo "  already byte-identical to the skeleton -- nothing to do."
  exit 0
fi

# ------------------------------------------------------- the refusal check --
# What does the skeleton define?
mapfile -t skel_fns < <(grep -oE '^[a-z_]+\(\)' "$SKEL" | tr -d '()' | sort -u)
# What does it SET? (a verb reading VERB_FOO that the skeleton never sets would
# die under `set -u`, which is just as fatal as a missing function.)
mapfile -t skel_vars < <(grep -oE '^[[:space:]]*VERB_[A-Z_]+=' "$SKEL" | tr -d ' =' | sort -u)

missing_fns=()
missing_vars=()
for f in "$tree"/bin/*; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"
  # Functions this verb defines for itself are not the skeleton's problem.
  mapfile -t own < <(grep -oE '^[a-z_]+\(\)' "$f" | tr -d '()' | sort -u)
  while read -r call; do
    [ -n "$call" ] || continue
    printf '%s\n' "${skel_fns[@]}" | grep -qx "$call" && continue
    printf '%s\n' "${own[@]:-}"    | grep -qx "$call" && continue
    missing_fns+=("$name calls $call()")
  done < <(grep -oE '\bverb_[a-z_]+\b' "$f" | sort -u)
  while read -r v; do
    [ -n "$v" ] || continue
    printf '%s\n' "${skel_vars[@]}" | grep -qx "$v" && continue
    grep -qE "^[[:space:]]*$v=" "$f" && continue
    missing_vars+=("$name reads \$$v")
  done < <(grep -oE '\bVERB_[A-Z_]+\b' "$f" | sort -u)
done

if [ "${#missing_fns[@]}" -gt 0 ] || [ "${#missing_vars[@]}" -gt 0 ]; then
  echo "  REFUSED -- the skeleton does not provide everything this branch's verbs use."
  echo "  Overwriting lib/verb.sh would break them at a call site nobody is watching."
  echo
  for m in ${missing_fns[@]+"${missing_fns[@]}"}; do echo "    MISSING FUNCTION  $m"; done
  for m in ${missing_vars[@]+"${missing_vars[@]}"}; do echo "    MISSING VARIABLE  $m"; done
  echo
  echo "  Either the skeleton should adopt it, or the verb should stop calling it."
  echo "  Both are real decisions; neither is this script's to make."
  exit 1
fi

# ------------------------------------------------------------- dirty check --
# A sync landing on top of uncommitted work makes the two indistinguishable in
# the commit -- this ecosystem's most-recorded failure signature.
if [ -n "$(git -C "$tree" status --porcelain 2>/dev/null)" ]; then
  echo "  REFUSED -- $tree has uncommitted changes."
  echo "  Commit or clear them first: a sync on a dirty tree cannot be told apart"
  echo "  from the work already there."
  exit 1
fi

n_live="$( [ -f "$live" ] && wc -l < "$live" || echo 0)"
echo "  would replace lib/verb.sh: $n_live lines -> $(wc -l < "$SKEL") lines"
echo "  every function and variable this branch's verbs use is present in the skeleton."
echo

if ((APPLY)); then
  mkdir -p "$(dirname "$live")"
  cp "$SKEL" "$live" || { echo "$CLI_NAME: could not write $live" >&2; exit 1; }
  echo "  WRITTEN. Nothing was committed -- read it, run the contract tests, then commit."
  echo
  echo "  verify:"
  for f in "$tree"/bin/*; do
    [ -f "$f" ] || continue
    echo "    (cd $tree && ./test/contract-test.sh bin/$(basename "$f"))"
  done
else
  echo "  Preflight only. Re-run with --apply to write it."
fi
exit 0
