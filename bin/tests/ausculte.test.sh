#!/usr/bin/env bash
# SUBJECT: bin/ausculte.sh. Hermetic -- every composed probe is a stub and
# curl/ssh/gh are stubbed failing, so this cannot pass because the fleet
# happened to be healthy. The exit ladder IS the contract, pinned rung by rung.
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected [$3] got [$2]"; fi; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin/lib"
cp "$HERE/../ausculte.sh" "$TMP/bin/"
cp "$HERE/../lib/cli-guard.sh" "$TMP/bin/lib/"
cp "$HERE/../lib/host-check.sh" "$TMP/bin/lib/"
cp "$HERE/../lib/zaxon.sh" "$TMP/bin/lib/"
cp "$HERE/../lib/propagation-set.sh" "$TMP/bin/lib/"

stub() { printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s"\nexit %s\n' "${3:-}" "$2" > "$TMP/bin/$1"; chmod +x "$TMP/bin/$1"; }

mkdir -p "$TMP/stub"
for c in curl ssh gh; do printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/stub/$c"; chmod +x "$TMP/stub/$c"; done
run() { PATH="$TMP/stub:$PATH" bash "$TMP/bin/ausculte.sh" "$@" 2>&1; }

echo "ausculte contract"

stub decision-rot.sh 0
run rot >/dev/null; check "a clean probe exits 0" "$?" "0"

stub decision-rot.sh 1 "answered and still open"
run rot >/dev/null; check "a probe reporting rot is DOWN (5)" "$?" "5"

stub decision-rot.sh 2 "usage"
out="$(run rot)"; check "a usage error from a probe is BLIND, not DOWN" "$?" "6"
case "$out" in *"fix ausculte"*) ok "...and it says the fault is ausculte's" ;;
  *) bad "usage error names itself" "got: $out" ;; esac

rm -f "$TMP/bin/decision-rot.sh"
out="$(run rot)"; check "a missing probe is BLIND (6), never OK" "$?" "6"
case "$out" in *"NOT \"all clear\""*) ok "...and the summary refuses to read as all-clear" ;;
  *) bad "blind summary" "got: $out" ;; esac

stub decision-rot.sh 1 "rot found"
stub silence-audit.sh 2 "usage"
run rot silence >/dev/null
check "one probe DOWN and one BLIND exits DOWN" "$?" "5"

# --- arming reads what the accounts DID ----------------------------------
# Counting the word "armed" said OK while three accounts had been dead eight
# days. And the first draft of the fix printed OK off a jq error, because the
# ledger writes "+00:00" and fromdateiso8601 accepts only "Z".
status() { printf '#!/usr/bin/env bash\ncat <<'"'"'J'"'"'\n%s\nJ\n' "$1" > "$TMP/stub/curl"; chmod +x "$TMP/stub/curl"; }
recent="$(date -u -d '-1 hour' +%Y-%m-%dT%H:%M:%S+00:00)"
old_run="$(date -u -d '-9 days' +%Y-%m-%dT%H:%M:%S+00:00)"

status "{\"accounts\":[{\"account\":\"live\",\"armed\":true,\"last_run\":{\"started_at\":\"$recent\"}}]}"
out="$(run arming)"; rc=$?
check "an account that dispatched recently is OK" "$rc" "0"
has "and the offset form is parsed, not fatal" "$out" "OK      arming"

status "{\"accounts\":[{\"account\":\"dead\",\"armed\":true,\"last_run\":{\"started_at\":\"$old_run\"}}]}"
out="$(run arming)"; rc=$?
check "an armed account that stopped dispatching is DOWN (5)" "$rc" "5"
has "and it is named" "$out" "dead"

# No run record is BLIND, not DOWN: three accounts dispatch and write none at
# all (hf7y/scheduler#259), so the document cannot say either way.
status "{\"accounts\":[{\"account\":\"never\",\"armed\":true,\"last_run\":null}]}"
out="$(run arming)"; rc=$?
check "an armed account with no run record is BLIND (6), not DOWN" "$rc" "6"
has "and it is named too" "$out" "never"
hasnt "and it is never called not-dispatching" "$out" "not dispatching"

