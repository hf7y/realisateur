#!/usr/bin/env bash
#
# Contract test for bin/etiquette.sh: the `needs-human` label is a VIEW of
# what line 1 declares, and could-not-look is never clean.
#
# HERMETICITY: full. A fake `gh` RECORDS every `issue edit`, so --apply is
# graded on what it wrote, not what it printed.
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/etiquette.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }
harness_tmp

mkdir -p "$T/bin"
cat > "$T/bin/gh" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "issue" ] && [ "$2" = "edit" ]; then
  printf '%s\n' "$*" >> "$EDITS"; exit 0
fi
if [ "$1" = "label" ] && [ "$2" = "create" ]; then
  printf '%s\n' "$*" >> "$EDITS"; exit 0
fi
if [ "$1" = "label" ] && [ "$2" = "list" ]; then
  [ -n "${GH_LABEL_FAIL:-}" ] && { echo "$GH_LABEL_FAIL" >&2; exit 1; }
  cat "${LABELS_FIXTURE:-/dev/null}"; exit 0
fi
if [ -n "${GH_FAIL:-}" ]; then echo "$GH_FAIL" >&2; exit 1; fi
cat "$FIXTURE"
EOF
chmod +x "$T/bin/gh"
export PATH="$T/bin:$PATH"

# A fixture grammar, so the suite grades the MECHANISM rather than the estate's
# current label set.
printf '# fixture grammar\nneeds-human\tB60205\tderived:decision\tOnly a human can move this.\ndeferred\tFBCA04\twritten:defere\tParked for an agent.\n' > "$T/grammar.tsv"
printf 'needs-human\tOnly a human can move this.\ndeferred\tParked for an agent.\n' > "$T/labels.txt"

run() { EDITS="$T/edits" FIXTURE="$T/f.json" LABELS_FIXTURE="$T/labels.txt" \
        ETIQUETTE_GRAMMAR="$T/grammar.tsv" bash "$SCRIPT" o/r "$@"; }
grammar_only() { ETIQUETTE_GRAMMAR="$T/grammar.tsv" bash "$SCRIPT" "$@"; }

echo "etiquette.test.sh"

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
has "A6 the agreeing pair is counted, not just silent" "$out" "2 issue(s) agree"
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
out="$(EDITS="$T/edits" FIXTURE="$T/f.json" LABELS_FIXTURE="$T/labels.txt" \
       ETIQUETTE_GRAMMAR="$T/grammar.tsv" GH_FAIL="HTTP 401" bash "$SCRIPT" o/r 2>&1)"; code=$?
rc  "E1 an unreadable issue list exits 6 (BLIND), not 0" 6 "$code"
has "E2 ...and says so rather than reporting nothing waiting" "$out" "not \"nothing needs a human\""

section "F. an empty tracker is clean, and is NOT the same as BLIND"
out="$(run 2>&1)"; code=$?
rc  "F1 no open issues exits 0" 0 "$code"
hasnt "F2 ...without claiming BLIND" "$out" "BLIND"

section "G. usage"
rc "G1 two repos is a usage error" 2 "$(grammar_only o/r o/s >/dev/null 2>&1; echo $?)"
rc "G2 an unknown flag is a usage error" 2 "$(grammar_only --nope >/dev/null 2>&1; echo $?)"

section "H. the grammar is READ, not compiled in"
# What "central" means mechanically: change the file, change the behaviour,
# with no edit here (#397).
out="$(grammar_only 2>&1)"
has "H1 with no repo it PRINTS the grammar"          "$out" "needs-human"
has "H2 ...including the SOURCE column, which says who may write each" "$out" "derived:decision"
has "H3 ...and names the one home it read"           "$out" "grammar.tsv"
eq  "H4 --path prints that same file, so a host can prove which one it obeys" \
    "$(grammar_only --path)" "$T/grammar.tsv"

# The load-bearing one: a label the compiled-in code never heard of.
printf 'invented-here\t00FF00\ttyped\tA label that exists only in this fixture.\n' >> "$T/grammar.tsv"
out="$(run 2>&1)"
has "H5 a label added to the FILE is demanded of the repo, with no code change" \
    "$out" "invented-here"
: > "$T/edits"; run --apply >/dev/null 2>&1
has "H6 ...and --apply provisions it from the file's own colour and meaning" \
    "$(cat "$T/edits")" "label create invented-here"
has "H7 ...with the colour the file gave it"  "$(cat "$T/edits")" "00FF00"

# And the derived label is read from the file too, not typed in the script.
sed -i 's/^needs-human\t/needs-a-person\t/' "$T/grammar.tsv"
sed -i 's/^needs-human\t/needs-a-person\t/' "$T/labels.txt"
cat > "$T/f.json" <<'EOF'
[{"number":1,"title":"declares","body":"DECISION: @zach -- pick one","labels":[]}]
EOF
: > "$T/edits"; run --apply >/dev/null 2>&1
has "H8 renaming the derived label in the FILE moves what --apply writes" \
    "$(cat "$T/edits")" "--add-label needs-a-person"
hasnt "H9 ...and the old name is not written from a hardcoded copy" \
    "$(cat "$T/edits")" "--add-label needs-human"

section "I. a grammar that did not load is BLIND, never an empty grammar"
# With --apply this would provision nothing and say so in the past tense.
out="$(ETIQUETTE_GRAMMAR="$T/nope.tsv" bash "$SCRIPT" o/r 2>&1)"; code=$?
rc  "I1 a missing grammar exits 6 (BLIND), not 0"  6 "$code"
has "I2 ...and says it could not read the RULES"   "$out" "not \"there are no rules\""
printf '# only comments\n' > "$T/empty.tsv"
rc  "I3 a grammar with no rows is BLIND too, not a vacuous pass" 6 \
    "$(ETIQUETTE_GRAMMAR="$T/empty.tsv" bash "$SCRIPT" o/r >/dev/null 2>&1; echo $?)"
rc  "I4 an unreadable LABEL list is BLIND, not 'no labels'" 6 \
    "$(EDITS="$T/edits" FIXTURE="$T/f.json" ETIQUETTE_GRAMMAR="$T/grammar.tsv" \
       GH_LABEL_FAIL="HTTP 403" bash "$SCRIPT" o/r >/dev/null 2>&1; echo $?)"

section "J. the grammar is a floor, not a whitelist"
# Deleting unrecognised labels is one bad row from erasing a repo's taxonomy.
printf 'needs-a-person\tOnly a human.\ndeferred\tParked.\ninvented-here\tfixture.\nsomebodys-own-label\tnot ours\n' > "$T/labels.txt"
: > "$T/edits"; out="$(run --apply 2>&1)"
hasnt "J1 a label absent from the grammar is never deleted" "$(cat "$T/edits")" "label delete"
hasnt "J2 ...and is not reported as a finding either"       "$out" "somebodys-own-label"

echo
summary
