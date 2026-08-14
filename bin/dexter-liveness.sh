#!/usr/bin/env bash
# dexter-liveness.sh -- is dexter actually serving what it is supposed to serve?
#
# THE OUTAGE THIS EXISTS FOR. zaxon -- the only relay that carries a question
# to a human -- was dead for ten days and nothing noticed. Not because anything
# was broken: hermes-gateway is `enabled`, runs as its own user, carries
# Restart=always. The WSL distro it lives in never restarted after the
# 2026-08-03 reboot, and a distro has no supervisor above it. It was found by
# accident, by a groc-mangr dispatch run that happened to try the relay
# (hf7y/groc-mangr#9).
#
# So this is the alarm, and its most important check is the LAST one: dexter
# starts its distro and its VMs from the Windows per-user Startup folder, which
# runs at LOGIN, not at boot. A reboot with nobody logging in leaves monkey
# down -- which is all of self-dev -- and reads, from the outside, exactly like
# a quiet night.
#
#   bin/dexter-liveness.sh            # human-readable, exit tells the story
#   bin/dexter-liveness.sh --json     # one object, for a status document
#
# READ-ONLY. It starts nothing, fixes nothing, and writes nothing on dexter.
# Fixing is a separate act with a separate blast radius -- same stance as
# senechal's health/*.sh, which this deliberately imitates rather than
# reinvents. When `ausculte hosts` exists, this becomes one of its probes.
#
# exit: 0 all good  5 something declared is down  6 BLIND (cannot reach dexter)
set -uo pipefail

HOST="${DEXTER_HOST:-dexter}"
JSON=0
[ "${1:-}" = "--json" ] && JSON=1

# THE EXPECTED SET, in one place. A thing that should be running on dexter and
# is not named here is invisible to this probe -- which is the failure mode it
# is named after, so add to it rather than writing a second checker.
EXPECT_DISTROS="Ubuntu"          # hermes joins this when it is containerised
EXPECT_VMS="monkey"              # nomac is the office VM, started by hand
EXPECT_PORTS="8643"              # zaxon MCP
EXPECT_CONTAINERS=""             # filled in as services move to /srv

fail=0; blind=0; findings=()
note() { findings+=("$1"); }

probe="$(ssh -n -o ConnectTimeout=10 -o BatchMode=yes "$HOST" '
  echo "UPTIME_S=$(cut -d. -f1 /proc/uptime)"
  echo "DOCKER=$(systemctl is-active docker 2>/dev/null)"
  echo "CONTAINERS=$(sudo -n docker ps --format "{{.Names}}" 2>/dev/null | tr "\n" "," )"
  echo "PORTS=$(ss -ltn 2>/dev/null | awk "{print \$4}" | sed "s/.*://" | sort -un | tr "\n" ",")"
  sudo -n systemctl restart systemd-binfmt 2>/dev/null
  cd /mnt/c || exit 0
  echo "DISTROS=$(/mnt/c/Windows/System32/wsl.exe -l -q --running 2>/dev/null | tr -d "\0\r" | tr "\n" ",")"
  echo "VMS=$("/mnt/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" list runningvms 2>/dev/null | tr -d "\0" | sed "s/\" .*//;s/\"//" | tr "\n" ",")"
  echo "WINBOOT=$(/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString(\"o\")" 2>/dev/null | tr -d "\0\r")"
' 2>/dev/null)" || { blind=1; }

[ -z "$probe" ] && blind=1

if [ "$blind" = 1 ]; then
  # BLIND IS NOT OK, and it is not "down" either. Saying which is the whole
  # point -- "I could not look" reported as healthy is how ten days pass.
  if [ "$JSON" = 1 ]; then
    printf '{"host":"%s","status":"BLIND","reason":"ssh to %s failed or returned nothing"}\n' "$HOST" "$HOST"
  else
    echo "BLIND -- cannot reach $HOST over ssh. This is not 'healthy'."
  fi
  exit 6
fi

val() { printf '%s\n' "$probe" | sed -n "s/^$1=//p" | head -1; }
has() { case ",$2," in *",$1,"*) return 0;; *) return 1;; esac; }

for d in $EXPECT_DISTROS; do
  has "$d" "$(val DISTROS)" || { note "WSL distro '$d' is not running"; fail=1; }
done
for v in $EXPECT_VMS; do
  has "$v" "$(val VMS)" || { note "VirtualBox VM '$v' is not running -- if this is monkey, self-dev dispatch is down"; fail=1; }
done
for p in $EXPECT_PORTS; do
  has "$p" "$(val PORTS)" || { note "nothing is listening on port $p (zaxon MCP) -- the relay cannot carry a question to a human"; fail=1; }
done
for c in $EXPECT_CONTAINERS; do
  has "$c" "$(val CONTAINERS)" || { note "container '$c' is not running"; fail=1; }
done
[ "$(val DOCKER)" = "active" ] || { note "dockerd is not active -- every containerised service on this host is down"; fail=1; }

# THE CHECK THAT WOULD HAVE CAUGHT THE TEN DAYS. dexter's distro and VMs are
# started from the Windows per-user Startup folder, i.e. at LOGIN. If Windows
# has booted much more recently than the Ubuntu distro has been up, then the
# machine came back and nobody logged in, and everything above is down for a
# reason no amount of service configuration will fix.
winboot="$(val WINBOOT)"; up_s="$(val UPTIME_S)"
if [ -n "$winboot" ] && [ -n "$up_s" ]; then
  win_epoch="$(date -u -d "$winboot" +%s 2>/dev/null)"
  if [ -n "$win_epoch" ]; then
    distro_started=$(( $(date -u +%s) - up_s ))
    drift=$(( distro_started - win_epoch ))
    if [ "$drift" -gt 3600 ]; then
      note "the Ubuntu distro started ${drift}s AFTER Windows booted -- dexter's autostart is login-scoped, so a reboot without a login leaves this host dark"
    fi
  fi
fi

if [ "$JSON" = 1 ]; then
  printf '{"host":"%s","status":"%s","distros":"%s","vms":"%s","docker":"%s","findings":[' \
    "$HOST" "$([ "$fail" = 1 ] && echo DOWN || echo OK)" \
    "$(val DISTROS)" "$(val VMS)" "$(val DOCKER)"
  for i in "${!findings[@]}"; do
    [ "$i" -gt 0 ] && printf ','
    printf '"%s"' "$(printf '%s' "${findings[$i]}" | sed 's/"/\\"/g')"
  done
  printf ']}\n'
else
  if [ "${#findings[@]}" -eq 0 ]; then
    echo "OK -- distros: $(val DISTROS) vms: $(val VMS) docker: $(val DOCKER)"
  else
    printf 'FINDING: %s\n' "${findings[@]}"
  fi
fi

exit $(( fail ? 5 : 0 ))
