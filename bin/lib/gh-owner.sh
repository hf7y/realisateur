#!/usr/bin/env bash
# gh-owner.sh -- THE ONE HOME of "which GitHub account owns this estate".
#
# `hf7y` was a fallback in 18 places under 10 names (#673). Setting one moved
# five call sites; the rest kept resolving to the old account -- and GitHub
# redirects a transferred repo forever, so they would keep WORKING, exit 0,
# with the estate split across two owners. A break would have been kinder.
#
# NOT a refusal: /etc/selfdev/gh-app.conf does not exist on mandark, where this
# default IS the live value. Eighteen copies of a default was the bug, not the
# default. To move the estate: change the line below, and set SELFDEV_GH_OWNER
# in /etc/selfdev/gh-app.conf per host.
#
# No re-source sentinel -- the assignment is idempotent, and a sentinel is a
# name a caller can collide with (stamp-verb-build.sh held its own $GH_OWNER_LIB
# and made this file return early, leaving the value unbound under `set -u`).
#
# DEFERE_DECIDER is NOT resolved from here: it is an @handle for an issue's
# line 1, and an organization cannot decide anything.

GH_ESTATE_OWNER="${GH_ESTATE_OWNER:-hf7y}"
