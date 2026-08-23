#!/usr/bin/env bash
# verbs-refresh.sh -- the clock mandark does not have: tell me my verbs are
# stale, and pull the new ones when I say so.
#
# KIND: LOCAL
#
# TRAPS (the rest of this header is in the vault):
# WHAT IT ADDS over `install-verb-build.sh --check`:
#   - AGE. A channel can be up to date and months old: if the nightly cutter
#     stops, --check says "up to date" forever. Stale-and-current is a finding.
#   - OFF-CHANNEL LINKS. A verb whose symlink points at a FIXED build dir
#     rather than through `current` never moves when a build is adopted -- the
#     switch reports success and that verb stays behind. --link leaves those
#     alone deliberately (installe owns them), so nothing reported them.
#   - DANGLING links, which PATH search skips in silence.
#

set -uo pipefail

CLI_NAME='verbs-refresh.sh'
CLI_SUMMARY='is my verb build current, how old is it, and pull the new one'
CLI_USAGE='  verbs-refresh.sh            report: which build, how old, anything newer
  verbs-refresh.sh --apply    pull the newest build and switch to it
  verbs-refresh.sh --quiet    one line, only when something is wrong (for ~/.bashrc)'
CLI_FLAGS='--apply --quiet'
CLI_EXITS='  0  on the newest build, it is not stale, and every verb link resolves
  1  something needs doing: a newer build exists, the current one is older
     than STALE_DAYS, or a verb link is dangling or off-channel
  2  usage error
  6  BLIND -- could not reach the build channel, or there is no build root
     here at all. NEVER 0: could-not-look is not up-to-date.'
CLI_POSITIONAL=none
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

BUILD_ROOT="${BUILD_ROOT:-$HOME/.local/share/verb-builds}"
VERB_BIN="${VERB_BIN:-$HOME/.local/bin}"
INSTALL_VERB_BUILD="${INSTALL_VERB_BUILD:-$(dirname "${BASH_SOURCE[0]}")/install-verb-build.sh}"
STALE_DAYS="${STALE_DAYS:-14}"

APPLY=0
QUIET=0
for a in "$@"; do
  case "$a" in
    --apply) APPLY=1 ;;
    --quiet) QUIET=1 ;;
  esac
done

say() { [ "$QUIET" = 1 ] || printf '%s\n' "$*"; }

# One line, only when something is wrong. Written to be safe in a shell rc:
# it never blocks on the network in --quiet mode (see the --check gate below).
# The advice is per-finding, not a blanket "--apply". --apply pulls a build;
nag() { printf 'verbs: %s -- %s\n' "$1" "$2" >&2; }

[ -d "$BUILD_ROOT" ] || {
  echo "$CLI_NAME: no build root at $BUILD_ROOT -- this host has never adopted a verb build. BLIND, not up to date." >&2
  exit 6
}

pin="$(readlink "$BUILD_ROOT/current" 2>/dev/null)"
[ -n "$pin" ] || {
  echo "$CLI_NAME: $BUILD_ROOT/current is not a symlink -- no build is pinned. BLIND, not up to date." >&2
  exit 6
}

# AGE. The build id is a UTC stamp (2026-08-14T033443Z), so the age comes from
# the id itself and not from the directory's mtime -- an mtime is whenever the
# files last happened to be touched, which is not when the build was cut.
age_days=''
stamp="$(printf '%s' "$pin" | sed -n 's/^\([0-9]\{4\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)T.*/\1-\2-\3/p')"
if [ -n "$stamp" ]; then
  then_s="$(date -u -d "$stamp" +%s 2>/dev/null)"
  now_s="$(date -u +%s)"
  [ -n "$then_s" ] && age_days=$(( (now_s - then_s) / 86400 ))
fi

say "verbs: on build $pin${age_days:+ ($age_days day(s) old)}"

findings=0

if [ -n "$age_days" ] && [ "$age_days" -gt "$STALE_DAYS" ]; then
  say "  STALE  this build is $age_days days old (> $STALE_DAYS). If nothing newer exists either, the nightly cutter has stopped -- that is the finding, not the age."
  findings=$((findings+1))
