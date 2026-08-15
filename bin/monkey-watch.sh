#!/usr/bin/env bash
# monkey-watch.sh -- publish monkey's status on a schedule, FROM DEXTER, and
# alert when it changes state.
#
#   monkey-watch.sh            probe and print, publish nothing
#   monkey-watch.sh --apply    probe, publish to hf7y.com/monkey, alert on change
#
# WHY THIS EXISTS AND publish-monkey-status.sh WAS NOT ENOUGH
# (hf7y/realisateur#274). That script runs BY HAND, from mandark, and refuses
# to publish unless the ssh collection succeeds:
#     "collector returned no accounts. Refusing to publish an empty page."
# Which means the page cannot report the one thing worth reporting. On
# 2026-08-14 monkey's root went read-only, sshd reset every connection, all 14
# accounts were unreachable for hours -- and the page sat there showing a
# healthy world from before the outage, confidently, because publishing
# REQUIRES the thing that was broken. The monitoring inherited the failure it
# was supposed to report.
#
# THE FIX IS WHERE IT RUNS, NOT HOW OFTEN. dexter HOSTS the VM, so
# `VBoxManage showvminfo` answers even when the guest is dead. That host-side
# fact is always available and is what makes "running but not answering"
# distinguishable from "powered off" -- the former was tonight's condition and
# is invisible from inside the guest, by definition.
#
# So: the host-side probe is REQUIRED and always published; the guest-side
# detail is BEST EFFORT and its absence is itself the headline. A page that
# stops updating must read as an alarm, not as good news, so every payload
# carries its own timestamp and the renderer is expected to show staleness.
set -uo pipefail

CLI_NAME='monkey-watch'
VBOX="${VBOX:-/mnt/c/Program Files/Oracle/VirtualBox/VBoxManage.exe}"
VM="${VM:-monkey}"
MONKEY_IP="${MONKEY_IP:-100.121.83.23}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_dexter_monkey}"
STATE_FILE="${STATE_FILE:-$HOME/.local/state/monkey-watch.last}"
PUBLISH_REPO="${PUBLISH_REPO:-hf7y/hf7y.github.io}"
PUBLISH_DIR="${PUBLISH_DIR:-monkey}"
ZAXON="${ZAXON:-http://127.0.0.1:8643/mcp}"
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

die() { printf '%s: FAIL: %s\n' "$CLI_NAME" "$*" >&2; exit 2; }
[ -x "$VBOX" ] || die "VBoxManage not found at $VBOX -- this must run on the VM host (dexter)."

vbm() { "$VBOX" "$@" < /dev/null 2>&1 | tr -d '\0\r'; }

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- host-side: always available --------------------------------------------
VMSTATE="$(vbm showvminfo "$VM" --machinereadable | grep '^VMState=' | cut -d'"' -f2)"
[ -n "$VMSTATE" ] || VMSTATE="unknown"
DISK="$(vbm showvminfo "$VM" --machinereadable | grep '^"SATA-0-0"=' | cut -d'"' -f4)"

# WHERE THE DISK LIVES IS A FIRST-CLASS FACT, not trivia. The whole outage was
# a virtual disk on an external USB drive. If this ever reads D: again,
# somebody has reverted the fix and should find out from the page.
case "$DISK" in
  C:*) DISK_HOME="internal" ;;
  D:*) DISK_HOME="EXTERNAL-USB" ;;
  *)   DISK_HOME="unknown" ;;
esac

# --- guest-side: best effort ------------------------------------------------
# The SSH BANNER is the probe, not a TCP connect. A read-only root accepts TCP
# and then resets at key exchange, which is exactly what "sshd is up" looks
# like to a port check -- that false green is the failure mode being designed
# against here.
BANNER="$(timeout 8 bash -c "exec 3<>/dev/tcp/$MONKEY_IP/22 && head -c 12 <&3" 2>/dev/null || true)"
case "$BANNER" in
  SSH-2.0*) SSHD="answering" ;;
  '')       SSHD="silent" ;;
  *)        SSHD="reset" ;;
esac

