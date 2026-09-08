#!/usr/bin/env bash
# RUNNER: bin/dresse.sh
# GUARD-TEST: bin/tests/selfdev-libexec-probe.test.sh
# GATE: strict
set -uo pipefail  # DRIFT: a self-dev account carries a private ~/.local/libexec/selfdev tree, or dcp-gate-site ticks off one instead of the shared tick (#887). Read-only -- removal/repoint touch another account's $HOME, a human's act.

CLI_NAME='selfdev-libexec-probe.sh'
CLI_SUMMARY='fail while a self-dev account still carries a private ~/.local/libexec/selfdev tree, or dcp-gate-site still ticks its release adoption out of one'
CLI_USAGE='  selfdev-libexec-probe.sh            report drift, change nothing
  selfdev-libexec-probe.sh --strict   exit 1 if anything above still exists'
CLI_FLAGS='--strict'
CLI_POSITIONAL=none
CLI_EXITS='  0  visited every account; no --strict, or --strict and nothing found
  1  --strict was given and at least one private tree, or the private tick
     row on dcp-gate-site, still exists -- a GAP, not damage: nothing here
     removes it
  6  BLIND -- the self-dev uid band matched no account at all, or
     dcp-gate-sites own crontab could not be read at all. NEVER 0.'
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/cli-guard.sh"
cli_guard "$@"

STRICT=0
for a in "$@"; do
  case "$a" in
    --strict) STRICT=1 ;;
  esac
done

UID_MIN="${SELFDEV_UID_MIN:-3000}"
UID_MAX="${SELFDEV_UID_MAX:-3099}"
HOME_ROOT="${SELFDEV_HOME_ROOT:-/home}"
SUDO="${SUDO-sudo}"
TICK_ACCT="${SELFDEV_TICK_ACCOUNT:-dcp-gate-site}"
HOST_TICK="${SELFDEV_HOST_TICK:-/usr/local/libexec/selfdev/selfdev-release-tick.sh}"

selfdev_accounts() {
  { [ -n "${SELFDEV_PASSWD:-}" ] && cat "$SELFDEV_PASSWD" || getent passwd; } 2>/dev/null \
    | awk -F: -v lo="$UID_MIN" -v hi="$UID_MAX" '$3+0>=lo && $3+0<=hi {print $1}' | sort
}

echo "selfdev-libexec-probe -- $(date '+%Y-%m-%d %H:%M')"
echo "(read-only: this probe never removes a tree or edits a crontab -- see #887)"
echo

accts="$(selfdev_accounts)"
if [ -z "$accts" ]; then
  echo "$CLI_NAME: BLIND -- no self-dev account in uid band $UID_MIN-$UID_MAX -- nothing was checked." >&2
  echo "$CLI_NAME: nothing was measured. This is NOT a clean result." >&2
  exit 6
fi

trees=0; okc=0
echo "-- ~/.local/libexec/selfdev, every self-dev account --"
while read -r u; do
  [ -n "$u" ] || continue
  d="$HOME_ROOT/$u/.local/libexec/selfdev"
  if $SUDO test -d "$d" 2>/dev/null; then
    echo "  DRIFT $u: $d still exists -- a private copy nothing refreshes (#887)"
    trees=$((trees + 1))
  else
    echo "  ok    $u"
    okc=$((okc + 1))
  fi
done <<<"$accts"

echo
echo "-- $TICK_ACCT's release tick --"
tick_bad=0; tick_blind=0
if printf '%s\n' "$accts" | grep -qx "$TICK_ACCT"; then
  if crontab_out="$($SUDO crontab -l -u "$TICK_ACCT" 2>&1)"; then
    case "$crontab_out" in
      *".local/libexec/selfdev/selfdev-release-tick.sh"*)
        echo "  DRIFT $TICK_ACCT: still adopts builds out of its own ~/.local/libexec/selfdev, not $HOST_TICK (#839, #887)"
        tick_bad=1 ;;
      *"selfdev-release:TICK"*)
        echo "  ok    $TICK_ACCT: the release tick row points at the shared host tick, not a private copy"
        ;;
      *)
        echo "  ok    $TICK_ACCT: no release-tick row in its crontab at all"
        ;;
    esac
  else
    case "$crontab_out" in
      *"no crontab for"*)
        echo "  ok    $TICK_ACCT: no crontab at all"
        ;;
      *)
        echo "  BLIND $TICK_ACCT: crontab -l -u $TICK_ACCT could not be read here -- not checked"
        tick_blind=1 ;;
    esac
  fi
else
  echo "  BLIND $TICK_ACCT is not in uid band $UID_MIN-$UID_MAX on this host -- cannot check its crontab"
  tick_blind=1
fi

n_accts="$(printf '%s\n' "$accts" | grep -c .)"
found=$((trees + tick_bad))
echo
echo "== $found drift finding(s): $trees of $n_accts account(s) carry a private ~/.local/libexec/selfdev tree, $okc clear; $TICK_ACCT's tick is $([ "$tick_bad" -eq 1 ] && echo DRIFT || { [ "$tick_blind" -eq 1 ] && echo BLIND || echo clear; }) =="

if [ "$tick_blind" -eq 1 ]; then
  echo "$CLI_NAME: could not read $TICK_ACCT's crontab -- the count above is NOT the whole picture." >&2
  exit 6
fi

[ "$STRICT" -eq 1 ] && [ "$found" -gt 0 ] && exit 1
exit 0
