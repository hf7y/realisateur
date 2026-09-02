#!/usr/bin/env bash
# roster-set.sh -- WHICH REPOSITORIES THIS ESTATE SWEEPS. One list, one file.
#
# Was typed into three sweeps: three chances to add a repo to two of them.
# STILL TYPED -- hf7y owns roughly twice what this estate sweeps, and uid
# 3000-3099 misses the ecosystem repos that carry decisions and never dispatch.

[ -n "${SWEEP_SET_LIB:-}" ] && return 0  # exported as SWEEP*, not ROSTER*: distinct from scheduler's schedule/ROSTER, the sole arming authority (#905)
SWEEP_SET_LIB=1

. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/estate-set.sh"
SWEEP_OWNER="${SWEEP_OWNER:-$GH_ESTATE_OWNER}"

# SWEPT, NOT ARMED. Membership says which repos to READ; liveness is
# lib/arming.sh's authority, read at run time. `apms` here is `apms-2173`,
# its real repo name: $OWNER/$p below is a GitHub path, not a ROSTER key (#905).
SWEEP_PROJECTS=(
  abletim apms-2173 baudin bibliothecaire chezz crt dcp-gate-site ecosim
  gardien groc-mangr nine-speakers realisateur scheduler secretaire senechal
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
SWEEP_ECOSYSTEM=(  # dcp-gate-site moved to SWEEP_PROJECTS 2026-09-02 (#905): onboarded live with an account 2026-08-28, so it now dispatches
  verbs front-door basheur
  musc-2300 scriba-senatus french-textbook
  etalon vitae space-canon maitre
)

SWEEP=("${SWEEP_PROJECTS[@]}" "${SWEEP_ECOSYSTEM[@]}")
