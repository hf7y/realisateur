#!/usr/bin/env bash
# wire-release-channel.sh -- give a self-dev account (or every one of them) the
# release bootstrap and its own clock, so it can adopt verb builds.
#
# TRAP: the bootstrap set is DERIVED from bin/lib/propagation-set.sh, never
#   typed here. A second list of "what the bootstrap is" drifts from the one
#   the tick enforces.
# TRAP: root is needed for exactly one thing pull cannot bootstrap -- putting
#   the first files into a 0700 home the account cannot fetch into yet.
# TRAP: an account-creation-time-only change applies to FUTURE accounts only.
#

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

# --- THE CHECKOUT THIS INSTALLS FROM MUST BE CURRENT --------------------
# Deploy verified against a git ref; drift fails loud.
# This script is the deploy and it verified nothing. Cost, 2026-08-22:
# /root/realisateur-refresh sat 12 commits behind main, `--host --apply` ran
# happily out of it, reported `3 ok, 0 gap, 0 bad`, and installed the OLD
# install-verb-build.sh -- so realisateur#531's libexec clock, whose entire
# purpose is to stop a host tool needing a human, was "applied" and absent.
# Nothing said so; the mtimes all moved, which reads exactly like success.
#
# FAIL CLOSED ON APPLY. Elsewhere in this estate an unreadable channel fails
# OPEN, because refusing to operate on a bad network reading is worse than
# operating on the last known good state. That reasoning does not transfer:
# this writes bytes to a shared host. Installing UNKNOWN bytes is not a
# conservative default, and "I could not check" is not "it is current".
#
# No override flag. A documented bypass turns a guard into a toll booth, and
# the one-line fix is `git pull` in the checkout you are standing in.
checkout_is_current() {
  local root rc
  root="$(cd "$HERE/.." && pwd)"
  git -C "$root" rev-parse --git-dir >/dev/null 2>&1 || {
    echo "  BLIND   $root is not a git checkout -- cannot tell what these bytes are. Install from a clone."
    return 6; }
  git -C "$root" fetch -q origin main 2>/dev/null || {
    echo "  BLIND   could not fetch origin/main -- cannot tell whether this checkout is current."
    return 6; }
  rc="$(git -C "$root" rev-list --count HEAD..FETCH_HEAD 2>/dev/null)" || return 6
  case "$rc" in ''|*[!0-9]*) return 6 ;; esac
  [ "$rc" -eq 0 ] && return 0
  echo "  BAD     this checkout is $rc commit(s) BEHIND origin/main."
  echo "          Installing from it ships stale bytes and reports success."
  echo "          Fix: git -C $root pull --ff-only"
  return 1
}

# shellcheck source=lib/propagation-set.sh
. "$HERE/lib/propagation-set.sh"

# Run a command AS an account with a LOGIN-shaped PATH. Ubuntu's .profile only
# adds ~/.local/bin at login and `sudo -u x cmd` is not one -- that omission is
# what made land-selfdev.sh report "FATAL: installe is not on PATH" from the
# script that had just linked it (vault:realisateur/MONKEY.md 8.1).
run_as_acct() {
  sudo -u "$1" -H env -i \
    HOME="$2" USER="$1" LOGNAME="$1" \
    PATH="$2/.local/bin:/usr/local/bin:/usr/bin:/bin" \
    bash -lc "$3"
}

# STAGGER, so the fleet does not all fetch in the same minute.
cron_spec_for() {
  [ -z "${TICK_CRON_SPEC:-}" ] || { printf '%s' "$TICK_CRON_SPEC"; return; }
  local m; m=$(( $(cksum <<<"$1" | cut -d' ' -f1) % 60 ))
  printf '%d 5 * * *' "$m"
}

# Read a crontab and KEEP its stderr, merged into stdout.
#
# Not `2>/dev/null`. An empty crontab writes "no crontab for <user>" to stderr
# and exits 1 -- that is the ANSWER, not an error. But a permission failure
crontab_of() { # crontab_of [account] -- the crontab, or why it could not be read
  if [ -n "${1:-}" ]; then sudo -u "$1" crontab -l 2>&1; else crontab -l 2>&1; fi
}
has_tick() { crontab_of "${1:-}" | grep -q 'selfdev-release:TICK'; }

