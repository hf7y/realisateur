#!/usr/bin/env bash
# land-selfdev.sh -- stand the self-dev ecosystem up on a host that has nothing.
#
# RUN THIS ON THE TARGET HOST, as the project user. It is not offered as a
# curl-pipe-bash one-liner and that is deliberate: getting the script onto the
# machine is a human act, and it is the last one that should be invisible.
#
#   ./land-selfdev.sh              --check (default): probes, writes NOTHING
#   ./land-selfdev.sh --land       clone, install, and stop before arming cron
#
# ANCESTRY: modelled on vkv/office/provision/land-office.sh -- same --check
# vocabulary (OK / MISSING / DO), same idempotence, same refusal to arm anything
# without an explicit flag. That script is the shape realisateur's own
# bin/install-verbs.sh header already cites as the one to imitate.
#
# WHAT IT DELIBERATELY DOES NOT DO: it never writes a crontab. `sync-crontab.sh`
# is run in PREVIEW at the end and the --apply command is printed for a human.
# Arming dispatch is the single step that spends a shared quota, and every other
# guard in this ecosystem stops one step short of it for the same reason.

set -uo pipefail

MODE="${1:---check}"
case "$MODE" in --check|--land) ;; *) echo "usage: $0 [--check|--land]" >&2; exit 2 ;; esac

# One name for "where projects live", shared with install-verbs.sh, verb-set.sh
# and installe -- four tools that must not be able to disagree about this.
PROJECTS="${INSTALLE_PROJECTS:-$HOME/Documents/Projects}"
# The host's own copy of the bootstrap and provisioning tools, spelled the same
# way setup-selfdev-project.sh spells it. Nothing here runs out of a clone.
LIBEXEC="${SELFDEV_LIBEXEC:-/usr/local/libexec/selfdev}"
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/estate-set.sh"
GH_OWNER="${SELFDEV_GH_OWNER:-$GH_ESTATE_OWNER}"

PASS=0; GAPS=0; BAD=0
ok()  { printf '  OK      %s\n' "$*"; PASS=$((PASS+1)); }
gap() { printf '  MISSING %s\n' "$*"; GAPS=$((GAPS+1)); }
bad() { printf '  BAD     %s\n' "$*"; BAD=$((BAD+1)); }
act() { printf '  DO      %s\n' "$*"; }

echo "== land-selfdev ($MODE) -- host $(hostname -s), user $(id -un) =="

# --- probe -------------------------------------------------------------------
for c in git python3 node claude; do
  if command -v "$c" >/dev/null 2>&1; then ok "$c on PATH ($(command -v "$c"))"
  else gap "$c is not on PATH"; fi
done

# Ubuntu's ~/.profile only prepends ~/.local/bin if the directory EXISTS at
# login. Created later, it is not on PATH until the next login -- which is how
# a verb that is installed correctly still cannot be found.
if [ -d "$HOME/.local/bin" ]; then ok "~/.local/bin exists"
else gap "~/.local/bin does not exist -- create it BEFORE the next login or .profile will not add it to PATH"; fi
case ":$PATH:" in *":$HOME/.local/bin:"*) ok "~/.local/bin is on PATH" ;;
                  *) gap "~/.local/bin is not on this shell's PATH" ;; esac

if systemctl --user show-environment >/dev/null 2>&1; then ok "systemd --user is running"
else gap "systemd --user is not available to this session"; fi

# Linger is not needed for cron, but it is what lets a --user unit survive
# logout later. Cheap to have, expensive to add (needs root) once you need it.
linger="$(loginctl show-user "$(id -un)" -p Linger --value 2>/dev/null || true)"
case "$linger" in yes) ok "linger enabled" ;; *) gap "linger is not enabled (needs root: loginctl enable-linger $(id -un))" ;; esac

# THE ONE THAT SILENTLY DISPATCHES THE WRONG ROTATION.
# scheduler resolves schedule/_paced.$(hostname -s).conf and falls back to the
# SHARED _paced.conf when there is no host file. On a new host that fallback is
# not a default, it is another machine's rotation.
HOST="$(hostname -s)"
SHARED_PACED="$PROJECTS/scheduler/schedule/_paced.conf"
if [ -f "$PROJECTS/scheduler/schedule/_paced.$HOST.conf" ]; then
  ok "schedule/_paced.$HOST.conf exists -- this host has its own rotation"
elif [ -d "$PROJECTS/scheduler" ]; then
  # The fallback is not wrong by itself: mandark deliberately has no host file
  # and reads the shared one, which is documented in _paced.dexter.conf's own
  # header. What matters is WHAT would be inherited. Falling back onto a file
  enabled=$(grep -cE '^[a-z][^|]*\|1\|' "$SHARED_PACED" 2>/dev/null || echo 0)
  if [ "${enabled:-0}" -gt 0 ]; then
    bad "no schedule/_paced.$HOST.conf, and the shared _paced.conf has $enabled ENABLED row(s) -- this host would silently dispatch another machine's rotation"
  else
    gap "no schedule/_paced.$HOST.conf; this host falls back to the shared _paced.conf, which currently has 0 enabled rows (inert, but give this host its own file before arming anything)"
  fi
