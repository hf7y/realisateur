#!/usr/bin/env bash
#
# SUBJECT: bin/monkey-watch.sh -- the only observer OUTSIDE the system it
# observes, and the invoker of the dashboard Zach reads.
#
# THE DEFECT THIS PINS, 2026-08-22. realisateur#511's reachability scan read
# .github/workflows/ and this repo's own bin/, found no caller for
# monkey-watch.sh, and deleted it. Its caller was a CRONTAB LINE ON ANOTHER
# MACHINE -- dexter, every ten minutes, out of a checkout dexter pulls itself.
#
# The blast radius was not one script. DELETION-LIST.txt:23 protected
# publish-monkey-status.sh and monkey-status-collect.py BY NAME as "the
# dashboard Zach reads", and the same PR deleted the only thing that invokes
# them: the list kept the payload and cut its clock (realisateur#518). Then
# #524 deleted lib/monkey-watch-merge.py as an orphan -- correctly measured,
# wrong conclusion, because the right fix was to restore its consumer.
#
# Meanwhile dexter's cron kept firing into a deleted path and appending
# `not found` to a log that reached 47 MB. A cron entry pointing at a deleted
# script is not inert; it is a fault indicator nobody reads.
#
# So the assertions are: the observer exists, it still names the parts it
# needs, those parts exist -- and, generally, THE DASHBOARD PAYLOAD HAS AN
# INVOKER. That last one is the guard; the rest is scaffolding for it.

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

summary
