#!/usr/bin/env bash
# selfdev-agent-survey.sh -- what does each self-dev account ACTUALLY do on
# its own dispatch run, vs. what its own prompt claims it does?
#
# GUARD: no -- the `-survey` name matches guard-estate.test.sh's shape rule,
# and this is the opt-out it provides for a name that is not a gate. It cannot
# be one: it needs root on the self-dev host, a live `gh` token per account,
# and ten accounts to walk, so no CI job and no hook can ever run it. Its own
# header says the rest -- signals, not verdicts; a GAP here is something to
# look at, not a proven bug. What it does instead of gating is exit non-zero
# when it found something, so a human's shell can branch on it without
# scraping the text.
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
# two ways: does the account's OWN dispatch prompt claim to do it, and does
# its OWN recent run log show evidence it actually did. The two can disagree
# in either direction -- that disagreement is the finding.
#
# WHY THIS EXISTS. PR hf7y/ecosim#41 sat ready-to-review and untouched
# through three of ecosim's own dispatch ticks: its loop re-checks a fixed
# issue queue but has no PR sweep at all, so a ready PR on its own repo is
# currently invisible to it by construction. That was found by hand, one
# account at a time. Before rewriting the self-dev prompt/dispatch logic
# fleet-wide, get the SAME read on every account in one pass, mechanically,
# so the rewrite is aimed at measured gaps instead of the one gap that
# happened to get noticed.
#
# ADDITIONAL FAILURE SURFACES (2026-08-10, from the ecosim/vim-arcade
# global-instruction-mechanism discussion). Four more things turned out to
# be true of the monkey fleet the first version of this script could not
# see, because it only ever read $repo/.claude/commands/*.md -- which,
# ecosim.conf's own header admits, is "an unadapted copy of realisateur's
# template" nothing actually dispatches for a scheduler-run-based account.
# The REAL prompt lives in that account's OWN clone of the `scheduler` repo,
# at schedule/<acct>.conf's BATCH_PROMPT, sourced fresh by scheduler-run on
# every tick. So:
#   - PROMPT SOURCE now prefers that conf's BATCH_PROMPT (sourced the same
#     way scheduler-run sources it) over the command-file copy, falling
#     back only if no scheduler clone/conf is found.
#   - DUPLICATED PROSE: commit hf7y/scheduler@9cfd130 hand-typed an
#     identical "STANDING RULES" block into three separate accounts'
#     BATCH_PROMPT strings, byte-for-byte, with no shared source -- a
#     future edit to one and not the others is invisible until someone
#     diffs them by hand. Checked cross-account, once, after the per-account
#     loop (a single account's own claims/evidence read can't see this;
#     it's a property of the FLEET).
#   - STALE PROMPT REFS: prompts that hardcode a specific issue number
#     ("Start with #34") never get revisited once that issue closes -- the
#     ecosim/vim-arcade briefs do exactly this. Checked live against
#     GitHub's actual issue state.
#   - PULL-BLOCKED: the pull-before-dispatch step in usage-paced-runner.sh
#     is fail-loud-not-block by design -- a dirty or diverged scheduler
#     clone means that account silently never receives ANY global
#     instruction update, indefinitely, until a human notices. This is the
#     mechanical precondition for every fix above actually reaching an
#     account; check it directly rather than assuming a push landed.
#   - DRAFT-PR-BLIND: a prompt can claim PR awareness (classify_prs) via
#     "gh pr list" and still never mention "draft" -- which is exactly the
#     autonomy-merge engine's own blind spot (lib/autonomy-merge.sh walks
#     LOCAL branches, never checks GitHub's draft/ready state at all). If
#     draft PRs exist and the prompt is silent on the word, that gap is
#     real, not assumed.
set -uo pipefail

CLI_NAME='selfdev-agent-survey.sh'
CLI_SUMMARY='per self-dev account: does its prompt claim, and its log show, reconcile/issues/PRs/work-them? plus fleet-wide duplication/staleness/pull-health/draft-PR checks'
CLI_USAGE='  selfdev-agent-survey.sh   survey every account in the self-dev uid band; read-only'
CLI_FLAGS=''
CLI_POSITIONAL=none
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

UID_MIN="${SELFDEV_UID_MIN:-3000}"
UID_MAX="${SELFDEV_UID_MAX:-3099}"
GH_OWNER="${SELFDEV_GH_OWNER:-hf7y}"
LOG_TAIL="${SELFDEV_SURVEY_LOG_LINES:-400}"
# Evidence older than this is reported and then ignored. 3 days: the armed
# tick is `0 */6`, so a working account writes 4 entries a day and anything
# past 3 days means it has missed a dozen consecutive dispatches.
LOG_MAX_AGE_DAYS="${SELFDEV_SURVEY_LOG_MAX_AGE_DAYS:-3}"
DUP_LINE_THRESHOLD="${SELFDEV_SURVEY_DUP_THRESHOLD:-15}"

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
# Draft-PR awareness: distinct from classify_prs (which fires on any "gh pr
# list") -- this asks whether the prompt ever engages with draft state at
# all, the exact word lib/autonomy-merge.sh's own engine never checks for.
classify_draft_aware() { grep -qiE '\bdraft\b' <<<"$1" && echo yes || echo no; }

