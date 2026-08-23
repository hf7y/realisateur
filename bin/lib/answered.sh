#!/usr/bin/env bash
# lib/answered.sh -- has a human answered this issue? decision-rot's predicate,
# reused so `needs-human` stops claiming a decision Zach already made.
#
# One account authors every comment, so authorship cannot separate Zach from an
# agent. `gh-sign` stamps agent comments: an UNSTAMPED comment after the stamp
# went live is a human's; older is unknowable, and unknowable is not an answer.
# But Zach's answers are usually SPOKEN, and the stamp erased the agent relay
# that wrote them down -- #430 was answered four times and re-surfaced every
# one. So a stamped comment counts when it names a decider. Forgeable on
# purpose: a forged relay is typed and auditable, a lost answer leaves nothing.
ANSWERED_STAMP_ERA="${ANSWERED_STAMP_ERA:-2026-08-14}"
ANSWERED_RELAY_RE='<!--\\s*decision-by:'   # <!-- decision-by: zach 2026-08-21 -->

# issue_answered <owner/repo> <number>
#   0 answered
#   1 not answered -- no qualifying comment exists at all
#   2 BLIND -- could not read the comments
#   3 DISCARDED -- a qualifying comment exists but predates ANSWERED_STAMP_ERA
#     (realisateur#553): unknowable whether it is Zach's or an agent's, so it
#     is not credited as an answer, but it is not NOTHING either -- a caller
#     must be able to tell the two apart instead of folding both into 1.
issue_answered() {
  local repo="$1" num="$2" out
  out="$(gh api "repos/$repo/issues/$num/comments" --paginate \
         --jq "[.[]|select((.body|test(\"<!--\\\\s*agent:\")|not) or (.body|test(\"$ANSWERED_RELAY_RE\")))]|last|.created_at // \"\"" 2>/dev/null)" || return 2
  # A non-date is not an answer: a misread must never clear a label.
  [[ "$out" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]] || return 1
  [[ "${out:0:10}" < "$ANSWERED_STAMP_ERA" ]] && return 3
  return 0
}
