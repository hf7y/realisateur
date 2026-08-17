#!/usr/bin/env bash
# propagation-set.sh -- THE DEV/PROD CONTRACT, in one place.
#
# THE DECISION (2026-08-07, Zach-directed). Self-dev accounts do NOT pull
# fresh clones of realisateur. `main` IS NOT A DEPLOY REF; everything they use
# reaches them through the nightly verb build.
#
# The argument is what it buys the DEV side, not agent safety. If live accounts
# pull `main` on a tick, every commit is a deployment and `main` must turn
# conservative to protect them. Separating them is what lets `main` STAY FAST.
#
# PULL, NOT PUSH. The clock lives on the CONSUMER, in the account's own
# crontab, running as the account. bin/tests/propagation.test.sh asserts this
# mechanically -- the tick must contain no `sudo -u` and no `ssh` on its apply
# path -- so the doctrine is enforced, not merely written here.
#
# BOOTSTRAP AND PAYLOAD. A build cannot deliver its own installer, so a small,
# near-immutable bootstrap is installed once per account by
# setup-selfdev-project.sh. It is bounded and asserted to stay bounded
# (PROP_LEAK_BOUND); everything else is payload and arrives versioned.
#
# TRAP: the PROP_*_SCRIPTS values are newline-separated STRINGS consumed by
#   `for s in $LIST`, not shell code. A `#` comment placed INSIDE the quotes
#   does not comment anything -- it CLOSES the string and the rest of the list
#   executes as commands. The first draft of that very comment did this and
#   propagation.test.sh caught it as 20 lines of "command not found".
#   Comments go ABOVE the assignment.
#
# TRAP: a comment line whose FIRST word is `shellcheck` is parsed as a
#   shellcheck directive -- SC1072/SC1073, a parse error on the whole file.
#   Spell the path as `bin/shellcheck-lint.sh`, never bare.
#
# TRAP: do not reclassify a row to PAYLOAD without a matching man page. That
#   drops it from every build in silence (#85).

PROP_RELEASE_REPO="hf7y/verbs"
PROP_RELEASE_REMOTE="https://github.com/hf7y/verbs.git"

# A version is a UTC-timestamp build id, so lexical sort is chronological.
# ONE pin per HOST since #180: /usr/local/share/verb-builds/current. This path
# is the LEGACY per-account shape, kept because --survey still has to
# recognise it; prop_current_pin() resolves either.
PROP_PIN_PATH=".local/share/verb-builds/current"

# STAMPING -- THREE STATES, NEVER TWO. Every stamper calls
# prop_build_trailer().
#
#   Verb-Build: <build id>   stamped, and the build is known
#   Verb-Build: unknown      stamped, and the producer honestly did not know
#   (no trailer at all)      UNSTAMPED: predates or bypasses the mechanism
#
# TRAP: an unstamped artifact must stay distinguishable from one stamped
#   "unknown" -- they mean opposite things about the mechanism. The second
#   proves the stamper ran and told the truth; the first proves nothing ran.
#   NEVER guess a plausible build id ("the latest one", "the one in the
#   manifest"); that destroys exactly this distinction.
#
# It is a git TRAILER because it must survive the artifact being read later
# out of context: it travels with a clone, a cherry-pick and a patch, and
# `git log --format='%(trailers:key=Verb-Build)'` reads it in bulk.

