#!/usr/bin/env bash
# decision-rot.sh -- how many of Zach's answers is nobody acting on?
#
# RUNNER: no -- a SURVEY, not a guard: run in a triage pass, or ahead of an /ideate or /nightly-batch
# GUARD-TEST: bin/tests/decision-rot.test.sh -- 32 cases, offline behind a fake `gh`
# GATE: none -- reads live issue trackers across 18 repos
#
# THE PREDICATE: ANSWERED **AND** STILL OPEN. That is the whole thing, and it
# introduces no label, no field, no file, no schema and no new state. It
# follows from behaviour that already exists:
#   * Zach answers by COMMENTING and LEAVES THE ISSUE OPEN (his words,
#     2026-08-14), so an answer never closes anything;
#   * the nightly acts on an issue and then CLOSES it, so closing is the
#     estate's existing signal for "handled".
# An answered issue still open is therefore direction handed over and never
# taken up. Closed-and-answered is not rot.
#
# TRAP: if a future change to this audit needs a convention INVENTED to make
#   it work, THE AUDIT IS WRONG -- report that and stop. An earlier draft
#   defined rot as "no commit or PR referencing the issue is newer than the
#   answer". It worked, and it could go stale SILENTLY: a change in how people
#   write commit messages would quietly stop resolving references and the tool
#   would report a smaller, wrong number with no signal. The predicate above
#   fails LOUDLY in both directions instead.
#
# TRAP: ANSWERED is hf7y/chezz's predicate, reused as a CONVENTION and NOT
#   imported -- that dependency would run the wrong direction across repos.
#   It is NOT the `answered` label; nothing applies it.
#
# KNOWN GAP: an agent comment that is not stamped is indistinguishable from
#   Zach's, and such comments exist in the estate today. That is a defect in
#   the stamping, not in this predicate; the fix belongs where the stamp is
#   written (bin/gh-sign.sh), not in a clause added here.
#
set -uo pipefail

CLI_NAME='decision-rot.sh'
CLI_SUMMARY='is an answered issue still sitting open?'
CLI_USAGE='  decision-rot.sh --all              audit every ecosystem1 repo
  decision-rot.sh <owner>/<repo>    audit one repo
  decision-rot.sh --all --json      machine-readable NDJSON + summary line'
CLI_FLAGS='--all --json'
CLI_POSITIONAL=any
CLI_EXITS='  0  clean -- every answered issue has been closed
  1  rot found -- at least one answered issue is still open
  3  error -- a repo could not be read; the count is NOT trustworthy'
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

# DECISION_ROT_OWNER exists for bin/tests/decision-rot.test.sh, which pins the
# predicate against fixture JSON whose author login is not this estate's.
OWNER="${DECISION_ROT_OWNER:-hf7y}"

# THE ROSTER. Derived 2026-08-15 from hf7y/scheduler `schedule/<project>.conf`
# -- the fifteen projects dispatch actually reads -- plus the three ecosystem
# repos that carry decisions but are never dispatched (`verbs` is the verb
# build channel; `front-door` and `basheur` are ecosystem infrastructure).
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
ROSTER=(
  baudin bibliothecaire chezz crt ecosim gardien groc-mangr nine-speakers
  realisateur scheduler secretaire senechal sequestria vim-arcade wtul
  verbs front-door basheur
)

