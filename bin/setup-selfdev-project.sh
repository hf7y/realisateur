#!/usr/bin/env bash
# setup-selfdev-project.sh -- stand up ONE new self-dev project account, end to
# end, in a single root command.
#
# TRAPS (the rest of this header is in the vault):
# WHAT IT RUNS, in order, each already proven on its own:
#   1. bin/provision-selfdev-user.sh <p> --apply   (root)  account + creds
#   2. the hands key into <p>'s authorized_keys    (root)  see --no-key
#   3. bin/wire-selfdev-git.sh <repo> --apply      (as <p>) per-repo deploy keys
#   4. bin/land-selfdev.sh --land                  (as <p>) clones + verbs
#   5. the App credential, host-wide               (root)  see 5/8 below
#   6. the RELEASE BOOTSTRAP + its clock            (as <p>) see below
#   7. bin/selfdev-permissions-provision.sh        (root)  the permissions
#      block, without which the account's first unattended night cannot write
#      .claude/** at all (hf7y/realisateur#282)
#   8. bin/selfdev-hooks-provision.sh              (root)  the SubagentStop hook (#272)

set -uo pipefail

PROJECT="${1:-}"; shift 2>/dev/null || true
MODE="--check"; WANT_KEY=1
for a in "$@"; do
  case "$a" in
    --check|--apply) MODE="$a" ;;
    --no-key)        WANT_KEY=0 ;;
    *) echo "usage: $0 <project> [--check|--apply] [--no-key]" >&2; exit 2 ;;
  esac
done
case "$PROJECT" in ""|-*) echo "usage: $0 <project> [--check|--apply] [--no-key]" >&2; exit 2 ;; esac

[ "$(id -u)" -eq 0 ] || { echo "$0: run as root (sudo bash $0 $PROJECT $MODE)" >&2; exit 2; }

HERE="$(cd "$(dirname "$0")" && pwd)"
HOST="$(hostname -s 2>/dev/null || echo unknown)"
# Whose key, and whose repo checkout, we are working from. Under sudo this is
# the human; run as root proper it is root, and then --no-key is the only
# sensible mode because root's authorized_keys is not a project credential.
HANDS="${SUDO_USER:-root}"
HANDS_HOME="$(getent passwd "$HANDS" | cut -d: -f6)"

say() { printf '\n== %s ==\n' "$*"; }
die() { printf '\nsetup-selfdev-project: %s\n' "$*" >&2; exit 5; }

echo "== setup-selfdev-project $PROJECT ($MODE) on $HOST, hands=$HANDS =="

for s in provision-selfdev-user.sh wire-selfdev-git.sh land-selfdev.sh; do
  [ -x "$HERE/$s" ] || die "$HERE/$s missing or not executable -- this script only sequences the three, it does not reimplement them"
done

if [ "$MODE" = --check ]; then
  echo "  would run, in order:"
  echo "    1. provision-selfdev-user.sh $PROJECT --apply       (account, claude + gh creds)"
  [ "$WANT_KEY" -eq 1 ] && echo "    2. copy $HANDS's authorized_keys into /home/$PROJECT/.ssh/" \
                        || echo "    2. SKIPPED (--no-key)"
  echo "    3. wire-selfdev-git.sh for realisateur, scheduler, senechal, $PROJECT"
  echo "    4. land-selfdev.sh --land as $PROJECT"
  echo "    5. selfdev-app-key.sh --apply: the host-wide GitHub App credential,"
  echo "       and $PROJECT into the group that can read it"
  echo "    6. release bootstrap into ~$PROJECT/.local/libexec/selfdev/, then"
  echo "       selfdev-release-tick.sh --install-cadence --apply as $PROJECT"
  echo "    7. selfdev-permissions-provision.sh --apply: the permissions block"
  echo "    8. selfdev-hooks-provision.sh --apply: the SubagentStop closeout hook"
  echo
  echo "  it will NOT arm dispatch: that is a 0->1 in schedule/_paced.$HOST.conf."
  echo "Next: sudo bash $0 $PROJECT --apply"
  exit 0
fi

