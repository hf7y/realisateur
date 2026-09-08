#!/usr/bin/env bash
# cutover-check.sh -- has a host actually crossed to gen-2, and is the old
# design's residue GONE?
# KIND: verb
# RUNNER: operator -- whoever migrates a host; reads a REMOTE host, so CI cannot
# GUARD-TEST: bin/tests/cutover-check.test.sh -- hermetic behind CUTOVER_SSH
# GATE: none -- it grades a host, never this tree
#
# BLIND IS NEVER CLEAN -- an unreachable host exits 6, never 0.
# READS, NEVER OPENS -- credential rows test existence and mode, never contents.
# The rows, and why each one is there, are bin/lib/cutover-rows.tsv.
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
HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
ROWS="${CUTOVER_ROWS:-$HERE/lib/cutover-rows.tsv}"

pass=0; fail=0
section() { printf '\n%s\n' "$*"; }
ok()      { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
bad()     { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; return 0; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

printf 'cutover-check -- %s\n' "$HOST"
[ -r "$ROWS" ] || { section "BLIND"; bad "no row file at $ROWS -- nothing to grade with"; exit 6; }

# ONE round trip: a second ssh per row would make the report a mix of moments.
FACTS="$T/facts"
if ! "$SSH" -o BatchMode=yes -o ConnectTimeout=15 "$HOST" bash -s -- \
      "$UID_LO" "$UID_HI" "$BUILD_ROOT" > "$FACTS" 2>"$T/err" <<'PROBE'
set -uo pipefail
LO="$1"; HI="$2"; BR="$3"
accts() { awk -F: -v lo="$LO" -v hi="$HI" '$3>=lo && $3<hi {print $1}' /etc/passwd; }
echo "PROBE-OK"
echo "BUILD $(readlink "$BR/current" 2>/dev/null)"
S="$BR/current/scheduler"

for a in $(accts); do
  h="/home/$a"
  echo "ACCT $a"
  sudo -n test -d "$h/Documents/Projects/scheduler"          && echo "CLONE $a"
  sudo -n test -d "$h/.local/share/verb-builds"              && echo "PRIVATEPIN $a"
  sudo -n test -d "$h/.local/share/scheduler-paced-runner"   && echo "ACCTSTATE $a"
  sudo -n test -d "$h/.selfdev-setup"                        && echo "SETUPDIR $a"
  sudo -n test -d "$h/.local/libexec/selfdev"                && echo "ACCTLIBEXEC $a"
  sudo -n test -e "$h/.local/state/selfdev-release-tick.status" && echo "TICKSTATUS $a"
  sudo -n test -e "$h/.config/selfdev/gh-app.conf"           && echo "ACCTAPPCONF $a"
  sudo -n test -e "$h/.config/selfdev/app.pem"               && echo "ACCTAPPCONF $a"
  sudo -n test -e "$h/.local/bin/usage-gate.sh"              && echo "ACCTGATE $a"
  sudo -n test -e "$h/handrun.log"                           && echo "HANDRUN $a"
  sudo -n sh -c "ls -d $h/.local/share/*-nightly-batch/repo" >/dev/null 2>&1 && echo "NIGHTLYREPO $a"
  n=$(sudo -n -u "$a" crontab -l 2>/dev/null | grep -c 'scheduler-paced-runner:RUNNER' || true)
  [ "${n:-0}" -gt 0 ] && echo "ACCTCRON $a"
  n=$(sudo -n -u "$a" crontab -l 2>/dev/null | grep -c 'selfdev-release:TICK' || true)
  [ "${n:-0}" -gt 0 ] && echo "ACCTTICKCRON $a"
  n=$(sudo -n -u "$a" git config --get-regexp '^url\..*\.insteadof' 2>/dev/null | grep -c . || true)
  [ "${n:-0}" -gt 0 ] && echo "INSTEADOF $a"
  sudo -n test -e "$h/.claude/settings.json"                 && echo "KEEPCLAUDE $a"
  sudo -n test -e "$h/.config/gh/hosts.yml"                  && echo "KEEPGH $a"
  sudo -n test -d "$h/.local/share/scheduler-registry"       && echo "KEEPREGISTRY $a"
  sudo -n test -d "$h/.local/share/scheduler-verdict"        && echo "KEEPVERDICT $a"
  sudo -n test -d "$h/tmp"                                   && echo "KEEPTMP $a"
  id -nG "$a" 2>/dev/null | tr ' ' '\n' | grep -qx selfdev   && echo "KEEPSELFDEVGRP $a"
  [ "$(loginctl show-user "$a" -p Linger --value 2>/dev/null)" = yes ] && echo "KEEPLINGER $a"
done

n=$(sudo -n crontab -l 2>/dev/null | grep -c 'PACED_HOST_MODE=1' || true)
[ "${n:-0}" -gt 0 ] && echo "ROOTCRONROW"
# the roster read, as the identity an armed cron row actually has
sudo -n env -i /usr/bin/curl -fsS --max-time 8 \
  "${SCHEDULER_ROSTER_URL:-http://100.107.253.56:8646}/roster" >/dev/null 2>&1 \
  && echo "ROOTROSTER ok" || echo "ROOTROSTER fail"
[ -x "$S/bin/usage-gate.sh" ]                        && echo "GATE ok"
[ -e "$S/lib/gh-app-token.sh" ]                      && echo "LIBGHAPP ok"
grep -q 'ROSTER_URL' "$S/lib/dose-common.sh" 2>/dev/null && echo "SERVICEREAD ok"
# Ask what fetch_roster DELEGATES to -- the gh call is inside fetch_repo_file.
# COMMENTS STRIPPED FIRST, or this grades a paragraph, not the code beside it.
sed -n '/^fetch_roster()/,/^}/p' "$S/lib/dose-common.sh" 2>/dev/null \
  | sed 's/#.*//' \
  | grep -qE 'fetch_repo_file|gh_as|\bgh ' && echo "GHROSTER present"
grep -rl 'Documents/Projects/scheduler' "$S/schedule/" 2>/dev/null | while read -r fq; do
  echo "CLONEPATHCONF $(basename "$fq")"
done
sudo -n test -r /etc/selfdev/gh-app.conf \
  && sudo -n test -x /usr/local/libexec/selfdev/selfdev-gh-app.sh \
  && echo "HOSTCRED ok"
sudo -n test -r /etc/selfdev/claude-token && echo "CLAUDETOK ok"
# the split-brain: root drives, the account runs, so nothing per-project is root's
sudo -n test -d /root/.local/share/scheduler-verdict && echo "ROOTVERDICT"
sudo -n sh -c 'ls -d /root/.local/share/*-nightly-batch' >/dev/null 2>&1 && echo "ROOTBATCH"
sudo -n test -d /home/zach/Documents/Projects/scheduler/schedule && echo "LEGACYSCHED"
n=$(sudo -n grep -c ' DISPATCH ' /var/lib/scheduler-paced-runner/run.log 2>/dev/null || true)
[ "${n:-0}" -gt 0 ] && echo "DISPATCHED"
exit 0
PROBE
then
  section "BLIND"
  bad "could not read $HOST -- nothing was verified" "$(head -3 "$T/err")"
  printf '\ncutover-check: %d passed, %d failed -- BLIND, which is NEVER clean\n' "$pass" "$fail"
  exit 6
fi
grep -q '^PROBE-OK$' "$FACTS" || { section "BLIND"; bad "the probe did not run to completion on $HOST"; exit 6; }

# WHOLE TOKEN: `^CLONE` also matches CLONEPATHCONF -- seven clones, none named.
f() { grep -cE "^$1( |\$)" "$FACTS" 2>/dev/null || true; }
names() { grep "^$1 " "$FACTS" 2>/dev/null | awk '{print $2}' | sort -u | paste -sd' ' -; }
NACCT=$(f ACCT)
[ "$NACCT" -gt 0 ] || { section "BLIND"; bad "no uid $UID_LO-$UID_HI accounts found on $HOST -- a host with none cannot be graded"; exit 6; }

cur=''
while IFS=$'\t' read -r id sec token expect label why; do
  case "$id" in ''|\#*) continue ;; esac
  if [ "$sec" != "$cur" ]; then
    cur="$sec"
    case "$sec" in
      A) section 'A. the cutover landed' ;;
      B) section 'B. RESIDUE -- the old design is gone, not merely unused' ;;
      C) section 'C. MUST-KEEP -- asserted PRESENT, so a cleanup cannot cut load-bearing state' ;;
      *) section "$sec" ;;
    esac
  fi
  n="$(f "$token")"
  case "$expect" in
    absent)
      [ "$n" -eq 0 ] && ok "$id $label" \
        || bad "$id $label -- but $n: $(names "$token")" "$why" ;;
    present)
      [ "$n" -gt 0 ] && ok "$id $label" || bad "$id $label -- absent" "$why" ;;
    all)
      [ "$n" -ge "$NACCT" ] && ok "$id $label ($n/$NACCT)" \
        || bad "$id $label -- only $n of $NACCT account(s)" "$why" ;;
    *) bad "$id has expect='$expect', which is not absent|present|all" "the row file is malformed, so this row graded nothing" ;;
  esac
done < "$ROWS"

printf '\ncutover-check -- %s: %d passed, %d failed\n' "$HOST" "$pass" "$fail"
[ "$fail" -eq 0 ]
