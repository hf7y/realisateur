#!/usr/bin/env bash
# roster-set.sh -- WHICH REPOSITORIES THIS ESTATE SWEEPS. One list, one file.
#
# Was typed into three sweeps: three chances to add a repo to two of them.
# STILL TYPED -- the org lists 51, and uid 3000-3099 misses the ecosystem
# repos that carry decisions and never dispatch.

[ -n "${ROSTER_SET_LIB:-}" ] && return 0
ROSTER_SET_LIB=1

. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/gh-owner.sh"
ROSTER_OWNER="${ROSTER_OWNER:-$GH_ESTATE_OWNER}"

# SWEPT, NOT ARMED. Membership says which repos to READ. Liveness is a
# different authority, read at run time by lib/arming.sh.
# NOT `apms`: a live ROSTER row whose repo does not exist, and a 404 here makes
# the whole sweep BLIND. That is hf7y/scheduler's finding.
ROSTER_PROJECTS=(
  abletim baudin bibliothecaire chezz crt ecosim gardien groc-mangr
  nine-speakers realisateur scheduler secretaire senechal sequestria
  vim-arcade wtul
)

# ECOSYSTEM: carries decisions, never dispatches. WIRED, NOT ARMED -- swept by
# decision-rot, given no account, no crontab row and no quota.
#
# EIGHT ADDED 2026-08-22, Zach-directed ("wiring up projects was the original
# job of realisateur"). 64 open issues then sat in ELEVEN repos no sensor
# looked at: `tempo` read BLIND, `check-project-busy` refused the name, and
# decision-rot walked past them, so an answered decision aged forever while
# `ausculte rot` read OK. They were invisible rather than idle.
#
# ARMING IS A SEPARATE ACT and deliberately not done here: being swept costs
# one API read per run, being armed costs quota every night.
ROSTER_ECOSYSTEM=(
  verbs front-door basheur
  dcp-gate-site musc-2300 scriba-senatus french-textbook
  etalon vitae space-canon
)

ROSTER=("${ROSTER_PROJECTS[@]}" "${ROSTER_ECOSYSTEM[@]}")