# prop_current_pin -- the adopted build id, or nothing. Never a guess.
#
# TRAP: TWO ROOTS, in the order the account actually resolves them. The
#   private pin first (an account that still has one is running it, because
#   its ~/.local/bin shims shadow the host-wide directory), the host-wide root
#   second. Without the second this went honest-but-useless the moment an
#   account retired: probed 2026-08-13, four retired accounts stamped
#   `unknown` while running a perfectly well-known build from /usr/local/bin.
#   "Unknown" is right for an unreadable pin and wrong for a pin that moved --
#   and the three-state rule only earns its keep while `unknown` stays rare.
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
# Every entry is a file a consumer must hold BEFORE any payload can arrive.
# Adding one is a review event, not a convenience -- the bound is asserted in
# bin/tests/propagation.test.sh.
#
# TRAP: the bound is spent. selfdev-gh-app.sh takes the fourth and last slot,
#   as the git CREDENTIAL HELPER: an account with no payload cannot
#   authenticate to git and therefore cannot FETCH a payload, so it must be
#   present before anything else can arrive. Classifying it PAYLOAD would be
#   circular -- the build delivering the credential needed to fetch the build.
#   That argument depends on hf7y/verbs being PRIVATE; it went public later,
#   so the classification is now re-openable (#108).
PROP_BOOTSTRAP_SCRIPTS="
install-verb-build.sh
selfdev-release-tick.sh
release-ledger.sh
selfdev-gh-app.sh
"

# Files the bootstrap scripts need alongside them. Named explicitly because
# `setup-selfdev-project.sh` stages by copy into a 0700 home and a missed
# dependency there presents as "Permission denied", not "file not found" --
# the trap vault:realisateur/MONKEY.md 8.3 records from account #4.
PROP_BOOTSTRAP_SUPPORT="
lib/cli-guard.sh
lib/propagation-set.sh
lib/selfdev-app-key.sh
"

# --- PROVISIONING: root-side, runs from a hands account, never on the -------
# --- consumer's clock. Not bootstrap: these stand an account UP, once.
#
# selfdev-gh-app-register.sh is filed here and not LOCAL, which is a close call
# worth naming: LOCAL also admits "operator scripts a human runs from a hands
# account", and this is one. PROVISION wins because it is per-ACCOUNT and
# stands one UP exactly once (two browser clicks per account, vault:realisateur/MONKEY.md 962) --
# this list's literal definition, and what its neighbours land-selfdev.sh,
# provision-selfdev-user.sh, setup-selfdev-project.sh and wire-selfdev-git.sh
# all do. LOCAL's members are repo-wide CI gates and estate-wide surveys; a
# script whose first argument is an account name does not belong among them.
#
# selfdev-app-key.sh is PROVISION: it puts the one GitHub App credential at
# /etc/selfdev/app.pem, so nothing on a bare host can mint a token until it
# has run. Runs AS ROOT on the self-dev host.
PROP_PROVISION_SCRIPTS="
land-selfdev.sh
provision-selfdev-user.sh
install-honey-plugin.sh
setup-selfdev-project.sh
wire-selfdev-git.sh
wire-release-channel.sh
selfdev-gh-app-register.sh
selfdev-app-key.sh
selfdev-permissions-provision.sh
selfdev-hooks-provision.sh
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
notify-senechal.sh
precipitation-scan.sh
silence-audit.sh
gh-sign.sh
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
#
# IT IS NOW WRITTEN OUT rather than being `$PROP_PAYLOAD_SCRIPTS`, because the
# two stopped being the same set the day one of them was actually declared.
# gh-sign.sh is PAYLOAD and is NOT pending: hf7y/realisateur#330 puts bin/gh +
# man/gh.1 on the bashified branch, so it reaches accounts as a verb in a
# dated build and not as a clone-backed shim. That is the exit this section
# has named since #115 -- declare it, add it to PAYLOAD, do not grow the bound
# -- taken for the first time. Anything added to PAYLOAD without a declaration
# belongs in this list too, and then the bound refuses it.
PROP_PAYLOAD_PENDING="
check-project-busy.sh
closeout-lint.sh
focus-commit.sh
notify-senechal.sh
precipitation-scan.sh
silence-audit.sh
"
PROP_LEAK_BOUND=7

