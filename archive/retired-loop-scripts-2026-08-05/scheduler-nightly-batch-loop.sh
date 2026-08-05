#!/usr/bin/env bash
# The scheduler's OWN Tier 2 nightly job -- the scheduler eating its own
# dogfood, working the backlog in .claude/scheduler/FOCUS.md (TODO.md was
# retired 2026-07-18; FOCUS.md is now both scope and backlog).
#
# UNLIKE every other job, this one does NOT source lib/sweep-loop-common.sh.
# That engine is built around a disposable REMOTE clone (clone / reset
# --hard / fetch / push); the scheduler repo is LOCAL-ONLY with no remote,
# and is itself the meta-tool that controls every other job's cron. So this
# wrapper is bespoke and deliberately conservative:
#
#   * Works in a throwaway `git worktree` on a fresh branch nightly/<date>,
#     NOT the live working copy. The live tree stays on main, untouched, so
#     nothing done here at 3am can change the engine or crontab the other
#     jobs rely on until a human merges.
#   * REVIEW GATE, not auto-apply: the night's work lands as commits on
#     nightly/<date> for you to inspect (git log main..nightly/<date>) and
#     merge in the morning. Nothing is pushed, merged, or activated
#     automatically.
#   * Backstop: snapshots the live crontab before/after and shouts
#     (notify-send -u critical) if the run somehow modified it. The command
#     file forbids touching anything outside the worktree; this proves it.
#
# To switch to auto-apply later, that's a deliberate change at the MERGE
# GATE block below -- not the default for the thing that can break every
# other job.

set -uo pipefail

JOB_NAME="scheduler-nightly-batch"
SCHED_REPO="/home/zach/Documents/Projects/scheduler"
STATE_DIR="$HOME/.local/share/$JOB_NAME"
LOG="$STATE_DIR/run.log"
LOCK="$STATE_DIR/run.lock"
WORKTREE="$STATE_DIR/worktree"
BRANCH="nightly/$(date +%F)"
MAX_TURNS="${MAX_TURNS:-60}"
ALLOWED_TOOLS="Bash,Read,Write,Edit,Glob,Grep"
NODE_BIN_DIR="${NODE_BIN_DIR:-/home/zach/.nvm/versions/node/v25.2.1/bin}"
REPORTS_DIR="$HOME/reports/scheduler"

export PATH="$NODE_BIN_DIR:$PATH"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"

mkdir -p "$STATE_DIR" "$REPORTS_DIR"

exec 200>"$LOCK"
if ! flock -n 200; then
  echo "$(date -Is) already running, skipping" >> "$LOG"
  exit 0
fi

