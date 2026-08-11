#!/usr/bin/env bash
# claim-drift.sh -- has a pull request grown since it was presented as done?
#
# GUARD: has a pull request grown since it was presented as done?
# RUNNER: operator -- needs a GitHub credential against live PRs; run in a review pass
# GUARD-TEST: bin/tests/claim-drift.test.sh
# GATE: none -- every path calls `gh` against a live PR; the fixture is in its own suite
# VERIFIED: 2026-08-07 via bash bin/claim-drift.sh --all (1 unclaimed draft, 0 drifted)
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
CLI_FLAGS='--all --strict --repo --convention'
CLI_POSITIONAL=any
CLI_EXITS='  0  audited; no --strict, or --strict and nothing drifted
  1  --strict and at least one PR has grown since it was claimed done
  6  BLIND -- the tracker could not be read'
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/cli-guard.sh"
cli_guard "$@"

# THE CANONICAL TEXT. One place, printed on demand.
#
# Why a flag and not a paragraph in a brief: on 2026-08-07 this convention was
# retyped from memory into eight agent briefs by one coordinator, who then
# invented a SECOND, conflicting meaning ("draft = needs a decision") in a
# throwaway answer an hour later. Nothing was wrong with any single retyping;
# the defect is that retyping was the distribution mechanism. A spawner can now
# reference this instead of recalling it, and the guard below enforces the same
# text it prints -- so a brief that paraphrases it wrongly produces a red check
# rather than silent drift.
print_convention() {
  cat <<'CONV'
PULL REQUEST CONVENTION -- canonical. Reference this; do not paraphrase it.

  COMPLETION axis (mechanized here, enforced by this script):
    a DRAFT pull request claims nothing        -> it can never drift
    marking it READY is the commitment point   -> that instant anchors the claim
    a PR OPENED non-draft claims done at its opening
    Growth after "done" is legal. Growth while STILL claiming done is not:
    convert back to draft while you work, mark ready again when finished.

  ATTENTION axis (decided 2026-08-08; enforced here and by branch protection):
    NO decision -> ready + `gh pr merge --auto --squash`. It lands unattended
                   when the required checks pass. Nobody reads it. This is the
                   default and should be the common case.
    A decision  -> ready, auto-merge OFF, and the FIRST non-empty line is:
                     DECISION: <the one call the human must make>
                   Optionally NO-DECISION: <why> when auto-merge is unavailable
                   but no judgement is needed.
    A DRAFT is exempt from both: it claims nothing, so it asks nothing.

  Why PRs at all, when nobody reads most of them: the PR is what runs CI
  against the MERGE RESULT. Four PRs on 2026-08-07 merged with zero textual
  conflicts and broke each other's repository-wide invariants; `main` went red
  twice. Dropping the PR would drop that gate. What was removed is the WAITING,
  not the gate.

  THE MECHANISM, live on hf7y/realisateur since 2026-08-08 -- cited so this
  text cannot quietly become aspirational:
    allow_auto_merge=true, delete_branch_on_merge=true
    branch protection on main: required checks `suites` and `markdown-cost`
    strict=false          -- deliberately NOT "require branches up to date":
                             that forces every open PR to re-sync whenever main
                             moves, the loop that broke #95/#96/#98 repeatedly.
    enforce_admins=true    -- flipped from false on 2026-08-11: twelve
                             self-dev accounts run tools this repo ships, so a
                             bad merge here breaks all of them at once, and
                             `--admin` routing around a wedged check (done
                             once, on Zach's explicit authorization, for #123)
                             is not a standing practice. A required check that
                             an admin can route around on a bad day is not a
                             gate, it is a suggestion.
    no required reviews   -- the point. Green is sufficient; nobody has to look.
  Before this, main was UNPROTECTED and allow_auto_merge was false: every check
  was voluntary, which is how #102 was merged red.

  Why the first line: the stated failure mode is "if it's a PR not a draft,
  I'm just going to merge it without reading". A ready PR whose ask is buried
  in prose cannot be triaged without opening it.

  OVERCAUTIOUS (mechanized here, 2026-08-10, non-blocking): the mirror
  failure -- a DECISION line on a diff that touched no existing file's
  behavior (every changed file is new, or a shrinking .md edit). Before
  reaching for DECISION, ask: does this diff change what any ALREADY-RUNNING
  thing does? If every file is new or a doc trim, it probably doesn't, and
  the default (no decision, auto-merge) is very likely the right one.

  THE CHEAPER QUESTION, AND THE ONE THE SCRIPT CANNOT ASK FOR YOU. Same day,
  same repository: PR #124 (this very check) STILL got a DECISION line, and
  the mechanized OVERCAUTIOUS test above correctly stayed silent about it --
  #124 edits an existing file, so the diff-shape heuristic has nothing to
  say. The actual defect was one line up the stack: the user had ALREADY,
  in plain language earlier in the same conversation, asked for exactly
  this mechanism, and it had ALREADY been verified doing exactly that
  (tests passing, dogfooded live against the real incident). Nothing was
  open. "Did the user already explicitly ask for this, and is there
  evidence it does what was asked" is not readable from a diff -- it is
  readable from the conversation, by the one party who was in it. No
  amount of diff-shape cleverness closes that gap; a script that tried
  would be guessing at intent from the wrong side of the wall. Before
  writing DECISION, an agent must ask that cheaper question itself, in
  the room, before the diff-shape heuristic ever gets a turn.

  The classification is the AUTHOR's, declared. No guard can read intent.
  This script does NOT re-implement the green gate -- branch protection owns
  that. It only asks whether a PR that wants attention says what it wants,
  and now also whether a PR that wants attention needed to ask at all --
  and even that second half only catches ONE shape of "didn't need to ask".
CONV
}

REPO=''
ALL=0
STRICT=0
PRS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --convention) print_convention; exit 0 ;;
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

