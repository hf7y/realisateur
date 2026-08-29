#!/usr/bin/env bash
set -uo pipefail  # SUBJECT: bin/lib/vmhost.sh -- pins the virtualbox backend against a stub VBoxManage as an inert wrap of the old vbm() call shape (#563)
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
harness_tmp

echo "vmhost.test.sh"

FAKE="$T/VBoxManage.exe"  # showvminfo prints $FAKE_VMINFO; controlvm screenshotpng writes a dummy PNG; savestate/startvm log to $CALLS
FAKE_VMINFO="$T/vminfo"
CALLS="$T/calls"
cat > "$FAKE" <<STUB
#!/usr/bin/env bash
case "\$1" in
  showvminfo) cat "$FAKE_VMINFO" ;;
  controlvm)  [ "\$3" = screenshotpng ] && printf '\x89PNG-fake' > "\$4"
              [ "\$3" = savestate ] && printf 'controlvm %s savestate\n' "\$2" >> "$CALLS" ;;
  startvm)    printf 'startvm %s %s %s\n' "\$2" "\$3" "\$4" >> "$CALLS" ;;
esac
STUB
chmod +x "$FAKE"
printf 'VMState="running"\n"SATA-0-0"="C:\\VMs\\monkey.vdi"\n' > "$FAKE_VMINFO"

VMHOST_VBOX="$FAKE"
. "$REPO/bin/lib/vmhost.sh"

section "A. backend detection"
unset VMHOST_BACKEND
eq "A1 an executable VBoxManage at \$VMHOST_VBOX detects as virtualbox" "$(vmhost_backend)" "virtualbox"
eq "A2 no VBoxManage and no override detects as unknown" \
  "$(VMHOST_VBOX="$T/nowhere" vmhost_backend)" "unknown"
eq "A3 \$VMHOST_BACKEND overrides detection" "$(VMHOST_BACKEND=hyperv vmhost_backend)" "hyperv"

section "B. vmhost_require -- the fail-loud precondition monkey-watch.sh calls"
vmhost_require; rc "B1 virtualbox backend with VBoxManage present succeeds" 0 $?
VMHOST_VBOX="$T/nowhere" vmhost_require 2>/dev/null; rc "B2 virtualbox backend with VBoxManage missing fails" 2 $?
VMHOST_BACKEND=hyperv vmhost_require 2>/dev/null; rc "B3 an unimplemented backend fails, not silently no-ops" 2 $?

section "C. vmhost_state -- wraps showvminfo verbatim (#563's 'inert refactor')"
eq "C1 reads VMState out of --machinereadable" "$(vmhost_state monkey)" "running"
printf 'VMState="poweroff"\n' > "$FAKE_VMINFO"
eq "C2 a different fixture value passes through unchanged" "$(vmhost_state monkey)" "poweroff"
printf '' > "$FAKE_VMINFO"
eq "C3 no VMState line at all reads unknown, not empty" "$(vmhost_state monkey)" "unknown"

section "D. vmhost_disk_raw / vmhost_classify_disk -- the value monkey-watch.sh publishes as-is, and its classing"
printf '"SATA-0-0"="C:\\VMs\\monkey.vdi"\n' > "$FAKE_VMINFO"
eq "D1 the raw descriptor passes through for publishing" "$(vmhost_disk_raw monkey)" 'C:\VMs\monkey.vdi'
eq "D2 a C: drive letter classes internal" "$(vmhost_classify_disk 'C:\VMs\monkey.vdi')" "internal"
eq "D3 a D: drive letter classes EXTERNAL-USB -- the outage this exists to catch" \
  "$(vmhost_classify_disk 'D:\VMs\monkey.vdi')" "EXTERNAL-USB"
eq "D4 anything else classes unknown, not a guess" "$(vmhost_classify_disk '')" "unknown"
printf '"SATA-0-0"="D:\\VMs\\monkey.vdi"\n' > "$FAKE_VMINFO"
eq "D5 vmhost_disk composes raw + classify against a live fixture" "$(vmhost_disk monkey)" "EXTERNAL-USB"

section "E. vmhost_screenshot -- the #560 console capture, via the backend"
SHOT="$T/console.png"
rm -f "$SHOT"
vmhost_screenshot monkey "$SHOT"
[ -s "$SHOT" ] && ok "E1 a screenshot lands at the given path" || bad "E1 a screenshot lands at the given path" "nothing written to $SHOT"