else
  gap "scheduler not cloned yet; cannot check for _paced.$HOST.conf"
fi

# THREE WAYS THIS USER CAN BE AUTHENTICATED, and the check must know all of
# them or it reports a false gap on the shape we actually use.
#
CRED="$HOME/.claude/.credentials.json"
SETTINGS="$HOME/.claude/settings.json"
auth=""
if [ -f "$CRED" ]; then auth="$CRED"
elif [ -f "$SETTINGS" ] && grep -q 'CLAUDE_CODE_OAUTH_TOKEN' "$SETTINGS" 2>/dev/null; then auth="$SETTINGS"
fi
if [ -n "$auth" ]; then
  m="$(stat -c%a "$auth" 2>/dev/null || echo '?')"
  [ "$m" = "600" ] && ok "claude auth configured in $(basename "$auth"), mode 600" \
                   || bad "$auth is mode $m, expected 600 -- a readable token is a finding"
elif [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
  gap "auth is only in this shell's environment -- cron will not have it; run \`claude setup-token\` and put it in $SETTINGS"
else
  gap "no claude auth for $(id -un) -- dispatch would run and produce NOTHING, silently"
fi
# Configuration is not capability. The only real proof is a call, and it costs
# a token, so it is not run here -- but say so, rather than letting "ok" above
# read as more than it is.
[ -n "$auth" ] && printf '  ..      the witness is a live call, not this file: claude -p "reply ok"\n'

# Read AND write. A key existing is not the same fact as GitHub accepting it,
# and this ecosystem has already lost four days to that exact distinction.
if git ls-remote "https://github.com/$GH_OWNER/realisateur.git" HEAD >/dev/null 2>&1; then
  ok "GitHub read path works"
else gap "cannot read https://github.com/$GH_OWNER/realisateur.git"; fi
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  ok "gh is authenticated (file-based token survives cron with no session bus)"
else gap "gh is not authenticated -- the WRITE path is unproven, and a read probe does not establish it"; fi

avail="$(df -BG --output=avail "$HOME" 2>/dev/null | tail -1 | tr -dc '0-9' || true)"
[ -n "$avail" ] && { [ "$avail" -ge 10 ] && ok "${avail}G free on \$HOME" || gap "only ${avail}G free on \$HOME"; }

if [ "$MODE" = --check ]; then
  echo
  printf 'check only, nothing changed: %d ok, %d missing, %d bad\n' "$PASS" "$GAPS" "$BAD"
  [ "$BAD" -eq 0 ] || { echo "resolve the BAD rows before --land."; exit 5; }
  echo "Next: $0 --land"
  exit 0
fi

# --- land --------------------------------------------------------------------
[ "$BAD" -eq 0 ] || { echo; echo "land-selfdev: refusing to land with $BAD BAD row(s) above." >&2; exit 5; }
echo
echo "== landing =="
mkdir -p "$PROJECTS"

# Credentials come BEFORE the clone that needs them, per repo.
WIRE="$(dirname "$0")/wire-selfdev-git.sh"

wire_repo() {
  local name="$1" access=""
  [ -x "$WIRE" ] || { gap "$name: wire-selfdev-git.sh not found beside $(basename "$0") -- clone will use whatever credential happens to exist"; return 0; }
  # READ-WRITE only for the account's OWN repo. The account is named for its
  # project, which is the whole reason one unix user per project buys anything.
  [ "$name" = "$(id -un)" ] && access="--rw"
  # NOT piped into sed: a pipeline's status is the LAST command's, so `| sed`
  # would swallow every failure this script exists to surface.
  local out rc
  out="$("$WIRE" "$name" --apply $access 2>&1)"; rc=$?
  printf '%s\n' "$out" | sed 's/^/    /'
  [ "$rc" -eq 0 ] || bad "$name: git credentials could not be wired (rc=$rc)"
}

clone_or_update() {
  local name="$1" url="$2" dir="$PROJECTS/$1"
  case "$url" in *"github.com/$GH_OWNER/"*|*"github.com:$GH_OWNER/"*) wire_repo "$name" ;; esac
  if [ -d "$dir/.git" ]; then
    act "$name: fast-forward only"
    git -C "$dir" fetch -q origin && git -C "$dir" pull -q --ff-only || \
      { bad "$name: could not fast-forward (diverged or dirty) -- left untouched"; return 1; }
    ok "$name at $(git -C "$dir" rev-parse --short HEAD)"
  else
    act "$name: clone $url"
    git clone -q "$url" "$dir" || { bad "$name: clone failed"; return 1; }
    ok "$name cloned at $(git -C "$dir" rev-parse --short HEAD)"
  fi
}

