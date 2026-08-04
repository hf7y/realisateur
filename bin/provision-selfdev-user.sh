#!/usr/bin/env bash
# provision-selfdev-user.sh -- add a self-dev project account to this host.
#
# RUN THIS ON THE SELF-DEV HOST, as a user who can sudo. It creates ONE unix
# account for ONE project, exactly as MONKEY.md describes the topology, and
# copies the shared Claude credential into it so the account can actually
# spend a token.
#
#   ./provision-selfdev-user.sh <project>              --check (default)
#   ./provision-selfdev-user.sh <project> --apply
#
# WHY THIS EXISTS. `ecosim`, the first such account, was created by hand in a
# root sitting on 2026-08-03. Every step was reconstructed from memory into a
# shell, and two of them were wrong in ways that only showed up later:
#
#   * `install -d -m 755 -o ecosim ... /home/ecosim/.local/bin` chowns only the
#     FINAL component, so /home/ecosim/.local stayed root-owned and the paced
#     runner could not create its own lockfile. The first dispatch died on it.
#   * the credential was placed by three separate ad-hoc commands, none of
#     which was written down anywhere a second account could reuse.
#
# Zach, 2026-08-03, on the topology: "each account shares one claude auth token
# that has been copied. should get copied automatically." This is that.
#
# WHAT IT DELIBERATELY DOES NOT DO:
#   * no sudo for the project account. A self-dev user needs nothing outside
#     $HOME; if a run believes otherwise that is a finding to surface, not a
#     capability to pre-grant. (The office's `romulus` has blanket NOPASSWD
#     because it binds a port and manages a service. This is not that.)
#   * no clone, no install, no crontab. `bin/land-selfdev.sh` does those, as
#     the project user, and stops before arming dispatch.
#   * no rotation edit. Adding a participant is realisateur's judgment and
#     lands in schedule/_paced.<host>.conf through a reviewed change.

set -uo pipefail

PROJECT="${1:-}"
MODE="${2:---check}"
case "$PROJECT" in ""|-*) echo "usage: $0 <project> [--check|--apply]" >&2; exit 2 ;; esac
case "$MODE" in --check|--apply) ;; *) echo "usage: $0 <project> [--check|--apply]" >&2; exit 2 ;; esac

# The uid band MONKEY.md reserves for self-dev projects: clear of the human
# 1000s and of the office's romulus=1001, so a future merge of conventions
# cannot collide.
UID_MIN="${SELFDEV_UID_MIN:-3000}"
UID_MAX="${SELFDEV_UID_MAX:-3099}"
# Where the credential is read FROM. The invoking user's own, by default --
# one identity, one quota, which is the accepted topology.
# RUN AS ROOT, OR AS A USER WHO CAN SUDO -- both work, and the difference
# matters for exactly one thing: whose credential gets copied.
#
# Under `sudo bash provision-selfdev-user.sh ...` (which is how an unattended
# caller with no tty must invoke it, since sudo's timestamp is per-tty and
# `sudo -v` buys nothing here), $HOME is root's. Looking for the credential
# there would silently find nothing and provision an account that cannot spend
# a token -- the exact failure this script exists to prevent. So when running
# as root, fall back to SUDO_USER's home.
CRED_HOME="$HOME"
if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
  CRED_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  [ -n "$CRED_HOME" ] || CRED_HOME="$HOME"
fi
SRC_SETTINGS="${SELFDEV_TOKEN_SRC:-$CRED_HOME/.claude/settings.json}"
SRC_TOKEN_FILE="${SELFDEV_TOKEN_FILE:-$CRED_HOME/.claude-token}"

PASS=0; GAPS=0; BAD=0
ok()  { printf '  OK      %s\n' "$*"; PASS=$((PASS+1)); }
gap() { printf '  MISSING %s\n' "$*"; GAPS=$((GAPS+1)); }
bad() { printf '  BAD     %s\n' "$*"; BAD=$((BAD+1)); }
act() { printf '  DO      %s\n' "$*"; }
die() { printf 'provision-selfdev-user: FATAL %s\n' "$*" >&2; exit 1; }

HOME_DIR="/home/$PROJECT"
echo "== provision-selfdev-user $PROJECT ($MODE) on $(hostname -s) =="

# --- where does the token come from ------------------------------------------
# Read it now, in --check too, because "there is a credential to copy" is the
# single fact this script exists to act on. Never printed.
TOKEN=""
if [ -f "$SRC_SETTINGS" ]; then
  TOKEN="$(python3 -c "import json;print(json.load(open('$SRC_SETTINGS')).get('env',{}).get('CLAUDE_CODE_OAUTH_TOKEN',''))" 2>/dev/null || true)"
  [ -n "$TOKEN" ] && ok "source credential: $SRC_SETTINGS (env block)"
