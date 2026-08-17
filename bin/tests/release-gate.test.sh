#!/usr/bin/env bash
#
# TRAPS (the rest of this header is in the vault):
# WHY A FAKE `gh` AND NOT THE REAL ONE. The gate's whole job is to be right
# about GitHub's answer, so a suite that asks GitHub cannot distinguish its
# own passing from the org happening to be green today -- and the two states
# this most needs to pin (RED, PENDING) cannot be produced on demand against
# a real repository at all. cut-verb-build-test.sh already established this
# shape here: a fake `gh` on a controlled path, fixture answers, no network.
#
# Usage: bin/tests/release-gate.test.sh   (exit 0 = all pass)

set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
GATE="$REPO/bin/release-gate.sh"
[ -x "$GATE" ] || { echo "FAIL: $GATE not executable"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

echo "release-gate.test.sh"

# --- the fake gh -----------------------------------------------------------
# Answers are read from $T/answers/<project>. One line: the check-runs
# conclusions, verbatim, as the real --jq join would produce. The literal
# token BLIND makes the api call fail instead.
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
FAKEGH="$T/gh"
cat > "$FAKEGH" <<'EOF'
#!/usr/bin/env bash
# $1=api $2=<path> [--jq <expr>]
path="$2"; jqexpr=""
[ "${3:-}" = "--jq" ] && jqexpr="${4:-.}"
# Every queried path is logged, so a test can assert which ENDPOINTS the gate
# touches -- not merely what it concluded. That is how "it stopped using
# check-runs" becomes an assertion rather than a hope.
printf '%s\n' "$path" >> "$QUERYLOG"
emit() { printf '%s' "$1" | jq -r "$jqexpr"; }

# `!foo` means a run whose status is foo and whose conclusion is null.
runs_json() {
  printf '%s' "$1" | tr ',' '\n' | grep . | while IFS= read -r c; do
    case "$c" in
      '!'*) printf '{"status":"%s","conclusion":null}\n' "${c#!}" ;;
      *)    printf '{"status":"completed","conclusion":"%s"}\n' "$c" ;;
    esac
  done | jq -s '{total_count:length, workflow_runs:.}'
}

case "$path" in
  repos/*/*/actions/runs*)
    p="$(echo "$path" | cut -d/ -f3)"
    a="$(cat "$ANSWERS/$p" 2>/dev/null)"
    [ "$a" = BLIND ] && exit 1
    [ "$a" = EMPTY ] && a=""
    case "$a" in NOREPO|NOSHA) a="" ;; esac
    emit "$(runs_json "$a")"; exit $? ;;
  repos/*/*/commits/*/status)
    p="$(echo "$path" | cut -d/ -f3)"
    s="$(cat "$ANSWERS/$p.status" 2>/dev/null)"
    [ "$s" = BLIND ] && exit 1
    # THE VERIFIED REAL SHAPE for a commit with no statuses, probed
    # 2026-08-07: {"state":"pending","total_count":0,"statuses":[]}. The
    # rolled-up `state` says "pending" even though nothing is pending. This
    # fixture is the whole reason the gate must not read `.state`.
    if [ -z "$s" ]; then
      emit '{"state":"pending","total_count":0,"statuses":[]}'; exit $?
    fi
    j="$(printf '%s' "$s" | tr ',' '\n' | grep . | jq -R '{state:.}' \
         | jq -s '{state:"pending", total_count:length, statuses:.}')"
    emit "$j"; exit $? ;;
  repos/*/*/commits/*)
    p="$(echo "$path" | cut -d/ -f3)"
    [ "$(cat "$ANSWERS/$p" 2>/dev/null)" = NOSHA ] && exit 1
    emit '{"sha":"abcdef1234567890abcdef1234567890abcdef12"}'; exit $? ;;
  repos/*/*)
    p="$(echo "$path" | cut -d/ -f3)"
    [ "$(cat "$ANSWERS/$p" 2>/dev/null)" = NOREPO ] && exit 1
    # Deliberately NOT "main": the gate must ask for the default branch
    # rather than assume it, or a project defaulting to something else is
    # silently UNGATED forever.
    emit '{"default_branch":"trunk"}'; exit $? ;;
esac
exit 1
EOF
chmod +x "$FAKEGH"

