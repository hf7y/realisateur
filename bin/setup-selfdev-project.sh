#!/usr/bin/env bash
# setup-selfdev-project.sh -- stand up ONE new self-dev project account, end to
# end, in a single root command.
# TRAPS (the rest of this header is in the vault):
# WHAT IT RUNS, in order, each already proven on its own:
#   1. bin/provision-selfdev-user.sh <p> --apply   (root)  account + creds
#   2. the hands key into <p>'s authorized_keys    (root)  see --no-key
#   3. bin/wire-selfdev-git.sh <repo> --apply      (as <p>) per-repo deploy keys
#   4. the App credential + selfdev-gh-app.sh --wire  (root, as <p>) see 4/8
#   5. bin/land-selfdev.sh --land                  (as <p>) clones + verbs
#   6. the RELEASE BOOTSTRAP + its clock            (as <p>) see below
#   7. bin/selfdev-permissions-provision.sh        (root)  the permissions
#      block, without which the account's first unattended night cannot write
#      .claude/** at all (hf7y/realisateur#282)
#   8. bin/selfdev-hooks-provision.sh              (root)  the SubagentStop hook (#272)
#   9. the project's own runtime secrets           (root)  REPORTED, not supplied (#289)

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
  echo "    4. selfdev-app-key.sh --apply: the host-wide GitHub App credential, and"
  echo "       $PROJECT into the group that can read it; then selfdev-gh-app.sh"
  echo "       --wire as $PROJECT, without which no https clone can authenticate"
  echo "    5. land-selfdev.sh --land as $PROJECT"
  echo "    6. release bootstrap into ~$PROJECT/.local/libexec/selfdev/, then"
  echo "       selfdev-release-tick.sh --install-cadence --apply as $PROJECT"
  echo "    7. selfdev-permissions-provision.sh --apply: the permissions block"
  echo "    8. selfdev-hooks-provision.sh --apply: the SubagentStop closeout hook"
  echo
  echo "  it will NOT arm dispatch: that is a human editing the state column for"
  echo "  $PROJECT in scheduler's schedule/ROSTER (the sole arming authority, #364)."
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
# that had just linked it.
run_as() {
  sudo -u "$PROJECT" -H env -i \
    HOME="$HOME_DIR" USER="$PROJECT" LOGNAME="$PROJECT" \
    PATH="$HOME_DIR/.local/bin:/usr/local/bin:/usr/bin:/bin" \
    SELFDEV_PROJECTS="$PROJECT" \
    bash -lc "cd '$HOME_DIR' || exit 1; $1"
}

# STAGE, don't reach across accounts: $HERE is typically another project's
# realisateur clone, and every project home is 0700 (see run_as).
STAGE="$HOME_DIR/.selfdev-setup"
install -d -m 700 -o "$PROJECT" -g "$PROJECT" "$STAGE"
install -m 700 -o "$PROJECT" -g "$PROJECT" \
  "$HERE/wire-selfdev-git.sh" "$HERE/land-selfdev.sh" "$STAGE/"

say "3/8 git credentials, per repo"
# THE PIPE USED TO EAT THE ANSWER. wire-selfdev-git.sh already fails loud on
# its own: its "6. the witness" section runs `git ls-remote` against the freshly
# wired alias and exits 5 on `BAD WITNESS FAILED: ... the wiring is not live`.
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

# BEFORE LANDING (#692): land-selfdev.sh clones over https, which step 3's
# deploy keys do not serve. --apply makes the key readable, --wire makes git use it.
say "4/8 the GitHub App credential (host-wide key, then this account's git helper)"
if [ -x "$HERE/selfdev-app-key.sh" ]; then
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/estate-set.sh"
  appkey_out="$("$HERE/selfdev-app-key.sh" --apply --owner "${SELFDEV_GH_OWNER:-$GH_ESTATE_OWNER}" 2>&1)"; appkey_rc=$?  # rc from the command, not a pipeline (see 3/4's pipefail note)
  printf '%s\n' "$appkey_out" | sed 's/^/  /'
  [ "$appkey_rc" -eq 0 ] && echo "  OK      $PROJECT can read the host-wide App key" \
    || die "selfdev-app-key.sh --apply failed -- $PROJECT cannot mint an App token, so
