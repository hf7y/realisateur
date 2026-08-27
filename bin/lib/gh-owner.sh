#!/usr/bin/env bash
# gh-owner.sh -- THE ONE HOME of "which GitHub account owns this estate".
#
# WHY THIS EXISTS (2026-08-27, hf7y/realisateur#673). The literal `hf7y` was a
# fallback default in SIXTEEN places under NINE different variable names --
# DEFERE_OWNER, VERB_BUILD_OWNER, SELFDEV_GH_OWNER, DECISION_ROT_OWNER,
# CRED_GH_OWNER, ROSTER_OWNER, ANSWERED_OWNER, PUBLISH_REPO,
# ARMING_ROSTER_REPO. Setting one of them moved five call sites and left
# eleven pointing at the old account.
#
# THAT FAILS SILENTLY, WHICH IS THE POINT. GitHub redirects a transferred repo
# indefinitely, so the eleven stragglers would keep WORKING against the old
# owner -- an estate split across two accounts with every command exiting 0 and
# nothing to see. A break would have been kinder.
#
# NOT A REFUSAL. An earlier draft of #673 proposed refusing when the owner is
# unset. That is wrong here: /etc/selfdev/gh-app.conf does not exist on mandark,
# and the default is the live value there. The defect was never that a default
# exists -- it is that the default was written in sixteen places. One place with
# a default is correct; sixteen places with the same default is the bug.
#
# TO MOVE THE ESTATE TO A NEW OWNER: change the line below, and set
# SELFDEV_GH_OWNER in /etc/selfdev/gh-app.conf on each host. Nothing else.
# bin/tests/gh-owner.test.sh fails if a new `hf7y` literal appears in bin/.
#
# A DECIDER IS NOT AN OWNER. bin/defere.sh's DEFERE_DECIDER is the @handle
# written on line 1 of an issue body. It is deliberately NOT resolved from here:
# an organization cannot be a decider, and folding the two would silently
# address every deferred decision to a company.

# NO RE-SOURCE SENTINEL. The assignment below is already idempotent, and a
# sentinel is a name a caller can collide with: bin/stamp-verb-build.sh held
# its own $GH_OWNER_LIB path variable, which made sourcing this file return
# early and left GH_ESTATE_OWNER unbound under `set -u`.
GH_ESTATE_OWNER="${GH_ESTATE_OWNER:-hf7y}"
