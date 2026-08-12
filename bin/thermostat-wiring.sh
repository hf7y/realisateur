#!/usr/bin/env bash
# thermostat-wiring.sh -- eight live probes asking one question: does the
# ecosystem match the 2026-08-07 redesign, or only describe it?
#
# GUARD: does the ecosystem match the 2026-08-07 redesign, or only describe it?
# RUNNER: bin/tests/thermostat-wiring.test.sh
# GUARD-TEST: bin/tests/thermostat-wiring.test.sh
# GATE: none -- probes the scheduler checkout and the issue tracker; the tests workflow already declines to wire it for that reason, and its suite fabricates an estate instead
# VERIFIED: 2026-08-07 via bash bin/thermostat-wiring.sh (1/8 met, 0 blind, no regression)
#
# ---------------------------------------------------------------------------
# WHY THIS IS A RATCHET AND NOT A CONFORMANCE TEST
#
# The obvious build here is a test that passes when the vision is realised.
# That test is red on day one and red for weeks, and this ecosystem has
# already priced what a permanently-red check is worth: the `ci` MOVE in
# pivot.sh exists because seven suites had been red long enough that red had
# stopped meaning anything. A check nobody expects to be green is a document
# with an exit code.
#
# So the assertion is not "the vision is met". It is "the vision is no
# further away than the last time someone looked". bin/thermostat-wiring.ratchet
# records the checks that were passing when it was last accepted; this script
# exits 1 if any of THEM has since regressed, and exits 0 otherwise -- while
# still printing, every single run, exactly how many are left and which.
#
# That inverts the incentive the redesign is about. Under a conformance test,
# an agent that writes a paragraph about BLOCKERS.md changes nothing and the
# test is red either way, so the paragraph costs nothing. Under a ratchet,
# the only move that changes this script's output is deleting the file --
# and once deleted, `--accept` makes the deletion permanent, because putting
# it back is now a failing build rather than an argument.
#
# ---------------------------------------------------------------------------
# WHAT IT REFUSES TO DO
#
# It never reports "I could not see" as "nothing is wrong" (the recorded
# pathology: a propagation pass that reached zero projects and exited 0).
# A check that cannot be probed is BLIND, and BLIND on a check the ratchet
# depends on is exit 2 -- because an unprobeable check cannot prove the
# absence of a regression. BLIND on a check that was already failing is
# reported and tolerated: it costs nothing to be unable to measure something
# that was not yet true.
#
# It also never lowers the ratchet. `--accept` raises it or refuses.
#
# usage:  thermostat-wiring.sh [--strict] [--accept] [--quiet]
# exit:   0 no regression   1 REGRESSION against the ratchet
#         2 BLIND (a ratcheted check could not be probed -- never success)
#         3 --strict and the vision is not fully met (no regression)
set -uo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
RATCHET="$ROOT/bin/thermostat-wiring.ratchet"

CLI_NAME='thermostat-wiring.sh'
CLI_SUMMARY='is the ecosystem wired to the 2026-08-07 redesign, and has it slipped?'
CLI_USAGE='  thermostat-wiring.sh            probe, report, fail only on regression
  thermostat-wiring.sh --strict   also fail while the vision is unmet
  thermostat-wiring.sh --accept   record the currently-passing checks'
CLI_FLAGS='--strict --accept --quiet'
CLI_EXITS='  0  every ratcheted check still passes
  1  REGRESSION -- a check that used to pass no longer does
  2  BLIND -- a ratcheted check could not be probed. NEVER "all clear"
  3  --strict, and the vision is not fully met (but nothing regressed)'
CLI_POSITIONAL=none
. "$ROOT/bin/lib/cli-guard.sh"
cli_guard "$@"

STRICT=0; ACCEPT=0; QUIET=0
for a in "$@"; do
  case "$a" in
    --strict) STRICT=1 ;;
    --accept) ACCEPT=1 ;;
    --quiet)  QUIET=1 ;;
  esac
done

# Resolved, never hardcoded -- same order as coin.sh, milestone-audit.sh and
# steward-survey.sh, so this runs under the uid 3000-3099 dispatch accounts
# where $HOME is /home/<project>. bin/hardcoded-home-lint.sh enforces it.
SCHED="${SCHED_ROOT:-${INSTALLE_PROJECTS:-$HOME/Documents/Projects}/scheduler}"

# --- results -----------------------------------------------------------------
# Parallel arrays rather than an associative array: this has to run under the
# bash 3.2 on one host in the estate that still has it.
IDS=(); STATES=(); NOTES=()

record() { IDS+=("$1"); STATES+=("$2"); NOTES+=("$3"); }

