#!/usr/bin/env bash
# playbook.sh -- carry a project's STANDING BRIEF to and from its issue queue.
#
# WHY AN ISSUE AND NOT A FILE. A self-dev account's brief has to be readable
# by the run and writable by Zach from a phone. A file in the repo is neither:
# editing it needs a clone and a push, and an unattended run that rewrites its
# own brief is a loop with no outside input. The issue queue is already the
# channel Zach files into, already reachable from lalavala, and already the
# thing BATCH_PROMPT tells the run to read first. So the brief lives there,
# in ONE issue, and this script is the only thing that writes it.
#
#   playbook.sh push <owner/repo> <file>   upsert the playbook issue from a file
#   playbook.sh pull <owner/repo> [--out F]  fetch it (default: stdout)
#   playbook.sh check <owner/repo>         is there exactly one, and how old
#
# The pull half is what a dispatch run calls, first thing, before it touches
# the queue -- it needs `gh` and nothing else, so it works from any account
# with a token and no write access at all.
#
# EXACTLY ONE. Two playbook issues is the failure this guards: two briefs that
# disagree, with the run reading whichever `gh` listed first. push updates the
# existing one rather than opening a second; pull REFUSES on two rather than
# picking. A missing playbook is also a refusal, not an empty string -- a run
# that silently proceeds with no brief is the thing worth preventing.
set -euo pipefail

CLI_NAME="$(basename "$0")"
LABEL="${PLAYBOOK_LABEL:-playbook}"
TITLE_PREFIX="PLAYBOOK"

die() { echo "$CLI_NAME: $*" >&2; exit 1; }

usage() { sed -n '4,20p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

# Print the playbook issue number for a repo, or fail loud.
find_one() {
  local repo="$1"
  # shellcheck disable=SC2046  # word splitting is the point: one number per line
  set -- $(gh issue list --repo "$repo" --label "$LABEL" --state open \
             --json number --jq '.[].number')
  case $# in
    1) echo "$1" ;;
    0) die "no open issue labelled '$LABEL' in $repo. There is no standing brief to read; refusing to return an empty one." ;;
    *) die "$# issues labelled '$LABEL' in $repo ($*). Two briefs that disagree is worse than none -- close all but one." ;;
  esac
}

cmd="${1:-}"; repo="${2:-}"
if [ -z "$cmd" ] || [ -z "$repo" ]; then usage; fi
command -v gh >/dev/null || die "gh is not on PATH. Cannot reach the issue queue."

case "$cmd" in
  push)
    file="${3:-}"
    [ -s "${file:-/nonexistent}" ] || die "push needs a NON-EMPTY file. Refusing to overwrite a standing brief with nothing."
    # The label must exist before it can be applied; creating it is idempotent.
    gh label create "$LABEL" --repo "$repo" --color "0e8a16" \
        --description "the standing brief a dispatch run reads first" >/dev/null 2>&1 || true
    title="$TITLE_PREFIX -- standing brief (do not close)"
    if num="$(find_one "$repo" 2>/dev/null)"; then
      gh issue edit "$num" --repo "$repo" --title "$title" --body-file "$file" >/dev/null
      echo "$CLI_NAME: updated $repo#$num from $file"
    else
      num="$(gh issue create --repo "$repo" --title "$title" --label "$LABEL" \
               --body-file "$file" --json number --jq .number 2>/dev/null \
             || gh issue create --repo "$repo" --title "$title" --label "$LABEL" \
                  --body-file "$file" | sed 's#.*/##')"
      echo "$CLI_NAME: created $repo#$num from $file"
    fi
    ;;
  pull)
    out=""
    [ "${3:-}" = "--out" ] && { out="${4:-}"; [ -n "$out" ] || die "--out needs a path"; }
    num="$(find_one "$repo")"
    body="$(gh issue view "$num" --repo "$repo" --json body --jq .body)"
    [ -n "$body" ] || die "$repo#$num is empty. An empty brief is a broken one; not writing it."
    if [ -n "$out" ]; then
      mkdir -p "$(dirname "$out")"
      printf '%s\n' "$body" > "$out"
      echo "$CLI_NAME: $repo#$num -> $out"
    else
      printf '%s\n' "$body"
    fi
    ;;
  check)
    num="$(find_one "$repo")"
    gh issue view "$num" --repo "$repo" \
      --json number,title,updatedAt,author \
      --jq '"\(.number)\t\(.updatedAt)\t\(.author.login)\t\(.title)"'
    ;;
  *) usage ;;
esac
