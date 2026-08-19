#!/usr/bin/env bash
# thermostat-wiring.sh -- nine live probes asking one question: does the
# ecosystem match the 2026-08-07 redesign, or only describe it?
#
# RUNNER: bin/tests/thermostat-wiring.test.sh
# GUARD-TEST: bin/tests/thermostat-wiring.test.sh
# GATE: none -- probes the scheduler checkout and the issue tracker; the tests workflow already declines to wire it for that reason, and its suite fabricates an estate instead
#
# TRAPS (the rest of this header is in the vault):
# It never reports "I could not see" as "nothing is wrong" (the recorded
# pathology: a propagation pass that reached zero projects and exited 0). A
# check that cannot be probed is BLIND: exit 2 if ratcheted (an unprobeable
# check cannot prove no regression), tolerated if not (nothing yet to lose).
# It also never lowers the ratchet. `--accept` raises it or refuses.
#
# usage:  thermostat-wiring.sh [--strict] [--accept] [--quiet]
# exit:   0 no regression   1 REGRESSION against the ratchet

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
SCHED_OWNER="${SCHED_OWNER:-hf7y}"
SCHED_REPO="${SCHED_REPO:-scheduler}"

# --- results -----------------------------------------------------------------
# Parallel arrays rather than an associative array: this has to run under the
# bash 3.2 on one host in the estate that still has it.
IDS=(); STATES=(); NOTES=()

record() { IDS+=("$1"); STATES+=("$2"); NOTES+=("$3"); }

# #414: a checkout wins when present; GitHub is the clone-free fallback.
SCHED_LOCAL=0
[ -d "$SCHED/.git" ] && SCHED_LOCAL=1

_SCHED_TREE_READ=0
_SCHED_TREE=""
sched_tree() {
  if [ "$_SCHED_TREE_READ" = 0 ]; then
    _SCHED_TREE_READ=1
    _SCHED_TREE="$(gh api "repos/$SCHED_OWNER/$SCHED_REPO/git/trees/HEAD?recursive=1" \
                     -q '.tree[] | "\(.mode) \(.path)"' 2>/dev/null)" || _SCHED_TREE=""
  fi
  [ -n "$_SCHED_TREE" ]
}

sched_file() {
  if [ "$SCHED_LOCAL" = 1 ]; then
    cat "$SCHED/$1" 2>/dev/null
    return
  fi
  gh api "repos/$SCHED_OWNER/$SCHED_REPO/contents/$1?ref=HEAD" -q .content 2>/dev/null \
    | base64 -d 2>/dev/null
}

