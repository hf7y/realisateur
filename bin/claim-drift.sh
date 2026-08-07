#!/usr/bin/env bash
# claim-drift.sh -- has a pull request grown since it was presented as done?
#
# THE FAILURE THIS CLOSES. An agent reported work COMPLETE and pointed at a
# pull request. The PR was not a draft. Then more commits landed on it. The
# thing reviewed -- or approved, or merely believed finished -- was not the
# thing that ended up on the branch. The completion claim was true when made
# and silently false afterwards, and NOTHING anywhere marked the moment it went
# stale. Live instance, not a hypothetical: hf7y/realisateur#98 was opened
# non-draft at 2026-08-07T21:29:10Z and took four more commits after.
#
# The repository has already tried prose for this and lost twice: a subagent
# that reported "completed" and then woke and wrote more (vim-arcade 5b5783e,
# 2026-08-04), and the recorded lesson that "the first 'completed' may not be
# the report". A rule people are supposed to remember has now failed enough
# times to count as measured.
#
# WHAT IT DELIBERATELY DOES NOT DO -- and this is the design, not a caveat.
# It does not forbid growth after "done". Addressing review feedback is
# legitimate and ordinary, and a mechanism that blocked it would be worked
# around inside a week -- which is WORSE than no mechanism, because it looks
# like protection while being routinely bypassed. It refuses nothing, blocks
# no push, and cannot deny anything: it only makes the claim DETECTABLY STALE.
# What is forbidden here is not growth. It is SILENT growth -- the claim
# standing unchallenged while the artifact moves underneath it.
#
# WHERE THE CLAIM LIVES, which is the whole trick. A completion claim written
# in prose to a human cannot be checked later by anyone. So the claim is not
# prose: it is the PR's own draft state, which GitHub already records with a
# timestamp and which nobody has to remember to write down.
#
#   a DRAFT pull request claims nothing        -> it can never drift
#   marking it READY is the commitment point   -> that instant is the anchor
#   a PR OPENED non-draft claims done at its opening
#
# That last line is the one that matters, and it is why anchoring on the
# `ready_for_review` timeline event alone is not enough: a PR opened non-draft
# never emits that event, so a check that looks only for it sees nothing on
# exactly the PRs that exhibit the problem. Measured, not assumed -- neither
# open PR in this repository on 2026-08-07 had one.
#
# WITHDRAWING AND RE-MAKING A CLAIM is therefore a first-class, one-gesture
# act with no new artifact to maintain: convert back to draft while you work
# (the flag clears -- see case D of the suite), mark ready again when you are
# done (the anchor moves to the new instant, and the PR reads CURRENT again).
# Growth stays legal. Growth while still claiming to be finished does not.
#
# HOW IT SURFACES. .github/workflows/claim-drift.yml runs this on every
# pull_request event INCLUDING ready_for_review and converted_to_draft, which
# are not in the default set. A drifted claim is a red check on the PR -- and
# because this repository has no branch protection available (private repo on
# a plan where the branch-protection and rulesets APIs both answer 403
# "Upgrade to GitHub Pro", probed 2026-08-07), a red check here blocks nothing
# at all. It is a light, which is exactly what was asked for.
#
# The CITABLE half falls out for free: for a claimed PR this prints the
# IMMUTABLE sha the claim was made about. A report that says "done, PR #98 at
# a49d0f4d" is self-falsifying -- anyone, later, by hand or by this script,
# can compare that sha to the head and see the claim has gone stale. A report
# that cites nothing immutable cannot be checked at all, which is the same
# principle as stamping a released artifact with what produced it, aimed at
# claims instead of at artifacts.
#
# NAMED FOR ITS SIBLING. deploy-drift.sh asks whether a running deployment is
# still what we merged. This asks whether a completion claim is still what is
# on the branch. Same question, same vocabulary, other end of the pipe.
#
# USAGE
#   claim-drift.sh <pr-number>...        audit the named PRs
#   claim-drift.sh --all                 audit every OPEN pull request
#   claim-drift.sh --strict ...          exit 1 on drift, 6 on BLIND
#   claim-drift.sh --repo <owner/name>   default: the checkout's own remote
#
# EXIT CODES
#   0  audited; no --strict, or --strict and nothing drifted
#   1  --strict and at least one PR has grown since it was claimed done
#   2  usage error (lib/cli-guard.sh)
#   6  BLIND -- the tracker could not be read. A domain that existed and was
#      NOT read is not a pass; 6 is the ecosystem's blind code (garde,
#      ausculte, closeout-lint) rather than a third invention.
set -uo pipefail

