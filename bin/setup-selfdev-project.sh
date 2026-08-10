#!/usr/bin/env bash
# setup-selfdev-project.sh -- stand up ONE new self-dev project account, end to
# end, in a single root command.
#
# RUN ON THE SELF-DEV HOST, AS ROOT (or via sudo):
#
#   sudo bash bin/setup-selfdev-project.sh <project> [--check|--apply] [--no-key]
#
# WHY THIS EXISTS. Zach, 2026-08-04, on what was still manual: "what is keeping
# this from being automated? lack of passwordless root on monkey?" Mostly yes --
# and the honest follow-up was that the three things needing root were the SAME
# requirement three times, spread across three sittings. This collapses them.
#
# `bibliothecaire`, account #2, took three interactive root sittings on
# 2026-08-04: create the account, install a key so the rest could be driven,
# copy the gh credential (a second run of the provisioner, after it learned to).
# Everything else ran unprivileged. This script is those three, in order, plus
# the unprivileged remainder, so account #3 is one command instead of an evening.
#
# WHAT IT RUNS, in order, each already proven on its own:
#   1. bin/provision-selfdev-user.sh <p> --apply   (root)  account + creds
#   2. the hands key into <p>'s authorized_keys    (root)  see --no-key
#   3. bin/wire-selfdev-git.sh <repo> --apply      (as <p>) per-repo deploy keys
#   4. bin/land-selfdev.sh --land                  (as <p>) clones + verbs
#   5. the RELEASE BOOTSTRAP + its clock            (as <p>) see below
#
# WHY STEP 5 IS HERE AND NOWHERE ELSE. The account consumes tooling from the
# verb release channel (`hf7y/verbs` build tags), not from a clone of any
# repo's `main` -- see bin/lib/propagation-set.sh for that decision and why
# `main` staying fast is the point of it. A build cannot deliver its own
# installer, so a small, near-immutable BOOTSTRAP has to exist on the account
# first: install-verb-build.sh, selfdev-release-tick.sh, and two libs. Four
# files, copied once, whose only job is to find, verify and install a
# versioned payload -- the gradlew/rustup shape.
#
# This script is the natural and only correct home for that copy, because it
# is the one thing that already runs EXACTLY ONCE PER ACCOUNT. Putting it in
# land-selfdev.sh would re-copy on every landing; putting it in the tick would
# make the bootstrap install itself, which is the circularity the bootstrap
# exists to cut.
#
# The clock goes in the ACCOUNT'S OWN crontab, installed BY the account. Pull,
# not push: a hands account reaching into a 0700 home over sudo does not scale
# past four accounts and leaves no record on the consumer side, so the account
# cannot answer "what version am I on, and when did I last look" without
# somebody else's shell history.
#
# WHAT IT DELIBERATELY DOES NOT DO: arm dispatch. That is a row in
# schedule/_paced.<host>.conf going from 0 to 1, it is a judgment about how a
# shared weekly quota is spent, and it stays a separate reviewed act. This
# script stops exactly where land-selfdev.sh stops, for the same reason.
#
# ABOUT STEP 2 (--no-key to skip). It copies the INVOKING human's
# authorized_keys into the project account, so the account can be driven over
# ssh without a further root sitting. This is not a privilege increase: the key
# it copies already belongs to a user who can sudo to root on this host, and
# therefore to this account. It IS a real grant, so it is one flag to decline
# and it is logged as an action rather than done quietly.
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
  echo "    5. release bootstrap into ~$PROJECT/.local/libexec/selfdev/, then"
  echo "       selfdev-release-tick.sh --install-cadence --apply as $PROJECT"
  echo
  echo "  it will NOT arm dispatch: that is a 0->1 in schedule/_paced.$HOST.conf."
  echo "Next: sudo bash $0 $PROJECT --apply"
  exit 0
fi

# --- 1. the account ----------------------------------------------------------
say "1/4 account + credentials"
"$HERE/provision-selfdev-user.sh" "$PROJECT" --apply || die "provisioning failed -- nothing after this can work; read its rows above"

HOME_DIR="$(getent passwd "$PROJECT" | cut -d: -f6)"
[ -n "$HOME_DIR" ] || die "no home for $PROJECT after provisioning"

# --- 2. the hands key --------------------------------------------------------
say "2/4 ssh access for the hands account"
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
# that had just linked it (MONKEY.md 8.1).
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
# script living under a different account's home: it fails as
# "Permission denied", not as a missing file, which looks like a broken
# install rather than what it is. Found running this script for real the
# first time, account #4 (vim-arcade, 2026-08-04). Fix: copy the two
# unprivileged scripts into THIS account's own home, owned by it, before
# calling them as it.
STAGE="$HOME_DIR/.selfdev-setup"
install -d -m 700 -o "$PROJECT" -g "$PROJECT" "$STAGE"
install -m 700 -o "$PROJECT" -g "$PROJECT" \
  "$HERE/wire-selfdev-git.sh" "$HERE/land-selfdev.sh" "$STAGE/"

say "3/4 git credentials, per repo"
for repo in realisateur scheduler senechal "$PROJECT"; do
  access=""
  # READ-WRITE only for the account's own repo; read-only for the three shared.
  [ "$repo" = "$PROJECT" ] && access="--rw"
  echo "  -- $repo ${access:---read-only}"
  run_as "'$STAGE/wire-selfdev-git.sh' '$repo' --apply $access" 2>&1 | sed 's/^/     /'
done

say "4/5 land"
run_as "'$STAGE/land-selfdev.sh' --land" 2>&1 | tail -25

# --- 5. the release bootstrap, and the account's own clock -------------------
# DELEGATED to bin/wire-release-channel.sh since 2026-08-10, not reimplemented.
# It was inline here, which meant the only way to give an account a clock was
# to run account creation at it -- so nine of monkey's ten accounts never got
# one and the release channel sat at one consumer for five days. That script
# has the whole argument; this is the same code with a second caller.
say "5/5 release bootstrap + clock"
"$HERE/wire-release-channel.sh" "$PROJECT" --apply
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