MODE=''
REPOS=()
JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --all) MODE=all; shift ;;
    --json) JSON=1; shift ;;
    */*) MODE=one; REPOS+=("$1"); shift ;;
    *) echo "decision-rot.sh: not an <owner>/<repo>: $1" >&2; exit 2 ;;
  esac
done
if [ -z "$MODE" ]; then
  echo "decision-rot.sh: pass --all or an <owner>/<repo>" >&2
  exit 2
fi
if [ "$MODE" = all ]; then
  for p in "${ROSTER[@]}"; do REPOS+=("$OWNER/$p"); done
fi

command -v gh >/dev/null || { echo "decision-rot.sh: gh not on PATH" >&2; exit 3; }
command -v jq >/dev/null || { echo "decision-rot.sh: jq not on PATH" >&2; exit 3; }

# THE PREDICATE, in one jq program, so bin/tests/decision-rot.test.sh can pin
# it against fixtures with no network. stdin is a `gh issue list --json
# number,title,state,labels,comments` array.
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
DECISION_ROT_JQ='
  # stamped: TRUE iff the body`s LAST NON-BLANK LINE opens with the agent
  # marker. A marker, not a field grammar -- see the header.
  def stamped:
    (. // "") | split("\n") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0))
    | if length == 0 then false else (.[-1] | test("^<!--\\s*agent:")) end;
  # The answer: the LATEST owner comment that is not agent-stamped. An older
  # answer that was taken up does not excuse a newer one that was not.
  def answer:
    [ .comments[]? | select((.author.login // "") == $o) | select((.body | stamped) | not) ]
    | if length == 0 then null else (sort_by(.createdAt) | .[-1]) end;
  # The `answered` label is an optional override, never the trigger. It still
  # needs a clock, so it falls back to the newest owner comment of any kind.
  def labelled_answer:
    if ((.labels // []) | any(.name == "answered"))
    then ([ .comments[]? | select((.author.login // "") == $o) ]
          | if length == 0 then null else (sort_by(.createdAt) | .[-1]) end)
    else null end;
  def answered: (answer // labelled_answer);
'

rot_scan() {
  jq -r --arg o "$1" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$DECISION_ROT_JQ"'
    .[]
    | . as $i
    | answered as $a
    | select($a != null)
    | select($i.state == "OPEN")            # <-- ROT: answered, and still open
    | [ $i.number,
        ($a.createdAt | split("T")[0]),
        ((($now | fromdateiso8601) - ($a.createdAt | fromdateiso8601)) / 86400 | floor),
        ($i.title | gsub("\\s+"; " "))
      ] | @tsv'
}

answered_count() {
  jq -r --arg o "$1" "$DECISION_ROT_JQ"'
    [ .[] | select(answered != null) ] | length'
}

ERRORS=0
TOTAL_ANSWERED=0
TOTAL_ROT=0
ROWS=''   # repo<TAB>answered<TAB>rot<TAB>oldest_days
ROT=''    # repo<TAB>number<TAB>answered_at<TAB>age_days<TAB>title

for repo in "${REPOS[@]}"; do
  if ! issues=$(gh issue list --repo "$repo" --state all --limit 500 \
                  --json number,title,state,labels,comments 2>&1); then
    case "$issues" in
      *"issues are disabled"*|*"Issues are disabled"*)
        printf '%-16s (issues disabled)\n' "${repo#*/}" >&2 ;;
      *)
        printf 'decision-rot.sh: ERROR reading %s: %s\n' "$repo" "$issues" >&2
        ERRORS=$((ERRORS+1)) ;;
    esac
    continue
  fi
  if ! printf '%s' "$issues" | jq -e 'type == "array"' >/dev/null 2>&1; then
    printf 'decision-rot.sh: ERROR %s returned a non-array (rate limit? token scope?)\n' "$repo" >&2
    ERRORS=$((ERRORS+1)); continue
  fi

  n_answered=$(printf '%s' "$issues" | answered_count "$OWNER")
  rows=$(printf '%s' "$issues" | rot_scan "$OWNER")
  n_rot=$(printf '%s\n' "$rows" | grep -c .)
  oldest=$(printf '%s\n' "$rows" | grep . | cut -f3 | sort -rn | head -n1)

  TOTAL_ANSWERED=$((TOTAL_ANSWERED + n_answered))
  TOTAL_ROT=$((TOTAL_ROT + n_rot))
  ROWS+="${repo#*/}"$'\t'"$n_answered"$'\t'"$n_rot"$'\t'"${oldest:-0}"$'\n'
  while IFS= read -r line; do
    [ -n "$line" ] && ROT+="$repo"$'\t'"$line"$'\n'
  done <<< "$rows"
done

if [ "$JSON" = 1 ]; then
  printf '%s' "$ROT" | while IFS=$'\t' read -r r n a g t; do
    [ -n "$r" ] || continue
    jq -cn --arg repo "$r" --argjson number "$n" --arg answered_at "$a" \
           --argjson age_days "$g" --arg title "$t" \
           '{kind:"rotting",repo:$repo,number:$number,answered_at:$answered_at,age_days:$age_days,title:$title}'
  done
  jq -cn --argjson repos "${#REPOS[@]}" --argjson answered "$TOTAL_ANSWERED" \
         --argjson rotting "$TOTAL_ROT" --argjson errors "$ERRORS" \
         '{kind:"summary",repos:$repos,answered:$answered,rotting:$rotting,errors:$errors}'
else
  printf '%-18s %9s %8s %12s\n' REPO ANSWERED ROTTING OLDEST_DAYS
  printf '%s' "$ROWS" | while IFS=$'\t' read -r r a n o; do
    [ -n "$r" ] || continue
    printf '%-18s %9s %8s %12s\n' "$r" "$a" "$n" "$o"
  done
  printf '%-18s %9s %8s\n' TOTAL "$TOTAL_ANSWERED" "$TOTAL_ROT"
  if [ "$TOTAL_ROT" -gt 0 ]; then
    echo
    echo 'ROTTING -- answered, still open:'
    printf '%s' "$ROT" | sort -t$'\t' -k4,4rn | while IFS=$'\t' read -r r n a g t; do
      [ -n "$r" ] || continue
      printf '  %-16s #%-5s answered %s  %4sd  %s\n' "${r#*/}" "$n" "$a" "$g" "$t"
    done
  fi
fi

if [ "$ERRORS" -gt 0 ]; then
  echo "decision-rot.sh: $ERRORS repo(s) unreadable -- the count above is NOT trustworthy" >&2
  exit 3
fi
[ "$TOTAL_ROT" -gt 0 ] && exit 1
exit 0