ACCOUNTS="[]"; GUEST_ERR=""; ROOTMOUNT=""; UPTIME=""
if [ "$SSHD" = "answering" ]; then
  GUEST="$(ssh -n -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=15 \
      -o StrictHostKeyChecking=accept-new "$MONKEY_IP" \
      'echo "UPTIME=$(uptime -p 2>/dev/null)"; echo "ROOT=$(mount | grep " / " | grep -o "(r[wo]" | tr -d "(")"; getent passwd | awk -F: "\$3>=3000 && \$3<3100 {print \"ACCT=\" \$1}"' 2>/dev/null || true)"
  UPTIME="$(printf '%s\n' "$GUEST" | sed -n 's/^UPTIME=//p' | head -1)"
  ROOTMOUNT="$(printf '%s\n' "$GUEST" | sed -n 's/^ROOT=//p' | head -1)"
  ACCOUNTS="$(printf '%s\n' "$GUEST" | sed -n 's/^ACCT=//p' | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')"
  [ -n "$UPTIME" ] || GUEST_ERR="ssh answered but the probe returned nothing"
else
  GUEST_ERR="sshd is $SSHD -- no guest detail available"
fi

# --- verdict ----------------------------------------------------------------
# ROOT=ro is called out separately from "down" because it is the specific,
# recurring failure here and it LOOKS like up from most angles.
if [ "$VMSTATE" != "running" ];      then VERDICT="DOWN";     WHY="VM is $VMSTATE"
elif [ "$SSHD" != "answering" ];     then VERDICT="DOWN";     WHY="VM running but sshd is $SSHD (this is what a read-only root looks like)"
elif [ "$ROOTMOUNT" = "ro" ];        then VERDICT="DEGRADED"; WHY="root is mounted READ-ONLY"
elif [ "$DISK_HOME" = "EXTERNAL-USB" ]; then VERDICT="DEGRADED"; WHY="disk is back on the external USB drive"
else                                      VERDICT="OK";       WHY="running, sshd answering, root rw, disk internal"
fi

payload="$(python3 - "$NOW" "$VMSTATE" "$DISK" "$DISK_HOME" "$SSHD" "$UPTIME" "$ROOTMOUNT" "$VERDICT" "$WHY" "$GUEST_ERR" "$ACCOUNTS" <<'PY'
import json,sys
n,vm,disk,dh,sshd,up,root,verdict,why,gerr,accts = sys.argv[1:12]
print(json.dumps({
  "generated": n, "verdict": verdict, "why": why,
  "host": {"vm_state": vm, "disk": disk, "disk_home": dh},
  "guest": {"sshd": sshd, "uptime": up, "root_mount": root,
            "accounts": json.loads(accts), "error": gerr or None},
  "staleness_note": "This page is generated on dexter, the VM host, so it can report monkey being down. If 'generated' is old, the WATCHER is broken -- not necessarily monkey.",
}, indent=2))
PY
)"

printf '%s\n' "$payload"
printf '%s: %s -- %s\n' "$CLI_NAME" "$VERDICT" "$WHY"

[ "$APPLY" = 1 ] || { printf '%s: NOT published (need --apply)\n' "$CLI_NAME"; exit 0; }

# --- alert on CHANGE, not every tick ----------------------------------------
# A watcher that messages every run trains its reader to ignore it, which is
# the same way a NOTE-level lint stops being read.
mkdir -p "$(dirname "$STATE_FILE")"
LAST="$(cat "$STATE_FILE" 2>/dev/null || echo "")"
if [ "$VERDICT" != "$LAST" ]; then
  printf '%s\n' "$VERDICT" > "$STATE_FILE"
  if [ -n "$LAST" ]; then
    msg="monkey: $LAST -> $VERDICT

$WHY

vm=$VMSTATE sshd=$SSHD root=${ROOTMOUNT:-?} disk=$DISK_HOME
https://hf7y.com/$PUBLISH_DIR/"
    hdr="$(mktemp)"
    curl -s -D "$hdr" -o /dev/null -m 20 -H 'Content-Type: application/json' \
      -H 'Accept: application/json,text/event-stream' -X POST "$ZAXON" \
      -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"monkey-watch","version":"1"}}}' || true
    sid="$(grep -i '^mcp-session-id:' "$hdr" | tr -d '\r' | awk '{print $2}')"
    if [ -n "$sid" ]; then
      curl -s -o /dev/null -m 20 -H 'Content-Type: application/json' \
        -H 'Accept: application/json,text/event-stream' -H "mcp-session-id: $sid" \
        -X POST "$ZAXON" -d '{"jsonrpc":"2.0","method":"notifications/initialized"}'
      python3 - "$msg" > /tmp/monkey-watch-msg.json <<'PY'
import json,sys
print(json.dumps({"jsonrpc":"2.0","id":3,"method":"tools/call","params":{
  "name":"ask_zach","arguments":{"question":sys.argv[1],"from_agent":"monkey-watch"}}}))
PY
      curl -s -m 30 -H 'Content-Type: application/json' \
        -H 'Accept: application/json,text/event-stream' -H "mcp-session-id: $sid" \
        -X POST "$ZAXON" --data-binary @/tmp/monkey-watch-msg.json >/dev/null || true
      printf '%s: alerted (%s -> %s)\n' "$CLI_NAME" "$LAST" "$VERDICT"
    fi
    rm -f "$hdr"
  fi
fi

# --- publish ----------------------------------------------------------------
# ALWAYS publishes. There is deliberately no "refusing to publish an empty
# page" guard here: an empty guest section IS the report when monkey is down,
# and refusing to publish it is what hid the outage.
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
gh repo clone "$PUBLISH_REPO" "$WORK/site" -- -q --depth 1 2>/dev/null \
  || { echo "$CLI_NAME: could not clone $PUBLISH_REPO -- status not published" >&2; exit 1; }
mkdir -p "$WORK/site/$PUBLISH_DIR"
printf '%s\n' "$payload" > "$WORK/site/$PUBLISH_DIR/status.json"
cd "$WORK/site"
if [ -n "$(git status --porcelain "$PUBLISH_DIR")" ]; then
  git add "$PUBLISH_DIR/status.json"
  git -c user.name='monkey-watch' -c user.email='noreply@hf7y.com' \
      commit -q -m "monkey-watch: $VERDICT ($WHY)"
  git push -q || { echo "$CLI_NAME: push failed" >&2; exit 1; }
  printf '%s: published %s\n' "$CLI_NAME" "$VERDICT"
else
  printf '%s: no change to publish\n' "$CLI_NAME"
fi
