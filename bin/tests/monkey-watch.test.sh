#!/usr/bin/env bash
#
# SUBJECT: bin/monkey-watch.sh -- the only observer OUTSIDE the system it
# observes, and the invoker of the dashboard Zach reads.
#
# THE DEFECT THIS PINS, 2026-08-22. realisateur#511's reachability scan read
# .github/workflows/ and this repo's bin/, found no caller for monkey-watch.sh,
# and deleted it. Its caller was a CRONTAB LINE ON ANOTHER MACHINE -- dexter,
# every ten minutes, out of a checkout dexter pulls itself.
# The blast radius was not one script: DELETION-LIST.txt:23 protected the
# dashboard payload BY NAME while the same PR deleted its only invoker, keeping
# the payload and cutting its clock (#518); #524 then deleted the merge lib as
# an orphan. Dexter's cron kept firing into a deleted path, appending
# `not found` to a 47 MB log -- a fault indicator nobody reads.
#
# So: the observer exists, names the parts it needs, those parts exist -- and
# THE DASHBOARD PAYLOAD HAS AN INVOKER, which is the guard.

set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
W="$REPO/bin/monkey-watch.sh"

echo "monkey-watch.test.sh"

section "A. the observer exists and runs only where it can see"
[ -x "$W" ] && ok "bin/monkey-watch.sh is present and executable" \
  || bad "bin/monkey-watch.sh is present and executable" "missing -- the estate has no observer outside monkey"
out="$(bash "$W" 2>&1)"; rc=$?
if [ "$rc" = 2 ]; then ok "off the VM host it FAILS LOUD (2) rather than reporting a healthy world"
else bad "off-host exit is 2" "got $rc: $out"; fi
case "$out" in *VBoxManage*) ok "...and says which host it must run on" ;;
  *) bad "the refusal names the host" "got: $out" ;; esac

section "B. the parts it names still exist"
for f in bin/monkey-status-collect.py share/monkey-status.html bin/lib/monkey-watch-merge.py bin/lib/zaxon.sh; do
  if grep -q "$(basename "$f")" "$W"; then
    [ -e "$REPO/$f" ] && ok "$f -- named by the observer, and present" \
      || bad "$f is present" "the observer names it and it is gone; this run would die at that line"
  else
    bad "$W names $(basename "$f")" "it no longer does -- either the observer changed or this check has stopped checking"
  fi
done

section "C. THE GUARD -- the payload is EXECUTED, not merely named"
# The first draft of this section counted `grep -rl <name>` as an invoker and
# reported 3 for a payload nothing ran -- two comments and a classification
# row. That is the silence-audit defect verbatim ("counts named-in-a-doc as
# wired"), which is what got silence-audit deleted. Assert the CALL SITE.
code() { grep -v '^[[:space:]]*#' "$1"; }   # comments are not wiring
if code "$W" | grep -q '< *"\$COLLECTOR"'; then
  ok "the collector is FED to monkey over stdin -- a real call site, not a mention"
else
  bad "monkey-watch.sh executes the collector" "no '< \$COLLECTOR' redirect in non-comment code"
fi
if code "$W" | grep -q 'cp "\$PAGE_SRC"'; then
  ok "the page source is COPIED into the published tree"
else
  bad "monkey-watch.sh publishes the page" "no 'cp \$PAGE_SRC' in non-comment code"
fi
if code "$W" | grep -q 'monkey-watch-merge.py'; then
  ok "the merge helper is INVOKED, so #524's orphan reading cannot recur"
else
  bad "monkey-watch.sh invokes the merge helper" "not in non-comment code"
fi
# And the superseded publisher stays gone: two writers of one status.json with
# different failure semantics is how the 2026-08-14 outage got hidden.
[ -e "$REPO/bin/publish-monkey-status.sh" ] \
  && bad "publish-monkey-status.sh stays deleted" "it is back -- two publishers, and the mandark one refuses to publish exactly when it matters" \
  || ok "publish-monkey-status.sh stays deleted -- one publisher, with the outside vantage"

