#!/usr/bin/env bash
# selfdev-ssh-transport.sh -- the one way a provisioning script drives a
# target host from the operator's machine (realisateur#895). Same shape
# selfdev-credentials.sh already proved: BatchMode ssh, a bounded timeout, one
# knob pair every caller shares instead of inventing its own (CRED_SSH_BIN,
# DRESSE_SSH_BIN, ...).
#
# WHY TAR, NOT A HEREDOC: the scripts this ships (provision-selfdev-user.sh,
# setup-selfdev-project.sh, unland-foreign-clone.sh, ...) already assume they
# ARE the payload -- they read lib/ beside them, take root and act. Shipping
# the tree and running the SAME script unmodified on the target is smaller and
# safer than teaching each one to reimplement itself inline over ssh.

[ -n "${SELFDEV_SSH_TRANSPORT_LIB:-}" ] && return 0
SELFDEV_SSH_TRANSPORT_LIB=1

SELFDEV_SSH_BIN="${SELFDEV_SSH_BIN:-ssh}"
SELFDEV_SSH_TIMEOUT="${SELFDEV_SSH_TIMEOUT:-20}"

# selfdev_ssh_ship_run <host> <sudo:0|1> <tar-root> <paths> <script> [args...]
#
# Tars <paths> (a space-separated list, relative to <tar-root>) over ssh to a
# fresh remote tmpdir, runs <script> (a path inside that tree, e.g.
# bin/foo.sh) there with [args...], and removes the tmpdir on the remote's own
# exit. Streams the remote's stdout/stderr as they arrive; returns its exit
# code, or 6 (BLIND: nothing on the target ran at all) if ssh, the tar
# extraction or the mktemp on the far side failed before the script started.
selfdev_ssh_ship_run() {
  local host="$1" want_sudo="$2" root="$3" paths="$4" script="$5"; shift 5
  local q="" a
  for a in "$@"; do q="$q $(printf '%q' "$a")"; done
  local sudo_prefix=""
  [ "$want_sudo" = 1 ] && sudo_prefix='sudo -n '
  # shellcheck disable=SC2086  # $paths is a caller-built list of tar members; word-splitting is the point
  tar -c -C "$root" $paths 2>/dev/null \
    | "$SELFDEV_SSH_BIN" -o BatchMode=yes -o ConnectTimeout="$SELFDEV_SSH_TIMEOUT" "$host" \
        "set -u
         d=\$(mktemp -d) || exit 6
         trap 'rm -rf \"\$d\"' EXIT
         tar -x -C \"\$d\" || exit 6
         ${sudo_prefix}bash \"\$d/$script\"$q"
}
