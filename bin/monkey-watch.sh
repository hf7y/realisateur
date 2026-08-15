#!/usr/bin/env bash
# monkey-watch.sh -- publish monkey's status on a schedule, FROM DEXTER, and
# alert when it changes state.
#
#   monkey-watch.sh            probe and print, publish nothing
#   monkey-watch.sh --apply    probe, publish to hf7y.com/monkey, alert on change
#
# WHY THIS EXISTS (hf7y/realisateur#274). publish-monkey-status.sh runs BY
# HAND, from mandark, and refuses to publish unless its ssh collection
# succeeds: "collector returned no accounts. Refusing to publish an empty
# page." So the page cannot report the one thing worth reporting. On
# 2026-08-14 monkey's root went read-only, sshd reset every connection, 14
# accounts were unreachable for hours -- and the page showed a healthy world
# from before the outage, because publishing REQUIRES the thing that broke.
# The monitoring inherited the failure it was supposed to report.
#
# THE FIX IS WHERE IT RUNS. dexter HOSTS the VM, so `VBoxManage showvminfo`
# answers even when the guest is dead. That host-side fact is what makes
# "running but not answering" -- exactly that outage -- distinguishable from
# "powered off", and it is invisible from inside the guest by definition.
#
# THE COLLECTOR IS THE SOURCE OF THE ACCOUNT ROWS. THIS SCRIPT IS NOT.
# bin/monkey-status-collect.py runs as root ON monkey and probes each
# account's real crontab and real scheduler ledger: `armed` means that
# account's own crontab holds a dispatch runner, and a missing ledger means it
# has never run -- which for an armed account is a finding, not a blank. None
# of that is derivable from dexter.
#
# The FIRST version of this script hand-rolled a thinner payload instead of
# running the collector, and it broke the page: share/monkey-status.html reads
# `d.accounts` and got undefined. That is the "claim copied from a document"
# failure the page exists to avoid, committed by the thing publishing the page.
# Host-side facts are now ADDED to the collector's document, never substituted
# for it.
set -uo pipefail

CLI_NAME='monkey-watch'
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VBOX="${VBOX:-/mnt/c/Program Files/Oracle/VirtualBox/VBoxManage.exe}"
VM="${VM:-monkey}"
MONKEY_IP="${MONKEY_IP:-100.121.83.23}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_dexter_monkey}"
COLLECTOR="${COLLECTOR:-$HERE/bin/monkey-status-collect.py}"
PAGE_SRC="${PAGE_SRC:-$HERE/share/monkey-status.html}"
STATE_FILE="${STATE_FILE:-$HOME/.local/state/monkey-watch.last}"
PUBLISH_REPO="${PUBLISH_REPO:-hf7y/hf7y.github.io}"
PUBLISH_DIR="${PUBLISH_DIR:-monkey}"
ZAXON="${ZAXON:-http://127.0.0.1:8643/mcp}"
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

die() { printf '%s: FAIL: %s\n' "$CLI_NAME" "$*" >&2; exit 2; }
[ -x "$VBOX" ] || die "VBoxManage not at $VBOX -- this must run on the VM host (dexter)."
[ -f "$COLLECTOR" ] || die "collector not found at $COLLECTOR.
  This script runs from a realisateur checkout so the collector that runs is
  the one in the tree. Clone it rather than copying the collector next to me."

vbm() { "$VBOX" "$@" < /dev/null 2>&1 | tr -d '\0\r'; }
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- host-side: always available --------------------------------------------
VMSTATE="$(vbm showvminfo "$VM" --machinereadable | grep '^VMState=' | cut -d'"' -f2)"
[ -n "$VMSTATE" ] || VMSTATE="unknown"
DISK="$(vbm showvminfo "$VM" --machinereadable | grep '^"SATA-0-0"=' | cut -d'"' -f4)"

# WHERE THE DISK LIVES IS A PUBLISHED FACT, not trivia: the whole outage was a
# virtual disk on an external USB drive that logged 1580 controller errors in a
# week. If this ever reads EXTERNAL-USB again, someone reverted the fix and the
# page should say so rather than waiting to be asked.
case "$DISK" in
  C:*) DISK_HOME="internal" ;;
  D:*) DISK_HOME="EXTERNAL-USB" ;;
  *)   DISK_HOME="unknown" ;;
esac

# --- guest-side: best effort ------------------------------------------------
# THE SSH BANNER IS THE PROBE, NOT A TCP CONNECT. A read-only root accepts TCP
# and then resets at key exchange, so a port check reports green on precisely
# the failure this watcher exists to catch.
BANNER="$(timeout 8 bash -c "exec 3<>/dev/tcp/$MONKEY_IP/22 && head -c 12 <&3" 2>/dev/null || true)"
case "$BANNER" in
  SSH-2.0*) SSHD="answering" ;;
  '')       SSHD="silent" ;;
  *)        SSHD="reset" ;;
esac

