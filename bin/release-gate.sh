#!/usr/bin/env bash
# release-gate.sh -- decide whether tonight's verb build is allowed to be cut.
#
# ============================================================================
# WHY THIS EXISTS
# ============================================================================
#
# The nightly build in `hf7y/verbs` has cut whatever was on each project's
# `bashified` branch, every night, with no opinion about whether that code
# worked. Zach's directive, 2026-08-07: `main` must never be allowed to sit
# red the way it just did for weeks, so a red `main` must STOP RELEASES. The
# coupling is the point, not a side effect -- a release channel that ships
# from a broken tree is a faster way to distribute a break.
#
# ============================================================================
# WHAT "GREEN" MEANS, AND WHY IT IS THIS AND NOT SOMETHING EASIER
# ============================================================================
#
# GREEN = every check run attached to the EXACT CURRENT HEAD SHA of the
# project's default branch has concluded successfully.
#
# The freshness property falls out of that and needs no window to tune: a
# successful run from three days ago is attached to a DIFFERENT sha, so the
# API simply does not return it. There is no "how old is too old" constant in
# this file, deliberately -- every such constant is a thing that can be set
# wrong and a thing a reader has to trust.
#
# Two easier answers were rejected, each for a measured reason:
#
#   1. GATE ON THE SHA BEING CUT (the bashified sha in the manifest).
#      Probed 2026-08-07 across all 12 projects carrying a `bashified`
#      branch: EVERY ONE has zero check runs on that branch. Workflows
#      trigger on `pull_request` and `push: [main]`; nothing runs on
#      bashified. A gate keyed there would return "no checks" for every
#      project on every night forever -- an exit-0 no-op wearing a gate's
#      name, which is this repository's signature failure.
#
#   2. GATE ON "THE LATEST RUN ON main" (`gh run list --branch main`).
#      That returns the newest run regardless of which commit it tested. A
#      commit pushed after the last run passed inherits that pass. This is
#      precisely the stale-evidence bug the directive named, and it is worse
#      than no gate because it reports a verdict it did not earn.
#
# So: default branch HEAD, check runs for that sha, nothing inferred.
#
# ============================================================================
# FOUR STATES, NOT TWO. UNGATED IS THE ONE THAT MATTERS.
# ============================================================================
#
# Measured 2026-08-07 -- 12 projects carry a `bashified` branch and only
# THREE have any CI at all on main:
#
#     realisateur     success,success
#     vim-arcade      success
#     senechal        success,success
#     ecosim          NONE          scheduler       NONE
#     crt             NONE          baudin          NONE
#     bibliothecaire  NONE          gardien         NONE
#     sequestria      NONE          nine-speakers   NONE
#     groc-mangr      NONE
#
# A two-state gate is therefore unbuildable in both directions. "All projects
# must be green" blocks every cut forever, tonight and every night, and the
# first operator response would be to delete the gate. "No checks counts as
# green" is the found-nothing/nothing-is-wrong conflation that MONKEY.md 5's
# `garde` already cost this estate once.
#
#   GREEN    checks exist for HEAD and all concluded success/neutral/skipped
#   RED      any check for HEAD concluded failure/timed_out/cancelled/
#            action_required                      -> REFUSE, exit 1
#   PENDING  any check for HEAD is queued or in_progress
#                                                  -> REFUSE, exit 4
#   UNGATED  zero checks exist for HEAD -- the project has no CI
#                                                  -> ALLOW, but counted
#
# PENDING gets its own exit code because the operator's action differs and
# nothing else in the output would tell them: RED means go fix a tree,
# PENDING means come back in five minutes. Collapsing them would send someone
# hunting a break that does not exist.
#
# UNGATED never blocks, and is never silently folded into GREEN. It is
# printed, counted, and the count is the ratchet: it is the number of
# projects whose verbs ship on nobody's evidence. Driving it to zero is the
# work; hiding it would remove the reason to do that work.
#
# ============================================================================
# WHERE THE PROJECT LIST COMES FROM -- nowhere, it is handed one
# ============================================================================
#
# --manifest names the manifest cut-verb-build.sh just produced, and the gate
# checks EXACTLY the projects it names. There is no second derivation and no
# typed list, so the gate cannot disagree with the build about what is in the
# build. BUILD-DISCIPLINE's "config read from one source" applies to a
# derivation as hard as to a hostname, and VERB-DISTRIBUTION.md 5 already
# refused to retype the declaration rule into YAML for the same reason.
#
# In CI this runs AFTER assemble and BEFORE commit-and-tag, so the manifest
# already exists in the workspace and nothing has been pushed yet. One
# derivation, one gate, one artifact.
#
# ============================================================================
# BLIND
# ============================================================================
#
# An unauthenticated or unreachable `gh` cannot be allowed to read as GREEN,
# for exactly the reason build-verbs.yml already asserts its PAT before doing
# anything: a credential-limited read is short BY CONSTRUCTION and looks
# perfectly healthy. Exit 3, never 0.
#
# ============================================================================
# EXIT CODES
#   0  every gated project is GREEN -- the build may be cut
#   1  REFUSE: at least one project's default branch is RED
#   2  usage error (cli-guard)
#   3  BLIND: could not ask GitHub. This is not "green".
#   4  REFUSE: at least one project's checks are still running
# ============================================================================
set -uo pipefail

