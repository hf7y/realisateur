#!/usr/bin/env bash
# HERMETICITY: every case builds its own status.json fixture under one
# `mktemp -d` and grades it through the script's `--url` entry point pointed at
# a local path, so the real parse-and-grade code runs with no host to be up and
# no clone to be current. Nothing reads the live channel, the live estate, or
# any other account -- the LIVE assertions deliberately live next door in
# release-channel-wiring.test.sh instead, so this suite stays green offline.
#
# release-ledger.test.sh -- THE INVERSION, AS A GUARD.
#
# Gating the nightly cut on CI green created a new silent failure, and it is
# the shape this estate keeps paying for:
#
#     "no cut tonight because nothing changed"
#     "no cut tonight because main is broken"
#
# are identical to anything that detects a release by LOOKING FOR A NEW BUILD.
# You cannot detect an absence by looking for something. So the channel emits
# a verdict every night whether or not it cuts, and these assertions are what
# stop that verdict from decaying back into a thing nobody grades.
#
# THE SIX RULES, one per section:
#   1. Default-deny on the enum      -- an unknown decision is BAD, not OK
#   2. Two clocks                    -- emitter alive vs pipeline productive
#   3. Escalate on streak            -- one blocked night is not an outage
#   4. A producer cannot report its own absence -- time-keyed, consumer-side
#   5. An empty channel is not clean -- zero verdicts is BAD
#   6. Unreadable is not empty       -- BLIND(3) and BAD(1) are different facts
#
# The two cases normally left untested because they are awkward to produce --
# "no verdicts at all" and "the newest verdict is stale" -- are produced here
# with fixtures and are sections 4 and 5. They are the whole point: every
# other assertion still passes on a channel that died last Tuesday.
#
# HERMETIC. Fixture ledger files in a temp dir, LEDGER_NOW frozen so "how old
# is this row" is arithmetic and not a race with the wall clock. No network,
# no git, no live machine read.
#
# Usage: bin/tests/release-ledger.test.sh   (exit 0 = all pass)
set -uo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
LED="$REPO/bin/release-ledger.sh"
[ -x "$LED" ] || { echo "FAIL: $LED not executable"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { echo "  ok   $1"; pass=$((pass+1)); }
bad() { echo "  FAIL $1"; fail=$((fail+1)); }
has()   { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing: $3)" ;; esac; }
hasnt() { case "$2" in *"$3"*) bad "$1 (unexpectedly present: $3)" ;; *) ok "$1" ;; esac; }
rc()    { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected exit $2, got $3)"; fi; }

# A frozen "now" so ages are arithmetic. 2026-08-10T00:00:00Z.
NOW=1786060800
at() { date -u -d "@$(( NOW - $1 * 3600 ))" +%Y-%m-%dT%H:%M:%SZ; }   # at <hours ago>

mkledger() { # mkledger <file>; rows on stdin as: <hours-ago> <decision> <reason>
  local f="$1"
  printf '# date\tdecision\treason\tmain_sha\tci_run\tbuild_id\n' > "$f"
  while read -r h dec reason; do
    [ -n "${h:-}" ] || continue
    printf '%s\t%s\t%s\tabc1234\t99\t%s\n' "$(at "$h")" "$dec" "$reason" \
      "$([ "$dec" = CUT ] && echo "build-$h" || echo '-')" >> "$f"
  done
}

check() { LEDGER_NOW="$NOW" "$LED" --ledger "$1" 2>&1; }

echo "release-ledger.test.sh"

# ===========================================================================
echo
echo "-- THE HEALTHY CASES ---------------------------------------------------"
# ===========================================================================
mkledger "$T/cut.tsv" <<'EOF'
50 CUT nightly
26 CUT nightly
2 CUT nightly
EOF
O="$(check "$T/cut.tsv")"; R=$?
rc "a channel that cut recently exits 0" 0 "$R"
has "it says the emitter is alive" "$O" "emitter alive"
has "it reports the last cut's age (clock 2)" "$O" "last CUT was"

# THE CASE THE WHOLE DESIGN EXISTS FOR: nothing changed. This must be
# CLEAN, and it must be visibly different from a block.
mkledger "$T/nochange.tsv" <<'EOF'
50 CUT nightly
26 NO_CHANGE no-project-moved
2 NO_CHANGE no-project-moved
EOF
O="$(check "$T/nochange.tsv")"; R=$?
rc "NO_CHANGE nights exit 0 -- a quiet week is healthy" 0 "$R"
has "the newest verdict is named as NO_CHANGE, not as an absence" "$O" "NO_CHANGE"
hasnt "a no-change channel is never called blocked" "$O" "BLOCKED STREAK"

