#!/usr/bin/env bash
# needs-zach.sh -- is the `needs-human` label telling the truth?
#
# RUNNER: no -- a SURVEY, run in a triage pass or ahead of /ideate and /cloture
# GUARD-TEST: bin/tests/needs-zach.test.sh
# GATE: none -- reads live issue trackers
#
# THE PREDICATE, and it invents nothing: an open issue whose FIRST NON-EMPTY
# LINE declares `DECISION:` is waiting on a person; `NO-DECISION:` is not.
# That is grammar_declaration() in bin/lib/body-grammar.sh -- the rule
# bin/gh-sign.sh already enforces on every agent-written body at creation.
# So the label is DERIVED, and this reconciles it. Typed, it was wrong three
# times out of three on 2026-08-18: #396 has the measurement, #397 the estate.
#
# TRAP: line 1 declaring NEITHER is UNDECLARED, never quietly read as "no
# decision" -- nobody can tell whether it needs Zach, which is the question.
set -uo pipefail

CLI_NAME='needs-zach.sh'
CLI_SUMMARY='does the `needs-human` label match what each issue body declares?'
CLI_USAGE='  needs-zach.sh <owner>/<repo>          report drift, write nothing
  needs-zach.sh <owner>/<repo> --apply  add/remove the label to match the body'
CLI_FLAGS='--apply'
CLI_POSITIONAL='<owner>/<repo>'
CLI_EXITS='  0  every open issue`s label matches its declaration
  1  findings: a label disagrees with the body, or a body declares nothing
  2  usage error
  6  BLIND -- the issue list could not be read. Never 0: could-not-look is not clean.'
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/cli-guard.sh"
cli_guard "$@"
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/body-grammar.sh"

LABEL='needs-human'
APPLY=0
REPO=''
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    -*) printf '%s: unknown argument: %s\n' "$CLI_NAME" "$1" >&2; exit 2 ;;
    *)  [ -n "$REPO" ] && { printf '%s: one repo at a time\n' "$CLI_NAME" >&2; exit 2; }
        REPO="$1" ;;
  esac
  shift
done
[ -n "$REPO" ] || { printf '%s: name a repo: <owner>/<repo>\n' "$CLI_NAME" >&2; exit 2; }

say() { printf '%s\n' "$*"; }
row() { printf '  %-11s %-6s %s\n' "$1" "#$2" "${3:-}"; }

# One request, and its failure is BLIND. `gh issue list` prints [] for a repo
# that does not exist AND for one with no open issues, so the exit code is the
# only thing separating "nothing waiting" from "could not look".
json="$(gh issue list --repo "$REPO" --state open --limit 200 \
        --json number,title,body,labels 2>&1)" || {
  printf '%s: BLIND -- could not read %s: %s\n' "$CLI_NAME" "$REPO" "$json" >&2
  printf '%s: that is "I could not look", not "nothing needs Zach".\n' "$CLI_NAME" >&2
  exit 6
}

say "needs-zach -- $REPO, open issues, label vs line 1"
say ""

findings=0; matched=0; changed=0
while IFS=$'\t' read -r num has_label title; do
  [ -n "$num" ] || continue
  body="$(printf '%s' "$json" | jq -r --argjson n "$num" '.[]|select(.number==$n)|.body')"
  want=''
  case "$(grammar_declaration "$body")" in
    decision)    want=yes ;;
    no-decision) want=no ;;
    none)
      findings=$((findings + 1))
      row UNDECLARED "$num" "line 1 declares neither DECISION: nor NO-DECISION: -- ${title:0:52}"
      continue ;;
  esac
  [ "$has_label" = "$want" ] && { matched=$((matched + 1)); continue; }
  findings=$((findings + 1))
  if [ "$want" = yes ]; then
    row MISSING "$num" "declares DECISION: but is not labelled $LABEL -- ${title:0:52}"
    [ "$APPLY" -eq 1 ] && gh issue edit "$num" --repo "$REPO" --add-label "$LABEL" >/dev/null \
      && { changed=$((changed + 1)); row "  +label" "$num" "$LABEL added"; }
  else
    row STALE "$num" "labelled $LABEL but declares NO-DECISION: -- ${title:0:52}"
    [ "$APPLY" -eq 1 ] && gh issue edit "$num" --repo "$REPO" --remove-label "$LABEL" >/dev/null \
      && { changed=$((changed + 1)); row "  -label" "$num" "$LABEL removed"; }
  fi
done < <(printf '%s' "$json" | jq -r --arg l "$LABEL" \
  '.[] | [.number, (if any(.labels[]; .name==$l) then "yes" else "no" end), .title] | @tsv')

say ""
say "$matched issue(s) already agree, $findings finding(s), $changed label(s) written."
if [ "$findings" -gt 0 ] && [ "$APPLY" -eq 0 ]; then
  say 'Re-run with --apply to make the label match the body. An UNDECLARED body'
  say 'is NOT fixed by a label -- edit line 1, which is where the answer lives.'
fi
[ "$findings" -eq 0 ] || exit 1
