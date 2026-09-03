#!/usr/bin/env bash
# lib/part.sh -- find a script this one calls, across the three layouts it can
# run from: beside this file in a checkout, installed under libexec, or on PATH
# as a verb. Two copies of this existed (ausculte's `part`, unarmed's
# `sibling`) and disagreed: one tested -x and also tried the verb symlink
# beside the caller, the other tested -r. This is the -x one.
#
# TRAP: needs $HERE set by the caller to its own resolved directory.

[ -n "${PART_LIB:-}" ] && return 0
PART_LIB=1

part() {
  local n="$1" p
  for p in "$HERE/$n" "${SELFDEV_LIBEXEC:-/usr/local/libexec/selfdev}/$n" \
           "$HERE/${n%.sh}" "$(command -v "${n%.sh}" 2>/dev/null || true)"; do
    [ -n "$p" ] && [ -x "$p" ] && { printf '%s' "$p"; return 0; }
  done
  return 1
}