wire_one() {
  local acct="$1" home="$2" boot f boot_ok=1 spec
  boot="$home/.local/libexec/selfdev"
  spec="$(cron_spec_for "$acct")"

  if [ "$MODE" = --check ]; then
    # SC2046 is baselined here on purpose: word splitting IS the point --
    # prop_support_libs prints one lib per line, exactly as the unquoted
    # $PROP_BOOTSTRAP_SCRIPTS beside it does. A directive cannot attach
    # through `local`, so the ratchet carries it with this reason instead.
    local n; n="$(set -- $PROP_BOOTSTRAP_SCRIPTS $(prop_support_libs "$HERE"); echo $#)"
    echo "  would   install $n bootstrap file(s) into $boot"
    if has_tick "$acct"; then
      echo "  ok      $acct already has the clock in its own crontab"
    else
      echo "  would   have $acct install the tick into its OWN crontab at '$spec' (arms no dispatch)"
    fi
    return 0
  fi

  install -d -m 755 -o "$acct" -g "$acct" "$boot" "$boot/lib" || return 1
  # shellcheck disable=SC2046  # word splitting is the point: prop_support_libs
  # prints one lib per line, exactly as $PROP_BOOTSTRAP_SCRIPTS beside it does.
  for f in $PROP_BOOTSTRAP_SCRIPTS $(prop_support_libs "$HERE"); do
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
    # SC2046 is baselined here on purpose: word splitting IS the point --
    # prop_support_libs prints one lib per line, exactly as the unquoted
    # $PROP_BOOTSTRAP_SCRIPTS beside it does. A directive cannot attach
    # through `local`, so the ratchet carries it with this reason instead.
    local n; n="$(set -- $PROP_BOOTSTRAP_SCRIPTS $(prop_support_libs "$HERE"); echo $#)"
    echo "  would   install $n bootstrap file(s) into $HOST_LIBEXEC"
    echo "  would   install $(prop_host_tools | wc -l) host tool(s) into $HOST_LIBEXEC (dresse and every step it runs)"
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
  # shellcheck disable=SC2046  # word splitting is the point: prop_support_libs
  # prints one lib per line, exactly as $PROP_BOOTSTRAP_SCRIPTS beside it does.
  for f in $PROP_BOOTSTRAP_SCRIPTS $(prop_support_libs "$HERE"); do
    if [ -f "$HERE/$f" ]; then
      install -m 755 -o root -g root "$HERE/$f" "$HOST_LIBEXEC/$f"
      echo "  OK      $HOST_LIBEXEC/$f"
    else
      echo "  BAD     $HERE/$f is missing -- the bootstrap is incomplete and $HOST cannot obtain a build"
      boot_ok=0
    fi
  done
  [ "$boot_ok" -eq 1 ] || return 1

  # THE HOST TOOLS: the verb a human types on this machine, and every step it
  # runs. Missing ones are named, never skipped silently.
  for f in $(prop_host_tools); do
    if [ -f "$HERE/$f" ]; then
      install -m 755 -o root -g root "$HERE/$f" "$HOST_LIBEXEC/$f"
      echo "  OK      $HOST_LIBEXEC/$f"
    else
      echo "  BAD     $HERE/$f is missing -- $HOST cannot be provisioned from its own libexec"
      boot_ok=0
    fi
  done
  [ "$boot_ok" -eq 1 ] || return 1
  # THE VERB HAS TO BE TYPEABLE. dresse is provision-class, so it never travels
  # in a verb build and nothing links it: deployed to libexec and absent from
  # PATH, it is a verb Zach cannot type, which was its whole justification.
  ln -sfn "$HOST_LIBEXEC/dresse.sh" "$HOST_BIN/dresse" \
    && echo "  OK      $HOST_BIN/dresse -> $HOST_LIBEXEC/dresse.sh" \
    || { echo "  BAD     could not link $HOST_BIN/dresse"; return 1; }
  if [ -x "$HOST_LIBEXEC/dresse.sh" ] && bash "$HOST_LIBEXEC/dresse.sh" --help >/dev/null 2>&1; then
    echo "  OK      $HOST_LIBEXEC/dresse.sh --help runs from the deployed path"
  else
    echo "  BAD     $HOST_LIBEXEC/dresse.sh is absent or cannot run --help"
    return 1
  fi

  # FIRST ADOPTION, here rather than left to the clock. wire_one defers it
  # ("first adoption is a separate act") because an account already had verbs
  # from its landing and could wait a night for the pin to move. This host has
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
  printf '\n-- the checkout these bytes come from --\n'
  checkout_is_current; _cur=$?
  [ "$_cur" -eq 0 ] && echo "  ok      this checkout is level with origin/main"
  if [ "$MODE" = --apply ] && [ "$_cur" -ne 0 ]; then
    echo
    echo "== NOTHING INSTALLED. --check is honest about what it would do; --apply refuses to write bytes it cannot vouch for. =="
    exit 1
  fi
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