fi

# VERB LINKS. Cheap, local, no network -- so this half runs even in --quiet.
off=0; dangling=0
if [ -d "$VERB_BIN" ]; then
  for have in "$VERB_BIN"/*; do
    [ -L "$have" ] || continue
    tgt="$(readlink "$have")"
    case "$tgt" in
      "$BUILD_ROOT/current/"*)
        # Routes through `current`, so a switch moves it. Still has to resolve.
        if [ ! -e "$have" ]; then
          say "  DANGLING $(basename "$have") -> $tgt (PATH search skips it silently: the verb is simply 'not found')"
          dangling=$((dangling+1)); findings=$((findings+1))
        fi
        ;;
      "$BUILD_ROOT/"*)
        say "  OFF-CHANNEL $(basename "$have") -> $tgt"
        say "             nailed to one build, so adopting a new one leaves it behind. installe owns it; reconcile there, do not clobber."
        off=$((off+1)); findings=$((findings+1))
        ;;
    esac
  done
fi

# IS THERE ANYTHING NEWER. Delegated, and it touches the network.
#
# --quiet RUNS THIS TOO, and that is deliberate. The first version skipped the
# network in --quiet to keep a login shell fast -- which meant the one thing
# the nag exists to say ("a newer build is available") was the one thing it
# could never say. A warning that cannot fire is worse than no warning,
# because it reads as an all-clear. Its own test caught it.
#
# The login cost is bounded by a stamp instead: at most one channel check per
# CHECK_TTL_HOURS. A skipped check is NEVER reported as "up to date" -- it is
# simply not claimed, which is why `newer` stays 0 and nothing is printed.
newer=0
do_check=1
STAMP="$BUILD_ROOT/.verbs-refresh-last-check"
if [ "$QUIET" = 1 ] && [ "$APPLY" = 0 ] && [ -f "$STAMP" ]; then
  ttl_s=$(( ${CHECK_TTL_HOURS:-12} * 3600 ))
  last_s="$(date -u -r "$STAMP" +%s 2>/dev/null || echo 0)"
  [ $(( $(date -u +%s) - last_s )) -lt "$ttl_s" ] && do_check=0
fi
if [ "$do_check" = 1 ]; then
  "$INSTALL_VERB_BUILD" --check >/dev/null 2>&1
  case $? in
    0) say "  ok     no newer build on the channel" ;;
    1) say "  NEWER  a newer build is available"; newer=1; findings=$((findings+1)) ;;
    *) echo "$CLI_NAME: could not reach the build channel -- BLIND, not up to date." >&2; exit 6 ;;
  esac
  touch "$STAMP" 2>/dev/null || true
fi

if [ "$APPLY" = 1 ]; then
  if [ "$newer" = 0 ]; then
    say "  nothing to pull."
  else
    say
    say "-- pulling the newest build (install-verb-build.sh --latest --apply) --"
    if ! "$INSTALL_VERB_BUILD" --latest --apply; then
      echo "$CLI_NAME: install-verb-build.sh refused the build; nothing switched. Your verbs are unchanged, which is the safe outcome." >&2
      exit 1
    fi
    findings=$((findings - 1))
    say "verbs: now on build $(readlink "$BUILD_ROOT/current" 2>/dev/null)"
  fi
  [ "$off" -eq 0 ] || say "  NOTE: $off off-channel link(s) above did NOT move with the switch."
fi

if [ "$QUIET" = 1 ] && [ "$findings" -gt 0 ]; then
  if [ "$newer" = 1 ]; then
    nag "a newer build is available" "run $CLI_NAME --apply"
  elif [ "$dangling" -gt 0 ]; then
    nag "$dangling verb link(s) dangling" "run $CLI_NAME to name them; --apply will NOT fix these"
  elif [ "$off" -gt 0 ]; then
    nag "$off verb(s) pinned off-channel" "run $CLI_NAME to name them; reconcile via installe"
  else
    nag "build $pin is $age_days days old and nothing newer exists" "the nightly cutter has probably stopped"
  fi
fi

[ "$findings" -gt 0 ] && exit 1
exit 0
