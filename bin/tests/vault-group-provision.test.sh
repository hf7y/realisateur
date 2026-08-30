#!/usr/bin/env bash
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/vault-group-provision.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

harness_tmp

echo "vault-group-provision.test.sh"

section "A. the argument contract"
"$SCRIPT" --not-a-real-flag >/dev/null 2>&1; eq "A1 unknown flag exits 2" "$?" "2"
"$SCRIPT" --help >/dev/null 2>&1;            eq "A2 --help exits 0" "$?" "0"
OUT="$("$SCRIPT" --help 2>&1)"
has "A3 --help documents the BLIND exit" "$OUT" "BLIND"
has "A4 --help documents the refused-without-root exit" "$OUT" "refused"

section "B. an empty roster is BLIND, not a silent pass"
mkdir -p "$T/emptyhome"
OUT="$(HOME_ROOT="$T/emptyhome" SUDO='' "$SCRIPT" --check 2>&1)"; RC=$?
eq  "B1 no accounts under HOME_ROOT exits 6" "$RC" "6"
has "B2 and says BLIND" "$OUT" "BLIND"
has "B3 and says nothing was measured" "$OUT" "nothing was measured"

section "C. a roster with one account, no privilege needed to read it (SUDO='')"
mkdir -p "$T/home/proj/.claude" "$T/home/zach/.claude"
OUT="$(HOME_ROOT="$T/home" SUDO='' "$SCRIPT" --check --group nonexistent-test-group 2>&1)"; RC=$?
has "C1 the fixture account is listed" "$OUT" "proj"
hasnt "C2 zach is excluded from the roster" "$OUT" "  ..      zach"
eq  "C3 a group that does not exist is a finding (exit 1), not exit 6" "$RC" "1"

section "D. --apply without root is refused, --check never needs it"
if [ "$(id -u)" -eq 0 ]; then
  ok "D1 skipped: running as root"
else
  OUT="$("$SCRIPT" --apply 2>&1)"; RC=$?
  eq  "D1 --apply without root exits 5" "$RC" "5"
  has "D1b and says so" "$OUT" "needs root"
fi
grep -q 'rm -rf' "$SCRIPT" && bad "D2 the script contains an rm -rf" || ok "D2 no rm -rf anywhere in the script"

section "F. the read door (#742): the spool, its clock, and the interlock"
mkdir -p "$T/home2/proj/.claude" "$T/vaultdir" "$T/fakebin"
chmod 2775 "$T/vaultdir"
OUT="$(HOME_ROOT="$T/home2" SUDO='' PATH="$T/fakebin:$PATH" \
       "$SCRIPT" --check --dir "$T/vaultdir" --spool "$T/no-spool" 2>&1)"
has "F1 a missing spool is a finding -- deposits would have nowhere to go" "$OUT" "no-spool does not exist"
has "F2 an undrained spool is a finding -- a queue nothing drains is a backlog" "$OUT" "does not drain the spool"

OUT="$(HOME_ROOT="$T/home2" SUDO='' PATH="$T/fakebin:$PATH" \
       "$SCRIPT" --check --dir "$T/vaultdir" 2>&1)"
has "F3 with no spool-capable consigne on PATH, tightening is REFUSED" "$OUT" "cannot spool"
has "F4 and it names the remedy -- install the build first" "$OUT" "verb build"

printf '#!/bin/sh\n# CONSIGNE_SPOOL\n' > "$T/fakebin/consigne"; chmod +x "$T/fakebin/consigne"
OUT="$(HOME_ROOT="$T/home2" SUDO='' PATH="$T/fakebin:$PATH" \
       "$SCRIPT" --check --dir "$T/vaultdir" 2>&1)"
hasnt "F5 with a spool-capable consigne the interlock stands down" "$OUT" "cannot spool"
has   "F6 and 2775 is then reported as the open door it is" "$OUT" "the read door is open"

chmod 0700 "$T/vaultdir"; chmod g-s "$T/vaultdir"   # numeric chmod does NOT clear setgid on a dir
OUT="$(HOME_ROOT="$T/home2" SUDO='' PATH="$T/fakebin:$PATH" \
       "$SCRIPT" --check --dir "$T/vaultdir" 2>&1)"
has "F7 0700 is the target, and is reported as shut" "$OUT" "read door is shut"

chmod 2700 "$T/vaultdir"
OUT="$(HOME_ROOT="$T/home2" SUDO='' PATH="$T/fakebin:$PATH" \
       "$SCRIPT" --check --dir "$T/vaultdir" 2>&1)"
has "F8 2700 is NOT shut -- a preserved setgid bit must not read as the target" "$OUT" "read door is open"

section "E. it is declared, so it reaches a host by a named channel"
. "$ROOT/lib/propagation-set.sh"
ch="$(prop_channel vault-group-provision.sh 2>/dev/null)" || ch=""
eq "E1 prop_channel says provision -- a human runs this once, on nobody's clock" "$ch" "provision"

echo
summary