[ -f "$LOG" ] && { tail -n 4000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"; }

PROMPT="/nightly-batch

This is the scheduler improving ITSELF, fully unattended, behind a HUMAN REVIEW GATE: everything you do lands as commits on branch $BRANCH for a person to review and merge in the morning. Nothing you do tonight goes live automatically.

Read .claude/scheduler/FOCUS.md FIRST -- it is this project's scope AND backlog (there is no TODO.md anymore). Pick the highest-value, LOWEST-RISK improvement(s) you can fully finish AND verify tonight. This repository is the meta-tool that controls every other project's cron jobs, so correctness matters more than volume: one well-tested change beats three risky ones.

HARD RULES (this is infrastructure, not an app):
  * Make changes ONLY as commits in THIS working directory ($WORKTREE) on branch $BRANCH. Touch nothing outside it.
  * NEVER run 'crontab', and NEVER run bin/sync-crontab.sh with --apply. Previewing (no --apply) to validate a schedule change is fine and encouraged.
  * NEVER edit the installed wrapper scripts under ~/.local/bin, or any file outside this repo.
  * Prefer changes verifiable here and now (shellcheck, a dry-run, simulating cron's env with 'env -u SSH_AUTH_SOCK') over changes whose only test is 'wait for tonight'. If a change can't be safely verified without going live, write it up as a proposal in the report instead of committing it.
  * On a real judgment call or anything needing the user's blessing, append it to .claude/scheduler/QUESTIONS.md and describe it in the report rather than deciding unilaterally.

Commit each finished change with a clear message. Then write your report to $REPORTS_DIR/\$(date +%Y-%m-%d).md and update $REPORTS_DIR/LATEST.md to match, covering: what you changed and why, how you verified it, what you deliberately deferred (and why), and any open questions. A change that isn't committed on $BRANCH didn't happen."

# Pick up any %%TAG inline comments left in the previous report (see
# docs/feedback-tags.md) and put them first in tonight's prompt.
FEEDBACK_FILE="$REPORTS_DIR/LATEST.md"
if [ -f "$FEEDBACK_FILE" ]; then
  FEEDBACK_BLOCK="$("$SCHED_REPO/bin/collect-feedback.sh" "$FEEDBACK_FILE" 2>/dev/null || true)"
  if [ -n "$FEEDBACK_BLOCK" ]; then
    echo "found inline feedback tags in $FEEDBACK_FILE -- prepending to prompt"
    PROMPT="Human feedback on the previous report, left inline in $FEEDBACK_FILE -- act on this FIRST, before anything else:

$FEEDBACK_BLOCK

---

$PROMPT"
  fi
fi

# Same idea, but for the cross-project BLOCKERS.md ("## scheduler" section
# only), consumed on collection since that file is hand-maintained and
# persistent (see lib/sweep-loop-common.sh's identical logic for every
# other project).
BLOCKERS_FILE="$SCHED_REPO/BLOCKERS.md"
if [ -f "$BLOCKERS_FILE" ]; then
  BLOCKERS_BLOCK="$("$SCHED_REPO/bin/collect-feedback.sh" "$BLOCKERS_FILE" --section "scheduler" --consume 2>/dev/null || true)"
  if [ -n "$BLOCKERS_BLOCK" ]; then
    echo "found inline feedback tags in $BLOCKERS_FILE under ## scheduler -- prepending to prompt"
    PROMPT="Human feedback left inline in $BLOCKERS_FILE (cross-project blockers file) -- act on this FIRST, before anything else:

$BLOCKERS_BLOCK

---

$PROMPT"
  fi
fi

{
  echo "=== $(date -Is) scheduler-nightly-batch start ==="
  CRON_BEFORE="$(crontab -l 2>/dev/null | md5sum)"

  cd "$SCHED_REPO" || { echo "cannot cd $SCHED_REPO"; exit 1; }

  # Fresh worktree + branch for tonight; clean up any leftover from a rerun.
  git worktree remove --force "$WORKTREE" 2>/dev/null || true
  git branch -D "$BRANCH" 2>/dev/null || true
  git worktree prune
  if ! git worktree add -b "$BRANCH" "$WORKTREE" main; then
    echo "FAILED to create worktree"
    notify-send -u critical "$JOB_NAME" "worktree add failed -- see $LOG"
    exit 1
  fi

  cd "$WORKTREE" || exit 1
  BEFORE_SHA=$(git rev-parse HEAD)
  echo "worktree $WORKTREE on $BRANCH at $BEFORE_SHA"

  if [ "${SCHED_DRYRUN:-0}" = "1" ]; then
    echo "DRYRUN: skipping claude invocation"
    STATUS="dryrun"
  elif claude -p "$PROMPT" --allowedTools "$ALLOWED_TOOLS" --max-turns "$MAX_TURNS"; then
    STATUS="done"
  else
    STATUS="FAILED"
  fi

  AFTER_SHA=$(git rev-parse HEAD)
  if [ "$AFTER_SHA" = "$BEFORE_SHA" ]; then
    echo "no commits this run"
  else
    echo "commits on $BRANCH awaiting review:"
    git log --oneline "main..$BRANCH"
  fi

  # ---- MERGE GATE ---------------------------------------------------------
  # Default: leave the branch for human review (detach worktree, KEEP branch).
  # To auto-apply instead, replace this block with a fast-forward/merge of
  # $BRANCH into main -- deliberately NOT the default for the meta-tool.
  cd "$SCHED_REPO"
  git worktree remove --force "$WORKTREE" 2>/dev/null || true
  # -------------------------------------------------------------------------

  CRON_AFTER="$(crontab -l 2>/dev/null | md5sum)"
  if [ "$CRON_BEFORE" != "$CRON_AFTER" ]; then
    echo "WARNING: live crontab CHANGED during this run -- investigate"
    notify-send -u critical "$JOB_NAME" "live crontab modified during a self-run -- investigate $LOG"
  fi

  echo "=== $STATUS $(date -Is) ==="
  [ "$STATUS" = "FAILED" ] && notify-send -u critical "$JOB_NAME FAILED" "see $LOG"
  [ "$AFTER_SHA" != "$BEFORE_SHA" ] && notify-send "$JOB_NAME" "New commits on $BRANCH awaiting your review/merge."
  [ "$STATUS" = "FAILED" ] && exit 1
  exit 0
} >> "$LOG" 2>&1