mkdir -p "$T/answers"
QUERYLOG="$T/queried.log"; export QUERYLOG; : > "$QUERYLOG"
# set_answer  -- the ACTIONS surface (workflow runs)
# set_status  -- the COMMIT STATUS surface (external CI). Absent = zero
#                statuses, which is every project in this org today.
set_answer() { printf '%s' "$2" > "$T/answers/$1"; }
set_status() { printf '%s' "$2" > "$T/answers/$1.status"; }

gate() { # gate <projects...>
  ANSWERS="$T/answers" RELEASE_GATE_GH="$FAKEGH" "$GATE" --projects "$*" 2>&1
}

# ===========================================================================
echo
echo "-- GREEN ---------------------------------------------------------------"
set_answer alpha "success,success"
set_answer beta  "success,neutral,skipped"
O="$(gate alpha beta)"; R=$?
rc "all checks concluded successfully exits 0" 0 "$R"
has "GREEN is stated per project" "$O" "GREEN"
has "the gate says it opened" "$O" "GATE OPEN"
has "the summary counts greens" "$O" "2 green, 0 red"

# ===========================================================================
echo
echo "-- RED -----------------------------------------------------------------"
set_answer gamma "success,failure"
O="$(gate alpha gamma)"; R=$?
rc "a failed check exits 1" 1 "$R"
has "RED is stated per project" "$O" "RED"
has "the blocked message names the project" "$O" "RED on: gamma"
has "the operator is told the fleet is not stranded, only held" "$O" "stays on the last good build"
has "the coupling is stated as intended, not apologised for" "$O" "intended coupling"
hasnt "a red run does not also claim the gate opened" "$O" "GATE OPEN"

for c in timed_out cancelled action_required; do
  set_answer delta "success,$c"
  gate delta >/dev/null 2>&1; R=$?
  rc "conclusion '$c' is RED, not green" 1 "$R"
done

# ===========================================================================
echo
echo "-- PENDING is not RED --------------------------------------------------"
# Different operator action: waiting versus fixing. Collapsing them sends
# somebody hunting a break that does not exist.
set_answer eps "success,!in_progress"
O="$(gate alpha eps)"; R=$?
rc "an unconcluded check exits 4, not 1 and not 0" 4 "$R"
has "PENDING is stated per project" "$O" "PENDING"
has "the deferred message says nothing is broken" "$O" "Nothing is broken"
has "it names the project to wait on" "$O" "running on: eps"
hasnt "a pending run does not claim the gate opened" "$O" "GATE OPEN"

set_answer zeta "!queued"
gate zeta >/dev/null 2>&1; rc "a queued check is PENDING too" 4 $?

# RED outranks PENDING: if one project is broken and another is mid-run, the
# actionable fact is the break.
set_answer eta "failure"
set_answer theta "!in_progress"
gate eta theta >/dev/null 2>&1; rc "RED outranks PENDING when both are present" 1 $?

# ===========================================================================
echo
echo "-- UNGATED is neither GREEN nor RED ------------------------------------"
# 9 of the 12 projects carrying a bashified branch had no CI at all on
# 2026-08-07. Refusing on them blocks every cut forever; calling them green
# is the found-nothing/nothing-is-wrong conflation.
set_answer iota EMPTY
O="$(gate alpha iota)"; R=$?
rc "a project with no CI does NOT block the cut" 0 "$R"
has "UNGATED is stated by that name, not as GREEN" "$O" "UNGATED"
has "the ungated count is reported, not hidden" "$O" "1 ungated"
has "the ungated project is named" "$O" "NO CI evidence at all: iota"
has "the note explains why it does not block" "$O" "would block every cut"
has "the note frames the count as the work" "$O" "the count IS the work"

O="$(gate iota)"; R=$?
rc "a build where NOTHING has CI still cuts, and says so" 0 "$R"
has "...and reports zero green rather than implying coverage" "$O" "0 green, 0 red"

# ===========================================================================
echo
echo "-- BLIND is not green --------------------------------------------------"
set_answer kappa BLIND
O="$(gate alpha kappa)"; R=$?
rc "an unreadable project exits 3 BLIND, not 0" 3 "$R"
has "BLIND is stated per project" "$O" "BLIND"
has "BLIND says explicitly that it is not green" "$O" "NOT a green result"
has "BLIND names why a short read looks healthy" "$O" "short by construction"

