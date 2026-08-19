#!/usr/bin/env bash
# selfdev-claude-token.sh -- install the shared Claude Code OAuth token in ONE
# host-wide place, and purge the per-account copies it replaces (realisateur#409).
#
# usage:
#   selfdev-claude-token.sh --check              report where the token is, and
#                                                every stale copy still on disk
#   selfdev-claude-token.sh --install <file>     write /etc/selfdev/claude-token
#                                                (0640 root:selfdev) from <file>
#   selfdev-claude-token.sh --purge              LIST the copies that would go
#   selfdev-claude-token.sh --purge --apply      shred them
#
# exit: 0 OK  1 usage  2 GAP (something to do)  4 BAD  6 BLIND (could not look)
#
# --purge is DRY-RUN unless --apply. It removes only paths it can name and has
# just verified; it never globs a home directory blind.
#
# ORDER MATTERS. Purging before rotating is theatre: the value in those files
# is still live. Rotate (`claude setup-token`), --install the new value, prove
# a dispatch works, and only then --purge. Nothing here enforces that order --
# it cannot, since it cannot tell a rotated token from an unrotated one -- so
# it is stated here and printed by --check.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/selfdev-claude-token.sh
. "$ROOT/lib/selfdev-claude-token.sh"

UID_MIN="${SELFDEV_UID_MIN:-3000}"; UID_MAX="${SELFDEV_UID_MAX:-3099}"
# Overridable so the suite exercises THIS code path rather than a fixture
# shape production never writes -- the defect that made three guards
# untestable (realisateur, guards-scrape-unexpanded-HOME).
HOME_ROOT="${SELFDEV_HOME_ROOT:-/home}"
PASS=0; GAPS=0; BAD=0; BLIND=0
ok()    { printf '  OK      %s\n' "$*"; PASS=$((PASS+1)); }
gap()   { printf '  GAP     %s\n' "$*"; GAPS=$((GAPS+1)); }
bad()   { printf '  BAD     %s\n' "$*"; BAD=$((BAD+1)); }
blind() { printf '  BLIND   %s\n' "$*"; BLIND=$((BLIND+1)); }
die()   { printf 'selfdev-claude-token: %s\n' "$*" >&2; exit 1; }

usage() { sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

MODE=""; SRC=""; APPLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --check)   MODE=check ;;
    --install) MODE=install; SRC="${2:-}"; [ -n "$SRC" ] || die "--install needs a file"; shift ;;
    --purge)   MODE=purge ;;
    --apply)   APPLY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 -- try --help" ;;
  esac
  shift
done
[ -n "$MODE" ] || { usage; exit 1; }

# selfdev_accounts -- the accounts in the self-dev uid band on THIS host.
# Prints nothing and returns 1 if the band is empty, which is a finding
# (this host has no self-dev accounts) and not an emptiness to pass over.
selfdev_accounts() {
  local out
  if [ -n "${SELFDEV_ACCOUNTS:-}" ]; then
    # word-split deliberately: the override is a space-separated list
    # shellcheck disable=SC2086
    out="$(printf '%s\n' $SELFDEV_ACCOUNTS)"
  else
    out="$(getent passwd | awk -F: -v lo="$UID_MIN" -v hi="$UID_MAX" \
      '$3>=lo && $3<=hi {print $1}')"
  fi
  [ -n "$out" ] || return 1
  printf '%s\n' "$out"
}

# stale_copies <account> -- the per-account paths this design replaces. Named,
# not globbed, except the .bak-* series which IS a glob because its names are
# timestamps. Prints only paths that exist.
stale_copies() {
  local h="$HOME_ROOT/$1" p
  for p in "$h/.claude-token" "$h/.claude/settings.json" "$h"/.claude/settings.json.bak-*; do
    [ -e "$p" ] && printf '%s\n' "$p"
  done
  return 0
}

# strip_token_key <settings.json> -- remove ONLY the CLAUDE_CODE_OAUTH_TOKEN
# key, leaving every other setting exactly as it was. The file is not ours to
# delete; it holds hooks, permissions and model config an account needs.
strip_token_key() {
  python3 - "$1" <<'PY'
import json, sys, pathlib
p = pathlib.Path(sys.argv[1]); d = json.loads(p.read_text())
d.get("env", {}).pop("CLAUDE_CODE_OAUTH_TOKEN", None)
if d.get("env") == {}: d.pop("env")
p.write_text(json.dumps(d, indent=2) + "\n"); p.chmod(0o600)
PY
}

TOKPATH="$(selfdev_token_path)"

case "$MODE" in
install)
  [ -r "$SRC" ] || die "cannot read $SRC"
  tok="$(tr -d '\r\n' < "$SRC")"
  case "$tok" in sk-ant-oat*) ;; *) die "$SRC does not hold an sk-ant-oat* token -- refusing to install it" ;; esac
  getent group "$SELFDEV_TOKEN_GROUP" >/dev/null || die "no group $SELFDEV_TOKEN_GROUP on this host"
  install -d -m 755 -o root -g root "$SELFDEV_TOKEN_DIR" || die "cannot create $SELFDEV_TOKEN_DIR (run as root)"
  # Via a mode-600 temp file so the value never appears in argv, which is
  # readable in ps by any local user -- the same care provision-selfdev-user.sh
  # takes, kept here because this is now the only writer.
  tmp="$(mktemp)"; chmod 600 "$tmp"; printf '%s\n' "$tok" > "$tmp"
  install -m 640 -o root -g "$SELFDEV_TOKEN_GROUP" "$tmp" "$TOKPATH" || { rm -f "$tmp"; die "install to $TOKPATH failed"; }
  shred -u "$tmp" 2>/dev/null || rm -f "$tmp"
  ok "wrote $TOKPATH (0640 root:$SELFDEV_TOKEN_GROUP)"
  echo
  echo "Next: prove one dispatch reads it before purging anything."
  exit 0
  ;;

