#!/usr/bin/env bash
# monkey-tailscale.sh -- put the self-dev host `monkey` on the tailnet.
#
# WHY. monkey dispatches nightly and mandark cannot reach it. There is no
# ssh alias, the name does not resolve, and the only working route is two
# hops (mandark -> dexter -> 127.0.0.1:2225) using a key that lives ON
# dexter, which is why `ssh -J` cannot authenticate the last hop: ProxyJump
# offers the LOCAL key there. Every ecosim sensor therefore reports monkey
# BLIND -- correctly, and uselessly.
#
# Tailscale fixes this at the right layer. It gives monkey a name that
# resolves from mandark directly, so `ecosim`'s transport resolver picks it
# up with NO code change and no ssh config edit (see ecosim/lib/hosts.py,
# which tries an ssh alias first and the tailnet second, precisely so a new
# host becomes readable by joining rather than by being listed).
#
# WHAT THIS IS NOT. It does not make the tailnet the source of truth for
# WHICH hosts dispatch. That remains `schedule/_paced.*.conf`. Measured
# 2026-08-04: the tailnet held mandark/dexter/homeassistant while the
# dispatch set was mandark/dexter/monkey -- the two differ in both
# directions, and a census taken from tailscale would have invented one
# participant and dropped another. Transport only.
#
#   ./monkey-tailscale.sh --check      probe only; changes nothing, no sudo
#   ./monkey-tailscale.sh --install    install tailscaled and join the tailnet
#
# Requires for --install, and refuses to guess at either:
#   TS_AUTHKEY        a tailnet auth key (https://login.tailscale.com/admin/settings/keys)
#                     Use an EPHEMERAL=false, PREAUTHORIZED key tagged for
#                     this host. Passed by ENVIRONMENT, never a file here.
#   MONKEY_SUDO_PASS  zach@monkey has sudo but NOT NOPASSWD, and installing a
#                     system daemon needs root. Passed by ENVIRONMENT, fed to
#                     `sudo -S` on stdin, never in argv and never echoed.
#
# A secret in a tracked file is the discipline row this repo will not break.
#
# AFTER A SUCCESSFUL --install THIS IS MACHINE-WIDE CONFIG on another host:
# a systemd unit (tailscaled) and a new network identity. The script prints
# the `notify-senechal` line to run; senechal owns knowing it exists.

set -euo pipefail

JUMP="${MONKEY_JUMP:-dexter}"          # reached via ~/.ssh/config alias
KEYFILE="${MONKEY_KEYFILE:-\$HOME/.ssh/selfdev_monkey}"   # lives ON the jump host
PORT="${MONKEY_PORT:-2225}"
USER_ON_MONKEY="${MONKEY_USER:-zach}"
HOSTNAME_WANTED="${MONKEY_TS_HOSTNAME:-monkey}"

die()  { printf 'monkey-tailscale: %s\n' "$*" >&2; exit 1; }
info() { printf '  %-8s %s\n' "$1" "$2"; }

# Run a script on monkey, through dexter. The script is base64-encoded so it
# crosses two shells without quoting damage -- the ancestor script records a
# post-install command that only just survived that assembly, and this avoids
# the problem rather than re-solving it each time.
on_monkey() {
  local script b64
  script="$1"
  b64="$(printf '%s' "$script" | base64 -w0)"
  ssh -o BatchMode=yes -o ConnectTimeout=10 "$JUMP" \
    "ssh -i $KEYFILE -o BatchMode=yes -o ConnectTimeout=10 -p $PORT \
        ${USER_ON_MONKEY}@127.0.0.1 \"echo $b64 | base64 -d | bash -s\""
}

MODE="${1:---check}"