# NOTE THE MISSING -n. `ssh -n` redirects stdin from /dev/null, which silently
# feeds the collector an EMPTY program -- it ran, printed nothing usable, and
# the watcher correctly reported DEGRADED instead of publishing a lie. Keep
# stdin free here; mssh_n below is the variant for calls that send nothing.
mssh()   { ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=20 \
               -o StrictHostKeyChecking=accept-new "$MONKEY_IP" "$@" 2>/dev/null; }
mssh_n() { ssh -n -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=20 \
               -o StrictHostKeyChecking=accept-new "$MONKEY_IP" "$@" 2>/dev/null; }

GUEST_JSON=""; GUEST_ERR=""; ROOTMOUNT=""; UPTIME=""
if [ "$SSHD" = "answering" ]; then
  # Fed over STDIN rather than installed on monkey, so the version that runs is
  # the version in this checkout -- no second copy to drift. Borrowed wholesale
  # from publish-monkey-status.sh, which got this right.
  GUEST_JSON="$(mssh 'sudo -n python3 -' < "$COLLECTOR" || true)"
  if ! printf '%s' "$GUEST_JSON" | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if isinstance(d.get("accounts"),list) else 1)' 2>/dev/null; then
    GUEST_ERR="collector ran but returned no usable accounts array"
    GUEST_JSON=""
  fi
  ROOTMOUNT="$(mssh_n 'mount | grep " / " | grep -o "(r[wo]" | tr -d "("' || true)"
  UPTIME="$(mssh_n 'uptime -p' || true)"
else
  GUEST_ERR="sshd is $SSHD -- the collector could not be run"
fi

# --- verdict ----------------------------------------------------------------
# read-only root is called out separately from "down": it is the specific
# recurring failure here, and it looks like up from most angles.
if   [ "$VMSTATE" != "running" ];       then VERDICT="DOWN";     WHY="VM is $VMSTATE"
elif [ "$SSHD" != "answering" ];        then VERDICT="DOWN";     WHY="VM running but sshd is $SSHD (this is what a read-only root looks like)"
elif [ "$ROOTMOUNT" = "ro" ];           then VERDICT="DEGRADED"; WHY="root is mounted READ-ONLY"
elif [ "$DISK_HOME" = "EXTERNAL-USB" ]; then VERDICT="DEGRADED"; WHY="disk is back on the external USB drive"
elif [ -z "$GUEST_JSON" ];              then VERDICT="DEGRADED"; WHY="${GUEST_ERR:-guest detail unavailable}"
else                                         VERDICT="OK";       WHY="running, sshd answering, root rw, disk internal"
fi

payload="$(GUEST_JSON="$GUEST_JSON" NOW="$NOW" VMSTATE="$VMSTATE" DISK="$DISK" \
  DISK_HOME="$DISK_HOME" SSHD="$SSHD" UPTIME="$UPTIME" ROOTMOUNT="$ROOTMOUNT" \
  VERDICT="$VERDICT" WHY="$WHY" GUEST_ERR="$GUEST_ERR" \
  python3 "$HERE/bin/lib/monkey-watch-merge.py")"
[ -n "$payload" ] || die "payload builder produced nothing -- publishing nothing."

printf '%s\n' "$payload"
printf '%s: %s -- %s\n' "$CLI_NAME" "$VERDICT" "$WHY"

[ "$APPLY" = 1 ] || { printf '%s: NOT published (need --apply)\n' "$CLI_NAME"; exit 0; }

# --- alert on CHANGE, not every tick ----------------------------------------
# A watcher that messages every run trains its reader to ignore it, the same
# way a NOTE-level lint stops being read.
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
      MSG="$msg" python3 -c 'import json,os; print(json.dumps({"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"ask_zach","arguments":{"question":os.environ["MSG"],"from_agent":"monkey-watch"}}}))' > /tmp/monkey-watch-msg.json
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
# page" guard: an empty accounts[] IS the report when monkey is unreachable,
# and refusing to publish it is exactly what hid the 2026-08-14 outage.
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
gh repo clone "$PUBLISH_REPO" "$WORK/site" -- -q --depth 1 2>/dev/null \
  || { echo "$CLI_NAME: could not clone $PUBLISH_REPO -- nothing published" >&2; exit 1; }
mkdir -p "$WORK/site/$PUBLISH_DIR"
printf '%s\n' "$payload" > "$WORK/site/$PUBLISH_DIR/status.json"
[ -f "$PAGE_SRC" ] && cp "$PAGE_SRC" "$WORK/site/$PUBLISH_DIR/index.html"
cd "$WORK/site" || die "could not enter the site clone"
if [ -n "$(git status --porcelain "$PUBLISH_DIR")" ]; then
  git add "$PUBLISH_DIR"
  git -c user.name='monkey-watch' -c user.email='noreply@hf7y.com' \
      commit -q -m "monkey-watch: $VERDICT ($WHY)"
  git push -q || { echo "$CLI_NAME: push failed" >&2; exit 1; }
  printf '%s: published %s\n' "$CLI_NAME" "$VERDICT"
else
  printf '%s: no change to publish\n' "$CLI_NAME"
fi
