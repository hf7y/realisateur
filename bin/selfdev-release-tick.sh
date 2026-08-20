#!/usr/bin/env bash
# selfdev-release-tick.sh -- the clock on the consumer side of the release
# channel, and the alarm that fires when the clock stops.
#
# TRAPS (the rest of this header is in the vault):
# Probed 2026-08-07: builds had been cut nightly since 2026-08-05 and
# `~/.local/share/verb-builds/` did not exist on a single one of the ten
# accounts on `monkey`. Zero consumers. Meanwhile every account's realisateur
# clone sat 15 commits behind `origin/main` and ten ecosystem commands on
# every account's PATH exec'd into it, successfully and silently.
# OPERATION is fail-open: an unreachable release channel does NOT stop the
# account. It keeps running the build it already has, which was fully verified
# when it was installed, and this tick exits 3 BLIND and says so. BUILD-
# DISCIPLINE's first rule is "fail LOUD", not "fail STOPPED": a hard refusal
# that silently halts a nightly tick is just a different silent failure, and
# it converts a network blip into an outage. A verified-but-older build
# running is a known, named, rollback-able state. Exit 3 and a status line are
# the loudness; halting would buy nothing and cost a night's work.
#
# EXIT CODES

set -uo pipefail

CLI_NAME='selfdev-release-tick.sh'
CLI_SUMMARY='the consumer-side clock for the verb release channel, and the alarm when it stops'
CLI_USAGE='  selfdev-release-tick.sh                  --check (default): pin vs latest, and is the clock alive
  selfdev-release-tick.sh --apply          adopt the newest build (delegates to install-verb-build.sh)
  selfdev-release-tick.sh --install-cadence  print (with --apply, install) THIS ACCOUNT'"'"'s cron entry
  selfdev-release-tick.sh --retire-cadence   print (with --apply, remove) THIS ACCOUNT'"'"'s cron entry and private pin, once the host-wide channel resolves
  selfdev-release-tick.sh --survey         read-only fleet view: every account'"'"'s pin vs latest'
CLI_FLAGS='--check --apply --install-cadence --retire-cadence --survey'
CLI_POSITIONAL=none
CLI_EXITS='  0  on the current build and the clock is alive
  1  findings: a newer build exists, the clock is dead, or bootstrap incomplete
  3  BLIND: could not reach the release channel. This is not "up to date".'
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

# The support library sits beside this script in the bootstrap, and beside it
# in the repo. Both layouts are the same relative path, on purpose.
. "$(dirname "${BASH_SOURCE[0]}")/lib/propagation-set.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib/host-check.sh"

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
# Environment the cron line carries, in `VAR=val` form, ahead of the command.
# Empty for a per-account tick: its defaults ARE the account's own paths.
#
# The host-scoped tick needs it, because every path it works on is deliberately
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
CRON_ENV="${TICK_CRON_ENV:-}"
RELEASE_STATUS_URL="${RELEASE_STATUS_URL:-https://hf7y.com/verbs/status.json}"
# Whether adoption also writes the bin links. OFF by default and it stays off
# for a per-ACCOUNT tick, because `installe` owns that account's ~/.local/bin
# and install-verb-build.sh's --link exists to not clobber it.
#
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
TICK_LINK="${TICK_LINK:-0}"
SURVEY_HOST="${TICK_SURVEY_HOST:-monkey}"
SURVEY_PASSWD="${TICK_SURVEY_PASSWD:-/etc/passwd}"
UID_MIN="${TICK_UID_MIN:-3000}"
UID_MAX="${TICK_UID_MAX:-3099}"

# The host-wide link directory a retired account must resolve verbs from.
# Overridable so bin/tests/propagation.test.sh can point it at a fixture.
HOST_BIN="${TICK_HOST_BIN:-/usr/local/bin}"
# The verb this account is asked to resolve as proof the host channel reaches
# it. One real verb, looked up the way a non-interactive `ssh <host> <verb>`
# would, beats inferring reachability from the host's own /usr/local/bin.
HOST_PROBE_VERB="${TICK_HOST_PROBE_VERB:-dose}"
# This account's own bin directory -- the one whose entries shadow $HOST_BIN.
LOCAL_BIN="${TICK_LOCAL_BIN:-$HOME/.local/bin}"

