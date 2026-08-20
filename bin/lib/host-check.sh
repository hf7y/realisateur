#!/usr/bin/env bash
# host-check.sh -- "am I already on <host>?" in ONE place.
#
# realisateur#434 and #433 named the identical defect twice: a probe run ON
# its own target host still shelled out over ssh to reach it -- root@monkey
# ssh'ing to "monkey" -- and died on a host-key check that self-ssh will
# never satisfy. Two copies of this check would drift the way the rest of
# this file's siblings warn about; there is exactly one.
#
# SELFDEV_LOCAL_HOSTNAME overrides the detected hostname so a hermetic test
# can exercise the "already local" branch without a real hostname match.

on_target_host() {
  local target="$1"
  local here="${SELFDEV_LOCAL_HOSTNAME:-$(hostname -s 2>/dev/null || hostname 2>/dev/null)}"
  [ -n "$here" ] && [ "$here" = "${target%%.*}" ]
}
