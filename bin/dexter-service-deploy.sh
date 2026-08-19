#!/usr/bin/env bash
# dexter-service-deploy.sh -- ship a service from its owning repo to dexter's /srv.
#
# Commands have a channel (a verb on `bashified` -- vault:realisateur/VERB-DISTRIBUTION.md).
# Services had none, which is how zaxon ended up in an undocumented WSL distro.
#
#   bin/dexter-service-deploy.sh <name>            # push + up -d
#   bin/dexter-service-deploy.sh <name> --dry-run  # show what would move
#
# Source of truth is provision/dexter/<name>/ in the OWNING project's repo, read
# live from GitHub -- dexter holds no clones. /srv/<name>/data on dexter is
# service state and is NEVER overwritten from here.
set -euo pipefail

CLI_NAME="$(basename "$0")"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${DEXTER_HOST:-dexter}"
NAME="${1:-}"
DRY=0
[ "${2:-}" = "--dry-run" ] && DRY=1

die() { echo "$CLI_NAME: $*" >&2; exit 1; }
# shellcheck source=bin/lib/ownership-set.sh
. "$HERE/bin/lib/ownership-set.sh"

[ -n "$NAME" ] || die "usage: $CLI_NAME <service-name> [--dry-run]
services visible from here: $(find "$HERE/provision/dexter" "$HOME"/Documents/Projects/*/provision/dexter -mindepth 1 -maxdepth 1 -type d -printf '%f ' 2>/dev/null)"

# WHERE A SERVICE COMES FROM. The container channel is realisateur's ROAD; the
# freight belongs to whichever project owns the service. A checkout is used when
# one is here but is never required: dexter has none, so the fallback is GitHub.
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
SEARCH=""
if [ -n "${DEXTER_SERVICE_PATH:-}" ]; then
  IFS=: read -ra _roots <<< "$DEXTER_SERVICE_PATH"
  for r in "${_roots[@]}"; do SEARCH="$SEARCH $r/$NAME"; done
fi
SEARCH="$SEARCH $HERE/provision/dexter/$NAME"
for d in "$HOME"/Documents/Projects/*/provision/dexter/"$NAME"; do
  SEARCH="$SEARCH $d"
done
SRC=""
for d in $SEARCH; do [ -d "$d" ] && { SRC="$d"; break; }; done

# WHO OWNS WHICH SERVICE, without a map in this file. The ledger names the
# projects that exist (zaxon is crt's); each is asked whether its tree carries
# provision/dexter/<name>/, and the first that does is the source. A tree that
# does not READ is blind, never absence, so it exits 6 rather than "no such
# service".
OWNER="${DEXTER_OWNER:-hf7y}"
if [ -z "$SRC" ]; then
  blind=""
  STAGE="$(mktemp -d)"; trap 'rm -rf "$STAGE"' EXIT
  for repo in realisateur $(printf '%s\n' "$OWN_RECEIVERS" | awk '/exists/{print $1}'); do
    tree="$(gh api "repos/$OWNER/$repo/git/trees/HEAD?recursive=1" -q '.tree[] | "\(.mode) \(.path)"' 2>/dev/null)" || tree=""
    [ -n "$tree" ] || { blind="$blind $repo"; continue; }
    files="$(printf '%s\n' "$tree" | awk -v p="provision/dexter/$NAME/" '$1 != "040000" && index($2, p) == 1')"
    [ -n "$files" ] || continue
    while read -r mode path; do
      rel="${path#provision/dexter/$NAME/}"
      mkdir -p "$STAGE/$(dirname "$rel")"
      b64="$(gh api "repos/$OWNER/$repo/contents/$path?ref=HEAD" -q .content 2>/dev/null)" \
        || { echo "$CLI_NAME: BLIND -- $OWNER/$repo:$path did not read. An unreadable source is not an empty one." >&2; exit 6; }
      printf '%s' "$b64" | base64 -d > "$STAGE/$rel"
      [ "$mode" = "100755" ] && chmod +x "$STAGE/$rel" || true
    done <<< "$files"
    SRC="$STAGE"; break
  done
  if [ -z "$SRC" ] && [ -n "$blind" ]; then
    echo "$CLI_NAME: BLIND -- could not read the tree of:$blind" >&2
    echo "  '$NAME' may well exist in one of them. Refusing to call an unreadable" >&2
    echo "  estate an empty one. Check \`gh auth status\` and re-run." >&2
    exit 6
  fi
fi
[ -n "$SRC" ] || die "no such service: '$NAME' is not in provision/dexter/ of this
  repo, of any sibling checkout, nor of any project the ownership ledger names."
[ -f "$SRC/compose.yaml" ] || die "$NAME has no compose.yaml. A service that cannot be composed is not deployable from here."

# --- THE ONE-OWNER CHECK ----------------------------------------------------
# zaxon's data/ holds a WhatsApp linked-device session. Two processes holding
# it means WhatsApp logs the link out, and recovering costs a QR scan on Zach's
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
if [ "$NAME" = "zaxon" ]; then
  running="$(ssh -n "$HOST" 'sudo -n systemctl restart systemd-binfmt 2>/dev/null; cd /mnt/c && /mnt/c/Windows/System32/wsl.exe -l -q --running 2>/dev/null | tr -d "\0\r"' || true)"
  case "$running" in
    *hermes*) die "the 'hermes' distro is RUNNING and owns the same WhatsApp session.
  Starting a second owner logs the link out and costs a QR scan to recover.
  Stop it first:  ssh $HOST 'wslx --terminate hermes'
  Refusing rather than racing it." ;;
  esac
fi

# WHAT THE REPO DOES NOT OWN. `data/` is always service state; a service may
# declare more in `.deploykeep` (zaxon's 97M uv interpreter belongs to no repo).
# Without this, --delete-after removes it and the service crash-loops.
KEEP="--exclude data"
if [ -f "$SRC/.deploykeep" ]; then
  while IFS= read -r line; do
    case "$line" in ''|\#*) continue;; esac
    KEEP="$KEEP --exclude $line"
  done < "$SRC/.deploykeep"
fi

if [ "$DRY" = 1 ]; then
  echo "$CLI_NAME: would push $SRC/ -> $HOST:/srv/$NAME/ (excluding data/) and run compose up -d"
  # shellcheck disable=SC2086
  rsync -an $KEEP --itemize-changes "$SRC/" "$HOST:/srv/$NAME/" 2>/dev/null | head -20
  exit 0
fi

# /srv is root-owned; make the dir once, owned by the login user, so the push needs no privilege.
ssh -n "$HOST" "sudo -n mkdir -p /srv/$NAME && sudo -n chown \$(id -u):\$(id -g) /srv/$NAME"
# shellcheck disable=SC2086  # KEEP is a built argument list, intentionally split
rsync -a $KEEP --delete-after "$SRC/" "$HOST:/srv/$NAME/"

# --build is idempotent and cheap when nothing changed, and it means a
# Dockerfile edit actually reaches the running container instead of silently not.
ssh -n "$HOST" "cd /srv/$NAME && sudo -n docker compose up -d --build" 2>&1 | tail -15
ssh -n "$HOST" "cd /srv/$NAME && sudo -n docker compose ps"

echo "$CLI_NAME: deployed $NAME -> $HOST:/srv/$NAME"
echo "  verify from here:  bin/dexter-liveness.sh"
