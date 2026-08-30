#!/usr/bin/env bash
set -uo pipefail  # SUBJECT: provision/monkey-wsl2/* -- the migration runbook and its witness (senechal#438)
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
D="$REPO/provision/monkey-wsl2"
harness_tmp
echo "monkey-wsl2.test.sh"

section "A. the runbook survives roff -- a mangled command is worse than no runbook"
if command -v man >/dev/null 2>&1; then
  R="$(MANWIDTH=200 man --nh --nj -l "$D/runbook.1" 2>/dev/null)"
  RF="$(printf '%s' "$R" | tr '\n' ' ' | tr -s ' ')"   # flattened: roff re-wraps prose, so sentence assertions match RF while command assertions match R, where a broken line IS the bug
  has "A1 the import command keeps its Windows path separators" "$R" 'wsl.exe --import monkey D:\wsl-migration\monkey'
  has "A2 the rollback keeps VBoxManage's quoted program path" "$R" "'C:\\Program Files\\Oracle\\VirtualBox\\VBoxManage.exe' startvm monkey"
  has "A3 the fstab fix keeps its sed delimiters and ampersand" "$R" "sed -i 's|^/dev/disk/by-uuid|#&|; s|^/swapfile|#&|' /etc/fstab"
  has "A4 the rehearsal still drops monkey's tailscale identity" "$R" '--exclude=./var/lib/tailscale'
  has "A11 ...and says the cutover KEEPS it, with what depends on it" "$RF" "12 runner registrations"
  has "A12 a green backend line is not mistaken for the verification" "$RF" "A green backend line is NOT the verification"
  has "A13 the shutdown window puts autoMemoryReclaim under [experimental]" "$R" "[experimental]"
  has "A14 ...and restores the human channel rather than assuming it" "$RF" "zaxon-relay-mcp whisper-server zaxon-relay-watcher hermes-gateway"
  has "A15 ...and drives the window from the route that survives it" "$RF" "Drive the whole window from port 22"
  has "A16 absence from the distro list is not failure, and the retry error is named" "$R" "Wsl/Service/RegisterDistro/0x8000000d"
  has "A17 the import survives the shell that launched it" "$RF" "does not stop the import"
  has "A18 ...so it is not wrapped in a short timeout" "$RF" "too short here by a factor of four"
  has "A5 --terminate is named, and --shutdown is named as the hazard" "$R" 'wsl --terminate'
  has "A7 the runners are DISABLED -- the rehearsal proved mask does not hold them" "$RF" "systemctl mask DOES NOT WORK ON THE RUNNER UNITS"
  has "A19 ...and the .wants count is checked before systemd ever starts" "$RF" "must print 0 BEFORE systemd is ever started"
  has "A20 ufw and ssh are disarmed because the netns is shared" "$RF" "ufw would install iptables rules"
  has "A21 a rehearsal's expected rc=5 fields are named, not read as faults" "$RF" "A rehearsal legitimately exits 5"
  has "A22 interop can break after --terminate, and the repair is named" "$RF" "systemd-binfmt"
  has "A23 the cutover is recorded as deliberately not run by an agent" "$RF" "needs Zach's go, not an agent's"
  has "A24 the live wedge progression is recorded where the operator reads it" "$RF" "monkey is degrading now"
  has "A25 the operator is pointed at the unresponsiveness, not the clock stall" "$RF" "Read the 390 s, not the 415 s"
  has "A26 the post-migration queue is in the file, not in someone's head" "$RF" "POST-MIGRATION QUEUE"
  has "A27 ...and each parked item carries the evidence it rests on" "$RF" "ghost registration, not a runner that fell over"
  has "A28 the channel cutover records WHY hermes blocked the containers" "$RF" "address already in use"
  has "A29 ...and which side won the split-brain merge, with the one exception" "$RF" "HERMES_LOCAL_STT_COMMAND"
  has "A8 ...and says why: they would contend with the live fleet's agents" "$RF" "SAME agents as the live monkey"
  has "A9 --shutdown's blast radius names the human channel" "$R" "zaxon-relay-mcp.service"
  has "A10 it says a probe inside a distro cannot identify what it measured" "$R" "cannot tell you which distro it measured"
else
  ok "A1-A5 skipped: no man(1) on this runner"
fi
hasnt "A6 the runbook does not tell a reader to run --shutdown" \
  "$(grep -v '^\.' "$D/runbook.1" | grep -o 'wsl\.exe --shutdown')" 'wsl.exe --shutdown'