CLI_NAME='claim-drift.sh'
CLI_SUMMARY='has a pull request grown since it was presented as done?'
CLI_USAGE='  claim-drift.sh <pr-number>...        audit the named PRs
  claim-drift.sh --all                 audit every OPEN pull request
  claim-drift.sh --strict ...          exit 1 on drift, 6 on BLIND
  claim-drift.sh --repo <owner/name>   default: the checkout own remote'
CLI_FLAGS='--all --strict --repo'
CLI_POSITIONAL=any
CLI_EXITS='  0  audited; no --strict, or --strict and nothing drifted
  1  --strict and at least one PR has grown since it was claimed done
  6  BLIND -- the tracker could not be read'
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/cli-guard.sh"
cli_guard "$@"

REPO=''
ALL=0
STRICT=0
PRS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --repo)   REPO="${2:-}"; [ -n "$REPO" ] || cli_die '--repo needs owner/name'; shift 2 ;;
    --all)    ALL=1; shift ;;
    --strict) STRICT=1; shift ;;
    *)        case "$1" in
                ''|*[!0-9]*) cli_die "not a pull request number: $1" ;;
              esac
              PRS+=("$1"); shift ;;
  esac
done

# A run that examines nothing is not a clean run. Saying "no drift" about an
# empty set is the found-nothing / nothing-is-wrong conflation this repository
# keeps paying for, so it is a usage error rather than a green exit.
if [ "$ALL" -eq 0 ] && [ "${#PRS[@]}" -eq 0 ]; then
  cli_die 'nothing to audit: give one or more PR numbers, or --all'
fi

drifted=0; current=0; unclaimed=0; settled=0; blind=0

note_blind() { blind=$((blind+1)); printf '  #%-4s BLIND     %s\n' "$1" "$2"; }

# The two tools this reads the world with. Their absence is BLIND, not clean --
# a guard that reports success when its own instrument is missing is the
# exit-0 no-op BUILD-DISCIPLINE.md exists to prevent.
have() { command -v "$1" >/dev/null 2>&1; }

if [ -z "$REPO" ]; then
  if have gh; then
    REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" || REPO=''
  fi
fi

printf 'claim-drift: %s\n\n' "${REPO:-(unknown repo)}"

if ! have gh || ! have jq; then
  missing=''
  have gh || missing="$missing gh"
  have jq || missing="$missing jq"
  printf '  BLIND: cannot read the tracker --%s not on PATH.\n' "$missing"
  printf '         This is not "no claim has drifted". Nothing was examined.\n\n'
  [ "$STRICT" -eq 1 ] && exit 6
  exit 0
fi

if [ "$ALL" -eq 1 ]; then
  list="$(gh pr list --repo "$REPO" --state open --limit 100 --json number 2>/dev/null)" || list=''
  if [ -z "$list" ]; then
    printf '  BLIND: could not list open pull requests for %s.\n\n' "$REPO"
    [ "$STRICT" -eq 1 ] && exit 6
    exit 0
  fi
  while read -r n; do [ -n "$n" ] && PRS+=("$n"); done < <(printf '%s' "$list" | jq -r '.[].number' 2>/dev/null)
fi

