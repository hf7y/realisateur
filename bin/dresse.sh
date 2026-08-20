#!/usr/bin/env bash
# dresse.sh -- stand a self-dev host, or one account on it, UP. The one command
# Zach types; the sixteen hand-run scripts stay, and this is their front door.
#
# KIND: verb
#
# Zach, 2026-08-19: "There should be a verb that does whatever that realisateur
# agent would do, agentless, simple enough for Zach to type." (#435; the name
# was left to this implementation -- "I don't care. You decide.")
#
# WHO RUNS IT: a human with sudo, ON the host being provisioned. NO self-dev
# account gets sudo, now or later. If a step here seems to need an account to
# have it, the step is wrong.
#
# TRAP: the step plan is CHECKED against bin/lib/propagation-set.sh, never
#   invented beside it. Every script a step runs must be provision-class there,
#   and every provision-class script this does NOT reach is PRINTED as
#   uncovered. A front door that quietly covers eleven of sixteen reads exactly
#   like one that covers sixteen.
#
# TRAP: it installs no secret unattended. selfdev-claude-token.sh --install
#   takes a file a human supplies, so --apply reports the gap and the command
#   rather than inventing a value. A trailing space in a pasted token took the
#   fleet down on 2026-08-19.
#
set -uo pipefail

CLI_NAME='dresse'
CLI_SUMMARY='stand a self-dev host or account up: run every provisioning step, in order, idempotently'
CLI_USAGE='  dresse --host [--check|--apply]      the machine: App key, token, release channel, fleet blocks
  dresse --all [--check|--apply]       every account in the self-dev uid band
  dresse <account> [--check|--apply]   one account, standing it up if it does not exist'
