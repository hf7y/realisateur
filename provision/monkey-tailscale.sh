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
# A secret in a tracked file is the discipline row this repo will not break.
# TS_AUTHKEY is read from the environment HERE and then sent to monkey on
# STDIN -- never as a remote environment variable (ssh does not forward it)
# and never in argv (visible in `ps`). See push_secret.
#
# PRECONDITION: passwordless sudo on monkey, from ./monkey-nopasswd.sh.
# This script used to accept MONKEY_SUDO_PASS as an alternative; that path
# was removed because it doubled the secrets in flight to save one command.
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

# Put a secret on monkey, reading it from STDIN, at mode 0600.
#
# WHY NOT AN ENVIRONMENT VARIABLE, which is what the first version did and is
# the bug this function exists to make impossible: `FOO=x ssh host 'echo $FOO'`
# sets FOO on the LOCAL side. ssh does not forward arbitrary environment
#   [rest of this note: vault:realisateur/guard-archaeology-20260817.md]
push_secret() {                 # $1 = filename under $HOME on monkey
  ssh -o BatchMode=yes -o ConnectTimeout=10 "$JUMP" \
    "ssh -i $KEYFILE -o BatchMode=yes -o ConnectTimeout=10 -p $PORT \
        ${USER_ON_MONKEY}@127.0.0.1 \"umask 077; cat > \\\$HOME/$1\""
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
    && info OK      "sudo needs no password; --install can run unattended" \
    || info NEEDS   "sudo needs a password -> run ./monkey-nopasswd.sh --install once"
  echo
  echo "check only. Nothing changed."
  ;;

--install)
  [ -n "${TS_AUTHKEY:-}" ] || die "TS_AUTHKEY is unset. Generate one at
    https://login.tailscale.com/admin/settings/keys and export it. This script
    will not invent a credential, and will not read one out of a file."

  # PRECONDITION, not a fallback. An earlier version accepted a sudo password
  # as an alternative and fed it to `sudo -S`; that path is gone, because it
  # doubled the number of secrets in flight to save one human command. Run
  # ./monkey-nopasswd.sh --install once and this becomes unattended forever.
  ssh -o BatchMode=yes -o ConnectTimeout=10 "$JUMP" \
     "ssh -i $KEYFILE -o BatchMode=yes -p $PORT ${USER_ON_MONKEY}@127.0.0.1 \
      'sudo -n true'" >/dev/null 2>&1 \
    || die "sudo on monkey still needs a password. Run
    ./monkey-nopasswd.sh --install once, from a terminal, and re-run this."
  echo "  OK       sudo is passwordless on monkey"

  echo "== monkey tailscale (--install) =="

  # The key travels on STDIN into a 0600 file. See push_secret for why not
  # env (it does not cross ssh) and why not argv (visible in `ps`).
  printf '%s' "$TS_AUTHKEY" | push_secret .ts-authkey \
    || die "could not place the auth key on monkey"

  # Idempotent: re-running `tailscale up` with the same flags is a no-op
  # rather than a second node.
  out="$(on_monkey '
    set -e
    K="$HOME/.ts-authkey"
    # Delete the key on ANY exit path, including failure. A credential left
    # in a home directory because the script died early is worse than the
    # failure that killed it.
    trap "rm -f \"$K\"" EXIT
    KEY="$(cat "$K" 2>/dev/null || true)"

    # THE GUARD THIS SCRIPT DID NOT HAVE, and the reason the first run hung.
    # `tailscale up --authkey=` with an EMPTY value is not an error to
    # tailscale: it silently falls back to interactive browser login and
    # blocks forever. On an unattended two-hop run that is indistinguishable
    # from a network stall. Refuse loudly instead, and refuse BEFORE the
    # call rather than diagnosing the hang afterwards.
    case "$KEY" in
      "")        echo "REFUSED: the auth key arrived EMPTY on monkey" >&2; exit 2 ;;
      tskey-*)   : ;;
      *)         echo "REFUSED: value does not look like a tailscale auth key" >&2; exit 2 ;;
    esac

    if ! command -v tailscale >/dev/null 2>&1; then
      echo "installing tailscale..."
      curl -fsSL https://tailscale.com/install.sh -o /tmp/ts-install.sh
      sudo -n bash /tmp/ts-install.sh >/dev/null 2>&1
      rm -f /tmp/ts-install.sh
    else
      echo "tailscale already present: $(tailscale --version | head -1)"
    fi
    sudo -n systemctl enable --now tailscaled

    # --timeout so a wedged join fails instead of hanging the whole chain.
    sudo -n tailscale up --authkey="$KEY" \
        --hostname="'"$HOSTNAME_WANTED"'" --ssh=false --timeout=90s
    printf "IP=%s\n" "$(tailscale ip -4 | head -1)"
    printf "BACKEND=%s\n" "$(tailscale status | head -1)"
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