CLI_NAME='release-gate.sh'
CLI_SUMMARY='decide whether a verb build may be cut, from the CI state of the exact commits it ships'
CLI_USAGE='  release-gate.sh --manifest <file>   gate the projects that manifest names
  release-gate.sh --projects "a b c"  gate a named list (for operators)'
CLI_FLAGS='--manifest --projects --owner'
CLI_POSITIONAL=any   # flag VALUES read as positionals to cli-guard
CLI_EXITS='  0  every gated project is GREEN -- the build may be cut
  1  REFUSE: a project'"'"'s default branch is RED
  3  BLIND: could not ask GitHub. This is not "green".
  4  REFUSE: a project'"'"'s checks are still running'
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

OWNER="${RELEASE_GATE_OWNER:-hf7y}"
MANIFEST=''
PROJECTS=''
GH="${RELEASE_GATE_GH:-gh}"

while [ $# -gt 0 ]; do
  case "$1" in
    --manifest) MANIFEST="${2:?--manifest needs a file}"; shift ;;
    --projects) PROJECTS="${2:?--projects needs a list}"; shift ;;
    --owner)    OWNER="${2:?--owner needs a value}"; shift ;;
    *) printf '%s: unknown argument: %s\n' "$CLI_NAME" "$1" >&2; exit 2 ;;
  esac
  shift
done

if [ -z "$MANIFEST" ] && [ -z "$PROJECTS" ]; then
  printf '%s: need --manifest <file> or --projects "a b c"\n' "$CLI_NAME" >&2
  exit 2
fi

# The project list, DERIVED from the manifest the build just made. Column 1,
# deduplicated, comment rows dropped.
if [ -n "$MANIFEST" ]; then
  [ -f "$MANIFEST" ] || { printf '%s: no such manifest: %s\n' "$CLI_NAME" "$MANIFEST" >&2; exit 2; }
  PROJECTS="$(grep -v '^#' "$MANIFEST" | cut -f1 | grep -v '^$' | sort -u | tr '\n' ' ')"
  [ -n "${PROJECTS// /}" ] || {
    # An empty manifest reaching the gate means the build produced nothing
    # and something upstream should already have refused. Saying "green" here
    # would rubber-stamp it.
    printf '%s: BLIND -- the manifest names no projects. Nothing was gated.\n' "$CLI_NAME" >&2
    exit 3
  }
fi

green=0; red=0; pending=0; ungated=0; blind=0
red_names=''; pending_names=''; ungated_names=''

printf '== release-gate: %s ==\n\n' "$OWNER"
printf '  %-20s %-9s %-8s %s\n' PROJECT HEAD STATE CHECKS
printf '  %-20s %-9s %-8s %s\n' -------- ---- ----- ------