for n in "${PRS[@]}"; do
  pr="$(gh pr view "$n" --repo "$REPO" \
        --json number,title,url,state,isDraft,createdAt,headRefOid,commits 2>/dev/null)" || pr=''
  if [ -z "$pr" ]; then
    note_blind "$n" "could not read the pull request."
    continue
  fi
  state="$(printf '%s' "$pr" | jq -r '.state // ""')"
  isdraft="$(printf '%s' "$pr" | jq -r '.isDraft // false')"
  created="$(printf '%s' "$pr" | jq -r '.createdAt // ""')"
  head="$(printf '%s' "$pr" | jq -r '.headRefOid // ""')"
  if [ -z "$state" ] || [ -z "$created" ]; then
    note_blind "$n" "the pull request payload was unreadable."
    continue
  fi

  # A merged or closed PR's head cannot move again, so whatever was claimed
  # about it is settled -- true or false, it is no longer going stale.
  if [ "$state" != OPEN ]; then
    settled=$((settled+1))
    printf '  #%-4s SETTLED   %s at %s -- head is immutable now.\n' "$n" "$(printf '%s' "$state" | tr 'A-Z' 'a-z')" "${head:0:8}"
    continue
  fi

  if [ "$isdraft" = true ]; then
    unclaimed=$((unclaimed+1))
    printf '  #%-4s UNCLAIMED draft -- it claims nothing, so it cannot drift.\n' "$n"
    continue
  fi

  # THE ANCHOR. Last time this PR was presented as finished.
  tl="$(gh api "repos/$REPO/issues/$n/timeline" --paginate 2>/dev/null)" || tl=''
  if [ -z "$tl" ]; then
    note_blind "$n" "could not read the pull request timeline."
    continue
  fi
  anchor="$(printf '%s' "$tl" \
    | jq -r -s 'add // [] | map(select(.event=="ready_for_review") | .created_at) | last // ""' 2>/dev/null)"
  if [ -n "$anchor" ]; then
    why="marked ready for review"
  else
    # No ready_for_review event at all: the PR was opened non-draft, and
    # opening it that way IS the claim. This branch is the incident.
    anchor="$created"
    why="opened non-draft"
  fi

  after="$(printf '%s' "$pr" | jq -r --arg a "$anchor" '[.commits[] | select(.committedDate > $a)] | length')"
  claim_sha="$(printf '%s' "$pr" | jq -r --arg a "$anchor" \
      '[.commits[] | select(.committedDate <= $a)] | last | .oid // ""')"
  [ -n "$claim_sha" ] || claim_sha='(no commit at claim time)'

  if [ "${after:-0}" -eq 0 ]; then
    current=$((current+1))
    printf '  #%-4s CURRENT   claimed %s (%s); head %s unchanged since.\n' \
      "$n" "$anchor" "$why" "${head:0:8}"
    printf '                  cite this: %s#%s at %s\n' "$REPO" "$n" "${claim_sha:0:12}"
  else
    drifted=$((drifted+1))
    printf '  #%-4s DRIFTED   claimed %s (%s)\n' "$n" "$anchor" "$why"
    printf '                  claim sha %s  ->  head %s   (%s commit(s) since)\n' \
      "${claim_sha:0:12}" "${head:0:8}" "$after"
    printf '                  FLAG: this PR was presented as done and has grown since.\n'
    printf '                  Not forbidden -- but the claim is stale. Convert it back\n'
    printf '                  to draft while you work, or mark it ready again to\n'
    printf '                  re-commit to what is now on the branch.\n'
  fi
done

printf '\n%d drifted, %d current, %d unclaimed, %d settled, %d blind.\n' \
  "$drifted" "$current" "$unclaimed" "$settled" "$blind"

if [ "$STRICT" -eq 1 ]; then
  [ "$blind" -gt 0 ] && exit 6
  [ "$drifted" -gt 0 ] && exit 1
fi
exit 0
