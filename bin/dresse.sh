#!/usr/bin/env bash
# dresse.sh -- stand a self-dev host, or one account on it, up (#435).
# KIND: verb
#
# TRAP: the plan is checked against propagation-set.sh plus the indirect set
#   read from the callers -- a typed list goes stale in silence.
# TRAP: no secret is installed unattended; both modes only --check the token.
#
set -uo pipefail

CLI_NAME='dresse'
CLI_SUMMARY='stand a self-dev host or account up: run every provisioning step, in order, idempotently'
CLI_USAGE='  dresse --host [--check|--apply]      the machine: App key, token, release channel, fleet blocks
  dresse --host --on <host> [...]      the same, driven from here over ssh
  dresse --all [--check|--apply]       every account in the self-dev uid band
  dresse <account> [--check|--apply]   one account, standing it up if it does not exist'
CLI_FLAGS='--host --all --check --apply --on'
CLI_POSITIONAL='<account>, or --all, or --host'
CLI_EXITS='  0  every step ran (or, under --check, could)
  1  at least one step refused
  2  usage error
  6  BLIND -- the propagation set could not be read, or --on could not reach the host'
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/cli-guard.sh"
cli_guard "$@"

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
HOST="$(hostname -s 2>/dev/null || echo unknown)"
UID_MIN="${SELFDEV_UID_MIN:-3000}"
UID_MAX="${SELFDEV_UID_MAX:-3099}"

MODE="--check"; ALL=0; HOSTWIDE=0; ACCT=""; ON=""
SSH_BIN="${DRESSE_SSH_BIN:-ssh}"
SSH_TIMEOUT="${DRESSE_SSH_TIMEOUT:-20}"
want_on=0
for a in "$@"; do
  if [ "$want_on" -eq 1 ]; then ON="$a"; want_on=0; continue; fi
  case "$a" in
    --check|--apply) MODE="$a" ;;
    --all)           ALL=1 ;;
    --host)          HOSTWIDE=1 ;;
    --on)            want_on=1 ;;
    --on=*)          ON="${a#--on=}" ;;
    -*)              echo "$CLI_NAME: unknown flag $a" >&2; exit 2 ;;
    *)               ACCT="$a" ;;
  esac
done
[ "$want_on" -eq 0 ] || { echo "$CLI_NAME: --on needs a host" >&2; exit 2; }
if [ "$ALL" -eq 0 ] && [ "$HOSTWIDE" -eq 0 ] && [ -z "$ACCT" ]; then
  echo "$CLI_NAME: name an account, --all for the whole uid band, or --host for the machine" >&2; exit 2