section "H. vmhost_save -- #704's pause actuator, savestate not acpipowerbutton"
rm -f "$CALLS"
vmhost_save monkey
eq "H1 drives controlvm savestate, not an ACPI request" "$(cat "$CALLS")" "controlvm monkey savestate"

section "I. vmhost_start -- #704's resume actuator"
rm -f "$CALLS"
vmhost_start monkey
eq "I1 defaults to a headless launch" "$(cat "$CALLS")" "startvm monkey --type headless"
rm -f "$CALLS"
VMHOST_START_TYPE=gui vmhost_start monkey
eq "I2 \$VMHOST_START_TYPE overrides the launch type" "$(cat "$CALLS")" "startvm monkey --type gui"

section "G. vmhost_logdir -- the query AND the path translation, both backend-specific (#639)"
printf 'LogFldr="C:\\Users\\zach\\VirtualBox VMs\\monkey\\Logs"\n' > "$FAKE_VMINFO"
eq "G1 the folder comes from the backend, and lands in coordinates this host can open" \
  "$(vmhost_logdir monkey)" "/mnt/c/Users/zach/VirtualBox VMs/monkey/Logs"
printf '' > "$FAKE_VMINFO"
eq "G2 no LogFldr line yields nothing, so the caller skips rather than reading /VBox.log" \
  "$(vmhost_logdir monkey)" ""

section "J. vmhost_pause_* -- #704's declared-pause record, pure file+clock logic"
VMHOST_PAUSE_DIR="$T/pause"
eq "J1 no declaration reads NONE" "$(vmhost_pause_status monkey 2026-08-29T00:00:00Z)" "NONE"
vmhost_pause_declare monkey 2026-08-29T18:00:00Z
eq "J2 before the expiry reads PAUSED with the declared until" \
  "$(vmhost_pause_status monkey 2026-08-29T10:00:00Z)" "PAUSED 2026-08-29T18:00:00Z"
eq "J3 at or past the expiry reads EXPIRED, still naming until" \
  "$(vmhost_pause_status monkey 2026-08-29T18:00:01Z)" "EXPIRED 2026-08-29T18:00:00Z"
vmhost_pause_mark_resumed monkey 2026-08-29T18:00:05Z
eq "J4 once the actuator fires it reads RESUMING, not EXPIRED again" \
  "$(vmhost_pause_status monkey 2026-08-29T18:05:00Z)" "RESUMING 2026-08-29T18:00:05Z"
eq "J5 \`until\` survives the resumed_at rewrite" "$(vmhost_pause_field monkey until)" "2026-08-29T18:00:00Z"
vmhost_pause_clear monkey
eq "J6 clearing removes the declaration outright" "$(vmhost_pause_status monkey 2026-08-29T18:05:00Z)" "NONE"
[ ! -f "$(vmhost_pause_file monkey)" ] && ok "J6b the file itself is gone" || bad "J6b the file itself is gone"

vmhost_pause_mark_resumed monkey 2026-08-29T18:00:05Z
eq "J7 marking resumed with no declaration is a no-op, not a fabricated record" \
  "$(vmhost_pause_status monkey 2026-08-29T18:05:00Z)" "NONE"

vmhost_pause_declare gardien 2026-08-29T18:00:00Z
eq "J8 declarations are per-vm; a second vm's file does not collide" \
  "$(vmhost_pause_status monkey 2026-08-29T18:05:00Z)" "NONE"
eq "J8b the second vm's own declaration is intact" \
  "$(vmhost_pause_status gardien 2026-08-29T10:00:00Z)" "PAUSED 2026-08-29T18:00:00Z"
vmhost_pause_clear gardien
unset VMHOST_PAUSE_DIR

section "F. an unsupported backend fails loud on every verb, not just detection"
VMHOST_BACKEND=hyperv vmhost_state monkey 2>/dev/null; rc "F1 vmhost_state" 2 $?
VMHOST_BACKEND=hyperv vmhost_disk_raw monkey 2>/dev/null; rc "F2 vmhost_disk_raw" 2 $?
VMHOST_BACKEND=hyperv vmhost_screenshot monkey "$T/x.png" 2>/dev/null; rc "F3 vmhost_screenshot" 2 $?
VMHOST_BACKEND=hyperv vmhost_logdir monkey 2>/dev/null; rc "F4 vmhost_logdir" 2 $?
VMHOST_BACKEND=hyperv vmhost_save monkey 2>/dev/null; rc "F5 vmhost_save" 2 $?
VMHOST_BACKEND=hyperv vmhost_start monkey 2>/dev/null; rc "F6 vmhost_start" 2 $?

summary
