#!/usr/bin/env bash
# propagation-set.sh -- THE DEV/PROD CONTRACT, in one place.
#
# THE DECISION (2026-08-07, Zach-directed; the desired-state frame it belongs
# to is #134). Self-dev accounts do NOT pull fresh clones of realisateur.
# `main` IS NOT A DEPLOY REF; everything they use reaches them through the
# nightly verb build.
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
#   `shellcheck` directive -- SC1072/SC1073, a parse error on the whole file.
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
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
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
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
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
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
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
ownership-audit.sh
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
#   [rest: vault:realisateur/guard-archaeology-20260817.md]

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