_pathspec_match() {
  local path="$1" pat="$2"
  case "$pat" in
    *'*'*|*'?'*|*'['*)
      # shellcheck disable=SC2254 # deliberate glob: $pat IS the glob pattern here
      case "$path" in $pat) return 0 ;; esac
      return 1 ;;
    *)
      [ "$path" = "$pat" ] && return 0
      case "$path" in "$pat"/*) return 0 ;; esac
      return 1 ;;
  esac
}

# tracked <repo> <pathspec>... -- prints matching tracked paths, or returns 2
# if the repo cannot be read at all. The distinction between "the repo has no
# such file" (the thing we want) and "there is no repo here" (BLIND) is the
# entire point; conflating them is how absence gets reported as success.
tracked() {
  local repo="$1"; shift
  if [ "$repo" = "$SCHED" ] && [ "$SCHED_LOCAL" = 0 ]; then
    sched_tree || return 2
    local path pat
    while IFS=' ' read -r _ path; do
      [ -n "$path" ] || continue
      for pat in "$@"; do
        if _pathspec_match "$path" "$pat"; then printf '%s\n' "$path"; break; fi
      done
    done <<< "$_SCHED_TREE"
    return 0
  fi
  [ -d "$repo/.git" ] || return 2
  git -C "$repo" ls-files -- "$@" 2>/dev/null
}

sched_grep() {
  local pat="$1"; shift
  if [ "$SCHED_LOCAL" = 1 ]; then
    git -C "$SCHED" grep -qlE "$pat" -- "$@" 2>/dev/null && return 0
    return 1
  fi
  sched_tree || return 2
  local path prefix match
  while IFS=' ' read -r _ path; do
    [ -n "$path" ] || continue
    match=0
    for prefix in "$@"; do
      case "$path" in "$prefix"/*) match=1; break ;; esac
    done
    [ "$match" = 1 ] || continue
    sched_file "$path" | grep -qE "$pat" && return 0
  done <<< "$_SCHED_TREE"
  return 1
}

sched_grep_files() {
  local pat="$1"; shift
  if [ "$SCHED_LOCAL" = 1 ]; then
    git -C "$SCHED" grep -lE "$pat" -- "$@" 2>/dev/null
    return
  fi
  sched_tree || return 2
  local path prefix match
  while IFS=' ' read -r _ path; do
    [ -n "$path" ] || continue
    match=0
    for prefix in "$@"; do
      case "$path" in "$prefix"/*) match=1; break ;; esac
    done
    [ "$match" = 1 ] || continue
    sched_file "$path" | grep -qE "$pat" && printf '%s\n' "$path"
  done <<< "$_SCHED_TREE"
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
_paced="$(sched_file 'schedule/_paced.conf')"
if [ -n "$_paced" ]; then
  # Rows are name|enabled|weight|command, so the weight column is field 3.
  # Matching on "a number between pipes" would also fire on a 2-field row and
  # report a weight that is not there.
  if printf '%s\n' "$_paced" \
       | awk -F'|' '!/^[[:space:]]*(#|$)/ && NF>=4 && $3 ~ /^[0-9]+$/ {n++}
                    END{exit !(n>0)}'; then
    record weight UNMET 'schedule/_paced.conf still carries a weight column'
  else
    record weight PASS 'no weight column'
  fi
else
  record weight BLIND "no _paced.conf under $SCHED"
fi
unset _paced

# Provenance: who filed each issue. Every actor here is `hf7y` (realisateur#40,
# #86), so authorship cannot answer it; a filing verb stamping a label can. An
# unlabelled issue reads as a Zach directive, i.e. errors toward dispatching MORE.
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
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
# THE PROBE MUST TEST THE PROPERTY, NOT A GUESSED FILENAME. The first pattern
# here was `scheduler-verdict/.*\.history` -- a path invented when this probe
# was written, before anything implemented it. hf7y/scheduler#135 shipped the
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
sched_grep 'scheduler-verdict/.*\.history|ledger_append' lib bin
case $? in
  0) record ledger PASS 'an append-only verdict ledger is written' ;;
  2) record ledger BLIND "no git repo at $SCHED, and its GitHub tree did not read" ;;
  *) record ledger UNMET 'no verdict history is appended anywhere in lib/ or bin/' ;;
esac

# THE SETPOINT -- the half of §3 provenance cannot see. Labels are an INPUT;
# this asks whether anything READS them. Until hf7y/scheduler#219 nothing did:
# the control loop was three brakes and nothing that could say "run this MORE",
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
_runner="$(sched_file 'bin/usage-paced-runner.sh')"
if [ -z "$_runner" ]; then
  record setpoint BLIND "no bin/usage-paced-runner.sh under $SCHED"
else
  _sp=""
  while IFS= read -r _f; do
    [ -n "$_f" ] || continue
    _b="$(basename "$_f")"
    printf '%s\n' "$_runner" | grep -qF "\$SELF_DIR/$_b" && _sp="$_sp $_b"
  done <<< "$(sched_grep_files 'gh issue list' bin lib)"
  if [ -n "$_sp" ]; then
    record setpoint PASS "the dispatcher runs a tracker-derived setpoint:$_sp"
  else
    record setpoint UNMET 'nothing the dispatcher runs reads the issue tracker -- pace is still a number a human edits'
  fi
  unset _sp _f _b
fi
unset _runner

# The guard moved to hf7y/etalon and is CALLED, not carried, so the witness is
# a workflow referencing it rather than a script in this tree. Any workflow may
# do the calling; grepping the whole directory is the point -- pinning it to
# one filename is what made this check wrong the moment the job moved.
if [ -d "$ROOT/.github/workflows" ]; then
  if grep -rqs 'etalon/.github/workflows/guard.yml\|markdown-cost' "$ROOT/.github/workflows/"; then
    record prosepriced PASS 'CI prices added prose'
  else
    record prosepriced UNMET 'no workflow calls the prose guard'
  fi
else
  record prosepriced BLIND 'no .github/workflows/ directory'
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
  if [ "$SCHED_LOCAL" = 1 ]; then
    printf '  scheduler: %s (checkout)\n\n' "$SCHED"
  else
    printf '  scheduler: %s (no checkout -- read live from github.com/%s/%s)\n\n' \
      "$SCHED" "$SCHED_OWNER" "$SCHED_REPO"
  fi
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
