#!/usr/bin/env bash
# HERMETICITY: DELIBERATELY NOT HERMETIC, and that is this suite's entire
# reason to exist -- see "WHY THIS FILE IS DIFFERENT" below. It is the one
# suite here that asks the real world whether the channel is WIRED: it queries
# GitHub for the build-verbs schedule and `curl`s the live verdict endpoint
# (https://zach.audio/verbs/status.json and the human page). A hermetic version
# of these cases would pass on a machine where nothing is scheduled and nothing
# is published, which is the failure it is built to catch.
#
# The blast radius is bounded and declared: every access is READ-ONLY -- GETs
# and `gh` queries, no write, no push, no account touched. Both endpoints are
# overridable (RELEASE_STATUS_URL, RELEASE_STATUS_PAGE) so the suite can be
# aimed at a fixture or a staging channel. It fails LOUD rather than skipping
# when the network is absent: unreachable reports "consumers are BLIND" and
# exits non-zero, because on this suite's question an unanswerable probe and a
# healthy channel are not the same answer.
#
# release-channel-wiring.test.sh -- assert the release channel is WIRED, not
# merely that its functions work when someone calls them.
#
# WHY THIS FILE IS DIFFERENT FROM THE OTHER SUITES
# ------------------------------------------------
# bin/tests/release-gate.test.sh and bin/tests/release-ledger.test.sh both
# pass perfectly on a machine where nothing is installed, nothing is
# scheduled, and no verdict has ever been published. They exercise shell
# functions. That is exactly the "built but not wired" failure this estate
# repeats -- realisateur/BUILD-DISCIPLINE.md's own "wire-on-commit" row, and
# the reason the nightly verb build ran for two days with zero consumers.
#
# So this suite asserts the MECHANISM EXISTS. It goes red if someone:
#   - deletes or unschedules the nightly workflow
#   - removes the gate from it, or lets the gate's refusal be ignored
#   - removes the publish step, or lets a BLOCKED night publish nothing
#   - drops the consumer-side liveness check out of the tick
#   - lets the vendored workflow drift from the deployed one   (--live)
#   - lets the published endpoint go stale or malformed        (--live)
#
# TWO MODES, and the split is deliberate.
#   default  hermetic: reads tracked files only. No network. CI-safe, and it
#            is what gates a merge.
#   --live   additionally probes GitHub and the published URL. NOT run in CI:
#            a suite that fails because an external endpoint blipped teaches
#            people to ignore the suite. Run it from a terminal, or from the
#            operator survey.
#
# Usage: bin/tests/release-channel-wiring.test.sh [--live]
set -uo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
WF="$REPO/provision/verbs-meta/build-verbs.yml"
TICK="$REPO/bin/selfdev-release-tick.sh"
GATE="$REPO/bin/release-gate.sh"
LEDGER="$REPO/bin/release-ledger.sh"
PUBLISH="$REPO/bin/publish-release-verdict.sh"

LIVE=0
[ "${1:-}" = "--live" ] && LIVE=1

pass=0; fail=0
ok()  { echo "  ok   $1"; pass=$((pass+1)); }
bad() { echo "  FAIL $1"; fail=$((fail+1)); }
has()   { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing: $3)" ;; esac; }
hasnt() { case "$2" in *"$3"*) bad "$1 (unexpectedly present: $3)" ;; *) ok "$1" ;; esac; }

echo "release-channel-wiring.test.sh$([ "$LIVE" = 1 ] && echo ' --live')"

# ===========================================================================
echo
echo "-- A. THE PIECES EXIST AT ALL ------------------------------------------"
# ===========================================================================
for f in "$WF" "$TICK" "$GATE" "$LEDGER" "$PUBLISH"; do
  [ -f "$f" ] && ok "exists: ${f#$REPO/}" || bad "MISSING: ${f#$REPO/}"
done
for f in "$TICK" "$GATE" "$LEDGER" "$PUBLISH"; do
  [ -x "$f" ] && ok "executable: $(basename "$f")" || bad "not executable: $(basename "$f")"
