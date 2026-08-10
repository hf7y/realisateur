#!/usr/bin/env bash
# selfdev-agent-survey.sh -- what does each self-dev account ACTUALLY do on
# its own dispatch run, vs. what its own prompt claims it does?
#
# RUN ON THE SELF-DEV HOST, AS ROOT (or via sudo):
#   sudo bash bin/selfdev-agent-survey.sh
#
# Offline against nothing -- it shells out to git, gh and sudo -u <account>
# for every row, so it costs real wall-clock and a live GitHub token per
# account. READ-ONLY throughout: no commit, no push, no gh mutation, no
# crontab or file write. Signals, not verdicts, same stance as
# hygiene-lint.sh/no-self-dev.sh -- a GAP here is something to look at, not
# a proven bug.
#
# THE FOUR EXPECTED BEHAVIORS (Zach, 2026-08-10). A self-dev run should:
#   1. RECONCILE  -- diff local checkout against origin, converge on it
#   2. ISSUES     -- look at its repo's open issues
#   3. PRS        -- look at its repo's open pull requests
#   4. WORKS      -- act on what it found (close/merge/comment/push)
# This walks every account in the self-dev uid band (same band
# provision-selfdev-user.sh creates accounts in) and checks each behavior
# two ways: does the account's OWN dispatch prompt (its
# .claude/commands/*.md) claim to do it, and does its OWN recent run log
# show evidence it actually did. The two can disagree in either direction --
# that disagreement is the finding.
#
# WHY THIS EXISTS. PR hf7y/ecosim#41 sat ready-to-review and untouched
# through three of ecosim's own dispatch ticks: its loop re-checks a fixed
# issue queue but has no PR sweep at all, so a ready PR on its own repo is
# currently invisible to it by construction. That was found by hand, one
# account at a time. Before rewriting the self-dev prompt/dispatch logic
# fleet-wide, get the SAME read on every account in one pass, mechanically,
# so the rewrite is aimed at measured gaps instead of the one gap that
# happened to get noticed.
set -uo pipefail

CLI_NAME='selfdev-agent-survey.sh'
CLI_SUMMARY='per self-dev account: does its prompt claim, and its log show, reconcile/issues/PRs/work-them?'
CLI_USAGE='  selfdev-agent-survey.sh   survey every account in the self-dev uid band; read-only'
CLI_FLAGS=''
CLI_POSITIONAL=none
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

UID_MIN="${SELFDEV_UID_MIN:-3000}"
UID_MAX="${SELFDEV_UID_MAX:-3099}"
GH_OWNER="${SELFDEV_GH_OWNER:-hf7y}"
LOG_TAIL="${SELFDEV_SURVEY_LOG_LINES:-400}"

# --- pure classification: given a blob of text, which of the four behaviors
# does it mention? Kept as standalone functions (no account/host access) so
# bin/tests/selfdev-agent-survey.test.sh can exercise them directly against
# fixture text -- the only part of this script that has a right answer
# independent of live machine state.
classify_reconcile() { grep -qEi 'git (fetch|pull|diff)|reconcile|ahead[^.]{0,20}behind|local[^.]{0,20}remote|origin/main|pushed: yes' <<<"$1" && echo yes || echo no; }
classify_issues()    { grep -qEi 'gh issue|issue list|open issue' <<<"$1" && echo yes || echo no; }
classify_prs()       { grep -qEi 'gh pr\b|pull request|\bPR #|pr list' <<<"$1" && echo yes || echo no; }
# "no opened/closed issues this run" is real idle-log phrasing (verbatim from
# ecosim's own sweep.log) that would otherwise false-positive on the bare
# verb match below -- strip "no ... closed/merged/opened" before matching.
classify_works() {
  local t
  t="$(sed -E 's#\bno[^.]{0,25}(closed|merged|opened)(/(closed|merged|opened))?\b#*#gi' <<<"$1")"
  grep -qEi 'close[sd]?\b|merge[sd]?\b|comment on|resolve[sd]?\b|act on|work(ed)? (it|them|the queue)' <<<"$t" && echo yes || echo no
}

row() { printf '    %-10s claims=%-3s evidence=%-3s  %s\n' "$1" "$2" "$3" "$4"; }

