#!/usr/bin/env bash
#
# selfdev-agent-survey.test.sh -- witness for the classify_* functions, the
# only part of selfdev-agent-survey.sh with a right answer independent of
# live machine/GitHub state. Offline, zero AI, no network, no sudo.
#
# Everything else in the script (account discovery, git/gh calls, log
# reading) needs a real self-dev host to exercise meaningfully -- this file
# does not attempt to fake that; it proves the yes/no classifier is not
# trivially always-yes or always-no on realistic text, in both directions
# (prompt text that claims a behavior, log text that shows it happened, and
# text that does neither).
#
# Usage: bin/tests/selfdev-agent-survey.test.sh   (exit 0 = all pass)
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
REPO_BIN="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_BIN/selfdev-agent-survey.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }


# shellcheck source=/dev/null
. "$SCRIPT"   # BASH_SOURCE guard keeps main() from firing; classify_* land in scope

# --- prompt text that claims all four -----------------------------------
PROMPT_FULL='Read .scheduler/FOCUS.md. Run git fetch and diff against origin/main
to reconcile. List open issues with gh issue list. Check gh pr list for
pull requests. Close or merge whatever is actionable, and work the queue.'
eq "prompt: reconcile claimed"  "$(classify_reconcile "$PROMPT_FULL")" yes
eq "prompt: issues claimed"     "$(classify_issues    "$PROMPT_FULL")" yes
eq "prompt: prs claimed"        "$(classify_prs        "$PROMPT_FULL")" yes
eq "prompt: works claimed"      "$(classify_works      "$PROMPT_FULL")" yes

# --- prompt text that claims only issues, like ecosim's real gap -------
PROMPT_ISSUES_ONLY='Work the open issue queue: re-verify each one live and
close what is actionable.'
eq "prompt: issues-only reconcile=no" "$(classify_reconcile "$PROMPT_ISSUES_ONLY")" no
eq "prompt: issues-only issues=yes"   "$(classify_issues    "$PROMPT_ISSUES_ONLY")" yes
eq "prompt: issues-only prs=no"       "$(classify_prs        "$PROMPT_ISSUES_ONLY")" no

# --- empty / unrelated text claims nothing -------------------------------
eq "empty: reconcile=no" "$(classify_reconcile "")" no
eq "empty: issues=no"    "$(classify_issues "")" no
eq "empty: prs=no"       "$(classify_prs "")" no
eq "empty: works=no"     "$(classify_works "")" no
UNRELATED='Wrote a README and drank coffee.'
eq "unrelated: works=no" "$(classify_works "$UNRELATED")" no

# --- log evidence text, the same classifiers applied to a run transcript -
LOG_WITH_EVIDENCE='pushed: yes -- 32fd897 -> 44b98a8
Closed hf7y/ecosim#38 -- wired the credential helper.
gh pr list showed nothing ready this run.'
eq "log: reconcile evidence"  "$(classify_reconcile "$LOG_WITH_EVIDENCE")" yes
eq "log: works evidence"      "$(classify_works      "$LOG_WITH_EVIDENCE")" yes
eq "log: prs evidence (list, not act)" "$(classify_prs "$LOG_WITH_EVIDENCE")" yes

LOG_IDLE='No commits, no pushes, no opened/closed issues this run -- tree is clean.'
eq "log idle: works=no" "$(classify_works "$LOG_IDLE")" no

# --- classify_draft_aware: distinct from classify_prs (prs fires on any
# "gh pr list" mention; draft-aware requires the word itself) -----------
PROMPT_PRS_NO_DRAFT='Check gh pr list for anything ready to merge.'
eq "draft-aware: prs claimed"       "$(classify_prs         "$PROMPT_PRS_NO_DRAFT")" yes
eq "draft-aware: draft not claimed" "$(classify_draft_aware "$PROMPT_PRS_NO_DRAFT")" no
PROMPT_DRAFT='Check gh pr list. Skip anything still in draft state.'
eq "draft-aware: draft claimed" "$(classify_draft_aware "$PROMPT_DRAFT")" yes

# --- duplicated_line_count: the fleet-wide check's pure comparator ------
# Two accounts whose prompts share a long identical block (the
# hf7y/scheduler@9cfd130 shape: one STANDING RULES block hand-typed into
# multiple BATCH_PROMPT strings) vs. two whose prompts are genuinely
# unrelated project-specific text.
STANDING_RULES='0. MECHANISM FIRST. Talking is not dev, fix it in this run.
1. CLOSE WHAT YOU RESOLVED, in the same run that resolved it.
2. DEBT RULE: you may not open more issues than you close.
3. IF YOU ARE BLOCKED, name what you TRIED and the EXACT wall.
4. LAND YOUR WORK. Commits on a branch nobody merges are not delivered.
5. NO NEW MARKDOWN FILES. Prose is not a deliverable.'
PROMPT_A="You are ecosim, the monitoring project.
$STANDING_RULES
Work the issue queue starting with #34."
PROMPT_B="You are vim-arcade, the display project.
$STANDING_RULES
Work the issue queue starting with #75."
dup_count="$(duplicated_line_count "$PROMPT_A" "$PROMPT_B")"
if [ "$dup_count" -ge 5 ]; then ok "duplication: shared STANDING RULES block detected ($dup_count lines)"; else bad "duplication: expected >=5 shared lines, got $dup_count"; fi

# --- json_field_count: the headline COUNT, on gh's real one-line output --
# The regression this pins: `grep -c '"number"'` counts LINES, and gh emits
# the whole array on one, so every account in the 2026-08-10 fleet run
# reported `ISSUES open=1` -- chezz's real 11 and gardien's real 7 included.
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
GH_ISSUES_ONELINE='[{"number":12},{"number":9},{"number":7},{"number":3}]'
eq "json count: 4 issues on one line" "$(json_field_count "$GH_ISSUES_ONELINE" number)" 4
eq "json count: empty list is 0"      "$(json_field_count '[]' number)" 0
eq "json count: no response is 0"     "$(json_field_count '' number)" 0
eq "json count: single record is 1"   "$(json_field_count '[{"number":5}]' number)" 1

PROMPT_C='You are baudin. Nobody has decided what you are for yet.'
PROMPT_D='You are crt. A Playwright dependency is missing on this host.'
dup_count2="$(duplicated_line_count "$PROMPT_C" "$PROMPT_D")"
eq "duplication: unrelated prompts share nothing" "$dup_count2" 0

echo
summary
