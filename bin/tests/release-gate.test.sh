#!/usr/bin/env bash
# HERMETICITY: one `mktemp -d` per run holds every fixture, and a FAKE `gh` is
# placed ahead of the real one on PATH so all four states (GREEN/RED/PENDING/
# BLIND) are produced on demand from canned answers. No network, no real
# repository, and no dependence on the org happening to be green today -- see
# the "WHY A FAKE gh" note below, which is the argument for the whole shape.
#
# release-gate.test.sh -- witness for bin/release-gate.sh's four states and
# their exit codes.
#
# WHY A FAKE `gh` AND NOT THE REAL ONE. The gate's whole job is to be right
# about GitHub's answer, so a suite that asks GitHub cannot distinguish its
# own passing from the org happening to be green today -- and the two states
# this most needs to pin (RED, PENDING) cannot be produced on demand against
# a real repository at all. cut-verb-build-test.sh already established this
# shape here: a fake `gh` on a controlled path, fixture answers, no network.
#
# THE FOUR STATES, and why each has its own assertion:
#   GREEN    checks exist for HEAD and all succeeded          -> exit 0
#   RED      a check for HEAD failed                          -> exit 1
#   PENDING  a check for HEAD has not concluded               -> exit 4
#   UNGATED  no checks exist for HEAD (the project has no CI)  -> exit 0, counted
#   BLIND    GitHub could not be asked                        -> exit 3
#
# The one that matters most is that UNGATED is neither GREEN nor RED. Nine of
# the twelve projects carrying a `bashified` branch had no CI at all when this
# was written, so folding UNGATED into RED blocks every cut forever and
# folding it into GREEN is the found-nothing/nothing-is-wrong conflation.
#
# Usage: bin/tests/release-gate.test.sh   (exit 0 = all pass)
set -uo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
GATE="$REPO/bin/release-gate.sh"
[ -x "$GATE" ] || { echo "FAIL: $GATE not executable"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { echo "  ok   $1"; pass=$((pass+1)); }
bad() { echo "  FAIL $1"; fail=$((fail+1)); }
has()   { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing: $3)" ;; esac; }
hasnt() { case "$2" in *"$3"*) bad "$1 (unexpectedly present: $3)" ;; *) ok "$1" ;; esac; }
rc()    { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected exit $2, got $3)"; fi; }

echo "release-gate.test.sh"

# --- the fake gh -----------------------------------------------------------
# Answers are read from $T/answers/<project>. One line: the check-runs
# conclusions, verbatim, as the real --jq join would produce. The literal
# token BLIND makes the api call fail instead.
FAKEGH="$T/gh"
cat > "$FAKEGH" <<'EOF'
#!/usr/bin/env bash
# $1=api $2=<path> then --jq <expr>
path="$2"
case "$path" in
  repos/*/*/commits/*/check-runs)
    p="$(echo "$path" | cut -d/ -f3)"
    a="$(cat "$ANSWERS/$p" 2>/dev/null)"
    [ "$a" = BLIND ] && exit 1
    [ "$a" = EMPTY ] && { echo ""; exit 0; }
    echo "$a"; exit 0 ;;
  repos/*/*/commits/*)
    p="$(echo "$path" | cut -d/ -f3)"
    [ "$(cat "$ANSWERS/$p" 2>/dev/null)" = NOSHA ] && exit 1
    echo "abcdef1234567890abcdef1234567890abcdef12"; exit 0 ;;
  repos/*/*)
    p="$(echo "$path" | cut -d/ -f3)"
    [ "$(cat "$ANSWERS/$p" 2>/dev/null)" = NOREPO ] && exit 1
    # Deliberately NOT "main": the gate must ask for the default branch
    # rather than assume it, or a project defaulting to something else is
    # silently UNGATED forever.
    echo "trunk"; exit 0 ;;
esac
exit 1
EOF
chmod +x "$FAKEGH"

mkdir -p "$T/answers"
set_answer() { printf '%s' "$2" > "$T/answers/$1"; }

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
echo "-- THE PROJECT LIST COMES FROM THE MANIFEST ----------------------------"
# No second derivation: the gate checks exactly what the build made. A gate
# that enumerated projects itself could disagree with the build about what is
# in the build, which is the one-fact-two-readers shape MONKEY.md 10 found
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
echo "release-gate.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
