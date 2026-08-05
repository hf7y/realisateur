#!/usr/bin/env bash
# wtul's Tier 2 (batch) wrapper on the shared engine at
# ~/Documents/Project Archive/scheduler/lib/sweep-loop-common.sh.
#
# No Tier 1 bug-sweep for this project (see PROJECT_KEY note below) and
# no live web tracker (INTAKE.md) - wtul is a personal CLI/hardware tool,
# not a web app with end users filing bugs, so there's nothing for a
# fast daytime sweep to read. This is the only wtul job on the shared
# registry, so the PROJECT_KEY mutex is mostly future-proofing in case a
# Tier 1 sweep ever gets added later.
#
# Cadence is twice a week (Wed + Sat early AM), not nightly - the show
# this project supports is weekly, so there's no value in a faster
# cycle. Real cron expression lives in ../schedule/wtul.conf, not here.
#
# NOT installed to crontab yet - that's bin/sync-crontab.sh --apply,
# a deliberate explicit step done separately.

JOB_NAME="wtul-batch"
PROJECT_KEY="wtul"
TIER="batch"
REPO_URL="git@github-wtul-deploy:hf7y/wtul.git"
REPO_SUBDIR="."
EXPIRY_DAYS=14   # extra margin over the engine's default 7 - not needed
                 # at twice-a-week, kept anyway as headroom
MAX_TURNS=200

PROMPT="/wtul-batch

This is a fully unattended run with no human review step. Read
.scheduler/FOCUS.md FIRST - that file is this project's backlog
(ROADMAP.md is a retired stub that only points back at it, and there is
no separate web tracker for this project). Re-read
.claude/commands/wtul-batch.md's own hardware-constraint section before
touching anything that talks to a real optical drive - this machine may
not have one attached, and there is no physical disc to insert during
an unattended run.

Write your report to ~/reports/wtul/\$(date +%Y-%m-%d).md and update
~/reports/wtul/LATEST.md to match it, so it is a 30-second read the next
time this machine boots up, covering: what shipped, what's still pending
hands-on hardware verification, what was deliberately deferred and why,
and any open questions that need a human decision. Confirm everything is
committed and pushed to origin/main before finishing - a run that isn't
saved anywhere didn't happen."

source "/home/zach/Documents/Projects/scheduler/lib/sweep-loop-common.sh"
