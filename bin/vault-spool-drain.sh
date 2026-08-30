#!/usr/bin/env bash
# vault-spool-drain.sh -- THE FAR SIDE OF THE CLOSED VAULT DOOR (#742).
#
# Zach, 2026-08-29 and again 2026-08-30: "there should just not be reading at
# all." The vault is an archive -- prose goes there when it stops being true --
# so a citation is a retrieval of a premise that was already retired, and the
# door closes. Writing is explicitly unaffected, and that is what this exists
# to keep true.
#
# WHAT IT DOES. `consigne` on a host with a closed vault writes a REQUEST into
# /srv/vault-spool naming the absolute source paths (never their content). This
# runs as a user that CAN read the vault, hands those same paths to the same
# unmodified bibliothecaire lib/consign-prose.sh, and commits what landed.
#
# consign-prose is NOT MODIFIED and is not reimplemented here. Its three reads
# of the vault -- the not-a-repo refusal, the overwrite refusal, and the
# read-back gate -- are the archive's integrity, not the leak. They run here,
# on this side of the door, exactly as they always did.
#
# GIT'S OWNERSHIP CHECK IS THE TRAP. consign-prose derives provenance by
# running `git -C <source dir> rev-parse`, and the source lives in a self-dev
# account's home while this runs as root. Git refuses a repo it does not own
# ("dubious ownership") and consign-prose reads that refusal as "not inside a
# git repository", which is exit 6 BLIND -- a deposit that never happens, for
# a reason that has nothing to do with the deposit. safe.directory is set for
# this process only, via GIT_CONFIG_COUNT, not written into anyone's config.
#
# IT COMMITS AND DOES NOT PUSH. A deposit sitting uncommitted in a tree nobody
# can list is invisible, which is worse than the mandark failure #212 records;
# so the commit is not optional. The push needs a credential this has no
# business holding, and is still the reaping pass's job (PROSE-REAPING.md 5.6).
# An unpushed vault is REPORTED at the end of every drain, never assumed clean.
#
# A REQUEST IS NEVER DELETED UNTIL ITS DEPOSIT IS ACCOUNTED FOR. On success it
# is removed; on failure it is renamed `.failed` and left, with the reason, so
# the queue is a queue and not a leak.
set -uo pipefail

CLI_NAME='vault-spool-drain.sh'
CLI_SUMMARY='deposit every spooled request into the vault and commit it -- the privileged half of `consigne` on a host where the vault is closed to the accounts that deposit into it (#742)'
CLI_USAGE='  vault-spool-drain.sh             --check (default): report the queue, write nothing
  vault-spool-drain.sh --apply     deposit every request, commit, and clear the queue'
CLI_FLAGS='--check --apply --spool --vault'
CLI_POSITIONAL=any   # --spool/--vault take a value; cli_guard sees it as positional
CLI_EXITS='  0  nothing queued, or every queued request was deposited
  1  at least one request could not be deposited -- it is kept as .failed
  5  refused: --apply without a readable vault, or without write access to it
  6  BLIND: no spool directory, so the queue could not be measured at all --
     a 0-request pass on a missing spool is NOT a clean result'
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib/cli-guard.sh"
cli_guard "$@"

MODE=--check
SPOOL="${CONSIGNE_SPOOL:-/srv/vault-spool}"
VAULT="${BIBLIOTHECAIRE_VAULT:-/srv/ecosystem1-vault}"
while [ $# -gt 0 ]; do
  case "$1" in
    --check|--apply) MODE="$1" ;;
    --spool) shift; SPOOL="${1:-}" ;;
    --vault) shift; VAULT="${1:-}" ;;
    *) cli_die "unexpected argument: $1" ;;
  esac
  shift
done

say() { printf '%s\n' "$*"; }
die() { printf '%s: %s\n' "$CLI_NAME" "$*" >&2; exit "${2:-5}"; }

[ -d "$SPOOL" ] || {
  printf '%s: BLIND: no spool at %s -- the queue was not measured, which is NOT the same as empty.\n' \
    "$CLI_NAME" "$SPOOL" >&2
  printf '%s: provision it with `sudo vault-group-provision.sh --apply`.\n' "$CLI_NAME" >&2
  exit 6
}

# The queue, counted before anything is decided. Only this process's own view:
# the spool is deliberately unlistable to a depositor, so this listing is the
# one place the queue is visible at all.
mapfile -t REQS < <(find "$SPOOL" -maxdepth 1 -type f -name 'req-*' 2>/dev/null | sort)

say "== vault-spool-drain ($MODE) -- $(hostname -s), spool $SPOOL, vault $VAULT =="
say "   ${#REQS[@]} request(s) queued"

if [ "${#REQS[@]}" -eq 0 ]; then
  say "$CLI_NAME: nothing queued."
  exit 0
