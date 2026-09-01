#!/usr/bin/env bash
# answered-by-hop.test.sh -- witness for answered.jq's `answered_by` (#568).
#
# WHAT IS PINNED, and why:
#
#   A: an ANSWERED-BY in the BODY is still found. The old behaviour, kept.
#   B: an ANSWERED-BY in a COMMENT is found. It was not, and that is why
#      hf7y/senechal#527 kept being asked after it had been answered: the hop
#      in answered.sh's issue_answered() only fires when answered_by is
#      non-null, and answered_by read `.body` alone.
#   C: the LAST pointer wins, so a comment supersedes the body rather than
#      being shadowed by it. An issue re-pointed at a newer answer must follow
#      the newer one.
#   D: no pointer anywhere is null -- absence must not read as a hop to "".
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

JQF="$(cd "$(dirname "$0")/.." && pwd)/lib/answered.jq"
[ -r "$JQF" ] || { echo "FAIL: $JQF not readable"; exit 1; }

# answered_by only; the verdict machinery has its own witnesses.
ab() { jq -r --arg owner zach --arg era 2026-08-14 \
         "$(cat "$JQF")"'. | answered_by // "null"'; }

section "ANSWERED-BY is read from the body AND the comments"

got="$(printf '%s' '{"body":"DECISION: @zach\nANSWERED-BY hf7y/wtul#34","comments":[]}' | ab)"
[ "$got" = "hf7y/wtul#34" ] \
  && ok "A: a pointer in the body is found" \
  || bad "A: a pointer in the body is found" "got: $got"

got="$(printf '%s' '{"body":"DECISION: @zach","comments":[
  {"createdAt":"2026-08-29T10:00:00Z","body":"ANSWERED-BY hf7y/senechal#439"}]}' | ab)"
[ "$got" = "hf7y/senechal#439" ] \
  && ok "B: a pointer in a COMMENT is found (senechal#527's case)" \
  || bad "B: a pointer in a COMMENT is found" "got: $got -- body-only again"

got="$(printf '%s' '{"body":"DECISION: @zach\nANSWERED-BY hf7y/wtul#34","comments":[
  {"createdAt":"2026-08-30T10:00:00Z","body":"ANSWERED-BY hf7y/senechal#439"},
  {"createdAt":"2026-08-29T10:00:00Z","body":"noise"}]}' | ab)"
[ "$got" = "hf7y/senechal#439" ] \
  && ok "C: the newest pointer wins over the body's" \
  || bad "C: the newest pointer wins over the body's" "got: $got"

got="$(printf '%s' '{"body":"DECISION: @zach","comments":[{"createdAt":"2026-08-29T10:00:00Z","body":"no pointer"}]}' | ab)"
[ "$got" = "null" ] \
  && ok "D: no pointer anywhere is null, not empty" \
  || bad "D: no pointer anywhere is null" "got: $got"

echo
summary
[ "$fail" -eq 0 ] || exit 1
