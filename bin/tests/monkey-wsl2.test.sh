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
  has "A1 the import command keeps its Windows path separators" "$R" 'wsl.exe --import monkey D:\wsl-migration\monkey'
  has "A2 the rollback keeps VBoxManage's quoted program path" "$R" "'C:\\Program Files\\Oracle\\VirtualBox\\VBoxManage.exe' startvm monkey"
  has "A3 the fstab fix keeps its sed delimiters and ampersand" "$R" "sed -i 's|^/dev/disk/by-uuid|#&|; s|^/swapfile|#&|' /etc/fstab"
  has "A4 the rehearsal still drops tailscaled.state" "$R" '--exclude=./var/lib/tailscale/tailscaled.state'
  has "A5 --terminate is named, and --shutdown is named as the hazard" "$R" 'wsl --terminate'
  has "A7 the rehearsal masks the runners before systemd can start them" "$R" "systemctl mask 'actions.runner.*' tailscaled cron"
  has "A8 ...and says why: they would contend with the live fleet's agents" "$R" "SAME agents as the live monkey"
  has "A9 --shutdown's blast radius names the human channel" "$R" "zaxon-relay-mcp.service"
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

section "E. the baseline is committed, so 'before' is not a memory"
if [ -r "$D/before.tsv" ]; then ok "E1 before.tsv is in the tree"; else bad "E1 before.tsv is in the tree" "missing"; fi
eq "E2 it was taken before the migration, on the VirtualBox backend" \
  "$(awk -F'\t' '$1=="backend"{print $2}' "$D/before.tsv" 2>/dev/null)" "oracle"
summary
