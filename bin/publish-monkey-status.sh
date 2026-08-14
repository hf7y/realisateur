#!/usr/bin/env bash
# publish-monkey-status.sh -- publish self-dev status on `monkey` to
# https://hf7y.com/monkey/  (status.json + a static page that reads it).
#
# Same shape as publish-release-verdict.sh, deliberately: a machine-readable
# document plus a page that renders it, with the staleness window written by
# the publisher rather than guessed by each consumer.
#
# WHERE IT RUNS. On a host that can `ssh monkey` and `sudo -n` there --
# mandark today. It is NOT a verb: nothing outside this repo calls it, and it
# needs an ssh credential to one specific host. Run by hand or from cron:
#   bin/publish-monkey-status.sh            # render only, print the payload
#   bin/publish-monkey-status.sh --apply    # render and push to the site
#
# READ-ONLY on monkey: the collector shells out to crontab -l and reads two
# files per account. The only write is the commit into hf7y/hf7y.github.io.
set -euo pipefail

CLI_NAME="$(basename "$0")"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${MONKEY_HOST:-monkey}"
PUBLISH_REPO="${PUBLISH_REPO:-hf7y/hf7y.github.io}"
PUBLISH_DIR="${PUBLISH_DIR:-monkey}"
PAGE_URL="https://hf7y.com/$PUBLISH_DIR/"
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# --- collect ----------------------------------------------------------------
# The collector is fed over stdin rather than installed on monkey, so the
# version that ran is the version in this tree -- no second copy to drift.
ssh "$HOST" 'sudo -n python3 -' < "$HERE/bin/monkey-status-collect.py" > "$WORK/status.json" \
  || { echo "$CLI_NAME: collection on $HOST failed -- publishing nothing." >&2; exit 1; }
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d.get("accounts") else 1)' \
  "$WORK/status.json" \
  || { echo "$CLI_NAME: collector returned no accounts. Refusing to publish an empty page." >&2; exit 1; }

cp "$HERE/share/monkey-status.html" "$WORK/index.html"

if [ "$APPLY" != 1 ]; then
  cat "$WORK/status.json"
  echo
  echo "$CLI_NAME: NOT published (need --apply). Would write:"
  echo "  $PUBLISH_REPO :: $PUBLISH_DIR/{status.json,index.html} -> $PAGE_URL"
  exit 0
fi

# --- publish ----------------------------------------------------------------
CLONE="$WORK/site"
git clone -q --depth 1 "https://github.com/${PUBLISH_REPO}.git" "$CLONE" \
  || { echo "$CLI_NAME: cannot clone $PUBLISH_REPO" >&2; exit 1; }
mkdir -p "$CLONE/$PUBLISH_DIR"
cp "$WORK/status.json" "$WORK/index.html" "$CLONE/$PUBLISH_DIR/"
git -C "$CLONE" add "$PUBLISH_DIR"
if git -C "$CLONE" diff --cached --quiet; then
  echo "$CLI_NAME: nothing to publish (identical document)"; exit 0
fi
git -C "$CLONE" commit -q -m "monkey self-dev status $(date -u +%Y-%m-%dT%H:%M:%SZ)"
git -C "$CLONE" push -q origin HEAD \
  || { echo "$CLI_NAME: push to $PUBLISH_REPO failed" >&2; exit 1; }
echo "$CLI_NAME: published -> $PAGE_URL"