for p in $PROJECTS; do
  # The default branch is asked for, never assumed to be `main`: a project
  # whose default is something else would otherwise be silently UNGATED.
  meta="$("$GH" api "repos/$OWNER/$p" --jq '.default_branch' 2>/dev/null)"
  if [ -z "$meta" ]; then
    printf '  %-20s %-9s %-8s %s\n' "$p" '?' 'BLIND' 'could not read the repository'
    blind=$((blind+1)); continue
  fi
  sha="$("$GH" api "repos/$OWNER/$p/commits/$meta" --jq '.sha' 2>/dev/null)"
  if [ -z "$sha" ]; then
    printf '  %-20s %-9s %-8s %s\n' "$p" '?' 'BLIND' "could not read $meta HEAD"
    blind=$((blind+1)); continue
  fi

  # Conclusions for THIS sha only. A run against any other commit is not
  # evidence about this one and is not returned here.
  concl="$("$GH" api "repos/$OWNER/$p/commits/$sha/check-runs" \
            --jq '[.check_runs[] | (.conclusion // ("!" + .status))] | join(",")' 2>/dev/null)"
  rcgh=$?
  if [ "$rcgh" != 0 ]; then
    printf '  %-20s %-9.7s %-8s %s\n' "$p" "$sha" 'BLIND' 'check-runs query failed'
    blind=$((blind+1)); continue
  fi

  if [ -z "$concl" ]; then
    printf '  %-20s %-9.7s %-8s %s\n' "$p" "$sha" 'UNGATED' 'no CI on this project'
    ungated=$((ungated+1)); ungated_names="$ungated_names $p"; continue
  fi

  # A status prefixed `!` is a run that has not concluded. Unknown is not
  # green; it is a reason to come back.
  state=GREEN
  case ",$concl," in
    *,'!'*) state=PENDING ;;
  esac
  case ",$concl," in
    *,failure,*|*,timed_out,*|*,cancelled,*|*,action_required,*|*,startup_failure,*|*,stale,*) state=RED ;;
  esac

  printf '  %-20s %-9.7s %-8s %s\n' "$p" "$sha" "$state" "$concl"
  case "$state" in
    GREEN)   green=$((green+1)) ;;
    RED)     red=$((red+1));         red_names="$red_names $p" ;;
    PENDING) pending=$((pending+1)); pending_names="$pending_names $p" ;;
  esac
done

echo
printf '  %d green, %d red, %d pending, %d ungated, %d blind\n' \
       "$green" "$red" "$pending" "$ungated" "$blind"

if [ "$blind" -gt 0 ]; then
  echo
  echo "BLIND: $blind project(s) could not be read. This is NOT a green result --" >&2
  echo "  a credential-limited read is short by construction and looks healthy." >&2
  exit 3
fi

if [ "$red" -gt 0 ]; then
  echo
  echo "RELEASE BLOCKED: the default branch is RED on:$red_names" >&2
  echo "  Tonight's build was NOT cut, and the fleet stays on the last good build." >&2
  echo "  That is the intended coupling: a release channel that ships from a broken" >&2
  echo "  tree is a faster way to distribute the break." >&2
  echo "  Fix the tree, or dispatch build-verbs manually once it is green." >&2
  exit 1
fi

if [ "$pending" -gt 0 ]; then
  echo
  echo "RELEASE DEFERRED: checks are still running on:$pending_names" >&2
  echo "  Nothing is broken -- the evidence is not in yet. Re-run when it is." >&2
  echo "  Reported separately from RED on purpose: waiting and fixing are" >&2
  echo "  different actions and the output must not send you to the wrong one." >&2
  exit 4
fi

if [ "$ungated" -gt 0 ]; then
  echo
  echo "  NOTE: $ungated project(s) ship with NO CI evidence at all:$ungated_names"
  echo "  These do not block the cut -- refusing on them would block every cut,"
  echo "  tonight and every night, and the first response would be to delete this"
  echo "  gate. They are counted because the count IS the work: it is the number"
  echo "  of projects whose verbs reach every agent on nobody's evidence."
fi

echo
echo "GATE OPEN: every project with CI is green at the commit it ships."
exit 0