# Count objects in a `gh ... --json <field>` response, which is ONE LINE of
# JSON regardless of how many records it holds. Pure, offline-testable, and
# extracted for exactly that reason: this was `grep -c '"number"'` until
# 2026-08-10, and `grep -c` counts LINES, not matches. Every account in the
# fleet therefore reported `ISSUES open=1` -- ecosim's real 3, chezz's real
# 11 and gardien's real 7 all rendered as the same digit, and the survey read
# as a fleet with a uniform one-issue backlog. A survey whose headline number
# is a boolean wearing a count's clothes is worse than one that prints
# nothing. Same `grep -o | wc -l` idiom the PR counts below already used
# correctly; no jq dependency added.
json_field_count() { grep -o "\"$2\"" <<<"$1" | wc -l | tr -d ' '; }

# Pure two-blob comparator for the cross-account duplication check: count of
# distinct lines (>=20 chars, to skip trivial/boilerplate matches like blank
# lines or a bare "STANDING RULES.") that appear verbatim in both blobs.
# Order-independent and offline-testable -- no account/host access.
duplicated_line_count() {
  comm -12 \
    <(printf '%s\n' "$1" | awk 'length($0)>=20' | sort -u) \
    <(printf '%s\n' "$2" | awk 'length($0)>=20' | sort -u) \
    | wc -l | tr -d ' '
}

row() { printf '    %-10s claims=%-3s evidence=%-3s  %s\n' "$1" "$2" "$3" "$4"; }

