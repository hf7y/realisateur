#!/usr/bin/env bash
# body-grammar.test.sh -- witness for bin/lib/body-grammar.sh and the
# admission control bin/gh-sign.sh builds on it.
#
# SUBJECT: bin/lib/body-grammar.sh, bin/gh-sign.sh, .github/workflows/deferral-ledger.yml
#
# Replaces bin/tests/deferral-ledger.test.sh: same rules, enforced at the
# write instead of audited after it. Section S is what the old suite could not
# have -- proof that a malformed body never reaches the network.
set -uo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
. "$ROOT/lib/body-grammar.sh"

SHIM="$ROOT/gh-sign.sh"
harness_tmp

# A stub `gh` that records that it was reached. Its existence is the assertion
# in section S: if the file appears, the write went through.
mkdir -p "$T/bin"
cat > "$T/bin/gh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$T/reached"
cat > "$T/last-body" 2>/dev/null || true
EOF
chmod +x "$T/bin/gh"

# findings <body> -- the grammar's finding count, as a string.
findings() { local o; o="$(grammar_check "$1")"; printf '%s' "$?"; : "$o"; }
codes()    { grammar_check "$1" | while read -r c _; do printf '%s ' "$c"; done; }

GOOD='DECISION: @zach -- link the shim host-wide?

Prose about the change.

<!-- DEFERRED -->
- hf7y/vim-arcade#143 -- drop the third copy of the retired grammar
- hf7y/realisateur#330 -- gh-sign is linked nowhere, so nothing is signed
<!-- /DEFERRED -->'

section 'A. the declaration is read from the FIRST non-empty line only'
eq 'A1 DECISION opens it'            "$(grammar_declaration "$GOOD")" decision
eq 'A2 NO-DECISION is its own kind'  "$(grammar_declaration 'NO-DECISION: nothing to call')" no-decision
eq 'A3 an ordinary body declares nothing' "$(grammar_declaration 'just a body')" none
eq 'A4 markdown furniture is stripped' "$(grammar_declaration '## DECISION: still counts')" decision
eq 'A5 leading blank lines are skipped' "$(grammar_declaration '

DECISION: after two blanks')" decision
# The word must OPEN the line: a body that merely QUOTES the convention must
# not exempt itself. This false positive is the one guard-estate's check E hit.
eq 'A6 a mention mid-line is not a declaration' \
  "$(grammar_declaration 'this PR follows the DECISION: convention')" none

section 'B. a decision buried below line 1 is the failure the convention exists for'
has 'B1 flagged' "$(codes 'intro paragraph

DECISION: buried at line 3

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->')" MISPLACED-DECISION
eq  'B2 the well-formed body is clean' "$(findings "$GOOD")" 0
# #419: NO-DECISION asserts there is nobody to decide, so it names no @handle.
eq  'B2a NO-DECISION needs no decider' "$(findings 'NO-DECISION: agent work -- tests green, nothing to weigh

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->')" 0
has 'B2b DECISION still needs one' "$(codes 'DECISION: who links the shim?

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->')" NO-DECIDER
has 'B2c a buried NO-DECISION is still MISPLACED' "$(codes 'intro paragraph

NO-DECISION: buried at line 3

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->')" MISPLACED-DECISION
# A decision inside a fenced block is quoted code, not a claim on a human.
eq  'B3 a fenced example is not a buried decision' \
  "$(findings 'NO-DECISION: @zach nothing to weigh

```
DECISION: this is an example
```

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->')" 0

section 'C. the DEFERRED block'
has 'C1 absent block is UNLEDGERED'   "$(codes 'a body with no ledger at all')" UNLEDGERED
has 'C2 empty block is EMPTY-LEDGER'  "$(codes 'NO-DECISION: @zach ok
<!-- DEFERRED -->
<!-- /DEFERRED -->')" EMPTY-LEDGER
has 'C3 two blocks are MULTI-LEDGER'  "$(codes 'NO-DECISION: @zach ok
<!-- DEFERRED -->
- none
<!-- /DEFERRED -->
<!-- DEFERRED -->
- none
<!-- /DEFERRED -->')" MULTI-LEDGER
has 'C4 an unclosed block is UNCLOSED' "$(codes 'NO-DECISION: @zach ok
<!-- DEFERRED -->
- hf7y/chezz#12 -- a thing')" UNCLOSED
eq  'C5 "- none" is a complete, passing answer' "$(findings 'NO-DECISION: @zach ok
<!-- DEFERRED -->
- none
<!-- /DEFERRED -->')" 0

