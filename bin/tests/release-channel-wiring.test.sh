#!/usr/bin/env bash
#
# TRAPS (the rest of this header is in the vault):
# So this suite asserts the MECHANISM EXISTS. It goes red if someone:
#   - deletes or unschedules the nightly workflow
#   - removes the gate from it, or lets the gate's refusal be ignored
#   - removes the publish step, or lets a BLOCKED night publish nothing
#   - drops the consumer-side liveness check out of the tick
#   - lets the vendored workflow drift from the deployed one   (--live)
#   - lets the published endpoint go stale or malformed        (--live)
#
# Usage: bin/tests/release-channel-wiring.test.sh [--live]

set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
WF="$REPO/provision/verbs-meta/build-verbs.yml"
TICK="$REPO/bin/selfdev-release-tick.sh"
LEDGER="$REPO/bin/release-ledger.sh"
PUBLISH="$REPO/bin/publish-release-verdict.sh"

# TWO LIVE CLAIMS, and they are separable on purpose.
#   --drift  is the deployed workflow the one this repo develops? A question
#            about THIS repo's own deploy, answerable by a PR author, and the
#            one CI gates on (.github/workflows/tests.yml, deploy-drift job).
#   --live   that, plus: is the published channel healthy right now? That one
#            goes red on an outage nobody's PR caused, so it is for a human
#            and for ausculte, never for a branch.
LIVE=0; DRIFT=0
case "${1:-}" in
  --live)  LIVE=1; DRIFT=1 ;;
  --drift) DRIFT=1 ;;
esac


echo "release-channel-wiring.test.sh$([ "$LIVE" = 1 ] && echo ' --live')"

# ===========================================================================
echo
echo "-- A. THE PIECES EXIST AT ALL ------------------------------------------"
# ===========================================================================
for f in "$WF" "$TICK" "$LEDGER" "$PUBLISH"; do
  [ -f "$f" ] && ok "exists: ${f#$REPO/}" || bad "MISSING: ${f#$REPO/}"
done
for f in "$TICK" "$LEDGER" "$PUBLISH"; do
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
echo "-- C. NOTHING REFUSES THE CUT, AND THAT IS ASSERTED ---------------------"
# ===========================================================================
# The gate is DELETED (#598, #599, #600): it errored or blocked 39% of nights
# while grading a minority of the manifest. This section used to assert it ran
# before `git tag` and that its refusal was not swallowed. Those assertions
# would now pass vacuously against a file that mentions no gate, which is the
# worst outcome -- a green line about a thing that is not there. So the claim
# is INVERTED: no gate may come back without this suite being rewritten to
# describe it, and section D below is what still holds the channel honest.
if printf '%s' "$WFSRC" | grep -qE 'release-gate\.sh|steps\.gate\.outputs'; then
  bad "the workflow calls a release gate again" \
    "it was removed for grading a minority of the manifest; if it is back, this suite must assert what it now covers"
else
  ok "no release gate stands between the assemble and the tag"
fi
has "the cut still runs only outside a dry run" "$WFSRC" "inputs.dry_run != true"

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
. "$REPO/bin/lib/estate-set.sh"  # the RESOLVED target, not the source text (#672)
eq "the publisher targets the public Pages site" \
   "${PUBLISH_REPO:-$GH_ESTATE_OWNER/$GH_ESTATE_SITE_REPO}" "hf7y/hf7y.github.io"
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
echo
echo "-- G0. A PUBLISHER THAT CANNOT PUBLISH LEAVES NO STALE SUCCESS ---------"
# ===========================================================================
# THE 2026-08-07 FAILURE. The publish step died on `--build-id -` and emitted
# nothing. The endpoint kept serving the previous night's CUT, 19h old, inside

# --- the document declares its own expiry ---------------------------------
tmp=''; TG="$(mktemp -d)"; trap 'rm -rf "${tmp:-}" "$TG"' EXIT
CUT_BUILD=''
"$PUBLISH" --dry-run --decision BLOCKED --reason "a project's default branch is RED" \
  --main-sha abc1234 --ci-run 99 --build-id "${CUT_BUILD:--}" --out "$TG" >/dev/null 2>&1
prc=$?
[ "$prc" -eq 0 ] && ok "the publisher renders a BLOCKED night's verdict (the argv the workflow builds)" \
                 || bad "the publisher exited $prc on a BLOCKED night's argv -- this is the 2026-08-07 outage"

