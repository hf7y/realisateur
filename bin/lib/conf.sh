#!/usr/bin/env bash
# conf.sh -- read a scheduler conf's PROJECT_REPO_PATH, EXPANDED.
#
# WHY THIS EXISTS
# ---------------
# Every registered project's conf writes its checkout as
#
#     PROJECT_REPO_PATH="$HOME/Documents/Projects/<name>"
#
# and five scripts in this repo read it with the same one-liner:
#
#     grep -oP '(?<=PROJECT_REPO_PATH=")[^"]*'
#
# which returns the LITERAL eleven characters `$HOME/Documents/...`. grep does
# not expand shell variables, and nothing downstream expanded them either. So
# `[ -d "$repo/.git" ]` was false for every project on every host, forever.
#
# WHAT THAT COST, measured 2026-08-06 rather than reasoned about:
#
#     $ bin/restamp-discipline.sh
#     baudin          SKIP -- no git repo at $HOME/Documents/Projects/baudin
#     ... 13 of these ...
#     == 0 in sync / 0 drifted / 13 skipped / 0 failed ==
#     $ echo $?
#     0
#
# restamp-discipline.sh is THE propagation mechanism -- the answer to Zach's
# 2026-07-26 question "how can all projects know about things like the senechal
# cross-write?" -- and it had been propagating the baseline to ZERO projects
# while exiting 0 and printing a tidy summary. Its own header says "Detection
# is not propagation" and "No exit-0 no-op"; it was committing both.
#
# The skip line is the tell and it was printed thirteen times a night: a path
# with a literal `$HOME` in it is not a path anyone typed.
#
# USAGE
#   . "$(dirname "${BASH_SOURCE[0]}")/lib/conf.sh"
#   repo="$(conf_repo_path "$conf")" || continue
#
# STILL ON THE RAW GREP, and each has the same defect: bin/milestone-audit.sh,
# bin/install-silence-audit.sh, bin/session-marker.sh, bin/closeout-lint.sh.
# Converting them is a separate pass against a repo another agent is working in
# right now; it is filed rather than done here, and filed loudly, because four
# scripts silently reporting on an empty project set is the same failure with
# four more faces.

# conf_repo_path <conf-file> -- the checkout path, with $HOME expanded.
# Returns 1 and prints nothing when the conf carries no PROJECT_REPO_PATH, so a
# caller's `|| continue` reads the way it looks.
#
# Expansion is deliberately LIMITED to $HOME and ${HOME}. `eval` would expand
# anything, and a conf is a file this repo does not own on a host it may not
# own either; command substitution inside one must not become code this script
# runs. If a conf ever needs a second variable, add it here by name.
conf_repo_path() {
  local conf="$1" p
  p="$(grep -oP '(?<=PROJECT_REPO_PATH=")[^"]*' "$conf" 2>/dev/null | head -1)"
  [ -n "$p" ] || return 1
  p="${p//\$\{HOME\}/$HOME}"
  p="${p//\$HOME/$HOME}"
  printf '%s\n' "$p"
}
