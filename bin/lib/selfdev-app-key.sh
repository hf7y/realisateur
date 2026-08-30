#!/usr/bin/env bash
# selfdev-app-key.sh -- WHERE THE SELF-DEV GITHUB APP CREDENTIAL LIVES.
# One answer, one host-wide location, sourced by every reader.
#
# TRAPS (the rest of this header is in the vault): the key was once on disk
# under four names across two hosts, and `selfdev-credentials.sh --apply` read a
# fifth that never existed -- so it refused to converge secretaire@monkey for
# want of a key sitting two directories away (realisateur#209). A copy per
# account is also one thing to rotate per account, and a rotation that misses
# one leaves that account minting tokens from a revoked key. All four are
# RETIRED; bin/tests/selfdev-host-credential.test.sh is what keeps them so.

[ -n "${SELFDEV_APP_KEY_LIB:-}" ] && return 0
SELFDEV_APP_KEY_LIB=1

SELFDEV_APP_DIR="${SELFDEV_APP_DIR:-/etc/selfdev}"
SELFDEV_APP_CONF_DEFAULT="$SELFDEV_APP_DIR/gh-app.conf"
SELFDEV_APP_PEM_DEFAULT="$SELFDEV_APP_DIR/app.pem"
SELFDEV_APP_GROUP="${SELFDEV_APP_GROUP:-selfdev}"

# selfdev_app_conf -- the conf path this host should read. Prints it; says
# nothing about whether it exists, which is the caller's business to report.
selfdev_app_conf() {
  printf '%s' "${SELFDEV_APP_CONF:-$SELFDEV_APP_CONF_DEFAULT}"
}

# selfdev_app_load -- source the conf, exporting SELFDEV_APP_ID / _APP_KEY /
# _GH_OWNER. rc 0 loaded, 1 no conf, 2 conf present but incomplete.
#
selfdev_app_load() {
  local conf; conf="$(selfdev_app_conf)"
  local env_id="${SELFDEV_APP_ID:-}" env_key="${SELFDEV_APP_KEY:-}" env_owner="${SELFDEV_GH_OWNER:-}"
  if [ -r "$conf" ]; then
    # shellcheck disable=SC1090
    . "$conf"
  elif [ -z "$env_id$env_key" ]; then
    return 1
  fi
  [ -n "$env_id" ]    && SELFDEV_APP_ID="$env_id"
  [ -n "$env_key" ]   && SELFDEV_APP_KEY="$env_key"
  [ -n "$env_owner" ] && SELFDEV_GH_OWNER="$env_owner"
  SELFDEV_APP_KEY="${SELFDEV_APP_KEY:-$SELFDEV_APP_PEM_DEFAULT}"
  export SELFDEV_APP_ID SELFDEV_APP_KEY SELFDEV_GH_OWNER
  [ -n "${SELFDEV_APP_ID:-}" ] && [ -n "${SELFDEV_APP_KEY:-}" ] || return 2
  return 0
}

# selfdev_app_readable -- can THIS process actually read the key? The witness
# is a read, not a stat: group membership that has not been picked up by the
# current session (a `usermod -aG` before the next login) stats fine and reads
# EACCES, and that difference is the whole failure mode of a group-readable
# secret.
selfdev_app_readable() {
  local key="${1:-${SELFDEV_APP_KEY:-$SELFDEV_APP_PEM_DEFAULT}}"
  head -c 1 -- "$key" >/dev/null 2>&1
}
