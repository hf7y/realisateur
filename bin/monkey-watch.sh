#!/usr/bin/env bash
# monkey-watch.sh -- publish monkey's status on a schedule, FROM DEXTER, and
# alert when it changes state.
#
# TRAPS (the rest of this header is in the vault):
# WHY THIS EXISTS (#274). publish-monkey-status.sh refuses to publish unless
# its ssh collection succeeds, so the page cannot report the one thing worth
# reporting: on 2026-08-14 monkey went unreachable for hours and the page
# showed the healthy world from before, because publishing REQUIRED the thing
# that broke. The monitoring inherited the failure it was meant to report.
# THE COLLECTOR IS THE SOURCE OF THE ACCOUNT ROWS. THIS SCRIPT IS NOT.
# monkey-status-collect.py runs as root ON monkey and reads each account's real
# crontab and ledger; a missing ledger on an ARMED account is a finding, not a
# blank. None of that is derivable from dexter.
#
# DELETED 2026-08-22 BY #511, RESTORED THE SAME DAY. DO NOT CUT IT AGAIN
# WITHOUT READING THIS. It was swept up in the self-dev v1 subtraction as a
# guard that "produces no findings" -- but it is not a guard. It is the ONLY
# OBSERVER OUTSIDE THE SYSTEM IT OBSERVES.
#
# ausculte runs on monkey. The health cadence runs on monkey. Every issue the
# estate files about itself is written by something ON monkey. So when monkey
# goes down, the tracker does not fill with alarms -- it goes QUIET, which is
# indistinguishable from a healthy night. dexter-liveness.sh's own header names
# the mechanism: dexter starts its distro and VMs from the Windows Startup
# folder, i.e. AT LOGIN, so a reboot nobody logs in after takes all of self-dev
# with it and "reads from the outside like a quiet night".
#
# DELETION-LIST.txt:23 protected `publish-monkey-status.sh` and
# `monkey-status-collect.py` by name -- "the dashboard Zach reads" -- and line
# 97 deleted the only thing that invokes them. The list kept the payload and
# cut its clock. That is realisateur#518, and this is its cause.
#
# The corpse kept running: dexter's crontab fired this path every ten minutes
# for the whole interval and appended `not found` to
# ~/.local/state/monkey-watch.log until it reached 47 MB. A cron entry pointing
# at a deleted script is not inert; it is a fault indicator nobody reads.
#
# The rule this earns: a REACHABILITY SCAN CANNOT SEE AN OFF-HOST CALLER.
# #511's scan read .github/workflows/ and this repo's own bin/; the caller here
# is a crontab line on a different machine. Before deleting anything, ask what
# invokes it FROM SOMEWHERE ELSE.

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
# shellcheck source=lib/zaxon.sh
. "$HERE/bin/lib/zaxon.sh"
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
    tid="$(zaxon_ask "$msg" monkey-watch)"
    [ -z "$tid" ] || printf '%s: alerted (%s -> %s) ticket %s\n' "$CLI_NAME" "$LAST" "$VERDICT" "$tid"
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
