#!/usr/bin/env bash
# pivot.sh -- install/uninstall the 2026-08-07 pivot. This file is the
# argument. There is no companion document, on purpose.
#
# ---------------------------------------------------------------------------
# THE ONE RULE THIS FILE ENFORCES ON ITSELF
#
# A MOVE is admitted here only if it can state three things: two mechanisms it
# RETIRES, one mechanism it ADDS, and how to put back exactly what it removed.
# `install` refuses any MOVE that cannot. That refusal is the whole philosophy
# in executable form, and it is checked at run time rather than promised in a
# heading:
#
#   - A mechanism that cannot be removed is not a mechanism, it is a monument.
#   - An addition that retires nothing is accumulation. This ecosystem
#     accumulated 42 issues in one day and shipped one `git merge --ff-only`.
#   - Prose describing a change is not the change. So the description IS the
#     script, and if the script is wrong the description cannot be right.
#
# ---------------------------------------------------------------------------
# WHY THE UNINSTALL PATH IS FIRST-CLASS
#
# On 2026-08-06, 26 pull requests merged and five of six dispatchers ran older
# code for a day; one was frozen for eighteen hours because the engine wrote
# into its own source tree and then refused to pull past its own writing. Every
# individual piece was careful. Nothing owned the step after "merged".
#
# The response to that is not a better memo. It is that every change here can
# be reversed by one command, so reversing costs less than arguing, so nobody
# has to defend a mechanism to remove it.
#
# usage:  pivot.sh status | install | uninstall [MOVE...]
# exit:   0 done   1 a MOVE failed   2 usage   3 BLIND (could not determine
#         state -- never reported as success)
set -uo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
cd "$ROOT" 2>/dev/null || { echo "pivot: BLIND: cannot reach repo root" >&2; exit 3; }

# --- the ledger -------------------------------------------------------------
# Each MOVE is: key | adds | retires-1 | retires-2 | witness command
# The witness is what proves the MOVE is installed. It is a live probe, not a
# flag file: this ecosystem has twice mistaken a recorded claim for a fact.
MOVES=(
"drift|bin/deploy-drift.sh -- one command answers whether every dispatcher runs what we merged|the assumption that a merge is a deploy|the six-account model of monkey (the machine has ten)|test -x bin/deploy-drift.sh"
"cost|bin/markdown-cost.sh -- a PR fails if >30%% of added lines are markdown, or it adds a top-level .md|the /nightly-batch ideation brief, which asked runs to infer ideas and scaffold projects|doctrine filed as engineering tickets (7 closed into the vault stream)|test -x bin/markdown-cost.sh"
"homes|bin/hardcoded-home-lint.sh -- refuses an absolute path into a named user's home, in code|/home/zach hardcoded in bashify.sh, coin.sh, amend.sh, branch-purge.sh, closure.sh|verb-set.test.sh running only on the one machine where that path existed|test -x bin/hardcoded-home-lint.sh"
"ci|.github/workflows/tests.yml -- all ten suites on every PR, a failing suite does not hide the nine after it|seven test suites that existed and never ran|green-by-not-looking (CI is red on three real defects, and stays red)|test -f .github/workflows/tests.yml"
"sonde|bin/ecosim-sensor-tick.sh speaks sonde's exit vocabulary (0/8/9/6, not 0/1/2/3)|the ecosim-sensor path that no build ever contained|exit code 3, which means BLIND upstream and needs-summon here|grep -q 'bin/sonde' bin/ecosim-sensor-tick.sh"
"thermostat|bin/thermostat-wiring.sh -- eight live probes, ratcheted, asking whether the estate matches the 2026-08-07 redesign or only describes it|bin/weight-audit.sh, which rewrote AND PUSHED a weight column that allocates nothing (cli-guard.sh's own exhibit for the silent write)|bin/incubation-audit.sh, the other weight writer, which also prepended dated prose into a project's FOCUS.md|test -x bin/thermostat-wiring.sh && ! test -e bin/weight-audit.sh && ! test -e bin/incubation-audit.sh"
)

# --- the refusal that carries the argument ----------------------------------
# Enforced before anything is installed. A MOVE missing a field is not a
# formatting error, it is a MOVE that has not finished thinking.
check_move() {
  local m="$1" key adds r1 r2 wit
  IFS='|' read -r key adds r1 r2 wit <<<"$m"
  [ -n "$key" ] && [ -n "$adds" ] && [ -n "$r1" ] && [ -n "$r2" ] && [ -n "$wit" ] || {
    printf 'pivot: REFUSED: MOVE %s does not name two retirements, one addition and a witness.\n' "${key:-<unnamed>}" >&2
    printf 'pivot: An addition that retires nothing is accumulation. It is not admitted here.\n' >&2
    return 1
  }
  return 0
}

status_one() {
  local m="$1" key adds r1 r2 wit
  IFS='|' read -r key adds r1 r2 wit <<<"$m"
  if eval "$wit" >/dev/null 2>&1; then printf '  %-8s INSTALLED\n' "$key"
  else printf '  %-8s absent\n' "$key"; return 1; fi
}

cmd="${1:-status}"
case "$cmd" in
  status)
    rc=0
    echo "pivot 2026-08-07 -- $ROOT"
    for m in "${MOVES[@]}"; do check_move "$m" || exit 1; status_one "$m" || rc=1; done
    echo
    echo "Each line above retires two mechanisms and adds one. Read the MOVES"
    echo "array for which two; that is the only place it is written down."
    exit $rc ;;
  install)
    # Everything in this round ships as tracked files already merged to main,
    # so install is: prove the tree carries them. A MOVE that needs a step
    # beyond `git pull` belongs in this case block, with its undo in uninstall.
    for m in "${MOVES[@]}"; do check_move "$m" || exit 1; done
    fail=0
    for m in "${MOVES[@]}"; do status_one "$m" || fail=1; done
    [ "$fail" = 0 ] || { echo "pivot: a MOVE is absent -- this checkout predates the pivot; git pull first." >&2; exit 1; }
    echo "pivot: installed."
    exit 0 ;;
  uninstall)
    # Deliberately NOT `rm`. Every MOVE in this round is a merged commit, so
    # the honest undo is a revert with a record, not a file deleted off a disk
    # where the next pull restores it and nobody knows why it came back.
    echo "pivot: uninstall is by revert, so the removal has a record too:"
    echo
    echo "  git revert <sha>     # the merge that added the MOVE"
    echo "  bin/pivot.sh status  # must then report it absent"
    echo
    echo "Deleting the file instead would leave the next pull to restore it"
    echo "silently -- the same failure this pivot exists to end."
    exit 0 ;;
  *)
    echo "usage: pivot.sh status | install | uninstall" >&2; exit 2 ;;
esac