drifted=0; current=0; unclaimed=0; settled=0; blind=0; undecided=0; overcautious=0

# first non-empty line, stripped of markdown furniture, classified.
# Returns 0 if the body declares itself, 1 if not.
#
# The word must OPEN the line. Matching it anywhere would let any PR that
# merely mentions the convention exempt itself -- the false positive
# guard-estate's check E hit and had to fix within ten minutes of being written.
declares_itself() {
  local first stripped
  first="$(printf '%s\n' "$1" | grep -m1 -v '^[[:space:]]*$')" || return 1
  stripped="$(printf '%s' "$first" | sed -e 's/^[[:space:]#>*_-]*//')"
  case "$stripped" in
    [Dd][Ee][Cc][Ii][Ss][Ii][Oo][Nn]:*|[Nn][Oo]-[Dd][Ee][Cc][Ii][Ss][Ii][Oo][Nn]:*) return 0 ;;
  esac
  return 1
}

# decision | no-decision | none -- which of the two declares_itself() accepts
# this body opened with. Kept separate from declares_itself() because the
# OVERCAUTIOUS check below only cares about the DECISION case: a NO-DECISION
# line already says "no judgement needed" and asks for nothing.
declaration_kind() {
  local first stripped
  first="$(printf '%s\n' "$1" | grep -m1 -v '^[[:space:]]*$')" || { echo none; return; }
  stripped="$(printf '%s' "$first" | sed -e 's/^[[:space:]#>*_-]*//')"
  case "$stripped" in
    [Nn][Oo]-[Dd][Ee][Cc][Ii][Ss][Ii][Oo][Nn]:*) echo no-decision ;;
    [Dd][Ee][Cc][Ii][Ss][Ii][Oo][Nn]:*)          echo decision ;;
    *)                                            echo none ;;
  esac
}

