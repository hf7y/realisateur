#!/usr/bin/env bash
# selfdev-app-key.sh -- WHERE THE SELF-DEV GITHUB APP CREDENTIAL LIVES.
# One answer, one host-wide location, sourced by every reader.
#
# ============================================================================
# WHY THIS EXISTS: four names for one key
# ============================================================================
#
# There is exactly ONE self-dev GitHub App (id 4521586, MONKEY.md 11.1). As of
# 2026-08-12 its private key was on disk under four different names, and the
# scripts that place it and the scripts that read it did not agree:
#
#   ~/.config/selfdev/app.pem              on each of 13 accounts (13 copies)
#   ~/.config/selfdev/monkey/monkey.pem    mandark, written by selfdev-gh-app.sh --adopt
#   ~/.config/selfdev/ecosim/ecosim.pem    mandark, a DIFFERENT key, orphaned
#   ~/.config/selfdev/app.pem              mandark -- the path the converge
#                                          step reads, which never existed
#
# The cost was not hypothetical. `selfdev-credentials.sh --apply <account>`
# exists to converge an account that is missing the credential; it looked for
# the last of those four, found nothing, and reported "cannot converge this
# without a human (a new App key needs a browser click)" -- while the key sat
# two directories away. Hit live converging secretaire@monkey (realisateur#209).
# Thirteen copies also means thirteen things to rotate, and a rotation that
# misses one leaves an account minting tokens from a revoked key.
#
# Zach, 2026-08-12: "settle on one app key and make sure everything agrees.
# the drift is a problem. make the key accessible host wide or something and
# ensure the new setting works."
#
# ============================================================================
# THE LAYOUT, and why /etc
# ============================================================================
#
#   /etc/selfdev/gh-app.conf   0644 root:root      SELFDEV_APP_ID/KEY/GH_OWNER
#   /etc/selfdev/app.pem       0640 root:selfdev   the ONE private key
#   group `selfdev`                                every uid 3000-3099 account
#
# /etc is the FHS location for host-specific configuration, which is exactly
# what "which App this host mints tokens as" is. The key is one file readable
# by a group rather than a copy per account: a copy per account is a fact
# stored 13 times, and this whole family of scripts exists because facts stored
# more than once drift. Rotation becomes one `install`, not thirteen.
#
# WHAT THIS DOES NOT DO: it does not weaken the secret. 0640 root:selfdev is
# readable by exactly the accounts that already each held their own 0600 copy
# of the same bytes. The App key was never per-account-secret; it was
# per-account-DUPLICATED, which is strictly worse.
#
# ============================================================================
# RESOLUTION ORDER -- two entries, and deliberately no per-account fallback
# ============================================================================
#
#   $SELFDEV_APP_CONF        explicit, per invocation (tests, a second App)
#   /etc/selfdev/gh-app.conf the host-wide answer
#
# A `~/.config/selfdev/` fallback is NOT in this list, and leaving it out is
# the point: a fallback is a second source, and a second source is the drift
# this file exists to end. bin/selfdev-credentials.sh FLAGS any surviving
# per-account copy so the migration is finishable and verifiable rather than
# indefinite.

# Guard against double-sourcing: several scripts source this AND their own
# credential-set lib, which sources it too.
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
# An ENV value already set wins, and is not overwritten by the file: that is
# how a test or a second App points one invocation somewhere else without
# editing host config.
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
