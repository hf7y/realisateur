#!/usr/bin/env bash
#
# wire-release-channel.test.sh -- witness for the door onto the release
# channel: that it refuses clearly, that it cannot silently arm anything, and
# that it never carries its own copy of the bootstrap list.
#
# Usage: bin/tests/wire-release-channel.test.sh   (exit 0 = all pass)
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
BIN="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$BIN/wire-release-channel.sh"


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
echo "== 5. THE STAGGER IS STABLE ============================================="
# The tick's own default is a fixed `41 5 * * *`. Wiring ten accounts with it
# would put ten clones of hf7y/verbs and ten symlink switches in one minute on
# one VM guest, nightly. Lift the real function rather than restating it -- a
# reimplementation here would pass while the script did something else.
eval "$(sed -n '/^cron_spec_for()/,/^}/p' "$SCRIPT")"
A1="$(cron_spec_for ecosim)"; A2="$(cron_spec_for ecosim)"
eq "same account, same minute on a re-run (no crontab churn)" "$A1" "$A2"
if [ "$(cron_spec_for ecosim)" != "$(cron_spec_for vim-arcade)" ]; then
  ok "different accounts get different minutes"
else
  bad "ecosim and vim-arcade collide on '$A1' -- the herd is not spread"
fi
# Derived from the NAME, not a position: an eleventh account must not renumber
# the ten already installed.
B1="$(cron_spec_for chezz)"
eq "a name's minute does not depend on who else exists" "$B1" "$(cron_spec_for chezz)"
case "$(cron_spec_for anything)" in
  *' 5 * * *') ok "the spec is a daily 05:xx cron 5-field line" ;;
  *) bad "unexpected cron spec shape: $(cron_spec_for anything)" ;;
esac
O="$(TICK_CRON_SPEC='7 3 * * *' cron_spec_for ecosim)"
eq "TICK_CRON_SPEC overrides the derivation" "$O" '7 3 * * *'
has "and the override is passed to the tick, not baked into it" "$CODE" 'TICK_CRON_SPEC='

echo
echo "== 6. AN EMPTY UID BAND IS A FINDING ===================================="
# "0 wired, 0 failed, exit 0" on a host with no self-dev accounts would be the
# found-nothing/nothing-is-wrong conflation this estate keeps paying for.
has "an empty band is named as a finding" "$SRC" 'that is a finding'

echo
summary
