#!/usr/bin/env bash
# lib/arming.sh -- DOES ANYTHING DISPATCH TO THIS REPO? Read-only, one call.
# Authority: hf7y/scheduler's schedule/ROSTER, which only a human edits. The
# read-only rule here is enforced by decision-rot.test.sh I14, not by prose.
# NOT lib/roster-set.sh, which is the SWEEP set. BLIND classifies NOTHING.

[ -n "${ARMING_LIB:-}" ] && return 0
ARMING_LIB=1

. "${BASH_SOURCE[0]%/*}/estate-set.sh"
ARMING_ROSTER_REPO="${ARMING_ROSTER_REPO:-$GH_ESTATE_OWNER/scheduler}"
ARMING_ROSTER_PATH="${ARMING_ROSTER_PATH:-schedule/ROSTER}"

ARMING_ROSTER=''   # project<TAB>state, one per line
ARMING_BLIND=1     # until a load succeeds

arming_load() {
  [ "$ARMING_BLIND" = 0 ] && return 0
  local raw
  command -v gh >/dev/null || return 6
  raw="$(gh api "repos/$ARMING_ROSTER_REPO/contents/$ARMING_ROSTER_PATH" \
           -H 'Accept: application/vnd.github.raw' 2>/dev/null)" || return 6
  ARMING_ROSTER="$(printf '%s\n' "$raw" | awk -F'|' '
    /^[[:space:]]*#/ || NF < 4 { next }
    { p = $1; s = $4
      gsub(/^[ \t]+|[ \t]+$/, "", p); gsub(/^[ \t]+|[ \t]+$/, "", s)
      if (p != "" && (s == "live" || s == "parked")) print p "\t" s }')"
  [ -n "$ARMING_ROSTER" ] || return 6
  ARMING_BLIND=0
  return 0
}

# arming_state <project> -- live|parked|absent; empty while BLIND, so a
# forgetful caller cannot read a guess as an answer.
arming_state() {
  [ "$ARMING_BLIND" = 0 ] || { printf ''; return 6; }
  local s
  s="$(printf '%s\n' "$ARMING_ROSTER" | awk -F'\t' -v p="$1" '$1 == p { print $2; exit }')"
  printf '%s' "${s:-absent}"
}
