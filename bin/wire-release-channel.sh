#!/usr/bin/env bash
# wire-release-channel.sh -- give a self-dev account (or every one of them) the
# release bootstrap and its own clock, so it can adopt verb builds.
#
# RUN ON THE SELF-DEV HOST, AS ROOT (or via sudo):
#
#   sudo bash bin/wire-release-channel.sh --all [--check|--apply]
#   sudo bash bin/wire-release-channel.sh <account> [--check|--apply]
#
# ============================================================================
# WHY THIS EXISTS -- a door that was missing, not a channel that was broken
# ============================================================================
#
# The release channel was built, tested and running. `cut-verb-build.sh`
# assembles every project's verbs into a dated build in `hf7y/verbs`;
# `build-verbs.yml` cuts one nightly; `install-verb-build.sh` fetches one by
# id, verifies every verb the manifest promises, and repoints ONE symlink
# atomically or discards the build; `selfdev-release-tick.sh` is the consumer's
# clock. None of that needed fixing.
#
# What was missing is that the clock could only be installed as the TAIL of
# `setup-selfdev-project.sh` -- a script that stands an ACCOUNT up, once, from
# nothing. An account provisioned before the release channel existed therefore
# had no way to be given a clock short of re-running account creation at it,
# which nobody was going to do. The cost, measured 2026-08-10 rather than
# supposed:
#
#   $ selfdev-release-tick.sh --survey
#   ecosim  2026-08-10T032316Z  clock 15h  armed
#   vim-arcade NONE never none        ... and eight more
#   1 ok, 9 gap, 0 bad
#
# Builds had been cut nightly for five days and NINE of ten accounts had never
# adopted one. propagation-set.sh's own headline -- A CHANNEL WITH NO CLOCK IS
# NOT A CHANNEL -- was true of nine tenths of the fleet, in the very estate
# that wrote it down. The failure was not the clock and not the builds; it was
# that the only way to install a clock was bundled inside a one-time
# account-creation script, so it silently applied to future accounts only.
#
# ============================================================================
# WHAT IT DOES NOT DO
# ============================================================================
#
# It ARMS NOTHING. Adopting a verb build is a git fetch and a symlink repoint;
# it spends no model quota and dispatches no agent. That is what makes it safe
# to run across the whole uid band while the armed set stays exactly where it
# is -- and arming remains what it was: a reviewed 0->1 in the scheduler repo's
# schedule/_paced.<host>.conf, plus that account's own sync-crontab run.
#
# It does not fetch, verify or switch a build either. It installs the bootstrap
# and the clock; `selfdev-release-tick.sh` does the rest, and delegates the
# switch to `install-verb-build.sh`, which is the one tested implementation of
# it. A second atomic-switch written here would be a second answer to "which
# build am I on", the one question a bug report has to be able to answer.
#
# ============================================================================
# PULL, NOT PUSH -- and why root is still the right caller for THIS step
# ============================================================================
#
# propagation-set.sh's doctrine is that the clock lives on the CONSUMER, runs
# as the account, from the account's own crontab, with no ssh and no sudo on
# its apply path. That is unchanged: this script installs the tick and then has
# THE ACCOUNT install its own cron entry, as itself.
#
# Root is needed here for the one thing pull cannot bootstrap -- putting the
# first files into a 0700 home the account cannot fetch them into yet. That is
# the industrial bootstrap shape (gradlew, rustup) propagation-set.sh already
# argues for, and it is a one-time act per account, not a clock.
#
# ============================================================================
# THE BOOTSTRAP SET IS DERIVED, NEVER TYPED HERE
# ============================================================================
#
# From bin/lib/propagation-set.sh, the same list bin/tests/propagation.test.sh
# enforces. A second list of "what the bootstrap is" would drift from the one
# under test, which is the one-fact-two-readers shape MONKEY.md 10 found five
# times in a single day.
set -uo pipefail

CLI_NAME='wire-release-channel.sh'
CLI_SUMMARY='install the verb-build release bootstrap and its clock on self-dev accounts that already exist'
CLI_USAGE='  wire-release-channel.sh --all [--check|--apply]      every account in the self-dev uid band
  wire-release-channel.sh <account> [--check|--apply]  one named account'
CLI_FLAGS='--all --check --apply'
CLI_POSITIONAL='<account>, or --all'
CLI_EXITS='  0  every requested account is wired (or, under --check, could be)
  1  at least one account could not be wired
  2  usage error'
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST="$(hostname -s 2>/dev/null || echo unknown)"
UID_MIN="${SELFDEV_UID_MIN:-3000}"
UID_MAX="${SELFDEV_UID_MAX:-3099}"

MODE="--check"; ALL=0; ACCT=""
for a in "$@"; do
  case "$a" in
    --check|--apply) MODE="$a" ;;
    --all)           ALL=1 ;;
    -*)              echo "$CLI_NAME: unknown flag $a" >&2; exit 2 ;;
    *)               ACCT="$a" ;;
  esac
done
if [ "$ALL" -eq 0 ] && [ -z "$ACCT" ]; then
  echo "$CLI_NAME: name an account, or --all for the whole uid band" >&2; exit 2
fi
if [ "$ALL" -eq 1 ] && [ -n "$ACCT" ]; then
  echo "$CLI_NAME: --all and a named account are mutually exclusive -- say which" >&2; exit 2
fi

# shellcheck source=lib/propagation-set.sh
. "$HERE/lib/propagation-set.sh"

