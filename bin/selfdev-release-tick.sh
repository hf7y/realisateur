#!/usr/bin/env bash
# selfdev-release-tick.sh -- the clock on the consumer side of the release
# channel, and the alarm that fires when the clock stops.
#
# ============================================================================
# WHY THIS EXISTS, AND WHY IT IS SO SMALL
# ============================================================================
#
# The release channel was already built. `cut-verb-build.sh` assembles every
# project's verbs into a dated build in `hf7y/verbs`; `build-verbs.yml` cuts
# one nightly; `install-verb-build.sh` fetches a build by id, verifies every
# verb the manifest promises, and repoints ONE symlink atomically or discards
# the build entirely. All of it works, and all of it is tested (31 + 17 cases
# across two hermetic suites).
#
# Probed 2026-08-07: builds had been cut nightly since 2026-08-05 and
# `~/.local/share/verb-builds/` did not exist on a single one of the ten
# accounts on `monkey`. Zero consumers. Meanwhile every account's realisateur
# clone sat 15 commits behind `origin/main` and ten ecosystem commands on
# every account's PATH exec'd into it, successfully and silently.
#
# Nothing was broken. Nothing had a clock.
#
# So this script adds the clock and NOTHING ELSE. It does not fetch a build,
# does not verify a manifest, does not move `current`. It calls
# `install-verb-build.sh`, which does all three and has been tested doing
# them. A second implementation of the switch would be a second answer to
# "which build am I on", which is the one question a bug report must be able
# to answer -- and rewriting a tested atomic-switch by hand is how the
# 2026-07-29 dispatch outage happened.
#
# `bin/tests/propagation.test.sh` asserts the delegation mechanically: this
# file must contain no symlink-switching of its own.
#
# ============================================================================
# PULL, NOT PUSH -- this runs AS THE ACCOUNT, FROM THE ACCOUNT'S OWN CRONTAB
# ============================================================================
#
# No ssh. No sudo. No hands account reaching into a 0700 home. The account
# owns its clock, checks its own pin, and adopts on its own terms. That is
# what lets it VERIFY BEFORE ADOPTING, and it is what leaves the record where
# the consumer is rather than in someone else's shell history.
#
# `--survey` is the one read-only operator view, and it is read-only by
# construction: it runs `--check` on each account and writes nothing anywhere.
#
# ============================================================================
# FAIL-OPEN ON OPERATION, FAIL-CLOSED ON ADOPTION
# ============================================================================
#
# These are different questions and they get different answers.
#
# ADOPTION is fail-closed, and it already is: `install-verb-build.sh` verifies
# every verb the manifest promises, and a build missing any of them is
# `rm -rf`'d with `current` unchanged. Half-adopting a verb set is the one
# failure with no local recovery -- scheduler's 2026-07-29 TOTAL dispatch
# outage was ONE missing symlink that no check on the machine could say
# should have existed.
#
# OPERATION is fail-open: an unreachable release channel does NOT stop the
# account. It keeps running the build it already has, which was fully verified
# when it was installed, and this tick exits 3 BLIND and says so. BUILD-
# DISCIPLINE's first rule is "fail LOUD", not "fail STOPPED": a hard refusal
# that silently halts a nightly tick is just a different silent failure, and
# it converts a network blip into an outage. A verified-but-older build
# running is a known, named, rollback-able state. Exit 3 and a status line are
# the loudness; halting would buy nothing and cost a night's work.
#
# The one place refusal IS correct is a compatibility-boundary crossing, and
# today that boundary is the manifest: `cut-verb-build.sh` refuses a build
# that SHRINKS without --allow-shrink, so the verb NAME SET -- the interface
# agents build against -- cannot silently narrow underneath them. A build
# whose verb SEMANTICS changed is not yet detectable by anything, and that is
# named as open rather than papered over.
#
# ============================================================================
# THE ALARM: A STOPPED CLOCK IS A FINDING
# ============================================================================
#
# Every mechanism here has been built before in some form, and the failure was
# never that it did the wrong thing -- it was that it stopped, and nothing
# said so. `land-selfdev.sh:175` already fast-forwards every clone; it could
# be un-run forever and nothing anywhere was observably worse off.
#
# So --apply records itself, and --check GRADES THAT RECORD'S AGE as a
# first-class row, offline, with no network and no ssh. A propagation that
# has not run in TICK_MAX_AGE_H hours is a finding with an exit code. The
# checker detects that the fixer died.
#
# ============================================================================
# EXIT CODES
#   0  on the current build, and the clock is alive
#   1  findings: a newer build exists, the clock is dead, or the bootstrap is
#      incomplete. Something a human or the next tick must act on.
#   2  usage error (cli-guard)
#   3  BLIND -- could not reach the release channel, or could not look at all.
#      NOT "up to date". The `garde` shape from MONKEY.md 5, where skipping
#      unreachable destinations made "nothing pending" indistinguishable from
#      "everything is proven".
# ============================================================================
set -uo pipefail