# --- LOCAL: never leaves this repo ------------------------------------------
# release-gate.sh and publish-release-verdict.sh are LOCAL because they run in
# the release pipeline (GitHub Actions checks realisateur out to get them), not
# on a consumer. An account never gates or publishes; it only reads the result.
#
# lib/body-grammar.sh is LOCAL: it is sourced by gh-sign.sh and claim-drift.sh
# from inside this checkout, never invoked on its own. It is the one file that
# has to travel WITH the shim if the shim is ever linked host-wide -- the
# GH_SIGN_LIB variable exists so an installer can say where it landed.
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
# gh-sign.sh WAS FILED HERE UNDER PROTEST and is now PAYLOAD, which is the
# protest being answered rather than restated. The protest read: LOCAL is true
# today and is also the one class that guarantees it never works, because a
# shim does nothing unless it is on an account's PATH ahead of the real gh.
# The exit it named -- declare it on the bashified branch with a man page, add
# it to PAYLOAD WITHOUT adding it to PENDING -- is the route #330 took.
#
# The decision that was blocking it, made by Zach on 2026-08-16: yes, a verb
# build may claim `/usr/local/bin/gh` on monkey and shadow the real binary for
# all 13 accounts. The condition attached was that there be exactly ONE copy
# of the policy and that changes to it propagate on their own -- which is why
# bin/carry-drift.sh exists and why the shim dates itself from its own build
# id and marks every body it signs once that build goes stale.
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
# rot-ratchet.sh and directive-prose.sh are LOCAL for the two reasons already
# written above, one each. rot-ratchet.sh inherits decision-rot.sh's exactly:
# it reads that script's output and needs the same estate-wide issue
# credential, which the per-account deploy-key tokens do not have.
# directive-prose.sh inherits markdown-cost.sh's: it is a CI gate on this
# repo's diffs, and reaching other repos is a COPY (#305), not an install.
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
# playbook.sh is LOCAL UNDER PROTEST (#244): its `push` half is a human at a
# keyboard, but its `pull` half is meant to run on every dispatch account,
# where LOCAL means it does not exist. Accounts read their brief with a
# retyped two-command `gh` snippet in BATCH_PROMPT instead -- that is the
# defect #244 exists for.
#
# dexter-* and monkey-* are LOCAL: they need an ssh credential to another
# host, or must run ON the VM host (VBoxManage against the guest).
# monkey-watch's whole purpose is to report monkey being down, which it can
# only do from somewhere that is not monkey (#274). A watcher that ships to
# its subject is the failure, not the delivery.
#
# sunset-coordinator-files.sh is LOCAL: it operates on a CHECKOUT it is
# handed. An account has no such clone and no push right to sixteen repos.
PROP_LOCAL_SCRIPTS="
sunset-coordinator-files.sh
dexter-liveness.sh
dexter-service-deploy.sh
monkey-vdi-to-internal.sh
monkey-watch.sh
playbook.sh
publish-monkey-status.sh
claim-drift.sh
carry-drift.sh
defere.sh
retire-check.sh
decision-rot.sh
rot-ratchet.sh
directive-prose.sh
cut-verb-build.sh
deploy-drift.sh
release-gate.sh
publish-release-verdict.sh
ecosim-sensor-tick.sh
floor-check.sh
hardcoded-home-lint.sh
markdown-cost.sh
ownership-audit.sh
port-markdown-cost.sh
reach-lint.sh
discipline.sh
thermostat-wiring.sh
path-provenance-audit.sh
selfdev-agent-survey.sh
selfdev-credentials.sh
served-not-cloned.sh
shellcheck-lint.sh
verb-kind-lint.sh
repo-settings-provision.sh
branch-protection-provision.sh
verbs-refresh.sh
no-worktree-lint.sh
run-suites.sh
"
# repo-settings-provision.sh is LOCAL: its subject is the FLEET (it walks the
# whole registry), and a per-account copy would be ten writers on one
# setting. It also needs admin on someone else's repo, which self-dev
# accounts deliberately do not hold.
#
# bin/no-worktree-lint.sh is LOCAL: its allowlist is compiled in and is about
# realisateur's tree. scheduler carries its own copy with its own allowlist --
# what propagates is the judgement, not the mechanism (scheduler#77).
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