# --- 1. the account ----------------------------------------------------------
say "1/8 account + credentials"
"$HERE/provision-selfdev-user.sh" "$PROJECT" --apply || die "provisioning failed -- nothing after this can work; read its rows above"

HOME_DIR="$(getent passwd "$PROJECT" | cut -d: -f6)"
[ -n "$HOME_DIR" ] || die "no home for $PROJECT after provisioning"

# --- 2. the hands key --------------------------------------------------------
say "2/8 ssh access for the hands account"
if [ "$WANT_KEY" -eq 0 ]; then
  echo "  SKIP    --no-key given; $PROJECT will need a root sitting for every later step"
elif [ ! -r "$HANDS_HOME/.ssh/authorized_keys" ]; then
  echo "  MISSING $HANDS_HOME/.ssh/authorized_keys unreadable -- no key copied"
else
  install -d -m 700 -o "$PROJECT" -g "$PROJECT" "$HOME_DIR/.ssh"
  install -m 600 -o "$PROJECT" -g "$PROJECT" "$HANDS_HOME/.ssh/authorized_keys" "$HOME_DIR/.ssh/authorized_keys"
  # chown -R, never a final-component chown: the exact bug that left ecosim's
  # ~/.local root-owned and killed its first dispatch.
  chown -R "$PROJECT:$PROJECT" "$HOME_DIR/.ssh"
  echo "  OK      $HOME_DIR/.ssh/authorized_keys installed from $HANDS"
fi

# --- 3 + 4. everything unprivileged -----------------------------------------
# Run as the project user with a LOGIN-shaped PATH. Ubuntu's .profile only adds
# ~/.local/bin at login, and `sudo -u x cmd` is not one -- that omission is what
# made land-selfdev.sh report "FATAL: installe is not on PATH" from the script
# that had just linked it (vault:realisateur/MONKEY.md 8.1).
run_as() {
  sudo -u "$PROJECT" -H env -i \
    HOME="$HOME_DIR" USER="$PROJECT" LOGNAME="$PROJECT" \
    PATH="$HOME_DIR/.local/bin:/usr/local/bin:/usr/bin:/bin" \
    SELFDEV_PROJECTS="senechal $PROJECT" \
    bash -lc "$1"
}

# STAGE, don't reach across accounts. $HERE is whatever checkout this script
# was invoked from -- typically an EXISTING project account's own realisateur
# clone, e.g. bibliothecaire's -- and every project home is 0700 (provisioned
# that way on purpose: "repos and working state are isolated per project").
# `sudo -u "$PROJECT"` therefore cannot read, let alone execute, a sibling
#   [rest of this note: vault:realisateur/guard-archaeology-20260817.md]
STAGE="$HOME_DIR/.selfdev-setup"
install -d -m 700 -o "$PROJECT" -g "$PROJECT" "$STAGE"
install -m 700 -o "$PROJECT" -g "$PROJECT" \
  "$HERE/wire-selfdev-git.sh" "$HERE/land-selfdev.sh" "$STAGE/"

say "3/8 git credentials, per repo"
# THE PIPE USED TO EAT THE ANSWER. wire-selfdev-git.sh already fails loud on
# its own: its "6. the witness" section runs `git ls-remote` against the freshly
# wired alias and exits 5 on `BAD WITNESS FAILED: ... the wiring is not live`.
# That exit went into `| sed`, and this script sets `set -uo pipefail` but never
# `set -e` and read neither $? nor PIPESTATUS -- so a repo whose credentials
#   [rest of this note: vault:realisateur/guard-archaeology-20260817.md]
wire_failed=""
for repo in realisateur scheduler senechal "$PROJECT"; do
  access=""
  # READ-WRITE only for the account's own repo; read-only for the three shared.
  [ "$repo" = "$PROJECT" ] && access="--rw"
  echo "  -- $repo ${access:---read-only}"
  run_as "'$STAGE/wire-selfdev-git.sh' '$repo' --apply $access" 2>&1 | sed 's/^/     /'
  rc="${PIPESTATUS[0]}"
  if [ "$rc" -ne 0 ]; then
    echo "     FAILED  wire-selfdev-git.sh $repo exited $rc -- $repo is NOT wired for $PROJECT"
    wire_failed="$wire_failed $repo(rc=$rc)"
  fi
