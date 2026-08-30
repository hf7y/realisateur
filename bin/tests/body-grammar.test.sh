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
findings() { local o; o="$(grammar_check "$1" "${2:-}")"; printf '%s' "$?"; : "$o"; }
codes()    { grammar_check "$1" "${2:-}" | while read -r c _; do printf '%s ' "$c"; done; }

GOOD='DECISION: @zach -- link the shim host-wide?
DEFAULT-AFTER 14d: link it and say so; unlinking is one command

Prose about the change.

<!-- DEFERRED -->
- hf7y/vim-arcade#143 -- drop the third copy of the retired grammar
- hf7y/realisateur#330 -- gh-sign is linked nowhere, so nothing is signed
<!-- /DEFERRED -->

<!-- DELIVERS -->
- host:monkey path:/usr/local/bin/gh via: install-verb-build.sh --link
<!-- /DELIVERS -->'

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
<!-- /DEFERRED -->

<!-- DELIVERS -->
- none
<!-- /DELIVERS -->')" 0
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
<!-- /DEFERRED -->

<!-- DELIVERS -->
- none
<!-- /DELIVERS -->')" 0

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
<!-- /DEFERRED -->

<!-- DELIVERS -->
- none
<!-- /DELIVERS -->')" 0

section 'D. every entry names a destination'
has 'D1 a bare intention has none' "$(codes 'NO-DECISION: @zach ok
<!-- DEFERRED -->
- clean up the ratchets sometime
<!-- /DEFERRED -->')" NO-DESTINATION
eq 'D2 owner/repo#N is a destination' "$(findings 'NO-DECISION: @zach ok
<!-- DEFERRED -->
- hf7y/scheduler#49 -- the sibling issue
<!-- /DEFERRED -->

<!-- DELIVERS -->
- none
<!-- /DELIVERS -->')" 0
eq 'D3 a URL is a destination' "$(findings 'NO-DECISION: @zach ok
<!-- DEFERRED -->
- https://github.com/hf7y/realisateur/issues/327 -- the read side
<!-- /DEFERRED -->

<!-- DELIVERS -->
- none
<!-- /DELIVERS -->')" 0
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
<!-- /DEFERRED -->

<!-- DELIVERS -->
- none
<!-- /DELIVERS -->')" 0

section 'T. the DELIVERS ledger -- where the change takes effect'
eq 'T1 no DELIVERS block is a finding' "$(codes 'NO-DECISION: x

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->')" 'UNSHIPPED '
eq 'T2 "- none" is a complete answer' "$(findings 'NO-DECISION: x

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->

<!-- DELIVERS -->
- none
<!-- /DELIVERS -->')" 0
eq 'T3 a typed claim passes' "$(findings 'NO-DECISION: x

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->

<!-- DELIVERS -->
- clock:root@monkey tag:realisateur:ausculte:CADENCE
<!-- /DELIVERS -->')" 0
eq 'T3b what a change TAKES OUT is a delivery too (#754)' "$(findings 'NO-DECISION: x

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->

<!-- DELIVERS -->
- retires: path:hooks/old-guard.sh -> path:hooks/new-guard.sh -- bin/supersession.sh checks it went
<!-- /DELIVERS -->')" 0
eq 'T4 prose a check cannot look for is a finding' "$(codes 'NO-DECISION: x

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->

<!-- DELIVERS -->
- it lands on the host
<!-- /DELIVERS -->')" 'UNTYPED-DELIVERY '
eq 'T5 an empty block is not an answer' "$(codes 'NO-DECISION: x

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->

<!-- DELIVERS -->
<!-- /DELIVERS -->')" 'EMPTY-SHIP '
eq 'T6 two blocks: a reader cannot tell which is current' "$(codes 'NO-DECISION: x

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->

<!-- DELIVERS -->
- none
<!-- /DELIVERS -->
<!-- DELIVERS -->
- none
<!-- /DELIVERS -->')" 'MULTI-SHIP '

eq 'T7 an indented example is not a second block' "$(findings 'NO-DECISION: x

Here is what one looks like:

    <!-- DELIVERS -->
    - host:monkey path:/usr/local/bin/dresse
    <!-- /DELIVERS -->

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->

<!-- DELIVERS -->
- none
<!-- /DELIVERS -->')" 0

