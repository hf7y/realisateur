#!/usr/bin/env bash
# roster-set.sh -- WHICH REPOSITORIES THIS ESTATE SWEEPS. One list, one file.
#
# Was typed into three sweeps: three chances to add a repo to two of them.
# STILL TYPED -- hf7y owns roughly twice what this estate sweeps, and uid
# 3000-3099 misses the ecosystem repos that carry decisions and never dispatch.

[ -n "${ROSTER_SET_LIB:-}" ] && return 0
ROSTER_SET_LIB=1

. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/estate-set.sh"
ROSTER_OWNER="${ROSTER_OWNER:-$GH_ESTATE_OWNER}"

# SWEPT, NOT ARMED. Membership says which repos to READ; liveness is
# lib/arming.sh's authority, read at run time. NOT `apms`: a live ROSTER row
# whose repo does not exist, and a 404 here makes the whole sweep BLIND.
ROSTER_PROJECTS=(
  abletim baudin bibliothecaire chezz crt dcp-gate-site ecosim gardien
  groc-mangr nine-speakers realisateur scheduler secretaire senechal
  sequestria vim-arcade wtul
)

# ECOSYSTEM: carries decisions, never dispatches. WIRED, NOT ARMED -- swept by
# decision-rot, given no account, no crontab row and no quota.
#
# EIGHT ADDED 2026-08-22, Zach-directed. 64 open issues then sat in ELEVEN
# repos no sensor looked at -- `tempo` read BLIND, `check-project-busy` refused
# the name, decision-rot walked past them. They were invisible, not idle.
#
# ARMING IS A SEPARATE ACT and deliberately not done here: being swept costs
# one API read per run, being armed costs quota every night.
ROSTER_ECOSYSTEM=(  # dcp-gate-site moved to ROSTER_PROJECTS 2026-09-02 (#905): onboarded live with an account 2026-08-28, so it now dispatches
  verbs front-door basheur
  musc-2300 scriba-senatus french-textbook
  etalon vitae space-canon maitre
)

ROSTER=("${ROSTER_PROJECTS[@]}" "${ROSTER_ECOSYSTEM[@]}")