set_answer lam NOREPO
gate lam >/dev/null 2>&1; rc "a repository that cannot be read is BLIND" 3 $?
set_answer mu NOSHA
gate mu >/dev/null 2>&1; rc "a HEAD that cannot be resolved is BLIND" 3 $?

# ===========================================================================
echo
echo "-- THE EVIDENCE SURFACES: WHAT THE TOKEN CAN ACTUALLY READ -------------"
# ===========================================================================
# THE 2026-08-07 FAILURE. The gate asked ONE endpoint,
# /commits/{sha}/check-runs, which needs the fine-grained permission
# `Checks: Read`. VERBS_READ_TOKEN holds "actions, code, commit statuses,
# metadata" -- and when Zach went to grant Checks, THERE IS NO SUCH CATEGORY
#   [rest of this note: vault:realisateur/guard-archaeology-20260817.md]
: > "$QUERYLOG"
set_answer sigma "success"
gate sigma >/dev/null 2>&1

qlog="$(cat "$QUERYLOG")"
hasnt "the gate no longer queries check-runs (needs a permission that cannot be granted)" \
      "$qlog" "check-runs"
has "it reads GitHub Actions runs instead (needs actions:read, which the token HAS)" \
    "$qlog" "actions/runs"
has "...filtered to the exact sha, so a run against another commit is not evidence" \
    "$qlog" "head_sha=abcdef1234567890abcdef1234567890abcdef12"
has "it also reads commit statuses (needs statuses:read, which the token HAS)" \
    "$qlog" "/status"

# --- the two surfaces are different producers, and both are consulted -------
# Actions creates workflow runs; external CI posts commit statuses. Covering
# only one and calling the other absent would grade a project with external CI
# as UNGATED -- a FALSE ABSENCE, and a false absence here ALLOWS the cut.
set_answer tau EMPTY          # no GitHub Actions at all...
set_status tau "failure"      # ...but an external build failed
O="$(gate tau)"; R=$?
rc "a project whose ONLY CI is an external commit status is gated on it" 1 "$R"
has "...and a failing external build is RED, not UNGATED" "$O" "RED"
hasnt "...and is not miscounted as having no CI" "$O" "1 ungated"

set_answer ups EMPTY
set_status ups "error"
gate ups >/dev/null 2>&1
rc "commit-status 'error' is RED too (the statuses vocabulary for a failure)" 1 $?

set_answer phi EMPTY
set_status phi "pending"
gate phi >/dev/null 2>&1
rc "a genuinely pending external build is PENDING" 4 $?

set_answer chi "success"
set_status chi "success"
gate chi >/dev/null 2>&1
rc "both surfaces green is GREEN" 0 $?

# A green Actions run does not excuse a failing external status.
set_answer psi "success"
set_status psi "failure"
gate psi >/dev/null 2>&1
rc "a green Actions run does NOT override a failed commit status" 1 $?

# --- the `state:"pending"` trap in the combined status endpoint -------------
# Probed 2026-08-07: a commit with ZERO statuses returns
#   {"state":"pending","total_count":0,"statuses":[]}
# Reaching for `.state` -- the obvious field -- makes every project in this
# org PENDING forever and defers every cut. Presence is decided by
# total_count. The fake returns exactly that shape, so this is a real test of
# the real jq filter and not a restatement of the rule.
set_answer omega "success"     # no set_status -> the zero-status shape above
O="$(gate omega)"; R=$?
rc "a commit with zero statuses does NOT read as PENDING (the .state trap)" 0 "$R"
has "...it is simply green on the Actions surface" "$O" "GREEN"

set_answer om2 EMPTY           # no Actions, no statuses
O="$(gate om2)"; R=$?
rc "no runs AND no statuses is UNGATED (exit 0), not PENDING" 0 "$R"
has "...named UNGATED rather than graded clean" "$O" "UNGATED"
has "...and the row says both surfaces were consulted and empty" \
    "$O" "no workflow run and no commit status"