CLI_NAME='selfdev-release-tick.sh'
CLI_SUMMARY='the consumer-side clock for the verb release channel, and the alarm when it stops'
CLI_USAGE='  selfdev-release-tick.sh                  --check (default): pin vs latest, and is the clock alive
  selfdev-release-tick.sh --apply          adopt the newest build (delegates to install-verb-build.sh)
  selfdev-release-tick.sh --install-cadence  print (with --apply, install) THIS ACCOUNT'"'"'s cron entry
  selfdev-release-tick.sh --survey         read-only fleet view: every account'"'"'s pin vs latest'
CLI_FLAGS='--check --apply --install-cadence --survey'
CLI_POSITIONAL=none
CLI_EXITS='  0  on the current build and the clock is alive
  1  findings: a newer build exists, the clock is dead, or bootstrap incomplete
  3  BLIND: could not reach the release channel. This is not "up to date".'
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

# The support library sits beside this script in the bootstrap, and beside it
# in the repo. Both layouts are the same relative path, on purpose.
. "$(dirname "${BASH_SOURCE[0]}")/lib/propagation-set.sh"

# --- knobs. Every one exists so bin/tests/propagation.test.sh can run against
# fixture homes with no network, no ssh and no sudo. Same reasoning as
# install-verbs.sh's INSTALLE_*: without the override a test silently audits
# the live estate and cannot tell its own passing from the estate's health.
STATE="${TICK_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}}"
STATUS_FILE="$STATE/selfdev-release-tick.status"
MAX_AGE_H="${TICK_MAX_AGE_H:-26}"
BUILD_ROOT="${VERB_BUILD_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/verb-builds}"
INSTALLER="${TICK_INSTALLER:-}"
CRON_TAG='# realisateur:selfdev-release:TICK'
CRON_SPEC="${TICK_CRON_SPEC:-41 5 * * *}"
SURVEY_HOST="${TICK_SURVEY_HOST:-monkey}"
SURVEY_PASSWD="${TICK_SURVEY_PASSWD:-/etc/passwd}"
UID_MIN="${TICK_UID_MIN:-3000}"
UID_MAX="${TICK_UID_MAX:-3099}"

MODE=check; CADENCE=0; SURVEY=0
for a in "$@"; do
  case "$a" in
    --check) MODE=check ;;
    --apply) MODE=apply ;;
    --install-cadence) CADENCE=1 ;;
    --survey) SURVEY=1 ;;
  esac
done

PASS=0; GAPS=0; BAD=0
ok()  { printf '  ok    %s\n' "$*"; PASS=$((PASS+1)); }
gap() { printf '  gap   %s\n' "$*"; GAPS=$((GAPS+1)); }
bad() { printf '  bad   %s\n' "$*"; BAD=$((BAD+1)); }
act() { printf '  ..    %s\n' "$*"; }

# ---------------------------------------------------------------------------
# Locate the installer. Beside this script first (the bootstrap layout on a
# consumer), then in a realisateur checkout (the dev layout). NOT derived from
# PATH: a shim on PATH may exec into a clone, and resolving the installer
# through the very channel we are trying to stop depending on is the circular
# dependency this whole design exists to cut.
# ---------------------------------------------------------------------------
find_installer() {
  # An override that names a path which is not there is a MISSING installer,
  # not an installer. Returning it anyway would make "bootstrap incomplete"
  # surface later as an opaque rc=127 from a command that does not exist.
  [ -n "$INSTALLER" ] && { [ -x "$INSTALLER" ] || return 1; printf '%s' "$INSTALLER"; return 0; }
  local here; here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local c
  for c in "$here/install-verb-build.sh" \
           "$HOME/Documents/Projects/realisateur/bin/install-verb-build.sh"; do
    [ -x "$c" ] && { printf '%s' "$c"; return 0; }
  done
  return 1
}

current_pin() { readlink "$BUILD_ROOT/current" 2>/dev/null | xargs -r basename 2>/dev/null; }

record_status() { # record_status <rc> <summary>
  mkdir -p "$STATE" 2>/dev/null || return 0
  local pin; pin="$(current_pin)"
  printf '%s rc=%s pin=%s %s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "${pin:-none}" "$2" >> "$STATUS_FILE"
}

