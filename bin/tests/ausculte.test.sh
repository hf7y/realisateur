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
run rot >/dev/null
check "a probe DOWN exits DOWN" "$?" "5"

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
# The count said OK through two days of a refusing cutter. curl/ssh stubbed.
verdict() { printf '#!/usr/bin/env bash\ncat <<'"'"'J'"'"'\n%s\nJ\n' "$1" > "$TMP/stub/curl"; chmod +x "$TMP/stub/curl"; }
fresh="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
old="$(date -u -d '-6 days' +%Y-%m-%dT%H:%M:%SZ)"

verdict "{\"decision\":\"ERROR\",\"blocked_streak\":3,\"cadence_hours\":24,\"grace_hours\":4,\"last_cut\":{\"at\":\"$old\",\"build_id\":\"B\"}}"
out="$(run propagation)"; rc=$?
check "a refusing channel is DOWN (5)" "$rc" "5"
has "and it names the decision and the date nothing has propagated since" "$out" "the channel is ERROR"

# BUILD AGE IS GRADED AGAINST THE CUT INTERVAL, NOT THE EMITTER CADENCE
# (#603). Under a 30-day interval the floor is 30d+28h, so the fixture has to
# be older than that to fail -- at -6d this row used to read DOWN, which is
# exactly the false alarm that would have fired on 29 nights in 30.
ancient="$(date -u -d '-40 days' +%Y-%m-%dT%H:%M:%SZ)"
verdict "{\"decision\":\"CUT\",\"build_id\":\"B\",\"blocked_streak\":0,\"cadence_hours\":24,\"grace_hours\":4,\"cut_interval_days\":30,\"last_cut\":{\"at\":\"$ancient\",\"build_id\":\"B\"}}"
out="$(run propagation)"; rc=$?
check "a build older than its CUT INTERVAL is DOWN (5)" "$rc" "5"
has "and it says the cutter has stopped, not that a cadence slipped" "$out" "the cutter has stopped"

# A DOCUMENT DECLARING NO INTERVAL IS A NIGHTLY ONE: cut_max_h collapses to
# max_h, so a schema-2 verdict grades exactly as it did before #603.
verdict "{\"decision\":\"CUT\",\"build_id\":\"B\",\"blocked_streak\":0,\"cadence_hours\":24,\"grace_hours\":4,\"last_cut\":{\"at\":\"$old\",\"build_id\":\"B\"}}"
out="$(run propagation)"; rc=$?
check "a schema-2 verdict with no cut_interval_days still grades at 28h (5)" "$rc" "5"

verdict "{\"decision\":\"CUT\",\"build_id\":\"B\",\"blocked_streak\":0,\"cadence_hours\":24,\"grace_hours\":4,\"last_cut\":{\"at\":\"$fresh\",\"build_id\":\"B\"}}"
out="$(run propagation)"; rc=$?
# BLIND, not DOWN: could-not-look is typed 6, and still not OK.
check "a fresh cut with an unreachable host is BLIND (6), never OK" "$rc" "6"
has "and the unreadable consumer is named" "$out" "could not read"

printf '#!/usr/bin/env bash\necho OLDBUILD\n' > "$TMP/stub/ssh"; chmod +x "$TMP/stub/ssh"
out="$(run propagation)"; rc=$?
check "a host behind a FRESH cut is OK -- it has not missed its window yet" "$rc" "0"
has "and the row still names who has not adopted" "$out" "not yet adopted by"

verdict "{\"decision\":\"CUT\",\"build_id\":\"B\",\"blocked_streak\":0,\"cadence_hours\":24,\"grace_hours\":4,\"last_cut\":{\"at\":\"$old\",\"build_id\":\"B\"}}"
out="$(run propagation)"; rc=$?
check "a host still behind a build past the window is DOWN (5)" "$rc" "5"

