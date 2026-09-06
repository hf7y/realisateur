#!/usr/bin/env bash
set -uo pipefail

CLI_NAME='prose-workflow-provision.sh'
CLI_SUMMARY='land .github/workflows/prose.yml (calling hf7y/etalon/.github/workflows/guard.yml@main) on a repo that has none, by PR -- hf7y/realisateur#800'
CLI_USAGE='  prose-workflow-provision.sh <repo>...          --check (default): report, write nothing
  prose-workflow-provision.sh --apply <repo>...  open a PR adding prose.yml where missing

  <repo> is a bare name under $GH_ESTATE_OWNER (hf7y), e.g. musc-2300.'
CLI_FLAGS='--check --apply'
CLI_POSITIONAL=any
CLI_EXITS='  0  every named repo already carries prose.yml (or, under --apply, an open
     PR exists or was just opened for every gap)
  1  findings under --check: at least one named repo has no prose.yml
  2  usage error
  6  BLIND: gh/jq missing, or a repo/branch/token/write call did not answer --
     never read as "clean"'
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
. "$HERE/lib/cli-guard.sh"
cli_guard "$@"
. "$HERE/lib/estate-set.sh"

OWNER="$GH_ESTATE_OWNER"
GH_BIN="${GH_BIN:-gh}"
APP_TOKEN_CMD="${PROSE_APP_TOKEN_CMD:-${SELFDEV_LIBEXEC:-/usr/local/libexec/selfdev}/selfdev-gh-app.sh}"
WORKFLOW_PATH='.github/workflows/prose.yml'

MODE=--check
names=()
for a in "$@"; do
  case "$a" in
    --check|--apply) MODE="$a" ;;
    -*) ;;
    *) names+=("$a") ;;
  esac
done
[ "${#names[@]}" -gt 0 ] || cli_die "no repo named"

command -v "$GH_BIN" >/dev/null || { echo "$CLI_NAME: BLIND -- $GH_BIN is not on PATH" >&2; exit 6; }
command -v jq >/dev/null || { echo "$CLI_NAME: BLIND -- jq is not on PATH" >&2; exit 6; }

BLIND=0; FINDINGS=0
say()   { printf '  %-7s %s\n' "$1" "$2"; }
blind() { say BLIND "$*"; BLIND=$((BLIND+1)); }

api_get() { "$GH_BIN" api "$1" 2>/dev/null; }

mint_token() {
  local repo="$1" t
  [ -x "$APP_TOKEN_CMD" ] || return 1
  t="$("$APP_TOKEN_CMD" --token --repos "$repo" 2>/dev/null | tail -1)"
  case "$t" in gh[a-z]_*) printf '%s' "$t"; return 0 ;; *) return 1 ;; esac
}

read -r -d '' PREAMBLE_TEXT <<'TXT' || :
prose.yml -- the estate's prose guard. The whole integration.

The guard itself lives in hf7y/etalon and is maintained ONLY there, so this
file never needs to change when the guard does. .prose-ratchet is this
repo's own floor and only ever falls.
TXT
PREAMBLE="$(printf '%s\n' "$PREAMBLE_TEXT" | awk '{print (length($0) ? "# " $0 : "#")}')"

body_public() {
  printf '%s\nname: prose\n\non:\n  pull_request:\n\nconcurrency:\n  group: ${{ github.workflow }}-${{ github.ref }}\n  cancel-in-progress: true\n\njobs:\n  prose:\n    uses: hf7y/etalon/.github/workflows/guard.yml@main\n    with:\n      state_prose: true\n' "$PREAMBLE"
}

body_private() {
  printf '%s\nname: prose\n\non:\n  pull_request:\n\njobs:\n  prose:\n    uses: hf7y/etalon/.github/workflows/guard.yml@main\n    with:\n      runs_on: '"'"'["self-hosted", "linux"]'"'"'\n      state_prose: true\n' "$PREAMBLE"
}

open_pr_exists() {
  local slug="$1" token="$2" heads
  heads="$(GH_TOKEN="$token" api_get "repos/$slug/pulls?state=open&per_page=100" \
            | jq -r '.[].head.ref' 2>/dev/null)"
  printf '%s\n' "$heads" | grep -qE '^prose-workflow-'
}