section "D. it is declared, so it reaches dexter by a named channel"
# LOCAL is correct and is not "never runs anywhere": dexter pulls this repo.
. "$REPO/bin/lib/propagation-set.sh"
ch="$(prop_channel monkey-watch.sh 2>/dev/null)" || ch=""
[ "$ch" = local ] && ok "prop_channel says local -- the checkout dexter pulls itself" \
  || bad "monkey-watch.sh is classified local" "got '${ch:-unclassified}'"

section "E. THE RENDERER READS THE VERDICT -- it does not re-derive one"
# THE DEFECT THIS PINS: the page headlined off accounts[], which is EMPTY when
# the guest is unreachable -- so a DOWN monkey rendered `0 ARMED` in GREEN.
# #535 removed the publisher that hid outages, not the renderer that still
# could. Asserted by RENDERING, not by grepping for a field name.
PAGE="$REPO/share/monkey-status.html"
if command -v node >/dev/null 2>&1; then
  render() {   # render <json> -> "<class> <headline>"
    node -e '
      const fs=require("fs");
      const src=fs.readFileSync(process.argv[1],"utf8").match(/<script>([\s\S]*)<\/script>/)[1];
      let out="";
      global.document={getElementById:()=>({set innerHTML(v){out=v;}})};
      const body=src.replace(/fetch\([\s\S]*?\.then\(d=>\{/,"(d=>{").replace(/\}\)\.catch\([\s\S]*$/,"})(D);");
      new Function("D",body)(JSON.parse(process.argv[2]));
      const m=out.match(/class="verdict (\w+)">([^<]*)</);
      console.log(m?m[1]+" "+m[2].trim():"NO-HEADLINE");
    ' "$PAGE" "$1" 2>/dev/null
  }
  FRESH='"generated":"2999-01-01T00:00:00Z","valid_until":"2999-01-01T00:00:00Z"'
  got="$(render "{\"accounts\":[],\"watcher\":{$FRESH,\"verdict\":\"DOWN\",\"why\":\"sshd silent\",\"vm_state\":\"running\",\"sshd\":\"silent\",\"disk_home\":\"internal\"}}")"
  case "$got" in bad\ DOWN*) ok "an unreachable monkey headlines DOWN, in red -- not a green 0 ARMED" ;;
    *) bad "DOWN document renders DOWN" "got [$got] -- the page is deriving its own verdict again" ;; esac

  itemsrender() {
    node -e '
      const fs=require("fs");
      const src=fs.readFileSync(process.argv[1],"utf8").match(/<script>([\s\S]*)<\/script>/)[1];
      let out="";
      global.document={getElementById:()=>({set innerHTML(v){out=v;}})};
      const body=src.replace(/fetch\([\s\S]*?\.then\(d=>\{/,"(d=>{").replace(/\}\)\.catch\([\s\S]*$/,"})(D);");
      new Function("D",body)(JSON.parse(process.argv[2]));
      console.log(out);
    ' "$PAGE" "$1" 2>/dev/null
  }
  got="$(itemsrender "{\"accounts\":[],\"watcher\":{$FRESH,\"verdict\":\"DOWN\",\"why\":\"sshd silent\",\"vm_state\":\"running\",\"sshd\":\"silent\",\"disk_home\":\"internal\",\"screenshot\":true}}")"
  has "a captured console screenshot is linked from the page" "$got" 'href="console.png"'
  got="$(itemsrender "{\"accounts\":[],\"watcher\":{$FRESH,\"verdict\":\"DOWN\",\"why\":\"sshd silent\",\"vm_state\":\"running\",\"sshd\":\"silent\",\"disk_home\":\"internal\",\"screenshot\":false}}")"
  hasnt "no screenshot means no dangling link to one" "$got" 'href="console.png"'

  got="$(render "{\"accounts\":[],\"watcher\":{\"generated\":\"2020-01-01T00:00:00Z\",\"valid_until\":\"2020-01-01T00:00:00Z\",\"verdict\":\"OK\",\"why\":\"fine\",\"vm_state\":\"running\",\"sshd\":\"answering\",\"disk_home\":\"internal\"}}")"
  case "$got" in *UNWATCHED*) ok "a watcher past its own valid_until reads UNWATCHED, not OK" ;;
    *) bad "a stale watcher reads UNWATCHED" "got [$got] -- a dead dexter would show its last verdict as current" ;; esac

  got="$(render '{"accounts":[],"generated":"2999-01-01T00:00:00Z"}')"
  case "$got" in *UNWATCHED*) ok "a document with no watcher block cannot report health" ;;
    *) bad "a watcher-less document reads UNWATCHED" "got [$got]" ;; esac
