#!/usr/bin/env bash
# estate-set.sh -- the estate's own names, one home (hf7y/realisateur#673, #672).
GH_ESTATE_OWNER="${GH_ESTATE_OWNER:-hf7y}"
GH_ESTATE_SITE="${GH_ESTATE_SITE:-hf7y.com}"
GH_ESTATE_SITE_REPO="${GH_ESTATE_SITE_REPO:-hf7y.github.io}"
# WHERE THE ARMING AUTHORITY ANSWERS (hf7y/scheduler#429). 100.107.253.56 is
# dexter's tailnet address AND monkey's own eth0 -- one WSL2 namespace, so one
# default reaches mandark and monkey both (measured 2026-09-01).
GH_ESTATE_ROSTER_URL="${GH_ESTATE_ROSTER_URL:-http://100.107.253.56:8646}"