fi

for r in "${REQS[@]}"; do
  acct="$(sed -n 's/^account\t//p' "$r" | head -1)"
  n="$(grep -c '^path\t' "$r" 2>/dev/null)" || n=0
  say "   .. $(basename "$r")  account=${acct:-?}  paths=$n"
done

if [ "$MODE" = --check ]; then
  say
  say "Next: sudo $CLI_NAME --apply"
  exit 1
fi

# --apply from here. The vault must be readable AND writable by THIS process;
# a drainer that cannot commit turns the spool into a silent backlog.
[ -r "$VAULT" ] && [ -x "$VAULT" ] || die "cannot read $VAULT -- run --apply as the account that owns the vault (root, or its owner)" 5
[ -w "$VAULT" ] || die "cannot write $VAULT -- nothing would be deposited" 5

IMPL="${CONSIGNE_IMPL:-}"
if [ -z "$IMPL" ]; then
  # The same mechanism `consigne` forwards to, found the same way: through the
  # installed `fonde`'s own tree. Not re-derived from the build layout, which
  # bin/lib/propagation-set.sh reserves to the two scripts that own it.
  fonde_bin="$(command -v fonde 2>/dev/null)" || fonde_bin=''
  [ -n "$fonde_bin" ] && IMPL="$(cd "$(dirname "$(readlink -f "$fonde_bin")")/.." && pwd)/lib/consign-prose.sh"
fi
[ -n "$IMPL" ] && [ -r "$IMPL" ] \
  || die "cannot find lib/consign-prose.sh (looked through the installed \`fonde\`; set CONSIGNE_IMPL). Nothing was deposited." 5

# Provenance comes from the SOURCE repo, which belongs to a self-dev account
# and not to whoever is running this. Scoped to this process; nobody's gitconfig
# is edited. See the header -- this is the difference between a deposit and a
# BLIND that names the wrong cause.
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0='*'

OK=0; FAILED=0
for r in "${REQS[@]}"; do
  acct="$(sed -n 's/^account\t//p' "$r" | head -1)"
  mapfile -t paths < <(sed -n 's/^path\t//p' "$r")
  if [ "${#paths[@]}" -eq 0 ]; then
    mv -- "$r" "$r.failed" && printf 'no path rows\n' > "$r.failed.why"
    say "  BAD     $(basename "$r") -- no path rows; kept as $(basename "$r").failed"
    FAILED=$((FAILED+1)); continue
  fi

  say "  ..      $(basename "$r") ($acct): ${#paths[@]} path(s)"
  # Serialized against every other writer of this vault on the identical lock
  # `consigne` itself takes (#213) -- a reaping pass's `consigne lock -- git
  # commit` and this drain must not interleave.
  if flock -w 60 "$VAULT/.consigne.lock" bash "$IMPL" "$VAULT" "${paths[@]}"; then
    rm -f -- "$r"
    OK=$((OK+1))
  else
    rc=$?
    mv -- "$r" "$r.failed" && printf 'consign-prose exit %s\n' "$rc" > "$r.failed.why"
    say "  BAD     $(basename "$r") -- consign-prose exited $rc; kept as $(basename "$r").failed"
    FAILED=$((FAILED+1))
  fi
done

# The commit is not optional: see the header. One commit for the whole drain,
# because the deposits in it are one queue and splitting them says nothing more.
if [ "$OK" -gt 0 ]; then
  if [ -n "$(git -C "$VAULT" status --porcelain 2>/dev/null)" ]; then
    git -C "$VAULT" add -A \
      && git -C "$VAULT" \
           -c user.name='vault-spool-drain' \
           -c user.email='vault-spool-drain@localhost' \
           commit -q -m "consigne: drain $OK spooled request(s) ($(hostname -s))" \
      && say "  OK      committed $OK drained request(s)" \
      || { say "  BAD     the deposits landed but could not be committed -- they are UNCOMMITTED in $VAULT"; FAILED=$((FAILED+1)); }
  fi
fi

# NEVER ASSUMED CLEAN (#212). An unpushed vault is one laptop away from being
# the only copy, and that failure was silent for nine days once already.
up="$(git -C "$VAULT" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"
if [ -n "$up" ]; then
  ahead="$(git -C "$VAULT" rev-list --count "$up..HEAD" 2>/dev/null)"
  case "$ahead" in ''|*[!0-9]*) ahead=0 ;; esac
  [ "$ahead" -gt 0 ] && say "  NOT PUSHED -- $VAULT is $ahead commit(s) ahead of $up; this does not push (PROSE-REAPING.md 5.6)"
fi

say
printf '%s (--apply): %d deposited, %d failed\n' "$CLI_NAME" "$OK" "$FAILED"
[ "$FAILED" -eq 0 ] && exit 0
exit 1