# A QUIET NIGHT IS NOT AN OUTAGE: 5 of the last 54 graded DOWN. NO_CHANGE
# publishes build_id "-", so the hosts are graded against last_cut.
printf '#!/usr/bin/env bash\necho /usr/local/share/verb-builds/B\n' > "$TMP/stub/ssh"
chmod +x "$TMP/stub/ssh"
verdict "{\"decision\":\"NO_CHANGE\",\"build_id\":\"-\",\"blocked_streak\":0,\"cadence_hours\":24,\"grace_hours\":4,\"last_cut\":{\"at\":\"$fresh\",\"build_id\":\"B\"}}"
out="$(run propagation)"; rc=$?
check "a NO_CHANGE night is healthy (0), not DOWN" "$rc" "0"
hasnt "and the channel is never called down for not moving" "$out" "the channel is NO_CHANGE"
has "and the hosts are graded against the last cut, not against \"-\"" "$out" "every host is on it"

verdict "{\"decision\":\"CUT\",\"build_id\":\"B\",\"blocked_streak\":0,\"cadence_hours\":24,\"grace_hours\":4,\"last_cut\":{\"at\":\"$fresh\",\"build_id\":\"B\"}}"
printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/stub/ssh"; chmod +x "$TMP/stub/ssh"

# No propagation-set reachable: BLIND, not a fleet of unreachable hosts.
mv "$TMP/bin/lib/propagation-set.sh" "$TMP/bin/lib/propagation-set.away"
out="$(run propagation)"; rc=$?
check "no propagation-set means BLIND, not unreachable hosts" "$rc" "6"
hasnt "and it never blames the hosts for a missing lib" "$out" "unreachable"
mv "$TMP/bin/lib/propagation-set.away" "$TMP/bin/lib/propagation-set.sh"

# THE MONTHLY CADENCE (#603). Kept at the END of this section on purpose: the
# rows above are order-dependent on which ssh stub is in place, and one that
# reaches the host half-way through changes what a later row measures.
printf '#!/usr/bin/env bash\necho /usr/local/share/verb-builds/B\n' > "$TMP/stub/ssh"; chmod +x "$TMP/stub/ssh"

# The behaviour change, and nothing pinned it before: a monthly channel
# mid-interval is healthy. Twenty days old, every host on it.
midcycle="$(date -u -d '-20 days' +%Y-%m-%dT%H:%M:%SZ)"
verdict "{\"decision\":\"NO_CHANGE\",\"build_id\":\"-\",\"blocked_streak\":0,\"cadence_hours\":24,\"grace_hours\":4,\"cut_interval_days\":30,\"last_cut\":{\"at\":\"$midcycle\",\"build_id\":\"B\"}}"
out="$(run propagation)"; rc=$?
check "a 20-day-old build under a 30-day interval is OK (0)" "$rc" "0"
has "and it says every host is on it" "$out" "every host is on it"

# THE ADOPTION BRANCH, REACHABLE FOR THE FIRST TIME. Before the split there
# was one number, so the build-age test returned DOWN first and the clause
# naming a host that failed to ADOPT could never be true -- a host that never
# took the build was reported as a channel-age problem instead. Here the build
# is well inside cut_max_h, so the only thing wrong is the host.
printf '#!/usr/bin/env bash\necho OLDBUILD\n' > "$TMP/stub/ssh"; chmod +x "$TMP/stub/ssh"
verdict "{\"decision\":\"CUT\",\"build_id\":\"B\",\"blocked_streak\":0,\"cadence_hours\":24,\"grace_hours\":4,\"cut_interval_days\":30,\"last_cut\":{\"at\":\"$old\",\"build_id\":\"B\"}}"
out="$(run propagation)"; rc=$?
check "a host that missed its adoption window under a healthy channel is DOWN (5)" "$rc" "5"
has "and the reason is ADOPTION, not the age of the build" "$out" "adoption window"

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
stub dexter-liveness.sh 0
out="$(run)"; rc=$?
check "a DOWN human channel is never folded into OK, even with everything else clean" "$rc" "5"
first="$(printf '%s\n' "$out" | awk 'NF{print $2; exit}')"
[ "$first" = "channel" ] && ok "the human channel is probed and reported first" \
  || bad "channel probed first" "first row named: $first"

