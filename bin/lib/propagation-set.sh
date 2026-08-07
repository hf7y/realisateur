#!/usr/bin/env bash
# propagation-set.sh -- THE DEV/PROD CONTRACT, in one place.
#
# ============================================================================
# THE DECISION (2026-08-07, Zach-directed)
# ============================================================================
#
# The question: do the self-dev accounts pull fresh clones of realisateur --
# making `main` the deploy ref for live agents -- or does everything they use
# reach them through the nightly verb build?
#
# ANSWER: the build. `main` IS NOT A DEPLOY REF, and the reason is not agent
# safety.
#
# Zach's framing, which corrected a draft of this file that had settled for a
# clone-with-a-clock: interactive development here produces a CONSUMABLE that
# agents pick up "in a controlled, stable way, and then build on." That is a
# dev/prod split with a release channel between them.
#
# The prize is what it buys the DEV side. If four live accounts pull `main` on
# a tick, every commit is a deployment, and `main` must then turn conservative
# to protect them -- reviews get heavier, risky refactors get deferred, and the
# repo whose entire value is fast iteration starts behaving like a production
# branch. Separating them is what lets `main` STAY FAST. Agent stability is the
# second-order benefit, not the argument.
#
# The counter-argument, weighed and rejected: `main` was already the de facto
# deploy ref, because `install-shims.sh` writes ~/.local/bin shims that `exec`
# a path inside the realisateur clone. Ten ecosystem commands resolve that way
# on every self-dev account today. The tempting move is to bless that and give
# it a clock. That is backwards -- it would make the leak permanent and make
# `main` conservative forever. The leak is named below as debt with a bound on
# it, and the bound is enforced by bin/tests/propagation.test.sh.
#
# ============================================================================
# WHAT WAS MEASURED, 2026-08-07, BEFORE ANY OF THIS
# ============================================================================
#
#   channel                       cadence            state
#   ----------------------------  -----------------  -----------------------
#   scheduler clone of main       every runner tick  CURRENT, all 3 armed
#   realisateur clone of main     NONE               15 commits behind, x4
#   installe bashified worktree   NONE               senechal 2dcf238 vs
#                                                    origin a1c8629, stale
#   hf7y/verbs nightly build      04:07Z nightly     CUT DAILY SINCE 08-05,
#                                                    INSTALLED ON ZERO HOSTS
#
# The one channel with a clock was current. Every channel without one had
# rotted. And the release channel -- the correct one, already built, already
# nightly, already refusing BLIND and shrinking builds -- had no consumer at
# all. `~/.local/share/verb-builds/` did not exist on any of the ten accounts.
#
#       >>> A CHANNEL WITH NO CLOCK IS NOT A CHANNEL. <<<
#
# It is a hope, and a hope that exits 0 is this estate's signature failure.
#
# ============================================================================
# PULL, NOT PUSH
# ============================================================================
#
# The clock lives on the CONSUMER, in the account's own crontab, running as
# the account. Not on a hands account reaching in over ssh + sudo.
#
# Push needs a human holding the right credential, does not scale past four
# accounts, and leaves no trace on the consumer side -- so the account cannot
# answer "what version am I on and when did I last check" without someone
# else's shell history. Pull lets the account VERIFY BEFORE ADOPTING (which is
# the property that makes an atomic switch possible at all) and leaves the
# record where the consumer is. Measured cost of push, same day: getting one
# key into `ecosim` needed a hand `scp` and the permission layer blocked it
# first.
#
# `bin/tests/propagation.test.sh` asserts this mechanically -- the tick must
# contain no `sudo -u` and no `ssh` on its apply path. A doctrine that is only
# written down is a doctrine that gets edged back the first time push is more
# convenient.
#
# ============================================================================
# BOOTSTRAP AND PAYLOAD
# ============================================================================
#
# A build cannot deliver its own installer, so something must exist on the
# account first. The industrial shape (gradlew, rustup) is a SMALL,
# NEAR-IMMUTABLE bootstrap checked into the consumer whose only job is to
# find, verify and install a versioned payload.
#
# Copying the whole toolset into N accounts would just relocate the rot. The
# bootstrap is therefore bounded and asserted to stay bounded: it changes
# rarely, so its own staleness does not matter, which is the only reason a
# copy is acceptable at all. Everything else is payload and arrives versioned.
#
# It is installed ONCE per account by `setup-selfdev-project.sh`, which
# already runs exactly once per account and is already the place per-account
# credentials and clones are established.
#
# ============================================================================
# THE DECIDER -- one question, asked once, no per-file adjudication
# ============================================================================
#
#   Would this script still be needed on a host that has NO PAYLOAD INSTALLED?
#
#   YES -> BOOTSTRAP. It finds, verifies, installs or repairs the payload, or
#          it is the clock that does so. Bounded set; growth is a review event.
#   NO  -> PAYLOAD. It is tooling an agent uses once the surface exists, so it
#          travels as a verb in a dated, named, atomically-switched build.
#   Never leaves this repo -> LOCAL. Linters CI gates, and operator scripts a
#          human runs from a hands account against the live estate.
#
# A rule that needs a human to adjudicate per file is not a rule, so the
# answer is written ONCE, here. propagation.test.sh fails CI if any bin/*.sh
# is unclassified, classified twice, or named here but deleted. A new script
# cannot be merged with no propagation path -- which is exactly the state
# bin/selfdev-gh-app.sh was written into on 2026-08-06, for accounts that had
# no way to receive it, with nothing anywhere noticing.

