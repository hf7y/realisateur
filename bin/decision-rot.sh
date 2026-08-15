#!/usr/bin/env bash
# decision-rot.sh -- how many of Zach's answers is nobody acting on?
#
# RUNNER: no -- a SURVEY, not a guard: run in a triage pass, or ahead of an /ideate or /nightly-batch
# GUARD-TEST: bin/tests/decision-rot.test.sh -- 32 cases, offline behind a fake `gh`
#
# ============================================================================
# THE QUESTION
# ============================================================================
#
# Zach, 2026-08-15: "how many decisions are just being left to rot right now.
# how can we audit that? is putting decisions in issues and spawning self-dev
# not adequate?"
#
# Filing a decision in an issue is only half a channel. The other half is
# something CONSUMING it, and nothing anywhere measured that. hf7y/chezz's
# scripts/answered-issues.mjs (2026-08-14) closed the first half -- it can tell
# an ANSWERED issue from an unanswered one -- after the wrong predicate
# silently ate four of Zach's replies for up to 16 days. This is the second
# half, and it needs no new machinery at all.
#
# ============================================================================
# THE PREDICATE: ANSWERED **AND** STILL OPEN. THAT IS THE WHOLE THING.
# ============================================================================
#
# It follows from behaviour that already exists, so there is nothing here to
# keep in sync with anything:
#
#   * Zach answers by COMMENTING and LEAVES THE ISSUE OPEN (his words,
#     2026-08-14). So an answer never closes anything.
#   * The nightly acts on an issue and then CLOSES it. So closing is the
#     estate's existing, unforced signal for "this was handled".
#
# Therefore an answered issue that is still open is, by the system's own
# convention, direction that was handed over and never taken up. An answered
# issue that is closed was handled -- checked against real data before being
# baked in: hf7y/chezz's answered-and-closed issues are #1 ("PILOT (safe to
# close)"), #8 (a test dry-run), and #14/#17/#19 (nightly build checks). Every
# one is genuinely finished. Closed-and-answered is not rot.
#
# No commit crawling, no reference parsing, no comparing comment dates against
# commit dates.
#
# THIS TOOL IS A READER, NOT A PROTOCOL. It introduces no label, no field, no
# file, no schema and no new state, and it must stay that way. Everything it
# reports is derivable by a person looking at the issue page right now. An
# earlier draft of this script defined rot as "no commit or PR referencing the
# issue is newer than the answer" and resolved that through the GitHub issue
# timeline. It worked. It was still wrong, and Zach's objection is the general
# one: a new clause is one more thing to go stale. If a future change to this
# audit needs a convention invented to make it work, THE AUDIT IS WRONG --
# report that and stop, rather than inventing one.
#
# ============================================================================
# "WHERE IS THIS? PROSE? ANOTHER LIABILITY TO GO STALE?" -- Zach, 2026-08-15
# ============================================================================
#
# Fair question, and the answer has two halves.
#
# WHERE IT LIVES. Not in prose. The predicate is the jq program below, in one
# place, and `bin/tests/decision-rot.test.sh` pins it against fixtures -- case
# B is the closed-issue trap, case C the stamped-agent-comment trap. CI globs
# `bin/tests/*.sh`, so changing the predicate without changing the test stops
# a merge. Everything above this line is commentary on code that runs; delete
# all of it and the audit is unchanged.
#
# CAN IT GO STALE. Yes -- but not silently, and that is the whole difference.
# It rests on two live behaviours, and if either one changes the number moves
# LOUDLY rather than quietly becoming wrong:
#
#   * if the nightly stops closing what it acts on, ROTTING climbs toward
#     ANSWERED and the tool screams;
#   * if Zach starts closing issues when he answers them, ANSWERED collapses
#     toward zero -- and a 423-to-single-digits drop in the denominator is not
#     something a reader can miss.
#
# Compare the clause this replaced ("no commit or PR referencing it is newer
# than the answer"): that one could go stale SILENTLY, because a change in how
# people write commit messages would quietly stop resolving references and the
# tool would have gone on reporting a smaller, wrong number with no signal. A
# predicate that fails loud in both directions is not the same kind of thing
# as one that fails quiet, even though both can be outlived.
#
# The remaining honest gap is named under SILENT ZERO's sibling below: an
# agent comment that is NOT stamped is indistinguishable from Zach's, and
# there are such comments in the estate today. That is a defect in the
# stamping, not in this predicate, and the fix belongs where the stamp is
# written -- not in a clause added here.
#
# ANSWERED is hf7y/chezz's predicate, reused verbatim as a CONVENTION and not
# imported -- that dependency would run the wrong direction across repos, and
# chezz's own header says so. Nothing is added to it. Its three findings,
# restated because each is a trap this script would otherwise have fallen into:
#
#   * NOT the `answered` label. Nothing applies it. Every consumer that
#     queried `--label question --label answered` matched nothing, forever,
#     and reported "0 answered" while exiting OK. Honoured as an optional
#     override if someone ever bothers; never the trigger.
#   * NOT issue STATE, for ANSWERED. State is the ROT half of the predicate,
#     which is exactly why the answer scan reads `--state all`: an answer that
#     landed on a closed issue still happened, and scanning only open issues
#     would make the denominator a function of the numerator.
#   * The STAMP is checked on the LAST NON-BLANK LINE ONLY (hf7y/vim-arcade#77's
#     predicate, mirrored in ecosim lib/provenance.py and bin/gh-comment.sh).
#     Under one shared `hf7y` token an agent's own reply looks EXACTLY like
#     Zach's, and the stamp is the only thing separating them -- this is the
#     one genuine ambiguity in the data and it is already solved. Checking the
#     whole body instead would let a stamp quoted mid-comment out of another
#     comment silently disqualify a human answer.
#
# AGE is days since that answer comment's own timestamp, read straight off the
# comment. It is the only number here that is not a boolean, and it is what
# makes the count actionable rather than merely true.
#
# WHAT IT DELIBERATELY DOES NOT CATCH -- named because a survey that does not
# state its blind spot gets read as an estate-wide count. Some decisions were
# never in an issue at all: hf7y/scheduler `schedule/FREEZE`'s sunset recorded
# in FREEZE's own header, `WAITING-ROOM.md` recording a merge as done that
# never ran, "resume 2026-08-13" as prose in a config comment. A decision
# written into a tracked FILE is outside this predicate by construction. That
# is a second audit, not a wider `--limit`.
#
# ============================================================================
# SILENT ZERO
# ============================================================================
#
# A count like this has been wrong-and-loud in this estate before, always by
# reporting a zero that meant "the query broke". Every path that could produce
# a zero for a reason other than "no rot" exits 3 instead:
#
#   * `gh` failing, rate-limiting, or returning a non-array -- exit 3, naming
#     the repo. A token that returns `[]` rather than an error is why the
#     ANSWERED column is printed per repo even when it is zero: a repo whose
#     issues did not load reads `0 answered`, and only the printed row lets a
#     reader see that 0-of-0 is not 0-of-40.
#   * a missing or renamed repo is a loud failure, not a quiet 15-of-18. Only
#     an explicit "issues are disabled" is soft, and it says so on stderr.
#   * `--state all`, never `--state open`, for the answer scan, and never
#     `gh search` -- `--state` and `--search` do not mean the same thing and
#     the difference has eaten answers here before.
#   * `--limit 500`, above every repo's issue count, because `gh issue list`
#     silently defaults to 30.
#   * issue titles are never parsed out of a `\(.number)\t\(.title)` line. A
#     title containing a newline split that line in two and the second half
#     was fed to `jq --argjson` as an issue number -- one jq error on stderr,
#     one issue silently dropped, on this script's first live run.
#   * any per-repo error makes the WHOLE run exit 3, even if the other
#     seventeen repos were clean.
#
# Usage:
#   bin/decision-rot.sh --all             every ecosystem1 repo (the roster below)
#   bin/decision-rot.sh <owner>/<repo>    one repo
#   bin/decision-rot.sh --all --json      NDJSON, one object per rotting issue,
#                                         then one `{"kind":"summary",...}` line
#
# ONE REPO **OR** ALL, because the two callers want different things and
# neither is served by the other. `--all` is the number Zach asked for and the
# only form a future gate can threshold on -- rot is an ESTATE property, and
# per-repo runs would have to be summed by whoever ran them, which is the
# eyeballing this replaces. The single-repo form exists for drill-down and for
# a per-project run.
#
# Exit codes:
#   0  clean -- every answered issue has been closed
#   1  rot found -- at least one answered issue is still open
#   2  usage error (cli-guard.sh)
#   3  error -- a repo could not be read; the count is NOT trustworthy
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
# Held here rather than fetched from scheduler because this script must run
# from any account with only `gh`, including the read-only deploy-key ones,
# and because a network read of another repo's config is a second thing that
# can fail silently. Re-derive, do not trust:
#   gh api repos/hf7y/scheduler/contents/schedule -q '.[].name'
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
#
# rot_scan <owner>       -> TSV per ROTTING issue: number, answer date, age days, title
# answered_count <owner> -> the ANSWERED total, same predicate, no state filter
DECISION_ROT_JQ='
  # isStamped: TRUE iff the body`s LAST NON-BLANK LINE is an agent provenance
  # stamp. hf7y/vim-arcade#77`s predicate, verbatim.
  def stamped:
    (. // "") | split("\n") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0))
    | if length == 0 then false
      else (.[-1] | test("^<!--\\s*agent:\\s*\\S+/\\S+\\s+\\S+\\s*-->$"))
      end;
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