# ---------------------------------------------------------------------------
# The clock row. Graded FIRST because it is the only row checkable with no
# network at all -- and because a dead clock makes every row after it a
# statement about the past rather than the present.
# ---------------------------------------------------------------------------
check_clock() {
  if [ ! -f "$STATUS_FILE" ]; then
    gap "NO CLOCK -- this account has never recorded a release tick ($STATUS_FILE absent). Install it: $0 --install-cadence --apply"
    return 0
  fi
  local mt now age_h line
  mt="$(stat -c %Y "$STATUS_FILE" 2>/dev/null || echo 0)"
  now="$(date +%s)"
  age_h=$(( (now - mt) / 3600 ))
  line="$(tail -1 "$STATUS_FILE" 2>/dev/null)"
  if [ "$age_h" -gt "$MAX_AGE_H" ]; then
    bad "CLOCK DEAD -- last release tick ${age_h}h ago (limit ${MAX_AGE_H}h). Propagation stopped and nothing else would have said so. Last line: $line"
  else
    ok "clock alive -- last tick ${age_h}h ago: $line"
  fi
}

# ---------------------------------------------------------------------------
# The pin row. Delegates entirely: install-verb-build.sh --check already
# prints "yours:" / "latest:" and distinguishes exit 1 (newer exists) from
# exit 3 (BLIND). Reimplementing that comparison here would be a second source
# of truth about which build is current.
# ---------------------------------------------------------------------------
check_pin() {
  local inst out rc
  if ! inst="$(find_installer)"; then
    # Deliberately NOT 3. BLIND means "we could not look at the channel";
    # this means we looked at ourselves and the bootstrap is not here. A
    # definite local finding must not borrow the vocabulary of an
    # indeterminate remote one.
    bad "BOOTSTRAP INCOMPLETE -- install-verb-build.sh is not beside this script and there is no realisateur checkout. This account cannot obtain a build at all."
    return 4
  fi
  out="$("$inst" --check 2>&1)"; rc=$?
  printf '%s\n' "$out" | sed 's/^/        /'
  case "$rc" in
    0) ok "pin current: $(current_pin)" ;;
    1) gap "a newer build exists -- this account is on $(current_pin || echo '<none>'). Adopt: $0 --apply" ;;
    3) bad "BLIND -- could not reach the release channel. The account keeps running its pinned build (fail-open on operation); nothing was verified." ;;
    *) bad "install-verb-build.sh --check exited $rc, which is not a verdict this script knows how to read" ;;
  esac
  return "$rc"
}

# ---------------------------------------------------------------------------
# The cron entry. ONE line, in THIS account's own crontab, installed by this
# account. No sudo, no ssh, no cross-account write.
# ---------------------------------------------------------------------------
install_cadence() {
  local self line
  self="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  line="$CRON_SPEC $self --apply $CRON_TAG"
  echo "-- cadence entry (account $(id -un)) ----------------------------------"
  printf '  %s\n' "$line"
  if [ "$MODE" != apply ]; then
    act "not installed (--check). Re-run with --apply."
    return 0
  fi
  local cur new
  cur="$(crontab -l 2>/dev/null || true)"
  new="$(printf '%s\n' "$cur" | grep -vF "$CRON_TAG")"
  printf '%s\n%s\n' "$new" "$line" | grep -v '^[[:space:]]*$' | crontab -
  # WITNESS: read it back out of cron, not out of the variable just written.
  # "crontab - exited 0" is not evidence that the line is scheduled.
  if crontab -l 2>/dev/null | grep -qF "$CRON_TAG"; then
    ok "cadence installed in $(id -un)'s crontab, verified by re-reading crontab -l"
    act "machine-wide config changed. Run: notify-senechal 'realisateur selfdev-release-tick cron in $(id -un)@$(hostname -s) crontab, owned by realisateur'"
  else
    bad "crontab accepted the write but the entry is absent on re-read"
  fi
}

