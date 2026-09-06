#!/usr/bin/env bash
set -uo pipefail  # narrowed-close-check.sh -- does a PR body close an issue it only did part of?
#
# RUNNER: .github/workflows/tests.yml (narrowed-close job)
# GUARD-TEST: bin/tests/narrowed-close-check.test.sh
# GATE: default
#
# WHY, and the three bodies it was built from: hf7y/realisateur#1057.

CLI_NAME='narrowed-close-check.sh'
CLI_SUMMARY='does a PR body close an issue it only did part of?'
CLI_USAGE='  narrowed-close-check.sh <owner/repo> <pr-number>   grade one PR body
  narrowed-close-check.sh --body-file <path>         grade a body already on disk'
CLI_FLAGS='--body-file'
CLI_POSITIONAL=any
CLI_EXITS='  0  no closing keyword is narrowed by the words after it
  1  FINDING -- a keyword closes an issue the sentence says it only partly did
  6  BLIND -- the body could not be read. NEVER reported as clean.'
HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
. "$HERE/lib/cli-guard.sh"
cli_guard "$@"

BODY_FILE=''
SLUG=''
PR=''
while [ $# -gt 0 ]; do
  case "$1" in
    --body-file) BODY_FILE="${2:?--body-file needs a path}"; shift ;;
    -*) echo "$CLI_NAME: unknown flag $1" >&2; exit 2 ;;
    *) if [ -z "$SLUG" ]; then SLUG="$1"; else PR="$1"; fi ;;
  esac
  shift
done

if [ -n "$BODY_FILE" ]; then
  [ -r "$BODY_FILE" ] || { echo "BLIND: cannot read $BODY_FILE" >&2; exit 6; }
  BODY="$(cat "$BODY_FILE")"
else
  command -v gh >/dev/null 2>&1 || { echo "BLIND: gh not on PATH -- no body to grade" >&2; exit 6; }
  if [ -n "$SLUG" ] && [ -n "$PR" ]; then
    BODY="$(gh pr view "$PR" --repo "$SLUG" --json body --jq .body 2>/dev/null)" || {
      echo "BLIND: could not read $SLUG#$PR" >&2; exit 6; }
  else
    BODY="$(gh pr view --json body --jq .body 2>/dev/null)" || {
      echo "BLIND: no PR named and none open for this branch -- nothing was graded." >&2
      echo "       usage: $CLI_NAME <owner/repo> <pr-number>" >&2
      exit 6; }
  fi
fi
[ -n "$BODY" ] || { echo "BLIND: $CLI_NAME read an empty body -- nothing was graded" >&2; exit 6; }

findings=0
fenced=0
while IFS= read -r line; do
  case "$line" in
    '```'*) fenced=$((1 - fenced)); continue ;;
  esac
  [ "$fenced" -eq 1 ] && continue
  line="$(printf '%s' "$line" | sed 's/`[^`]*`//g')"
  case "$line" in
    *'#'*) ;;
    *) continue ;;
  esac
  clause="$(printf '%s' "$line" | grep -oiE '(close[sd]?|fix(e[sd])?|resolve[sd]?)[[:space:]]+#[0-9]+[^;.]*' | head -1)"
  [ -n "$clause" ] || continue
  num="$(printf '%s' "$clause" | grep -oE '#[0-9]+' | head -1)"
  tell=''
  printf '%s' "$clause" | grep -qE "#[0-9]+['’]s" && tell="a possessive: the sentence closes something BELONGING to $num, not $num"
  if [ -z "$tell" ]; then
    printf '%s' "$clause" | grep -qiE '\b(half|halves|part|partial|gap|remainder|remaining|portion|side|step|one of)\b' \
      && tell="a narrowing noun: the sentence says this is part of $num, not all of it"
  fi
  [ -n "$tell" ] || continue
  findings=$((findings + 1))
  echo "FINDING: $clause"
  echo "  $tell."
  echo "  GitHub's parser stops at $num and will close it whole on merge."
  echo "  Use a bare ($num) reference instead -- it does not auto-close -- and close"
  echo "  $num by hand when its own claim is true."
done <<< "$BODY"

if [ "$findings" -gt 0 ]; then
  echo
  echo "$CLI_NAME: $findings narrowed closing keyword(s)."
  exit 1
fi
echo "$CLI_NAME: no closing keyword is narrowed by the words after it."
exit 0
