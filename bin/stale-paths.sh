#!/usr/bin/env bash
set -uo pipefail  # stale-paths.sh -- a SURVEY (#700), GUARD-TEST bin/tests/stale-paths.test.sh: does an open issue's body cite a path this repo's tree no longer has? GATE: none, this REPORTS and never auto-closes (musc-2300#2 spent a decision against a body describing a repo that had moved) -- extraction and false-positive avoidance live in the predicate, bin/lib/stale-paths.jq, not here.

CLI_NAME='stale-paths.sh'
CLI_SUMMARY='does an open issue cite a path the repo tree no longer has?'
CLI_USAGE='  stale-paths.sh --all              sweep every roster repo
  stale-paths.sh <owner>/<repo>     sweep one repo
  stale-paths.sh --all --json       machine-readable NDJSON + summary line'
CLI_FLAGS='--all --json'
CLI_POSITIONAL=any
CLI_EXITS='  0  clean -- no open issue cites an absent path
  1  finding(s) -- at least one open issue cites a path this tree does not have
  6  BLIND -- a repo or its tree could not be read; the count is NOT trustworthy'
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

OWNER="${STALE_PATHS_OWNER:-hf7y}"
HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

. "$HERE/lib/roster-set.sh"
if [ "${ROSTER_SET_LIB:-}" != 1 ] || [ "${#ROSTER[@]}" -eq 0 ]; then
  printf '%s: BLIND -- lib/roster-set.sh did not load, so this swept NO repositories.\n' \
    "$CLI_NAME" >&2
  exit 6
fi

ROSTER_PATTERN="$(IFS='|'; echo "${ROSTER[*]}")"  # for "named in prose, not $owner/repo-qualified" (measured live against hf7y/musc-2300)

STALE_PATHS_JQ_FILE="${STALE_PATHS_JQ_FILE:-$HERE/lib/stale-paths.jq}"
[ -r "$STALE_PATHS_JQ_FILE" ] || {
  printf '%s: BLIND -- the predicate is not readable at %s.\n' "$CLI_NAME" "$STALE_PATHS_JQ_FILE" >&2
  exit 6
}
STALE_PATHS_JQ="$(cat "$STALE_PATHS_JQ_FILE")"

MODE=''
REPOS=()
JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --all)  MODE=all; shift ;;
    --json) JSON=1; shift ;;
    */*)    MODE=one; REPOS+=("$1"); shift ;;
    *) echo "$CLI_NAME: not an <owner>/<repo>: $1" >&2; exit 2 ;;
  esac
done
[ -z "$MODE" ] && { echo "$CLI_NAME: pass --all or an <owner>/<repo>" >&2; exit 2; }
[ "$MODE" = all ] && for p in "${ROSTER[@]}"; do REPOS+=("$OWNER/$p"); done

command -v gh >/dev/null || { echo "$CLI_NAME: gh not on PATH" >&2; exit 6; }
command -v jq >/dev/null || { echo "$CLI_NAME: jq not on PATH" >&2; exit 6; }

ERRORS=0
FINDINGS=0
ROWS=''   # repo<TAB>number<TAB>missing-count<TAB>title
DETAIL='' # repo<TAB>number<TAB>path

for repo in "${REPOS[@]}"; do
  if ! issues=$(gh issue list --repo "$repo" --state open --limit 200 \
                  --json number,title,body 2>&1); then
    case "$issues" in
      *"issues are disabled"*|*"Issues are disabled"*) ;;
      *) printf '%s: ERROR reading %s issues: %s\n' "$CLI_NAME" "$repo" "$issues" >&2
         ERRORS=$((ERRORS + 1)) ;;
    esac
    continue
  fi
  if ! printf '%s' "$issues" | jq -e 'type == "array"' >/dev/null 2>&1; then
    printf '%s: ERROR %s issues returned a non-array (rate limit? token scope?)\n' "$CLI_NAME" "$repo" >&2
    ERRORS=$((ERRORS + 1)); continue
  fi

  if ! tree_json=$(gh api "repos/$repo/git/trees/HEAD?recursive=true" 2>&1); then
    printf '%s: ERROR reading %s tree: %s\n' "$CLI_NAME" "$repo" "$tree_json" >&2
    ERRORS=$((ERRORS + 1)); continue
  fi
  if [ "$(printf '%s' "$tree_json" | jq -r '.truncated // false')" = true ]; then  # a partial read: absence there is not evidence of absence
    printf '%s: ERROR %s tree is TRUNCATED by the API -- a miss there proves nothing\n' \
      "$CLI_NAME" "$repo" >&2
    ERRORS=$((ERRORS + 1)); continue
  fi
  tree="$(printf '%s' "$tree_json" | jq -c '[.tree[]?.path]')"

  found=$(printf '%s' "$issues" | jq -r --arg owner "$OWNER" --arg roster_pattern "$ROSTER_PATTERN" --argjson tree "$tree" \
    "$STALE_PATHS_JQ"'.[] | missing($tree) | select(.missing | length > 0)
     | [.number, (.missing | length), (.title | gsub("\\s+"; " "))] | @tsv')
  [ -n "$found" ] && while IFS=$'\t' read -r num cnt title; do
    [ -n "$num" ] || continue
    FINDINGS=$((FINDINGS + 1))
    ROWS+="${repo#*/}"$'\t'"$num"$'\t'"$cnt"$'\t'"$title"$'\n'
  done <<< "$found"

  paths=$(printf '%s' "$issues" | jq -r --arg owner "$OWNER" --arg roster_pattern "$ROSTER_PATTERN" --argjson tree "$tree" \
    "$STALE_PATHS_JQ"'.[] | missing($tree) | select(.missing | length > 0)
     | .number as $n | .missing[] | [$n, .] | @tsv')
  [ -n "$paths" ] && while IFS=$'\t' read -r num path; do
    [ -n "$num" ] || continue
    DETAIL+="${repo#*/}"$'\t'"$num"$'\t'"$path"$'\n'
  done <<< "$paths"
done

if [ "$JSON" = 1 ]; then
  printf '%s' "$ROWS" | while IFS=$'\t' read -r r n c t; do
    [ -n "$r" ] || continue
    missing=$(printf '%s' "$DETAIL" | awk -F'\t' -v r="$r" -v n="$n" '$1==r && $2==n {print $3}')
    jq -cn --arg repo "$r" --argjson number "$n" --argjson missing_count "$c" \
           --arg title "$t" --arg missing "$missing" \
           '{kind:"stale",repo:$repo,number:$number,missing_count:$missing_count,
             title:$title,missing:($missing | split("\n") | map(select(length>0)))}'
  done
  jq -cn --argjson repos "${#REPOS[@]}" --argjson findings "$FINDINGS" --argjson errors "$ERRORS" \
         '{kind:"summary",repos:$repos,findings:$findings,errors:$errors}'
else
  printf '%s' "$ROWS" | while IFS=$'\t' read -r r n c t; do
    [ -n "$r" ] || continue
    printf '  %-16s #%-5s %2s stale path(s)  %s\n' "$r" "$n" "$c" "$t"
    printf '%s' "$DETAIL" | awk -F'\t' -v r="$r" -v n="$n" '$1==r && $2==n {print "      -> " $3}'
  done
  printf '%s' "$ROWS" | grep -q . && echo "This is a REPORT, not an auto-close -- the body needs re-reading."
fi

[ "$ERRORS" -gt 0 ] && exit 6
[ "$FINDINGS" -gt 0 ] && exit 1
exit 0