check)
  echo "== selfdev-claude-token --check on $(hostname -s) =="
  echo
  echo "-- the one copy --"
  if [ -e "$TOKPATH" ]; then
    perm="$(stat -c '%a %U:%G' "$TOKPATH" 2>/dev/null || echo '?')"
    if [ "$perm" = "640 root:$SELFDEV_TOKEN_GROUP" ]; then
      ok "$TOKPATH ($perm)"
    else
      bad "$TOKPATH is $perm, want 640 root:$SELFDEV_TOKEN_GROUP"
    fi
    if selfdev_token_readable "$TOKPATH"; then
      ok "readable by this process ($(id -un))"
    else
      blind "present but NOT readable by $(id -un) -- cannot verify its contents"
    fi
  else
    gap "$TOKPATH does not exist -- the host-wide copy has not been installed"
  fi
  echo
  echo "-- the copies it replaces --"
  if ! accts="$(selfdev_accounts)"; then
    blind "no account in uid band $UID_MIN-$UID_MAX on this host -- nothing to survey, which on a self-dev host is itself a finding"
  else
    n=0
    while read -r a; do
      [ -n "$a" ] || continue
      # ABSENT and UNREADABLE are different answers. A home that is not
      # there holds no copy -- that is a fact. A home that is there and
      # cannot be entered is a domain we did not read, and folding that into
      # "clean" is the exact failure this ecosystem calls BLIND.
      if [ ! -e "$HOME_ROOT/$a" ]; then
        ok "$a has no home under $HOME_ROOT -- no copy to hold"
        continue
      fi
      if ! [ -x "$HOME_ROOT/$a" ]; then
        blind "$HOME_ROOT/$a not traversable by $(id -un) -- cannot say whether it holds a copy"
        continue
      fi
      while read -r p; do
        [ -n "$p" ] || continue
        n=$((n+1)); gap "stale copy: $p"
      done <<<"$(stale_copies "$a")"
    done <<<"$accts"
    [ "$n" -eq 0 ] && [ "$BLIND" -eq 0 ] && ok "no per-account copy found"
  fi
  echo
  echo "ORDER: rotate -> --install -> prove a dispatch -> --purge. Purging an"
  echo "unrotated token deletes copies of a value that is still live."
  ;;

purge)
  [ "$APPLY" -eq 1 ] || echo "== DRY RUN (no --apply): listing only ==" 
  if [ ! -e "$TOKPATH" ]; then
    bad "refusing to purge: $TOKPATH does not exist, so purging would leave NO copy of the token anywhere and every account would dispatch and produce nothing, silently"
    printf '\n== %d BAD ==\n' "$BAD"; exit 4
  fi
  selfdev_token_readable "$TOKPATH" || { blind "cannot read $TOKPATH as $(id -un) -- refusing to purge against a replacement I cannot verify"; printf '\n== %d BLIND ==\n' "$BLIND"; exit 6; }
  if ! accts="$(selfdev_accounts)"; then
    blind "no account in uid band $UID_MIN-$UID_MAX -- nothing enumerated, which is not the same as nothing present"
    printf '\n== %d BLIND ==\n' "$BLIND"; exit 6
  fi
  while read -r a; do
    [ -n "$a" ] || continue
    while read -r p; do
      [ -n "$p" ] || continue
      case "$p" in
        */.claude/settings.json)
          # The settings file is not ours to delete -- it holds unrelated
          # config. Strip only the one key, and only if it is there.
          if grep -q CLAUDE_CODE_OAUTH_TOKEN "$p" 2>/dev/null; then
            if [ "$APPLY" -eq 1 ]; then
              if strip_token_key "$p"; then
                ok "stripped CLAUDE_CODE_OAUTH_TOKEN from $p"
              else
                bad "could not strip $p"
              fi
            else
              gap "would strip CLAUDE_CODE_OAUTH_TOKEN from $p"
            fi
          fi
          ;;
        *)
          if [ "$APPLY" -eq 1 ]; then
            shred -u "$p" 2>/dev/null || rm -f "$p"
            if [ -e "$p" ]; then bad "could not remove $p"; else ok "shredded $p"; fi
          else
            gap "would shred $p"
          fi
          ;;
      esac
    done <<<"$(stale_copies "$a")"
  done <<<"$accts"
  echo
  [ "$APPLY" -eq 1 ] || echo "Re-run with --apply to act. Session transcripts under"
  [ "$APPLY" -eq 1 ] || echo "\$HOME/.claude/projects/**.jsonl are NOT touched here -- see #409; they need"
  [ "$APPLY" -eq 1 ] || echo "a decision about the transcript archive, not a blind delete."
  ;;
esac

printf '\n== %d OK, %d GAP, %d BAD, %d BLIND ==\n' "$PASS" "$GAPS" "$BAD" "$BLIND"
[ "$BAD"   -gt 0 ] && exit 4
[ "$BLIND" -gt 0 ] && exit 6
[ "$GAPS"  -gt 0 ] && exit 2
exit 0