survey_account() {
  local acct="$1" home repo prompt_text="" log_text="" verdict_gaps=""
  home="$(getent passwd "$acct" | cut -d: -f6)"
  echo
  echo "== $acct (uid $(id -u "$acct" 2>/dev/null), home $home) =="

  repo="$home/Documents/Projects/$acct"
  if [ ! -d "$repo/.git" ]; then
    echo "  SKIP  no $repo checkout -- cannot survey this account's own repo"
    return
  fi

  # -- 1. reconcile: local HEAD vs. what origin actually has, plus tree state
  local local_head remote_head dirty
  local_head="$(sudo -u "$acct" git -C "$repo" rev-parse HEAD 2>/dev/null || echo unknown)"
  remote_head="$(sudo -u "$acct" git -C "$repo" ls-remote origin HEAD 2>/dev/null | cut -f1)"
  dirty="$(sudo -u "$acct" git -C "$repo" status --porcelain 2>/dev/null)"
  if [ -z "$remote_head" ]; then
    echo "  RECONCILE  UNKNOWN -- could not read origin (network/auth?)"
  elif [ "$local_head" = "$remote_head" ] && [ -z "$dirty" ]; then
    echo "  RECONCILE  OK -- local == origin HEAD ($local_head), tree clean"
  else
    [ "$local_head" != "$remote_head" ] && echo "  RECONCILE  DRIFT -- local $local_head != origin $remote_head"
    [ -n "$dirty" ] && echo "  RECONCILE  DIRTY -- uncommitted changes present (a dirty tree at exit is a failed run)"
    verdict_gaps="$verdict_gaps reconcile"
  fi

  # -- 2/3. issues and PRs, live from GitHub, as the account's own token
  local issues_n="unknown" prs_ready="unknown" prs_draft="unknown"
  if sudo -u "$acct" gh auth status >/dev/null 2>&1; then
    issues_n="$(sudo -u "$acct" gh issue list --repo "$GH_OWNER/$acct" --state open --json number 2>/dev/null | grep -c '"number"' || echo 0)"
    local pr_json
    pr_json="$(sudo -u "$acct" gh pr list --repo "$GH_OWNER/$acct" --state open --json number,isDraft 2>/dev/null)"
    prs_ready="$(grep -o '"isDraft":false' <<<"$pr_json" | wc -l | tr -d ' ')"
    prs_draft="$(grep -o '"isDraft":true'  <<<"$pr_json" | wc -l | tr -d ' ')"
  fi
  echo "  ISSUES     open=$issues_n (repo $GH_OWNER/$acct)"
  echo "  PRS        ready=$prs_ready draft=$prs_draft"

  # -- prompt text: every slash command this account's own repo ships, since
  # dispatch resolves to one of them and which one varies by conf/tier
  local f
  for f in "$repo"/.claude/commands/*.md; do
    [ -f "$f" ] && prompt_text="$prompt_text
$(cat "$f")"
  done
  [ -z "$prompt_text" ] && echo "  PROMPT     none found under $repo/.claude/commands/"

  # -- recent evidence: the account's own dispatch log, whichever job dir it lands in
  for f in "$home"/.local/share/*-nightly-batch/sweep.log "$home"/.local/share/*-nightly-batch/run.log "$home"/reports/*/LATEST.md; do
    [ -f "$f" ] && log_text="$log_text
$(tail -n "$LOG_TAIL" "$f")"
  done
  [ -z "$log_text" ] && echo "  LOG        no sweep.log/run.log/LATEST.md found under $home"

  local dim claims evidence
  for dim in reconcile issues prs works; do
    claims="$(classify_"$dim" "$prompt_text")"
    evidence="$(classify_"$dim" "$log_text")"
    row "$dim" "$claims" "$evidence" "$( [ "$claims" = yes ] && [ "$evidence" = no ] && echo '<- claims it, no recent evidence' )"
    [ "$claims" = yes ] && [ "$evidence" = no ] && verdict_gaps="$verdict_gaps $dim"
  done

  if [ -n "$verdict_gaps" ]; then
    echo "  VERDICT    GAP --$verdict_gaps (signal, not proof -- a quiet night looks identical to a blind spot)"
  else
    echo "  VERDICT    no gap seen this pass"
  fi
}

main() {
  [ "$(id -u)" -eq 0 ] || echo "$CLI_NAME: not running as root -- sudo -u <account> calls below will mostly fail" >&2

  local accounts
  accounts="$(getent passwd | awk -F: -v lo="$UID_MIN" -v hi="$UID_MAX" '$3>=lo && $3<=hi {print $1}' | sort)"
  if [ -z "$accounts" ]; then
    echo "$CLI_NAME: no accounts found in uid band $UID_MIN-$UID_MAX" >&2
    exit 1
  fi

  echo "selfdev-agent-survey: uid band $UID_MIN-$UID_MAX, $(wc -l <<<"$accounts" | tr -d ' ') account(s)"
  local acct
  while IFS= read -r acct; do
    survey_account "$acct"
  done <<<"$accounts"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then main; fi
