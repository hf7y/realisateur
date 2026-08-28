#!/usr/bin/env bash
# lib/answered.sh -- the feeder for bin/lib/answered.jq, where the predicate
# lives and only lives. Two entry points, one gh call each: a bulk-fed
# issue_answered_json() for a caller already holding many issues (#573), and
# issue_answered() for a caller with just one number.
ANSWERED_STAMP_ERA="${ANSWERED_STAMP_ERA:-2026-08-14}"
ANSWERED_OWNER="${ANSWERED_OWNER:-hf7y}"
ANSWERED_JQ_FILE="${ANSWERED_JQ_FILE:-$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/answered.jq}"

# Set by issue_answered()/issue_answered_json() so a caller can SAY why --
# throwing away the reason the predicate already computed would rebuild it.
ANSWERED_WHY=''
ANSWERED_AT=''
# The ANSWERED-BY target this issue's body names, or empty. Set by both
# entry points; only issue_answered() has the network to follow it.
ANSWERED_BY=''

# issue_answered_json <one issue's {number,labels,comments[,body]}> -- no gh
# call, so an ANSWERED-BY pointer is surfaced in $ANSWERED_BY but never
# followed here -- following it is a second fetch, which belongs to the
# caller that has a `gh` (issue_answered(), below).
#   0  answered      a human answered, or `answered` says one did elsewhere
#   1  unanswered    nothing here that could be a human's
#   2  uncounted     something could be, and cannot be counted -- NOT a silence
#   6  BLIND         could not look. Never folded into any of the above.
issue_answered_json() {
  local issue_json="$1" out
  ANSWERED_WHY=''; ANSWERED_AT=''; ANSWERED_BY=''
  [ -r "$ANSWERED_JQ_FILE" ] || {
    ANSWERED_WHY="BLIND -- the predicate is not readable at $ANSWERED_JQ_FILE"
    return 6
  }
  out="$(printf '[%s]' "$issue_json" | jq -r --arg owner "$ANSWERED_OWNER" --arg era "$ANSWERED_STAMP_ERA" \
         "$(cat "$ANSWERED_JQ_FILE")"'.[] | verdict | "\(.verdict)\t\(.at // "")\t\(.answered_by // "")\t\(.why)"' 2>/dev/null)" || {
    ANSWERED_WHY='BLIND -- the predicate could not read that issue'
    return 6
  }
  ANSWERED_AT="$(printf '%s' "$out" | cut -f2)"
  ANSWERED_BY="$(printf '%s' "$out" | cut -f3)"
  ANSWERED_WHY="$(printf '%s' "$out" | cut -f4-)"
  case "$(printf '%s' "$out" | cut -f1)" in
    answered)   return 0 ;;
    unanswered) return 1 ;;
    uncounted)  return 2 ;;
    # A verdict this does not recognise is a misread, and a misread must never
    # clear a label.
    *) ANSWERED_WHY='BLIND -- the predicate returned no verdict'; return 6 ;;
  esac
}

# issue_answered <owner/repo> <number> -- fetches, then defers to the above.
# `issue view`, not `api .../comments`: the REST comment list carries no
# labels, and without labels the `answered` override cannot be seen here.
#
# ANSWERED-BY, ONE HOP (#568): if the local verdict is not already
# `answered` and the body names a target, fetch THAT issue's own local
# verdict -- via issue_answered_json, never issue_answered -- and adopt it if
# it is `answered`. Reading the target through the *_json entry point rather
# than recursing here is what keeps this to one hop: the target's own
# ANSWERED-BY, if it has one, is never read, so a cycle (A -> B -> A) cannot
# hang the predicate. A target that cannot be read (BLIND) or is itself
# unanswered leaves this issue's original verdict standing.
issue_answered() {
  local repo="$1" num="$2" json rc target t_repo t_num t_json t_rc t_why
  ANSWERED_WHY=''; ANSWERED_AT=''; ANSWERED_BY=''
  [ -r "$ANSWERED_JQ_FILE" ] || {
    ANSWERED_WHY="BLIND -- the predicate is not readable at $ANSWERED_JQ_FILE"
    return 6
  }
  json="$(gh issue view "$num" --repo "$repo" --json number,labels,comments,body 2>/dev/null)" || {
    ANSWERED_WHY="BLIND -- could not read $repo#$num"
    return 6
  }
  issue_answered_json "$json"; rc=$?
  target="$ANSWERED_BY"

  if [ "$rc" -ne 0 ] && [ -n "$target" ]; then
    t_repo="${target%#*}"
    t_num="${target##*#}"
    if t_json="$(gh issue view "$t_num" --repo "$t_repo" --json number,labels,comments,body 2>/dev/null)"; then
      issue_answered_json "$t_json"; t_rc=$?
      if [ "$t_rc" -eq 0 ]; then
        t_why="$ANSWERED_WHY"
        ANSWERED_WHY="ANSWERED-BY $target, itself answered -- $t_why"
        ANSWERED_BY="$target"
        return 0
      fi
    fi
    # The hop did not confirm an answer -- restore this issue's own verdict
    # rather than leave the target's WHY/AT sitting under this issue's number.
    issue_answered_json "$json"; rc=$?
  fi
  return "$rc"
}
