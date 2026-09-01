#!/usr/bin/env bash
# roster-service.test.sh -- ARMING WORKS WHILE `suites` IS RED.
#
# That is the whole reason the arming authority left the repo, and it is the
# assertion that stops this regressing. It is proved the strong way: the
# service is exercised with `gh` removed from PATH and every GitHub credential
# unset, so there is no green build to wait for because there is no build.
#
# THE BUG. hf7y/scheduler:schedule/ROSTER lived on a branch-protected `main`
# (enforce_admins: true, required check `suites`), so `dose --arm/--park` could
# only open a PR with auto-merge. On 2026-08-30 a fleet-wide park opened twenty
# PRs and EIGHT never merged -- #382 #384 #386 #387 #389 #391 #399 #400 #404 --
# each having printed "armed: PR #N will merge itself once 'suites' is green"
# and exited 0. hf7y/scheduler#429.
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
SRV="$HERE/provision/dexter/roster/roster_server.py"

T="$(mktemp -d)"
PORT="${ROSTER_TEST_PORT:-18747}"
URL="http://127.0.0.1:$PORT"
cleanup() { [ -n "${PID:-}" ] && kill "$PID" 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT

# The declaration, in schedule/ROSTER's own shape -- AND WITH NO TRAILING
# NEWLINE, which is hf7y/scheduler#430: the live file ends on the `d` of
# `parked` and the dispatcher's `while IFS= read -r line` dropped its last row
# (dcp-gate-site) every 20 minutes. A parser that has to be got right ten times
# in three languages is the thing this service deletes.
printf '%s' '# project | account@host | rate
alpha   | alpha@testhost   | 20m
crt     | crt@testhost     | 6h
omega   | omega@testhost   | 20m' > "$T/ROSTER"

section "A. the service comes up and ingests the declaration"
env -i PATH=/usr/bin:/bin \
    ROSTER_DB="$T/roster.db" ROSTER_PORT="$PORT" ROSTER_WRITE_TOKEN=tok \
    ROSTER_DECLARATION_URL="file://$T/ROSTER" \
    python3 "$SRV" > "$T/srv.log" 2>&1 &
PID=$!
for _ in $(seq 1 40); do curl -fsS "$URL/healthz" >/dev/null 2>&1 && break; sleep 0.25; done

H="$(curl -fsS "$URL/healthz")"
eq "A1 healthz answers" "$(jq -r .ok <<<"$H")" "true"
eq "A2 all three declared rows ingested, INCLUDING the last one with no trailing newline (#430)" \
   "$(jq -r .rows <<<"$H")" "3"
eq "A3 the last row resolves by name, which the bash reader could not do" \
   "$(curl -fsS "$URL/roster/omega" | jq -r .project)" "omega"
eq "A4 a new declaration is BORN PARKED -- ingest never arms anything" \
   "$(jq -r .live <<<"$H")" "0"

section "B. arming needs no build, no PR, and no GitHub at all"
# `env -i` with a PATH holding no `gh`: if this arms, no required check can
# possibly be gating it.
GHLESS="$T/nogh"; mkdir -p "$GHLESS"
for b in curl jq; do ln -sf "$(command -v "$b")" "$GHLESS/$b"; done
arm() { env -i PATH="$GHLESS" curl -fsS -X POST "$URL/roster/$1" \
          -H 'X-Roster-Token: tok' -d "{\"state\":\"$2\",\"by\":\"witness\"}"; }

eq "B1 --arm returns the COMMITTED row, not a scheduled intent" \
   "$(arm alpha live | jq -r .state)" "live"
eq "B2 and a fresh read agrees -- it is live NOW, not once something goes green" \
   "$(curl -fsS "$URL/roster/alpha" | jq -r .state)" "live"
eq "B3 parking works the same way, which is the half you want during an incident" \
   "$(arm alpha parked | jq -r .state)" "parked"
eq "B4 no gh binary was reachable while that happened" \
   "$(PATH="$GHLESS" command -v gh || echo none)" "none"

section "C. the audit survives: who armed what, when"
LOG="$(curl -fsS "$URL/log")"
eq "C1 both transitions are logged" "$(jq -r '.armings | length' <<<"$LOG")" "2"
eq "C2 with the FROM state, so a row's history is reconstructable" \
   "$(jq -r '[.armings[].from_state] | sort | join(",")' <<<"$LOG")" "live,parked"
eq "C3 and with who did it" "$(jq -r '.armings[0].by' <<<"$LOG")" "witness"

section "D. the write refuses by default and on a bad token"
eq "D1 a wrong token is 403" \
   "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$URL/roster/crt" \
        -H 'X-Roster-Token: wrong' -d '{"state":"live"}')" "403"
eq "D2 an undeclared project is 404 -- the service does not invent rows" \
   "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$URL/roster/nosuch" \
        -H 'X-Roster-Token: tok' -d '{"state":"live"}')" "404"
eq "D3 crt was not armed by any of that" \
   "$(curl -fsS "$URL/roster/crt" | jq -r .state)" "parked"

# NEVER OPEN BY DEFAULT: a container started without data/.env refuses writes
# rather than accepting them, so a lost token file cannot silently unlock the
# estate's arming control.
env -i PATH=/usr/bin:/bin ROSTER_DB="$T/notok.db" ROSTER_PORT="$((PORT + 1))" \
    ROSTER_DECLARATION_URL="file://$T/ROSTER" python3 "$SRV" > "$T/notok.log" 2>&1 &
NOTOK=$!
for _ in $(seq 1 40); do curl -fsS "http://127.0.0.1:$((PORT + 1))/healthz" >/dev/null 2>&1 && break; sleep 0.25; done
eq "D4 with no ROSTER_WRITE_TOKEN every write is 503, not accepted" \
   "$(curl -s -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:$((PORT + 1))/roster/alpha" \
        -H 'X-Roster-Token: anything' -d '{"state":"live"}')" "503"
kill "$NOTOK" 2>/dev/null

section "E. a reader that cannot reach the service is BLIND, never stale"
# The whole failure this replaces was a reader answering from a file that was
# no longer the authority. Unreachable must not become an answer.
OUT="$(ARMING_ROSTER_URL="http://127.0.0.1:$((PORT + 2))/roster" bash -c \
  ". '$HERE/bin/lib/arming.sh'; arming_load; printf '%s|%s' \"\$?\" \"\$(arming_state alpha)\"")"
eq "E1 arming_load returns 6 and arming_state answers with nothing" "$OUT" "6|"
OUT="$(ARMING_ROSTER_URL="$URL/roster" bash -c \
  ". '$HERE/bin/lib/arming.sh'; arming_load && arming_state crt")"
eq "E2 ...and reaches the real thing when it is up" "$OUT" "parked"

section "F. one address, and the python reader agrees with the bash one"
# monkey-status-collect.py is piped to `sudo -n python3 -` over ssh with no
# environment, so it cannot source estate-set.sh and carries the literal. Two
# homes for one fact drift silently; this is what stops them.
LIT="$(grep -oE 'http://[0-9.]+:[0-9]+' "$HERE/bin/monkey-status-collect.py" | head -1)"
eq "F1 the collector's literal is GH_ESTATE_ROSTER_URL" \
   "$LIT" "$(bash -c ". '$HERE/bin/lib/estate-set.sh'; printf '%s' \"\$GH_ESTATE_ROSTER_URL\"")"
eq "F2 and it no longer names a git host" \
   "$(grep -c 'raw.githubusercontent' "$HERE/bin/monkey-status-collect.py")" "0"

summary
