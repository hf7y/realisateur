#!/usr/bin/env bash
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
REPO_BIN="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_BIN/selfdev-agent-survey.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

pass=0; fail=0
ok()  { echo "  ok   $1"; pass=$((pass+1)); }
bad() { echo "  FAIL $1"; fail=$((fail+1)); }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected '$3', got '$2')"; fi; }

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

echo
echo "selfdev-agent-survey.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