# Populated by survey_account, read by the post-loop cross-account
# duplication check in main(). Not `local` -- survey_account runs in the
# main shell (a `while read <<<`, not a piped subshell), so this global
# assoc array is visible/mutable there.
declare -A PROMPTS

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

  # -- 1b. PULL-BLOCKED: can this account even RECEIVE a global-instruction
  # update? usage-paced-runner.sh's pull-before-dispatch is fail-loud-not-
  # block -- a dirty or diverged scheduler clone means it silently keeps
  # dispatching stale code/confs forever, with only a log line nobody reads.
  local sched_home="$home/Documents/Projects/scheduler"
  if [ ! -d "$sched_home/.git" ]; then
    echo "  PULL-HEALTH  no $sched_home checkout -- this account cannot receive scheduler/conf updates at all"
  else
    local sd_dirty sd_local sd_remote
    sd_dirty="$(sudo -u "$acct" git -C "$sched_home" status --porcelain --untracked-files=no 2>/dev/null)"
    if [ -n "$sd_dirty" ]; then
      echo "  FAIL  PULL-BLOCKED -- $sched_home has uncommitted tracked changes; the next pull-before-dispatch will SKIP, so this account is stuck on stale scheduler code/confs until a human clears it"
      verdict_gaps="$verdict_gaps pull-blocked"
    else
      sd_local="$(sudo -u "$acct" git -C "$sched_home" rev-parse HEAD 2>/dev/null)"
      sd_remote="$(sudo -u "$acct" git -C "$sched_home" ls-remote origin HEAD 2>/dev/null | cut -f1)"
      if [ -n "$sd_remote" ] && [ "$sd_local" != "$sd_remote" ]; then
        if sudo -u "$acct" git -C "$sched_home" merge-base --is-ancestor "$sd_local" "$sd_remote" 2>/dev/null; then
          echo "  PULL-HEALTH  $sched_home is behind origin/main -- fast-forwards automatically next tick, not a failure"
        else
          echo "  FAIL  PULL-BLOCKED -- $sched_home has DIVERGED from origin/main (ff-only will refuse); stuck on stale scheduler code/confs until a human merges"
          verdict_gaps="$verdict_gaps pull-blocked"
        fi
      fi
    fi
  fi

  # -- 2/3. issues and PRs, live from GitHub, as the account's own token
  local issues_n="unknown" prs_ready="unknown" prs_draft="unknown"
  if sudo -u "$acct" gh auth status >/dev/null 2>&1; then
    local issue_json pr_json
    issue_json="$(sudo -u "$acct" gh issue list --repo "$GH_OWNER/$acct" --state open --limit 200 --json number 2>/dev/null)"
    issues_n="$(json_field_count "$issue_json" number)"
    pr_json="$(sudo -u "$acct" gh pr list --repo "$GH_OWNER/$acct" --state open --limit 200 --json number,isDraft 2>/dev/null)"
    prs_ready="$(grep -o '"isDraft":false' <<<"$pr_json" | wc -l | tr -d ' ')"
    prs_draft="$(grep -o '"isDraft":true'  <<<"$pr_json" | wc -l | tr -d ' ')"
  fi
  echo "  ISSUES     open=$issues_n (repo $GH_OWNER/$acct)"
  echo "  PRS        ready=$prs_ready draft=$prs_draft"

  # -- prompt text: prefer the REAL dispatch prompt over the project's own
  # .claude/commands/*.md. For a scheduler-run-based account the command-
  # file copy is frequently an unadapted template nothing actually
  # dispatches -- ecosim.conf's own header says exactly that about its own
  # repo's nightly-batch.md. The prompt that actually reaches `claude -p` is
  # schedule/<acct>.conf's BATCH_PROMPT in that account's OWN scheduler
  # clone, sourced the same way bin/scheduler-run sources it.
  local sched_conf="$sched_home/schedule/$acct.conf"
  if [ -f "$sched_conf" ]; then
    prompt_text="$(sudo -u "$acct" bash -c "BATCH_PROMPT=''; SWEEP_PROMPT=''; source '$sched_conf' 2>/dev/null; printf '%s\n%s' \"\$BATCH_PROMPT\" \"\$SWEEP_PROMPT\"" 2>/dev/null)"
    [ -n "$(tr -d '[:space:]' <<<"$prompt_text")" ] || prompt_text=""
  fi
  local prompt_source="none"
  if [ -n "$prompt_text" ]; then
    prompt_source="$sched_conf"
  else
    local f
    for f in "$repo"/.claude/commands/*.md; do
      [ -f "$f" ] && prompt_text="$prompt_text
$(cat "$f")"
    done
    [ -n "$prompt_text" ] && prompt_source="$repo/.claude/commands/*.md (scheduler conf not found -- may be stale/unadapted, see header)"
  fi
  [ -z "$prompt_text" ] && echo "  PROMPT     none found (checked $sched_conf and $repo/.claude/commands/)"
  [ -n "$prompt_text" ] && echo "  PROMPT     source: $prompt_source"
  PROMPTS["$acct"]="$prompt_text"

  # -- recent evidence: the account's own dispatch log, whichever job dir it
  # lands in. TWO CORRECTIONS, both found 2026-08-10 by checking this
  # script's own reads against the fleet rather than trusting its columns:
  #
  # 1. WRONG DIR, for exactly the accounts that matter. The glob was
  #    `*-nightly-batch/{sweep,run}.log`. The three ARMED accounts dispatch
  #    through `usage-paced-runner.sh`, which writes
  #    `.local/share/scheduler-paced-runner/run.log` -- a name that does not
  #    end in `-nightly-batch` and so was never read. bibliothecaire, which
  #    had run that very morning, reported "no log found" and therefore
  #    `issues claims=yes evidence=no <- claims it, no recent evidence`: a
  #    GAP manufactured by the instrument. Match ANY job dir; the job's name
  #    is the scheduler's to choose and this script does not get to assume it.
  #
  # 2. NO RECENCY WINDOW. chezz, crt and baudin were paused on 2026-08-06
  #    (hf7y/scheduler@9006134) and their last log is from that day, so four
  #    days later they still read `evidence=yes` off work that has not
  #    happened since. That is the inverse of the caveat this script already
  #    prints: a quiet night can look like a blind spot, and a STOPPED
  #    account looks exactly like a working one. Evidence older than the
  #    window is reported and then NOT counted -- an account that stopped
  #    should read as stopped.
  local newest_log_age="" f_age
  for f in "$home"/.local/share/*/sweep.log "$home"/.local/share/*/run.log "$home"/reports/*/LATEST.md; do
    [ -f "$f" ] || continue
    f_age=$(( ( $(date +%s) - $(stat -c %Y "$f" 2>/dev/null || echo 0) ) / 86400 ))
    if [ "$f_age" -gt "$LOG_MAX_AGE_DAYS" ]; then
      echo "  LOG        STALE ${f_age}d: ${f#$home/} -- not counted as evidence (window ${LOG_MAX_AGE_DAYS}d)"
      continue
    fi
    if [ -z "$newest_log_age" ] || [ "$f_age" -lt "$newest_log_age" ]; then newest_log_age="$f_age"; fi
    log_text="$log_text