else
  # NOT a silent skip: a guard that passes when it cannot run is C's defect.
  bad "node is available to render the page" \
    "node is not on PATH, so the renderer contract went UNCHECKED -- install node or run this suite where it exists"
fi

section "F. an outage that persists gets re-pinged, not one ticket and silence (#549)"
. "$REPO/bin/lib/monkey-watch-alert.sh"
harness_tmp
SF="$T/state"
T0="2026-08-20T00:00:00Z"; T0_1H="2026-08-20T01:00:00Z"; T0_13H="2026-08-20T13:00:00Z"

d="$(mw_alert_decide DOWN OK "$SF" 12 "$T0")"
eq "F1 OK -> DOWN is one TRANSITION ping" "$d" "TRANSITION OK DOWN"
mw_alert_mark_sent "$SF" "$T0"

d="$(mw_alert_decide DOWN DOWN "$SF" 12 "$T0_1H")"
eq "F2 +1h against a 12h cadence is silence" "$d" "NONE"

d="$(mw_alert_decide DOWN DOWN "$SF" 12 "$T0_13H")"
eq "F3 +13h re-pings, carrying elapsed down-time" "$d" "PERSIST DOWN 13"
mw_alert_mark_sent "$SF" "$T0_13H"

rm -f "$SF" "$SF.since" "$SF.alerted"
n=0; for now in "$T0" "$T0_1H" "$T0_13H"; do
  d="$(mw_alert_decide OK OK "$SF" 12 "$now")"
  [ "$d" = NONE ] || n=$((n + 1))
done
eq "F4 zero pings across any run where the verdict is OK" "$n" "0"

d="$(mw_alert_decide DOWN OK "$SF" 12 "$T0")"; mw_alert_mark_sent "$SF" "$T0"
d="$(mw_alert_decide OK DOWN "$SF" 12 "$T0_13H")"
eq "F5 DOWN -> OK is one TRANSITION ping (recovery is not silence)" "$d" "TRANSITION DOWN OK"

section "G. a DOWN verdict captures the console, not a guess about the cause (#560)"
has "G1 no cause is baked into the sshd-down WHY string" "$(grep 'sshd is \$SSHD' "$W")" 'WHY="VM running but sshd is $SSHD"'
hasnt "G1b the read-only-root inference is gone from the source" "$(code "$W")" "this is what a read-only root looks like"
has "G2 the console is captured only on DOWN" "$(code "$W")" 'if [ "$VERDICT" = DOWN ]; then'
has "G2b via vmhost_screenshot (#563), not a direct VBoxManage call" "$(code "$W")" 'vmhost_screenshot "$VM"'
has "G3 vmhost's virtualbox backend uses screenshotpng, the same probe the issue's own repro used" \
  "$(code "$REPO/bin/lib/vmhost.sh")" 'screenshotpng'
has "G4 a stale screenshot from a past incident is cleared before republishing" "$(code "$W")" 'rm -f "$WORK/site/$PUBLISH_DIR/console.png"'

