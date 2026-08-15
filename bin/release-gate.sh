#!/usr/bin/env bash
# release-gate.sh -- decide whether tonight's verb build is allowed to be cut.
#
# RUNNER: provision/verbs-meta/build-verbs.yml bin/tests/release-gate.test.sh
# GUARD-TEST: bin/tests/release-gate.test.sh
# GATE: none -- calls `gh` against live default branches; the fixture is in its own suite
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
# So: default branch HEAD, CI evidence for that sha, nothing inferred.
#
# ============================================================================
# WHICH ENDPOINT THE EVIDENCE COMES FROM, AND WHY IT IS NOT THE OBVIOUS ONE
# ============================================================================
#
# This file used to ask ONE endpoint:
#
#     GET /repos/{owner}/{repo}/commits/{sha}/check-runs
#
# and on the first real gated cut (2026-08-07) it returned
# `check-runs query failed` for ELEVEN of twelve projects. The gate reported
#
#     0 green, 0 red, 0 pending, 1 ungated, 11 blind
#
# on a `main` that was green. It read as a public-vs-private partition, and it
# was not: the one project that came back was simply the only PUBLIC one, so it
# was readable without the permission the others needed.
#
# THE CAUSE. `/check-runs` requires the fine-grained permission **Checks:
# Read**. `VERBS_READ_TOKEN` holds "Read access to actions, code, commit
# statuses, and metadata" -- and Checks is not among them. Worse, when Zach
# went to grant it, THERE IS NO "Checks" CATEGORY OFFERED on that token's
# settings page. So the permission is not merely unset; it is not available to
# set, and waiting for it is waiting for something that will not arrive.
#
# THE FIX USES WHAT THE TOKEN ALREADY HOLDS. The same evidence is readable
# through two endpoints this token can already reach, and the gate now asks
# BOTH:
#
#   GET /repos/{o}/{r}/actions/runs?head_sha=<sha>   (needs `actions: read`)
#       -> .workflow_runs[] | status, conclusion
#   GET /repos/{o}/{r}/commits/{sha}/status          (needs `statuses: read`)
#       -> .total_count, .statuses[].state
#
# WHY BOTH, rather than quietly covering one and calling the other absent.
# They are DIFFERENT SURFACES carrying different producers' results:
#
#   GitHub Actions  creates workflow runs AND check runs. Visible in the
#                   first endpoint. This is all of this estate's CI today.
#   External CI     (Travis, CircleCI, a webhook, a bot) posts COMMIT
#                   STATUSES. Visible only in the second.
#
# Reading only Actions would grade a project whose CI is external as UNGATED
# -- "no evidence" when evidence exists and might be RED. That is a false
# absence, and a false absence here ALLOWS THE CUT. Reading only statuses
# would miss every project in this org. So: both, unioned.
#
# THE GAP THIS LEAVES, named rather than hidden: a GitHub App that creates
# CHECK RUNS but neither a workflow run nor a commit status is invisible to
# both endpoints, and such a project grades UNGATED. Nothing in this org does
# that today (probed below), and UNGATED is counted and printed rather than
# folded into GREEN, so the blind spot shows up in the ratchet rather than
# passing as a green. If a Checks-reading credential ever becomes available,
# adding it as a third surface is the fix; widening the other two is not.
#
# VERIFIED EQUIVALENT, 2026-08-07, six projects, all three endpoints at the
# same default-branch HEAD -- the new pair reproduces the old endpoint exactly,
# including on the projects that have no CI at all:
#
#   project         actions/runs      commits/status   check-runs (old)
#   --------------  ----------------  ---------------  ----------------
#   senechal        success,success   0 statuses       success,success
#   vim-arcade      success           0 statuses       success
#   scheduler       (none)            0 statuses       (none)
#   ecosim          (none)            0 statuses       (none)
#   crt             (none)            0 statuses       (none)
#   bibliothecaire  (none)            0 statuses       (none)
#
# ============================================================================
# THE `state: "pending"` TRAP IN THE COMBINED STATUS ENDPOINT
# ============================================================================
#
# `/commits/{sha}/status` returns a rolled-up `.state` field, and reaching for
# it is the obvious thing to do. It is wrong, and it fails in the direction
# that stops every release:
#
#   $ gh api repos/hf7y/realisateur/commits/$SHA/status \
#       --jq '{state, total_count}'
#   {"state":"pending","total_count":0}          # verified 2026-08-07
#
# A commit with NO statuses at all reports `state: "pending"` -- not "success",
# not empty. Every project in this org has zero commit statuses, so a gate
# keyed on `.state` would report PENDING for all twelve, every night, forever,
# and defer every cut. So PRESENCE is decided by `.total_count`, never by
# `.state`, and `.state` is not read at all. bin/tests/release-gate.test.sh
# pins this with a fixture that returns exactly the shape above.
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
#   GREEN    evidence exists for HEAD and all of it concluded success/
#            neutral/skipped
#   RED      any evidence for HEAD concluded failure/timed_out/cancelled/
#            action_required/error                 -> REFUSE, exit 1
#   PENDING  any evidence for HEAD is queued or in_progress
#                                                  -> REFUSE, exit 4
#   UNGATED  BOTH surfaces answered and neither has anything for HEAD --
#            the project has no CI                 -> ALLOW, but counted
#   BLIND    a surface could not be asked at all   -> REFUSE, exit 3
#
# UNGATED and BLIND are deliberately not the same state, and the difference is
# the whole lesson of 2026-08-07: "both endpoints answered, there is nothing
# there" ALLOWS the cut, while "an endpoint refused to answer" must not. A
# design that collapsed them would have turned that night's permission failure
# into a silent GREEN across eleven projects instead of a loud refusal.
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

  # ------------------------------------------------------------------------
  # SURFACE 1: GitHub Actions workflow runs, for THIS sha only. A run against
  # any other commit is not evidence about this one, and `?head_sha=` is what
  # keeps it that way -- the rejected alternative 2 above is precisely what
  # dropping that filter would produce.
  #
  # Workflow-run level, not job level: a run's `.conclusion` already
  # aggregates its jobs, so a failed job is a failed run. One row per
  # workflow instead of one per job, carrying the same verdict.
  # ------------------------------------------------------------------------
  runs="$("$GH" api "repos/$OWNER/$p/actions/runs?head_sha=$sha&per_page=100" \
            --jq '[.workflow_runs[] | (.conclusion // ("!" + .status))] | join(",")' 2>/dev/null)"
  rc_runs=$?

  # ------------------------------------------------------------------------
  # SURFACE 2: commit statuses, where external CI reports.
  #
  # `.total_count` decides PRESENCE. `.state` is NEVER read -- it returns
  # "pending" for a commit with zero statuses, which is every commit in this
  # org, and a gate keyed on it defers every cut forever. See the header.
  # `pending` is mapped into the same `!`-prefixed vocabulary the Actions
  # surface uses so there is ONE state machine below, not two.
  # ------------------------------------------------------------------------
  stat="$("$GH" api "repos/$OWNER/$p/commits/$sha/status" \
            --jq 'if (.total_count // 0) == 0 then ""
                  else [.statuses[] | (if .state == "pending" then "!pending" else .state end)] | join(",")
                  end' 2>/dev/null)"
  rc_stat=$?

  # A QUERY THAT FAILED IS NOT A QUERY THAT RETURNED NOTHING. Tonight's bug
  # presented as BLIND, which was honest and correct; collapsing "could not
  # ask" into "nothing found" would have turned it into a silent GREEN. The
  # surface that failed is named, because "which permission is missing" is
  # the only question worth asking when this fires.
  if [ "$rc_runs" != 0 ] || [ "$rc_stat" != 0 ]; then
    failed_surface=''
    [ "$rc_runs"  != 0 ] && failed_surface="actions/runs (needs actions:read)"
    [ "$rc_stat"  != 0 ] && failed_surface="${failed_surface:+$failed_surface + }commits/status (needs statuses:read)"
    printf '  %-20s %-9.7s %-8s %s\n' "$p" "$sha" 'BLIND' "query failed: $failed_surface"
    blind=$((blind+1)); continue
  fi

  # The union. Both surfaces answered; either may legitimately be empty.
  concl="$runs"
  [ -n "$stat" ] && concl="${concl:+$concl,}$stat"

  # ZERO EVIDENCE IS UNGATED, NEVER GREEN. Both endpoints answered and
  # neither had anything to say about this sha, so nothing tested it. This is
  # the direction that ALLOWS the cut, which is exactly why it is counted and
  # printed rather than folded into the green tally.
  if [ -z "$concl" ]; then
    printf '  %-20s %-9.7s %-8s %s\n' "$p" "$sha" 'UNGATED' 'no workflow run and no commit status for this sha'
    ungated=$((ungated+1)); ungated_names="$ungated_names $p"; continue
  fi

  # A conclusion prefixed `!` is a run that has not concluded. Unknown is not
  # green; it is a reason to come back.
  state=GREEN
  case ",$concl," in
    *,'!'*) state=PENDING ;;
  esac
  # `error` is here for the statuses surface: it is the commit-status
  # vocabulary's word for a failed check, and omitting it would grade an
  # errored external build GREEN.
  case ",$concl," in
    *,failure,*|*,timed_out,*|*,cancelled,*|*,action_required,*|*,startup_failure,*|*,stale,*|*,error,*) state=RED ;;
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
