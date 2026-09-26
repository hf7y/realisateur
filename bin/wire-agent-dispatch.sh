#!/usr/bin/env bash
# wire-agent-dispatch.sh -- point /srv/agent's four files at this clone, so a
# merged PR reaches the 01:00 nightly instead of a copy nothing refreshes.
# TRAPS (the rest of this header is in the vault):
# `/srv/agent` is not a git repository (#1332). The four files were placed by
# hand on 2026-09-24 and #1314 versioned them afterwards, so `main` and the
# host agreed by coincidence, not by any path. The clone this runs from is
# already pulled every 20 minutes by the `realisateur:estate-watch:WATCH` cron
# row, so a symlink is the whole propagation mechanism -- no second pull, no
# copy step, no deploy tree.
#
# WHY SYMLINKS AND NOT `cp`: a copy has to be re-copied, which is the thing
# that never happens. `nightly.sh` resolves its siblings with
# `dirname "${BASH_SOURCE[0]}"`, which is the SYMLINK's directory, so the logs,
# `.nightly.lock` and `work/` stay in /srv/agent where they belong.
#
# REFUSES on drift rather than adopting: a host copy that differs from the
# clone is someone's hand fix or a half-finished deploy, and overwriting it
# silently is how the estate loses work. It names the diff and stops.
set -uo pipefail

CLI_NAME="wire-agent-dispatch"
usage() { echo "usage: $0 [--check|--apply]" >&2; }

MODE=--check
while [ $# -gt 0 ]; do
  case "$1" in
    --check|--apply) MODE="$1" ;;
    *)               usage; exit 2 ;;
  esac
  shift
done

SRC="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../agent"
DST="${AGENT_DIR:-/srv/agent}"
FILES=(nightly.sh run-agent.sh repos Dockerfile)

PASS=0; GAPS=0; BAD=0
ok()  { printf '  OK      %s\n' "$*"; PASS=$((PASS+1)); }
gap() { printf '  LINK    %s\n' "$*"; GAPS=$((GAPS+1)); }
bad() { printf '  BAD     %s\n' "$*"; BAD=$((BAD+1)); }

echo "== $CLI_NAME ($MODE) -- $DST -> $SRC =="

[ -d "$SRC" ] || { echo "$CLI_NAME: no agent/ beside this script at $SRC -- wrong checkout" >&2; exit 2; }
[ -d "$DST" ] || { echo "$CLI_NAME: $DST does not exist -- this host does not dispatch" >&2; exit 2; }

# A pass holds this for the whole night. Replacing run-agent.sh underneath a
# running nightly is the one way this can break something that works.
if [ -e "$DST/.nightly.lock" ] && ! flock -n "$DST/.nightly.lock" true 2>/dev/null; then
  echo "$CLI_NAME: a nightly holds $DST/.nightly.lock -- it is dispatching right now. Try after it finishes." >&2
  exit 1
fi

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
for f in "${FILES[@]}"; do
  want="$(readlink -f "$SRC/$f")"
  [ -f "$want" ] || { bad "$f: not in the clone at $SRC/$f"; continue; }

  if [ -L "$DST/$f" ] && [ "$(readlink -f "$DST/$f")" = "$want" ]; then
    ok "$f -> the clone"
    continue
  fi
  if [ ! -e "$DST/$f" ]; then
    gap "$f: absent on the host"
  elif cmp -s "$DST/$f" "$want"; then
    gap "$f: a plain copy, identical today and refreshed by nothing"
  else
    bad "$f: a plain copy that DIFFERS from the clone -- diff '$DST/$f' '$want'"
    continue
  fi

  [ "$MODE" = --apply ] || continue
  if [ -e "$DST/$f" ]; then
    mkdir -p "$DST/.pre-wire" || { bad "$f: could not make $DST/.pre-wire"; continue; }
    cp -p "$DST/$f" "$DST/.pre-wire/$f.$stamp" || { bad "$f: could not back up, not touching it"; continue; }
  fi
  ln -sfn "$want" "$DST/$f" && ok "$f -> the clone (was backed up to .pre-wire/$f.$stamp)" \
    || bad "$f: could not link"
done

echo
if [ "$MODE" = --check ]; then
  printf 'check only, nothing changed: %d linked, %d to link, %d bad\n' "$PASS" "$GAPS" "$BAD"
  [ "$GAPS" -eq 0 ] && [ "$BAD" -eq 0 ] && echo "nothing to do." || echo "Next: $0 --apply"
else
  printf 'wired %s: %d linked, %d bad\n' "$DST" "$PASS" "$BAD"
fi
[ "$BAD" -eq 0 ] || exit 5
[ "$MODE" = --apply ] || [ "$GAPS" -eq 0 ] || exit 4
exit 0
