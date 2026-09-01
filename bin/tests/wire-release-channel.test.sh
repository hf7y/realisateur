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
# "Permission denied" lines where one refusal belongs -- the known trap,
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
# the one-fact-two-readers shape, found five times in one day.
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
echo
echo "== 7. THE HOST TOOLS ARE DERIVED, NOT LISTED ============================="
# shellcheck source=bin/lib/propagation-set.sh
. "$BIN/lib/propagation-set.sh"
tools="$(prop_host_tools)"
has "dresse is what a human types on a provisioned host" "$tools" "dresse.sh"
# The host set is the provisioning steps PLUS the probes ausculte composes,
# which are LOCAL-class and would otherwise leave it blind on a host.
n_prov=$(set -- $PROP_PROVISION_SCRIPTS; echo $#)
n_tool=$(printf '%s\n' "$tools" | grep -c .)
[ "$n_tool" -ge "$n_prov" ] \
  && ok "every provisioning step travels with it (no second list)" \
  || bad "every provisioning step travels" "want at least $n_prov, got $n_tool"
for extra in ausculte-cadence.sh decision-rot.sh; do
  printf '%s\n' "$tools" | grep -qx "$extra" \
    && ok "the host carries $extra, so ausculte is not blind about it there" \
    || bad "the host carries $extra" "absent from prop_host_tools"
done
dupes="$(printf '%s\n' "$tools" | sort | uniq -d)"
eq "and dresse is not named twice" "$dupes" ""
missing=""
for t in $tools; do [ -f "$BIN/$t" ] || missing="$missing $t"; done
eq "every derived tool exists in this checkout" "$missing" ""
grep -q 'prop_host_tools' "$SCRIPT" && ok "the door reads the derivation rather than retyping it" \
  || bad "the door does not call prop_host_tools"

grep -q 'ln -sfn "$HOST_LIBEXEC/dresse.sh" "$HOST_BIN/dresse"' "$SCRIPT" \
  && ok "the verb Zach types is linked onto PATH, not only deployed to libexec" \
  || bad "dresse is deployed and never linked; a verb nobody can type is not installed"


# --- the checkout these bytes come from (2026-08-22) ------------------------
# Deploy verified against a git ref; drift fails loud.
# This script IS the deploy and it verified nothing. /root/realisateur-refresh
# sat 12 commits behind main, `--host --apply` ran out of it, reported
# "3 ok, 0 gap, 0 bad", and installed the OLD install-verb-build.sh -- so
# realisateur#531's libexec clock was "applied" and absent. Every mtime moved,
# which reads exactly like success.
echo
echo "== 8. THE CHECKOUT THESE BYTES COME FROM ================================"
harness_tmp
FN="$T/cur.sh"
awk '/^checkout_is_current\(\) \{$/,/^\}$/' "$SCRIPT" > "$FN"
grep -q 'BEHIND' "$FN" \
  && ok "checkout_is_current() lifts out of the script" \
  || bad "could not extract checkout_is_current()" "from $SCRIPT"
# shellcheck disable=SC1090
. "$FN"

g() { git -c user.email=t@t -c user.name=t -c init.defaultBranch=main "$@"; }
UP="$T/up"; mkdir -p "$UP"; g init -q "$UP"
( cd "$UP" && echo one > f && g add -A && g commit -q -m one ) >/dev/null 2>&1
g clone -q "$UP" "$T/clone" >/dev/null 2>&1; mkdir -p "$T/clone/bin"

HERE="$T/clone/bin"
O="$(checkout_is_current 2>&1)"; r=$?
eq "level with origin/main returns 0" "$r" 0

( cd "$UP" && echo two > f && g add -A && g commit -q -m two ) >/dev/null 2>&1
O="$(checkout_is_current 2>&1)"; r=$?
eq  "a checkout BEHIND origin/main returns 1 -- not 0" "$r" 1
has "and it says how far behind, in commits" "$O" "1 commit(s) BEHIND"
has "and names the one-line fix in the checkout it stands in" "$O" "pull --ff-only"

# BLIND IS NOT CURRENT. "I could not check" must never read as "it is level":
# this writes bytes to a shared host, so unknown bytes are not a conservative
# default the way an unreadable release channel is.
mkdir -p "$T/nogit/bin"; HERE="$T/nogit/bin"
O="$(checkout_is_current 2>&1)"; r=$?
eq  "a non-git directory is BLIND (6), never 0" "$r" 6
has "and it says it cannot tell what the bytes are" "$O" "cannot tell what these bytes are"

# And the refusal is WIRED, not merely defined -- the defect shape of the week.
grep -q '_cur" -ne 0' "$SCRIPT" \
  && ok "--apply refuses on a stale checkout: the guard is CALLED" \
  || bad "--apply refuses on a stale checkout" "no refusal branch in $SCRIPT"

summary