# --- "the query failed" is not "the query returned nothing" -----------------
# Design point the coordinator named, and the one tonight's bug got RIGHT:
# it presented as BLIND. Collapsing the two would have turned a permission
# failure into a silent GREEN across eleven projects. Note which direction
# each one goes: UNGATED allows the cut, BLIND refuses it.
set_answer aa BLIND            # the actions/runs query itself fails
O="$(gate aa)"; R=$?
rc "an actions/runs query that FAILS is BLIND (3), not UNGATED (0)" 3 "$R"
has "...and names the surface that failed" "$O" "actions/runs"
has "...and the permission it needs, so the fix is obvious" "$O" "actions:read"

set_answer bb "success"
set_status bb BLIND            # actions answers, statuses refuses
O="$(gate bb)"; R=$?
rc "a statuses query that FAILS is BLIND even when Actions answered green" 3 "$R"
has "...and names that surface and its permission" "$O" "statuses:read"
hasnt "...and does not report the project as GREEN" "$O" "GATE OPEN"

# THE REGRESSION IN ONE CASE: eleven projects unreadable is a refusal, and it
# must never become an allow.
for n in c1 c2 c3; do set_answer "$n" BLIND; done
set_answer c4 "success"
O="$(gate c1 c2 c3 c4)"; R=$?
rc "many BLIND projects and one green still refuses" 3 "$R"
has "the count is reported honestly" "$O" "1 green, 0 red, 0 pending, 0 ungated, 3 blind"
has "BLIND says explicitly it is not green" "$O" "NOT a green result"

# ===========================================================================
echo
echo "-- THE PROJECT LIST COMES FROM THE MANIFEST ----------------------------"
# No second derivation: the gate checks exactly what the build made. A gate
# that enumerated projects itself could disagree with the build about what is
# in the build, which is the one-fact-two-readers shape vault:realisateur/MONKEY.md 10 found
# five times in a day.
set_answer nu "success"
set_answer xi "failure"
printf '# a comment row\n' >  "$T/m1.tsv"
printf 'nu\tverbA\tdeadbeef\thttps://x/nu\n'  >> "$T/m1.tsv"
printf 'nu\tverbB\tdeadbeef\thttps://x/nu\n'  >> "$T/m1.tsv"
printf 'xi\tverbC\tcafebabe\thttps://x/xi\n'  >> "$T/m1.tsv"
O="$(ANSWERS="$T/answers" RELEASE_GATE_GH="$FAKEGH" "$GATE" --manifest "$T/m1.tsv" 2>&1)"; R=$?
rc "a manifest naming a red project blocks the cut" 1 "$R"
has "each project is gated once, not once per verb" "$O" "1 green, 1 red"
has "the comment row is not treated as a project" "$O" "RED on: xi"

# An empty manifest must never rubber-stamp. If the build produced nothing,
# something upstream should already have refused, and saying GREEN here would
# launder that.
printf '# only a comment\n' > "$T/m2.tsv"
O="$(ANSWERS="$T/answers" RELEASE_GATE_GH="$FAKEGH" "$GATE" --manifest "$T/m2.tsv" 2>&1)"; R=$?
rc "an empty manifest is BLIND, never GREEN" 3 "$R"
has "...and says nothing was gated" "$O" "names no projects"

"$GATE" --manifest "$T/does-not-exist.tsv" >/dev/null 2>&1
rc "a missing manifest is a usage error, not a pass" 2 $?

# ===========================================================================
echo
echo "-- THE DEFAULT BRANCH IS ASKED FOR, NOT ASSUMED ------------------------"
# The fake gh answers "trunk". If the gate hardcoded `main` it would query a
# branch the fake does not serve and fall to BLIND, so a passing GREEN here
# is the witness that the default branch was read from the repository.
set_answer nun "success"
O="$(gate nun)"; R=$?
rc "a project whose default branch is not 'main' still gates GREEN" 0 "$R"

# ===========================================================================
echo
echo "-- THE ARGUMENT CONTRACT -----------------------------------------------"
"$GATE" --not-a-real-flag >/dev/null 2>&1; rc "unknown flag exits 2" 2 $?
"$GATE" >/dev/null 2>&1;                   rc "no arguments is a usage error, not a pass" 2 $?
"$GATE" --help >/dev/null 2>&1;            rc "--help exits 0" 0 $?
O="$("$GATE" --help 2>&1)"
has "--help documents the BLIND exit" "$O" "BLIND"
has "--help documents the pending exit separately" "$O" "still running"

echo
summary
