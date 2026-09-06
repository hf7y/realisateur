#!/usr/bin/env bash
# prose-workflow-provision.sh -- the half of #800 that lands the FILE:
# .github/workflows/prose.yml, so a repo has something for
# branch-protection-provision.sh to require.
#
# hf7y/realisateur#800 (2026-09-03, the comment that left this open): "Step 2
# -- setup-selfdev-project.sh gaining the step that writes prose.yml at
# standup -- is not done. Four repos needed it by hand tonight, which is four
# more than should have." This is that step, factored out so the same code is
# callable standalone against a repo that already exists, not only one still
# standing up -- setup-selfdev-project.sh's own step 10 is a one-repo call
# into this.
#
# THE SHAPE, confirmed live on 2026-09-06 by diffing five PRIVATE compliant
# copies (abletim, secretaire, apms-2173, nine-speakers, gardien, ecosim,
# wtul) against three PUBLIC ones (american-cycle, front-door, crt): a
# private repo's copy adds `runs_on: '["self-hosted","linux"]'` (hf7y's
# hosted minutes are refused there) and drops the `concurrency:` block a
# public copy always carries. Nothing else differs; `state_prose: true` is on
# both. bibliothecaire additionally carries `runtime: true`, which is a
# project's own extra input, not part of this floor, and is left alone.
#
# NO LOCAL CLONE, NO PUSH TO A DEFAULT BRANCH. Every write goes through the
# GitHub API: a branch off the default branch's tip, the file placed there by
# the contents API, then a PR -- the same "commits nothing to main itself"
# shape enrole-selfdev.sh and reprise.sh already use. CLAUDE.md refuses a
# direct push to main for every account, this one included.
#
# IDENTITY: a GitHub App installation token, minted the way ausculte.sh's
# --cadence branch and gh-sign.sh already mint one (selfdev-gh-app.sh
# --token), not the invoking account's own credential. This runs as root
# during standup, which has no `gh auth login` of its own, and the App's own
# bot identity is the point of that script existing (its own header).
#
# RUNNER-FIRST IS NOT A GATE HERE, DELIBERATELY. #800 carried a correction on
# 2026-09-03: an earlier comment said a private repo needs a self-hosted
# runner before it can get a workflow; the provisioner actually refuses a
# PRIVATE repo that has NO WORKFLOWS YET (needs_runner() is private AND
# has_workflows), so the workflow lands first and its checks queue rather
# than deadlock. apms-2173 proved it: 0 runners, 0 workflows, first check
# green in 13s. This script does not check for a runner and does not wait.
#
# BRANCH PROTECTION IS A SEPARATE, REVIEWED STEP. This never calls
# branch-protection-provision.sh and never touches required-check settings --
# it only gives that script something to require.
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
    -*) ;;   # cli_guard above already refused anything not in CLI_FLAGS
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

# mint_token <repo> -- an App installation token scoped to just this repo, or
# nothing (rc 1). Same minting call ausculte.sh --cadence and gh-sign.sh
# already use; not reimplemented here.
mint_token() {
  local repo="$1" t
  [ -x "$APP_TOKEN_CMD" ] || return 1
  t="$("$APP_TOKEN_CMD" --token --repos "$repo" 2>/dev/null | tail -1)"
  case "$t" in gh[a-z]_*) printf '%s' "$t"; return 0 ;; *) return 1 ;; esac
}

body_public() {
  cat <<'YAML'
# prose.yml -- the estate's prose guard. The whole integration.
#
# The guard itself lives in hf7y/etalon and is maintained ONLY there, so this
# file never needs to change when the guard does. .prose-ratchet is this
# repo's own floor and only ever falls.
name: prose

on:
  pull_request:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  prose:
    uses: hf7y/etalon/.github/workflows/guard.yml@main
    with:
      state_prose: true
YAML
}

body_private() {
  cat <<'YAML'
# prose.yml -- the estate's prose guard. The whole integration.
#
# The guard itself lives in hf7y/etalon and is maintained ONLY there, so this
# file never needs to change when the guard does. .prose-ratchet is this
# repo's own floor and only ever falls.
#
# runs_on: this repo is PRIVATE and hf7y's hosted minutes are refused, so the
# required check could not start at all.
name: prose

on:
  pull_request:

jobs:
  prose:
    uses: hf7y/etalon/.github/workflows/guard.yml@main
    with:
      runs_on: '["self-hosted", "linux"]'
      state_prose: true
YAML
}

# open_pr_exists <slug> <token> -- an open PR from an earlier run of this
# script is still open (rc 0), or not (rc 1). Checked before minting a branch
# so a re-run of setup-selfdev-project.sh (documented idempotent) does not
# open a second PR for the same gap while the first is still under review.
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
