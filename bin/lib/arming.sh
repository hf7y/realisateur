#!/usr/bin/env bash
# lib/arming.sh -- DOES ANYTHING DISPATCH TO THIS REPO? Read-only, one call.
#
# The authority is hf7y/scheduler's schedule/ROSTER, and its own header settles
# the access question: "this file is inert prose an agent may read but must not
# change". So this reads it and holds no write path at all -- decision-rot's
# suite greps this file for a write verb and fails if one appears. A guard
# against agents that lives in a comment is not a guard.
#
# WHY IT IS NOT DERIVED FROM lib/roster-set.sh: that file says which repos to
# SWEEP, which is a different question and deliberately a wider set. It listed
# dcp-gate-site as a project while dcp-gate-site was parked, which is how 12
# unreachable rows became an alarm nobody could clear.
#
# BLIND IS A STATE HERE. An unreadable roster classifies NOTHING. Defaulting to
# "armed" re-raises the alarm this exists to lower; defaulting to "parked"
# silences a real one. Both are the absence of a reading dressed as a reading.

[ -n "${ARMING_LIB:-}" ] && return 0
ARMING_LIB=1

ARMING_ROSTER_REPO="${ARMING_ROSTER_REPO:-hf7y/scheduler}"
ARMING_ROSTER_PATH="${ARMING_ROSTER_PATH:-schedule/ROSTER}"

ARMING_ROSTER=''   # project<TAB>state, one per line
ARMING_BLIND=1     # until a load succeeds

# arming_load -- 0 on success, 6 BLIND. Idempotent.
arming_load() {
  [ "$ARMING_BLIND" = 0 ] && return 0
  local raw
  command -v gh >/dev/null || return 6
  raw="$(gh api "repos/$ARMING_ROSTER_REPO/contents/$ARMING_ROSTER_PATH" \
           -H 'Accept: application/vnd.github.raw' 2>/dev/null)" || return 6
  # `| state` is the shape; a file that parses to nothing is BLIND, not empty.
  ARMING_ROSTER="$(printf '%s\n' "$raw" | awk -F'|' '
    /^[[:space:]]*#/ || NF < 4 { next }
    { p = $1; s = $4
      gsub(/^[ \t]+|[ \t]+$/, "", p); gsub(/^[ \t]+|[ \t]+$/, "", s)
      if (p != "" && (s == "live" || s == "parked")) print p "\t" s }')"
  [ -n "$ARMING_ROSTER" ] || return 6
  ARMING_BLIND=0
  return 0
}

# arming_state <project> -- live | parked | absent. Empty string while BLIND,
# so a caller that forgot to check cannot read a guess as an answer.
arming_state() {
  [ "$ARMING_BLIND" = 0 ] || { printf ''; return 6; }
  local s
  s="$(printf '%s\n' "$ARMING_ROSTER" | awk -F'\t' -v p="$1" '$1 == p { print $2; exit }')"
  printf '%s' "${s:-absent}"
}
