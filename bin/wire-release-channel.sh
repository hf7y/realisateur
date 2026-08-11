#!/usr/bin/env bash
# wire-release-channel.sh -- give a self-dev account (or every one of them) the
# release bootstrap and its own clock, so it can adopt verb builds.
#
# RUN ON THE SELF-DEV HOST, AS ROOT (or via sudo):
#
#   sudo bash bin/wire-release-channel.sh --host [--check|--apply]
#   sudo bash bin/wire-release-channel.sh --all [--check|--apply]
#   sudo bash bin/wire-release-channel.sh <account> [--check|--apply]
#
# ============================================================================
# --host: ONE PIN FOR THE MACHINE, AND WHY IT IS NOT THE SAME SHAPE AS --all
# ============================================================================
#
# Zach, 2026-08-11, on being shown that `ssh monkey <verb>` finds nothing:
# "unless there's a good reason not to, all verbs should be installed this way.
# change the install logic."
#
# THE MEASUREMENT THAT PROMPTED IT. `ssh monkey` yields
# PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin plus games
# and snap -- NOTHING under $HOME, because Ubuntu's .profile adds ~/.local/bin
# at login and a command-form ssh is not one. So on the host that runs five
# self-dev accounts, zero of the 33 verbs in the current build were reachable
# as `ssh monkey <verb>`, and /usr/local/bin was empty. The per-ACCOUNT wiring
# below is not wrong -- it is invisible from outside the account.
#
# WHAT --host DOES DIFFERENTLY. The build root is /usr/local/share/verb-builds
# and the links go into /usr/local/bin, so one pin serves every account on the
# machine and every non-interactive shell that ssh opens on it.
#
# THE TWO CONSEQUENCES, NAMED RATHER THAN DISCOVERED:
#
#   1. PER-ACCOUNT ROLLBACK IS GONE. Accounts move to a new build together.
#      That is a real loss and it is accepted, because nothing was using it and
#      because VERB-DISTRIBUTION.md section 4's own argument is that every user
#      path should install THE SAME NAMED THING -- "I am on 2026-08-11T031603Z"
#      is a bug report, and it stops being one if it is only true of one uid.
#
#   2. THE CLOCK HAS TO MOVE WITH THE ARTIFACT. An unprivileged account cannot
#      write /usr/local, so the five per-account TICK lines become ONE root
#      tick. This does not abandon propagation-set.sh's "pull, not push": the
#      pull still happens on the consumer, from the consumer's own crontab,
#      with no ssh -- there is simply one consumer per host instead of one per
#      account, for an artifact that is now per host. It is also strictly less
#      machinery: one nightly clone of hf7y/verbs instead of five.
#
# ORDER IS LOAD-BEARING. Adopt and verify /usr/local/bin FIRST; retire the
# per-account ticks only after. Reversing that leaves five accounts with no
# verb path at all, which is the failure the release channel exists to prevent.
# This script therefore retires NOTHING -- see "WHAT IT DOES NOT DO".
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
# --host RETIRES NOTHING. It does not remove a per-account TICK line, delete an
# account's build root, or touch ~/.local/bin. Every one of those is safe only
# AFTER /usr/local/bin has been verified to resolve, and "the previous channel
# was torn down in the same run that stood the new one up" is how a migration
# turns into an outage with no way back. Retirement is a separate reviewed act
# with its own issue.
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
CLI_SUMMARY='install the verb-build release bootstrap and its clock -- host-wide, or on self-dev accounts that already exist'
CLI_USAGE='  wire-release-channel.sh --host [--check|--apply]      /usr/local/bin, one pin for the whole machine
  wire-release-channel.sh --all [--check|--apply]      every account in the self-dev uid band
  wire-release-channel.sh <account> [--check|--apply]  one named account'
CLI_FLAGS='--host --all --check --apply'
CLI_POSITIONAL='<account>, or --all, or --host'
CLI_EXITS='  0  every requested target is wired (or, under --check, could be)
  1  at least one target could not be wired
  2  usage error'
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST="$(hostname -s 2>/dev/null || echo unknown)"
UID_MIN="${SELFDEV_UID_MIN:-3000}"
UID_MAX="${SELFDEV_UID_MAX:-3099}"

MODE="--check"; ALL=0; HOSTWIDE=0; ACCT=""
for a in "$@"; do
  case "$a" in
    --check|--apply) MODE="$a" ;;
    --all)           ALL=1 ;;
    --host)          HOSTWIDE=1 ;;
    -*)              echo "$CLI_NAME: unknown flag $a" >&2; exit 2 ;;
    *)               ACCT="$a" ;;
  esac
done
if [ "$ALL" -eq 0 ] && [ "$HOSTWIDE" -eq 0 ] && [ -z "$ACCT" ]; then
  echo "$CLI_NAME: name an account, --all for the whole uid band, or --host for the machine" >&2; exit 2
