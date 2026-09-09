#!/usr/bin/env bash
[ -n "${SELFDEV_SSH_TRANSPORT_LIB:-}" ] && return 0  # selfdev-ssh-transport.sh: one ssh transport, shared (realisateur#895)
SELFDEV_SSH_TRANSPORT_LIB=1

SELFDEV_SSH_BIN="${SELFDEV_SSH_BIN:-ssh}"
SELFDEV_SSH_TIMEOUT="${SELFDEV_SSH_TIMEOUT:-20}"

selfdev_ssh_ship_run() { # <host> <sudo:0|1> <tar-root> <paths-array-name> <script> [args...]
  local host="$1" want_sudo="$2" root="$3" paths_name="$4" script="$5"; shift 5
  local -n _ship_paths="$paths_name"
  local q="" a
  for a in "$@"; do q="$q $(printf '%q' "$a")"; done
  local sudo_prefix=""
  [ "$want_sudo" = 1 ] && sudo_prefix='sudo -n '
  tar -c -C "$root" "${_ship_paths[@]}" 2>/dev/null \
    | "$SELFDEV_SSH_BIN" -o BatchMode=yes -o ConnectTimeout="$SELFDEV_SSH_TIMEOUT" "$host" \
        "set -u
         d=\$(mktemp -d) || exit 6
         trap 'rm -rf \"\$d\"' EXIT
         tar -x -C \"\$d\" || exit 6
         ${sudo_prefix}bash \"\$d/$script\"$q"
}