fi
if [ -z "$TOKEN" ] && [ -f "$SRC_TOKEN_FILE" ]; then
  TOKEN="$(cat "$SRC_TOKEN_FILE" 2>/dev/null || true)"
  [ -n "$TOKEN" ] && ok "source credential: $SRC_TOKEN_FILE"
fi
[ -n "$TOKEN" ] || bad "no credential to copy -- looked in $SRC_SETTINGS (env block) and $SRC_TOKEN_FILE. Run \`claude setup-token\` first; a project account with no token dispatches and produces NOTHING, silently."

# --- account -----------------------------------------------------------------
if id "$PROJECT" >/dev/null 2>&1; then
  cur_uid="$(id -u "$PROJECT")"
  if [ "$cur_uid" -ge "$UID_MIN" ] && [ "$cur_uid" -le "$UID_MAX" ]; then
    ok "account $PROJECT exists, uid $cur_uid (in the self-dev band)"
  else
    bad "account $PROJECT exists at uid $cur_uid, OUTSIDE the self-dev band $UID_MIN-$UID_MAX -- refusing to adopt an account this script did not create"
  fi
else
  # Lowest free uid in the band, so accounts are dense and predictable.
  NEXT=""
  for u in $(seq "$UID_MIN" "$UID_MAX"); do
    id -u "$u" >/dev/null 2>&1 || { NEXT="$u"; break; }
  done
  [ -n "$NEXT" ] || bad "no free uid in $UID_MIN-$UID_MAX"
  gap "account $PROJECT does not exist (would create at uid ${NEXT:-?})"
fi

if [ "$(id -u)" -eq 0 ]; then
  ok "running as root (credential read from ${SUDO_USER:-root}'s home)"
elif sudo -n true >/dev/null 2>&1; then
  ok "passwordless sudo available"
else
  gap "sudo will prompt and there may be no tty -- invoke as: sudo $0 $PROJECT --apply"
fi

if [ "$MODE" = --check ]; then
  echo
  printf 'check only, nothing changed: %d ok, %d missing, %d bad\n' "$PASS" "$GAPS" "$BAD"
  [ "$BAD" -eq 0 ] || { echo "resolve the BAD rows before --apply."; exit 5; }
  echo "Next: $0 $PROJECT --apply"
  exit 0
fi

[ "$BAD" -eq 0 ] || die "refusing to apply with $BAD BAD row(s) above"

# --- apply -------------------------------------------------------------------
if ! id "$PROJECT" >/dev/null 2>&1; then
  NEXT=""
  for u in $(seq "$UID_MIN" "$UID_MAX"); do id -u "$u" >/dev/null 2>&1 || { NEXT="$u"; break; }; done
  [ -n "$NEXT" ] || die "no free uid in $UID_MIN-$UID_MAX"
  act "useradd $PROJECT uid=$NEXT"
  sudo useradd -u "$NEXT" -m -s /bin/bash "$PROJECT" || die "useradd failed"
fi

# 0700: repos and working state are isolated per project. SPEND is not, and
# cannot be, because the credential is shared -- said out loud here because a
# reader could otherwise mistake this mode for budget isolation.
act "home 0700, and the WHOLE tree owned by $PROJECT"
sudo chmod 700 "$HOME_DIR"
# chown -R, not `install -d -o`: install chowns only the final component, which
# is exactly how /home/ecosim/.local ended up root-owned and broke the first
# dispatch. This is the bug this script exists to stop repeating.
sudo chown -R "$PROJECT:$PROJECT" "$HOME_DIR"

# Ubuntu's ~/.profile only prepends ~/.local/bin if it EXISTS AT LOGIN. Created
# later, it is not on PATH until the next login -- a shim installed correctly
# that still cannot be found.
act "~/.local/bin, before the account's first login"
sudo -u "$PROJECT" mkdir -p "$HOME_DIR/.local/bin" "$HOME_DIR/.local/share" "$HOME_DIR/.claude"
sudo -u "$PROJECT" chmod 700 "$HOME_DIR/.claude"

act "linger (a --user unit outlives logout; cheap now, needs root later)"
sudo loginctl enable-linger "$PROJECT" >/dev/null 2>&1 || gap "enable-linger failed"

# No sudoers file. Stated as an action so its ABSENCE is visible in the log.
act "no sudoers entry for $PROJECT (deliberate)"
sudo rm -f "/etc/sudoers.d/90-$PROJECT"

