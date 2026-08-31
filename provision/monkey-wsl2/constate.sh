#!/usr/bin/env bash
set -uo pipefail

usage() {
  cat >&2 <<'USAGE'
constate.sh -- witness monkey's state before and after the WSL2 migration
(senechal#438). Runs on mandark and reaches in. NOT a verb, installed on no
host, so it needs no build tag to reach the thing it measures.

usage: constate.sh [--target ssh:<host> | wsl:<distro>] [--diff <before.tsv>]

  --target ssh:monkey   reach monkey by name, dexter:2224       (default)
  --target wsl:monkey   reach monkey as a distro, via dexter's port 22 (rescue route;
                        it cannot open the name, so ssh_hostkey reads ABSENT and it
                        legitimately exits 5)
  --diff <file>         grade this snapshot against an earlier one

exit: 0 held  2 usage  5 a MUST-HOLD field moved  6 BLIND, could not read the host
USAGE
}

TARGET="ssh:monkey"
BEFORE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 || { usage; exit 2; } ;;
    --diff)   BEFORE="${2:-}"; shift 2 || { usage; exit 2; } ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'constate: unknown argument "%s"\n' "$1" >&2; usage; exit 2 ;;
  esac
done
[ -z "$BEFORE" ] || [ -r "$BEFORE" ] || { printf 'constate: cannot read %s\n' "$BEFORE" >&2; exit 2; }

read -r -d '' PROBE <<'PROBE_EOF'
p() { printf '%s\t%s\n' "$1" "${2:-}"; }
p backend         "$(systemd-detect-virt 2>/dev/null)"
p hostname        "$(hostnamectl --static 2>/dev/null)"
p machine_id      "$(cat /etc/machine-id 2>/dev/null)"
p runners_enabled "$(systemctl list-unit-files --state=enabled 2>/dev/null | grep -c '^actions\.runner')"
p runners_active  "$(systemctl list-units --state=active 2>/dev/null | grep -c 'actions\.runner')"
p accounts        "$(getent passwd | awk -F: '$3>=3000 && $3<4000' | wc -l)"
p long_readout    "$(journalctl -k -b 2>/dev/null | grep -c 'Long readout interval')"
p soft_lockup     "$(journalctl -k -b 2>/dev/null | grep -c 'soft lockup')"
p mem_total_mb    "$(free -m | awk '/^Mem:/{print $2}')"
p swap_total_mb   "$(free -m | awk '/^Swap:/{print $2}')"
p root_used_gb    "$(df -BG --output=used / 2>/dev/null | tail -1 | tr -dc 0-9)"
p verbs_on_path   "$(ls /usr/local/bin 2>/dev/null | wc -l)"
p etc_selfdev     "$(ls /etc/selfdev 2>/dev/null | wc -l)"
p crontabs        "$(sudo -n ls /var/spool/cron/crontabs 2>/dev/null | wc -l)"
PROBE_EOF

DEXTER_WIN=(ssh -o BatchMode=yes -o ConnectTimeout=20 -p 22 -i "$HOME/.ssh/id_dexter_win" zach@dexter.tail893f2c.ts.net)

case "$TARGET" in
  ssh:*)  SNAP="$(timeout 90 ssh -o BatchMode=yes -o ConnectTimeout=20 "${TARGET#ssh:}" "$PROBE" 2>/dev/null)" ;;
  wsl:*)  SNAP="$(printf '%s' "$PROBE" | timeout 120 "${DEXTER_WIN[@]}" "wsl.exe -d ${TARGET#wsl:} -u root -- bash -s" 2>/dev/null | tr -d '\r')" ;;
  *) printf 'constate: --target must be ssh:<host> or wsl:<distro>, got "%s"\n' "$TARGET" >&2; exit 2 ;;
esac

if [ -z "${SNAP:-}" ] || ! printf '%s' "$SNAP" | grep -q '^machine_id'; then
  printf 'constate: BLIND -- no readable snapshot from %s\n' "$TARGET" >&2
  exit 6
fi
case "$TARGET" in
  ssh:*)
    _h="$(ssh -G "${TARGET#ssh:}" 2>/dev/null | awk '/^hostname /{print $2; exit}')"
    _p="$(ssh -G "${TARGET#ssh:}" 2>/dev/null | awk '/^port /{print $2; exit}')"
    _fp="$(ssh-keyscan -p "${_p:-22}" -t ed25519 "$_h" 2>/dev/null | ssh-keygen -lf - 2>/dev/null | awk '{print $2; exit}')"
    SNAP="$SNAP
$(printf 'ssh_hostkey\t%s' "$_fp")" ;;
esac
printf '%s\n' "$SNAP"

[ -n "$BEFORE" ] || exit 0

MUST_HOLD="machine_id hostname accounts crontabs etc_selfdev verbs_on_path"
get() { printf '%s\n' "$2" | awk -F'\t' -v k="$1" '$1==k{print $2; exit}'; }
OLD="$(cat "$BEFORE")"
rc=0
printf '\n--- graded against %s ---\n' "$BEFORE"
for k in $MUST_HOLD; do
  a="$(get "$k" "$OLD")"; b="$(get "$k" "$SNAP")"
  if [ "$a" = "$b" ]; then printf 'HOLD   %-16s %s\n' "$k" "$b"
  else printf 'MOVED  %-16s %s -> %s\n' "$k" "$a" "$b"; rc=5; fi
done

a="$(get ssh_hostkey "$OLD")"; b="$(get ssh_hostkey "$SNAP")"
if [ -z "$a" ]; then printf 'NOBASE %-16s %s -- the baseline predates this field; re-baseline before trusting a pass\n' ssh_hostkey "$b"; rc=5
elif [ "$a" = "$b" ]; then printf 'HOLD   %-16s %s\n' ssh_hostkey "$b"
elif [ -z "$b" ]; then printf 'ABSENT %-16s was %s -- the route was never opened, so nothing here proves it reaches monkey\n' ssh_hostkey "$a"; rc=5
else printf 'MOVED  %-16s %s -> %s -- THE NAME NOW ANSWERS ON A DIFFERENT HOST\n' ssh_hostkey "$a" "$b"; rc=5; fi

a="$(get backend "$OLD")"; b="$(get backend "$SNAP")"
if [ "$a" = "$b" ] && [ "$b" = wsl ]; then printf 'HOLD   %-16s %s\n' backend "$b"
elif [ "$a" = "$b" ]; then printf 'SAME   %-16s %s -- the migration has not happened on this target\n' backend "$b"
else printf 'FLIP   %-16s %s -> %s\n' backend "$a" "$b"; fi

for k in runners_enabled runners_active; do
  a="$(get "$k" "$OLD")"; b="$(get "$k" "$SNAP")"
  if [ "${b:-0}" -ge "${a:-0}" ] 2>/dev/null; then printf 'OK     %-16s %s (was %s)\n' "$k" "$b" "$a"
  else printf 'LOST   %-16s %s (was %s)\n' "$k" "$b" "$a"; rc=5; fi
done

for k in long_readout soft_lockup; do
  a="$(get "$k" "$OLD")"; b="$(get "$k" "$SNAP")"
  if [ "${b:-0}" -le "${a:-0}" ] 2>/dev/null; then printf 'OK     %-16s %s (was %s)\n' "$k" "$b" "$a"
  else printf 'ROSE   %-16s %s (was %s) -- the pathology this migration exists to end\n' "$k" "$b" "$a"; rc=5; fi
done
exit $rc