status "{\"nonsense\":true}"
out="$(run arming)"; rc=$?
check "a status document with no accounts is BLIND (6)" "$rc" "6"
hasnt "and never reports an account count it did not read" "$out" "account(s) armed"

# --- propagation reads the channel's VERDICT, not the verb count ---------
# The count said OK through two days of a refusing cutter, because every host
# still held its full set of verbs. These pin the three answers the verdict
# gives, with curl stubbed to serve a fixture and ssh stubbed failing.
verdict() { printf '#!/usr/bin/env bash\ncat <<'"'"'J'"'"'\n%s\nJ\n' "$1" > "$TMP/stub/curl"; chmod +x "$TMP/stub/curl"; }
fresh="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
old="$(date -u -d '-6 days' +%Y-%m-%dT%H:%M:%SZ)"

verdict "{\"decision\":\"ERROR\",\"blocked_streak\":3,\"cadence_hours\":24,\"grace_hours\":4,\"last_cut\":{\"at\":\"$old\",\"build_id\":\"B\"}}"
out="$(run propagation)"; rc=$?
check "a refusing channel is DOWN (5)" "$rc" "5"
has "and it names the decision and the date nothing has propagated since" "$out" "the channel is ERROR"

verdict "{\"decision\":\"CUT\",\"build_id\":\"B\",\"blocked_streak\":0,\"cadence_hours\":24,\"grace_hours\":4,\"last_cut\":{\"at\":\"$old\",\"build_id\":\"B\"}}"
out="$(run propagation)"; rc=$?
check "a build older than its cadence is DOWN (5)" "$rc" "5"
has "and it names the age against the cadence" "$out" "past its 28h cadence"

verdict "{\"decision\":\"CUT\",\"build_id\":\"B\",\"blocked_streak\":0,\"cadence_hours\":24,\"grace_hours\":4,\"last_cut\":{\"at\":\"$fresh\",\"build_id\":\"B\"}}"
out="$(run propagation)"; rc=$?
check "a fresh cut with an unreachable host is DOWN, not OK" "$rc" "5"
has "and the unreachable consumer is named" "$out" "unreachable"

# No propagation-set reachable: BLIND, not a fleet of unreachable hosts.
mv "$TMP/bin/lib/propagation-set.sh" "$TMP/bin/lib/propagation-set.away"
out="$(run propagation)"; rc=$?
check "no propagation-set means BLIND, not unreachable hosts" "$rc" "6"
hasnt "and it never blames the hosts for a missing lib" "$out" "unreachable"
mv "$TMP/bin/lib/propagation-set.away" "$TMP/bin/lib/propagation-set.sh"

printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/stub/curl"; chmod +x "$TMP/stub/curl"
out="$(run propagation)"; rc=$?
check "an unreadable verdict is BLIND (6), never OK" "$rc" "6"
has "and it says it could not read the verdict" "$out" "cannot read the release channel verdict"

run nosuchprobe >/dev/null; check "an unknown probe is a usage error (2)" "$?" "2"

out="$(run channel)"; rc=$?
check "channel is DOWN (5) when no zaxon relay answers" "$rc" "5"
case "$out" in *"no zaxon relay answered"*) ok "...and it names why" ;;
  *) bad "channel DOWN detail" "got: $out" ;; esac

stub decision-rot.sh 0
stub silence-audit.sh 0
stub dexter-liveness.sh 0
out="$(run)"; rc=$?
check "a DOWN human channel is never folded into OK, even with everything else clean" "$rc" "5"
first="$(printf '%s\n' "$out" | awk 'NF{print $2; exit}')"
[ "$first" = "channel" ] && ok "the human channel is probed and reported first" \
  || bad "channel probed first" "first row named: $first"

