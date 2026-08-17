#!/usr/bin/env bash
# dexter-service-deploy.sh -- ship a service from this repo to dexter's /srv.
#
# THE CHANNEL THIS IS HALF OF. Zach, 2026-08-14: "docker containers are the
# consumables produced by dev agents." Commands already have a channel -- a
# project declares a verb on its `bashified` branch, the nightly build cuts it,
# and every account adopts it (vault:realisateur/VERB-DISTRIBUTION.md). Services had none: they
# were hand-installed into whatever userland their author was sitting in, which
# is how zaxon ended up in an undocumented WSL distro and stayed dead for ten
# days. This is the service half: repo -> /srv/<name> -> compose up.
#
#   bin/dexter-service-deploy.sh <name>            # push + up -d
#   bin/dexter-service-deploy.sh <name> --dry-run  # show what would move
#
# Source of truth is provision/dexter/<name>/ in the OWNING project's repo. /srv/<name>/data on
# dexter is service state and is NEVER overwritten from here -- it is the one
# thing the repo does not own.
set -euo pipefail

CLI_NAME="$(basename "$0")"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${DEXTER_HOST:-dexter}"
NAME="${1:-}"
DRY=0
[ "${2:-}" = "--dry-run" ] && DRY=1

die() { echo "$CLI_NAME: $*" >&2; exit 1; }

[ -n "$NAME" ] || die "usage: $CLI_NAME <service-name> [--dry-run]
services visible from here: $(find "$HERE/provision/dexter" "$HOME"/Documents/Projects/*/provision/dexter -mindepth 1 -maxdepth 1 -type d -printf '%f ' 2>/dev/null)"

# WHERE A SERVICE COMES FROM. The container channel is realisateur's ROAD; the
# freight belongs to whichever project owns the service (bin/lib/ownership-set.sh
# has the ledger). zaxon is crt's, so its Dockerfile and compose.yaml live in
# hf7y/crt -- not here. This searches this repo first, then sibling checkouts,
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
[ -n "$SRC" ] || die "no such service: '$NAME' is not in this repo's provision/dexter/,
  nor in any sibling checkout under ~/Documents/Projects/*/provision/dexter/.
  If the owning project is not cloned here, clone it -- a service deploys from
  its owner's repo, not from a copy parked in this one."
[ -f "$SRC/compose.yaml" ] || die "$NAME has no compose.yaml. A service that cannot be composed is not deployable from here."

# --- THE ONE-OWNER CHECK ----------------------------------------------------
# zaxon's data/ holds a WhatsApp linked-device session. Two processes holding
# it means WhatsApp logs the link out, and recovering costs a QR scan on Zach's
# phone. The `hermes` distro runs the old copy, so it must be DOWN before this
# starts the new one. This is the difference between a migration and an
# outage, so it is a refusal rather than a warning.
if [ "$NAME" = "zaxon" ]; then
  running="$(ssh -n "$HOST" 'sudo -n systemctl restart systemd-binfmt 2>/dev/null; cd /mnt/c && /mnt/c/Windows/System32/wsl.exe -l -q --running 2>/dev/null | tr -d "\0\r"' || true)"
  case "$running" in
    *hermes*) die "the 'hermes' distro is RUNNING and owns the same WhatsApp session.
  Starting a second owner logs the link out and costs a QR scan to recover.
  Stop it first:  ssh $HOST 'wslx --terminate hermes'
  Refusing rather than racing it." ;;
  esac
fi

# WHAT THE REPO DOES NOT OWN. `data/` is always service state. A service may
# declare more in `.deploykeep` -- zaxon's uv interpreter, for instance, is 97M
# lifted off the old host and belongs to no repo. Without this, --delete-after
# removes it and the service crash-loops on a half-present runtime. The list
# lives WITH the service so this script needs no per-service special case.
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

# /srv is root-owned; make the directory once, owned by the login user, so the
# push itself needs no privilege.
ssh -n "$HOST" "sudo -n mkdir -p /srv/$NAME && sudo -n chown \$(id -u):\$(id -g) /srv/$NAME"
# shellcheck disable=SC2086  # KEEP is a built argument list, intentionally split
rsync -a $KEEP --delete-after "$SRC/" "$HOST:/srv/$NAME/"

# `docker compose up -d --build`: build is idempotent and cheap when nothing
# changed, and it means a Dockerfile edit in this repo actually reaches the
# running container instead of silently not.
ssh -n "$HOST" "cd /srv/$NAME && sudo -n docker compose up -d --build" 2>&1 | tail -15
ssh -n "$HOST" "cd /srv/$NAME && sudo -n docker compose ps"

echo "$CLI_NAME: deployed $NAME -> $HOST:/srv/$NAME"
echo "  verify from here:  bin/dexter-liveness.sh"