# --- the release channel ----------------------------------------------------
# One repo, one credential, one clone. VERB-DISTRIBUTION.md 5: this is what
# retires the per-repo deploy-key sprawl (four hand-made keys per account,
# "we can't do this for every install").
PROP_RELEASE_REPO="hf7y/verbs"
PROP_RELEASE_REMOTE="https://github.com/hf7y/verbs.git"

# A VERSION is a build id -- a UTC timestamp, so lexical sort is chronological
# and two builds in one day cannot collide. An account's pin is the target of
# ~/.local/share/verb-builds/current. "I am on 2026-08-06T043915Z and
# 2026-08-07T040739Z exists" is a one-line comparison; "I am on 60ef8c6" is
# archaeology.
PROP_PIN_PATH=".local/share/verb-builds/current"

# ============================================================================
# STAMPING: WHICH BUILD PRODUCED THIS ARTIFACT
# ============================================================================
#
# Zach, 2026-08-07: every artifact an agent produces should record which verb
# build produced it. The value already exists -- it is the pin above. What was
# missing is that nothing records it AT THE MOMENT WORK IS CREATED, so
# "what was ecosim running when it did that?" is unanswerable afterwards,
# which is the entire point of asking.
#
# ONE READER, HERE. Every stamper calls prop_build_trailer(); none of them
# reads the pin path themselves. Two readers of one fact is the shape
# MONKEY.md 10 found five times in a day.
#
# THREE STATES, NEVER TWO. The distinction the mechanism lives or dies on:
#
#   Verb-Build: 2026-08-07T040739Z   stamped, and the build is known
#   Verb-Build: unknown              stamped, and the producer honestly did
#                                    not know -- no build is adopted on this
#                                    host, or the pin is unreadable
#   (no trailer at all)              UNSTAMPED: produced by something that
#                                    predates or bypasses the mechanism
#
# An unstamped artifact must remain distinguishable from one stamped
# "unknown", because they mean opposite things about the mechanism: the
# second proves the stamper ran and told the truth; the first proves nothing
# ran. Guessing a plausible build id -- "the latest one", "the one in the
# manifest" -- would destroy exactly that distinction, so it is never done.
#
# WHY A GIT TRAILER. It survives the artifact being read later out of
# context, which is the requirement: the commit carries it forever, it
# travels with a clone, a cherry-pick and a patch, `git log
# --format='%(trailers:key=Verb-Build)'` reads it in bulk, and no human
# maintains it. A line in a report file satisfies none of those.

# prop_current_pin -- the adopted build id, or nothing. Never a guess.
prop_current_pin() {
  local p="${VERB_BUILD_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/verb-builds}/current"
  local t; t="$(readlink "$p" 2>/dev/null)" || return 1
  [ -n "$t" ] || return 1
  basename "$t"
}