# ===========================================================================
echo
echo "-- 3. ESCALATE ON STREAK -----------------------------------------------"
# ===========================================================================
# One blocked night is somebody pushing at 5pm. Grading that as a failure
# trains everyone to ignore the row, which costs more than the row is worth.
mkledger "$T/blocked1.tsv" <<'EOF'
50 CUT nightly
26 CUT nightly
2 BLOCKED realisateur-main-RED
EOF
O="$(check "$T/blocked1.tsv")"; R=$?
rc "ONE blocked night exits 0" 0 "$R"
has "...but is stated, as a note" "$O" "blocked once"
has "...and names when it escalates" "$O" "Escalates at 3 consecutive"

mkledger "$T/blocked2.tsv" <<'EOF'
50 CUT nightly
26 BLOCKED realisateur-main-RED
2 BLOCKED realisateur-main-RED
EOF
O="$(check "$T/blocked2.tsv")"; R=$?
rc "TWO blocked nights exit non-zero" 1 "$R"
has "...and say it is no longer one bad evening" "$O" "no longer one bad evening"

mkledger "$T/blocked3.tsv" <<'EOF'
74 CUT nightly
50 BLOCKED verb-set-suite-red
26 BLOCKED verb-set-suite-red
2 BLOCKED verb-set-suite-red
EOF
O="$(check "$T/blocked3.tsv")"; R=$?
rc "THREE consecutive blocked nights exit non-zero" 1 "$R"
has "the streak is called an outage" "$O" "BLOCKED STREAK of 3"
has "the streak names the date it started" "$O" "$(at 50)"
has "the streak names the reason" "$O" "verb-set-suite-red"
has "the streak says what the fleet lost" "$O" "unable to receive a release"

# ERROR counts toward the streak: a channel erroring nightly is as
# unproductive as one refusing nightly.
mkledger "$T/errstreak.tsv" <<'EOF'
50 ERROR runner-oom
26 ERROR runner-oom
2 ERROR runner-oom
EOF
check "$T/errstreak.tsv" >/dev/null 2>&1; rc "an ERROR streak escalates too" 1 $?

# NO_CHANGE breaks a streak -- it is a healthy night, not a blocked one.
mkledger "$T/broken-streak.tsv" <<'EOF'
98 CUT nightly
74 BLOCKED old
50 BLOCKED old
26 NO_CHANGE nothing-moved
2 NO_CHANGE nothing-moved
EOF
O="$(check "$T/broken-streak.tsv")"; R=$?
rc "a NO_CHANGE night breaks an older blocked streak" 0 "$R"
hasnt "...and the old streak is not still reported" "$O" "BLOCKED STREAK"

# ===========================================================================
echo
echo "-- 2 + 4. TWO CLOCKS, AND THE ONE THAT CATCHES A DEAD PRODUCER ---------"
# ===========================================================================
# THE CASE NORMALLY LEFT UNTESTED. If the workflow is disabled, deleted or
# unbilled it writes no ERROR -- it writes NOTHING. Every check that reads the
# newest row's CONTENTS is blind to it. Only "the newest verdict is older than
# N hours" is true here, and it is true on the CONSUMER with no network.
mkledger "$T/silent.tsv" <<'EOF'
400 CUT nightly
380 CUT nightly
360 CUT nightly
EOF
O="$(check "$T/silent.tsv")"; R=$?
rc "a ledger whose newest verdict is 360h old exits non-zero" 1 "$R"
has "the emitter is called SILENT, by name" "$O" "EMITTER SILENT"
has "it names the age and the limit" "$O" "360h old (limit 30h)"
has "it names the causes a contents-check cannot see" "$O" "disabled, deleted, unbilled"
has "it states why this check has to exist at all" "$O" "cannot report its own absence"

# And critically: every CONTENTS-based row still looks fine on that ledger.
# This is the assertion that proves clock 1 is not redundant with clock 2.
has "...while the decisions themselves are all still valid" "$O" "every decision value is in the closed enum"

# Clock 2 alone is not enough either: an emitter faithfully writing BLOCKED
# every night is ALIVE, and only the streak catches the dead pipeline.
mkledger "$T/livedead.tsv" <<'EOF'
74 BLOCKED main-red
50 BLOCKED main-red
26 BLOCKED main-red
2 BLOCKED main-red
EOF
O="$(check "$T/livedead.tsv")"; R=$?
has "a faithfully-reporting emitter is still graded alive" "$O" "emitter alive"
rc "...but its dead pipeline still fails the check" 1 "$R"
has "...and the failure is the streak, not the clock" "$O" "BLOCKED STREAK of 4"

# A channel that reports but has never produced.
mkledger "$T/nevercut.tsv" <<'EOF'
26 NO_CHANGE nothing-moved
2 NO_CHANGE nothing-moved
EOF
O="$(check "$T/nevercut.tsv")"; R=$?
rc "a channel that has never cut a build exits non-zero" 1 "$R"
has "...and says so plainly" "$O" "NO BUILD HAS EVER BEEN CUT"

