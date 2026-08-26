#!/usr/bin/env bash
#
# SUBJECT: bin/ausculte-cadence.sh. Hermetic -- ausculte is a stub and
# --no-escalate is used throughout, so a test run can never reach a person.
#
# Usage: bin/tests/ausculte-cadence.test.sh   (exit 0 = all pass)

set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/ausculte-cadence.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }
harness_tmp

mkdir -p "$T/bin" "$T/state"
stub_ausculte() { # <json> [exit]
  printf '#!/usr/bin/env bash\ncat <<%s\n%s\n%s\nexit %s\n' "JSON" "$1" "JSON" "${2:-0}" > "$T/bin/ausculte.sh"
  chmod +x "$T/bin/ausculte.sh"
}
run() { OUT="$(AUSCULTE_BIN="$T/bin/ausculte.sh" AUSCULTE_CADENCE_STATE="$T/state" \
               bash "$SCRIPT" --no-escalate "$@" 2>&1)"; RC=$?; }

DOWN_ROW='[{"probe":"arming","status":"DOWN","detail":"two accounts stopped"}]'
OK_ROW='[{"probe":"arming","status":"OK","detail":"all dispatching"}]'

section "A. a first DOWN is recorded, not escalated"
stub_ausculte "$DOWN_ROW"
run
rc "A1 exit 0 on the first strike" 0 "$RC"
has "A2 it says the next one escalates" "$OUT" "escalates if it is DOWN again"
[ -f "$T/state/arming.down" ] && ok "A3 the streak is on disk, so the next run knows" \
  || bad "A3 the streak is on disk" "no state file"

section "B. the second consecutive DOWN escalates"
run
rc "B1 exit 5" 5 "$RC"
has "B2 it names the row and says twice running" "$OUT" "arming -- twice running"

section "C. a recovery clears the streak"
stub_ausculte "$OK_ROW"
run
rc "C1 exit 0" 0 "$RC"
[ -f "$T/state/arming.down" ] && bad "C2 the streak is cleared" "state file survived" \
  || ok "C2 the streak is cleared"
stub_ausculte "$DOWN_ROW"
run
rc "C3 the next DOWN is a first strike again, not an escalation" 0 "$RC"

section "D. BLIND from ausculte is BLIND here"
stub_ausculte '[{"probe":"hosts","status":"BLIND","detail":"cannot reach dexter"}]'
run
rc "D1 a BLIND row is not escalated and not called OK" 0 "$RC"
hasnt "D2 BLIND is never reported as twice running" "$OUT" "twice running"

section "E. a non-array answer is BLIND, never 'no rows'"
printf '#!/usr/bin/env bash\nprintf "not json\\n"\nexit 0\n' > "$T/bin/ausculte.sh"
chmod +x "$T/bin/ausculte.sh"
run
rc "E1 exit 6" 6 "$RC"
has "E2 it says it produced no rows" "$OUT" "no rows"

section "E2. mints a credential when it has none"
printf '#!/usr/bin/env bash\n[ "$1" = --token ] && printf "ghs_fixturetoken\\n"\n' > "$T/bin/mint.sh"
chmod +x "$T/bin/mint.sh"
printf '#!/usr/bin/env bash\nprintf "[{\\"probe\\":\\"rot\\",\\"status\\":\\"OK\\",\\"detail\\":\\"%%s\\"}]\\n" "$GH_TOKEN"\n' > "$T/bin/ausculte.sh"
chmod +x "$T/bin/ausculte.sh"
OUT="$(AUSCULTE_BIN="$T/bin/ausculte.sh" AUSCULTE_CADENCE_STATE="$T/state" \
       SELFDEV_APP_MINT="$T/bin/mint.sh" GH_TOKEN='' GITHUB_TOKEN='' \
       bash "$SCRIPT" --no-escalate 2>&1)"; RC=$?
has "E2a the minted token reaches the probes" "$OUT" "ghs_fixturetoken"

OUT="$(AUSCULTE_BIN="$T/bin/ausculte.sh" AUSCULTE_CADENCE_STATE="$T/state" \
       SELFDEV_APP_MINT="$T/bin/mint.sh" GH_TOKEN=ghs_alreadyhere \
       bash "$SCRIPT" --no-escalate 2>&1)"
has "E2b an existing credential is not replaced" "$OUT" "ghs_alreadyhere"

section "F. --install-cadence writes nothing without --apply"
before="$(crontab -l 2>/dev/null | md5sum)"
run --install-cadence
has "F1 it prints the line it would install" "$OUT" "realisateur:ausculte:CADENCE"
eq "F2 the crontab is untouched" "$(crontab -l 2>/dev/null | md5sum)" "$before"

section "G. the body it escalates with passes the grammar gh-sign enforces"
# THE HOLE THIS CLOSES. Every section above passes --no-escalate, so the body
# this script writes was never built, let alone graded. On monkey `gh` IS
# gh-sign, which REFUSES `issue create` when lib/body-grammar.sh finds
# anything (exit 7) -- and this body carried no DELIVERS block, so it failed
# UNSHIPPED. Measured 2026-08-22: four rows BLIND, streak files on disk since
# 04:37, second strike reached every run, and zero issues ever filed. The
# health monitor could not pass its own repo's body grammar, and said so only
# to a cron mailbox monkey does not have.
cat > "$T/bin/gh" <<'STUB'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do
  case "$1" in --body) printf '%s' "$2" > "$GH_BODY_OUT"; shift 2 ;; *) shift ;; esac