section 'D. every entry names a destination'
has 'D1 a bare intention has none' "$(codes 'NO-DECISION: @zach ok
<!-- DEFERRED -->
- clean up the ratchets sometime
<!-- /DEFERRED -->')" NO-DESTINATION
eq 'D2 owner/repo#N is a destination' "$(findings 'NO-DECISION: @zach ok
<!-- DEFERRED -->
- hf7y/scheduler#49 -- the sibling issue
<!-- /DEFERRED -->')" 0
eq 'D3 a URL is a destination' "$(findings 'NO-DECISION: @zach ok
<!-- DEFERRED -->
- https://github.com/hf7y/realisateur/issues/327 -- the read side
<!-- /DEFERRED -->')" 0
# NO-OWNER is refused however well argued. #327 filed two of them: the issue
# it DID cite is open and findable, and both ownerless entries are lost --
# 0 issues mention gh-sign anywhere, and #327 merged as a no-op because of it.
has 'D4 NO-OWNER is refused even with a full reason' "$(codes 'NO-DECISION: @zach ok
<!-- DEFERRED -->
- NO-OWNER: it needs a human call about all thirteen accounts at once
<!-- /DEFERRED -->')" NO-DESTINATION
has 'D5 and refused without one' "$(codes 'NO-DECISION: @zach ok
<!-- DEFERRED -->
- NO-OWNER: later
<!-- /DEFERRED -->')" NO-DESTINATION
eq 'D6 a wrapped entry folds into its bullet' "$(findings 'NO-DECISION: @zach ok
<!-- DEFERRED -->
- hf7y/realisateur#330 -- it changes what four live accounts must hold
  before they can fetch anything, so a human decides
<!-- /DEFERRED -->')" 0

section 'S. the shim REFUSES, and the refusal is what stops the write'
run_shim() { ( PATH="$T/bin:$PATH"; cd "$T" && bash "$SHIM" "$@" 2>&1 ); }
rm -f "$T/reached"

printf '%s\n' "$GOOD" > "$T/good.md"
printf 'intro\n\nDECISION: buried\n' > "$T/bad.md"

out="$(run_shim issue create --title T --body-file "$T/bad.md")"; got=$?
rc   'S1 a malformed issue body exits 3' "$got" 3
has  'S2 it says what is wrong'          "$out" MISPLACED-DECISION
has  'S3 it prints the block to paste'   "$out" '<!-- DEFERRED -->'
if [ -f "$T/reached" ]; then bad 'S4 gh was never called' "gh ran: $(cat "$T/reached")"
else ok 'S4 gh was never called'; fi

out="$(run_shim issue create --title T --body-file "$T/good.md")"
if [ -f "$T/reached" ]; then ok 'S5 a well-formed body reaches gh'
else bad 'S5 a well-formed body reaches gh' "gh was never called: $out"; fi

# Comments are deliberately exempt: a thread reply is not where a ledger
# belongs, and refusing one loses the reply. It still gets signed.
rm -f "$T/reached"
run_shim issue comment 5 --body 'a reply with no ledger' >/dev/null
if [ -f "$T/reached" ]; then ok 'S6 a comment is not held to the create grammar'
else bad 'S6 a comment is not held to the create grammar' 'the shim refused a comment'; fi

# A guard that cannot look must SAY so and fall through -- never report clean.
out="$( PATH="$T/bin:$PATH" GH_SIGN_LIB=/nonexistent bash "$SHIM" issue create --title T --body-file "$T/bad.md" 2>&1 )"
has 'S7 a missing grammar library is announced BLIND, not silently skipped' "$out" BLIND

out="$(bash "$SHIM" --check-body "$T/bad.md" 2>&1)"; got=$?
rc  'S8 --check-body re-runs the same check offline' "$got" 3
has 'S9 --check-body names the same finding'         "$out" MISPLACED-DECISION

section 'I. the CI backstop is wired to the same grammar'
WF="$ROOT/../.github/workflows/deferral-ledger.yml"
if [ -f "$WF" ]; then
  wf="$(cat "$WF")"
  has 'I1 the workflow calls the shim, not a second implementation' "$wf" 'gh-sign.sh --check-body'
  # `edited` is not in the default pull_request set, and it is the ONLY event
  # emitted when an author adds the ledger -- the one act that turns the check
  # green. Without it they fix the finding and watch the check stay red.
  has 'I2 it fires on `edited`'          "$wf" 'edited'
  has 'I3 it fires on ready_for_review'  "$wf" 'ready_for_review'
  hasnt 'I4 no reference to the deleted script remains' "$wf" 'bin/deferral-ledger.sh'
else
  bad 'I1 workflow present' "no .github/workflows/deferral-ledger.yml"
fi

hasnt 'I5 the deleted script is really gone' "$(ls "$ROOT")" 'deferral-ledger.sh'

summary
