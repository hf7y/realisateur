#!/usr/bin/env bash
# cutover-check.sh -- has a host actually crossed to gen-2, and is the old
# design's residue GONE?
# KIND: verb
# RUNNER: by hand, and by whoever migrates a host; reads a REMOTE host
# GUARD-TEST: bin/tests/cutover-check.test.sh -- hermetic behind CUTOVER_SSH
# GATE: none -- it grades a host, never this tree
#
# TWO HALVES, and the second is the one that rots. "The new thing works" is
# easy to assert and easy to satisfy while the old thing sits beside it still
# armed. Every B row checks for something that should no longer EXIST.
#
# BLIND IS NEVER CLEAN. An unreachable host exits 6. Absent input reporting as
# a healthy state is this estate's signature defect, and a cutover check that
# goes quiet when it cannot look would be the worst instance of it.
#
# IT IS THE MIGRATION PLAN, EXECUTABLE. vaporwave was born clone-free and
# passes the hard rows cheaply; monkey has 19 clones, 13 per-account RUNNER
# rows and 19 per-account state dirs, and every FAIL here is one step of that
# migration in the order the steps have to happen.
set -uo pipefail

CLI_NAME='cutover-check.sh'
CLI_SUMMARY='has this host crossed to gen-2, and is the old design actually gone?'
CLI_USAGE='  cutover-check.sh [--host <h>]   grade a host; writes nothing, ever'
CLI_FLAGS='--host'
CLI_POSITIONAL=any
CLI_EXITS='  0  crossed, and no residue
  1  findings: something has not crossed, or residue remains
  6  BLIND: the host could not be read. NEVER clean.'
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/cli-guard.sh"
cli_guard "$@"

HOST="${CUTOVER_HOST:-vaporwave}"
while [ $# -gt 0 ]; do
  case "$1" in
    --host) HOST="${2:?--host needs a hostname}"; shift ;;
    *) printf '%s: unknown argument: %s\n' "$CLI_NAME" "$1" >&2; exit 2 ;;
  esac
  shift
done

SSH="${CUTOVER_SSH:-ssh}"
UID_LO="${CUTOVER_UID_LO:-3000}"
UID_HI="${CUTOVER_UID_HI:-3099}"
BUILD_ROOT="${CUTOVER_BUILD_ROOT:-/usr/local/share/verb-builds}"

