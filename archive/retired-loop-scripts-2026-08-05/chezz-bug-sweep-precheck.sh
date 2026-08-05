#!/usr/bin/env bash
# Cheap pre-check for the chezz bug-sweep: decides WHETHER a run needs to
# invoke `claude -p` at all. Wired in via PRECHECK_CMD in
# chezz-bug-sweep-loop.sh -- the shared engine
# (lib/sweep-loop-common.sh) skips the claude call when this exits
# non-zero, for ZERO model cost.
#
# Why: the sweep fires every 15 min, but the open-bug set changes rarely.
# On 2026-07-17, 57 of 76 runs found "0 new" and burned a full claude
# invocation (~84s avg, ~105 min total that day) just to conclude "nothing
# to do"; exactly one run actually fixed anything. This collapses the
# quiet cycles into a single curl. We invoke claude ONLY when the set of
# open bug reports actually changed since the last run we acted on.
#
# It also posts a sweep-status heartbeat every cycle (model or not) so the
# live page's "Bug sweep last ran ..." readout stays fresh even on skipped
# runs -- that's a plain curl, not a model call.
#
# Fails SAFE: any fetch/parse problem falls through to a real run rather
# than silently going dark.
set -uo pipefail

URL="https://script.google.com/macros/s/AKfycbyjpRvPRbXlGeqqwZ2ENddLfCn52QzAM2-NSFS6B-QpmhFlVhJijQZNEV9Q7rU0MRAG/exec"
STATE_DIR="/home/zach/.local/share/chezz-bug-sweep"
SIG_FILE="$STATE_DIR/last_open_bugs.sig"
mkdir -p "$STATE_DIR"

# Open bug reports only -- defects to fix. Features are the nightly's job,
# so a new feature report must NOT wake the bug sweep.
bugs="$(curl -sL --max-time 30 "$URL?scope=bugs&status=open&type=bug&limit=200" 2>/dev/null)"

# Fetch failed or isn't a JSON array -> don't skip; let the real run decide.
if [ -z "$bugs" ] || [ "${bugs:0:1}" != "[" ]; then
  echo "precheck: tracker fetch failed/unparseable -- not skipping (running claude)"
  exit 0
fi

# Signature = "<count>:<sha1 of sorted open-bug timestamps>". Changes when
# a bug is filed OR resolved anywhere; stable otherwise.
sig="$(printf '%s' "$bugs" | python3 -c '
import json,sys,hashlib
d=json.load(sys.stdin)
ts=sorted(str(x.get("timestamp","")) for x in d)
print(f"{len(ts)}:"+hashlib.sha1("|".join(ts).encode()).hexdigest())
' 2>/dev/null)"
count="${sig%%:*}"

# Heartbeat: keep the page's proof-of-life fresh regardless of skip/run.
# A real claude run re-posts its own accurate counts afterward (command
# file step 6), overwriting this.
curl -sL --max-time 30 "$URL" -X POST -H "Content-Type: text/plain" \
  --data-raw "{\"type\":\"sweep-status\",\"fetched\":${count:-0},\"fixed\":0,\"reclassified\":0,\"leftOpen\":${count:-0}}" \
  >/dev/null 2>&1 || true

# Empty sig (python missing/failed) -> fail safe, run claude.
if [ -z "$sig" ]; then
  echo "precheck: could not compute signature -- not skipping (running claude)"
  exit 0
fi

prev="$(cat "$SIG_FILE" 2>/dev/null || echo "")"
if [ "$sig" = "$prev" ]; then
  echo "precheck: open-bug set unchanged ($count open) -- skipping claude this run"
  exit 1
fi

# Changed (or first run since this gate was added): record it and run.
printf '%s' "$sig" > "$SIG_FILE"
echo "precheck: open-bug set changed (was '${prev:-none}', now '$sig') -- running claude"
exit 0
