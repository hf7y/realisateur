#!/usr/bin/env bash
# Migrated onto the shared engine -- see
# "/home/zach/Documents/Projects/scheduler/lib/sweep-loop-common.sh"
# for the actual lock/expiry/heartbeat/clone/invoke/registry logic.
# Everything below is project-specific config.

JOB_NAME="vkv-inventory-bug-sweep"
PROJECT_KEY="vkv-inventory"  # SAME key as vkv-inventory-nightly-batch-loop.sh --
                              # that's what lets them detect and skip around each other.
TIER="bug-sweep"
REPO_URL="git@github-vkv-deploy:media-arts-collective/inventory-app.git"
REPO_SUBDIR="."
MAX_TURNS=40

PROMPT="/bug-sweep

This is a fully unattended run with no human review step. Once you've
committed your fixes and pushed to origin/main, deploy them per
DEV_DEPLOYMENT_ID at the top of .claude/commands/bug-sweep.md (this repo
is itself a fork, not the real production app -- that ID is confirmed
fine to deploy to directly, not something to avoid). Never resolve or
reclassify a report you are not confident about; leave it open with a
note instead, per the command file's own guidance."

source "/home/zach/Documents/Projects/scheduler/lib/sweep-loop-common.sh"
