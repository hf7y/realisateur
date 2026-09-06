#!/usr/bin/env bash
set -uo pipefail

CLI_NAME='verb-name-taken.sh'
CLI_SUMMARY='ask whether a candidate verb name is already declared by any project, live from GitHub (realisateur#975)'
CLI_USAGE='  verb-name-taken.sh <name>            is <name> free, estate-wide?
  verb-name-taken.sh <name> --owner <org>  check a different estate'
CLI_FLAGS='--owner'
CLI_POSITIONAL=any   # the name itself, and --owner's VALUE, both land here to cli-guard
CLI_EXITS='  0  free: no project currently declares <name>
  1  taken: printed below, with the declaring project(s) and sha
  3  BLIND: one or more repositories could not be read, so "free" cannot be
     confirmed -- this is not the same answer as 0
  2  usage error'
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/estate-set.sh"
OWNER="$GH_ESTATE_OWNER"

NAME=''
while [ $# -gt 0 ]; do
  case "$1" in
    --owner) OWNER="${2:?--owner needs a value}"; shift ;;
    -*) printf '%s: unknown argument: %s\n' "$CLI_NAME" "$1" >&2; exit 2 ;;
    *)
      [ -z "$NAME" ] || { printf '%s: only one name at a time: %s\n' "$CLI_NAME" "$1" >&2; exit 2; }
      NAME="$1"
      ;;
  esac
  shift
done
case "$NAME" in
  '') printf '%s: a candidate name is required\n' "$CLI_NAME" >&2; exit 2 ;;
  */*|.|..) printf "%s: not a usable verb name: '%s'\n" "$CLI_NAME" "$NAME" >&2; exit 2 ;;
esac

say() { printf '%s\n' "$*" >&2; }

command -v gh >/dev/null 2>&1 || { say "$CLI_NAME: gh is not on PATH -- cannot read declarations."; exit 3; }
gh auth status >/dev/null 2>&1 || { say "$CLI_NAME: gh is not authenticated -- an unauthenticated read cannot see private repos and would report a false free."; exit 3; }

NOT_A_VERB="${VERB_NOT_A_VERB_FILE:-$(dirname "${BASH_SOURCE[0]}")/lib/not-a-verb.tsv}"   # same opt-out cut-verb-build.sh reads
is_exempt() {
  local p="$1" n="$2"
  [ -f "$NOT_A_VERB" ] || return 1
  awk -F'\t' -v p="$p" -v n="$n" \
    '!/^[[:space:]]*#/ && $1 == p && $2 == n { found = 1; exit } END { exit !found }' "$NOT_A_VERB"
}

export GIT_TERMINAL_PROMPT=0

repos="$(gh repo list "$OWNER" --limit 200 --no-archived --json name -q '.[].name' 2>/dev/null)"
[ -n "$repos" ] || { say "$CLI_NAME: cannot list $OWNER's repositories -- BLIND, not empty."; exit 3; }

blind=0
found=0
for repo in $repos; do
  refs="$(git ls-remote "https://github.com/$OWNER/$repo.git" refs/heads/bashified 2>/dev/null)"
  rc=$?
  if [ $rc -ne 0 ]; then
    say "  BLIND  $repo: could not read refs (git ls-remote exited $rc)"
    blind=$((blind + 1))
    continue
  fi
  sha="$(printf '%s\n' "$refs" | awk 'NR==1{print $1}')"
  [ -n "$sha" ] || continue   # no bashified branch: a normal, non-blind answer

  whole="$(gh api "repos/$OWNER/$repo/git/trees/$sha?recursive=1" \
             -q '.tree[] | "\(.mode) \(.path)"' 2>/dev/null)"   # whole tree, filtered locally below: empty here means the call failed, not "absent"
  if [ -z "$whole" ]; then
    say "  BLIND  $repo: bashified is $sha but its tree did not read"
    blind=$((blind + 1))
    continue
  fi
  mode="$(printf '%s\n' "$whole" | awk -v p="bin/$NAME" '$2 == p {print $1; exit}')"
  [ -n "$mode" ] || continue        # genuinely absent, not blind
  [ "$mode" = "100755" ] || continue   # non-executable bin/<name> declares no verb
  if is_exempt "$repo" "$NAME"; then
    say "  (not-a-verb) $repo/bin/$NAME exists but is recorded as exempt in $NOT_A_VERB -- not a live claim"
    continue
  fi
  printf 'TAKEN\t%s\t%s\t%s\n' "$repo" "$NAME" "$sha"
  found=$((found + 1))
done

if [ "$found" -gt 0 ]; then
  say "$NAME is TAKEN, declared by $found project(s) (see rows above)."
  exit 1
fi
if [ "$blind" -gt 0 ]; then
  say "$NAME was not found, but $blind repositor$([ "$blind" -eq 1 ] && echo y || echo ies) could not be read -- that is BLIND, not free. Re-run once they're reachable."
  exit 3
fi
say "$NAME is free: no project's bashified branch declares bin/$NAME."
exit 0
