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

section "F. --install-cadence writes nothing without --apply"
before="$(crontab -l 2>/dev/null | md5sum)"
run --install-cadence
has "F1 it prints the line it would install" "$OUT" "realisateur:ausculte:CADENCE"
eq "F2 the crontab is untouched" "$(crontab -l 2>/dev/null | md5sum)" "$before"

summary
