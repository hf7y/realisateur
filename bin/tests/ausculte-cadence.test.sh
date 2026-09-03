#!/usr/bin/env bash
#
# SUBJECT: bin/ausculte-cadence.sh. Hermetic -- ausculte is a stub, and the
# script has no channel to a person left to reach. G and H are what keep it
# that way; they are the point of this file now, not an afterthought in it.
#

set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/ausculte-cadence.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }
harness_tmp

mkdir -p "$T/bin" "$T/state"
stub_ausculte() { # <json> [exit]
  printf '#!/usr/bin/env bash\ncat <<%s\n%s\n%s\nexit %s\n' "JSON" "$1" "JSON" "${2:-0}" > "$T/bin/ausculte.sh"
  chmod +x "$T/bin/ausculte.sh"
}
run() { OUT="$(AUSCULTE_BIN="$T/bin/ausculte.sh" AUSCULTE_CADENCE_STATE="$T/state" \
               bash "$SCRIPT" "$@" 2>&1)"; RC=$?; }

DOWN_ROW='[{"probe":"arming","status":"DOWN","detail":"two accounts stopped"}]'
OK_ROW='[{"probe":"arming","status":"OK","detail":"all dispatching"}]'

section "A. a DOWN row is reported and recorded"
stub_ausculte "$DOWN_ROW"
run
rc "A1 exit 5 -- a DOWN row is DOWN on the first reading, not the second" 5 "$RC"
has "A2 it names the row and its detail" "$OUT" "arming"
[ -f "$T/state/arming.down" ] && ok "A3 the state is on disk, so a later reader can date it" \
  || bad "A3 the state is on disk" "no state file"

section "B. the record is a SINCE, not a counter"
# Rewriting the file each run would reset its mtime and destroy the only fact
# it carries -- how long the row has been saying this. That mtime is what a
# status page needs and what the escalation never produced usefully.
touch -d '2001-01-01T00:00:00Z' "$T/state/arming.down"
run
rc "B1 still DOWN, still exit 5" 5 "$RC"
_m="$(date -u -r "$T/state/arming.down" +%Y 2>/dev/null)"
[ "$_m" = 2001 ] && ok "B2 a persisting state does not rewrite its own timestamp" \
  || bad "B2 a persisting state keeps its timestamp" "mtime year is now [$_m]"
has "B3 and the row is reported as having held since then" "$OUT" "since 2001-01-01"

section "C. a recovery clears the record"
stub_ausculte "$OK_ROW"
run
rc "C1 exit 0" 0 "$RC"
[ -f "$T/state/arming.down" ] && bad "C2 the record is cleared" "state file survived" \
  || ok "C2 the record is cleared"
stub_ausculte "$DOWN_ROW"
run
has "C3 the next DOWN dates from now, not from the cleared record" "$OUT" "since now"

section "D. BLIND from ausculte is BLIND here"
stub_ausculte '[{"probe":"hosts","status":"BLIND","detail":"cannot reach dexter"}]'
run
rc "D1 a BLIND row is not DOWN and not OK" 0 "$RC"
[ -f "$T/state/hosts.blind" ] && ok "D2 BLIND keeps its own record, never the DOWN one" \
  || bad "D2 BLIND keeps its own record" "no hosts.blind"
[ -f "$T/state/hosts.down" ] && bad "D3 a BLIND row never writes the DOWN record" "hosts.down exists" \
  || ok "D3 a BLIND row never writes the DOWN record"

section "E. a non-array answer is BLIND, never 'no rows'"
printf '#!/usr/bin/env bash\nprintf "not json\\n"\nexit 0\n' > "$T/bin/ausculte.sh"
chmod +x "$T/bin/ausculte.sh"
run
rc "E1 exit 6" 6 "$RC"
has "E2 it says it produced no rows" "$OUT" "no rows"

section "E2. mints a credential when it has none"
printf '#!/usr/bin/env bash\n[ "$1" = --token ] && printf "ghs_fixturetoken\\n"\n' > "$T/bin/mint.sh"
chmod +x "$T/bin/mint.sh"
printf '#!/usr/bin/env bash\nprintf "[{\\"probe\\":\\"rot\\",\\"status\\":\\"OK\\",\\"detail\\":\\"%%s\\"}]\\n" "$GH_TOKEN"\n' > "$T/bin/ausculte.sh"
chmod +x "$T/bin/ausculte.sh"
OUT="$(AUSCULTE_BIN="$T/bin/ausculte.sh" AUSCULTE_CADENCE_STATE="$T/state" \
       SELFDEV_APP_MINT="$T/bin/mint.sh" GH_TOKEN='' GITHUB_TOKEN='' \
       bash "$SCRIPT" 2>&1)"; RC=$?
