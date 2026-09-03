#!/usr/bin/env bash
set -uo pipefail

usage() {
  cat >&2 <<'USAGE'
constate.sh -- is `vaporwave` a self-dev host yet? Runs on mandark and reaches
in. NOT a verb, installed on no host: it must be able to grade a machine that
carries none of our files.

usage: constate.sh [--target ssh:<host> | wsl:<distro>] [--json]

  --target ssh:vaporwave   by name; dexter:2225                    (default)
  --target wsl:vaporwave   as a distro, via dexter's port 22. The RESCUE route,
                           for use before sshd answers. It cannot open the name,
                           so ssh_hostkey reads ABSENT and it exits 5 BY DESIGN:
                           a host with no port does not conform YET, which is a
                           true statement and not a fault to go and fix.

There is no --diff and no baseline file. monkey's witness graded a MIGRATION,
so it asked "did identity survive"; a fresh host has no before, so this asks
"does it meet the contract" against expectations declared below.

exit: 0 conforms  2 usage  5 a MUST row failed  6 BLIND, could not read it
USAGE
}

TARGET="ssh:vaporwave"; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 || { usage; exit 2; } ;;
    --json)   JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'constate: unknown argument "%s"\n' "$1" >&2; usage; exit 2 ;;
  esac
done

PORT="${VAPORWAVE_PORT:-2225}"
MONKEY_PORT="${MONKEY_PORT:-2224}"
DEXTER_HOST="${DEXTER_HOST:-dexter.tail893f2c.ts.net}"

read -r -d '' PROBE <<'PROBE_EOF'
p() { printf '%s\t%s\n' "$1" "${2:-}"; }
p backend         "$(systemd-detect-virt 2>/dev/null)"
p hostname        "$(hostnamectl --static 2>/dev/null)"
p systemd         "$(systemctl is-system-running 2>/dev/null)"
p failed_units    "$(systemctl --failed --no-legend 2>/dev/null | awk '{print $2}' | paste -sd, -)"
p accounts        "$(getent passwd | awk -F: '$3>=3000 && $3<4000' | wc -l)"
p etc_selfdev     "$(ls /etc/selfdev 2>/dev/null | wc -l)"
p verbs_on_path   "$(ls /usr/local/bin 2>/dev/null | wc -l)"
p sshd_port       "$(ss -ltn 2>/dev/null | awk 'NR>1{print $4}' | sed 's/.*://' | sort -un | tr '\n' ' ')"
ts() {   # EVERY state names itself: `head -1` last in a pipe exits 0, so an earlier grep miss became an empty string that graded as a pass.
  command -v tailscale >/dev/null 2>&1 || { echo absent; return; }
  local j; j="$(tailscale status --json 2>/dev/null)" || { echo daemon-down; return; }
  [ -n "$j" ] || { echo daemon-down; return; }
  printf '%s' "$j" | sed -n 's/.*"BackendState":"\([A-Za-z]*\)".*/\1/p' | head -1 | grep . || echo unreadable
}
p tailscale       "$(ts)"
p fstab_uuid      "$(grep -c '^/dev/disk/by-uuid' /etc/fstab 2>/dev/null)"
p fstab_swapfile  "$(grep -c '^/swapfile' /etc/fstab 2>/dev/null)"
p mem_total_mb    "$(free -m | awk '/^Mem:/{print $2}')"
p root_used_gb    "$(df -BG --output=used / 2>/dev/null | tail -1 | tr -dc 0-9)"
PROBE_EOF

DEXTER_WIN=(ssh -o BatchMode=yes -o ConnectTimeout=20 -p 22 -i "$HOME/.ssh/id_dexter_win" "zach@$DEXTER_HOST")

case "$TARGET" in
  ssh:*) SNAP="$(timeout 90 ssh -o BatchMode=yes -o ConnectTimeout=20 "${TARGET#ssh:}" "$PROBE" 2>/dev/null)" ;;
  wsl:*) SNAP="$(printf '%s' "$PROBE" | timeout 120 "${DEXTER_WIN[@]}" "wsl.exe -d ${TARGET#wsl:} -u root -- bash -s" 2>/dev/null | tr -d '\r')" ;;
  *) printf 'constate: --target must be ssh:<host> or wsl:<distro>, got "%s"\n' "$TARGET" >&2; exit 2 ;;
esac

if [ -z "${SNAP:-}" ] || ! printf '%s' "$SNAP" | grep -q '^hostname'; then
  echo "constate: BLIND -- could not read $TARGET. This is NOT a clean host." >&2
  exit 6
fi