done
[ -z "$wire_failed" ] || die "git wiring FAILED for:$wire_failed
Stopping at 3/4: landing and the release bootstrap both assume every repo above
is reachable, and an account landed on broken credentials fails later, on its
first unattended run, as something else. Read the rows above (a WITNESS FAILED
line means the key exists and GitHub did not accept it), then re-run:
    sudo -u $PROJECT -H $STAGE/wire-selfdev-git.sh <repo> --apply [--rw]
and re-run this script when every repo wires clean; the steps before this one
are idempotent."

say "4/8 land"
run_as "'$STAGE/land-selfdev.sh' --land" 2>&1 | tail -25

# --- 5. the release bootstrap, and the account's own clock -------------------
# DELEGATED to bin/wire-release-channel.sh since 2026-08-10, not reimplemented.
# It was inline here, which meant the only way to give an account a clock was
# to run account creation at it -- so nine of monkey's ten accounts never got
# one and the release channel sat at one consumer for five days. That script
#   [rest of this note: vault:realisateur/guard-archaeology-20260817.md]
say "5/8 the GitHub App credential (host-wide)"
if [ -x "$HERE/selfdev-app-key.sh" ]; then
  # rc read from the command, not from a pipeline whose last stage is `sed`.
  # `set -o pipefail` is on here and would carry it, but the 3/4 block in this
  # same file records what that assumption cost once already.
  appkey_out="$("$HERE/selfdev-app-key.sh" --apply --owner "${SELFDEV_GH_OWNER:-hf7y}" 2>&1)"; appkey_rc=$?
  printf '%s\n' "$appkey_out" | sed 's/^/  /'
  if [ "$appkey_rc" -eq 0 ]; then
    echo "  OK      $PROJECT can read the host-wide App key"
  else
    echo "  BAD     selfdev-app-key.sh --apply failed -- $PROJECT cannot mint an App token."
    echo "          This is not fatal to the rest of provisioning, but the account is"
    echo "          incomplete: fix it with \`sudo $HERE/selfdev-app-key.sh --check\` before arming."
  fi
else
  echo "  MISSING $HERE/selfdev-app-key.sh -- cannot place the App credential"
fi

say "6/8 release bootstrap + clock"
"$HERE/wire-release-channel.sh" "$PROJECT" --apply

# --- 7. the permissions block ------------------------------------------------
# Without this, the account's FIRST unattended night hits the harness's
# sensitive-file gate on any `.claude/**` write and cannot record what it did
# (hf7y/realisateur#282, worked example: vim-arcade@monkey 2026-08-04 shipped
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
say "7/8 permissions block"
ACCOUNTS="$PROJECT" "$HERE/selfdev-permissions-provision.sh" --apply --strict \
  || echo "  WARN    $PROJECT still has no permissions block -- its first unattended run will not be able to write .claude/**"

# --- 8. the SubagentStop closeout hook, same boundary as step 7 (#272) ------
say "8/8 SubagentStop closeout hook"
ACCOUNTS="$PROJECT" "$HERE/selfdev-hooks-provision.sh" --apply --strict \
  || echo "  WARN    $PROJECT still has no SubagentStop hook wired -- a dirty tree at exit will not be caught"
echo "  DO      notify-senechal 'realisateur selfdev-release-tick cron in $PROJECT@$HOST crontab, owned by realisateur'"

cat <<EOF

== $PROJECT is landed and NOT armed ==

Arming is one reviewed change, deliberately not made here:

  1. in the scheduler repo, schedule/_paced.$HOST.conf: flip $PROJECT's row
     from |0| to |1|, commit, push.
  2. as $PROJECT on this host:
       cd ~/Documents/Projects/scheduler && git pull --ff-only \\
         && ./bin/sync-crontab.sh --apply
  3. confirm schedule/FREEZE names $PROJECT@$HOST -- without it, freeze-check
     refuses dispatch no matter what the rotation says.

Adding a participant spends a shared weekly quota. That is a judgment, and it
is why every guard in this ecosystem stops one step short of it.
EOF
