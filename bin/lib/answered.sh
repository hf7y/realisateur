#!/usr/bin/env bash
# lib/answered.sh -- the ONE-ISSUE feeder for bin/lib/answered.jq, which is
# where the predicate itself lives and is the only place it lives.
#
# This file used to carry a second copy of that predicate as an inline `--jq`
# expression, and bin/decision-rot.sh carried a third as DECISION_ROT_JQ. The
# three disagreed; see the header of answered.jq for the four axes and the cost.
#
# WHY THE PREDICATE IS jq AND NOT BASH: `decision-rot` reads 26 repos with ONE
# bulk `gh issue list --json ...,comments` each. If it called this function it
# would spend one API call per issue instead -- hundreds. So the shared thing
# is the text, and each caller feeds it the shape it already has.
ANSWERED_STAMP_ERA="${ANSWERED_STAMP_ERA:-2026-08-14}"
# Agents post as this account and nothing else can, so a comment from any other
# human login needs no stamp era to prove it is a person's. See answered.jq.
ANSWERED_OWNER="${ANSWERED_OWNER:-hf7y}"
ANSWERED_JQ_FILE="${ANSWERED_JQ_FILE:-$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/answered.jq}"

# Set by issue_answered() for a caller that wants to SAY why. The whole defect
# this file is being changed for is a verdict nobody could print, so throwing
# away the reason the predicate already computed would rebuild it.
ANSWERED_WHY=''
ANSWERED_AT=''

# issue_answered <owner/repo> <number>
#   0  answered      a human answered, or `answered` says one did elsewhere
#   1  unanswered    nothing here that could be a human's
#   2  uncounted     something could be, and cannot be counted -- NOT a silence
#   6  BLIND         could not look. Never folded into any of the above.
issue_answered() {
  local repo="$1" num="$2" json out
  ANSWERED_WHY=''; ANSWERED_AT=''
  [ -r "$ANSWERED_JQ_FILE" ] || {
    ANSWERED_WHY="BLIND -- the predicate is not readable at $ANSWERED_JQ_FILE"
    return 6
  }
  # `issue view`, not `api .../comments`: the REST comment list carries no
  # labels, and without labels the `answered` override cannot be seen here --
  # which is the half of the mechanism that closes hf7y/realisateur#568.
  json="$(gh issue view "$num" --repo "$repo" --json number,labels,comments 2>/dev/null)" || {
    ANSWERED_WHY="BLIND -- could not read $repo#$num"
    return 6
  }
  out="$(printf '[%s]' "$json" | jq -r --arg owner "$ANSWERED_OWNER" --arg era "$ANSWERED_STAMP_ERA" \
         "$(cat "$ANSWERED_JQ_FILE")"'.[] | verdict | "\(.verdict)\t\(.at // "")\t\(.why)"' 2>/dev/null)" || {
    ANSWERED_WHY='BLIND -- the predicate could not read that issue'
    return 6
  }
  ANSWERED_AT="$(printf '%s' "$out" | cut -f2)"
  ANSWERED_WHY="$(printf '%s' "$out" | cut -f3-)"
  case "$(printf '%s' "$out" | cut -f1)" in
    answered)   return 0 ;;
    unanswered) return 1 ;;
    uncounted)  return 2 ;;
    # A verdict this does not recognise is a misread, and a misread must never
    # clear a label.
    *) ANSWERED_WHY='BLIND -- the predicate returned no verdict'; return 6 ;;
  esac
}