pass=0; fail=0
section() { printf '\n%s\n' "$*"; }
ok()      { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
bad()     { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; [ $# -gt 1 ] && printf '        %s\n' "$2"; return 0; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

printf 'cutover-check -- %s\n' "$HOST"

# ONE round trip. Every probe below reads from this; a second ssh per row would
# make the report a mix of moments rather than one observation of one host.
FACTS="$T/facts"
if ! "$SSH" -o BatchMode=yes -o ConnectTimeout=15 "$HOST" bash -s -- \
      "$UID_LO" "$UID_HI" "$BUILD_ROOT" > "$FACTS" 2>"$T/err" <<'PROBE'
set -uo pipefail
LO="$1"; HI="$2"; BR="$3"
accts() { awk -F: -v lo="$LO" -v hi="$HI" '$3>=lo && $3<hi {print $1}' /etc/passwd; }
echo "PROBE-OK"
echo "BUILD $(readlink "$BR/current" 2>/dev/null)"
for a in $(accts); do
  echo "ACCT $a"
  sudo -n test -d "/home/$a/Documents/Projects/scheduler" && echo "CLONE $a"
  sudo -n test -d "/home/$a/.local/share/verb-builds"     && echo "PRIVATEPIN $a"
  sudo -n test -d "/home/$a/.local/share/scheduler-paced-runner" && echo "ACCTSTATE $a"
  n=$(sudo -n -u "$a" crontab -l 2>/dev/null | grep -c 'scheduler-paced-runner:RUNNER' || true)
  [ "${n:-0}" -gt 0 ] && echo "ACCTCRON $a"
done
echo "ROOTCRON $(sudo -n crontab -l 2>/dev/null | grep -c 'PACED_HOST_MODE=1' || true)"
# the roster read, as the identity an armed cron row actually has
sudo -n env -i /usr/bin/curl -fsS --max-time 8 \
  "${SCHEDULER_ROSTER_URL:-http://100.107.253.56:8646}/roster" >/dev/null 2>&1 \
  && echo "ROOTROSTER ok" || echo "ROOTROSTER fail"
S="$BR/current/scheduler"
[ -x "$S/bin/usage-gate.sh" ]                        && echo "GATE ok"
grep -q 'ROSTER_URL' "$S/lib/dose-common.sh" 2>/dev/null && echo "SERVICEREAD ok"
# The gh call is INSIDE fetch_repo_file, taking $rel -- so grepping for
# `gh_as api ... schedule/ROSTER` finds nothing and passes on a build that
# reads the roster over gh on every tick. Ask what fetch_roster DELEGATES to.
# COMMENTS STRIPPED FIRST. A prose mention of fetch_repo_file inside
# fetch_roster made this flag a build that reads over curl -- a check that
# grades a paragraph instead of the code it sits next to.
sed -n '/^fetch_roster()/,/^}/p' "$S/lib/dose-common.sh" 2>/dev/null \
  | sed 's/#.*//' \
  | grep -qE 'fetch_repo_file|gh_as|\bgh ' && echo "GHROSTER present"
grep -rl 'Documents/Projects/scheduler' "$S/schedule/" 2>/dev/null | while read -r f; do
  echo "CLONEPATHCONF $(basename "$f")"
done
PROBE
then
  section "BLIND"
  bad "could not read $HOST -- nothing was verified" "$(head -3 "$T/err")"
  printf '\ncutover-check: %d passed, %d failed -- BLIND, which is NEVER clean\n' "$pass" "$fail"
  exit 6
fi
grep -q '^PROBE-OK$' "$FACTS" || { section "BLIND"; bad "the probe did not run to completion on $HOST"; exit 6; }

# WHOLE TOKEN, not a prefix. `^CLONE` also matches CLONEPATHCONF, which made
# this report seven clones and then name none of them -- a count that cannot be
# reconciled with its own list is worse than no count.
f() { grep -cE "^$1( |\$)" "$FACTS" 2>/dev/null || true; }
names() { grep "^$1 " "$FACTS" 2>/dev/null | awk '{print $2}' | paste -sd' ' -; }
NACCT=$(f ACCT)
[ "$NACCT" -gt 0 ] || { section "BLIND"; bad "no uid $UID_LO-$UID_HI accounts found on $HOST -- a host with none cannot be graded"; exit 6; }

section "A. the cutover landed"
[ "$(f 'ROOTROSTER ok')" -gt 0 ] \
  && ok "A1 root reads the roster under env -i -- what an armed cron row is, and no credential" \
  || bad "A1 root cannot read the roster with a cleared environment" "this is the wall host mode dies on"
[ "$(f 'SERVICEREAD ok')" -gt 0 ] \
  && ok "A2 the installed build's dose-common reads a service URL" \
  || bad "A2 the build carries no ROSTER_URL -- it predates the cutover"
[ "$(f 'GHROSTER present')" -eq 0 ] \
  && ok "A3 fetch_roster delegates to no gh path -- the roster read leaves GitHub alone" \
  || bad "A3 fetch_roster still goes through gh/fetch_repo_file" "every tick asks github.com whether it may run a local job"
[ "$(f 'GATE ok')" -gt 0 ] \
  && ok "A4 usage-gate.sh rides the build -- absent, every tick HOLDs at rc=127 and reads as a busy quota" \
  || bad "A4 the build carries no usage-gate.sh"
[ "$(f ROOTCRON)" -gt 0 ] && [ "$(grep '^ROOTCRON' "$FACTS" | awk '{print $2}')" -gt 0 ] \
  && ok "A5 the host has a host-mode dispatch clock" \
  || bad "A5 no PACED_HOST_MODE row in root's crontab -- nothing dispatches"

section "B. RESIDUE -- the old design is gone, not merely unused"
[ "$(f CLONE)" -eq 0 ] \
  && ok "B1 no account carries a scheduler clone" \
  || bad "B1 $(f CLONE) scheduler clone(s) remain: $(names CLONE)" "the whole point of gen-2; each is a second, staler copy of the dispatcher"
[ "$(f ACCTCRON)" -eq 0 ] \
  && ok "B2 no per-account RUNNER crontab row" \
  || bad "B2 $(f ACCTCRON) account(s) still carry their own RUNNER row: $(names ACCTCRON)" "host mode dispatches for all of them; these double-dispatch"
[ "$(f PRIVATEPIN)" -eq 0 ] \
  && ok "B3 ONE build pin per host (#180), no per-account verb-builds" \
  || bad "B3 $(f PRIVATEPIN) account(s) keep a private build root: $(names PRIVATEPIN)" "~/.local/bin precedes /usr/local/bin, so their verbs resolve into a staler build"
[ "$(f ACCTSTATE)" -eq 0 ] \
  && ok "B4 no account-mode rotation state left behind" \
  || bad "B4 $(f ACCTSTATE) account(s) keep ~/.local/share/scheduler-paced-runner: $(names ACCTSTATE)" "a second rotation pointer for a rotation that no longer exists"
[ "$(f CLONEPATHCONF)" -eq 0 ] \
  && ok "B5 no conf in the build names a per-account clone path" \
  || bad "B5 $(f CLONEPATHCONF) conf(s) still name Documents/Projects/scheduler: $(names CLONEPATHCONF)" "on a clone-free host every one of those rows is a path that cannot exist"

printf '\ncutover-check -- %s: %d passed, %d failed\n' "$HOST" "$pass" "$fail"
[ "$fail" -eq 0 ]