$(tail -n "$LOG_TAIL" "$f")"
  done
  if [ -z "$log_text" ]; then
    echo "  LOG        no dispatch log under $home newer than ${LOG_MAX_AGE_DAYS}d -- every evidence=no below is ABSENCE OF A LOG, not absence of the behavior"
  else
    echo "  LOG        newest ${newest_log_age}d old"
  fi

  local dim claims evidence
  for dim in reconcile issues prs works; do
    claims="$(classify_"$dim" "$prompt_text")"
    evidence="$(classify_"$dim" "$log_text")"
    row "$dim" "$claims" "$evidence" "$( [ "$claims" = yes ] && [ "$evidence" = no ] && echo '<- claims it, no recent evidence' )"
    [ "$claims" = yes ] && [ "$evidence" = no ] && verdict_gaps="$verdict_gaps $dim"
  done

  # -- draft-PR-blind: real draft PRs exist, but the prompt never engages
  # with "draft" at all -- distinct from (and can be true even when) the
  # prs claim above is yes, since "gh pr list" alone never distinguishes
  # draft from ready, same blind spot as lib/autonomy-merge.sh's engine.
  if [ "$prs_draft" != "unknown" ] && [ "$prs_draft" -gt 0 ] 2>/dev/null; then
    if [ "$(classify_draft_aware "$prompt_text")" = no ]; then
      echo "  FAIL  DRAFT-PR-BLIND -- $prs_draft draft PR(s) open on $GH_OWNER/$acct but the dispatch prompt never mentions \"draft\": no instruction to check, review, or promote them"
      verdict_gaps="$verdict_gaps draft-prs"
    fi
  fi

  # -- stale prompt refs: a hardcoded "Start with #N" that GitHub already
  # shows CLOSED is dead prose the conf was never revisited to remove.
  local nums n state stale=()
  nums="$(grep -oE '#[0-9]+' <<<"$prompt_text" | tr -d '#' | sort -u)"
  if [ -n "$nums" ] && sudo -u "$acct" gh auth status >/dev/null 2>&1; then
    for n in $nums; do
      state="$(sudo -u "$acct" gh issue view "$n" --repo "$GH_OWNER/$acct" --json state --jq .state 2>/dev/null)"
      [ "$state" = "CLOSED" ] && stale+=("#$n")
    done
  fi
  if [ "${#stale[@]}" -gt 0 ]; then
    echo "  FAIL  STALE PROMPT REFS -- prompt names ${stale[*]} but GitHub already shows them CLOSED: a hardcoded issue pointer, no dynamic regeneration keeps it current"
    verdict_gaps="$verdict_gaps stale-refs"
  fi

  if [ -n "$verdict_gaps" ]; then
    echo "  VERDICT    GAP --$verdict_gaps (signal, not proof -- a quiet night looks identical to a blind spot)"
    FOUND=$((FOUND + 1))
  else
    echo "  VERDICT    no gap seen this pass"
  fi
}

# Fleet-wide, not per-account: a single account's own claims/evidence read
# can never see this, since duplicated prose lives ACROSS accounts by
# definition. Same failure mode as hf7y/scheduler@9cfd130 (three confs,
# one hand-typed "STANDING RULES" block, byte-identical, no shared source).
check_cross_account_duplication() {
  echo
  echo "== cross-account: duplicated prose (threshold: $DUP_LINE_THRESHOLD+ shared lines, >=20 chars each) =="
  local accts=("${!PROMPTS[@]}")
  local i j a b shared found=0
  for ((i = 0; i < ${#accts[@]}; i++)); do
    for ((j = i + 1; j < ${#accts[@]}; j++)); do
      a="${accts[i]}"; b="${accts[j]}"
      [ -n "${PROMPTS[$a]}" ] && [ -n "${PROMPTS[$b]}" ] || continue
      shared="$(duplicated_line_count "${PROMPTS[$a]}" "${PROMPTS[$b]}")"
      if [ "$shared" -ge "$DUP_LINE_THRESHOLD" ]; then
        echo "  FAIL  $a and $b share $shared near-identical prompt line(s) -- duplicated prose, not a shared source: an edit to one silently stops applying to the other"
        found=1
        FOUND=$((FOUND + 1))
      fi
    done
  done
  [ "$found" -eq 0 ] && echo "  ok    no cross-account prompt duplication at or above threshold"
}

# Findings this run. The exit code tracks it -- see the GUARD: no note at the
# top for why this is not a gate and why it reports honestly anyway. A script
# that prints FAIL and exits 0 is BUILD-DISCIPLINE.md's archetype defect
# (silence-audit printing 74 FLAGs and exiting 0), and "it is only a survey"
# is not a reason to reproduce it.
FOUND=0

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

  check_cross_account_duplication

  echo
  if [ "$FOUND" -gt 0 ]; then
    echo "selfdev-agent-survey: $FOUND finding(s) -- exit 1"
    return 1
  fi
  echo "selfdev-agent-survey: no findings this pass -- exit 0"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then main; fi