done

WFSRC="$(cat "$WF" 2>/dev/null || true)"

# ===========================================================================
echo
echo "-- B. THE CUT IS AUTOMATIC (a schedule, not a human) -------------------"
# ===========================================================================
has "the workflow has a schedule: trigger" "$WFSRC" "schedule:"
has "the schedule names a cron expression" "$WFSRC" "cron:"
has "it can also be dispatched by hand for a recovery run" "$WFSRC" "workflow_dispatch"

# ===========================================================================
echo
echo "-- C. THE CUT IS GATED ON GREEN ----------------------------------------"
# ===========================================================================
has "the workflow invokes the release gate" "$WFSRC" "release-gate.sh"
has "the gate is handed the manifest the build just made" "$WFSRC" "--manifest"

# The gate must run BEFORE anything is tagged or pushed. A gate that runs
# after the push is a report, not a gate.
gate_line="$(printf '%s' "$WFSRC" | grep -n 'release-gate.sh' | head -1 | cut -d: -f1)"
tag_line="$(printf '%s' "$WFSRC"  | grep -n 'git tag'          | head -1 | cut -d: -f1)"
if [ -n "$gate_line" ] && [ -n "$tag_line" ] && [ "$gate_line" -lt "$tag_line" ]; then
  ok "the gate runs before the tag is cut (line $gate_line < $tag_line)"
else
  bad "the gate does not run before 'git tag' (gate=$gate_line tag=$tag_line)"
fi

# A gate whose refusal is swallowed is decoration. `|| true` on the gate line
# is the specific way this dies quietly.
if printf '%s' "$WFSRC" | grep 'release-gate.sh' | grep -q '|| true'; then
  bad "the gate's refusal is swallowed by '|| true' -- it cannot block anything"
else
  ok "the gate's refusal is not swallowed"
fi

# ===========================================================================
echo
echo "-- D. A VERDICT IS PUBLISHED EVERY NIGHT, CUT OR NOT -------------------"
# ===========================================================================
# The whole inversion. If the verdict is only published when a build is cut,
# "nothing changed" and "main is broken" are identical again.
has "the workflow publishes a verdict" "$WFSRC" "publish-release-verdict.sh"
has "the publish step runs even when an earlier step failed" "$WFSRC" "if: always()"

for d in CUT NO_CHANGE BLOCKED ERROR; do
  has "the workflow can emit the '$d' verdict" "$WFSRC" "$d"
done

# The verdict must go to a URL, not into a clone. A file in a repo drifts the
# moment anyone clones it, which is the bug being fixed.
PUBSRC="$(cat "$PUBLISH" 2>/dev/null || true)"
has "the publisher targets the public Pages site" "$PUBSRC" "hf7y.github.io"
has "the publisher writes a machine-readable endpoint" "$PUBSRC" "status.json"
has "the publisher writes a human-readable page" "$PUBSRC" "index.html"

# ===========================================================================
echo
echo "-- E. THE CONSUMER READS THE URL LIVE, EVERY TICK ----------------------"
# ===========================================================================
TICKSRC="$(cat "$TICK" 2>/dev/null || true)"
LEDSRC="$(cat "$LEDGER" 2>/dev/null || true)"

has "the tick grades the release channel, not just its own pin" "$TICKSRC" "release-ledger.sh"
has "the ledger can be graded from a live URL" "$LEDSRC" "--url"
has "the ledger fetches over the network rather than reading a clone" "$LEDSRC" "curl"

# The endpoint must be fetched live each tick. Caching it into a file that is
# then graded recreates the drifting-file problem one layer down.
if printf '%s' "$TICKSRC" | grep -q 'RELEASE_STATUS_URL\|--url'; then
  ok "the tick passes a URL, not a path into a clone"
else
  bad "the tick does not read the verdict from a URL"
fi