CLI_FLAGS='--host --all --check --apply'
CLI_POSITIONAL='<account>, or --all, or --host'
CLI_EXITS='  0  every step ran (or, under --check, could)
  1  at least one step refused
  2  usage error
  6  BLIND -- the propagation set could not be read, so the plan is unverifiable'
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
if [ $(( ALL + HOSTWIDE + (${#ACCT} > 0 ? 1 : 0) )) -gt 1 ]; then
  echo "$CLI_NAME: --host, --all and a named account are mutually exclusive -- say which" >&2; exit 2
fi

# shellcheck source=lib/propagation-set.sh
. "$HERE/lib/propagation-set.sh" 2>/dev/null || {
  echo "$CLI_NAME: BLIND -- cannot read $HERE/lib/propagation-set.sh; the plan cannot be checked" >&2; exit 6; }
[ -n "${PROP_PROVISION_SCRIPTS:-}" ] || {
  echo "$CLI_NAME: BLIND -- propagation-set.sh declares no provisioning set" >&2; exit 6; }

# --- THE PLAN. One row per step: scope|script|check args|apply args|what ------
# Kept in run order. A row's script must be provision-class; see plan_check.
HOST_STEPS="
selfdev-app-key.sh|--check|--apply|the GitHub App key, host-wide, group-readable by the uid band
selfdev-claude-token.sh|--check|--check|the shared OAuth token (--install takes a file a human supplies)
wire-release-channel.sh|--host --check|--host --apply|the verb-build channel: bootstrap, pin, links, root's clock
selfdev-permissions-provision.sh||--apply|the .claude permissions block on every account
selfdev-hooks-provision.sh||--apply|the SubagentStop hook on every account
"
# An account that does not exist yet: setup-selfdev-project.sh is itself the
# ordered sequence (account, keys, git, land, App key, channel, permissions,
# hooks), so this does not restate it. One that does exist only needs the
# channel re-checked; the two fleet-wide blocks above already reach it.
ACCT_NEW_STEP="setup-selfdev-project.sh"
ACCT_STEPS="
wire-release-channel.sh|--check|--apply|the verb-build bootstrap and this account's own clock
"

pass_n=0; fail_n=0; gap_n=0
run_step() { # run_step <script> <args...>
  local s="$1"; shift
  local p="$HERE/$s"
  if [ ! -x "$p" ] && [ ! -f "$p" ]; then
    echo "  BAD     $s is not here -- the plan names a step this checkout does not have"
    fail_n=$((fail_n + 1)); return 1
  fi
  # shellcheck disable=SC2086
  bash "$p" $* 2>&1 | sed 's/^/     /'
  local rc=${PIPESTATUS[0]}
  # Under --check a nonzero exit is the step SAYING there is work to do; under
  # --apply the same code is a refusal. BLIND is never either -- it is a step
  # that could not look, and folding it into "gap" is the conflation this
  # estate keeps paying for.
  case "$rc" in
    0) echo "  OK      $s $*"; pass_n=$((pass_n + 1)) ;;
    6) echo "  BLIND   $s $* could not look (exit 6) -- not clean"; fail_n=$((fail_n + 1)) ;;
    *) if [ "$MODE" = --check ]; then
         echo "  GAP     $s $* reports work to do (exit $rc)"; gap_n=$((gap_n + 1))
       else
         echo "  BAD     $s $* exited $rc"; fail_n=$((fail_n + 1))
       fi ;;
  esac
  return 0
}

run_plan() { # run_plan <steps-block> <extra-arg-or-empty>
  local block="$1" extra="${2:-}" s ca aa what args
  while IFS='|' read -r s ca aa what; do
    [ -n "$s" ] || continue
    printf '\n  -- %s\n' "$what"
    if [ "$MODE" = --check ]; then args="$ca"; else args="$aa"; fi
    run_step "$s" ${extra:+$extra} $args
  done <<<"$block"
}

# COVERAGE. Names reached indirectly are declared here rather than assumed --
# setup-selfdev-project.sh runs them, and saying so is what keeps this list
# from becoming a second, quieter copy of the provisioning set.
VIA_SETUP="provision-selfdev-user.sh wire-selfdev-git.sh land-selfdev.sh install-verbs.sh install-shims.sh selfdev-app-key.sh selfdev-permissions-provision.sh selfdev-hooks-provision.sh wire-release-channel.sh"

plan_check() {
  local named s bad=0
  named="$(printf '%s\n%s\n%s\n' "$HOST_STEPS" "$ACCT_STEPS" "$ACCT_NEW_STEP" | cut -d'|' -f1 | grep -v '^$')"
  for s in $named; do
    if [ "$(prop_channel "$s" 2>/dev/null)" != provision ]; then
      echo "  BAD     $s is a step here but is not provision-class in propagation-set.sh"
      bad=1
    fi
  done
  for s in $PROP_PROVISION_SCRIPTS; do
    [ "$s" = dresse.sh ] && continue   # itself
    printf '%s\n' "$named" | grep -qx "$s" && continue
    case " $VIA_SETUP " in *" $s "*) continue ;; esac
    echo "  ..      not covered by $CLI_NAME: $s (still a hand-run script)"
  done
  return $bad
}

# ROOT is required to CHANGE the host, not to look at it. --check writes
# nothing, so it stays runnable by anyone -- and says which rows will refuse.
if [ "$MODE" = --apply ] && [ "$(id -u)" -ne 0 ]; then
  echo "$CLI_NAME: --apply must run as root (sudo $0 $*)" >&2; exit 2
fi

TARGET="$ACCT"; [ "$HOSTWIDE" -eq 1 ] && TARGET=--host; [ "$ALL" -eq 1 ] && TARGET=--all

echo "== $CLI_NAME ($MODE) on $HOST, uid band $UID_MIN-$UID_MAX =="
[ "$(id -u)" -eq 0 ] || echo "  ..      not root: root-only steps will refuse below; run --check under sudo for the full picture"
plan_check || exit 1

if [ "$HOSTWIDE" -eq 1 ]; then
  printf '\n-- %s (host-wide) --\n' "$HOST"
  run_plan "$HOST_STEPS"
else
  if [ "$ALL" -eq 1 ]; then
    ACCTS="$(getent passwd | awk -F: -v lo="$UID_MIN" -v hi="$UID_MAX" '$3>=lo && $3<=hi {print $1}' | sort)"
    # An empty band is a finding, not a clean run: it means this is not the
    # self-dev host, or the band moved.
    [ -n "$ACCTS" ] || { echo "$CLI_NAME: no accounts in uid band $UID_MIN-$UID_MAX on $HOST -- and that is a finding" >&2; exit 1; }
  else
    ACCTS="$ACCT"
  fi
  for acct in $ACCTS; do
    printf '\n-- %s --\n' "$acct"
    if [ -z "$(getent passwd "$acct" | cut -d: -f6)" ]; then
      printf '\n  -- the account itself, end to end\n'
      run_step "$ACCT_NEW_STEP" "$acct" "$MODE"
    else
      run_plan "$ACCT_STEPS" "$acct"
    fi
  done
fi

echo
if [ "$MODE" = --check ]; then
  echo "== nothing done (--check): $pass_n step(s) already satisfied, $gap_n with work to do, $fail_n blind. Next: sudo $CLI_NAME $TARGET --apply =="
else
  echo "== $pass_n step(s) ran, $fail_n refused =="
  [ "$fail_n" -eq 0 ] && echo "  DO      notify-senechal 'realisateur: $CLI_NAME --apply on $HOST changed machine-wide config (App key, release channel, per-account .claude blocks). Owned by realisateur.'"
fi
[ "$fail_n" -eq 0 ]
