#!/usr/bin/env bash
# atteste-spacing.test.sh -- witness for #969: `- path: X` (space after the
# colon) must grade identically to `- path:X`, and a body of only such
# entries must never read clean (BLIND is not a pass).
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/atteste.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

harness_tmp
echo "atteste-spacing.test.sh"

mkdir -p "$T/tree/bin"
: > "$T/tree/bin/real.sh"

body() {  # body <delivers-line>... -- a minimal compliant body on stdout
  printf 'NO-DECISION: fixture\n\n<!-- DELIVERS -->\n'
  local l; for l in "$@"; do printf -- '- %s\n' "$l"; done
  printf '<!-- /DELIVERS -->\n'
}
runbody() {  # runbody <delivers-line>... -- OUT/RC
  body "$@" > "$T/b.md"
  OUT="$(ATTESTE_ROOT="$T/tree" "$SCRIPT" --body "$T/b.md" 2>&1)"; RC=$?
}

section "A. a spaced kind:value grades the same as unspaced"
runbody 'path: bin/real.sh -- the thing'
has "A1 spaced path: that exists is SATISFIED" "$OUT" "SATISFIED path:bin/real.sh"
rc  "A2 and the run exits 0" 0 $RC

runbody 'path:bin/real.sh -- the thing'
has "A3 unspaced form still SATISFIED, unchanged" "$OUT" "SATISFIED path:bin/real.sh"
rc  "A4 and exits 0" 0 $RC

runbody 'path: bin/absent.sh -- the thing'
has "A5 a spaced path that is NOT there is a GAP, not BLIND" "$OUT" "GAP       path:bin/absent.sh"
rc  "A6 and exits 4" 4 $RC

section "B. a body of only spaced entries is never read clean"
runbody 'path: bin/absent.sh'
hasnt "B1 does not read UNTYPED for a spaced entry" "$OUT" "UNTYPED"
rc    "B2 exits 4 (GAP), never 0" 4 $RC

summary
