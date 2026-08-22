#!/usr/bin/env bash
# propagation-set.sh -- THE DEV/PROD CONTRACT, in one place.
#
# THE DECISION (#134, Zach-directed). Self-dev accounts do NOT pull fresh
# clones of realisateur. `main` IS NOT A DEPLOY REF; everything they use
# reaches them through the nightly verb build. The argument is what it buys the
# DEV side: if live accounts pull `main` on a tick, every commit is a
# deployment and `main` must turn conservative to protect them.
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
# TRAP: PAYLOAD without a man page ships nothing, silently (#85).

PROP_RELEASE_REPO="hf7y/verbs"
PROP_RELEASE_REMOTE="https://github.com/hf7y/verbs.git"

# A version is a UTC-timestamp build id, so lexical sort is chronological.
# ONE pin per HOST since #180: /usr/local/share/verb-builds/current. This path
# is the LEGACY per-account shape, kept because --survey still has to
# recognise it; prop_current_pin() resolves either.
PROP_PIN_PATH=".local/share/verb-builds/current"

# The HOST-WIDE pin, in one place. A reader that needs it on ANOTHER host --
# ausculte asks two of them whether they adopted the build the channel cut --
# builds its remote command from this rather than retyping the layout.
PROP_HOST_PIN="${VERB_HOST_BUILD_ROOT:-/usr/local/share/verb-builds}/current"

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
# It is a git TRAILER so it travels with a clone, a cherry-pick and a patch.

# prop_current_pin -- the adopted build id, or nothing. Never a guess.
#
# TRAP: TWO ROOTS, in the order the account resolves them -- the private pin
#   first (its ~/.local/bin shims shadow the host-wide directory), the
#   host-wide root second. `unknown` is right for an unreadable pin and wrong
#   for a pin that moved.
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

# Files the bootstrap scripts need alongside them. A missed dependency staged
# into a 0700 home presents as "Permission denied", not "file not found".
PROP_BOOTSTRAP_SUPPORT="
lib/cli-guard.sh
lib/host-check.sh
lib/propagation-set.sh
lib/selfdev-app-key.sh
"

# --- PROVISIONING: root-side, deployed to the host, invoked there by a -----
# --- human. Not bootstrap: these stand an account UP, once, and they run
# --- on nobody's clock.
#
PROP_PROVISION_SCRIPTS="
dresse.sh
land-selfdev.sh
provision-selfdev-user.sh
setup-selfdev-project.sh
wire-selfdev-git.sh
wire-release-channel.sh
selfdev-app-key.sh
selfdev-claude-token.sh
selfdev-permissions-provision.sh
selfdev-hooks-provision.sh
install-verbs.sh
stamp-verb-build.sh
"

# --- PAYLOAD: reaches user paths as a verb, inside a dated build ------------
PROP_PAYLOAD_SCRIPTS="
etiquette.sh
check-project-busy.sh
notify-senechal.sh
gh-sign.sh
discipline.sh
consigne
ausculte.sh
"

# --- THE LEAK, with a bound on it -------------------------------------------
# PAYLOAD-class scripts that are NOT yet declared on any bashified branch.
PROP_PAYLOAD_PENDING="
"
PROP_LEAK_BOUND=7

# --- LOCAL: never leaves this repo ------------------------------------------
# release-gate.sh and publish-release-verdict.sh are LOCAL because they run in
# the release pipeline (GitHub Actions checks realisateur out to get them), not
PROP_LOCAL_SCRIPTS="
ausculte-cadence.sh
dexter-liveness.sh
publish-monkey-status.sh
decision-rot.sh
cut-verb-build.sh
release-gate.sh
publish-release-verdict.sh
selfdev-credentials.sh
shellcheck-lint.sh
verb-kind-lint.sh
verbs-refresh.sh
run-suites.sh
"
# repo-settings-provision.sh is LOCAL: its subject is the FLEET (it walks the
# whole registry), and a per-account copy would be many writers on one
# setting. It also needs admin on someone else's repo, which self-dev

# prop_host_tools -- what a provisioned host carries under
# /usr/local/libexec/selfdev beyond the bootstrap: the verb a human types and
# every step it runs. DERIVED, so a step added to the provisioning set arrives
# on the host without a second list agreeing to it.
prop_host_tools() {
  # The probes ausculte composes are LOCAL-class and ride here, or it is
  # BLIND about them on a host.
  printf 'dresse.sh\nausculte-cadence.sh\ndexter-liveness.sh\ndecision-rot.sh\n'
  local s; for s in $PROP_PROVISION_SCRIPTS; do [ "$s" = dresse.sh ] || printf '%s\n' "$s"; done
}

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