# THE OVERCAUTIOUS CHECK. UNDECIDED (below) catches a ready PR that asks for
# nothing while silently wanting attention. This is the mirror failure: a
# ready PR that raises a DECISION nobody needs to make. Both are the same
# defect from opposite sides -- the classification not matching what the
# diff actually needs -- and 2026-08-10 supplied a live instance: a
# read-only survey script plus a prose-to-vault move (already sanctioned by
# PROSE-REAPING.md) got a `DECISION:` line and blocked auto-merge for a
# change that altered no running account's behavior at all.
#
# "No guard can read intent" (this file's own convention text) still holds --
# this does not decide whether a decision is warranted. It flags the one
# shape that is mechanically checkable without reading intent: EVERY changed
# file is either brand new, or an existing `.md` file whose diff removes at
# least as many lines as it adds (a prose trim/reap, not new prose). A diff
# shaped entirely like that cannot have changed any EXISTING script's or
# config's behavior, because nothing existing was touched except to shrink
# documentation. That is a necessary condition for "no decision was really
# needed", not a sufficient one -- so this prints a FLAG, never gates
# --strict, and never overrides the author's own classification.
is_additive_only_diff() {
  local file='' is_new=0 adds=0 dels=0 saw_file=0
  judge() {
    [ "$saw_file" -eq 0 ] && return 0
    [ "$is_new" -eq 1 ] && return 0
    case "$file" in
      *.md) [ "$dels" -ge "$adds" ] && return 0 ;;
    esac
    return 1
  }
  while IFS= read -r line; do
    case "$line" in
      'diff --git '*)
        if [ "$saw_file" -eq 1 ]; then judge || return 1; fi
        file="${line#diff --git a/}"; file="${file%% b/*}"
        is_new=0; adds=0; dels=0; saw_file=1
        ;;
      'new file mode'*) is_new=1 ;;
      '+++'*) : ;;
      '---'*) : ;;
      '+'*) adds=$((adds+1)) ;;
      '-'*) dels=$((dels+1)) ;;
    esac
  done <<<"$1"
  [ "$saw_file" -eq 1 ] && { judge || return 1; }
  return 0
}

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
        --json number,title,url,state,isDraft,createdAt,headRefOid,commits,body,autoMergeRequest 2>/dev/null)" || pr=''
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

  # THE ATTENTION AXIS. A ready PR either lands unattended or asks for a call.
  # Auto-merge IS the no-decision declaration -- it is a live GitHub state, not
  # a sentence someone wrote, so it cannot be stale. Only a PR that is ready,
  # not auto-merging, and silent about why is asking for attention without
  # saying what for.
  automerge="$(printf '%s' "$pr" | jq -r '.autoMergeRequest // "" | if . == "" then "" else "on" end')"
  body="$(printf '%s' "$pr" | jq -r '.body // ""')"
  if [ "$automerge" != on ] && ! declares_itself "$body"; then
    undecided=$((undecided+1))
    printf '  #%-4s UNDECIDED ready, not auto-merging, and its first line does not say why.\n' "$n"
    printf '                  Either `gh pr merge %s --auto --squash` (no decision needed),\n' "$n"
    printf '                  or open the body with `DECISION: <the call>`.\n'
    printf '                  See: claim-drift.sh --convention\n'
  fi

  # THE MIRROR CHECK: a DECISION nobody needs to make. See is_additive_only_diff
  # above for exactly what "nobody needs to make" means here and why it stops
  # at a FLAG rather than a verdict.
  if [ "$(declaration_kind "$body")" = decision ]; then
    prdiff="$(gh pr diff "$n" --repo "$REPO" 2>/dev/null)" || prdiff=''
    if [ -n "$prdiff" ] && is_additive_only_diff "$prdiff"; then
      overcautious=$((overcautious+1))
      printf '  #%-4s OVERCAUTIOUS DECISION line, but every changed file is new or a\n' "$n"
      printf '                  shrinking .md edit -- nothing existing was touched. Re-check\n'
      printf '                  whether this really needs the human'"'"'s call, or downgrade to\n'
      printf '                  plain ready + auto-merge (no decision) or a NO-DECISION line.\n'
      printf '                  See: claim-drift.sh --convention\n'
    fi
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

printf '\n%d drifted, %d undecided, %d overcautious, %d current, %d unclaimed, %d settled, %d blind.\n' \
  "$drifted" "$undecided" "$overcautious" "$current" "$unclaimed" "$settled" "$blind"

if [ "$STRICT" -eq 1 ]; then
  [ "$blind" -gt 0 ] && exit 6
  # overcautious never gates: it's a suggestion to reduce friction, and a
  # mechanism that BLOCKS on "you asked for review when you maybe didn't need
  # to" would just add the friction it exists to catch, one level up.
  # Both are findings, so both must move the exit code -- `guard-estate.test.sh`
  # asserts exit-code-tracks-findings over the whole population, and a verdict
  # that prints but does not gate is the `silence-audit` defect (74 FLAGs,
  # exit 0) this estate spent 2026-08-07 removing.
  [ "$drifted" -gt 0 ] || [ "$undecided" -gt 0 ] && exit 1
fi
exit 0
