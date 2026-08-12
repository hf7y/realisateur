#!/usr/bin/env bash
# not-a-spend.test.sh -- the signed escape from bashify's purge scorer.
#
# An exemption mechanism with no test is the dangerous kind: it is the one
# piece of machinery whose whole job is to say "ignore the guard". Every case
# below exists to bound it.
#
# HERMETICITY: PARTIAL, and the split is deliberate. Cases 1 and 5 are fully
# hermetic -- they read only this repo's own ledger and closure.sh's source, so
# they hold anywhere. Cases 2, 3, 4 and 6 must run closure.sh against a REAL
# project, which needs sibling checkouts and a bashified branch that CI does
# not have; they SKIP there rather than fail, and say so. A case that is red
# purely because of where it ran teaches a reader to ignore the suite, which is
# how the drift these guards exist to catch gets shipped.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
C="$ROOT/bashify/lib/closure.sh"
LEDGER="$ROOT/bin/lib/not-a-spend.tsv"
pass=0; fail=0
ok()  { printf '  PASS: %s\n' "$*"; pass=$((pass+1)); }
bad() { printf '  FAIL: %s\n' "$*"; fail=$((fail+1)); }
echo "not-a-spend.test"

# --- 1. every claim in the ledger is TRUE -------------------------------
# A row asserts the file invokes nothing. That is checkable, so check it --
# otherwise the ledger is a place to write wishes.
rows=0
while IFS=$'\t' read -r proj file why; do
  case "${proj:-}" in \#*|'') continue ;; esac
  rows=$((rows+1))
  f="$ROOT/../$proj/$file"; [ -f "$f" ] || f="$ROOT/$file"
  if [ ! -f "$f" ]; then bad "$proj/$file is signed for but does not exist"; continue; fi
  n=$(grep -cE 'claude -p|claude --print|api\.anthropic|curl[^|]*anthropic' "$f" 2>/dev/null)
  [ "$n" -eq 0 ] && ok "$file invokes nothing, as its row claims" \
    || bad "$file is SIGNED but contains $n invocation(s) -- the row is false"
  [ -n "${why:-}" ] && [ "${#why}" -gt 40 ] || bad "$file's row gives no usable reason"
done < "$LEDGER"
[ "$rows" -gt 0 ] && ok "ledger carries $rows signed row(s)" || bad "ledger is empty"

# --- can closure.sh see a real estate here? ------------------------------
out="$(timeout 120 bash "$C" realisateur x 2>/dev/null)"
if ! grep -qE 'bin/hygiene-lint\.sh' <<<"$out"; then
  echo "  SKIP: closure.sh cannot score realisateur here (no sibling checkouts /"
  echo "        no bashified branch). Cases 2,3,4,6 need a real estate; 1 and 5 ran."
  printf '\nnot-a-spend.test: %d passed, %d failed\n' "$pass" "$fail"
  [ "$fail" -eq 0 ]; exit $?
fi

# --- 2. a signed file's verdict changes ----------------------------------
grep -qE 'COMMENT-ONLY.*bin/hygiene-lint\.sh' <<<"$out" \
  && ok "a signed lint is no longer ESSENTIAL" || bad "hygiene-lint.sh did not clear"

# --- 3. THE MEASUREMENT IS UNCHANGED -------------------------------------
# The count must still be reported. An exemption that also hid the number
# would leave a reader unable to see what they are trusting.
grep -qE 'bin/hygiene-lint\.sh' <<<"$out" && grep -qE 'self=1[0-9].*bin/hygiene-lint\.sh' <<<"$out" \
  && ok "the raw score is still printed alongside the softened verdict" \
  || bad "the exemption hid the measurement, not just the verdict"

# --- 4. AN UNSIGNED SPENDER STILL FAILS ----------------------------------
# The load-bearing case. If this ever passes, the guard is gone.
sout="$(timeout 120 bash "$C" scheduler x 2>/dev/null)"
grep -qE 'ESSENTIAL.*bin/scheduler-run' <<<"$sout" \
  && ok "an unsigned genuine spender (scheduler-run) is still ESSENTIAL" \
  || bad "a real spender stopped being ESSENTIAL -- the guard is broken, not relaxed"

# --- 5. THE EXEMPTION IS PER-MEMBER, NOT BLANKET -------------------------
# Signing an outer file must not excuse a spender it sources: the spend is
# genuinely reachable through it. Asserted structurally, because building a
# fixture repo with a bashified branch is out of proportion here.
grep -q 'not_a_spend "$proj" "$m"' "$C" \
  && ok "the lookup is applied per closure MEMBER" \
  || bad "the exemption is applied to the outer file only -- signing one file would hide a sourced spender"
grep -q 'not_a_spend "$proj" "$rel"' "$C" \
  && bad "a blanket per-file exemption is still present" \
  || ok "no blanket per-file zeroing remains"

# --- 6. an unsigned file is untouched ------------------------------------
# CAPTURE, then grep. Piping closure.sh straight into grep makes `pipefail`
# hand the pipeline closure.sh's own exit status, so the && arm fails even when
# grep matched -- which is how this case reported a broken exemption when the
# exemption was fine and the test was not. Same trap as reading $? after a pipe.
noledger="$(NOT_A_SPEND_TSV=/dev/null timeout 120 bash "$C" realisateur x 2>/dev/null)"
grep -qE 'ESSENTIAL.*bin/hygiene-lint\.sh' <<<"$noledger" \
  && ok "with the ledger absent, the same file is ESSENTIAL again (not vacuous)" \
  || bad "the verdict does not depend on the ledger -- something else cleared it"

printf '\nnot-a-spend.test: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
