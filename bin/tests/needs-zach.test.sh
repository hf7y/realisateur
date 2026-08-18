#!/usr/bin/env bash
#
# Contract test for bin/needs-zach.sh: the `needs-human` label is a VIEW of
# what line 1 declares, and could-not-look is never clean.
#
# HERMETICITY: full. A fake `gh` RECORDS every `issue edit`, so --apply is
# graded on what it wrote, not what it printed.
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/needs-zach.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }
harness_tmp

mkdir -p "$T/bin"
cat > "$T/bin/gh" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "issue" ] && [ "$2" = "edit" ]; then
  printf '%s\n' "$*" >> "$EDITS"; exit 0
fi
if [ -n "${GH_FAIL:-}" ]; then echo "$GH_FAIL" >&2; exit 1; fi
cat "$FIXTURE"
EOF
chmod +x "$T/bin/gh"
export PATH="$T/bin:$PATH"

run() { EDITS="$T/edits" FIXTURE="$T/f.json" bash "$SCRIPT" o/r "$@"; }

echo "needs-zach.test.sh"

section "A. the label is derived from line 1, both directions"
cat > "$T/f.json" <<'EOF'
[
 {"number":1,"title":"agrees, labelled","body":"DECISION: @zach -- pick one","labels":[{"name":"needs-human"}]},
 {"number":2,"title":"agrees, unlabelled","body":"NO-DECISION: nothing to weigh","labels":[]},
 {"number":3,"title":"declares but is not labelled","body":"DECISION: @zach -- pick one","labels":[]},
 {"number":4,"title":"labelled but declares no decision","body":"NO-DECISION: nothing to weigh","labels":[{"name":"needs-human"}]}
]
EOF
: > "$T/edits"; out="$(run 2>&1)"; code=$?
rc  "A1 findings exit 1" 1 "$code"
has "A2 an unlabelled DECISION: is MISSING"            "$out" "MISSING     #3"
has "A3 a labelled NO-DECISION: is STALE"              "$out" "STALE       #4"
hasnt "A4 an agreeing labelled issue is not a finding" "$out" "#1   declares"
hasnt "A5 an agreeing unlabelled issue is not a finding" "$out" "#2   declares"
has "A6 the agreeing pair is counted, not just silent" "$out" "2 issue(s) already agree"
eq  "A7 a report writes NOTHING" "$(wc -l < "$T/edits")" "0"

section "B. --apply writes the label the body implies"
: > "$T/edits"; run --apply >/dev/null 2>&1
has "B1 the missing label is ADDED"   "$(cat "$T/edits")" "--add-label needs-human"
has "B2 ...to the issue that declares" "$(cat "$T/edits")" "issue edit 3"
has "B3 the stale label is REMOVED"   "$(cat "$T/edits")" "--remove-label needs-human"
has "B4 ...from the issue that does not" "$(cat "$T/edits")" "issue edit 4"
eq  "B5 exactly two writes -- the agreeing pair is left alone" "$(wc -l < "$T/edits")" "2"

section "C. a body that declares nothing is UNDECLARED, never 'no decision'"
cat > "$T/f.json" <<'EOF'
[{"number":9,"title":"predates the convention","body":"Found while doing something else.","labels":[]}]
EOF
: > "$T/edits"; out="$(run --apply 2>&1)"; code=$?
rc  "C1 exit 1" 1 "$code"
has "C2 reported UNDECLARED"                     "$out" "UNDECLARED  #9"
eq  "C3 --apply writes NO label for it: the fix is line 1, not a label" "$(wc -l < "$T/edits")" "0"

section "D. the declaration must OPEN line 1"
cat > "$T/f.json" <<'EOF'
[{"number":11,"title":"quotes the convention later","body":"Some preamble.\n\nDECISION: @zach -- this is a quotation, not a declaration","labels":[]}]
EOF
out="$(run 2>&1)"
has "D1 a DECISION: below line 1 does not earn the label" "$out" "UNDECLARED  #11"

section "E. could-not-look is BLIND, never clean"
cat > "$T/f.json" <<'EOF'
[]
EOF
GH_FAIL="HTTP 401" out="$(EDITS="$T/edits" FIXTURE="$T/f.json" GH_FAIL="HTTP 401" bash "$SCRIPT" o/r 2>&1)"; code=$?
rc  "E1 an unreadable issue list exits 6 (BLIND), not 0" 6 "$code"
has "E2 ...and says so rather than reporting nothing waiting" "$out" "not \"nothing needs Zach\""

section "F. an empty tracker is clean, and is NOT the same as BLIND"
out="$(run 2>&1)"; code=$?
rc  "F1 no open issues exits 0" 0 "$code"
hasnt "F2 ...without claiming BLIND" "$out" "BLIND"

section "G. usage"
rc "G1 no repo is a usage error, not a blind read" 2 "$(bash "$SCRIPT" >/dev/null 2>&1; echo $?)"
rc "G2 two repos is a usage error"                 2 "$(bash "$SCRIPT" o/r o/s >/dev/null 2>&1; echo $?)"

echo
summary