# tracked <repo> <pathspec>... -- prints matching tracked paths, or returns 2
# if the repo cannot be read at all. The distinction between "the repo has no
# such file" (the thing we want) and "there is no repo here" (BLIND) is the
# entire point; conflating them is how absence gets reported as success.
tracked() {
  local repo="$1"; shift
  [ -d "$repo/.git" ] || return 2
  git -C "$repo" ls-files -- "$@" 2>/dev/null
}

# absent <id> <repo> <human note> <pathspec>...
# PASS when the repo tracks none of the pathspecs. This shape is most of the
# redesign: every §1 item is something whose non-existence is the deliverable.
absent() {
  local id="$1" repo="$2" note="$3"; shift 3
  local hits
  hits="$(tracked "$repo" "$@")" || { record "$id" BLIND "no git repo at $repo"; return; }
  if [ -z "$hits" ]; then
    record "$id" PASS "$note"
  else
    record "$id" UNMET "$(echo "$hits" | tr '\n' ' ')"
  fi
}

# --- §1  issues replace markdown --------------------------------------------
# BLOCKERS.md is not a record of the freeze, it IS the freeze: scheduler#61,
# one uncommitted BLOCKERS.md dirtied by the engine's own --consume, blocked
# vim-arcade's clone from pulling for seven commits.
absent blockers "$SCHED" 'no BLOCKERS.md tracked' 'BLOCKERS.md' '*/BLOCKERS.md'
absent sweeploop "$SCHED" 'sweep-loop-common.sh retired' 'lib/sweep-loop-common.sh'
absent mdtrees  "$SCHED" 'no generated focus/ or questions/ trees' 'focus' 'questions'

# --- §2  vim-arcade owns everything a human looks at ------------------------
# The scheduler keeps no terminal surface of its own. scheduler#33 is the
# argument: the glance called four accounts dead while they ran daily, and it
# sat there, because nobody enjoys opening it.
absent headless "$SCHED" 'scheduler emits no human-facing report' \
  'bin/morning-report.sh' 'bin/collect-feedback.sh'

# --- §3  cadence is measured, not configured --------------------------------
# The weight field allocates nothing on the only dispatching host (the 0700
# homes already answered that question) and two scripts USED to write it.
if [ -f "$SCHED/schedule/_paced.conf" ]; then
  # Rows are name|enabled|weight|command, so the weight column is field 3.
  # Matching on "a number between pipes" would also fire on a 2-field row and
  # report a weight that is not there.
  if awk -F'|' '!/^[[:space:]]*(#|$)/ && NF>=4 && $3 ~ /^[0-9]+$/ {n++}
                END{exit !(n>0)}' "$SCHED/schedule/_paced.conf"; then
    record weight UNMET 'schedule/_paced.conf still carries a weight column'
  else
    record weight PASS 'no weight column'
  fi
else
  record weight BLIND "no _paced.conf under $SCHED"
fi

# The provenance label is the thermostat's actual sensor. Every actor in this
# estate is `hf7y` (realisateur#40, #86), so authorship cannot answer "did a
# human ask for this, or did an agent find it" -- but every agent path into
# the tracker is a COMMAND, so the command can stamp a label. An unlabelled
# issue reads as a Zach directive, i.e. it errors toward dispatching MORE,
# which is why this check exists at all.
if command -v gh >/dev/null 2>&1; then
  # gh's status is captured on its OWN line. Piping straight into grep would
  # hand $? to grep, and grep exits 1 on no-match -- so the success case
  # ("no unlabelled issues") would have been reported as BLIND forever.
  if ! raw="$(gh issue list --repo hf7y/scheduler --state open --limit 200 \
                --json number,labels 2>/dev/null)"; then
    record provenance BLIND 'gh could not read the tracker'
  else
  unlabelled="$(printf '%s' "$raw" \
                | grep -oP '"labels":\[\],"number":\K[0-9]+' | tr '\n' ' ')"
  if [ -n "$unlabelled" ]; then
    record provenance UNMET "unlabelled open issues: $unlabelled"
  else
    record provenance PASS 'every open issue carries a provenance label'
  fi
  fi
else
  record provenance BLIND 'gh is not on PATH'
fi