# ===========================================================================
echo
echo "-- F. THE CONSUMER-SIDE LIVENESS CHECK IS TIME-KEYED -------------------"
# ===========================================================================
# A producer cannot report its own absence. If the workflow is disabled or
# deleted it writes no ERROR -- it writes nothing. Only an age check catches
# that, and it has to live on the consumer.
has "the ledger grades the age of the newest verdict" "$LEDSRC" "EMITTER SILENT"
has "the age limit is a named, overridable constant" "$LEDSRC" "LEDGER_MAX_VERDICT_AGE_H"
has "the ledger says why a contents check cannot catch this" "$LEDSRC" "cannot report its own absence"
has "the ledger tracks the last CUT separately from the last verdict" "$LEDSRC" "last CUT was"
has "the ledger escalates on a streak" "$LEDSRC" "BLOCKED STREAK"
has "an empty channel is BAD, not clean" "$LEDSRC" "ZERO VERDICTS"
has "an unreadable channel is BLIND, not empty" "$LEDSRC" "BLIND"
has "the decision enum is closed and default-deny" "$LEDSRC" "UNRECOGNISED decision"

# ===========================================================================
if [ "$LIVE" != 1 ]; then
  echo
  echo "  (--live checks skipped: deployed-workflow drift and endpoint freshness)"
  echo
  echo "release-channel-wiring.test.sh: $pass passed, $fail failed"
  [ "$fail" -eq 0 ]
  exit
fi

echo
echo "-- G. LIVE: THE VENDORED WORKFLOW IS THE DEPLOYED ONE ------------------"
# ===========================================================================
# The vendored copy is only evidence about the real workflow while the two
# agree. Drift here means every assertion above is about a file nothing runs.
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
if gh api repos/hf7y/verbs/contents/.github/workflows/build-verbs.yml --jq '.content' 2>/dev/null | base64 -d > "$tmp"; then
  if diff -q "$tmp" "$WF" >/dev/null; then
    ok "the deployed workflow is byte-identical to the vendored one"
  else
    bad "DRIFT: hf7y/verbs' workflow differs from provision/verbs-meta/build-verbs.yml"
  fi
else
  bad "could not read the deployed workflow (auth? network?) -- drift is UNKNOWN, not clean"
fi

sched="$(gh api repos/hf7y/verbs/actions/workflows --jq '.workflows[]|select(.name=="build-verbs")|.state' 2>/dev/null)"
[ "$sched" = active ] && ok "the build-verbs workflow is ACTIVE on GitHub" \
                      || bad "build-verbs is '$sched' on GitHub, not active -- nothing is scheduled"

echo
echo "-- H. LIVE: THE ENDPOINT IS REACHABLE, FRESH AND WELL-FORMED -----------"
# ===========================================================================
URL="${RELEASE_STATUS_URL:-https://zach.audio/verbs/status.json}"
body="$(curl -fsS --max-time 20 "$URL" 2>/dev/null)"; crc=$?
if [ "$crc" != 0 ] || [ -z "$body" ]; then
  bad "the verdict endpoint $URL is not reachable -- consumers are BLIND"
else
  ok "the verdict endpoint is reachable: $URL"
  for k in decision generated history; do
    case "$body" in *"\"$k\""*) ok "status.json carries '$k'" ;; *) bad "status.json has no '$k'" ;; esac
  done
  "$LEDGER" --url "$URL" >/dev/null 2>&1; lr=$?
  case "$lr" in
    0) ok "the live channel grades HEALTHY" ;;
    1) bad "the live channel has findings (run: release-ledger.sh --url $URL)" ;;
    3) bad "the live channel graded BLIND" ;;
    *) bad "release-ledger.sh --url exited $lr" ;;
  esac
fi

HUMAN="${RELEASE_STATUS_PAGE:-https://zach.audio/verbs/}"
hbody="$(curl -fsS --max-time 20 "$HUMAN" 2>/dev/null)"
[ -n "$hbody" ] && ok "the human-readable page is reachable: $HUMAN" \
                || bad "the human-readable page $HUMAN is not reachable"

echo
echo "release-channel-wiring.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