section 'S. the shim REFUSES, and the refusal is what stops the write'
run_shim() { ( PATH="$T/bin:$PATH"; cd "$T" && bash "$SHIM" "$@" 2>&1 ); }
rm -f "$T/reached"

printf '%s\n' "$GOOD" > "$T/good.md"
printf 'intro\n\nDECISION: buried\n' > "$T/bad.md"

out="$(run_shim issue create --title T --body-file "$T/bad.md")"; got=$?
rc   'S1 a malformed issue body is REFUSED (7): nothing was created' 7 "$got"
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
rc  'S8 --check-body re-runs it offline and FINDS it (1), refusing nothing' 1 "$got"
has 'S9 --check-body names the same finding'         "$out" MISPLACED-DECISION

section 'I. the CI backstop is wired to the same grammar'
# deferral-ledger.yml was deleted 2026-08-22 (#511). It was never
# a required check, and it was green on every PR that answered `- none` -- 260
# of 262. A backstop satisfied by declaring nothing backstops nothing. The
# grammar itself is unchanged and still enforced at the write by
# gh-sign.sh --check-body, which sections A-H above exercise directly.
# Reinstating a delivery check that asks for a claim, not a field, is v2.

hasnt 'I5 the deleted script is really gone' "$(ls "$ROOT")" 'deferral-ledger.sh'

# --- DEFAULT-AFTER: the unanswered decision resolves itself (2026-08-22) -----
# 36 open `needs-human` issues, each subtracting from its repo's `actionable`
# count in tempo.sh -- so every unanswered question was also a brake on the
# repo that asked it. #262: the only brake in the loop was a person's
# attention, "which is why the estate could not be left alone".
section "DEFAULT-AFTER"

_da() { printf 'DECISION: @zach -- q\n%s\n<!-- DEFERRED -->\n- none\n<!-- /DEFERRED -->\n<!-- DELIVERS -->\n- none\n<!-- /DELIVERS -->\n' "$1"; }

grammar_check "$(_da 'DEFAULT-AFTER 14d: close it as declined')" >/dev/null 2>&1 \
  && ok "a well-formed default is accepted" \
  || bad "a well-formed default is accepted" "it was refused"

out="$(grammar_check "$(_da 'DEFAULT-AFTER: close it')" 2>&1)"
case "$out" in *BAD-DEFAULT*) ok "a default with no day count is BAD-DEFAULT" ;;
  *) bad "no day count is BAD-DEFAULT" "got: $out" ;; esac

out="$(grammar_check "$(_da 'DEFAULT-AFTER 14d:')" 2>&1)"
case "$out" in *BAD-DEFAULT*) ok "a window with no action is BAD-DEFAULT -- a timer to nowhere" ;;
  *) bad "no action is BAD-DEFAULT" "got: $out" ;; esac

_nodefault="$(printf 'DECISION: @zach -- q\n<!-- DEFERRED -->\n- none\n<!-- /DEFERRED -->\n<!-- DELIVERS -->\n- none\n<!-- /DELIVERS -->\n')"
out="$(grammar_check "$_nodefault" 2>&1)"
case "$out" in *NO-DEFAULT*) ok "#680: a DECISION with no DEFAULT-AFTER is NO-DEFAULT -- blocking by omission is refused" ;;
  *) bad "no default is NO-DEFAULT" "got: $out" ;; esac

grammar_check "$(_da 'DEFAULT-AFTER 0d: block -- irreversible, no default')" >/dev/null 2>&1 \
  && ok "#680: blocking forever stays legal when DECLARED as 0d, so an irreversible call has a spelling" \
  || bad "0d blocks forever" "it was refused; irreversible calls lost their spelling"

grammar_check "$(printf 'NO-DECISION: agent work\n<!-- DEFERRED -->\n- none\n<!-- /DEFERRED -->\n<!-- DELIVERS -->\n- none\n<!-- /DELIVERS -->\n')" >/dev/null 2>&1 \
  && ok "#680: NO-DECISION needs no default -- the rule binds the bodies that ask, not the ones that report" \
  || bad "NO-DECISION needs no default" "it was refused"

