#!/usr/bin/env bash
set -uo pipefail  # SUBJECT: provision/vaporwave-wsl2/* -- the standup runbook and its witness (realisateur#695)
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
D="$REPO/provision/vaporwave-wsl2"
harness_tmp
echo "vaporwave-wsl2.test.sh"

section "A. the runbook survives roff -- a mangled command is worse than no runbook"
if command -v man >/dev/null 2>&1; then
  R="$(MANWIDTH=200 man --nh --nj -l "$D/runbook.1" 2>/dev/null)"
  RF="$(printf '%s' "$R" | tr '\n' ' ' | tr -s ' ')"
  has "A1 the import keeps its Windows path separators" "$R" 'wsl.exe --import vaporwave C:\vaporwave'
  has "A2 the socket override lists BOTH address families" "$R" 'ListenStream=0.0.0.0:2225'
  has "A3 ...and the v6 one, which is what a bare ListenStream binds alone" "$R" 'ListenStream=[::]:2225'
  has "A4 the keyscan proof names both ports" "$R" 'ssh-keyscan -p 2225'
  has "A5 ...and monkey's, because the comparison IS the assertion" "$R" 'ssh-keyscan -p 2224'
  has "A6 wsl.conf keeps its section headers" "$R" '[boot]'
  has "A7 dresse is driven from mandark, with --on" "$R" 'dresse --host --on vaporwave --check'
else
  ok "A1-A7 skipped: no man(1) on this runner"
fi

section "B. the hazards it inherits are STATED, not assumed known"
has "B1 --shutdown is named as unavailable, by its cost" "$RF" "stops EVERY distro"
hasnt "B2 ...and the runbook never tells a reader to run it" \
  "$(grep -v '^\.' "$D/runbook.1" | grep -o 'wsl.exe --shutdown')" 'wsl.exe --shutdown'
has "B3 a bare wsl -d is named as hitting the HUMAN CHANNEL" "$RF" "hits Ubuntu, WHICH CARRIES ZACH'S CHANNEL"
has "B4 the shared namespace is stated as the reason ports matter" "$RF" "ONE NETWORK NAMESPACE"
has "B5 2225 is named free, and 22 is named NOT free" "$RF" "22 is NOT free"
has "B6 tailscale is refused with the mechanism, not just banned" "$RF" "ts-input"
has "B7 the guest disk goes on C:, and D: is named as the drive that failed" "$RF" "WD Elements USB"
has "B8 the uid band is the reason svc-vaporwave's 1001 is not reused" "$RF" "uid 1001 is NOT reused"
has "B9 the credential is not copied, with the reason" "$RF" "merges the second quota back into the first"
has "B10 ausculte is named as NOT generic, so symmetry has a stated cost" "$RF" "ausculte' is NOT generic"
has "B11 tier 2 names the owner the estate does not know" "$RF" "media-arts-collective"
has "B12 the build is named as NOT a prerequisite" "$RF" "verb build is NOT a prerequisite"

section "C. constate.sh -- a witness that cannot see says so"
rcv=0; out="$(VAPORWAVE_PORT=2225 timeout 90 bash "$D/constate.sh" --target ssh:no-such-host-here 2>&1)" || rcv=$?
rc  "C1 an unreachable host is BLIND (6), never a pass" 6 "$rcv"
has "C2 ...and says it is not clean" "$out" "NOT a clean host"
rcv=0; bash "$D/constate.sh" --target bogus >/dev/null 2>&1 || rcv=$?
rc  "C3 a malformed --target is a usage error (2)" 2 "$rcv"
rcv=0; bash "$D/constate.sh" --help >/dev/null 2>&1 || rcv=$?
rc  "C4 --help exits 0, the verb contract" 0 "$rcv"
has "C5 it declares it has no baseline, unlike monkey's witness" \
  "$(bash "$D/constate.sh" --help 2>&1)" "no --diff and no baseline"

section "D. the grader's own vocabulary"
S="$(cat "$D/constate.sh")"
has "D1 Running tailscale is the FAILING state, named with its blast radius" "$S" "kills dexter's tailnet"
has "D2 an unreadable tailscale state is BLIND, not a pass" "$S" "is not a state this grades; not a pass"
has "D3 ...and the reason the old probe passed on empty is recorded" "$S" 'last in a pipe exits 0'
has "D4 two identical host keys is a FAILURE, not a match" "$S" "port is not selecting our host"
has "D5 a wsl: target reading ABSENT is BY DESIGN, not a verdict" "$S" "exits 5 BY DESIGN"

summary