section "H. the observer cannot inherit the outage it exists to report (2026-08-25)"
# Measured that day: monkey answered TCP, sent its SSH banner, then stalled in
# auth. The banner probe reported "answering", every mssh hung with no deadline,
# seven --apply runs stacked at one per cron tick, and hf7y.com/monkey stayed
# frozen on the last healthy publish for 35 minutes while the fleet was down.
has "H1 every guest ssh carries a deadline, not just a ConnectTimeout" \
  "$(code "$W")" 'timeout "$SSH_DEADLINE" ssh'
has "H2 the deadline is overridable for tests" "$(code "$W")" 'SSH_DEADLINE="${SSH_DEADLINE:-'
hasnt "H3 no bare ssh call survives in the guest helpers" \
  "$(grep -E '^mssh(_n)?\(\)' -A1 "$W" | grep -c 'timeout "\$SSH_DEADLINE" ssh' | grep -q '^2$' && echo '' || echo 'undeadlined-helper')" \
  "undeadlined-helper"
has "H4 a tick that finds a run in flight leaves rather than stacking" "$(code "$W")" 'flock -n 9'
has "H5 the lock is taken before any probe" "$(code "$W")" 'exec 9>"$LOCK_FILE"'
has "H6 a stalled session is named as such, not as a bad payload" \
  "$(code "$W")" 'the session stalled'
has "H7 timeout's 124 is what distinguishes them" "$(code "$W")" '"$guest_rc" -eq 124'

section "I. the virtual clock is published before it takes sshd (realisateur#630)"
# 2026-08-25: VirtualBox gave up 41.8h of virtual sync across a 54h session and
# the guest read as a hung kernel. `controlvm reset` could not clear it -- the
# deficit belongs to the VMM process. Nothing measured it, so the first symptom
# was sshd dying.
has "I1 the drift is read from the VM's own log" "$(code "$W")" 'offVirtualSyncGivenUp'
# The LogFldr= query itself moved to lib/vmhost.sh with the rest of the
# backend vocabulary (#563); vmhost.test.sh C4/C5 hold it there. What this
# file still owns is that monkey-watch ASKS the backend rather than knowing
# where a VirtualBox log lives.
has "I2 the log folder is asked of the backend, not a hardcoded path" \
  "$(code "$W")" "vmhost_logdir"
has "I3 the value reaches the document" "$(code "$W")" 'CLOCK_DRIFT_H="$CLOCK_DRIFT_H"'
has "I4 merge publishes it" "$(code "$REPO/bin/lib/monkey-watch-merge.py")" 'clock_drift_hours'
has "I5 an unreadable log is null, not zero" \
  "$(code "$REPO/bin/lib/monkey-watch-merge.py")" 'else None'

# THE PARSING TRAP, pinned with the real shape. VirtualBox writes the value in
# nanoseconds with SPACE thousands separators; without `tr -d " "` this parses
# as 150 and reports 0.0h forever -- a sensor that is always green.
drift_of() {  # <log line> -> hours, using the script's own pipeline
  printf '%s\n' "$1" | grep -o 'offVirtualSyncGivenUp=[0-9 ]*' | tail -1 | cut -d= -f2 \
    | tr -d ' ' | awk 'length($0)>0 {printf "%.1f", $0/3600000000000}'
}
eq "I6 the real 2026-08-25 line reads 41.8h, not 0.0" \
  "$(drift_of 'TMR3UtcNow: nsNow=1 787 700 091 442 068 751 offVirtualSync=150 576 693 643 850 offVirtualSyncGivenUp=150 576 693 340 001, NowAgain=1')" \
  "41.8"
eq "I7 a fresh session reads 0.0" "$(drift_of 'offVirtualSyncGivenUp=0,')" "0.0"
eq "I8 no such line yields nothing, not a number" "$(drift_of 'nothing here')" ""

summary
