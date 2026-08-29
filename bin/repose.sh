#!/usr/bin/env bash
set -uo pipefail  # repose.sh: declare/check/cancel a timed VM pause (#704) -- monkey-watch.sh's own cron tick fires vmhost_start at `until`, so there is no second scheduler to miss

CLI_NAME='repose'
CLI_SUMMARY='declare, check or cancel a timed pause on a VM host'
CLI_USAGE='  repose <vm> <Nh>       pause <vm> for N hours: savestate now, resume at now+Nh
  repose <vm> --status   NONE | PAUSED <until> | EXPIRED <until> | RESUMING <at>
  repose <vm> --cancel   resume <vm> now and clear the declaration'
CLI_FLAGS='--status --cancel'
CLI_POSITIONAL=any
CLI_EXITS='  0  declared, reported, or resumed
  1  the VM action failed
  2  usage error'
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib/cli-guard.sh"
cli_guard "$@"
. "$HERE/lib/vmhost.sh"

[ $# -ge 1 ] || cli_die "name a vm"
VM="$1"; shift
[ $# -ge 1 ] || cli_die "name a duration (e.g. 2h), --status, or --cancel"

case "$1" in
  --status)
    vmhost_pause_status "$VM" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    ;;
  --cancel)  # always tries vmhost_start first: a cleared declaration with the VM still down reads as an unreported outage
    vmhost_require || { printf '%s: VBoxManage not at %s -- this must run on the VM host (dexter).\n' "$CLI_NAME" "$VMHOST_VBOX" >&2; exit 2; }
    if vmhost_start "$VM"; then
      vmhost_pause_clear "$VM"
      printf '%s: %s resumed, declaration cleared\n' "$CLI_NAME" "$VM"
    else
      printf '%s: vmhost_start %s failed -- declaration left in place\n' "$CLI_NAME" "$VM" >&2
      exit 1
    fi
    ;;
  *)
    case "$1" in [0-9]*h) N="${1%h}" ;; *) N="" ;; esac
    case "$N" in ''|*[!0-9]*) cli_die "duration must look like <N>h (got '$1')" ;; esac
    vmhost_require || { printf '%s: VBoxManage not at %s -- this must run on the VM host (dexter).\n' "$CLI_NAME" "$VMHOST_VBOX" >&2; exit 2; }
    UNTIL="$(date -u -d "+${N} hours" +%Y-%m-%dT%H:%M:%SZ)" || cli_die "could not compute +${N}h from now"
    if vmhost_save "$VM"; then
      vmhost_pause_declare "$VM" "$UNTIL"
      printf '%s: %s paused, resumes %s\n' "$CLI_NAME" "$VM" "$UNTIL"
    else
      printf '%s: vmhost_save %s failed -- nothing declared\n' "$CLI_NAME" "$VM" >&2
      exit 1
    fi
    ;;
esac
