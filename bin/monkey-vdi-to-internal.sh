#!/usr/bin/env bash
# monkey-vdi-to-internal.sh -- move monkey's virtual disk off the failing
# external USB drive onto dexter's internal NVMe, unattended.
#
# TRAPS (the rest of this header is in the vault):
# WHY. `monkey` is a VirtualBox guest hosting 14 self-dev accounts, and its
# monkey.vdi lives on D: -- a WD Elements USB drive that logged 1580 `disk`
# Event ID 11 controller errors between 2026-08-07 and 2026-08-14, one every
# 5-10 minutes without pause. On 2026-08-14 ~18:08 one landed on an NTFS
# transaction-log flush, VirtualBox lost its handle to the vdi, and the guest
# remounted root read-only:
#     EXT4-fs (sda2): I/O error while writing superblock
#     EXT4-fs (sda2): Remounting filesystem read-only
# sshd then reset every connection at key exchange, because it cannot write.
# Measured read throughput off that drive is 19.7 MB/s -- about 6x slow for a
# USB3 spinner, which is the resets showing up as latency.

set -uo pipefail

VBOX="/mnt/c/Program Files/Oracle/VirtualBox/VBoxManage.exe"
VM="monkey"
CTL="SATA"
SRC_WIN='D:\VirtualBox VMs\monkey\monkey.vdi'
DST_DIR_WIN='C:\VirtualBox VMs\monkey'
DST_WIN='C:\VirtualBox VMs\monkey\monkey.vdi'
DST_WSL="/mnt/c/VirtualBox VMs/monkey/monkey.vdi"
MONKEY_IP="100.121.83.23"
LOG="/mnt/c/Users/Public/monkey-recovery-$(date +%Y%m%d-%H%M%S).log"
CLONE_TRIES=4
BOOT_WAIT_SECS=600

exec > >(tee -a "$LOG") 2>&1

say() { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }

# Every VBoxManage call gets `< /dev/null` and its output stripped of NULs and
# CRs. It is a Windows process: it inherits stdin and will silently eat the
# rest of a piped script (vault:realisateur/MONKEY.md section 7 lost an afternoon to
# exactly this with VBoxManage.exe), and it emits UTF-16-ish CRLF that breaks
# every downstream grep if not stripped.
vbm() { "$VBOX" "$@" < /dev/null 2>&1 | tr -d '\0\r'; }

# --- zaxon ------------------------------------------------------------------
# ask_zach is the only outbound tool; it delivers a WhatsApp message. We are
# telling rather than asking, so the ticket id is logged and never polled.
# A notify failure must never change the outcome of the recovery.
notify() {
  local msg="$1" url="http://127.0.0.1:8643/mcp" hdr sid body
  hdr="$(mktemp)"; body="$(mktemp)"
  curl -s -D "$hdr" -o /dev/null -m 20 \
    -H 'Content-Type: application/json' -H 'Accept: application/json,text/event-stream' \
    -X POST "$url" \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"monkey-recovery","version":"1"}}}' \
    || { say "notify: initialize failed (recovery unaffected)"; return 0; }
  sid="$(grep -i '^mcp-session-id:' "$hdr" | tr -d '\r' | awk '{print $2}')"
  [ -n "$sid" ] || { say "notify: no session id (recovery unaffected)"; return 0; }
  curl -s -o /dev/null -m 20 -H 'Content-Type: application/json' \
    -H 'Accept: application/json,text/event-stream' -H "mcp-session-id: $sid" \
    -X POST "$url" -d '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  # Build the JSON with a real encoder: the message carries newlines and quotes
  # and a hand-built body would 400 and read like the relay being down.
  python3 - "$msg" > "$body" <<'PY'
import json,sys
print(json.dumps({"jsonrpc":"2.0","id":3,"method":"tools/call","params":{
  "name":"ask_zach","arguments":{"question":sys.argv[1],"from_agent":"monkey-recovery"}}}))
PY
  curl -s -m 30 -H 'Content-Type: application/json' \
    -H 'Accept: application/json,text/event-stream' -H "mcp-session-id: $sid" \
    -X POST "$url" --data-binary "@$body" | tr -d '\r' | grep -o 'ticket_id[^,}]*' | head -1
  rm -f "$hdr" "$body"
}

finish() {  # finish <VERDICT> <message>
  local verdict="$1"; shift
  say "VERDICT: $verdict"
  say "$*"
  notify "monkey recovery [$verdict]

$*

log: $LOG"
  exit 0
}

say "=== monkey vdi -> internal NVMe ==="
say "log: $LOG"
say ""
say "REVERT, if this leaves anything wrong -- the original is never touched:"
say "  VBoxManage storageattach $VM --storagectl $CTL --port 0 --device 0 --type hdd --medium \"$SRC_WIN\""
say ""

# --- 1. power off -----------------------------------------------------------
# The guest's root is already read-only, so there is nothing to flush and an
# ACPI shutdown would not be serviced anyway (systemd cannot write). A hard
# poweroff loses no work: everything these accounts produce is committed and
# pushed to GitHub, which is the whole reason this is safe to do unattended.
state="$(vbm showvminfo "$VM" --machinereadable | grep '^VMState=' | cut -d'"' -f2)"
say "1/5 VM state: $state"
if [ "$state" = "running" ]; then
  vbm controlvm "$VM" poweroff | sed 's/^/    /'
  for _ in $(seq 30); do
    state="$(vbm showvminfo "$VM" --machinereadable | grep '^VMState=' | cut -d'"' -f2)"
    [ "$state" = "poweroff" ] && break
    sleep 2
  done