# arming reads the PUBLISHED status, so it answers the same from any host and
# never needs root or a collector installed where it happens to be running.
printf '#!/usr/bin/env bash\necho called >> "%s/ssh_called"\nexit 255\n' "$TMP" > "$TMP/stub/ssh"
chmod +x "$TMP/stub/ssh"
out="$(run arming)"; rc=$?
check "an unreadable status document is BLIND (6)" "$rc" "6"
case "$out" in *"could not be read"*) ok "...and it names why" ;;
  *) bad "arming BLIND detail" "got: $out" ;; esac
[ -f "$TMP/ssh_called" ] \
  && bad "the arming probe never shells out to ssh" "ssh was invoked" \
  || ok "the arming probe never shells out to ssh"

expired="$(date -u -d '-2 days' +%Y-%m-%dT%H:%M:%SZ)"
status "{\"valid_until\":\"$expired\",\"accounts\":[{\"account\":\"a\",\"armed\":true,\"last_run\":{\"started_at\":\"$recent\"}}]}"
out="$(run arming)"; rc=$?
check "a status document past its own valid_until is BLIND (6)" "$rc" "6"
has "and it says nothing is publishing it" "$out" "expired at"

echo
echo "-- delivery: an unmet claim is DOWN, an absent ledger is BLIND ---------"
stub delivery-audit.sh 0 "3 PR(s) audited; 4 met, 0 UNMET, 0 blind (0 carried no ledger)."
out="$(run delivery)"; rc=$?
check "every claim met is OK (0)" "$rc" "0"
has  "and it carries the count" "$out" "PR(s) audited"

printf '#!/usr/bin/env bash\nprintf "  UNMET  #436  path:/x is NOT on monkey\\n"\nexit 1\n' > "$TMP/bin/delivery-audit.sh"
chmod +x "$TMP/bin/delivery-audit.sh"
out="$(run delivery)"; rc=$?
check "a merged PR claiming a delivery that is not there is DOWN (5)" "$rc" "5"

stub delivery-audit.sh 6 "0 PR(s) audited; 0 met, 0 UNMET, 2 blind (2 carried no ledger)."
out="$(run delivery)"; rc=$?
check "claims that could not be checked are BLIND (6), never OK" "$rc" "6"

rm -f "$TMP/bin/delivery-audit.sh"
out="$(run delivery)"; rc=$?
check "no delivery-audit at all is BLIND (6)" "$rc" "6"
has  "and it says which part is missing" "$out" "delivery-audit not present"

echo
echo "-- fleet: the reason an account gives for stopping ---------------------"
fleet() { printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s"\nexit 0\n' "$1" > "$TMP/stub/ssh"; chmod +x "$TMP/stub/ssh"; }

fleet "2026-08-20	monkey	wtul	wtul	batch	0	DONE	fine
FLEET-LEDGERS 1"
out="$(run fleet)"; rc=$?
check "a fleet that finished its last run is OK (0)" "$rc" "0"

fleet "2026-08-20	monkey	wtul	wtul	batch	0	NOT-DONE	blocked on a GitHub Actions billing failure -- needs Zach
FLEET-LEDGERS 1"
out="$(run fleet)"; rc=$?
check "an account that ended NOT-DONE is DOWN (5)" "$rc" "5"
has  "and the report carries the account's own words" "$out" "billing failure"

# THE FALSE OK THIS PROBE WAS BORN WITH: it globbed a path no account had.
fleet "FLEET-LEDGERS 0"
out="$(run fleet)"; rc=$?
check "zero ledgers is BLIND (6), not a quiet fleet" "$rc" "6"
has  "and it says it cannot tell" "$out" "cannot tell"

printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/stub/ssh"; chmod +x "$TMP/stub/ssh"
out="$(run fleet)"; rc=$?
check "an unreachable host is BLIND (6)" "$rc" "6"

echo
summary