one() {
  local name="$1" private branch info
  local slug="$OWNER/$name"
  info="$(api_get "repos/$slug")"
  [ -n "$info" ] || { blind "$name: the repo would not answer"; return; }
  private="$(printf '%s' "$info" | jq -r '.private')"
  branch="$(printf '%s' "$info" | jq -r '.default_branch // empty')"
  [ -n "$branch" ] || { blind "$name: no default branch reported"; return; }

  if api_get "repos/$slug/contents/$WORKFLOW_PATH?ref=$branch" | jq -e '.sha' >/dev/null 2>&1; then
    say ok "$name: $WORKFLOW_PATH already present on $branch"
    return
  fi

  say MISSING "$name ($([ "$private" = true ] && echo private || echo public)): no $WORKFLOW_PATH on $branch"
  FINDINGS=$((FINDINGS+1))
  if [ "$MODE" != --apply ]; then
    say remedy "$CLI_NAME --apply $name"
    return
  fi

  local token; token="$(mint_token "$name")" \
    || { blind "$name: could not mint an App token ($APP_TOKEN_CMD) -- is the App installed on $OWNER?"; return; }

  if open_pr_exists "$slug" "$token"; then
    say ok "$name: a PR already open from a prior run (head matches prose-workflow-*) -- not opening a second one"
    return
  fi

  local head_sha br b64 content
  head_sha="$(GH_TOKEN="$token" api_get "repos/$slug/git/ref/heads/$branch" | jq -r '.object.sha // empty')"
  [ -n "$head_sha" ] || { blind "$name: could not read the tip of $branch"; return; }
  br="prose-workflow-$(date -u +%Y%m%d%H%M%S)"
  if ! GH_TOKEN="$token" "$GH_BIN" api -X POST "repos/$slug/git/refs" \
        -f "ref=refs/heads/$br" -f "sha=$head_sha" >/dev/null 2>&1; then
    blind "$name: could not create branch $br off $branch"; return
  fi
  content="$([ "$private" = true ] && body_private || body_public)"
  b64="$(printf '%s' "$content" | base64 -w0 2>/dev/null || printf '%s' "$content" | base64)"
  if ! GH_TOKEN="$token" "$GH_BIN" api -X PUT "repos/$slug/contents/$WORKFLOW_PATH" \
        -f "message=prose-workflow-provision: add the estate prose guard (hf7y/realisateur#800)" \
        -f "content=$b64" -f "branch=$br" >/dev/null 2>&1; then
    blind "$name: could not write $WORKFLOW_PATH on $br (branch was created; not cleaned up -- a stray branch costs nothing a re-run will not overwrite)"; return
  fi
  local shape; shape="$([ "$private" = true ] && echo 'runs_on self-hosted (private)' || echo 'ubuntu-latest default (public)')"
  if ! GH_TOKEN="$token" "$GH_BIN" pr create --repo "$slug" --base "$branch" --head "$br" \
        --title 'add .github/workflows/prose.yml (hf7y/realisateur#800)' \
        --body "$(printf 'NO-DECISION: mechanical -- the estate guard every ROSTER repo carries, landed at standup by prose-workflow-provision.sh.\n\nCalls hf7y/etalon/.github/workflows/guard.yml@main, %s. Requiring this check (branch-protection-provision.sh --apply %s) is a separate, reviewed step this PR does not take.\n\n<!-- DEFERRED -->\n- hf7y/realisateur#800\n<!-- /DEFERRED -->\n\n<!-- DELIVERS -->\n- none\n<!-- /DELIVERS -->\n' "$shape" "$name")" \
        >/dev/null 2>&1; then
    blind "$name: $br was written but the PR could not be opened -- open it by hand: gh pr create --repo $slug --base $branch --head $br"; return
  fi
  say applied "$name: PR opened adding $WORKFLOW_PATH on $br"
}

echo "prose-workflow-provision ($MODE) -- $OWNER, $(date '+%Y-%m-%d %H:%M')"
for n in "${names[@]}"; do one "$n"; done

printf '\n== %d finding(s), %d BLIND, out of %d repo(s) ==\n' "$FINDINGS" "$BLIND" "${#names[@]}"
[ "$BLIND" -gt 0 ] && { echo "$CLI_NAME: $BLIND repo(s) unread -- the counts above are NOT trustworthy."; exit 6; }
[ "$MODE" = --apply ] && exit 0
[ "$FINDINGS" -gt 0 ] && exit 1
exit 0