section "B. constate.sh -- a witness that cannot see says so, it does not pass empty"
printf 'PATH stub\n' > /dev/null
mkdir -p "$T/bin"
cat > "$T/bin/ssh" <<'STUB'
#!/bin/sh
cat "$STUB_REPLY" 2>/dev/null
STUB
chmod +x "$T/bin/ssh"
export STUB_REPLY="$T/reply"
: > "$STUB_REPLY"
PATH="$T/bin:$PATH" "$D/constate.sh" >/dev/null 2>&1; rc "B1 an unreadable host is BLIND (6), never a clean 0" 6 $?
printf 'machine_id\tabc\nbackend\toracle\n' > "$STUB_REPLY"
out="$(PATH="$T/bin:$PATH" "$D/constate.sh" 2>/dev/null)"; rc "B2 a readable host exits 0" 0 $?
has "B3 ...and the snapshot is passed through as key<TAB>value" "$out" "machine_id	abc"
"$D/constate.sh" --target nonsense:x >/dev/null 2>&1; rc "B4 an unknown --target is a usage error (2)" 2 $?
"$D/constate.sh" --diff "$T/no-such-file" >/dev/null 2>&1; rc "B5 an unreadable --diff baseline is a usage error (2)" 2 $?

section "C. constate.sh --diff -- identity must hold, and backend must flip"
printf 'machine_id\tabc\nhostname\tmonkey\nbackend\toracle\nts_nodeid\tNODE1\nrunners_active\t12\nlong_readout\t4\n' > "$T/before.tsv"
printf 'machine_id\tabc\nhostname\tmonkey\nbackend\twsl\nts_nodeid\tNODE1\nrunners_active\t12\nlong_readout\t0\n' > "$STUB_REPLY"
g="$(PATH="$T/bin:$PATH" "$D/constate.sh" --diff "$T/before.tsv" 2>/dev/null)"; rc "C1 a clean migration exits 0" 0 $?
has "C2 the backend flip is reported as a FLIP, not a failure" "$g" "FLIP"
has "C3 identity that held is reported HOLD" "$g" "HOLD"
printf 'machine_id\tCHANGED\nhostname\tmonkey\nbackend\twsl\nts_nodeid\tNODE1\nrunners_active\t12\nlong_readout\t0\n' > "$STUB_REPLY"
g="$(PATH="$T/bin:$PATH" "$D/constate.sh" --diff "$T/before.tsv" 2>/dev/null)"; rc "C4 a moved machine_id fails (5) -- it is not the same host" 5 $?
has "C5 ...and says which field moved" "$g" "MOVED  machine_id"
printf 'machine_id\tabc\nhostname\tmonkey\nbackend\twsl\nts_nodeid\t\nrunners_active\t12\nlong_readout\t0\n' > "$STUB_REPLY"
g="$(PATH="$T/bin:$PATH" "$D/constate.sh" --diff "$T/before.tsv" 2>/dev/null)"; rc "C6 a lost tailscale identity fails (5)" 5 $?
has "C7 ...and is ABSENT, distinct from moved" "$g" "ABSENT"
printf 'machine_id\tabc\nhostname\tmonkey\nbackend\toracle\nts_nodeid\tNODE1\nrunners_active\t12\nlong_readout\t9\n' > "$STUB_REPLY"
g="$(PATH="$T/bin:$PATH" "$D/constate.sh" --diff "$T/before.tsv" 2>/dev/null)"; rc "C8 a RISING wedge counter fails (5)" 5 $?
has "C9 ...and names the pathology rather than printing a number alone" "$g" "ROSE"

section "D. etat.sh -- a report, never a gate"
has "D1 it says the order is provisional, where a reader sees it" "$(grep -A2 "BANNER" "$D/etat.sh")" "PROVISIONAL"
has "D2 ...and that DIVERGED is a finding, not a failure" "$(cat "$D/etat.sh")" "never a failure"
has "D3 it names the one gate only a human can pass" "$(cat "$D/etat.sh")" "can_admins_bypass"

section "E. the rehearsal verdict is committed, so its results are not a memory"
V="$D/rehearsal-verdict.tsv"
if [ -r "$V" ]; then ok "E3 the rehearsal verdict is in the tree"; else bad "E3 the rehearsal verdict is in the tree" "missing"; fi
vf() { awk -F'\t' -v k="$1" '$1==k{print $2; exit}' "$V" 2>/dev/null; }
eq "E4 the first boot really had no systemd -- the disarm window is real" "$(vf first_boot_pid1)" "init"
eq "E5 systemd came up once wsl.conf existed" "$(vf systemd_pid1_after_wslconf)" "systemd"
eq "E6 machine_id survived the tar: the distro IS monkey" "$(vf machine_id)" "HELD"
eq "E7 no runner reached GitHub as the live fleet" "$(vf runners_active)" "0"
eq "E8 tailscaled was proven to start, not assumed" "$(vf tailscaled_starts)" "YES"
eq "E9 ...and the login half is recorded as open, not quietly as passed" "$(vf tailscale_login_under_mirrored)" "UNTESTED"
eq "E10 the backend discriminator flipped" "$(vf detect_virt)" "wsl"

section "F. the baseline is committed, so 'before' is not a memory"
if [ -r "$D/before.tsv" ]; then ok "E1 before.tsv is in the tree"; else bad "E1 before.tsv is in the tree" "missing"; fi
eq "E2 it was taken before the migration, on the VirtualBox backend" \
  "$(awk -F'\t' '$1=="backend"{print $2}' "$D/before.tsv" 2>/dev/null)" "oracle"
summary
