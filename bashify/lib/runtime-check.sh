#!/usr/bin/env bash
# runtime-check.sh -- has any branch's lib/verb.sh drifted from the skeleton?
#
# TRAPS (the rest of this header is in the vault):
# WHY THIS EXISTS
# ---------------
# skel/lib/verb.sh says it exists "so nineteen utilities cannot drift into
# nineteen dialects." It had drifted into FOUR, across ten repos, and the
# canonical copy was running in only two of them. Nothing noticed for a month
# because nothing ever asked.
# THE CHECK IS BYTE-IDENTITY, deliberately, and that is not pedantry. The purge
# guard in bashify.sh already exempts lib/verb.sh's use of the word "agent"
# ONLY IF the file is byte-identical to the skeleton -- so "identical" is
# already load-bearing elsewhere in this generator, and a looser check here
# would silently widen that exemption.
# Offline, read-only, zero cost. It never writes to any repository.

set -uo pipefail

CLI_NAME='runtime-check.sh'
CLI_SUMMARY='report any bashified branch whose lib/verb.sh has drifted from the skeleton'
CLI_USAGE='  runtime-check.sh            check every project that declares a verb
  runtime-check.sh <project>  check one'
CLI_FLAGS=''
CLI_POSITIONAL=any
CLI_EXITS='  0  every checked runtime is byte-identical to the skeleton
  1  at least one has drifted (or a source could not be read)'

SELF="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"   # bashify/
ROOT="$(cd "$SELF/.." && pwd)"                                             # realisateur/
SKEL="$SELF/skel/lib/verb.sh"

. "$ROOT/bin/lib/cli-guard.sh"
cli_guard "$@"
. "$ROOT/bin/lib/verb-set.sh"

[ -f "$SKEL" ] || { echo "$CLI_NAME: FATAL: no skeleton at $SKEL" >&2; exit 1; }

PROJECTS="${INSTALLE_PROJECTS:-$HOME/Documents/Projects}"
WANT=("$@")

skel_sum="$(md5sum < "$SKEL" | cut -d' ' -f1)"
skel_lines="$(wc -l < "$SKEL")"

echo "runtime-check -- skeleton: $SKEL"
echo "  ${skel_sum:0:12}  $skel_lines lines"
echo

# The project list is DERIVED from the same declaration everything else reads,
# so a project cannot be checked here and unchecked there.
mapfile -t ALL < <(verb_set_declared | cut -f1 | sort -u)

if [ "${#ALL[@]}" -eq 0 ]; then
  # Zero projects is never "clean" -- it means discovery broke, which is the
  # same exit-0 no-op shape this whole family of checks exists to refuse.
  echo "$CLI_NAME: FATAL: no project declares a verb. That is a discovery failure, not a clean ecosystem." >&2
  exit 1
fi

drift=0
checked=0

for project in "${ALL[@]}"; do
  if [ "${#WANT[@]}" -gt 0 ]; then
    found=0
    for w in "${WANT[@]}"; do [ "$w" = "$project" ] && found=1; done
    [ "$found" = 1 ] || continue
  fi
  repo="$PROJECTS/$project"
  ref="$(verb_set_ref_of "$repo")" || {
    printf '  %-11s %-16s %s\n' UNREADABLE "$project" "no bashified ref at $repo"
    drift=$((drift + 1)); continue
  }
  checked=$((checked + 1))
  if ! blob="$(git -C "$repo" show "$ref:lib/verb.sh" 2>/dev/null)"; then
    printf '  %-11s %-16s %s\n' NORUNTIME "$project" "$ref carries no lib/verb.sh"
    drift=$((drift + 1)); continue
  fi
  sum="$(printf '%s\n' "$blob" | md5sum | cut -d' ' -f1)"
  if [ "$sum" = "$skel_sum" ]; then
    printf '  %-11s %-16s %s\n' OK "$project" "${sum:0:12}"
    continue
  fi
  # A BRANCH IS ITS COMMITTED STATE, so the comparison above is against the
  # committed blob and that is deliberate. But `sync-runtime --apply` writes the
  # working tree and does NOT commit, on purpose -- so between sync and commit
  # this check would report plain DRIFT about a runtime that has already been
  # adopted, and read as "the sync failed". Distinguish the two: still exit 1,
  # because the branch has not adopted it until it is committed, but say which
  # of the two situations this is.
  tree="$(verb_set_worktree_of "$repo")"
  if [ -n "$tree" ] && [ -f "$tree/lib/verb.sh" ] && cmp -s "$tree/lib/verb.sh" "$SKEL"; then
    printf '  %-11s %-16s %s\n' UNCOMMITTED "$project" \
      "working tree already matches the skeleton; the BRANCH does not yet"
    printf '  %-11s %-16s %s\n' '' '' \
      "commit it in $tree and this becomes OK"
    drift=$((drift + 1))
    continue
  fi
  n="$(printf '%s\n' "$blob" | wc -l)"
  d="$(diff <(printf '%s\n' "$blob") "$SKEL" 2>/dev/null | grep -c '^[<>]' || true)"
  printf '  %-11s %-16s %s  %s lines (skel %s), %s differing line(s)\n' \
    DRIFT "$project" "${sum:0:12}" "$n" "$skel_lines" "$d"
  # Name the known reason where there is one, so a reader does not have to
  # re-derive it -- but still count it as drift.
  if printf '%s' "$blob" | grep -q 'verb_gap_or_summon'; then
    printf '  %-11s %-16s %s\n' '' '' \
      'carries verb_gap_or_summon, which calls `claude -p` directly. The skeleton'
    printf '  %-11s %-16s %s\n' '' '' \
      'forbids contacting a model directly (Law 3). Adopting the union requires'
    printf '  %-11s %-16s %s\n' '' '' \
      'rewriting it to route through basheur; its call sites change shape.'
  fi
  # Names the path that actually runs, NOT a `bashify sync-runtime` subcommand.
  # Promoting these to subcommands is a page-first amendment: row 3 of the page
  # test compares `bashify list` against man/bashify.1 bidirectionally, so the
  # page has to contract them before the tool offers them. Advertising a
  # subcommand that does not exist is the exact defect `installe --force` was
  # -- a documented escape hatch wired to nothing.
  printf '  %-11s %-16s %s\n' '' '' "fix: bashify/lib/sync-runtime.sh $project --apply"
  drift=$((drift + 1))
done

echo
if [ "$checked" = 0 ] && [ "${#WANT[@]}" -gt 0 ]; then
  echo "$CLI_NAME: no project named '${WANT[*]}' declares a verb -- nothing was checked." >&2
  echo "(refusing to exit 0 about a name that matches nothing)" >&2
  exit 1
fi
if [ "$drift" = 0 ]; then
  echo "OK -- $checked runtime(s) byte-identical to the skeleton."
else
  echo "$drift of $checked runtime(s) have DRIFTED."
  echo "The skeleton's own promise is that this cannot happen; each row above is"
  echo "that promise not being kept."
fi
exit $(( drift > 0 ? 1 : 0 ))
