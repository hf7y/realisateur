#!/usr/bin/env bash
# roster-set.sh -- WHICH REPOSITORIES THIS ESTATE SWEEPS. One list, one file.
#
# Was typed into three sweeps: three chances to add a repo to two of them.
# STILL TYPED -- the org lists 51, and uid 3000-3099 misses the ecosystem
# repos that carry decisions and never dispatch.

[ -n "${ROSTER_SET_LIB:-}" ] && return 0
ROSTER_SET_LIB=1

ROSTER_OWNER="${ROSTER_OWNER:-hf7y}"

ROSTER_PROJECTS=(
  baudin bibliothecaire chezz crt ecosim gardien groc-mangr nine-speakers
  realisateur scheduler secretaire senechal sequestria vim-arcade wtul
)

# ECOSYSTEM: carries decisions, never dispatches. WIRED, NOT ARMED -- swept by
# decision-rot (and so by ausculte's `rot` row), given no account, no crontab
# row and no quota. That distinction is the whole point of this second array.
#
# EIGHT ADDED 2026-08-22, Zach-directed ("all of these should be wired up...
# wiring up projects was the original job of realisateur"). Measured that day:
# 200 open issues estate-wide, 136 in repos with an armed account that works
# them unattended, and 64 in ELEVEN repos no sensor looked at. Three of the
# eleven were already here; these are the other eight, with their open counts:
#
#   dcp-gate-site 16   musc-2300 10   scriba-senatus 8   french-textbook 7
#   abletim 5          etalon 3       vitae 1            space-canon 1
#
# They were invisible rather than idle. `tempo dcp-gate-site` read BLIND ("no
# readable schedule/dcp-gate-site.conf"), `check-project-busy` refused to
# answer for a name it could not check, and decision-rot walked past them --
# so an answered-and-abandoned decision in any of them aged forever and
# `ausculte rot` still read OK. This file's own header already named the gap:
# "uid 3000-3099 misses the ecosystem repos that carry decisions and never
# dispatch."
#
# ARMING IS A SEPARATE ACT and is deliberately not done here: an account
# (provision-selfdev-user.sh), a schedule/<p>.conf, an enabled row in
# _paced.<host>.conf and an EXEMPT line in FREEZE. Being swept costs one API
# read per repo per decision-rot run; being armed costs quota every night.
ROSTER_ECOSYSTEM=(
  verbs front-door basheur
  dcp-gate-site musc-2300 scriba-senatus french-textbook
  abletim etalon vitae space-canon
)

ROSTER=("${ROSTER_PROJECTS[@]}" "${ROSTER_ECOSYSTEM[@]}")