fi
# Every pair of these is a different target with a different link directory, so
# a run that accepted two would have to pick one silently. Say which.
if [ $(( ALL + HOSTWIDE + (${#ACCT} > 0 ? 1 : 0) )) -gt 1 ]; then
  echo "$CLI_NAME: --host, --all and a named account are mutually exclusive -- say which" >&2; exit 2
fi

# --- host-scoped paths. Overridable ONLY so bin/tests can exercise this
# without being root on a real host, same reasoning as the tick's own knobs.
HOST_BUILD_ROOT="${HOST_VERB_BUILD_ROOT:-/usr/local/share/verb-builds}"
HOST_BIN="${HOST_INSTALLE_BIN:-/usr/local/bin}"
HOST_LIBEXEC="${HOST_SELFDEV_LIBEXEC:-/usr/local/libexec/selfdev}"
HOST_STATE="${HOST_TICK_STATE:-/var/lib/selfdev-release}"

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

# Read a crontab and KEEP its stderr, merged into stdout.
#
# Not `2>/dev/null`. An empty crontab writes "no crontab for <user>" to stderr
# and exits 1 -- that is the ANSWER, not an error. But a permission failure
# writes there too, and silencing both makes them the same event. That is
# precisely what bin/silence-audit.sh's [stderr-silenced] rule is about: "turns
# permission denied into clean". The grep below is unaffected either way (no
# error message contains the tag), so the only thing the silence bought was
# hiding the reason from the branch whose whole job is to report it.
crontab_of() { # crontab_of [account] -- the crontab, or why it could not be read
  if [ -n "${1:-}" ]; then sudo -u "$1" crontab -l 2>&1; else crontab -l 2>&1; fi
}
has_tick() { crontab_of "${1:-}" | grep -q 'selfdev-release:TICK'; }

wire_one() {
  local acct="$1" home="$2" boot f boot_ok=1 spec
  boot="$home/.local/libexec/selfdev"
  spec="$(cron_spec_for "$acct")"

  if [ "$MODE" = --check ]; then
    local n; n="$(set -- $PROP_BOOTSTRAP_SCRIPTS $PROP_BOOTSTRAP_SUPPORT; echo $#)"
    echo "  would   install $n bootstrap file(s) into $boot"
    if has_tick "$acct"; then
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
  if has_tick "$acct"; then
    echo "  OK      clock verified in $acct's crontab (re-read, not asserted)"
  else
    echo "  BAD     the clock is NOT in $acct's crontab -- $acct will never advance past the build it has"
    echo "  BAD     crontab -l said: $(crontab_of "$acct" | head -3 | tr '\n' ' ')"
    return 1
  fi
  echo "  ..      first adoption is a separate act: sudo -u $acct $boot/selfdev-release-tick.sh --apply"
}

# ---------------------------------------------------------------------------
# --host. Same three acts as wire_one -- bootstrap, adopt, clock -- against
# host-scoped paths, plus one wire_one does not need: a witness that the LINKS
# resolve. Per account, `installe` owns the bin directory and --link is off, so
# there is nothing to witness; here the links ARE the deliverable, and a pin
# that moved while /usr/local/bin stayed empty is precisely the shape that
# looks healthy from every report and delivers nothing to a user's PATH.
# ---------------------------------------------------------------------------
# The environment BOTH the first adoption and the cron line need, written ONCE.
# An array, so `env "${TICK_ENV[@]}"` needs no word-splitting and `${TICK_ENV[*]}`
# still yields the single string cron wants ahead of the command. Two spellings
# of the same four settings is how the run that installs the clock and the clock
# itself end up disagreeing about which build root they mean.
TICK_ENV=(
  "VERB_BUILD_ROOT=$HOST_BUILD_ROOT"
  "INSTALLE_BIN=$HOST_BIN"
  "TICK_STATE=$HOST_STATE"
  "TICK_LINK=1"
)

wire_host() {
  local f boot_ok=1 spec tick before after linked
  spec="$(cron_spec_for "$HOST")"       # by HOSTNAME, not by account: one tick
  tick="$HOST_LIBEXEC/selfdev-release-tick.sh"

  if [ "$MODE" = --check ]; then
    local n; n="$(set -- $PROP_BOOTSTRAP_SCRIPTS $PROP_BOOTSTRAP_SUPPORT; echo $#)"
    echo "  would   install $n bootstrap file(s) into $HOST_LIBEXEC"
    echo "  would   adopt the latest build into $HOST_BUILD_ROOT and link it into $HOST_BIN"
    if has_tick; then
      echo "  ok      root already has the host clock in its own crontab"
    else
      echo "  would   install the host tick into ROOT's crontab at '$spec' (arms no dispatch)"
    fi
    echo "  now     $HOST_BIN holds $(ls -1 "$HOST_BIN" 2>/dev/null | wc -l) file(s); current pin: $(readlink "$HOST_BUILD_ROOT/current" 2>/dev/null || echo '<none>')"
    return 0
  fi

  install -d -m 755 -o root -g root \
    "$HOST_LIBEXEC" "$HOST_LIBEXEC/lib" "$HOST_BUILD_ROOT" "$HOST_STATE" "$HOST_BIN" || return 1
  for f in $PROP_BOOTSTRAP_SCRIPTS $PROP_BOOTSTRAP_SUPPORT; do
    if [ -f "$HERE/$f" ]; then
      install -m 755 -o root -g root "$HERE/$f" "$HOST_LIBEXEC/$f"
      echo "  OK      $HOST_LIBEXEC/$f"
    else
      echo "  BAD     $HERE/$f is missing -- the bootstrap is incomplete and $HOST cannot obtain a build"
      boot_ok=0
    fi
  done
  [ "$boot_ok" -eq 1 ] || return 1

  # FIRST ADOPTION, here rather than left to the clock. wire_one defers it
  # ("first adoption is a separate act") because an account already had verbs
  # from its landing and could wait a night for the pin to move. This host has
  # NONE: leaving it to the tick means /usr/local/bin stays empty until 05:xx
  # tomorrow, and the whole point of the mode is that `ssh <host> <verb>` works
  # when the run finishes. Delegated to the tick, which delegates the switch to
  # install-verb-build.sh -- no second implementation of "adopt".
  before="$(readlink "$HOST_BUILD_ROOT/current" 2>/dev/null || echo '<none>')"
  echo "  ..      adopting (pin before: $before)"
  env "${TICK_ENV[@]}" "$tick" --apply 2>&1 | sed 's/^/     /'

  # WITNESS 1: the pin. Read off the filesystem, not off an exit code -- the
  # tick exits 1 for findings unrelated to the adoption (a clock it has not
  # installed yet, which is the state it is IN on this very run).
  after="$(readlink "$HOST_BUILD_ROOT/current" 2>/dev/null || echo '<none>')"
  if [ "$after" = '<none>' ]; then
    echo "  BAD     no build adopted -- $HOST_BUILD_ROOT/current does not resolve. Rows above say why; nothing was linked."
    return 1
  fi
  echo "  OK      pin $after (re-read after the switch, not inferred)"

  # WITNESS 2: the links, and that they point INTO the pin we just read. A
  # count alone would pass on links left by an earlier build root.
  linked="$(find "$HOST_BIN" -maxdepth 1 -type l -lname "$HOST_BUILD_ROOT/current/*" 2>/dev/null | wc -l)"
  if [ "$linked" -eq 0 ]; then
    echo "  BAD     $HOST_BIN holds no link into $HOST_BUILD_ROOT/current -- the pin moved and no PATH did. This is a channel with a clock and no consumer."
    return 1
  fi
  echo "  OK      $linked verb(s) linked into $HOST_BIN -> $HOST_BUILD_ROOT/current"

  # WITNESS 3: run one. The executable bit is not a witness -- VERB-DISTRIBUTION
  # section 6(3) records a build in which every verb was present, executable and
  # broken, because they source lib/verb.sh from a project root the assemble
  # step had not copied. `--help` introducing itself is the check that caught it.
  if [ -x "$HOST_BIN/dose" ] && "$HOST_BIN/dose" --help >/dev/null 2>&1; then
    echo "  OK      $HOST_BIN/dose --help runs (a verb that exists and cannot run is not installed)"
  else
    echo "  BAD     $HOST_BIN/dose is absent or cannot run --help -- the links resolve to something that does not work"
    return 1
  fi

  # THE CLOCK, in ROOT's own crontab, installed by root -- the same pull-not-push
  # shape as the per-account tick, with one consumer per host for an artifact
  # that is now per host. The tick re-reads crontab -l as its own witness.
  TICK_CRON_SPEC="$spec" TICK_CRON_ENV="${TICK_ENV[*]}" "$tick" --install-cadence --apply 2>&1 | sed 's/^/     /'
  if has_tick; then
    echo "  OK      host clock verified in root's crontab (re-read, not asserted)"
  else
    echo "  BAD     the clock is NOT in root's crontab -- $HOST will never advance past $after"
    echo "  BAD     crontab -l said: $(crontab_of | head -3 | tr '\n' ' ')"
    return 1
  fi
}

[ "$(id -u)" -eq 0 ] || { echo "$CLI_NAME: run as root (sudo bash $0 $*)" >&2; exit 2; }

if [ "$HOSTWIDE" -eq 1 ]; then
  echo "== wire-release-channel --host ($MODE) on $HOST =="
  echo "   build root $HOST_BUILD_ROOT   links $HOST_BIN   state $HOST_STATE"
  printf '\n-- %s (host-wide) --\n' "$HOST"
  if wire_host; then
    echo
    # "wired" is a claim about the world and --check changed nothing in it. The
    # same sentence under both modes is how a preview gets read as a result.
    if [ "$MODE" = --check ]; then
      echo "== nothing done (--check). Next: sudo bash $0 --host --apply =="
    else
      echo "== host wired =="
    fi
    if [ "$MODE" = --apply ]; then
      echo "  DO      notify-senechal 'realisateur: verb build linked into $HOST_BIN on $HOST, plus a selfdev-release-tick cron in ROOT's crontab. Owned by realisateur. Revert: rm the links + crontab line.'"
      echo "  NOTE    the per-account TICK lines and build roots are UNTOUCHED. Retiring them is a"
      echo "          separate reviewed act, and it is safe only now that $HOST_BIN resolves."
    fi
    exit 0
  else
    echo
    echo "== host NOT wired -- rows above say which step refused =="
    exit 1
  fi
fi

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