# --- §4  prose does not end a run -------------------------------------------
# The append-only ledger (scheduler#54) is what makes REPETITION observable;
# without it the verdict is destroyed at dispatch and DONE cannot brake.
if [ -d "$SCHED/.git" ]; then
  # THE PROBE MUST TEST THE PROPERTY, NOT A GUESSED FILENAME. The first pattern
  # here was `scheduler-verdict/.*\.history` -- a path invented when this probe
  # was written, before anything implemented it. hf7y/scheduler#135 shipped the
  # ledger as lib/run-ledger.sh writing ledger.tsv, and this probe went on
  # reporting UNMET against a working implementation.
  #
  # A wrong UNMET is worse than no probe: it is read as work still to do, and
  # the next reader builds it a second time. Same defect already fixed once
  # today in scheduler's roster-target.sh `rosterfromgh`, which demanded a
  # literal `gh` and could not see a call through a variable.
  #
  # Widened, not loosened: an append-only ledger is a function that APPENDS
  # (>>) verdict rows, so either the original path shape or a named
  # ledger_append counts. Both are specific to this mechanism; neither matches
  # incidental prose.
  if git -C "$SCHED" grep -qlE 'scheduler-verdict/.*\.history|ledger_append' -- lib bin 2>/dev/null; then
    record ledger PASS 'an append-only verdict ledger is written'
  else
    record ledger UNMET 'no verdict history is appended anywhere in lib/ or bin/'
  fi
else
  record ledger BLIND "no git repo at $SCHED"
fi

if [ -f "$ROOT/.github/workflows/tests.yml" ]; then
  if grep -q 'markdown-cost' "$ROOT/.github/workflows/tests.yml"; then
    record prosepriced PASS 'CI prices added markdown'
  else
    record prosepriced UNMET 'CI does not run markdown-cost.sh'
  fi
else
  record prosepriced BLIND 'no .github/workflows/tests.yml'
fi

# --- the ratchet -------------------------------------------------------------
RATCHETED=""
[ -f "$RATCHET" ] && RATCHETED="$(grep -vE '^\s*(#|$)' "$RATCHET" | tr '\n' ' ')"

in_ratchet() { case " $RATCHETED " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

pass=0; unmet=0; blind=0; regressed=""; blind_ratcheted=""
for i in "${!IDS[@]}"; do
  case "${STATES[$i]}" in
    PASS)  pass=$((pass+1)) ;;
    UNMET) unmet=$((unmet+1))
           in_ratchet "${IDS[$i]}" && regressed="$regressed ${IDS[$i]}" ;;
    BLIND) blind=$((blind+1))
           in_ratchet "${IDS[$i]}" && blind_ratcheted="$blind_ratcheted ${IDS[$i]}" ;;
  esac
done
total=${#IDS[@]}

if [ "$QUIET" = 0 ]; then
  printf 'thermostat-wiring -- %s\n' "$(date '+%Y-%m-%d %H:%M')"
  printf '  scheduler: %s\n\n' "$SCHED"
  for i in "${!IDS[@]}"; do
    mark=' '; in_ratchet "${IDS[$i]}" && mark='*'
    printf '  %s %-6s %-12s %s\n' "$mark" "${STATES[$i]}" "${IDS[$i]}" "${NOTES[$i]}"
  done
  printf '\n  (* = held by the ratchet; regressing one of these fails the build)\n\n'
fi

# --accept: raise, or refuse. Lowering a ratchet is how a ratchet becomes a
# suggestion, so there is no flag that does it -- edit the file by hand and
# defend it in the diff.
if [ "$ACCEPT" = 1 ]; then
  if [ -n "$regressed" ]; then
    echo "thermostat-wiring: REFUSED: cannot accept while$regressed is regressed" >&2
    exit 1
  fi
  {
    echo "# thermostat-wiring.ratchet -- checks that were passing when accepted."
    echo "# Raised by --accept. Never lowered by any flag. See bin/thermostat-wiring.sh."
    echo "# accepted $(date -Is)"
    for i in "${!IDS[@]}"; do
      [ "${STATES[$i]}" = PASS ] && echo "${IDS[$i]}"
      in_ratchet "${IDS[$i]}" && [ "${STATES[$i]}" != PASS ] && echo "${IDS[$i]}"
    done | sort -u
  } > "$RATCHET"
  echo "thermostat-wiring: ratchet now holds $pass of $total checks"
  exit 0
fi

if [ -n "$blind_ratcheted" ]; then
  echo "thermostat-wiring: BLIND on ratcheted check(s):$blind_ratcheted" >&2
  echo "thermostat-wiring: this is 'I cannot see', NOT 'nothing regressed'." >&2
  exit 2
fi

if [ -n "$regressed" ]; then
  echo "thermostat-wiring: REGRESSION:$regressed passed when the ratchet was accepted." >&2
  exit 1
fi

echo "thermostat-wiring: $pass/$total met, $unmet to go, $blind blind -- no regression"
if [ "$STRICT" = 1 ] && [ "$unmet" != 0 ]; then
  echo "thermostat-wiring: --strict: the vision is not met yet" >&2
  exit 3
fi
exit 0
