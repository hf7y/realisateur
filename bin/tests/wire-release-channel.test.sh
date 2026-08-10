#!/usr/bin/env bash
# HERMETICITY: hermetic. Every case exercises the ARGUMENT CONTRACT and the
# refusals, which all resolve before the script touches an account: usage
# errors and the not-root refusal exit ahead of any `install`, `sudo -u` or
# crontab write. Nothing here runs as root, so the apply path is never
# reachable from this suite -- deliberately. Its real work (installing files
# into a 0700 home and having an account write its own crontab) needs root on
# a live self-dev host with ten accounts, and a fake of that would assert that
# the fake works.
#
# wire-release-channel.test.sh -- witness for the door onto the release
# channel: that it refuses clearly, that it cannot silently arm anything, and
# that it never carries its own copy of the bootstrap list.
#
# Usage: bin/tests/wire-release-channel.test.sh   (exit 0 = all pass)
set -uo pipefail
BIN="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$BIN/wire-release-channel.sh"

pass=0; fail=0
ok()  { echo "  ok   $1"; pass=$((pass+1)); }
bad() { echo "  FAIL $1"; fail=$((fail+1)); }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected '$3', got '$2')"; fi; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (output lacked '$3')" ;; esac; }
hasnt() { case "$2" in *"$3"*) bad "$1 (output contained '$3')" ;; *) ok "$1" ;; esac; }

[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

echo "== 1. THE ARGUMENT CONTRACT =============================================="
rc=0; O="$(bash "$SCRIPT" 2>&1)" || rc=$?
eq "no argument is a usage error, not a default to --all" "$rc" 2
has "and it says which choice is missing" "$O" "--all"

rc=0; O="$(bash "$SCRIPT" --all somebody 2>&1)" || rc=$?
eq "--all plus a named account is a usage error" "$rc" 2
has "and it refuses to guess which was meant" "$O" "mutually exclusive"

rc=0; O="$(bash "$SCRIPT" --nonsense 2>&1)" || rc=$?
eq "an unknown flag exits 2" "$rc" 2

rc=0; O="$(bash "$SCRIPT" --help 2>&1)" || rc=$?
eq "--help exits 0" "$rc" 0
has "--help documents --all" "$O" "--all"
has "--help names --check as a mode" "$O" "--check"

echo
echo "== 2. NOT ROOT IS A REFUSAL, NOT A PARTIAL RUN ==========================="
# The whole job is writing into another account's 0700 home. Attempting it
# unprivileged and reporting per-account failures would be nine confusing
# "Permission denied" lines where one refusal belongs -- MONKEY.md 8.3's trap,
# where a missed dependency in a 0700 home presents as a permission error and
# reads as a broken install.
if [ "$(id -u)" -eq 0 ]; then
  echo "  skip  running as root; the not-root refusal cannot be exercised here"
else
  rc=0; O="$(bash "$SCRIPT" --all --check 2>&1)" || rc=$?
  eq "not root exits 2, before touching any account" "$rc" 2
  has "and says to re-run as root" "$O" "run as root"
  hasnt "it does not report accounts as wired on the way out" "$O" "wired,"
fi

echo
echo "== 3. IT CANNOT ARM DISPATCH ============================================="
# Arming is a 0->1 in the scheduler repo plus that account's own sync-crontab.
# This script installs a verb-build clock. The two have been confused before --
# the whole point of running it fleet-wide is that it spends no model quota --
# so the separation is asserted, not just documented.
SRC="$(cat "$SCRIPT")"
# Assert against the CODE, not the prose. The header argues at length about
# what arming is and why this is not it, so a naive grep over the whole file
# matches the very sentences promising the opposite -- and would have kept
# passing after someone deleted the paragraph and added the call.
CODE="$(grep -v '^[[:space:]]*#' "$SCRIPT")"
hasnt "no _paced conf is edited here" "$CODE" '_paced'
hasnt "no sync-crontab is invoked here" "$CODE" 'sync-crontab'
hasnt "no scheduler-run is invoked here" "$CODE" 'scheduler-run'
has   "it installs only the release tick's cadence" "$CODE" '--install-cadence'

echo
echo "== 4. ONE LIST, NOT TWO ================================================="
# The bootstrap set is bin/lib/propagation-set.sh's, enforced by
# propagation.test.sh. A second copy here would drift from the one under test:
# the one-fact-two-readers shape MONKEY.md 10 found five times in one day.
has   "the bootstrap set is sourced from propagation-set.sh" "$SRC" 'lib/propagation-set.sh'
has   "and consumed by name, not retyped" "$SRC" 'PROP_BOOTSTRAP_SCRIPTS'
hasnt "no literal install-verb-build.sh list entry is typed here" "$SRC" '
install-verb-build.sh
selfdev-release-tick.sh'

echo
echo "== 5. AN EMPTY UID BAND IS A FINDING ===================================="
# "0 wired, 0 failed, exit 0" on a host with no self-dev accounts would be the
# found-nothing/nothing-is-wrong conflation this estate keeps paying for.
has "an empty band is named as a finding" "$SRC" 'that is a finding'

echo
echo "wire-release-channel.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
