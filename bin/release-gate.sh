#!/usr/bin/env bash
# release-gate.sh -- decide whether tonight's verb build is allowed to be cut.
#
# RUNNER: provision/verbs-meta/build-verbs.yml bin/tests/release-gate.test.sh
# GUARD-TEST: bin/tests/release-gate.test.sh
# GATE: none -- calls `gh` against live default branches; the fixture is in its own suite
#
# Zach, 2026-08-07: a red `main` must STOP RELEASES. A release channel that
# ships from a broken tree is a faster way to distribute a break. The rollout
# that decides which repos can satisfy this at all is #285 -- 5 of 12 rostered
# repos have any CI, so most cannot yet be gated on a green default branch.
#
# GREEN = every check run attached to the EXACT CURRENT HEAD SHA of the
# project's default branch has concluded successfully. Freshness falls out of
# that with no window to tune: a successful run from three days ago is
# attached to a different sha, so the API does not return it.
#
# TRAP: do NOT re-key this on the bashified sha being cut. Probed 2026-08-07
#   across all 12 projects carrying a `bashified` branch: every one has ZERO
#   check runs there, because workflows trigger on pull_request and
#   push:[main]. A gate keyed on bashified returns "no checks" for every
#   project every night -- an exit-0 no-op wearing a gate's name.
#
# TRAP: the gated project list is DERIVED from the manifest, never retyped,
#   so the gate cannot disagree with the build about what is in the build.
#   In CI this runs AFTER assemble and BEFORE commit-and-tag.
#
# TRAP: an unauthenticated or unreachable `gh` must never read as GREEN. A
#   credential-limited read is short BY CONSTRUCTION and looks healthy.
#
# EXIT CODES
#   0  every gated project is GREEN -- the build may be cut
#   1  REFUSE: at least one project's default branch is RED
#   2  usage error (cli-guard)
#   3  BLIND: could not ask GitHub. This is not "green".
#   4  REFUSE: at least one project's checks are still running
#
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
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
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