MODE=check; CADENCE=0; RETIRE=0; SURVEY=0
for a in "$@"; do
  case "$a" in
    --check) MODE=check ;;
    --apply) MODE=apply ;;
    --install-cadence) CADENCE=1 ;;
    --retire-cadence) RETIRE=1 ;;
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
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
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
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
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
  line="$CRON_SPEC ${CRON_ENV:+$CRON_ENV }$self --apply $CRON_TAG"
  echo "-- cadence entry (account $(id -un)) ----------------------------------"
  printf '  %s\n' "$line"
  if [ "$MODE" != apply ]; then
    act "not installed (--check). Re-run with --apply."
    return 0
  fi
  local cur new back
  # stderr KEPT, merged into stdout, rather than sent to /dev/null. An empty
  # crontab writes "no crontab for <user>" there and exits 1 -- that is the
  # answer, not an error -- but so does a permission failure, and silencing
  # both makes them one event. That conflation is bin/silence-audit.sh's
  #   [rest: vault:realisateur/guard-archaeology-20260817.md]
  cur="$(crontab -l 2>&1 || true)"
  case "$cur" in *"no crontab for"*) cur="" ;; esac
  new="$(printf '%s\n' "$cur" | grep -vF "$CRON_TAG")"
  printf '%s\n%s\n' "$new" "$line" | grep -v '^[[:space:]]*$' | crontab -
  # WITNESS: read it back out of cron, not out of the variable just written.
  # "crontab - exited 0" is not evidence that the line is scheduled.
  back="$(crontab -l 2>&1)"
  if printf '%s\n' "$back" | grep -qF "$CRON_TAG"; then
    ok "cadence installed in $(id -un)'s crontab, verified by re-reading crontab -l"
    act "machine-wide config changed. Run: notify-senechal 'realisateur selfdev-release-tick cron in $(id -un)@$(hostname -s) crontab, owned by realisateur'"
  else
    bad "crontab accepted the write but the entry is absent on re-read. crontab -l said: $(printf '%s' "$back" | head -3 | tr '\n' ' ')"
  fi
}

