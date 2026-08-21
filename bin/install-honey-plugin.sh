#!/usr/bin/env bash
# install-honey-plugin.sh -- install the Honey plugin into every self-dev
# account on this host, and wire it to apply on EVERY session (not only when
# an agent remembers to type /honey).

set -uo pipefail

MODE=--check
HONEY_MODE=ultra
ONLY_USER=
while [ $# -gt 0 ]; do
  case "$1" in
    --check|--apply) MODE="$1" ;;
    --mode) HONEY_MODE="${2:-}"; shift ;;
    --user) ONLY_USER="${2:-}"; shift ;;
    *) echo "usage: $0 [--check|--apply] [--mode lite|full|ultra] [--user <account>]" >&2; exit 2 ;;
  esac
  shift
done
case "$HONEY_MODE" in lite|full|ultra) ;; *) echo "bad --mode: $HONEY_MODE" >&2; exit 2 ;; esac

UID_MIN="${SELFDEV_UID_MIN:-3000}"
UID_MAX="${SELFDEV_UID_MAX:-3099}"

# Same reasoning as provision-selfdev-user.sh: under `sudo bash ...` $HOME is
# root's, and root has no marketplace clone. Fall back to SUDO_USER's home.
SRC_HOME="$HOME"
if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
  SRC_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  [ -n "$SRC_HOME" ] || SRC_HOME="$HOME"
fi
SRC="${HONEY_SRC:-$SRC_HOME/.claude/plugins/marketplaces/greenpt}"

PASS=0; GAPS=0; BAD=0
ok()  { printf '  OK      %s\n' "$*"; PASS=$((PASS+1)); }
gap() { printf '  MISSING %s\n' "$*"; GAPS=$((GAPS+1)); }
bad() { printf '  BAD     %s\n' "$*"; BAD=$((BAD+1)); }

[ -f "$SRC/.claude-plugin/plugin.json" ] || {
  echo "no honey marketplace clone at $SRC" >&2
  echo "install it once in an interactive session (/plugin), or set HONEY_SRC." >&2
  exit 4
}
VERSION="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$SRC/.claude-plugin/plugin.json" | head -1)"
[ -n "$VERSION" ] || { echo "no version in $SRC/.claude-plugin/plugin.json" >&2; exit 4; }
SHA="$(git -C "$SRC" rev-parse HEAD 2>/dev/null || echo unknown)"

echo "honey $VERSION ($SHA) from $SRC  mode=$HONEY_MODE  $MODE"

USERS="$(awk -F: -v lo="$UID_MIN" -v hi="$UID_MAX" '$3>=lo && $3<=hi {print $1}' /etc/passwd)"
[ -n "$ONLY_USER" ] && USERS="$ONLY_USER"
[ -n "$USERS" ] || { echo "no self-dev accounts in uid $UID_MIN-$UID_MAX" >&2; exit 4; }

# Run a command as the account. Works whether we are root or a sudoer.
asuser() { local u="$1"; shift; sudo -u "$u" -H "$@"; }

# The witness: run the SessionStart hook exactly as Claude Code would, as the
# account, and require the directive on stdout. Anything short of this passes
# on the empty-cache install described above.
witness() {
  local u="$1" home="$2" out
  out="$(printf '{}' | asuser "$u" node -e \
    "require('module').runMain(process.argv[1])" \
    "$home/.claude/plugins/cache/greenpt/honey/$VERSION/hooks/honey-session.js" 2>/dev/null)"
  printf '%s' "$out" | grep -q 'Honey mode is ACTIVE'
}

for u in $USERS; do
  home="$(getent passwd "$u" | cut -d: -f6)"
  if [ -z "$home" ] || [ ! -d "$home" ]; then bad "$u: no home"; continue; fi
  if witness "$u" "$home"; then ok "$u: hook injects the directive"; continue; fi

  if [ "$MODE" = --check ]; then gap "$u: honey not wired"; continue; fi

  dest="$home/.claude/plugins"
  asuser "$u" mkdir -p "$dest/cache/greenpt/honey"
  # Copy the payload as the target user, from a readable staging copy: rsync
  # straight out of $SRC_HOME would need the account to read another user's
  # 0700 home.
  stage="$(mktemp -d)"
  tar -C "$SRC" --exclude=.git --exclude=node_modules -cf - . | tar -C "$stage" -xf -
  chmod -R a+rX "$stage"
  asuser "$u" rm -rf "$dest/cache/greenpt/honey/$VERSION"
  asuser "$u" cp -a "$stage" "$dest/cache/greenpt/honey/$VERSION"
  rm -rf "$stage"

  asuser "$u" tee "$dest/installed_plugins.json" >/dev/null <<EOF
{
  "version": 2,
  "plugins": {
    "honey@greenpt": [
      {
        "scope": "user",
        "installPath": "$home/.claude/plugins/cache/greenpt/honey/$VERSION",
        "version": "$VERSION",
        "gitCommitSha": "$SHA"
      }
    ]
  }
}
EOF
  asuser "$u" tee "$dest/known_marketplaces.json" >/dev/null <<EOF
{
  "greenpt": {
    "source": { "source": "github", "repo": "Green-PT/honey-for-devs" },
    "installLocation": "$home/.claude/plugins/marketplaces/greenpt"
  }
}
EOF
  # settings.json has other writers (credential provisioning, per-project
  # config) -- merge the two keys, never rewrite the file.
  asuser "$u" python3 - "$home/.claude/settings.json" <<'EOF'
import json, os, sys
p = sys.argv[1]
d = json.load(open(p)) if os.path.exists(p) else {}
d.setdefault("enabledPlugins", {})["honey@greenpt"] = True
d.setdefault("extraKnownMarketplaces", {})["greenpt"] = {
    "source": {"source": "github", "repo": "Green-PT/honey-for-devs"}}
os.makedirs(os.path.dirname(p), exist_ok=True)
tmp = p + ".tmp"
json.dump(d, open(tmp, "w"), indent=2)
os.replace(tmp, p)
EOF
  asuser "$u" node -e "require('module').runMain(process.argv[1])" \
    "$home/.claude/plugins/cache/greenpt/honey/$VERSION/hooks/honey-state.js" \
    set "$HONEY_MODE" >/dev/null

  if witness "$u" "$home"; then ok "$u: installed, hook injects the directive"
  else bad "$u: installed but hook injects nothing"; fi
done

printf '%s\n' "--- $PASS ok, $GAPS missing, $BAD bad"
[ "$BAD" -gt 0 ] && exit 1
# 4, not 3: a GAP is in scope and not installed yet (#334).
[ "$GAPS" -gt 0 ] && [ "$MODE" = --check ] && exit 4
exit 0