fi
if [ $(( ALL + HOSTWIDE + (${#ACCT} > 0 ? 1 : 0) )) -gt 1 ]; then
  echo "$CLI_NAME: --host, --all and a named account are mutually exclusive -- say which" >&2; exit 2
fi
if [ -n "$ON" ] && [ "$HOSTWIDE" -eq 0 ]; then
  echo "$CLI_NAME: --on drives the HOST plan only (realisateur#895 half 1 -- an account is a ten-script sequence). For an account, run this on the host itself." >&2
  exit 2
fi

# shellcheck source=lib/propagation-set.sh
. "$HERE/lib/propagation-set.sh" 2>/dev/null || {
  echo "$CLI_NAME: BLIND -- cannot read $HERE/lib/propagation-set.sh; the plan cannot be checked" >&2; exit 6; }
[ -n "${PROP_PROVISION_SCRIPTS:-}" ] || {
  echo "$CLI_NAME: BLIND -- propagation-set.sh declares no provisioning set" >&2; exit 6; }

# script|check args|apply args|what, in run order
HOST_STEPS="
selfdev-app-key.sh|--check|--apply|the GitHub App key, host-wide, group-readable by the uid band
selfdev-claude-token.sh|--check|--check|the shared OAuth token (--install takes a file a human supplies)
wire-release-channel.sh|--host --check|--host --apply|the verb-build channel: bootstrap, pin, links, root's clock
selfdev-permissions-provision.sh|--strict|--apply|the .claude permissions block on every account
selfdev-hooks-provision.sh|--strict|--apply|the SubagentStop hook on every account
"
ACCT_NEW_STEP="setup-selfdev-project.sh"
ACCT_STEPS="
wire-release-channel.sh|--check|--apply|the verb-build bootstrap and this account's own clock
"

pass_n=0; fail_n=0; gap_n=0

# A TAR: a step needs lib/ and hooks/ beside it (#385/#386). %q: ssh re-parses
# one joined string (selfdev-credentials.sh). Why not a checkout: dresse(1).
remote_step() { # remote_step <script> <args...>
  local s="$1"; shift
  local q="" a sudo_prefix=""
  for a in "$@"; do q="$q $(printf '%q' "$a")"; done
  [ "$MODE" = --apply ] && sudo_prefix='sudo -n '
  tar -c -C "$HERE/.." bin/lib "bin/$s" hooks 2>/dev/null \
    | "$SSH_BIN" -o BatchMode=yes -o ConnectTimeout="$SSH_TIMEOUT" "$ON" \
        "set -u
         d=\$(mktemp -d) || exit 6
         trap 'rm -rf \"\$d\"' EXIT
         tar -x -C \"\$d\" || exit 6
         ${sudo_prefix}bash \"\$d/bin/$s\"$q"
}

run_step() { # run_step <script> <args...>
  local s="$1"; shift
  local p="$HERE/$s"
  if [ ! -x "$p" ] && [ ! -f "$p" ]; then
    echo "  BAD     $s is not here -- the plan names a step this checkout does not have"
    fail_n=$((fail_n + 1)); return 1
  fi
  # shellcheck disable=SC2086
  if [ -n "$ON" ]; then remote_step "$s" "$@" 2>&1 | sed 's/^/     /'
  else                  bash "$p" "$@" 2>&1 | sed 's/^/     /'; fi
  local rc=${PIPESTATUS[0]}
  case "$rc" in
    0) echo "  OK      $s ${*}"; pass_n=$((pass_n + 1)) ;;
    6) echo "  BLIND   $s ${*} could not look (exit 6) -- not clean"; fail_n=$((fail_n + 1)) ;;
    *) if [ "$MODE" = --check ]; then
         echo "  GAP     $s ${*} reports work to do (exit $rc)"; gap_n=$((gap_n + 1))
       else
         echo "  BAD     $s ${*} exited $rc"; fail_n=$((fail_n + 1))
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

via_setup() {
  local f
  for f in "$ACCT_NEW_STEP" land-selfdev.sh; do
    [ -f "$HERE/$f" ] && grep -ohE '[a-z0-9-]+\.sh' "$HERE/$f"
  done | sort -u
}

plan_check() {
  local named via s bad=0
  via="$(via_setup)"
  [ -n "$via" ] || { echo "  BLIND   cannot read $ACCT_NEW_STEP -- coverage is unverifiable"; return 6; }
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
    printf '%s\n' "$via" | grep -qx "$s" && continue
    echo "  ..      not covered by $CLI_NAME: $s (still a hand-run script)"
  done
  return $bad
}

# ROOT CHANGES THE HOST, it does not look at it -- under --on, remote sudo -n.
if [ "$MODE" = --apply ] && [ -z "$ON" ] && [ "$(id -u)" -ne 0 ]; then
  echo "$CLI_NAME: --apply must run as root (sudo $0 $*)" >&2; exit 2
fi

TARGET="$ACCT"; [ "$HOSTWIDE" -eq 1 ] && TARGET=--host; [ "$ALL" -eq 1 ] && TARGET=--all

TARGET_HOST="${ON:-$HOST}"   # what notify-senechal below must name
WHERE="$HOST"; [ -z "$ON" ] || WHERE="$ON (over ssh from $HOST)"
echo "== $CLI_NAME ($MODE) on $WHERE, uid band $UID_MIN-$UID_MAX =="
if [ -n "$ON" ]; then
  [ "$MODE" != --apply ] || echo "  ..      --apply needs passwordless 'sudo -n' for $(id -un) on $ON; a step that cannot get it reports BAD, not a prompt"
else
  [ "$(id -u)" -eq 0 ] || echo "  ..      not root: root-only steps will refuse below; run --check under sudo for the full picture"
fi
plan_check || exit $?

if [ "$HOSTWIDE" -eq 1 ]; then
  printf '\n-- %s (host-wide) --\n' "$TARGET_HOST"
  run_plan "$HOST_STEPS"
else
  if [ "$ALL" -eq 1 ]; then
    ACCTS="$(getent passwd | awk -F: -v lo="$UID_MIN" -v hi="$UID_MAX" '$3>=lo && $3<=hi {print $1}' | sort)"
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
  if [ -n "$ON" ]; then NEXT="$CLI_NAME $TARGET --on $ON --apply"
  else                 NEXT="sudo $CLI_NAME $TARGET --apply"; fi
  echo "== nothing done (--check): $pass_n step(s) already satisfied, $gap_n with work to do, $fail_n blind. Next: $NEXT =="
else
  echo "== $pass_n step(s) ran, $fail_n refused =="
  [ "$fail_n" -eq 0 ] && echo "  DO      notify-senechal 'realisateur: $CLI_NAME --apply on $TARGET_HOST changed machine-wide config (App key, release channel, per-account .claude blocks). Owned by realisateur.'"
fi
[ "$fail_n" -eq 0 ]
