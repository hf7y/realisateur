#!/usr/bin/env bash
#
# Cases:
#   A --check runs every host step and writes nothing
#   B a step that exits nonzero under --check is a GAP, not a refusal
#   C exit 6 from a step is BLIND -- never folded into GAP, never "ok"
#   D --apply as non-root refuses (exit 2); no step runs
#   E a provision-class script no step reaches is PRINTED as uncovered
#   F a step whose script is not provision-class is a BAD plan (exit 1)
#   G no propagation set -> BLIND, exit 6
#
# Usage: bin/tests/dresse.test.sh   (exit 0 = all pass)

set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
REPO_BIN="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$REPO_BIN/dresse.sh" ] || { echo "FAIL: no dresse.sh"; exit 1; }
harness_tmp

# A stub estate: dresse.sh, the cli-guard it sources, and stand-in steps whose
# exit codes the cases drive. Real steps would need root and a real host.
mkdir -p "$T/bin/lib"
cp "$REPO_BIN/dresse.sh" "$T/bin/"
cp "$REPO_BIN/lib/cli-guard.sh" "$T/bin/lib/"
D="$T/bin/dresse.sh"
RAN="$T/ran.log"

stub() { # stub <name> <exit code>
  printf '#!/usr/bin/env bash\necho "%s: $*" >> "%s"\nexit %s\n' "$1" "$RAN" "$2" > "$T/bin/$1"
  chmod +x "$T/bin/$1"
}

# The propagation set the stub reads. Same variable names and same
# prop_channel contract as the real one; nothing else is needed here.
write_set() { # write_set <provision-list>
  cat > "$T/bin/lib/propagation-set.sh" <<EOF
PROP_PROVISION_SCRIPTS="
$1
"
prop_channel() {
  local n="\$1" s
  for s in \$PROP_PROVISION_SCRIPTS; do [ "\$s" = "\$n" ] && { echo provision; return 0; }; done
  return 1
}
EOF
}

STEPS='dresse.sh
setup-selfdev-project.sh
selfdev-app-key.sh
selfdev-claude-token.sh
wire-release-channel.sh
selfdev-permissions-provision.sh
selfdev-hooks-provision.sh'

write_set "$STEPS
pivot.sh"
for s in selfdev-app-key.sh selfdev-claude-token.sh wire-release-channel.sh \
         selfdev-permissions-provision.sh selfdev-hooks-provision.sh; do stub "$s" 0; done

section "A. --check runs the plan and writes nothing"
: > "$RAN"
out="$(bash "$D" --host --check 2>&1)"; rcv=$?
rc "A1 exit 0 when every step is satisfied" 0 "$rcv"
has "A2 the App key step ran" "$(cat "$RAN")" "selfdev-app-key.sh: --check"
has "A3 the channel step ran with --host" "$(cat "$RAN")" "wire-release-channel.sh: --host --check"
has "A4 says nothing was done" "$out" "nothing done (--check)"
APPLY_FLAG=--apply
hasnt "A5 no step was told --apply" "$(cat "$RAN")" "$APPLY_FLAG"

section "B. nonzero under --check is a GAP, not a refusal"
stub selfdev-app-key.sh 1
out="$(bash "$D" --host --check 2>&1)"; rcv=$?
has "B1 reported as GAP" "$out" "GAP     selfdev-app-key.sh"
rc  "B2 still exit 0 -- work to do is not a refusal" 0 "$rcv"

section "C. exit 6 is BLIND and is never clean"
stub selfdev-app-key.sh 6
out="$(bash "$D" --host --check 2>&1)"; rcv=$?
has "C1 reported as BLIND" "$out" "BLIND   selfdev-app-key.sh"
hasnt "C2 not called a gap" "$out" "GAP     selfdev-app-key.sh"
rc  "C3 exit 1 -- a step that could not look fails the run" 1 "$rcv"
stub selfdev-app-key.sh 0

section "D. --apply as non-root refuses before any step"
: > "$RAN"
out="$(bash "$D" --host --apply 2>&1)"; rcv=$?
rc "D1 exit 2" 2 "$rcv"
has "D2 names root" "$out" "must run as root"
eq  "D3 no step ran" "$(cat "$RAN")" ""

section "E. an unreached provision-class script is printed"
out="$(bash "$D" --host --check 2>&1)"
has "E1 pivot.sh named as uncovered" "$out" "not covered by dresse: pivot.sh"
hasnt "E2 dresse does not report itself" "$out" "not covered by dresse: dresse.sh"

section "F. a step outside the provisioning set is a bad plan"
: > "$RAN"
write_set "dresse.sh
setup-selfdev-project.sh
selfdev-app-key.sh"
out="$(bash "$D" --host --check 2>&1)"; rcv=$?
has "F1 names the undeclared step" "$out" "is not provision-class"
rc  "F2 exit 1" 1 "$rcv"
eq  "F3 no step ran on a bad plan" "$(cat "$RAN")" ""

section "G. no propagation set is BLIND, never clean"
rm -f "$T/bin/lib/propagation-set.sh"
out="$(bash "$D" --host --check 2>&1)"; rcv=$?
rc "G1 exit 6" 6 "$rcv"
has "G2 says BLIND" "$out" "BLIND"

summary
