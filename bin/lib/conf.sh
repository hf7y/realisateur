#!/usr/bin/env bash
# conf.sh -- read a scheduler conf's PROJECT_REPO_PATH, EXPANDED.
#
# TRAPS (the rest of this header is in the vault):
# THE FOUR THIS HEADER USED TO NAME AS STILL BROKEN are settled (#73), two of
# them by DELETION: milestone-audit.sh and install-silence-audit.sh were
# RETIRED in b3fef3d, closeout-lint.sh was fixed in place, session-marker.sh
# converted here. The sweep found three MORE the list never named --
# reach-lint.sh -- which is the
# argument for a ratchet over a list, so bin/tests/conf.test.sh section C now
# scans the tree for the shape and no prose here has to be kept accurate.
# Expansion is deliberately LIMITED to $HOME and ${HOME}. `eval` would expand
# anything, and a conf is a file this repo does not own on a host it may not
# own either; command substitution inside one must not become code this script
# runs. If a conf ever needs a second variable, add it here by name.

conf_repo_path() {
  local conf="$1" p
  # The value is everything after the first `=`, minus a trailing comment and
  # surrounding whitespace, minus one matched pair of quotes. Deliberately NOT
  # three lookbehinds for three quote styles: one regex per shape is how the
  # readers multiplied in the first place.
  p="$(grep -E '^[[:space:]]*PROJECT_REPO_PATH=' "$conf" 2>/dev/null | head -1)"
  [ -n "$p" ] || return 1
  p="${p#*=}"
  p="${p%%[[:space:]]#*}"
  p="${p#"${p%%[![:space:]]*}"}"
  p="${p%"${p##*[![:space:]]}"}"
  case "$p" in
    '"'*'"') p="${p#\"}"; p="${p%\"}" ;;
    "'"*"'") p="${p#\'}"; p="${p%\'}" ;;
  esac
  [ -n "$p" ] || return 1
  p="${p//\$\{HOME\}/$HOME}"
  p="${p//\$HOME/$HOME}"
  printf '%s\n' "$p"
}
