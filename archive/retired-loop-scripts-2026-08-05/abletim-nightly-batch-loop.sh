#!/usr/bin/env bash
# Thin wrapper so schedule/_paced.conf can name a single space-free path --
# usage-paced-runner.sh word-splits its command field, and the scheduler
# repo itself lives under a path with a space ("Project Archive").
#
# NOTE: abletim is DEXTER-PINNED (see schedule/abletim.conf and
# _paced.conf's parked abletim line) -- this wrapper exists for line-format
# uniformity and should never be dispatched on mandark. Its REPO_URL
# (ssh://mandark-lan/...) only resolves from dexter.
exec "/home/zach/Documents/Projects/scheduler/bin/scheduler-run" abletim batch