# ---------------------------------------------------------------------------
# --survey: the read-only operator view. It does not write, does not adopt,
# and does not need the accounts to trust it -- it runs each account's own
# --check. Reporting from a hands account is fine; PROPAGATING from one is
# what this design rejects.
# ---------------------------------------------------------------------------
run_survey() {
  echo "-- fleet survey: $SURVEY_HOST (read-only) -----------------------------"
  local found=0
  local out
  out="$(ssh -o BatchMode=yes -o ConnectTimeout=15 "$SURVEY_HOST" "bash -s" <<EOF
set -uo pipefail
while IFS=: read -r user _ uid _ _ home _; do
  [ "\$uid" -ge $UID_MIN ] 2>/dev/null || continue
  [ "\$uid" -le $UID_MAX ] || continue
  pin=\$(sudo -u "\$user" readlink "\$home/$PROP_PIN_PATH" 2>/dev/null | xargs -r basename 2>/dev/null)
  clk=\$(sudo -u "\$user" stat -c %Y "\$home/.local/state/selfdev-release-tick.status" 2>/dev/null || echo 0)
  cron=none
  sudo -u "\$user" crontab -l 2>/dev/null | grep -q 'selfdev-release:TICK' && cron=armed
  echo "\$user \${pin:-NONE} \$clk \$cron"
done < $SURVEY_PASSWD
EOF
)"
  local rc=$?
  if [ "$rc" != 0 ] || [ -z "$out" ]; then
    echo
    echo "BLIND: could not survey $SURVEY_HOST (ssh rc=$rc). Nothing was verified." >&2
    return 3
  fi
  printf '  %-16s %-26s %-8s %s\n' ACCOUNT PIN CLOCK CRON
  local now; now="$(date +%s)"
  while read -r user pin clk cron; do
    found=1
    local age='never'
    [ "${clk:-0}" -gt 0 ] 2>/dev/null && age="$(( (now - clk) / 3600 ))h"
    printf '  %-16s %-26s %-8s %s\n' "$user" "$pin" "$age" "$cron"
    if [ "$pin" = NONE ]; then
      gap "$user: no build adopted -- the release channel has no consumer here"
    elif [ "$cron" != armed ]; then
      gap "$user: on build $pin but NO CLOCK -- it will never advance"
    else
      ok "$user: $pin, clock $age"
    fi
  done <<<"$out"
  [ "$found" = 1 ] || { echo; echo "BLIND: no project accounts (uid $UID_MIN-$UID_MAX) on $SURVEY_HOST." >&2; return 3; }
  return 0
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
echo "== selfdev-release-tick ($MODE) -- $(id -un)@$(hostname -s 2>/dev/null || echo '?') =="
echo

if [ "$SURVEY" = 1 ]; then
  run_survey; srv=$?
  echo
  printf '%d ok, %d gap, %d bad\n' "$PASS" "$GAPS" "$BAD"
  [ "$srv" = 3 ] && exit 3
  [ "$GAPS" -eq 0 ] && [ "$BAD" -eq 0 ] || exit 1
  exit 0
fi

if [ "$CADENCE" = 1 ]; then
  install_cadence
  echo
  printf '%d ok, %d gap, %d bad\n' "$PASS" "$GAPS" "$BAD"
  [ "$BAD" -eq 0 ] || exit 1
  exit 0
fi

echo "-- clock --------------------------------------------------------------"
check_clock

echo
echo "-- pin vs release channel ---------------------------------------------"
check_pin; pin_rc=$?

if [ "$MODE" = apply ] && [ "$pin_rc" = 1 ]; then
  echo
  echo "-- adopting -----------------------------------------------------------"
  inst="$(find_installer)"
  # DELEGATED. This script has no switching logic: install-verb-build.sh
  # verifies every verb the manifest promises and discards an incomplete
  # build rather than switching to it. Fail-CLOSED, here, deliberately.
  if "$inst" --latest --apply 2>&1 | sed 's/^/        /'; then
    after="$(current_pin)"
    ok "adopted build $after (pin re-read after the switch, not inferred from an exit code)"
    GAPS=$((GAPS-1))
  else
    bad "adoption refused or failed -- current is unchanged. The account is still on $(current_pin || echo '<none>'), which is a known verified state."
  fi
fi

echo
summary="$(printf '%d ok, %d gap, %d bad' "$PASS" "$GAPS" "$BAD")"
echo "$summary"

rc=0
[ "$GAPS" -eq 0 ] && [ "$BAD" -eq 0 ] || rc=1
# BLIND outranks findings: "a newer build may exist, we could not look" must
# never be reported with the same code as "a newer build exists".
[ "$pin_rc" = 3 ] && rc=3

[ "$MODE" = apply ] && { record_status "$rc" "$summary"; echo "recorded: $STATUS_FILE"; }

case "$rc" in
  0) ;;
  3) echo; echo "BLIND: the release channel could not be reached. This is not 'up to date'." >&2 ;;
  *) echo; echo "NOT ON THE CURRENT RELEASE, or the clock has stopped. Rows above say which." >&2 ;;
esac
exit "$rc"