the clone in 5/8 has no credential and would report 'landed' over a failure.
Fix it with \`sudo $HERE/selfdev-app-key.sh --check\`, then re-run; every step
above is idempotent."
else
  die "$HERE/selfdev-app-key.sh missing -- cannot place the App credential"
fi

GH_APP="${SELFDEV_LIBEXEC:-/usr/local/libexec/selfdev}/selfdev-gh-app.sh"
[ -x "$GH_APP" ] || die "$GH_APP is not installed, so $PROJECT gets no git credential
helper and cannot clone over https. Install the host tools first:
    sudo $HERE/wire-release-channel.sh --host --apply"
run_as "'$GH_APP' --wire --repos '$PROJECT'" 2>&1 | sed 's/^/  /'
[ "${PIPESTATUS[0]}" -eq 0 ] || die "selfdev-gh-app.sh --wire failed for $PROJECT -- no git
credential helper, so the clone in 5/8 cannot authenticate. Read the rows above."

# A STEP THAT CANNOT FAIL IS NOT A STEP: `| tail -25` dropped the status.
say "5/8 land"
land_out="$(run_as "'$STAGE/land-selfdev.sh' --land" 2>&1)"; land_rc=$?
printf '%s\n' "$land_out" | tail -25
[ "$land_rc" -eq 0 ] || die "land-selfdev.sh exited $land_rc -- $PROJECT is NOT landed.
Its own summary line above counts the BAD rows; the full output is longer than
the 25 lines shown. Re-run it directly to see all of them:
    sudo -u $PROJECT -H $STAGE/land-selfdev.sh --land"

# --- 6. the release bootstrap, and the account's own clock -------------------
# DELEGATED to bin/wire-release-channel.sh since 2026-08-10, not reimplemented.
# It was inline here, which meant the only way to give an account a clock was
say "6/8 release bootstrap + clock"
"$HERE/wire-release-channel.sh" "$PROJECT" --apply

# --- 7. the permissions block ------------------------------------------------
# Without this, the account's FIRST unattended night hits the harness's
# sensitive-file gate on any `.claude/**` write and cannot record what it did
say "7/8 permissions block"
ACCOUNTS="$PROJECT" "$HERE/selfdev-permissions-provision.sh" --apply --strict \
  || echo "  WARN    $PROJECT still has no permissions block -- its first unattended run will not be able to write .claude/**"

# --- 8. the SubagentStop closeout hook, same boundary as step 7 (#272) ------
say "8/8 SubagentStop closeout hook"
ACCOUNTS="$PROJECT" "$HERE/selfdev-hooks-provision.sh" --apply --strict \
  || echo "  WARN    $PROJECT still has no SubagentStop hook wired -- a dirty tree at exit will not be caught"
echo "  DO      notify-senechal 'realisateur selfdev-release-tick cron in $PROJECT@$HOST crontab, owned by realisateur'"

# --- 9. the project's OWN runtime secrets: DECLARED, never supplied ----------
# #289's boundary, stated. This provisions what the ECOSYSTEM needs; a
# project's own credentials stay on the workstation. Copying them here would
# widen the blast radius #171 spent itself narrowing.
#
# It owes the difference between "needs none" and "needs some and has none":
# a project declares them in `.selfdev-secrets`, one path per line.
say "9/9 the project's own runtime secrets"
SECRETS_DECL="$HOME_DIR/Documents/Projects/$PROJECT/.selfdev-secrets"
if [ ! -r "$SECRETS_DECL" ]; then
  echo "  --      $PROJECT declares no runtime secrets (.selfdev-secrets absent)."
  echo "          If it needs any, that file is where it says so; nothing here supplies them."
else
  missing=0
  while IFS= read -r want; do
    case "$want" in ''|\#*) continue ;; esac
    # Runs as root, which can stat a path a project owns; no sudo hop.
    if [ -e "$want" ]; then
      echo "  OK      $want"
    else
      echo "  MISSING $want -- $PROJECT cannot do its own work without it"
      missing=$((missing + 1))
    fi
  done < "$SECRETS_DECL"
  [ "$missing" -gt 0 ] && \
    echo "  DO      put those in place as $PROJECT by hand. This script will not: they are the project's, not the ecosystem's."
fi

cat <<EOF

== $PROJECT is landed and NOT armed ==

Arming is one reviewed change, deliberately not made here:

  1. in a scheduler clone -- conf fields + the rotation row, mechanically:
       $HERE/enrole-selfdev.sh $PROJECT --check      # writes nothing
       $HERE/enrole-selfdev.sh $PROJECT --apply      # then review its diff, PR it
     (it is idempotent, and --retire is its exact reverse)
  2. as $PROJECT on this host, once that lands:
       $HERE/enrole-selfdev.sh $PROJECT --apply --sync
     which is `git pull --ff-only && ./bin/sync-crontab.sh --apply` as $PROJECT.

Adding a participant spends a shared weekly quota. That is a judgment, and it
is why every guard in this ecosystem stops one step short of it.
EOF