# SCHEDULER ONLY, and load-bearing per account: its schedule/<p>.conf files are
# the registry the loop below derives every other repo from, and
# _paced.<host>.conf dispatches out of the account's OWN checkout.
#
# REALISATEUR IS NOT CLONED HERE (#134, quoted in bin/lib/propagation-set.sh):
# "Self-dev accounts do NOT pull fresh clones of realisateur ... everything
# they use reaches them through the nightly verb build." What this script needs
# it takes from $LIBEXEC below; the account that OWNS realisateur gets its
# checkout from the derived loop, out of schedule/realisateur.conf's REPO_URL.
clone_or_update scheduler "https://github.com/$GH_OWNER/scheduler.git"

# EVERY OTHER REPO IS DERIVED, NOT TYPED. schedule/<p>.conf already declares
# REPO_URL per project -- that IS the registry. A typed list here would be a
# second source that drifts from it, which is the failure realisateur's own
for p in ${SELFDEV_PROJECTS:-senechal ecosim}; do
  conf="$PROJECTS/scheduler/schedule/$p.conf"
  if [ ! -f "$conf" ]; then bad "$p: no schedule/$p.conf -- not a registered project"; continue; fi
  url="$(grep -hE '^REPO_URL=' "$conf" | head -1 | cut -d'"' -f2)"
  [ -n "$url" ] || { bad "$p: schedule/$p.conf declares no REPO_URL"; continue; }
  clone_or_update "$p" "$url"
done

# THE CHICKEN-AND-EGG: installe is itself a verb, and it is the tool that
# installs verbs. So no build present means one gets installed here, by the
# script that OWNS the verb-build layout -- never by an `ln -sf` of our own,
# which would make this a third reader of it (propagation.test.sh case 6b).
#
# TRAP: if that cannot happen -- no credential for the meta-repo, no network --
#   the installer exits non-zero (3 is its BLIND) and this reports BAD rather
#   than going on to install-verbs.sh with no installe to route through.
#
# BOTH RUN FROM $LIBEXEC, never from a clone. wire-release-channel.sh --host
# --apply puts them there, and setup-selfdev-project.sh already refuses to
# reach this script until it has (it needs $LIBEXEC/selfdev-gh-app.sh at 4/8).
if ! command -v installe >/dev/null 2>&1; then
  if [ -x "$LIBEXEC/install-verb-build.sh" ]; then
    act "installe: bootstrap by installing the pinned verb build"
    if "$LIBEXEC/install-verb-build.sh" --latest --apply --link; then
      command -v installe >/dev/null 2>&1 \
        && ok "verb build installed; installe on PATH" \
        || bad "the verb build installed but installe is still not on PATH"
    else
      bad "could not install a verb build (see above) -- no verb can be installed on this host"
    fi
  else
    bad "no $LIBEXEC/install-verb-build.sh -- cannot obtain a verb build, so no verb can be installed. Install the host tools first: sudo wire-release-channel.sh --host --apply"
  fi
else ok "installe already on PATH"; fi

# NO SHIM STEP (#264, #511). User commands and hooks ride the verb build --
# carried in bin/lib/carries.tsv, installed by install-verb-build.sh above --
# and the settings.json half is selfdev-hooks-provision.sh, root's own step.
if [ -x "$LIBEXEC/install-verbs.sh" ]; then
  act "install-verbs.sh --apply (every write routed through installe)"
  "$LIBEXEC/install-verbs.sh" --apply \
    && ok "verb surface installed" || gap "install-verbs.sh reported gaps -- read them above"
else
  gap "no $LIBEXEC/install-verbs.sh -- the verb surface was not checked (sudo wire-release-channel.sh --host --apply)"
fi

# --- stop here ---------------------------------------------------------------
echo
echo "== dispatch preview (NOTHING armed) =="
if [ -x "$PROJECTS/scheduler/bin/sync-crontab.sh" ]; then
  ( cd "$PROJECTS/scheduler" && ./bin/sync-crontab.sh ) || true
fi
cat <<EOF

land-selfdev: $PASS ok, $GAPS missing, $BAD bad.

NOTHING IS SCHEDULED YET, deliberately. Read the preview above; there must be
ZERO lines beginning "ERROR [". Then, and only as a separate act:

    cd $PROJECTS/scheduler && ./bin/sync-crontab.sh --apply

Arming dispatch is the one step that spends a shared quota, and on this
ecosystem's accounting mandark, dexter and this host all draw on the same
weekly budget.
EOF
[ "$BAD" -eq 0 ]
