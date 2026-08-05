#!/usr/bin/env bash
# Thin wrapper so schedule/_paced.conf can name a single space-free path --
# usage-paced-runner.sh word-splits its command field, and the scheduler
# repo itself lives under a path with a space ("Project Archive"). Just
# execs the generic entrypoint; all real config is in
# schedule/ecosim.conf.
exec "/home/zach/Documents/Projects/scheduler/bin/scheduler-run" ecosim batch