# arming reads the PUBLISHED status, so it answers the same from any host.
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

# The `delivery` and `silence` probes went with their scripts (#511);
# their cases went too, rather than being stubbed against a deleted probe.

echo
echo "-- fleet: the reason an account gives for stopping ---------------------"
fleet() { printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s"\nexit 0\n' "$1" > "$TMP/stub/ssh"; chmod +x "$TMP/stub/ssh"; }

fleet "2026-08-20	monkey	wtul	wtul	batch	0	DONE	fine
FLEET-LEDGERS 1"
out="$(run fleet)"; rc=$?
check "a fleet that finished its last run is OK (0)" "$rc" "0"

# NOT-DONE IS THE HEALTHY STATE, and this suite used to assert the opposite.
# The runner records NOT-DONE for an agent verdict of CONTINUE --
# schedule/_verdict-semantics.md, "there is ACTIONABLE work left". Measured
# 2026-08-22: 9 of 14 accounts read NOT-DONE and six had shipped a merged PR in
# that very run. The old assertion made this row DOWN whenever the fleet was
# working, which is the one failure a health verb may not have.
fleet "2026-08-20	monkey	wtul	wtul	batch	0	NOT-DONE	Landed PR #54 and closed #58; more in the queue
FLEET-LEDGERS 1"
out="$(run fleet)"; rc=$?
check "an account still working, and saying so, is OK (0) -- not DOWN" "$rc" "0"
has  "and the count of accounts still working is reported" "$out" "1 still working"

# A run the runner itself could get no verdict out of is the same silence as a
# blank reason: gardien and scheduler both read this way on 2026-08-22.
fleet "2026-08-20	monkey	gardien	gardien	batch	1	NOT-DONE	no-verdict: ran with no verdict written
FLEET-LEDGERS 1"
out="$(run fleet)"; rc=$?
check "a run that wrote no verdict is DOWN (5) -- the sensor got nothing" "$rc" "5"
has  "and it says so in the account's own words" "$out" "no-verdict"

fleet "2026-08-20	monkey	chezz	chezz	batch	3	NOT-DONE	
FLEET-LEDGERS 1"
out="$(run fleet)"; rc=$?
check "an account that stops without saying why is DOWN" "$rc" "5"
has  "and the silence is NAMED, not printed as an empty message" "$out" "NO REASON RECORDED"
has  "...and the headline counts the SILENT ones, not every NOT-DONE" "$out" "stopped without saying why"

# A GATE THAT CANNOT REACH THE API IS NOT A PACED FLEET -- same silence.
fleet "2026-08-20	monkey	wtul	wtul	batch	0	DONE	fine
FLEET-GATE-ERR realisateur 4
FLEET-LEDGERS 1"
out="$(run fleet)"; rc=$?
check "a gate ERRORing for 2+ ticks is DOWN (5), not a quiet fleet" "$rc" "5"
has  "and it says the accounts are not being held on purpose" "$out" "is being held on purpose"
has  "and it names the account and the count" "$out" "realisateur(4)"

fleet "2026-08-20	monkey	wtul	wtul	batch	0	DONE	fine
FLEET-GATE-ERR realisateur 1
FLEET-LEDGERS 1"
out="$(run fleet)"; rc=$?
check "a single gate error is not yet DOWN -- one tick is a hiccup" "$rc" "0"

fleet "2026-08-20	monkey	wtul	wtul	batch	0	DONE	fine
FLEET-PULL realisateur 3 fetch-failed 0
FLEET-LEDGERS 1"
out="$(run fleet)"; rc=$?
check "a checkout frozen 3+ ticks is DOWN (5); the runner will not self-heal" "$rc" "5"
has  "and says a merged fix cannot land" "$out" "cannot land"

# THE FALSE OK THIS PROBE WAS BORN WITH: it globbed a path no account had.
fleet "FLEET-LEDGERS 0"
out="$(run fleet)"; rc=$?
check "zero ledgers is BLIND (6), not a quiet fleet" "$rc" "6"
has  "and it says it cannot tell" "$out" "cannot tell"

printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/stub/ssh"; chmod +x "$TMP/stub/ssh"
out="$(run fleet)"; rc=$?
check "an unreachable host is BLIND (6)" "$rc" "6"

# ON THE HOST ITSELF, THERE IS NOTHING TO SSH TO. The cadence runs as root on
# monkey, where root has an empty authorized_keys and no known_hosts, so
# `ssh monkey` from monkey failed host key verification and this row was BLIND
# on the one machine holding the files. ssh stays stubbed FAILING here: if the
# local path were not taken the message would be the ssh fallback's.
printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/stub/ssh"; chmod +x "$TMP/stub/ssh"
out="$(PATH="$TMP/stub:$PATH" AUSCULTE_FLEET_HOST=selfhost SELFDEV_LOCAL_HOSTNAME=selfhost \
       bash "$TMP/bin/ausculte.sh" fleet 2>&1)"; rc=$?
check "reading its OWN host needs no ssh -- still BLIND here, but for the right reason" "$rc" "6"
has  "and the reason is an empty fleet, not an unreachable one" "$out" "no account has a paced-runner ledger"
hasnt "so the ssh fallback was never taken" "$out" "could not read the accounts"

echo
echo "-- NOT-MINE: the containment boundary is not a failure -----------------"
# monkey is a VirtualBox GUEST on dexter. A guest holding shell on its own
# hypervisor is backwards, so root@monkey has an empty authorized_keys and no
# key at all -- and with only OK/DOWN/BLIND the `hosts` row could report that
# correct arrangement ONLY as BLIND: an alarm that can never clear, which
# trains its reader to ignore the row and then the verb. Ashby S.8/7, the
# argument this file keeps making: a transducer with fewer output values than
# its input has distinct states loses distinctions.
stub decision-rot.sh 0
out="$(PATH="$TMP/stub:$PATH" SELFDEV_LOCAL_HOSTNAME=monkey bash "$TMP/bin/ausculte.sh" hosts 2>&1)"; rc=$?
case "$out" in *NOT-MINE*) ok "on the guest, hosts is NOT-MINE -- not BLIND" ;;
  *) bad "hosts is NOT-MINE on monkey" "got: $out" ;; esac