case "$MODE" in
--check)
  echo "== monkey tailscale (--check) =="
  out="$(on_monkey '
    printf "HOST=%s\n" "$(hostname -s)"
    printf "TAILSCALE=%s\n" "$(command -v tailscale || echo none)"
    printf "TAILSCALED=%s\n" "$(systemctl is-active tailscaled 2>/dev/null || echo inactive)"
    printf "STATUS=%s\n" "$(tailscale ip -4 2>/dev/null | head -1 || echo none)"
    printf "SUDO_NOPASS=%s\n" "$(sudo -n true 2>/dev/null && echo yes || echo no)"
    printf "OS=%s\n" "$(. /etc/os-release; echo "$ID $VERSION_ID")"
  ' 2>&1)" || die "cannot reach monkey through $JUMP -- $out"

  # Parsed, never eval'd. `OS=ubuntu 24.04` through `eval` runs `24.04` as a
  # command -- which is both a bug and a reminder that this text came off
  # another machine and has no business being executed here.
  field() { printf '%s\n' "$out" | sed -n "s/^$1=//p" | head -1; }
  HOST="$(field HOST)";           TAILSCALE="$(field TAILSCALE)"
  TAILSCALED="$(field TAILSCALED)"; STATUS="$(field STATUS)"
  SUDO_NOPASS="$(field SUDO_NOPASS)"; OS="$(field OS)"
  [ "$HOST" = "monkey" ] || die "reached a host named '$HOST', not monkey -- refusing to go further"
  info OK "reached monkey through $JUMP ($OS)"
  if [ "$TAILSCALE" = none ]; then
    info MISSING "tailscale is not installed"
  else
    info OK "tailscale at $TAILSCALE (daemon: $TAILSCALED, ip: $STATUS)"
  fi
  [ "$SUDO_NOPASS" = yes ] \
    && info OK      "sudo needs no password" \
    || info NEEDS   "sudo requires a password -> set MONKEY_SUDO_PASS for --install"
  echo
  echo "check only. Nothing changed."
  ;;

--install)
  [ -n "${TS_AUTHKEY:-}" ]       || die "TS_AUTHKEY is unset. Generate one at
    https://login.tailscale.com/admin/settings/keys and export it. This script
    will not invent a credential, and will not read one out of a file."
  [ -n "${MONKEY_SUDO_PASS:-}" ] || die "MONKEY_SUDO_PASS is unset. zach@monkey
    has sudo but not NOPASSWD, so installing a daemon needs it. Export it for
    this one command; do not add it to a file in this repo."

  echo "== monkey tailscale (--install) =="
  # Idempotent: if tailscaled is already up with an address, this re-runs
  # `tailscale up` with the same flags, which is a no-op rather than a second
  # node. The auth key and sudo password reach the remote shell on STDIN of
  # `sudo -S` and via the environment respectively; neither appears in argv,
  # so neither is visible in `ps` on monkey.
  out="$(TS_AUTHKEY="$TS_AUTHKEY" MONKEY_SUDO_PASS="$MONKEY_SUDO_PASS" on_monkey '
    set -e
    S() { printf "%s\n" "$MONKEY_SUDO_PASS" | sudo -S -p "" "$@"; }
    if ! command -v tailscale >/dev/null 2>&1; then
      echo "installing tailscale..."
      curl -fsSL https://tailscale.com/install.sh -o /tmp/ts-install.sh
      S bash /tmp/ts-install.sh
      rm -f /tmp/ts-install.sh
    else
      echo "tailscale already present"
    fi
    S systemctl enable --now tailscaled
    S tailscale up --authkey="$TS_AUTHKEY" --hostname="'"$HOSTNAME_WANTED"'" --ssh=false
    printf "IP=%s\n" "$(tailscale ip -4 | head -1)"
    printf "NAME=%s\n" "$(tailscale status --json | grep -o "\"DNSName\":\"[^\"]*\"" | head -1)"
  ' 2>&1)" || die "install failed:
$out"
  printf '%s\n' "$out" | sed 's/^/  /'
  echo
  echo "Now verify FROM mandark (this is the witness that matters):"
  echo "    tailscale status | grep monkey"
  echo "    ssh monkey hostname -s        # should print: monkey"
  echo "    cd ~/Documents/Projects/ecosim && sonde run rotation | grep monkey"
  echo
  echo "Then file it, because a systemd unit on another host is machine-wide:"
  echo "    notify-senechal 'monkey joined the tailnet: tailscaled installed and"
  echo "    enabled on the monkey VM (VirtualBox guest on dexter). Owned by"
  echo "    realisateur/provision/monkey-tailscale.sh. Retire with:"
  echo "    sudo tailscale logout && sudo systemctl disable --now tailscaled'"
  ;;

*) die "usage: monkey-tailscale.sh [--check|--install]" ;;
esac
