#!/usr/bin/env bash
set -uo pipefail  # supersession.sh -- a SURVEY (#754), GUARD-TEST bin/tests/supersession.test.sh: is a declared transition finished at BOTH ends? GATE: none, this REPORTS -- the ledger and the predicate are bin/lib/superseded.tsv, not here.

CLI_NAME='supersession.sh'
CLI_SUMMARY='is anything half-transitioned -- the old one still live, or the new one never landed?'
CLI_USAGE='  supersession.sh           the ledger, plus every `retires:` a merged PR declared
  supersession.sh --local   the ledger only; skip the merged-PR search'
CLI_FLAGS='--local'
CLI_POSITIONAL=none
CLI_EXITS='  0  every declared transition finished: the retired ref is gone, the armed ref is there
  1  finding(s) -- RESIDUE (the old one is still present) or UNARMED (the new one is absent)
  6  BLIND -- a ref could not be resolved; the count is NOT trustworthy'
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/cli-guard.sh"
cli_guard "$@"

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
LEDGER="${SUPERSEDED_TSV:-$HERE/lib/superseded.tsv}"
. "$HERE/lib/estate-set.sh"
OWNER="$GH_ESTATE_OWNER"
SELF="$OWNER/realisateur"

LOCAL=0
[ "${1:-}" = --local ] && LOCAL=1

[ -r "$LEDGER" ] || {
  printf '%s: BLIND -- the ledger is not readable at %s.\n' "$CLI_NAME" "$LEDGER" >&2
  exit 6
}

FINDINGS=0
BLIND=0
ROWS=0

blind() {  # <why> -- a ref this run could not resolve. Never folded into clean
  printf '  BLIND    %s\n' "$1"; BLIND=$((BLIND + 1))
}

gh_exists() {  # <api path> <what> -> 0 there, 1 not there, 2 could not tell. A 404 is an ANSWER; a rate limit read as "absent" would clear the very alarm this raises
  local err
  err="$(gh api "$1" 2>&1 >/dev/null)" && return 0
  case "$err" in *'Not Found'*|*404*) return 1 ;; esac
  blind "cannot read $2: ${err%%$'\n'*}"; return 2
}

ref_present() {  # <ref> <repo it was declared in> -> 0 present, 1 absent, 2 could not tell (already reported). This repo answers from its own tree; another repo's only over the API
  local ref="$1" repo="$2" p st
  case "$ref" in
    path:/*) [ -e "${ref#path:}" ] && return 0 || return 1 ;;
    path:*)
      p="${ref#path:}"
      if [ "$repo" = "$SELF" ]; then [ -e "$ROOT/$p" ] && return 0 || return 1; fi
      gh_exists "repos/$repo/contents/$p" "$p in $repo" ;;
    branch:*)
      gh_exists "repos/$repo/branches/${ref#branch:}" "$ref in $repo" ;;
    issue:*)
      p="${ref#issue:}"
      st="$(gh issue view "${p#*\#}" --repo "${p%%\#*}" --json state --jq .state 2>&1)" || {
        blind "cannot read $ref: ${st%%$'\n'*}"; return 2; }
      [ "$st" = OPEN ] && return 0 || return 1 ;;
    *) blind "no resolver for the ref kind in: $ref"; return 2 ;;
  esac
}

judge() {  # <retired> <armed> <witness> <note> <repo> -- the predicate, and the one place a row becomes a line: it names the thing and what replaced it, the way check_shrink() names the verb it refused over
  local retired="$1" armed="$2" witness="$3" note="$4" repo="$5"
  ROWS=$((ROWS + 1))
  if [ "$retired" != - ]; then
    ref_present "$retired" "$repo"
    case $? in
      0) if [ "$armed" = - ]; then
           printf '  RESIDUE  %s is still present -- it was to be deleted outright (%s)\n' "$retired" "$witness"
         else
           printf '  RESIDUE  %s is still present -- %s replaced it (%s)\n' "$retired" "$armed" "$witness"
         fi
         [ -n "$note" ] && printf '           %s\n' "$note"
         FINDINGS=$((FINDINGS + 1)) ;;
    esac
  fi
  if [ "$armed" != - ]; then
    ref_present "$armed" "$repo"
    case $? in
      1) if [ "$retired" = - ]; then
           printf '  UNARMED  %s is absent -- it was declared and never landed (%s)\n' "$armed" "$witness"
         else
           printf '  UNARMED  %s is absent -- it was to replace %s (%s)\n' "$armed" "$retired" "$witness"
         fi
         [ -n "$note" ] && printf '           %s\n' "$note"
         FINDINGS=$((FINDINGS + 1)) ;;
    esac
  fi
}

printf '%s: declared transitions\n' "$CLI_NAME"

while IFS=$'\t' read -r retired armed witness note; do
  case "${retired:-}" in ''|'#'*) continue ;; esac
  judge "$retired" "${armed:--}" "${witness:-no witness}" "${note:-}" "$SELF"
done < "$LEDGER"

# THE CHEAP DECLARATION. DELIVERS is already mandatory and already typed
# (lib/body-grammar.sh), so `- retires: <ref> -> <ref>` costs one bullet in a
# block the author is writing anyway. Narrowed to bodies carrying the word.
if [ "$LOCAL" -eq 0 ]; then
  if ! command -v gh >/dev/null; then
    blind 'gh is not on PATH, so no merged PR declaration was read'
  elif ! prs="$(gh search prs --owner "$OWNER" --merged 'retires:' --limit 100 \
                  --json number,repository,body 2>&1)"; then
    blind "could not search merged PRs: ${prs%%$'\n'*}"
  else
    while IFS=$'\t' read -r repo num line; do
      [ -n "${line:-}" ] || continue
      rest="${line#*retires:}"; rest="${rest# }"
      note="${rest#*-- }"; [ "$note" = "$rest" ] && note=''
      refs="${rest%% -- *}"
      retired="${refs%% -> *}"; retired="${retired%% }"
      armed='-'; [ "$refs" != "$retired" ] && { armed="${refs#* -> }"; armed="${armed%% }"; }
      judge "${retired:--}" "$armed" "$repo#$num" "$note" "$repo"
    done < <(printf '%s' "$prs" | jq -r '
      .[] | .repository.nameWithOwner as $r | .number as $n
      | (.body // "") | split("\n")[]
      | select(test("^\\s*[-*]\\s*retires:"))
      | [$r, ($n|tostring), (sub("^\\s*[-*]\\s*"; "") | rtrimstr("\r"))] | @tsv' 2>/dev/null)
  fi
fi

printf 'TOTAL %d row(s) %d finding(s) %d blind\n' "$ROWS" "$FINDINGS" "$BLIND"
[ "$FINDINGS" -gt 0 ] && exit 1
[ "$BLIND" -gt 0 ] && exit 6
exit 0
