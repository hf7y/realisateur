#!/usr/bin/env bash
# estate-set.sh -- the estate's own names, one home (hf7y/realisateur#673, #672).
GH_ESTATE_OWNER="${GH_ESTATE_OWNER:-hf7y}"
GH_ESTATE_SITE="${GH_ESTATE_SITE:-hf7y.com}"
GH_ESTATE_SITE_REPO="${GH_ESTATE_SITE_REPO:-hf7y.github.io}"
# WHERE THE ARMING AUTHORITY ANSWERS (hf7y/scheduler#429). 100.107.253.56 is
# dexter's tailnet address, and every WSL2 distro on dexter shares that
# namespace -- so one default serves the host and its distros alike.
GH_ESTATE_ROSTER_URL="${GH_ESTATE_ROSTER_URL:-http://100.107.253.56:8646}"