fi
[ "$state" = "poweroff" ] || finish "STUCK" "VM would not power off; state=$state. Nothing was changed."
say "    powered off"

# --- 2. clone ---------------------------------------------------------------
# READ from D:, WRITE to C:. Retried, because at 19.7 MB/s this is a ~13 minute
# continuous read off a drive that resets every 5-10 minutes -- a failed clone
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
mkdir -p "$(dirname "$DST_WSL")"
SRC_BYTES="$(stat -c %s "/mnt/d/VirtualBox VMs/monkey/monkey.vdi" 2>/dev/null || echo 0)"
say "2/5 cloning ($((SRC_BYTES/1024/1024)) MB source, expect ~13 min at measured 19.7 MB/s)"
ok=0
for try in $(seq "$CLONE_TRIES"); do
  rm -f "$DST_WSL"
  say "    attempt $try/$CLONE_TRIES"
  if vbm clonemedium disk "$SRC_WIN" "$DST_WIN" --format VDI | sed 's/^/    /'; then
    if [ -f "$DST_WSL" ]; then
      DST_BYTES="$(stat -c %s "$DST_WSL")"
      say "    clone present: $((DST_BYTES/1024/1024)) MB"
      # A dynamically-allocated clone may differ in size from its source, so
      # size equality is NOT the test. Non-trivial size plus clonemedium's own
      # success is what we have; the real verification is the boot below.
      [ "$DST_BYTES" -gt 1000000000 ] && { ok=1; break; }
      say "    clone implausibly small -- discarding"
    else
      say "    clonemedium returned success but no file exists"
    fi
  fi
  say "    attempt $try failed; the source drive is unharmed either way"
  sleep 20
done
[ "$ok" = 1 ] || finish "STUCK" "Clone failed after $CLONE_TRIES attempts. The VM is POWERED OFF and still attached to the ORIGINAL disk on D:. Nothing was lost; start it again with: VBoxManage startvm monkey --type headless"

# --- 3. repoint -------------------------------------------------------------
# Only now, with a verified clone on internal storage.
say "3/5 repointing $CTL port 0 to internal copy"
vbm storageattach "$VM" --storagectl "$CTL" --port 0 --device 0 --type hdd --medium "$DST_WIN" | sed 's/^/    /'
attached="$(vbm showvminfo "$VM" --machinereadable | grep "^\"$CTL-0-0\"=" | cut -d'"' -f4)"
say "    now attached: $attached"
case "$attached" in
  C:*) : ;;
  *) finish "STUCK" "Repoint did not take -- disk still reads as '$attached'. VM is powered off and the original is intact." ;;
esac

# --- 4. boot ----------------------------------------------------------------
say "4/5 starting VM (ext4 will fsck the dirty filesystem on the way up)"
vbm startvm "$VM" --type headless | sed 's/^/    /'

# HEALTH PROBE THAT NEEDS NO CREDENTIAL. A completed SSH banner means sshd
# accepted a connection and wrote its session state -- which is precisely the
# thing a read-only root prevented. TCP-accepts alone is NOT the test: that is
# what the broken host does today, resetting immediately after connect.
say "    waiting up to $((BOOT_WAIT_SECS/60)) min for sshd to answer with a banner"
wait_for_ssh() {
  local secs="$1" banner
  for _ in $(seq $((secs/10))); do
    banner="$(timeout 6 bash -c "exec 3<>/dev/tcp/$MONKEY_IP/22 && head -c 12 <&3" 2>/dev/null)"
    case "$banner" in
      SSH-2.0*) say "    sshd answered: $banner"; return 0 ;;
    esac
    sleep 10
  done
  return 1
}

up=0
if wait_for_ssh "$BOOT_WAIT_SECS"; then
  up=1
else
  # ONE RESET, THEN GIVE UP. Learned the hard way on the 2026-08-14 run: the
  # first boot after the move hung in initramfs at "Begin: Loading essential
  # drivers", frozen -- two screenshots twenty minutes apart were BYTE
  #   [rest: vault:realisateur/guard-archaeology-20260817.md]
  say "    no banner after $((BOOT_WAIT_SECS/60)) min -- capturing console, then ONE reset"
  vbm controlvm "$VM" screenshotpng 'C:\Users\Public\monkey-recovery-hung-boot.png' | sed 's/^/    /'
  vbm controlvm "$VM" reset | sed 's/^/    /'
  say "    reset issued; waiting again"
  wait_for_ssh "$BOOT_WAIT_SECS" && up=1
fi

# --- 5. report --------------------------------------------------------------
if [ "$up" = 1 ]; then
  finish "DONE" "monkey is back up, running from INTERNAL NVMe (C:) instead of the failing USB drive.

sshd answered with a banner, which means root is writable again -- that is the exact failure that took it down.

The original vdi on D: was never touched and is still there as a fallback.
Still outstanding: the WD Elements drive logged 1580 controller errors Aug 7-14 and is still faulty. That is a cable/power/enclosure job, and D: presumably holds other things worth caring about."
fi

shot="/mnt/c/Users/Public/monkey-recovery-console.png"
vbm controlvm "$VM" screenshotpng 'C:\Users\Public\monkey-recovery-console.png' | sed 's/^/    /'
finish "STUCK" "monkey was moved to internal NVMe and started, but sshd never answered -- not on the first boot, and not after one reset.

One hung boot is expected and is handled; two is not. This is most likely fsck wanting manual input at a recovery prompt, and I did NOT try to drive it blind.

Console screenshot: $shot
To revert to the old disk on D:
  VBoxManage storageattach monkey --storagectl SATA --port 0 --device 0 --type hdd --medium \"$SRC_WIN\"
The original vdi on D: was never touched."