# Run a command AS an account with a LOGIN-shaped PATH. Ubuntu's .profile only
# adds ~/.local/bin at login and `sudo -u x cmd` is not one -- that omission is
# what made land-selfdev.sh report "FATAL: installe is not on PATH" from the
# script that had just linked it (MONKEY.md 8.1).
run_as_acct() {
  sudo -u "$1" -H env -i \
    HOME="$2" USER="$1" LOGNAME="$1" \
    PATH="$2/.local/bin:/usr/local/bin:/usr/bin:/bin" \
    bash -lc "$3"
}

# STAGGER, so ten accounts do not all fetch in the same minute.
# selfdev-release-tick.sh's default CRON_SPEC is a fixed `41 5 * * *`, which is
# right for the one account it was written for and wrong for a fleet: wiring
# the band would put ten simultaneous clones of hf7y/verbs and ten symlink
# switches into one minute on one VM guest, every night. The tick already
# exposes TICK_CRON_SPEC for exactly this, so the fix is to pass it, not to
# edit the tick.
#
# DERIVED FROM THE NAME, not from a counter, so it is STABLE: re-running this
# script puts an account back on the same minute, and standing up an eleventh
# account does not move the other ten. An index into the sorted band would
# renumber everyone the first time a name sorted earlier than an existing one.
cron_spec_for() {
  [ -z "${TICK_CRON_SPEC:-}" ] || { printf '%s' "$TICK_CRON_SPEC"; return; }
  local m; m=$(( $(cksum <<<"$1" | cut -d' ' -f1) % 60 ))
  printf '%d 5 * * *' "$m"
}

wire_one() {
  local acct="$1" home="$2" boot f boot_ok=1 spec
  boot="$home/.local/libexec/selfdev"
  spec="$(cron_spec_for "$acct")"

  if [ "$MODE" = --check ]; then
    local n; n="$(set -- $PROP_BOOTSTRAP_SCRIPTS $PROP_BOOTSTRAP_SUPPORT; echo $#)"
    echo "  would   install $n bootstrap file(s) into $boot"
    if sudo -u "$acct" crontab -l 2>/dev/null | grep -q 'selfdev-release:TICK'; then
      echo "  ok      $acct already has the clock in its own crontab"
    else
      echo "  would   have $acct install the tick into its OWN crontab at '$spec' (arms no dispatch)"
    fi
    return 0
  fi

  install -d -m 755 -o "$acct" -g "$acct" "$boot" "$boot/lib" || return 1
  for f in $PROP_BOOTSTRAP_SCRIPTS $PROP_BOOTSTRAP_SUPPORT; do
    if [ -f "$HERE/$f" ]; then
      install -m 755 -o "$acct" -g "$acct" "$HERE/$f" "$boot/$f"
      echo "  OK      $boot/$f"
    else
      echo "  BAD     $HERE/$f is missing -- the bootstrap is incomplete and $acct cannot obtain a build"
      boot_ok=0
    fi
  done
  [ "$boot_ok" -eq 1 ] || return 1

  run_as_acct "$acct" "$home" "TICK_CRON_SPEC='$spec' '$boot/selfdev-release-tick.sh' --install-cadence --apply" 2>&1 | sed 's/^/     /'
  # WITNESS: read the crontab back, as the account, rather than believing the
  # installer's own report of itself. "crontab - exited 0" is not evidence that
  # a line is scheduled.
  if sudo -u "$acct" crontab -l 2>/dev/null | grep -q 'selfdev-release:TICK'; then
    echo "  OK      clock verified in $acct's crontab (re-read, not asserted)"
  else
    echo "  BAD     the clock is NOT in $acct's crontab -- $acct will never advance past the build it has"
    return 1
  fi
  echo "  ..      first adoption is a separate act: sudo -u $acct $boot/selfdev-release-tick.sh --apply"
}

[ "$(id -u)" -eq 0 ] || { echo "$CLI_NAME: run as root (sudo bash $0 $*)" >&2; exit 2; }

if [ "$ALL" -eq 1 ]; then
  ACCTS="$(getent passwd | awk -F: -v lo="$UID_MIN" -v hi="$UID_MAX" '$3>=lo && $3<=hi {print $1}' | sort)"
  # An empty band is a finding, not a clean run: it means this is not the
  # self-dev host, or the band moved. Reporting "0 wired, 0 failed" and exiting
  # 0 would be the found-nothing/nothing-is-wrong conflation this estate keeps
  # paying for.
  [ -n "$ACCTS" ] || { echo "$CLI_NAME: no accounts in uid band $UID_MIN-$UID_MAX on $HOST -- nothing to wire, and that is a finding" >&2; exit 1; }
else
  ACCTS="$ACCT"
fi

echo "== wire-release-channel ($MODE) on $HOST, uid band $UID_MIN-$UID_MAX =="
ok_n=0; bad_n=0
for acct in $ACCTS; do
  home="$(getent passwd "$acct" | cut -d: -f6)"
  printf '\n-- %s --\n' "$acct"
  if [ -z "$home" ] || [ ! -d "$home" ]; then
    echo "  BAD     no home for $acct -- the account does not exist here; stand it up with setup-selfdev-project.sh first"
    bad_n=$((bad_n + 1)); continue
  fi
  if wire_one "$acct" "$home"; then ok_n=$((ok_n + 1)); else bad_n=$((bad_n + 1)); fi
done

echo
echo "== $ok_n wired, $bad_n failed =="
if [ "$MODE" = --apply ] && [ "$ok_n" -gt 0 ]; then
  echo "  DO      notify-senechal 'realisateur selfdev-release-tick cron installed in $ok_n account crontab(s) on $HOST, owned by realisateur'"
  echo "  THEN    selfdev-release-tick.sh --survey   (from a hands account: every account's pin vs latest)"
fi
[ "$bad_n" -eq 0 ]
