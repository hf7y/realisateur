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
# and two builds in one day cannot collide. "I am on 2026-08-06T043915Z and
# 2026-08-07T040739Z exists" is a one-line comparison; "I am on 60ef8c6" is
# archaeology.
#
# WHERE THE PIN LIVES CHANGED ON 2026-08-13, and this file said otherwise for
# long enough to mislead a session. There is now ONE pin per HOST:
#
#   /usr/local/share/verb-builds/current   linked into /usr/local/bin, moved by
#                                          ONE tick in root's crontab
#
# and NO account on monkey holds a private one -- hf7y/realisateur#180, all 13
# retired, measured per account: every host-wide verb resolves from
# /usr/local/bin in a login shell on every one of them.
#
# PROP_PIN_PATH is kept because the LEGACY shape still has to be RECOGNISED --
# --survey grades an account that still holds a private pin, and a host that
# has not migrated is a real state, not a bug. It is no longer the place to
# look first. prop_current_pin() below reads the host-wide root as its
# fallback and is the only function that should resolve either.
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
#
# TWO ROOTS, IN THE ORDER THE ACCOUNT ACTUALLY RESOLVES THEM. The private pin
# first: an account that still has one is running it, because its ~/.local/bin
# shims point into it and shadow the host-wide directory. The HOST-WIDE root
# second, which is where hf7y/realisateur#180 is moving every account.
#
# Without the second, this function went honest-but-useless the moment an
# account retired: probed 2026-08-13, the four accounts retired that morning
# stamped `Verb-Build: unknown` while running a perfectly well-known build out
# of /usr/local/bin. "Unknown" is the right answer to an unreadable pin and the
# wrong answer to a pin that moved -- and the three-state rule above only earns
# its keep while `unknown` stays rare enough to mean something.
prop_current_pin() {
  local p t
  for p in "${VERB_BUILD_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/verb-builds}/current" \
           "${VERB_HOST_BUILD_ROOT:-/usr/local/share/verb-builds}/current"; do
    t="$(readlink "$p" 2>/dev/null)" || continue
    [ -n "$t" ] || continue
    basename "$t"
    return 0
  done
  return 1
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
# selfdev-gh-app.sh SPENDS THE FOURTH AND LAST SLOT under the declared bound
# of 4, so this addition is the "review event" the bound exists to force. The
# argument for it, stated so a reviewer can reject it: the script is the git
# CREDENTIAL HELPER. `--credential` is invoked by git on every fetch and push
# the account makes, so it is not a stand-up-once script (that is its sibling
# selfdev-gh-app-register.sh, filed under PROVISION below). And it answers the
# decider's question the only way a credential helper can -- an account with no
# payload installed cannot authenticate to git, and therefore cannot FETCH a
# payload, so this must be present before anything else can arrive.
#
# THAT LAST STEP WAS PROBED, NOT ASSUMED, because it is the whole argument: if
# the release repo were PUBLIC, an account could fetch the payload with no
# credential at all and this would be payload, not bootstrap.
#   # verified 2026-08-07 23:20Z via `gh repo view hf7y/verbs --json visibility`
#   -> {"isPrivate":true,"visibility":"PRIVATE"}
# and bin/install-verb-build.sh:63 clones it over HTTPS
# (https://github.com/hf7y/verbs.git), which git can only authenticate through
# a credential helper. So the payload is unreachable until this file is already
# on the account. Classifying it PAYLOAD would be circular -- the build
# delivering the credential needed to fetch the build -- and would also push
# PROP_PAYLOAD_PENDING to 11 against a PROP_LEAK_BOUND of 10 that only ever
# goes down.
#
# >>> THAT STAMP WENT FALSE THE SAME NIGHT, AND THE ARGUMENT ABOVE WENT WITH
# >>> IT. `hf7y/verbs` was flipped to PUBLIC at ~23:30Z on 2026-08-07.
#   # verified 2026-08-07 23:52Z via `gh repo view hf7y/verbs --json visibility,isPrivate`
#   -> {"isPrivate":false,"visibility":"PUBLIC"}
#
# The stamp is corrected rather than deleted BECAUSE the reasoning downstream
# of it is now wrong, and a corrected stamp with the old text struck through it
# is the only version of this comment that shows a reader why. The argument for
# selfdev-gh-app.sh occupying the fourth and last bootstrap slot was ITS OWN
# probe: a private release repo makes the credential helper a precondition for
# fetching anything, so it cannot travel as payload. A PUBLIC release repo
# removes that precondition entirely -- `git clone https://github.com/hf7y/verbs.git`
# now needs no credential at all -- so the circularity is gone and with it the
# only thing that made this file bootstrap rather than payload.
#
# THE SLOT IS NOT FREED IN THIS COMMIT, DELIBERATELY. Reclassifying a bootstrap
# entry changes what four live accounts hold before they can fetch anything,
# and that is its own review with its own probe of what is already staged on
# each account. It is reported as a finding, not acted on here. Note before
# anyone acts on it: the helper is still needed to PUSH as the App identity and
# to reach the account's own PRIVATE project repo, so the question is not "is
# it still needed" (it is) but "must it be present BEFORE the first payload
# arrives" (it need no longer be). Those are different questions and only the
# second one decides the slot.
#
# It is also the file propagation.test.sh's own doctrine names as the motivating
# case: written 2026-08-06 for accounts that had no way to receive it. Giving it
# a channel is that finding being closed, not the bound being eroded. The bound
# is now FULL: the next addition must retire one of these four or raise the
# bound deliberately, which is exactly the conversation it was built to force.
PROP_BOOTSTRAP_SCRIPTS="
install-verb-build.sh
selfdev-release-tick.sh
release-ledger.sh
selfdev-gh-app.sh
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
#
# selfdev-gh-app-register.sh is filed here and not LOCAL, which is a close call
# worth naming: LOCAL also admits "operator scripts a human runs from a hands
# account", and this is one. PROVISION wins because it is per-ACCOUNT and
# stands one UP exactly once (two browser clicks per account, MONKEY.md 962) --
# this list's literal definition, and what its neighbours land-selfdev.sh,
# provision-selfdev-user.sh, setup-selfdev-project.sh and wire-selfdev-git.sh
# all do. LOCAL's members are repo-wide CI gates and estate-wide surveys; a
# script whose first argument is an account name does not belong among them.
#
# NOTE FOR ANY FUTURE EDITOR OF THESE LISTS: they are newline-separated strings
# consumed by `for s in $LIST`, NOT shell code. A `#` comment placed INSIDE the
# quotes does not comment anything -- it closes the string and the rest of the
# list executes as commands. That is not hypothetical; it is what the first
# draft of this very comment did, and `bin/tests/propagation.test.sh` caught it
# as 20 lines of "command not found". Comments go ABOVE the assignment.
# selfdev-app-key.sh is PROVISION, not LOCAL and not PAYLOAD, on the same test
# every entry here answers: would a host with NO payload installed still need
# it? Yes -- it is what puts the one GitHub App credential at
# /etc/selfdev/app.pem in the first place, and nothing on a bare host can mint
# a token until it has run. It runs AS ROOT ON THE SELF-DEV HOST (like
# provision-selfdev-user.sh directly above it), not from a hands account over
# ssh (which is what makes selfdev-credentials.sh LOCAL instead), and
# setup-selfdev-project.sh calls it as step 5/6.
PROP_PROVISION_SCRIPTS="
land-selfdev.sh
provision-selfdev-user.sh
install-honey-plugin.sh
setup-selfdev-project.sh
wire-selfdev-git.sh
wire-release-channel.sh
selfdev-gh-app-register.sh
selfdev-app-key.sh
install-shims.sh
install-verbs.sh
pivot.sh
session-marker.sh
stamp-verb-build.sh
"

# --- PAYLOAD: reaches user paths as a verb, inside a dated build ------------
PROP_PAYLOAD_SCRIPTS="
check-project-busy.sh
closeout-lint.sh
focus-commit.sh
retired/hygiene-lint.sh
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
# WHAT THE SHIMS ACTUALLY ARE (Zach, 2026-08-13, correcting a session that had
# read this section as a design): they are an artefact of the OLD scheduler
# workflow, which ran under zach@mandark where one clone served everything.
# They are not relevant to the individual-account model at all. So the exit is
# not "bless the shim and give it a clock" -- it never was -- and it is also
# not "each account keeps a realisateur clone". It is the verb cut, and the
# work is already moving: notify-senechal.sh was converted to a STANDALONE
# wrapper filing GitHub issues with `gh` directly (#197), holding no dependency
# on a senechal checkout, and it ships with the verb cut once the French rename
# lands -- hf7y/realisateur#196, "One door as a French verb: notify-senechal
# and consulte are the same mechanism, written twice".
#
# WHAT IS NOT TRUE, stated because the absence of it read as permission: the
# build ships NONE of these seven today. Probed 2026-08-13 against the live
# manifest -- 33 verbs, 12 projects, not one of the seven among them. So a
# session cannot retire these shims "because the verbs cover them"; on that day
# every account still reached notify-senechal, focus-commit and
# check-project-busy through this leak, and those are mandated front doors in
# CLAUDE.md. Retiring the shim before the verb exists removes the door.
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
#
# deferral-ledger.sh is LOCAL for the same reason as its sibling
# claim-drift.sh: it reads a pull request on this repository from a CI job. An
# account never audits a PR body.
#
# defere.sh IS FILED HERE UNDER PROTEST, and the protest has an issue number
# rather than being left as a sentence: hf7y/realisateur#115. It is a filing
# front door, and the agents that most need it run on the ten uid 3000-3099
# accounts, where LOCAL means it does not exist. It is not PAYLOAD today
# because PROP_PAYLOAD_PENDING == PROP_PAYLOAD_SCRIPTS with PROP_LEAK_BOUND=7,
# so an eighth entry would RAISE the leak bound -- and the correct fix is to
# declare bin/defere + man/defere.1 on the bashified branch and add it to
# PAYLOAD without adding it to PENDING, not to grow the bound. Doing that is
# #115's job. Reclassifying it here without the man page would silently drop
# it from every build (#85).
#
# gh-comment.sh (#238) is LOCAL for the same reason as defere.sh, one step
# short of the protest: nothing checked into this repo calls it yet (no
# script here posts a GitHub comment at all -- that is the gap #238 found),
# so unlike defere.sh it is not YET needed on the ten accounts, only built
# ahead of that need so the stamp is never optional once something does call
# it. Promote it alongside defere.sh if and when it gains a caller other
# accounts need, not before -- the leak bound is the same FULL 7 either way.
#
# decision-rot.sh is LOCAL on floor-check.sh's reasoning, not retire-check.sh's:
# it is an ESTATE-WIDE SURVEY that a human runs from a hands-on session and
# reads. It needs a GitHub credential that can see all eighteen repos' issues,
# which the per-account deploy-key tokens do not have, so shipping it to the
# self-dev accounts would install a command that returns a short, quiet count
# there -- the exact silent-zero its own header spends thirty lines closing.
# It is a plausible VERB by Zach's test ("would another agent or Zach ever call
# one of those?") -- both would -- and it is deliberately not one YET, on
# retire-check.sh's precedent below: a front door is claimed after the tool has
# been used against this estate, not on the day it is written.
#
# retire-check.sh (#166) is LOCAL for the identical reason, same paragraph:
# adding an eighth PAYLOAD row raises the leak bound rather than shrinking it.
# It also is not yet CALLED by anything -- wiring it into cloture.md step 3,
# the command every project's session would actually invoke it from, needs an
# edit to `.claude/commands/*.md`, which this repo's own sensitive-file gate
# refuses in an unattended session (#187, same wall). Until both land --
# PAYLOAD without growing the bound, and the cloture.md wiring -- this stays a
# standalone tool run by path, not a verb.
# publish-monkey-status.sh is LOCAL for publish-release-verdict.sh's reason,
# one paragraph up: it runs where the ssh credential to the self-dev host is,
# and an account never publishes a page about its own fleet.
#
# playbook.sh IS FILED HERE UNDER PROTEST, like defere.sh above, and with the
# same issue-number-not-a-sentence rule: hf7y/realisateur#244. Its `push` half
# is genuinely local -- a human hand, at a keyboard with write access. Its
# `pull` half is the opposite: it is meant to run on every dispatch account,
# first thing, before the queue. LOCAL means it does not exist there. Until it
# is declared as bin/playbook + man/playbook.1 on the bashified branch and
# added to PAYLOAD (without growing PROP_LEAK_BOUND, see #115's shape), the
# accounts read their brief with a two-command `gh` snippet written into
# BATCH_PROMPT instead -- which is retyped logic, which is the defect, which
# is what #244 is for. Do NOT reclassify this row to PAYLOAD without the man
# page: that drops it from every build in silence (#85).
# dexter-liveness.sh and dexter-service-deploy.sh are LOCAL: both need an ssh
# credential to dexter and a working copy of provision/dexter/. An account
# neither probes another host nor deploys to one -- it is the thing deployed.
#
# monkey-vdi-to-internal.sh and monkey-watch.sh are LOCAL for a sharper version
# of the same reason: both must run ON THE VM HOST, because both call
# VBoxManage against the guest. Shipping either to an account would be worse
# than useless -- monkey-watch's whole purpose is to report monkey being down,
# which it can only do from somewhere that is not monkey (hf7y/realisateur#274,
# where the previous publisher could not report an outage because publishing
# required ssh to the thing that was down). A watcher that ships to its subject
# is the failure, not the delivery.
PROP_LOCAL_SCRIPTS="
dexter-liveness.sh
dexter-service-deploy.sh
monkey-vdi-to-internal.sh
monkey-watch.sh
playbook.sh
publish-monkey-status.sh
claim-drift.sh
defere.sh
deferral-ledger.sh
gh-comment.sh
retire-check.sh
decision-rot.sh
cut-verb-build.sh
deploy-drift.sh
release-gate.sh
publish-release-verdict.sh
ecosim-sensor-tick.sh
floor-check.sh
hardcoded-home-lint.sh
make-bootstrap-branch.sh
markdown-cost.sh
ownership-audit.sh
port-markdown-cost.sh
reach-lint.sh
discipline.sh
stamp-agent.sh
suite-docs-lint.sh
thermostat-wiring.sh
path-provenance-audit.sh
selfdev-agent-survey.sh
selfdev-credentials.sh
served-not-cloned.sh
shellcheck-lint.sh
verb-kind-lint.sh
repo-settings-provision.sh
no-worktree-lint.sh
"
# repo-settings-provision.sh is LOCAL for thermostat-wiring.sh's reason, not
# bin/shellcheck-lint.sh's. (The `bin/` is load-bearing: a comment line whose
# FIRST word is `shellcheck` is parsed as a shellcheck directive, and this one
# was -- SC1072/SC1073, a parse error on the whole file, which is why every
# other note in this header spells the path out too.)
# Its subject is the FLEET: it walks scheduler's whole
# schedule/*.conf registry and asks GitHub about every registered repo at
# once. A per-account copy would have each of ten accounts reconfiguring all
# thirteen repositories on its own clock, which is not ten times the value --
# it is ten writers on one setting. It also needs a credential no provisioned
# account holds or should: `gh repo edit` is admin on someone else's repo,
# where the self-dev accounts are deliberately read-only deploy keys.
# bin/no-worktree-lint.sh is LOCAL on shellcheck-lint.sh's exact reasoning, and
# note that scheduler DOES need the same guard and still does not get this file.
# Its allowlist is compiled in and is about realisateur's tree -- one entry, for
# bashify/lib/sync-runtime.sh, which exists in no other repository. Shipping it
# would hand an account a guard excusing a path it does not have, and check B
# would report that entry stale forever. scheduler carries its own copy
# (bin/no-worktree-guard.sh) with its own allowlist, the same PORTED-COPY answer
# hf7y/scheduler#77 gets for shellcheck-lint.sh and for the same reason: what
# would propagate is the judgement, not the mechanism.
#
# bin/shellcheck-lint.sh is LOCAL because it lints THIS REPOSITORY'S OWN SOURCE.
# Its file selection is `git ls-files` against its own ROOT and its baseline is
# bin/shellcheck-lint.ratchet, both of which describe realisateur's tree and
# nothing else. Shipping it to a self-dev account would hand that account a
# guard whose ratchet is about someone else's code -- it would either lint the
# wrong tree or find no tree at all and report BLIND forever, which is the
# ecosim-sensor failure this estate already has an open issue about.
#
# scheduler wanting the same guard is hf7y/scheduler#77, and the answer there
# is a PORTED COPY with its own re-derived disable list, not a propagated one.
# The disable list encodes a judgement about which shellcheck codes are idiom
# in a specific codebase; propagating it would propagate the judgement.
# selfdev-agent-survey.sh is LOCAL for the same reason as thermostat-wiring.sh:
# an estate-wide, root-only, read-only survey a human runs from a hands account
# against the live fleet. It walks the whole uid 3000-3099 band and shells out
# `sudo -u <each account>`, so it is not a thing any single account runs about
# itself -- an account has no view of its nine neighbours, and the cross-account
# duplication check is a property of the FLEET that no per-account run can see.
#
# It arrived UNCLASSIFIED in c226afd on 2026-08-10 and this suite went red on
# exactly that, which is the gate working: a script with no propagation path
# reaches no account by any route.
#
# selfdev-credentials.sh is LOCAL for the identical reason, one paragraph up:
# it needs `ssh <host>` and passwordless `sudo -n -u <account>` across the
# whole uid 3000-3099 fleet to audit them side by side, and the comparison
# across accounts (which one diverged) is a property of the FLEET no single
# account's own dispatch run could see about itself. --apply narrows to one
# named account but still runs from a hands account over ssh, never from the
# account's own crontab -- the opposite shape of the PULL doctrine section 5
# states for the release channel, and correctly so: converging a CREDENTIAL
# is a provisioning act with a human-reviewed trigger (an operator running
# --apply), not a clock an account winds on itself.
#
# WORTH RECORDING IS WHERE THE RED SAT. `.github/workflows/tests.yml` runs every
# suite in bin/tests/ on every pull request, so CI caught this immediately and
# said so. The commit is on the branch of PR #126 -- which was marked READY,
# with auto-merge enabled, while three of its four checks were failing. The
# convention in CLAUDE.md is that marking a PR ready IS the completion claim,
# and `gh pr merge --auto` is what makes an unattended landing safe; both held
# here (mergeStateStatus BLOCKED, nothing landed). What did not happen is anyone
# reading the red. The gate was never the missing piece.
#
# path-provenance-audit.sh is LOCAL and that is uncomfortable on purpose. It
# is an estate-wide survey, like thermostat-wiring.sh above it, so LOCAL is
# the correct list -- but the account class it most wants to measure is the
# PROVISIONED one, where its bar is 100% and where LOCAL means it does not
# reach. PAYLOAD is not the fix: adding an eighth row would push
# PROP_PAYLOAD_PENDING past a PROP_LEAK_BOUND of 7 that only ever falls, and
# would be reclassifying a gap rather than closing it. The gap is instead
# MEASURED, by that script's own `fleetview` and `sweepwired` checks, and
# handed to the project whose job it is (hf7y/senechal): a sweep senechal runs
# from senechal/health/ reaches every account it has a view of, which is the
# real answer and is not realisateur's to install.
#
# verb-kind-lint.sh is LOCAL for the same reason cut-verb-build.sh above it
# is: it runs INSIDE the release pipeline, over the tree that pipeline just
# assembled, from a checkout GitHub Actions makes of this repository
# (build-verbs.yml checks realisateur out to .realisateur and runs it from
# there). An account never grades a build's channel declarations -- it
# receives a build that has already been graded, or it receives nothing
# because the cut refused. Shipping it as PAYLOAD would also be circular in
# the same way selfdev-gh-app.sh's note describes: the guard that decides
# whether a build may be cut cannot arrive inside that build.

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