# The reader the actuator consumes.
got="$(grammar_default_after "$(_da 'DEFAULT-AFTER 14d: close it as declined')")"
eq "the reader returns days and action, tab-separated" "$got" "$(printf '14\tclose it as declined')"
grammar_default_after "$(_da 'nothing here')" >/dev/null 2>&1 \
  && bad "absent default returns 1" "it returned 0" \
  || ok "an absent default returns 1, so the actuator can tell 'blocks forever' from 'not read'"

section "ANSWERED-BY"

_ab() { printf 'NO-DECISION: q\n%s\n<!-- DEFERRED -->\n- none\n<!-- /DEFERRED -->\n<!-- DELIVERS -->\n- none\n<!-- /DELIVERS -->\n' "$1"; }

grammar_check "$(_ab 'ANSWERED-BY hf7y/wtul#34')" >/dev/null 2>&1 \
  && ok "a well-formed pointer is accepted" \
  || bad "a well-formed pointer is accepted" "it was refused"

out="$(grammar_check "$(_ab 'ANSWERED-BY wtul#34')" 2>&1)"
case "$out" in *BAD-ANSWERED-BY*) ok "no owner (bare repo#n) is BAD-ANSWERED-BY" ;;
  *) bad "no owner is BAD-ANSWERED-BY" "got: $out" ;; esac

out="$(grammar_check "$(_ab 'ANSWERED-BY hf7y/wtul')" 2>&1)"
case "$out" in *BAD-ANSWERED-BY*) ok "no issue number is BAD-ANSWERED-BY" ;;
  *) bad "no issue number is BAD-ANSWERED-BY" "got: $out" ;; esac

out="$(grammar_check "$(_ab 'ANSWERED-BY see the other issue')" 2>&1)"
case "$out" in *BAD-ANSWERED-BY*) ok "prose instead of a ref is BAD-ANSWERED-BY" ;;
  *) bad "prose instead of a ref is BAD-ANSWERED-BY" "got: $out" ;; esac

grammar_check "$(printf 'NO-DECISION: q\n<!-- DEFERRED -->\n- none\n<!-- /DEFERRED -->\n<!-- DELIVERS -->\n- none\n<!-- /DELIVERS -->\n')" >/dev/null 2>&1 \
  && ok "a body with no pointer is still valid" \
  || bad "no pointer is still valid" "it was refused"

got="$(grammar_answered_by "$(_ab 'ANSWERED-BY hf7y/wtul#34')")"
eq "the reader returns the ref" "$got" "hf7y/wtul#34"
grammar_answered_by "$(_ab 'nothing here')" >/dev/null 2>&1 \
  && bad "absent pointer returns 1" "it returned 0" \
  || ok "an absent pointer returns 1, so the caller can tell 'no pointer' from 'not read'"


section "R. a PR says what it takes out, or says nothing on purpose (#754)"
eq 'R1 a PR that delivers and never mentions a retirement is refused' \
   "$(codes 'NO-DECISION: x

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->

<!-- DELIVERS -->
- path:bin/new.sh -- the replacement
<!-- /DELIVERS -->' pr)" 'UNRETIRED '
eq 'R2 the bare claim is the answer, exactly as DEFERRED takes "- none"' \
   "$(findings 'NO-DECISION: x

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->

<!-- DELIVERS -->
- path:bin/new.sh -- the replacement
- retires: none
<!-- /DELIVERS -->' pr)" 0
eq 'R3 an explanation after the bare claim is prose the probe cannot read' \
   "$(codes 'NO-DECISION: x

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->

<!-- DELIVERS -->
- path:bin/new.sh -- x
- retires: none -- nothing existed before
<!-- /DELIVERS -->' pr)" 'UNRETIRED '
eq 'R4 a real retirement satisfies it' \
   "$(findings 'NO-DECISION: x

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->

<!-- DELIVERS -->
- retires: path:bin/old.sh -> path:bin/new.sh -- why
<!-- /DELIVERS -->' pr)" 0
eq 'R5 a PR that lands nowhere is not asked twice' \
   "$(findings 'NO-DECISION: x

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->

<!-- DELIVERS -->
- none
<!-- /DELIVERS -->' pr)" 0
eq 'R6 an ISSUE retires nothing, so it is never asked' \
   "$(findings 'NO-DECISION: x

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->

<!-- DELIVERS -->
- path:bin/new.sh -- the replacement
<!-- /DELIVERS -->')" 0

summary
