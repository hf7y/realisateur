#!/usr/bin/env bash
# Chezz's Tier 1 (bug sweep) wrapper on the shared engine at
# ~/Documents/Project Archive/scheduler/lib/sweep-loop-common.sh -- this
# used to hand-duplicate that ~70 lines of lock/expiry/heartbeat/clone
# logic itself; the push-verification block below (compare local HEAD to
# the remote's, not just "did HEAD move") was actually invented here
# first and has since been folded into the shared library for every
# project that uses it.

JOB_NAME="chezz-bug-sweep"
PROJECT_KEY="chezz"
TIER="bug-sweep"
REPO_URL="git@github-chezz-deploy:hf7y/chezz.git"
REPO_SUBDIR="."
MAX_TURNS=40

# Cost controls (added 2026-07-18 -- the sweep fires every 15 min but the
# open-bug set changes rarely; on 2026-07-17, 57 of 76 runs found nothing
# new yet each still spun up a full claude invocation).
#
#  * PRECHECK_CMD skips the claude call entirely (zero model cost) unless
#    the set of open bug reports actually changed since the last run --
#    turns ~75 wasted invocations/day into cheap curls. See the script.
#  * MODEL runs the (mechanical) triage/fix on Sonnet instead of the CLI
#    default, cutting the cost of the runs that DO fire. Bump back to a
#    stronger model or unset if fix quality drops.
PRECHECK_CMD="/home/zach/.local/bin/chezz-bug-sweep-precheck.sh"
MODEL="claude-sonnet-5"

PROMPT="/bug-sweep

This is a fully unattended run with no human review step. Once npm run check passes and you have committed your fixes, run git push origin HEAD:main yourself so the fixes go live immediately. Never resolve or reclassify a report you are not confident about, leave it open with a note instead, per the command file's own guidance."

source "/home/zach/Documents/Projects/scheduler/lib/sweep-loop-common.sh"