# ===========================================================================
echo
echo "-- 5. AN EMPTY CHANNEL IS NOT A CLEAN CHANNEL --------------------------"
# ===========================================================================
printf '# date\tdecision\treason\tmain_sha\tci_run\tbuild_id\n' > "$T/empty.tsv"
O="$(check "$T/empty.tsv")"; R=$?
rc "a ledger with a header and zero rows exits non-zero" 1 "$R"
has "zero verdicts is named as such" "$O" "ZERO VERDICTS"
has "...and cites the conflation it refuses" "$O" "'Found nothing' is not 'nothing is wrong'"

# ===========================================================================
echo
echo "-- 6. UNREADABLE IS NOT EMPTY ------------------------------------------"
# ===========================================================================
O="$("$LED" --ledger "$T/no-such-file.tsv" 2>&1)"; R=$?
rc "a ledger that cannot be read is BLIND (3), not BAD (1) and not clean" 3 "$R"
has "BLIND says it is a different fact from reporting nothing" "$O" "different fact from a channel that reported nothing"
has "BLIND says what to do rather than inviting a silence" "$O" "do not silence this"

# ===========================================================================
echo
echo "-- 1. DEFAULT-DENY ON THE ENUM -----------------------------------------"
# ===========================================================================
# The day a fifth state is added, an unprepared consumer must REFUSE it, not
# grade it clean and keep grading it clean.
mkledger "$T/unknown.tsv" <<'EOF'
26 CUT nightly
2 THROTTLED quota-exhausted
EOF
O="$(check "$T/unknown.tsv")"; R=$?
rc "an unrecognised decision value exits non-zero" 1 "$R"
has "the unknown value is named" "$O" "THROTTLED"
has "it refuses rather than guesses" "$O" "must not grade them clean"
has "it names the closed enum so the fix is obvious" "$O" "CUT NO_CHANGE BLOCKED ERROR"

# An unknown value ANYWHERE in the record counts, not only the newest row:
# it means this consumer's understanding of the channel is out of date.
mkledger "$T/unknown-old.tsv" <<'EOF'
26 SKIPPED some-old-state
2 CUT nightly
EOF
check "$T/unknown-old.tsv" >/dev/null 2>&1
rc "an unknown value in an OLDER row is caught too" 1 $?

# The emitter half enforces the same enum, so "unknown" on the consumer can
# never mean "possibly fine".
"$LED" --ledger "$T/w.tsv" --append --decision THROTTLED --reason x >/dev/null 2>&1
rc "the emitter refuses to write a decision outside the enum" 2 $?
[ -f "$T/w.tsv" ] && bad "the refused append created a file anyway" \
                  || ok "a refused append writes nothing at all"

# ===========================================================================
echo
echo "-- THE EMITTER HALF ----------------------------------------------------"
# ===========================================================================
"$LED" --ledger "$T/e.tsv" --append --decision CUT --reason "3 green 0 red" \
       --main-sha 09ba8da --ci-run 31146415539 --build-id 2026-08-07T040739Z >/dev/null
O="$(cat "$T/e.tsv")"
has "append writes a header on a fresh ledger" "$O" "# date"
has "append records the decision" "$O" "CUT"
has "append records the reason" "$O" "3 green 0 red"
has "append records the main sha, so the evidence is findable" "$O" "09ba8da"
has "append records the CI run id" "$O" "31146415539"
has "append records the build id it produced" "$O" "2026-08-07T040739Z"

"$LED" --ledger "$T/e.tsv" --append --decision BLOCKED --reason "main RED" >/dev/null
n="$(grep -vc '^#' "$T/e.tsv")"
[ "$n" = 2 ] && ok "append is append-only: the earlier verdict survives" \
             || bad "append clobbered history (rows=$n)"

# A reason containing a tab would silently shift every later column.
"$LED" --ledger "$T/tabs.tsv" --append --decision ERROR \
       --reason "$(printf 'a\tb')" >/dev/null
fields="$(grep -v '^#' "$T/tabs.tsv" | head -1 | awk -F'\t' '{print NF}')"
[ "$fields" = 6 ] && ok "a tab inside a reason cannot shift the columns" \
                  || bad "a tabbed reason produced $fields fields, not 6"

# ===========================================================================
echo
echo "-- THE ARGUMENT CONTRACT -----------------------------------------------"
# ===========================================================================
"$LED" --not-a-real-flag >/dev/null 2>&1; rc "unknown flag exits 2" 2 $?
"$LED" >/dev/null 2>&1;                   rc "no --ledger is a usage error" 2 $?
"$LED" --help >/dev/null 2>&1;            rc "--help exits 0" 0 $?
O="$("$LED" --help 2>&1)"
has "--help documents BLIND as not-clean" "$O" 'not "clean"'

echo
echo "release-ledger.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