check "...and NOT-MINE is not an alarm: exit 0, neither 5 nor 6" "$rc" "0"
case "$out" in *monkey-watch*) ok "...and it NAMES who answers instead, so the question is not merely dropped" ;;
  *) bad "NOT-MINE names the owner" "got: $out" ;; esac

# A HOST OMITTED WITHOUT SAYING SO is how a partial answer reads as a complete
# one. Every propagation verdict has to carry the host it was not allowed to
# ask -- so the row needs a READABLE channel verdict to get that far, the same
# fixture the cut tests above use.
verdict "{\"decision\":\"CUT\",\"build_id\":\"B\",\"blocked_streak\":0,\"cadence_hours\":24,\"grace_hours\":4,\"last_cut\":{\"at\":\"$fresh\",\"build_id\":\"B\"}}"
out="$(PATH="$TMP/stub:$PATH" SELFDEV_LOCAL_HOSTNAME=monkey bash "$TMP/bin/ausculte.sh" propagation 2>&1)"
case "$out" in *"not asked from here"*) ok "propagation names the host it did not ask, so a partial answer cannot read as a complete one" ;;
  *) bad "propagation names the skipped host" "got: $out" ;; esac
case "$out" in *dexter*) ok "...and names WHICH host, not just that one was skipped" ;;
  *) bad "the skipped host is named" "got: $out" ;; esac

# Off the guest, nothing changes: mandark still asks dexter directly.
out="$(PATH="$TMP/stub:$PATH" SELFDEV_LOCAL_HOSTNAME=mandark bash "$TMP/bin/ausculte.sh" hosts 2>&1)"
case "$out" in *NOT-MINE*) bad "off-guest hosts still probes dexter" "it went NOT-MINE on mandark" ;;
  *) ok "off the guest the row still probes dexter -- the boundary is monkey's, not everyone's" ;; esac

summary