# prop_build_trailer -- the trailer line, always emitted, honest when unknown.
prop_build_trailer() {
  local pin; pin="$(prop_current_pin 2>/dev/null)"
  printf 'Verb-Build: %s\n' "${pin:-unknown}"
}

# --- BOOTSTRAP: small, near-immutable, installed once per account -----------
# Every entry here is a file a consumer must hold BEFORE any payload can
# arrive. Adding one is a review event, not a convenience -- see the bound
# asserted in propagation.test.sh.
# release-ledger.sh is bootstrap because the CONSUMER runs it: it is how an
# account tells "no new build because nothing changed" from "no new build
# because main is broken", and that question has to be answerable on a host
# that has no payload installed at all.
PROP_BOOTSTRAP_SCRIPTS="
install-verb-build.sh
selfdev-release-tick.sh
release-ledger.sh
"

# Files the bootstrap scripts need alongside them. Named explicitly because
# `setup-selfdev-project.sh` stages by copy into a 0700 home and a missed
# dependency there presents as "Permission denied", not "file not found" --
# the trap MONKEY.md 8.3 records from account #4.
PROP_BOOTSTRAP_SUPPORT="
lib/cli-guard.sh
lib/propagation-set.sh
"

# --- PROVISIONING: root-side, runs from a hands account, never on the -------
# --- consumer's clock. Not bootstrap: these stand an account UP, once.
PROP_PROVISION_SCRIPTS="
land-selfdev.sh
provision-selfdev-user.sh
setup-selfdev-project.sh
wire-selfdev-git.sh
install-shims.sh
install-verbs.sh
relink-verbs-to-build.sh
pivot.sh
session-marker.sh
"

# --- PAYLOAD: reaches user paths as a verb, inside a dated build ------------
PROP_PAYLOAD_SCRIPTS="
check-project-busy.sh
closeout-lint.sh
focus-commit.sh
hygiene-lint.sh
notify-senechal.sh
precipitation-scan.sh
silence-audit.sh
"

# --- THE LEAK, with a bound on it -------------------------------------------
# PAYLOAD-class scripts that are NOT yet declared on any bashified branch.
# realisateur's bashified branch declares THREE verbs (arpente, epluche,
# juge); the seven below reach accounts as clone-backed shims instead, which is
# `main` acting as a deploy ref through the back door.
#
# This list may SHRINK and must never GROW. propagation.test.sh enforces that
# against PROP_LEAK_BOUND. Empty it by adding bin/<n> + man/<n>.1 to
# realisateur's bashified branch -- never by reclassifying a row as bootstrap.
PROP_PAYLOAD_PENDING="$PROP_PAYLOAD_SCRIPTS"
PROP_LEAK_BOUND=7

# --- LOCAL: never leaves this repo ------------------------------------------
# release-gate.sh and publish-release-verdict.sh are LOCAL because they run in
# the release pipeline (GitHub Actions checks realisateur out to get them), not
# on a consumer. An account never gates or publishes; it only reads the result.
PROP_LOCAL_SCRIPTS="
cut-verb-build.sh
deploy-drift.sh
release-gate.sh
publish-release-verdict.sh
ecosim-sensor-tick.sh
floor-check.sh
hardcoded-home-lint.sh
make-bootstrap-branch.sh
markdown-cost.sh
reach-lint.sh
restamp-discipline.sh
stamp-agent.sh
thermostat-wiring.sh
"

# prop_channel <script-basename> -- prints bootstrap|provision|payload|local,
# or nothing (rc 1) when the script is unclassified. Callers MUST treat rc 1
# as a finding: an unclassified script has no propagation path at all.
prop_channel() {
  local n="$1" s
  for s in $PROP_BOOTSTRAP_SCRIPTS; do [ "$s" = "$n" ] && { echo bootstrap; return 0; }; done
  for s in $PROP_PROVISION_SCRIPTS; do [ "$s" = "$n" ] && { echo provision; return 0; }; done
  for s in $PROP_PAYLOAD_SCRIPTS;   do [ "$s" = "$n" ] && { echo payload;   return 0; }; done
  for s in $PROP_LOCAL_SCRIPTS;     do [ "$s" = "$n" ] && { echo local;     return 0; }; done
  return 1
}
