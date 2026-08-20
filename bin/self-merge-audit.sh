#!/usr/bin/env bash
# self-merge-audit.sh -- realisateur#288 item 3: same account both ends of a merge, no required status check to have gated it.
# RUNNER: bin/tests/self-merge-audit.test.sh
# GUARD-TEST: bin/tests/self-merge-audit.test.sh
# GATE: strict

set -uo pipefail

CLI_NAME='self-merge-audit.sh'
CLI_SUMMARY='did a recent PR merge with the same account on both ends and nothing required to gate it?'
CLI_USAGE='  self-merge-audit.sh              report, change nothing
  self-merge-audit.sh <repo>...    report for named repo(s)
  self-merge-audit.sh --strict [<repo>...]  exit 1 if any hazard was found
  self-merge-audit.sh --verbose [<repo>...] list every self-merge, gated or not'
CLI_FLAGS='--strict --verbose --count'
CLI_EXITS='  0  every rostered repo read; no hazard, or none checked with --strict
  1  --strict was given and at least one HAZARD self-merge was found
  6  BLIND -- at least one repo could not be read at all, or the roster
     matched nothing. NEVER 0: could-not-look is not clean.'
CLI_POSITIONAL=any
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

OWNER="${SMA_OWNER:-hf7y}"
GH_BIN="${GH_BIN:-gh}"
COUNT="${SMA_COUNT:-10}"   # merged PRs inspected per repo, most recent first

ROSTER=(
  baudin bibliothecaire chezz crt ecosim gardien groc-mangr nine-speakers
  realisateur scheduler secretaire senechal sequestria vim-arcade wtul
  verbs front-door basheur
)

STRICT=0
VERBOSE=0
want=()
for a in "$@"; do
  case "$a" in
    --strict)  STRICT=1 ;;
    --verbose) VERBOSE=1 ;;
    --count)   : ;;
    *)         want+=("$a") ;;
  esac
done

names=()
for p in "${ROSTER[@]}"; do
  if [ "${#want[@]}" -gt 0 ]; then
    skip=1; for w in "${want[@]}"; do [ "$w" = "$p" ] && skip=0; done
    [ "$skip" -eq 1 ] && continue
  fi
  names+=("$p")
done
cli_require_matched want names

command -v "$GH_BIN" >/dev/null || { echo "$CLI_NAME: $GH_BIN not on PATH" >&2; exit 6; }

echo "self-merge-audit -- $(date '+%Y-%m-%d %H:%M')"
echo

api_get() { "$GH_BIN" api "$1" 2>/dev/null; }

read_contexts() {
  local out
  out="$(api_get "repos/$1/branches/$2/protection")" || return 0
  printf '%s' "$out" | jq -r '[.required_status_checks.contexts[]?] | join(",")' 2>/dev/null
}

blind=0
hazard=0
gated_self=0
scanned=0

for name in "${names[@]}"; do
  slug="$OWNER/$name"

  if repo_json="$(api_get "repos/$slug")"; then
    branch="$(printf '%s' "$repo_json" | jq -r '.default_branch // empty' 2>/dev/null)"
  else
    branch=''
  fi
  if [ -z "$branch" ]; then
    echo "  BLIND $name: could not read the repo (no access, or it does not exist)"
    blind=$((blind+1))
    continue
  fi

  # `pulls` REST list never returns merged_by; `gh pr list --json mergedBy` does.
  if ! pr_json="$("$GH_BIN" pr list --repo "$slug" --state merged \
        --json number,author,mergedBy --limit "$COUNT" 2>/dev/null)"; then
    echo "  BLIND $name: could not list pull requests"
    blind=$((blind+1))
    continue
  fi

  have="$(read_contexts "$slug" "$branch")"
  gated=0; [ -n "$have" ] && gated=1

  found_any=0
  hazard_nums=()
  gated_nums=()
  while IFS=$'\t' read -r num author merger; do
    [ -n "$num" ] || continue
    found_any=1
    [ -n "$merger" ] && [ "$author" = "$merger" ] || continue
    if [ "$gated" -eq 1 ]; then
      gated_nums+=("#$num")
      gated_self=$((gated_self+1))
      [ "$VERBOSE" -eq 1 ] && echo "  self-merge (gated) $name#$num: $author merged their own PR, but [$have] was required"
    else
      hazard_nums+=("#$num")
      hazard=$((hazard+1))
      echo "  HAZARD $name#$num: $author merged their own PR with no required check to queue behind"
    fi
  done < <(printf '%s' "$pr_json" | jq -r '.[] | [.number, .author.login, (.mergedBy.login // "")] | @tsv' 2>/dev/null)

  if [ "$found_any" -eq 0 ]; then
    echo "  ok    $name: no merged pull request in the last $COUNT closed"
  elif [ "$VERBOSE" -eq 0 ] && [ "${#hazard_nums[@]}" -eq 0 ]; then
    if [ "${#gated_nums[@]}" -gt 0 ]; then
      echo "  ok    $name: ${#gated_nums[@]} self-merge(s), all gated by [$have]"
    else
      echo "  ok    $name: no self-merge among its last $COUNT merged PR(s)"
    fi
  fi
  scanned=$((scanned+1))
done

echo
echo "== $scanned repo(s) scanned, $hazard HAZARD self-merge(s), $gated_self gated self-merge(s), $blind BLIND =="

if [ "$blind" -gt 0 ]; then
  echo "$CLI_NAME: $blind repo(s) unreadable -- the counts above are NOT trustworthy."
  exit 6
fi
if [ "$STRICT" = 1 ] && [ "$hazard" -gt 0 ]; then
  exit 1
fi
exit 0