hk()  { timeout 20 ssh-keyscan -p "$1" -t ed25519 "$DEXTER_HOST" 2>/dev/null | ssh-keygen -lf - 2>/dev/null | awk '{print $2}' | head -1; }
OURS="$(hk "$PORT")"; THEIRS="$(hk "$MONKEY_PORT")"   # measured from OUTSIDE, the row a host that is down cannot fake: monkey's witness once passed on identity FILES for a node nothing could reach (senechal#438). The PORT selects the host, so a key identical to monkey's means nothing is listening on ours and the address fell through to whatever else is in the shared netns.
SNAP="$SNAP
ssh_hostkey	${OURS:-ABSENT}"

if [ "$JSON" = 1 ]; then
  printf '%s\n' "$SNAP" | awk -F'\t' 'BEGIN{printf "{"} {printf "%s\"%s\":\"%s\"", (NR>1?",":""), $1, $2} END{print "}"}'
  exit 0
fi
printf '%s\n' "$SNAP"

get() { printf '%s\n' "$SNAP" | awk -F'\t' -v k="$1" '$1==k{print $2; exit}'; }
fail=0
must() { # must <label> <actual> <expected-description> <test-result-rc>
  if [ "$4" -eq 0 ]; then printf 'MUST   %-14s %s\n' "$1" "$2"
  else printf 'FAIL   %-14s %s (want %s)\n' "$1" "$2" "$3"; fail=1; fi
}
note() { printf 'note   %-14s %s\n' "$1" "$2"; }

echo; echo "--- graded against the contract ---"
must backend   "$(get backend)"  "wsl"       "$([ "$(get backend)" = wsl ]; echo $?)"
must hostname  "$(get hostname)" "vaporwave" "$([ "$(get hostname)" = vaporwave ]; echo $?)"
WSL_EXPECTED_FAILURES="getty@tty1.service"   # DEGRADED IS NORMAL ON A DISTRO: getty@tty1 ships enabled with no tty1 to open, and monkey -- this estate's own reference host -- reads degraded too, so demanding `running` is a check nobody can make green. Grade the FAILED UNITS, not the word.
case "$(get systemd)" in
  running) must systemd running "running" 0 ;;
  degraded)
    _unexpected=""
    _fu="$(get failed_units)"
    for _u in ${_fu//,/ }; do
      case " $WSL_EXPECTED_FAILURES " in *" $_u "*) ;; *) _unexpected="$_unexpected $_u" ;; esac
    done
    if [ -z "$_unexpected" ]; then
      must systemd "degraded (only $(get failed_units) -- no tty1 on a distro; monkey reads this too)" "running, or degraded by WSL-impossible units only" 0
    else
      must systemd "degraded:$_unexpected" "no failed unit outside $WSL_EXPECTED_FAILURES" 1
    fi ;;
  *) printf 'BLIND  %-14s "%s" is not a state this grades; not a pass\n' systemd "$(get systemd)"; fail=1 ;;
esac
must fstab     "uuid=$(get fstab_uuid) swapfile=$(get fstab_swapfile)" "both 0 -- either hangs wsl --import" \
     "$([ "$(get fstab_uuid)" = 0 ] && [ "$(get fstab_swapfile)" = 0 ]; echo $?)"
case "$(get tailscale)" in   # a kernel-TUN tailscaled lands a ts-input DROP in the SHARED netns; Running is the hazard, absent/daemon-down/NeedsLogin/Stopped are safe, and `unreadable`/empty are NEITHER -- BLIND is not a pass
  absent|daemon-down|NeedsLogin|Stopped) must tailscale "$(get tailscale)" "not Running" 0 ;;
  Running) must tailscale Running "not Running -- a kernel-TUN ts-input DROP in the shared netns kills dexter's tailnet" 1 ;;
  *) printf 'BLIND  %-14s "%s" is not a state this grades; not a pass\n' tailscale "$(get tailscale)"; fail=1 ;;
esac
if [ -z "$OURS" ]; then
  printf 'ABSENT ssh_hostkey    nothing answers :%s -- the name does not reach this host\n' "$PORT"
  fail=1   # ABSENT IS NEVER A PASS on either route; on wsl: it is expected (see --help) and still exits 5, because a host with no port does not conform yet
elif [ "$OURS" = "$THEIRS" ]; then
  printf 'FAIL   ssh_hostkey    :%s and :%s serve ONE key -- the port is not selecting our host\n' "$PORT" "$MONKEY_PORT"
  fail=1
else
  must ssh_hostkey "$OURS" "distinct from :$MONKEY_PORT" 0
fi
note accounts     "$(get accounts) in uid 3000-3099 (0 until dresse --on has run)"
note etc_selfdev  "$(get etc_selfdev) file(s) (app.pem, gh-app.conf, claude-token is 3)"
note verbs_on_path "$(get verbs_on_path) (0 until wire-release-channel --host)"

[ "$fail" -eq 0 ] || exit 5
echo "constate: conforms."