# --- the credential ----------------------------------------------------------
# Written as the project user, via a mode-600 temp file, so the token never
# appears in argv (visible in ps to any local user) and never transits a
# world-readable path.
act "copy the shared credential into $PROJECT's settings.json"
TMP="$(mktemp)"; chmod 600 "$TMP"
printf '%s' "$TOKEN" > "$TMP"
sudo install -m 600 -o "$PROJECT" -g "$PROJECT" "$TMP" "$HOME_DIR/.claude-token"
shred -u "$TMP" 2>/dev/null || rm -f "$TMP"
sudo -u "$PROJECT" python3 - "$HOME_DIR" <<'PY'
import json, pathlib, sys
home = pathlib.Path(sys.argv[1])
tok = (home / ".claude-token").read_text().strip()
p = home / ".claude" / "settings.json"
d = json.loads(p.read_text()) if p.exists() else {}
d.setdefault("env", {})["CLAUDE_CODE_OAUTH_TOKEN"] = tok
p.write_text(json.dumps(d, indent=2) + "\n")
p.chmod(0o600)
PY

# --- the OTHER credential ------------------------------------------------------
# gh, on the same argument as the claude token above, and added 2026-08-03 for
# the same reason the rest of this script exists: bibliothecaire was the second
# account, and this was the step still being done by hand.
#
# WHY AN ACCOUNT NEEDS IT AT ALL. Two distinct jobs, and only the first is
# obvious. (1) bin/wire-selfdev-git.sh registers this account's per-repo deploy
# keys through `gh`, so without a token the account cannot obtain the git
# credentials it needs to clone anything private. (2) the work itself: the
# request queues these projects run on ARE GitHub issues -- bibliothecaire's
# brief is literally "work the issues labelled request", and ecosim filed #26
# and #27 the same way. An account with no gh is an account that cannot be
# asked for anything and cannot answer.
#
# THE TOKEN IS SHARED, not minted. Same topology as the claude credential, and
# the same accepted consequence: one identity, one audit trail. Least privilege
# between REPOS is bought by per-repo deploy keys (see wire-selfdev-git.sh), not
# by giving each account a different GitHub identity.
GH_SRC="${SELFDEV_GH_HOSTS:-$CRED_HOME/.config/gh/hosts.yml}"
if [ -r "$GH_SRC" ]; then
  # No `MODE` guard here: --check has already exited above. Everything from
  # this point down runs only under --apply.
  act "copy the shared gh credential into $PROJECT's hosts.yml"
  sudo install -d -m 700 -o "$PROJECT" -g "$PROJECT" "$HOME_DIR/.config" "$HOME_DIR/.config/gh"
  sudo install -m 600 -o "$PROJECT" -g "$PROJECT" "$GH_SRC" "$HOME_DIR/.config/gh/hosts.yml"
  # The witness is gh answering, not the file existing -- `gh auth status`
  # actually calls GitHub, which is the same distinction the claude witness
  # below draws between configuration and capability.
  if sudo -u "$PROJECT" -H env -i HOME="$HOME_DIR" PATH=/usr/local/bin:/usr/bin:/bin \
       gh auth status >/dev/null 2>&1; then
    ok "$PROJECT can reach GitHub as an authenticated user"
  else
    bad "$PROJECT's gh copy does not authenticate -- deploy keys cannot be registered and issue queues cannot be worked"
  fi
else
  gap "no gh credential at $GH_SRC -- $PROJECT will not be able to register deploy keys or work an issue queue. Run \`gh auth login\` as ${SUDO_USER:-$(id -un)} first."
fi

# --- witness -----------------------------------------------------------------
# Configuration is not capability. The only proof is a call, and it is made
# under a STRIPPED environment because that is how cron will make it.
echo
act "witness: a real call, as $PROJECT, with nothing inherited"
if sudo -u "$PROJECT" -H env -i HOME="$HOME_DIR" PATH=/usr/local/bin:/usr/bin:/bin \
     claude -p 'reply with the single word ok' </dev/null 2>&1 | grep -qi '^ok'; then
  ok "$PROJECT can spend a token under a cron-shaped environment"
else
  bad "$PROJECT could NOT spend a token -- the account exists but dispatch would produce nothing"
fi

echo
printf 'provisioned %s: %d ok, %d missing, %d bad\n' "$PROJECT" "$PASS" "$GAPS" "$BAD"
cat <<EOF

NOT LANDED AND NOT ARMED, deliberately. Next, as $PROJECT:
    bin/land-selfdev.sh --check      # then --land
and only then a reviewed change to schedule/_paced.$(hostname -s).conf plus
schedule/FREEZE. Adding a participant is a judgment, not a side effect of
creating an account.
EOF
[ "$BAD" -eq 0 ]
