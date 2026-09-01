#!/usr/bin/env bash
set -uo pipefail

CLI_NAME='unland-foreign-clone.sh'
CLI_SUMMARY='remove the clone of <project> that bin/land-selfdev.sh minted into self-dev accounts that do not own it, keeping the checkout of the one that does'
CLI_USAGE='  unland-foreign-clone.sh <project>            --check (default): list what would go, remove nothing
  unland-foreign-clone.sh <project> --apply    remove them, then print the witness to paste back'
CLI_FLAGS='--check --apply'
CLI_POSITIONAL='<project>'
CLI_EXITS='  0  nothing left to remove
  1  findings: clones are present (--check), or one was kept back (--apply)
  5  refused: --apply without root
  6  BLIND: the self-dev uid band matched no account at all -- nothing was
     looked at, and a 0-account pass is NOT a clean result'
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib/cli-guard.sh"
cli_guard "$@"

MODE=--check
PROJECT=
while [ $# -gt 0 ]; do
  case "$1" in
    --check|--apply) MODE="$1" ;;
    [a-z][a-z0-9-]*) [ -n "$PROJECT" ] && cli_die "one project at a time: already given '$PROJECT'"; PROJECT="$1" ;;
    *) cli_die "unexpected argument: $1" ;;
  esac
  shift
done  # $PROJECT is MATCHED, not merely non-empty: it becomes a path component of the rm -rf below, and `..` would name every account's whole Documents/Projects
[ -n "$PROJECT" ] || cli_die "which project's foreign clones? (e.g. senechal)"

UID_LO=3000; UID_HI=3100                                          # the self-dev band, same as bin/monkey-status-collect.py
HOME_ROOT="${SELFDEV_HOME_ROOT:-/home}"                           # fixture seams:
PASSWD_SRC="${SELFDEV_PASSWD:-}"                                  # unset in production

PASS=0; GAPS=0; BAD=0
ok()  { printf '  OK      %s\n' "$*"; PASS=$((PASS+1)); }
gap() { printf '  WOULD   %s\n' "$*"; GAPS=$((GAPS+1)); }
bad() { printf '  BAD     %s\n' "$*"; BAD=$((BAD+1)); }
act() { printf '  DO      %s\n' "$*"; }
die() { printf '\n%s: %s\n' "$CLI_NAME" "$*" >&2; exit "${2:-5}"; }

echo "== unland-foreign-clone $PROJECT ($MODE) -- $(hostname -s), uid $UID_LO-$((UID_HI-1)) under $HOME_ROOT =="

[ "$MODE" = --check ] || [ "$(id -u)" -eq 0 ] || die "$MODE needs root (sudo $CLI_NAME $PROJECT $MODE)" 5

accounts() {  # the uid band IS the roster, same predicate bin/monkey-status-collect.py uses -- never a typed list
  { [ -n "$PASSWD_SRC" ] && cat "$PASSWD_SRC" || getent passwd; } 2>/dev/null \
    | awk -F: -v lo="$UID_LO" -v hi="$UID_HI" '$3+0>=lo && $3+0<hi {print $1}' | sort
}

# TRAP: as root, git refuses another account's repo (safe.directory) and then
#   fails exactly as it does on a corrupt tree -- without the -c below every
#   clone reads "not a readable git tree" and this removes nothing.
residue() {  # a bootstrap copy can hold work that exists nowhere else -- `scheduler -i realisateur` wrote .idea files into whatever account it ran under until hf7y/scheduler retired that path on 2026-08-29, and on 2026-08-30 a cleanup sweep held all three surviving clones back with local commits of its own
  local d="$1" out
  out="$(git -c safe.directory='*' -C "$d" status --porcelain 2>/dev/null)" \
    || { printf 'not a readable git tree'; return 0; }
  [ -n "$out" ] && { printf 'uncommitted or untracked files (%s)' "$(printf '%s\n' "$out" | grep -c .)"; return 0; }
  out="$(git -c safe.directory='*' -C "$d" log --branches --not --remotes --oneline 2>/dev/null)"
  [ -n "$out" ] && printf 'unpushed commits (%s)' "$(printf '%s\n' "$out" | grep -c .)"
  return 0
}

roster="$(accounts)"
if [ -z "$roster" ]; then
  echo "BLIND: no account in uid $UID_LO-$((UID_HI-1)) -- nothing was looked at." >&2
  echo "$CLI_NAME: nothing was measured. This is NOT a clean result." >&2
  exit 6
fi

for a in $roster; do
  case "$a" in ''|*/*|.|..) bad "refusing an implausible account name: '$a'"; continue ;; esac  # it becomes a path component below; a roster that can hold anything else is a delete-anything primitive

  d="$HOME_ROOT/$a/Documents/Projects/$PROJECT"

  if [ "$a" = "$PROJECT" ]; then  # THE OWNING ACCOUNT, and the account name equalling the directory name is the only thing that tells its dev checkout (schedule/<project>.conf's PROJECT_REPO_PATH) from a copy land-selfdev.sh minted
    ok "$a: KEPT -- this account owns $PROJECT, so $d is its own dev checkout"
    continue
  fi

  [ -d "$d" ] || { ok "$a: no clone at $d"; continue; }

  r="$(residue "$d")"
  if [ -n "$r" ]; then
    bad "$a: KEPT -- $d has $r; salvage it, then re-run"
    continue
  fi

  if [ "$MODE" = --apply ]; then
    if rm -rf "$d"; then act "$a: removed $d"; else bad "$a: could not remove $d"; fi
  else
    gap "$a: would remove $d"
  fi
done

echo
printf '%s (%s): %d ok, %d to remove, %d kept back\n' "$CLI_NAME" "$MODE" "$PASS" "$GAPS" "$BAD"

cat <<WITNESS

== WITNESS -- run this on $(hostname -s) after --apply and paste the output ==
  sudo find $HOME_ROOT -maxdepth 4 -type d -path '*/Documents/Projects/$PROJECT'
  echo "clones left: \$(sudo find $HOME_ROOT -maxdepth 4 -type d -path '*/Documents/Projects/$PROJECT' | grep -c .) (expect 1 -- $PROJECT's own)"
  command -v ausculte; ausculte --help >/dev/null 2>&1; echo "ausculte rc=\$?"
Root, and find rather than a glob: $PROJECT's own home is 0700, so a glob the
invoking shell expands cannot see the one clone that is supposed to SURVIVE,
and the witness reads "clones left: 0" on a correct run (2026-08-31).
The last line is the half that matters: it proves the removal took the
clones and not the tooling, which reaches these accounts as verbs.
WITNESS

if [ "$MODE" = --check ]; then
  [ "$GAPS" -eq 0 ] && [ "$BAD" -eq 0 ] && exit 0
  echo "Next: sudo $CLI_NAME $PROJECT --apply"
  exit 1
fi
[ "$BAD" -eq 0 ] && exit 0
exit 1