has "E2a the minted token reaches the probes" "$OUT" "ghs_fixturetoken"

OUT="$(AUSCULTE_BIN="$T/bin/ausculte.sh" AUSCULTE_CADENCE_STATE="$T/state" \
       SELFDEV_APP_MINT="$T/bin/mint.sh" GH_TOKEN=ghs_alreadyhere \
       bash "$SCRIPT" 2>&1)"
has "E2b an existing credential is not replaced" "$OUT" "ghs_alreadyhere"

section "F. --install-cadence writes nothing without --apply"
before="$(crontab -l 2>/dev/null | md5sum)"
run --install-cadence
has "F1 it prints the line it would install" "$OUT" "realisateur:ausculte:CADENCE"
eq "F2 the crontab is untouched" "$(crontab -l 2>/dev/null | md5sum)" "$before"

section "G. it files nothing at anybody"
# 10 issues in 5 days over 5 distinct rows, and on 2026-08-26 Zach closed three
# in one batch: "Closing as probe output, not a work item." The channel's own
# reader ruled its output is not work, so filing into it again is how that
# ruling went unread. Deleted 2026-08-27 on his call: "gh issue create DELETED".
#
# The stub below FAILS the test by succeeding: if any gh write survives, it is
# captured here and the assertion fires. A grep of the source would pass on a
# call assembled from variables; running the thing cannot be fooled that way.
cat > "$T/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
case "$*" in *"issue list"*) echo 654 ;; esac
exit 0
STUB
chmod +x "$T/bin/gh"
ghrun() { OUT="$(PATH="$T/bin:$PATH" GH_LOG="$T/gh.log" ZAXON='http://127.0.0.1:1/mcp' \
                 AUSCULTE_BIN="$T/bin/ausculte.sh" AUSCULTE_CADENCE_STATE="$T/state" \
                 bash "$SCRIPT" 2>&1)"; RC=$?; }

: > "$T/gh.log"; rm -f "$T/state"/*.down "$T/state"/*.blind
stub_ausculte "$DOWN_ROW"
ghrun; ghrun            # twice: the old code escalated on exactly this second run
rc "G1 a row DOWN twice running still exits 5" 5 "$RC"
case "$(cat "$T/gh.log")" in
  *"issue create"*) bad "G2 no issue is ever created" "it called gh issue create" ;;
  *)                ok  "G2 no issue is ever created" ;;
esac

# AND NO CLOSE EITHER. The recovery close existed only to retract the filing;
# with nothing filed it can only close an issue a HUMAN opened under that title.
: > "$T/gh.log"
stub_ausculte "$OK_ROW"
ghrun
rc "G3 a recovery exits 0" 0 "$RC"
case "$(cat "$T/gh.log")" in
  *"issue close"*) bad "G4 no issue is ever closed" "it called gh issue close" ;;
  *)               ok  "G4 no issue is ever closed" ;;
esac
[ -f "$T/state/arming.down" ] && bad "G5 the record is still cleared on recovery" "state survived" \
  || ok "G5 the record is still cleared on recovery"

section "H. it reaches no human at all, by either route"
# Measured 2026-08-26 against the relay's own ticket store: the phone leg had
# 47 questions, 47 stale, 0 EVER answered, 44% of every ticket the relay has
# carried. Zach: "it means nothing to me. I've ignored it." The relay holds ONE
# question at a time, so each held the only channel to him for its full TTL.
# These guards exist because the comment saying "do not re-add" is prose, and
# prose is what failed here.
CAD="$SCRIPT"
live="$(grep -vE '^[[:space:]]*#' "$CAD")"
case "$live" in
  *zaxon_ask*) bad "H1 no live call to zaxon_ask" "it is back -- 47 sent, 0 answered" ;;
  *)           ok  "H1 no live call to zaxon_ask" ;;
esac
case "$live" in
  *"lib/zaxon.sh"*) bad "H2 it does not even source the relay lib" "sourcing it is how the call comes back" ;;
  *)                ok  "H2 it does not even source the relay lib" ;;
esac
case "$live" in
  *"issue create"*) bad "H3 the issue leg is gone from the source too" "gh issue create is back" ;;
  *)                ok  "H3 the issue leg is gone from the source too" ;;
esac
# EXIT 5 IS WHAT IS LEFT, and it must not go quiet: a cadence that reports
# nothing and exits 0 is the no-op this file's own history is full of.
has "H4 a DOWN row still exits 5, so a caller can still see it" "$live" 'exit 5'

summary