done
exit 0
STUB
chmod +x "$T/bin/gh"
rm -f "$T/state"/*.down "$T/state"/*.blind
stub_ausculte "$DOWN_ROW"
esc() { OUT="$(PATH="$T/bin:$PATH" GH_BODY_OUT="$T/body.txt" ZAXON='http://127.0.0.1:1/mcp' \
               AUSCULTE_BIN="$T/bin/ausculte.sh" AUSCULTE_CADENCE_STATE="$T/state" \
               bash "$SCRIPT" 2>&1)"; RC=$?; }
esc   # first strike -- recorded
esc   # second strike -- escalates, and writes the body
rc "G1 the second strike escalates with escalation ENABLED" 5 "$RC"
[ -s "$T/body.txt" ] && ok "G2 a body reached gh issue create" \
  || bad "G2 a body reached gh issue create" "nothing was captured"
# shellcheck source=bin/lib/body-grammar.sh
. "$(dirname "$SCRIPT")/lib/body-grammar.sh"
if findings="$(grammar_check "$(cat "$T/body.txt" 2>/dev/null)")"; then
  ok "G3 that body passes lib/body-grammar.sh, so gh-sign will not refuse it"
else
  bad "G3 that body passes lib/body-grammar.sh" "$findings"
fi

section "H. it does not reach Zach's phone, and that is deliberate"
# Measured 2026-08-26 against the relay's own ticket store: this sender had
# 47 questions, 47 stale, 0 EVER answered, 2026-08-21 to 2026-08-26 -- 44% of
# every ticket the relay has carried. Zach: "it means nothing to me. I've
# ignored it." The relay holds ONE question at a time (hf7y/crt#67), so each
# held the only channel to him for its full TTL. This guard exists because the
# comment saying "do not re-add" is prose, and prose is what failed here.
CAD="$SCRIPT"
live="$(grep -vE '^[[:space:]]*#' "$CAD")"
case "$live" in
  *zaxon_ask*) bad "H1 no live call to zaxon_ask" "it is back -- see the header; 47 sent, 0 answered" ;;
  *)           ok  "H1 no live call to zaxon_ask" ;;
esac
case "$live" in
  *"lib/zaxon.sh"*) bad "H2 it does not even source the relay lib" "sourcing it is how the call comes back" ;;
  *)                ok  "H2 it does not even source the relay lib" ;;
esac
# The escalation still HAPPENS -- only the phone leg is gone. If these three go
# quiet, the cadence has stopped escalating at all, which is a different bug.
has "H3 it still files the issue, which is the durable escalation" "$(cat "$CAD")" 'gh issue create -R "$ISSUE_REPO"'
has "H4 it still dedupes that issue rather than filing per tick" "$(cat "$CAD")" 'already filed as'
has "H5 it still exits 5 so the caller sees an escalation" "$(cat "$CAD")" 'exit 5'

section "I. recovery closes the issue the escalation filed"
# THE HOLE THIS CLOSES. Recovery cleared the streak FILE and stopped there, so
# an issue reading "propagation has been DOWN for two consecutive runs" stayed
# open after propagation came back. And the dedup in section H's H4 matches an
# OPEN issue of that title, so the stale one SUPPRESSED the next real filing --
# the channel escalates once and then goes quiet, which is worse than noisy.
cat > "$T/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
case "$*" in
  *"issue list"*) echo 654 ;;
esac
exit 0
STUB
chmod +x "$T/bin/gh"
recov() { OUT="$(PATH="$T/bin:$PATH" GH_LOG="$T/gh.log" ZAXON='http://127.0.0.1:1/mcp' \
                 AUSCULTE_BIN="$T/bin/ausculte.sh" AUSCULTE_CADENCE_STATE="$T/state" \
                 bash "$SCRIPT" 2>&1)"; RC=$?; }

rm -f "$T/gh.log"; : > "$T/gh.log"
rm -f "$T/state"/*.down "$T/state"/*.blind
stub_ausculte "$DOWN_ROW"
recov; recov                       # first strike, then escalate -- an issue now exists
stub_ausculte "$OK_ROW"
recov                              # the probe recovers
rc "I1 a recovery exits 0" 0 "$RC"
has "I2 it says which issue it closed" "$OUT" "recovered; closed"
has "I3 it actually called gh issue close on the number gh issue list returned" \
    "$(cat "$T/gh.log")" "issue close 654"
[ -f "$T/state/arming.down" ] && bad "I4 the streak file is still cleared" "state file survived" \
  || ok "I4 the streak file is still cleared"

# A SECOND OK MUST NOT CLOSE ANYTHING. Without the streak-file guard this would
# fire a gh call every four hours forever, and would close an issue a HUMAN
# filed under that title after the outage was over.
: > "$T/gh.log"
recov
case "$(cat "$T/gh.log")" in
  *"issue close"*) bad "I5 an OK with no streak on disk closes nothing" "it called gh issue close anyway" ;;
  *)               ok  "I5 an OK with no streak on disk closes nothing" ;;
esac

# BLIND has its own streak, so it must have its own retraction -- section D's
# whole point is that the two never collapse into one.
: > "$T/gh.log"
stub_ausculte '[{"probe":"arming","status":"BLIND","detail":"no credential"}]'
recov; recov
stub_ausculte "$OK_ROW"
recov
has "I6 a recovered BLIND closes the BLIND issue, not the DOWN one" \
    "$(cat "$T/gh.log")" 'has been BLIND'

summary
