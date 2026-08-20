#!/usr/bin/env bash
# containment-audit.sh -- no self-dev account reaches outside its own home (#437).
#
# TRAP: three verdicts, never two. Owning nothing outside its home is OK;
#   owning something is DOWN; not being able to look is BLIND, and BLIND is
#   never reported as clean.
# TRAP: the uid band is read from passwd on the host being audited, so an
#   account added later is covered without an edit here.
#
set -uo pipefail

CLI_NAME='containment-audit.sh'
CLI_SUMMARY='self-dev accounts own nothing outside their own homes, and hold no sudo'
CLI_USAGE='  containment-audit.sh            audit this host
  containment-audit.sh --host <h>  audit another host over ssh
  containment-audit.sh --json      one object per check'
CLI_FLAGS='--host --json'
CLI_POSITIONAL=any
CLI_EXITS='  0  every account is contained
  5  DOWN -- an account owns a file outside its home, or holds sudo
  6  BLIND -- a probe could not run. NEVER "contained".'
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

HOST=""; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --host) HOST="${2:?--host needs a hostname}"; shift ;;
    --json) JSON=1 ;;
    -*) echo "$CLI_NAME: unknown flag $1" >&2; exit 2 ;;
    *)  echo "$CLI_NAME: unexpected argument $1" >&2; exit 2 ;;
  esac; shift
done

UID_MIN="${SELFDEV_UID_MIN:-3000}"
UID_MAX="${SELFDEV_UID_MAX:-3099}"

# Run a probe here or there. `ssh -n` so a probe cannot eat this script's stdin.
probe() {
  if [ -n "$HOST" ]; then ssh -n -o ConnectTimeout=10 -o BatchMode=yes "$HOST" "$1" 2>/dev/null
  else bash -c "$1" 2>/dev/null; fi
}

down=0; blind=0; rows=""
record() { rows="$rows$1|$2|$3"$'\n'; case "$2" in DOWN) down=1 ;; BLIND) blind=1 ;; esac; }

accounts="$(probe "getent passwd | awk -F: -v lo=$UID_MIN -v hi=$UID_MAX '\$3>=lo && \$3<=hi {print \$1\":\"\$6}'")"
if [ -z "$accounts" ]; then
  record accounts BLIND "no account in uid band $UID_MIN-$UID_MAX answered -- this is not the self-dev host, or the probe could not run"
else
  record accounts OK "$(printf '%s\n' "$accounts" | grep -c .) account(s) in the band"

  # REACH. `find -uid` needs to read every directory it walks, so an
  # unreadable tree is BLIND for that account rather than "owns nothing".
  #
  # The one thing an account owns outside its home by design is its OWN
  # crontab -- the clock lives on the consumer, in the account's own crontab,
  # running as the account. The exemption is derived from the account's name
  # at probe time, so it covers exactly one path and cannot be widened by
  # editing a list here.
  while IFS=: read -r acct home; do
    [ -n "$acct" ] || continue
    out="$(probe "sudo -n find /home /etc /usr/local /srv /var -xdev -uid \$(id -u $acct) -not -path '$home' -not -path '$home/*' -not -path '/var/spool/cron/crontabs/$acct' -print -quit 2>/dev/null; echo RC=\$?")"
    case "$out" in
      "") record "reach:$acct" BLIND 'the sweep produced nothing at all, not even a return code' ;;
      RC=0) record "reach:$acct" OK "owns nothing outside $home" ;;
      RC=*) record "reach:$acct" BLIND "the sweep could not read the tree ($out)" ;;
      *)    record "reach:$acct" DOWN "owns $(printf '%s' "$out" | head -1) outside $home" ;;
    esac
  done <<< "$accounts"

  # SUDO. Any mention of a band account in /etc/sudoers.d is a grant until
  # proven otherwise; this refuses to parse sudoers and call it safe.
  names="$(printf '%s\n' "$accounts" | cut -d: -f1 | paste -sd'|')"
  out="$(probe "sudo -n grep -rlE '^[[:space:]]*($names)[[:space:]]' /etc/sudoers /etc/sudoers.d 2>/dev/null; echo RC=\$?")"
  case "$out" in
    "")   record sudo BLIND 'could not read /etc/sudoers.d' ;;
    RC=*) record sudo OK 'no self-dev account appears in sudoers' ;;
    *)    record sudo DOWN "a self-dev account appears in $(printf '%s' "$out" | head -1)" ;;
  esac
fi

if [ "$JSON" = 1 ]; then
  printf '%s' "$rows" | while IFS='|' read -r n v d; do
    [ -n "$n" ] || continue
    printf '{"check":"%s","verdict":"%s","detail":"%s"}\n' "$n" "$v" "${d//\"/\\\"}"
  done
else
  printf '== containment-audit %s (uid band %s-%s) ==\n' "${HOST:-$(hostname -s 2>/dev/null || echo local)}" "$UID_MIN" "$UID_MAX"
  printf '%s' "$rows" | while IFS='|' read -r n v d; do
    [ -n "$n" ] || continue
    printf '  %-6s %-24s %s\n' "$v" "$n" "$d"
  done
fi

[ "$down" -eq 0 ] || exit 5
[ "$blind" -eq 0 ] || exit 6
exit 0
