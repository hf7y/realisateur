#!/usr/bin/env bash
# ausculte-cadence.sh -- put the health verb on a clock, and give it a mouth.
#
# Until this file NOTHING invoked `ausculte`: no cron, no workflow, no hook, no
# script. It was typed by a human or it did not run -- which is how a refusing
# release channel and three dead accounts stayed unseen for days.
#
# TRAP: a watcher that shouts on the first DOWN teaches the reader to ignore
#   it. Two consecutive DOWNs escalate; the streak is on disk.
# TRAP: it escalates through the channel ausculte itself probes, so the issue
#   is filed FIRST -- if the relay is what is down, the record still exists.
#
set -uo pipefail

CLI_NAME='ausculte-cadence.sh'
CLI_SUMMARY='run ausculte on a clock; escalate a row that stays DOWN'
CLI_USAGE='  ausculte-cadence.sh                 run once, report, escalate if warranted
  ausculte-cadence.sh --install-cadence
                                      show the crontab line
  ausculte-cadence.sh --install-cadence --apply
                                      install it into this account'"'"'s crontab
  ausculte-cadence.sh --no-escalate   grade and record, but reach no human'
CLI_FLAGS='--install-cadence --apply --quiet --no-escalate'
CLI_POSITIONAL=none
CLI_EXITS='  0  every row OK, or a first-time DOWN recorded and not yet escalated
  5  a row has been DOWN twice running and was escalated
  6  BLIND -- ausculte itself could not be run
  2  usage error'
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
STATE="${AUSCULTE_CADENCE_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/ausculte-cadence}"
AUSCULTE="${AUSCULTE_BIN:-$HERE/ausculte.sh}"
[ -x "$AUSCULTE" ] || AUSCULTE="$(command -v ausculte || true)"
CRON_TAG='# realisateur:ausculte:CADENCE'
CRON_SPEC="${AUSCULTE_CRON_SPEC:-37 */4 * * *}"
ISSUE_REPO="${AUSCULTE_ISSUE_REPO:-hf7y/realisateur}"

MODE=run; APPLY=0; QUIET=0; NO_ESC=0
for a in "$@"; do
  case "$a" in
    --install-cadence) MODE=cadence ;;
    --apply)           APPLY=1 ;;
    --quiet)           QUIET=1 ;;
    --no-escalate)     NO_ESC=1 ;;
    -*) echo "$CLI_NAME: unknown flag $a" >&2; exit 2 ;;
    *)  echo "$CLI_NAME: unexpected argument $a" >&2; exit 2 ;;
  esac
done

if [ "$MODE" = cadence ]; then
  self="$(readlink -f "${BASH_SOURCE[0]}")"
  line="$CRON_SPEC $self --quiet $CRON_TAG"
  if [ "$APPLY" -eq 0 ]; then echo "  would   install into $(id -un)'s crontab: $line"; exit 0; fi
  ( crontab -l 2>/dev/null | grep -v 'realisateur:ausculte:CADENCE'; printf '%s\n' "$line" ) | crontab -
  # WITNESS: read it back rather than believing `crontab -` exited 0.
  if crontab -l 2>/dev/null | grep -q 'realisateur:ausculte:CADENCE'; then
    echo "  OK      cadence in $(id -un)'s crontab (re-read, not asserted): $line"
    exit 0
  fi
  echo "  BAD     the cadence is NOT in the crontab -- nothing will run ausculte" >&2
  exit 1
fi

[ -n "$AUSCULTE" ] && [ -x "$AUSCULTE" ] \
  || { echo "$CLI_NAME: BLIND -- ausculte is not runnable from here" >&2; exit 6; }

mkdir -p "$STATE" || { echo "$CLI_NAME: BLIND -- cannot write $STATE" >&2; exit 6; }

out="$("$AUSCULTE" --json 2>/dev/null)"
# --json is ONE array: reading it line-wise grades nothing and exits 0.
rows="$(printf '%s' "$out" | jq -c '.[]' 2>/dev/null)"
[ -n "$rows" ] || { echo "$CLI_NAME: BLIND -- ausculte produced no rows" >&2; exit 6; }
[ "$QUIET" -eq 1 ] || printf '%s\n' "$out"

escalated=0
while IFS= read -r row; do
  [ -n "$row" ] || continue
  name="$(printf '%s' "$row" | jq -r '.probe // .row // empty' 2>/dev/null)"
  status="$(printf '%s' "$row" | jq -r '.status // empty' 2>/dev/null)"
  detail="$(printf '%s' "$row" | jq -r '.detail // empty' 2>/dev/null)"
  [ -n "$name" ] || continue
  f="$STATE/$name.down"
  if [ "$status" != DOWN ]; then rm -f "$f"; continue; fi

  # SECOND STRIKE ESCALATES: one DOWN can be a probe catching a restart.
  if [ ! -f "$f" ]; then
    printf '%s\n' "$detail" > "$f"
    [ "$QUIET" -eq 1 ] || echo "  ..      $name DOWN once; escalates if it is DOWN again next run"
    continue
  fi

  echo "  DOWN    $name -- twice running: $detail"
  escalated=1
  # A test run must never reach a person.
  [ "$NO_ESC" -eq 1 ] && continue

  title="ausculte: $name has been DOWN for two consecutive runs"
  body="NO-DECISION: filed by the health cadence, which escalates a row only on its second consecutive DOWN

\`ausculte $name\` reported DOWN twice running.

    $detail

Reproduce: \`ausculte $name\`

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->"
  if command -v gh >/dev/null 2>&1; then
    existing="$(gh issue list -R "$ISSUE_REPO" --search "in:title \"ausculte: $name has been DOWN\"" \
                  --state open --json number --jq '.[0].number' 2>/dev/null)"
    if [ -n "$existing" ]; then
      echo "  ..      already filed as $ISSUE_REPO#$existing"
    else
      gh issue create -R "$ISSUE_REPO" --title "$title" --body "$body" >/dev/null 2>&1 \
        && echo "  ..      filed on $ISSUE_REPO" \
        || echo "  BAD     could not file the issue -- the record is this line only"
    fi
  fi

  if [ -r "$HERE/lib/zaxon.sh" ]; then
    # shellcheck source=lib/zaxon.sh
    . "$HERE/lib/zaxon.sh"
    zaxon_ask "ausculte: $name DOWN twice. $(printf '%s' "$detail" | cut -c1-90)" ausculte-cadence >/dev/null 2>&1 \
      && echo "  ..      asked over zaxon"
  fi
done <<< "$rows"

[ "$escalated" -eq 0 ] || exit 5
exit 0
