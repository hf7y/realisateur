#!/usr/bin/env bash
# lib/answered.sh -- has a human answered this issue? decision-rot's predicate,
# reused so `needs-human` stops claiming a decision Zach already made.
#
# One account authors every comment, so authorship cannot separate Zach from an
# agent. `gh-sign` stamps agent comments: an UNSTAMPED comment after the stamp
# went live is a human's; older is unknowable, and unknowable is not an answer.
ANSWERED_STAMP_ERA="${ANSWERED_STAMP_ERA:-2026-08-14}"

# THE RELAY MARKER, AND WHY IT HAD TO EXIST. Most of Zach's answers are spoken
# in a session, not typed into the tracker. An agent that writes one down is
# the ONLY way it outlives the session -- and until 2026-08-21 that relay was
# self-defeating: `gh-sign` stamps the agent's comment, the rule above reads
# every stamped comment as not-an-answer, and the relayed decision was
# invisible to the predicate built to find exactly it. #430 was answered four
# times and re-surfaced as `needs-human` every time.
#
# So a stamped comment counts when it carries this marker naming the decider:
#     <!-- decision-by: zach 2026-08-21 -->
# An agent could forge it. That is the deliberate trade: a forged relay is
# TYPED and greppable, so it can be audited; a lost answer leaves no trace at
# all, and losing them is the failure that is actually happening.
ANSWERED_RELAY_RE='<!--\\s*decision-by:'

# issue_answered <owner/repo> <number> -- 0 if answered, 1 if not, 2 if BLIND.
issue_answered() {
  local repo="$1" num="$2" out
  out="$(gh api "repos/$repo/issues/$num/comments" --paginate \
         --jq "[.[]|select((.body|test(\"<!--\\\\s*agent:\")|not) or (.body|test(\"$ANSWERED_RELAY_RE\")))]|last|.created_at // \"\"" 2>/dev/null)" || return 2
  # A non-date is not an answer: a misread must never clear a label.
  [[ "$out" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]] || return 1
  [[ ! "${out:0:10}" < "$ANSWERED_STAMP_ERA" ]] || return 1
  return 0
}