# ---------------------------------------------------------------------------
# The other half of install_cadence: hf7y/realisateur#180 retires the
# per-account clock and private build root now that one host-wide channel
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
retire_cadence() {
  echo "-- retire cadence (account $(id -un)) ---------------------------------"
  local probe; probe="$(command -v "$HOST_PROBE_VERB" 2>/dev/null || true)"
  case "$probe" in
    "$HOST_BIN"/*)
      ok "$HOST_PROBE_VERB resolves to $probe -- the host-wide channel reaches this account" ;;
    *)
      bad "refusing to retire: '$HOST_PROBE_VERB' resolves to ${probe:-nothing}, not $HOST_BIN/$HOST_PROBE_VERB. Retiring here would leave the account with no clock AND no verbs."
      return ;;
  esac

  # "Already retired" must account for the shims too. A hand retire that
  # removed the build root and left $HOME/.local/bin pointing into it looks
  # finished by every other measure -- that is the realisateur account on
  # 2026-08-13, 33 dangling links reported as done.
  local shims=0 s
  if [ -d "$LOCAL_BIN" ]; then
    for s in "$LOCAL_BIN"/*; do
      [ -L "$s" ] || continue
      case "$(readlink "$s")" in "$BUILD_ROOT"/*) shims=$((shims+1)) ;; esac
    done
  fi
  if ! crontab -l 2>/dev/null | grep -qF "$CRON_TAG" && [ ! -d "$BUILD_ROOT" ] && [ "$shims" = 0 ]; then
    ok "already retired: no $CRON_TAG line, no private build root at $BUILD_ROOT, no shim pointing into it"
    return
  fi

  if [ "$MODE" != apply ]; then
    act "would remove the $CRON_TAG line from $(id -un)'s crontab"
    act "would retire $shims shim(s) in $LOCAL_BIN pointing into that root"
    act "would remove the private build root $BUILD_ROOT (pin $(current_pin || echo '<none>'))"
    act "not removed (--check). Re-run with --apply."
    return
  fi

  # Same stderr discipline as install_cadence: `cur` is what gets written
  # BACK, so reading an unreadable crontab as empty would erase every other
  # entry in it.
  local cur new back
  cur="$(crontab -l 2>&1 || true)"
  case "$cur" in *"no crontab for"*) cur="" ;; esac
  if printf '%s\n' "$cur" | grep -qF "$CRON_TAG"; then
    new="$(printf '%s\n' "$cur" | grep -vF "$CRON_TAG")"
    printf '%s\n' "$new" | grep -v '^[[:space:]]*$' | crontab -
    # WITNESS: read it back out of cron, not out of the variable just written.
    back="$(crontab -l 2>&1)"
    if printf '%s\n' "$back" | grep -qF "$CRON_TAG"; then
      bad "crontab accepted the write but the $CRON_TAG line is STILL there on re-read"
      return
    fi
    ok "cadence removed from $(id -un)'s crontab, verified by re-reading crontab -l"
    act "machine-wide config changed. Run: notify-senechal 'realisateur selfdev-release-tick cron REMOVED from $(id -un)@$(hostname -s) crontab; that account now follows the host-wide channel in $HOST_BIN'"
  fi

  # The shims that point INTO the build root go before the root itself.
  # Removing the root first leaves a $HOME/.local/bin full of dangling links
  # -- 33 of them on the realisateur account on 2026-08-13, from the hand
  #   [rest: vault:realisateur/guard-archaeology-20260817.md]
  local shim tgt inst
  inst="$(command -v installe 2>/dev/null || true)"
  if [ -d "$LOCAL_BIN" ]; then
    for shim in "$LOCAL_BIN"/*; do
      [ -L "$shim" ] || continue
      tgt="$(readlink "$shim")"
      case "$tgt" in "$BUILD_ROOT"/*) ;; *) continue ;; esac
      if [ -n "$inst" ] && "$inst" retire "$(basename "$shim")" >/dev/null 2>&1 && [ ! -e "$shim" ] && [ ! -L "$shim" ]; then
        ok "shim $(basename "$shim") retired through installe (its target was not touched)"
      else
        rm -f "$shim"
        [ -L "$shim" ] && bad "shim $(basename "$shim") survived removal" \
                       || ok "shim $(basename "$shim") unlinked directly (installe was not reachable to do it)"
      fi
    done
  fi

  # The private pin goes only after the clock and the shims, and only if it is
  # under $HOME. A BUILD_ROOT pointed elsewhere is the HOST-scoped tick's own
  # root, and this path must never delete that.
  if [ -d "$BUILD_ROOT" ]; then
    case "$BUILD_ROOT" in
      "$HOME"/*)
        rm -rf "$BUILD_ROOT"
        if [ -d "$BUILD_ROOT" ]; then bad "private build root $BUILD_ROOT survived removal"
        else ok "private build root $BUILD_ROOT removed (verbs now resolve from $HOST_BIN)"; fi ;;
      *)
        bad "refusing to remove $BUILD_ROOT -- it is not under \$HOME, so it is not this account's private pin" ;;
    esac
  fi
}

# ---------------------------------------------------------------------------
# --survey: the read-only operator view. It does not write, does not adopt,
# and does not need the accounts to trust it -- it runs each account's own
#   [rest: vault:realisateur/guard-archaeology-20260817.md]

survey_scan_accounts() {
  while IFS=: read -r user _ uid _ _ home _; do
    [ "$uid" -ge "$UID_MIN" ] 2>/dev/null || continue
    [ "$uid" -le "$UID_MAX" ] || continue
    pin=$(sudo -u "$user" readlink "$home/$PROP_PIN_PATH" 2>/dev/null | xargs -r basename 2>/dev/null)
    clk=$(sudo -u "$user" stat -c %Y "$home/.local/state/selfdev-release-tick.status" 2>/dev/null || echo 0)
    cron=none
    sudo -u "$user" crontab -l 2>/dev/null | grep -q 'selfdev-release:TICK' && cron=armed
    # Does this account resolve the host-wide channel? Asked AS THE ACCOUNT,
    # because a $HOME/.local/bin entry earlier on its PATH shadows the host
    # directory, and the host's own view cannot see that.
    host=no
    sudo -u "$user" -H sh -c "command -v $HOST_PROBE_VERB" 2>/dev/null | grep -q "^$HOST_BIN/" && host=yes
    echo "$user ${pin:-NONE} $clk $cron $host"
  done < "$SURVEY_PASSWD"
}

run_survey() {
  echo "-- fleet survey: $SURVEY_HOST (read-only) -----------------------------"
  local found=0
  local out rc local_scan=0
  if on_target_host "$SURVEY_HOST"; then
    local_scan=1
    out="$(survey_scan_accounts)"; rc=$?
  else
    out="$(ssh -o BatchMode=yes -o ConnectTimeout=15 "$SURVEY_HOST" \
      "UID_MIN=$UID_MIN UID_MAX=$UID_MAX PROP_PIN_PATH='$PROP_PIN_PATH' HOST_PROBE_VERB='$HOST_PROBE_VERB' HOST_BIN='$HOST_BIN' SURVEY_PASSWD='$SURVEY_PASSWD' bash -s" <<EOF
set -uo pipefail
$(declare -f survey_scan_accounts)
survey_scan_accounts
EOF
)"
    rc=$?
  fi
  if [ "$rc" != 0 ] || [ -z "$out" ]; then
    echo
    if [ "$local_scan" = 1 ]; then
      echo "BLIND: could not scan $SURVEY_HOST locally (rc=$rc). Nothing was verified." >&2
    else
      echo "BLIND: could not survey $SURVEY_HOST (ssh rc=$rc). Nothing was verified." >&2
    fi
    return 3
  fi
  printf '  %-16s %-26s %-8s %-6s %s\n' ACCOUNT PIN CLOCK CRON CHANNEL
  local now; now="$(date +%s)"
  while read -r user pin clk cron host; do
    found=1
    local age='never'
    [ "${clk:-0}" -gt 0 ] 2>/dev/null && age="$(( (now - clk) / 3600 ))h"
    printf '  %-16s %-26s %-8s %-6s %s\n' "$user" "$pin" "$age" "$cron" \
           "$([ "${host:-no}" = yes ] && echo host-wide || echo private)"
    # THREE STATES, and the middle one is the point. Before hf7y/realisateur#180
    # a missing private pin meant the channel had no consumer here. AFTER it,
    # it is the FINISHED state, and grading it as a gap makes this view report
    #   [rest: vault:realisateur/guard-archaeology-20260817.md]
    if [ "${host:-no}" = yes ] && [ "$pin" = NONE ]; then
      ok "$user: follows the host-wide channel ($HOST_BIN); no private pin or clock to keep"
    elif [ "$pin" = NONE ]; then
      gap "$user: no build adopted AND $HOST_PROBE_VERB does not resolve from $HOST_BIN -- this account has no verbs"
    elif [ "$cron" != armed ]; then
      gap "$user: on private build $pin but NO CLOCK -- it will never advance. Retire it (--retire-cadence) or arm it (--install-cadence)."
    else
      ok "$user: private pin $pin, clock $age (pre-#180 shape; --retire-cadence moves it to $HOST_BIN)"
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

if [ "$CADENCE" = 1 ] && [ "$RETIRE" = 1 ]; then
  echo "--install-cadence and --retire-cadence are opposites; pick one." >&2
  exit 2
fi

if [ "$RETIRE" = 1 ]; then
  retire_cadence
  echo
  printf '%d ok, %d gap, %d bad\n' "$PASS" "$GAPS" "$BAD"
  [ "$BAD" -eq 0 ] || exit 1
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

# --- the CHANNEL's own health, read live from the published verdict ---------
# This is the row that separates "no new build because nothing changed" from
# "no new build because main is broken". Without it both are just an absence,
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
echo
echo "-- release channel (live) ---------------------------------------------"
led="$(dirname "${BASH_SOURCE[0]}")/release-ledger.sh"
if [ -x "$led" ]; then
  ch_out="$("$led" --url "$RELEASE_STATUS_URL" 2>&1)"; ch_rc=$?
  printf '%s\n' "$ch_out" | sed 's/^/        /'
  case "$ch_rc" in
    0) ok "release channel healthy (verdict fresh, no blocked streak)" ;;
    3) bad "release channel BLIND -- $RELEASE_STATUS_URL unreachable. Not 'healthy'." ;;
    *) bad "release channel UNHEALTHY -- the emitter is silent or the pipeline is blocked. Rows above say which; this is why no new build has appeared." ;;
  esac
else
  bad "release-ledger.sh is not beside this script -- the channel's own health is UNGRADED, so an absent build cannot be explained"
fi

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
  # The optional flag is an ARRAY appended after the literal call, not folded
  #   [rest: vault:realisateur/guard-archaeology-20260817.md]
  link_arg=(); [ "$TICK_LINK" = 1 ] && link_arg=(--link)
  if "$inst" --latest --apply "${link_arg[@]}" 2>&1 | sed 's/^/        /'; then
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
