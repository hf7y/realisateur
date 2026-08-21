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

ROSTER_ECOSYSTEM=(verbs front-door basheur)

ROSTER=("${ROSTER_PROJECTS[@]}" "${ROSTER_ECOSYSTEM[@]}")