if [ -s "$TG/status.json" ]; then
  ok "it wrote a status.json"
  SJ="$(cat "$TG/status.json")"
  has "the document declares when it stops being evidence" "$SJ" '"valid_until"'
  has "it publishes the cadence that expiry is derived from" "$SJ" '"cadence_hours"'
  has "the schema is bumped so a consumer knows which shape it has" "$SJ" '"schema": 3'
  # THE CUT INTERVAL IS NOT THE EMITTER CADENCE (#603). The document has to
  # carry both, because a consumer that ages last_cut against cadence_hours
  # grades a healthy monthly channel DOWN on 29 nights in 30.
  has "it publishes the interval a BUILD is cut on, not only the emitter's" "$SJ" '"cut_interval_days"'
  has "it still carries the decision"  "$SJ" '"decision": "BLOCKED"'
  # END TO END, through the consumer's real --url path rather than a
  # paraphrase of it: the publisher's own output, graded by the real grader.
  # This is the join the original bug slipped through -- both halves had
  # suites and nothing ever ran one against the other.
  O="$("$LEDGER" --url "file://$TG/status.json" 2>&1)"; R=$?
  has "the consumer reads the publisher's own document without a fixture" "$O" "graded live from"
  hasnt "...and does not call it unparseable" "$O" "not a status document"
  # A verdict published a moment ago is inside its own expiry, so the only
  # findings may be about the CHANNEL (one blocked night), never freshness.
  hasnt "a just-published verdict is never graded EXPIRED" "$O" "VERDICT EXPIRED"
  has "...and freshness is graded against the published deadline, not a guess" "$O" "valid until"
  # Now age the same document past the expiry it published for itself. Nothing
  # about the decision changes; only the producer's claim about it expires.
  vu="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["valid_until"])' "$TG/status.json")"
  future="$(date -u -d "$vu +1 hour" +%s)"
  O="$(LEDGER_NOW="$future" "$LEDGER" --url "file://$TG/status.json" 2>&1)"; R=$?
  [ "$R" != 0 ] && ok "past its published valid_until the same document grades non-zero" \
                || bad "past its published valid_until the document still graded clean (rc=$R)"
  has "...and is named EXPIRED rather than alive" "$O" "VERDICT EXPIRED"
else
  bad "the publisher wrote no status.json"
  for m in "valid_until" "cadence_hours" "schema 3" "cut_interval_days" "decision" "end-to-end grade"; do
    bad "(skipped, no status.json): $m"
  done
fi

# The human page must read the SAME field. A page with its own hardcoded
# staleness threshold is a second answer to "is this current", and the two
# drift the first time the cron expression moves.
if [ -s "$TG/index.html" ]; then
  IH="$(cat "$TG/index.html")"
  has "the human page grades staleness from valid_until, not a hardcoded hour count" "$IH" "d.valid_until"
  has "an expired page says the decision shown is not tonight's" "$IH" "not tonight"
else
  bad "the publisher wrote no index.html"
fi

# --- the run that cannot publish does not exit 0 over it -------------------
# `set -uo pipefail` has no -e, so a publish invocation whose rc is neither
# captured nor last-in-step is a silent failure by construction.
has "the workflow captures the publisher's exit code" "$WFSRC" "prc=\$?"
has "it retries with a minimal argv rather than giving up" "$WFSRC" "minimal fallback"
has "a fallback-only publish still fails the run"          "$WFSRC" "MINIMAL FALLBACK"
has "a total publish failure is named, not implied"        "$WFSRC" "NO VERDICT WAS PUBLISHED"
has "...and says the endpoint is serving a previous night" "$WFSRC" "previous night"
# Matched on the INVOCATION (`--apply`), not on every mention of the name: the
# staging step legitimately carries `cp ... || true` because a run whose
# assemble failed has no .realisateur to copy from, and that `|| true` is
# checked one step later by the `-x` test. A grep that cannot tell those two
# apart is the false alarm this whole estate is trying to stop producing.
if printf '%s\n' "$WFSRC" | grep -- '--apply' | grep -q '|| true'; then
  bad "the publisher's failure is swallowed by '|| true' -- the channel can go silent at exit 0"
else
  ok "the publisher's failure is not swallowed by '|| true'"
fi

# ===========================================================================
if [ "$DRIFT" != 1 ]; then
  echo
  echo "  (skipped: deployed-workflow drift (--drift) and endpoint freshness (--live))"
  echo
summary
  exit
fi

echo
echo "-- G. DEPLOYED: THE VENDORED WORKFLOW IS THE ONE THAT RUNS -------------"
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

if [ "$LIVE" != 1 ]; then
  echo
  echo "  (--live skipped: endpoint freshness. That is a claim about the"
  echo "   CHANNEL's health right now, not about this branch, so CI does not"
  echo "   gate on it -- ausculte's propagation probe is what pages.)"
  echo
summary
  exit
fi

echo
echo "-- H. LIVE: THE ENDPOINT IS REACHABLE, FRESH AND WELL-FORMED -----------"
# ===========================================================================
URL="${RELEASE_STATUS_URL:-https://hf7y.com/verbs/status.json}"
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

HUMAN="${RELEASE_STATUS_PAGE:-https://hf7y.com/verbs/}"
hbody="$(curl -fsS --max-time 20 "$HUMAN" 2>/dev/null)"
[ -n "$hbody" ] && ok "the human-readable page is reachable: $HUMAN" \
                || bad "the human-readable page $HUMAN is not reachable"

echo
summary
