#!/usr/bin/env bash
# cutover-check.test.sh -- witness for bin/cutover-check.sh.
#
# HERMETIC: CUTOVER_SSH points at a stub that prints a fixture instead of
# reaching a host, so this suite grades the GRADING and never the estate. CI
# has no route to vaporwave or monkey, and a check that quietly passed when it
# could not look is the exact defect cutover-check exists to refuse.
#
# The fixtures are the two real hosts as measured 2026-09-08: vaporwave clean
# but for its conf rows, monkey with everything still in front of it.
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/bin/cutover-check.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

harness_tmp
echo "cutover-check.test.sh"

cat > "$T/ssh" <<'EOF'
#!/usr/bin/env bash
[ -n "${FACTS_FILE:-}" ] || { echo "stub ssh: no FACTS_FILE" >&2; exit 255; }
[ "$FACTS_FILE" = UNREACHABLE ] && { echo "ssh: connect to host port 22: No route to host" >&2; exit 255; }
cat "$FACTS_FILE"
EOF
chmod +x "$T/ssh"
run() { FACTS_FILE="$1" CUTOVER_SSH="$T/ssh" "$SCRIPT" --host fixture 2>&1; }

# --- a host that has fully crossed ------------------------------------------
cat > "$T/clean" <<'EOF'
PROBE-OK
BUILD 2026-09-08T031951Z
ACCT dog
ROOTCRON 1
ROOTROSTER ok
GATE ok
SERVICEREAD ok
EOF

# --- a host with everything still in front of it ----------------------------
cat > "$T/dirty" <<'EOF'
PROBE-OK
BUILD 2026-09-07T031807Z
ACCT ecosim
CLONE ecosim
PRIVATEPIN ecosim
ACCTSTATE ecosim
ACCTCRON ecosim
ROOTCRON 0
ROOTROSTER fail
GHROSTER present
CLONEPATHCONF _paced.monkey.conf
EOF

section "A. a crossed host passes, and says so"
OUT="$(run "$T/clean")"; RC=$?
rc  "A1 a fully crossed host exits 0" 0 "$RC"
has "A2 names the credential-free root read"  "$OUT" "A1 root reads the roster"
has "A3 names the service read"               "$OUT" "A2 the installed build"
has "A4 no residue rows fire"                 "$OUT" "B1 no account carries a scheduler clone"

section "B. residue is reported even when the new half works"
OUT="$(run "$T/dirty")"; RC=$?
rc  "B1 a host with residue exits 1" 1 "$RC"
has "B2 a clone is named, with the account"      "$OUT" "scheduler clone(s) remain: ecosim"
has "B3 a per-account RUNNER row is named"       "$OUT" "still carry their own RUNNER row: ecosim"
has "B4 a private build pin is named"            "$OUT" "keep a private build root: ecosim"
has "B5 account-mode rotation state is named"    "$OUT" "scheduler-paced-runner: ecosim"
has "B6 a conf naming a clone path is named"     "$OUT" "_paced.monkey.conf"
has "B7 the gh roster read is caught"            "$OUT" "fetch_roster still goes through gh"

section "C. counts reconcile with their own lists"
# A count that cannot be reconciled with the names beside it is worse than no
# count: `^CLONE` also matches CLONEPATHCONF, and this check once reported
# seven clones and then named none of them.
case "$OUT" in
  *"1 scheduler clone(s) remain: ecosim"*) ok "C1 one CLONE row counts one, not one-per-prefix-match" ;;
  *) bad "C1 the clone count does not match its list" "$(printf '%s\n' "$OUT" | grep 'clone(s) remain')" ;;
esac

section "D. BLIND is never clean"
OUT="$(FACTS_FILE=UNREACHABLE CUTOVER_SSH="$T/ssh" "$SCRIPT" --host fixture 2>&1)"; RC=$?
rc  "D1 an unreachable host exits 6, not 0 and not 1" 6 "$RC"
has "D2 and says BLIND"                     "$OUT" "BLIND"
has "D3 and says nothing was verified"      "$OUT" "nothing was verified"
hasnt "D4 and claims no passing rows"       "$OUT" "no account carries a scheduler clone"

printf '%s\n' > /dev/null
OUT="$(printf 'garbage\n' > "$T/truncated"; run "$T/truncated")"; RC=$?
rc  "D5 a probe that did not complete is BLIND too" 6 "$RC"

printf '\ncutover-check.test.sh: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
