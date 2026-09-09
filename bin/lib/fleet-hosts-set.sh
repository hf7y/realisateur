#!/usr/bin/env bash
# fleet-hosts-set.sh -- WHICH HOSTS bin/ausculte.sh's fleet probe(s) read. One
# list, one file, the same shape as roster-set.sh/estate-set.sh (hf7y/realisateur#1139).
#
# THE DEFECT THIS CLOSES: ausculte.sh's fleet probe read
# `ssh ${AUSCULTE_FLEET_HOST:-monkey}` -- a single default, not a set. A second
# host (vaporwave) was therefore never asked, and its silence read as health --
# this estate's signature defect, at the scale of a whole host. See
# uid-band comments in bin/monkey-status-collect.py for why the SAME shape let
# svc-vaporwave run undetected for weeks; unrelated code, same lesson.
#
# A host in this set that cannot be reached must read BLIND, never be folded
# silently into an OK -- ausculte.sh's fleet probe enforces that, this file
# only says who is asked.

[ -n "${FLEET_HOSTS_SET_LIB:-}" ] && return 0
FLEET_HOSTS_SET_LIB=1

. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/estate-set.sh"

# AUSCULTE_FLEET_HOSTS: space-separated override (tests, and any host not yet
# ready to be asked in production). Unset means the estate's real fleet.
if [ -n "${AUSCULTE_FLEET_HOSTS:-}" ]; then
  # shellcheck disable=SC2206  # deliberate word-split: a space-separated host list, not a path
  FLEET_HOSTS=(${AUSCULTE_FLEET_HOSTS})
else
  # monkey: the estate's original self-dev host. vaporwave: the second one
  # media-arts-collective projects (wavebucks, inventory-app) land on
  # (hf7y/realisateur#1130/#1131/#1132) -- added here so ausculte cannot go on
  # reading vaporwave's silence as health once accounts exist there.
  FLEET_HOSTS=(monkey vaporwave)
fi
