#!/usr/bin/env bash
# ownership-set.sh -- THE OWNERSHIP LEDGER, in one place.
#
# ============================================================================
# THE AXIS, AND WHY IT IS NOT THE ONE propagation-set.sh ALREADY HAS
# ============================================================================
#
# bin/lib/propagation-set.sh answers DISTRIBUTION: bootstrap / provision /
# payload / local -- by what route does this file reach the host that runs it.
# This file answers OWNERSHIP: which project's mission does this file serve.
#
# They are orthogonal, and both are needed. A PAYLOAD verb still has an owner
# (bin/notify-senechal.sh is payload here and senechal's by mission); a LOCAL
# CI gate can be foreign (bin/claim-drift.sh never leaves this repo and is
# still PR tooling, which vim-arcade owns). Conflating them is how a file gets
# defended twice: "it has a propagation path" is not "it belongs here".
#
# The test each axis fails differently:
#   propagation  a file with no channel cannot REACH the host that needs it.
#   ownership    a file with a foreign owner cannot BE MAINTAINED here without
#                this repo's maintainer becoming that project's maintainer.
#
# ============================================================================
# THE MISSION TEST -- one question, from this repo's own documents
# ============================================================================
#
# UNIVERSE.md, "The anatomy", line 47, on what this organ is:
#
#     realisateur -- perception and judgment. Senses (the offline surveys),
#     triages (park-by-default), records. It never decides; the human decides.
#
# PRECIPITATION.md restates the same boundary as a pair:
#
#     Scheduler enforces weights and never sets them; realisateur senses and
#     never decides.
#
# And README.md gives the effector half that is genuinely realisateur's:
#
#     realisateur's job is to notice what's been dropped, infer the idea
#     behind it, and turn it into a real, scaffolded project wired into the
#     rest of the development ecosystem.
#
# So the question asked of every file below is:
#
#   >>> Does this file SENSE the ecosystem, TRIAGE what it senses, or SCAFFOLD
#   >>> a new project from an idea? If it instead ACTS ON the estate --
#   >>> installs, provisions, mints, cuts, publishes, dispatches, relinks --
#   >>> then by this repo's own doctrine it is somebody else's organ, and the
#   >>> only question left is whose.
#
# BELONGS-ELSEWHERE WITHOUT A NAMED RECEIVER IS A COMPLAINT, NOT A FINDING.
# Every foreign row names a receiver, and every receiver is declared in
# OWN_RECEIVERS below with a probe that was actually run.
#
# ============================================================================
# WHAT THIS LEDGER IS NOT
# ============================================================================
#
# It is not a migration order and it does not move anything. Naming a file
# foreign changes nothing about where it runs today; bin/install-shims.sh is
# senechal's by mission AND is the thing that writes the PATH shims this
# estate currently runs on. See bin/ownership-audit.sh's header for why the
# audit and the move are deliberately separate acts.
#
# ============================================================================
# HOW A NEW FILE GETS CLASSIFIED
# ============================================================================
#
# It does not get classified by being added here. The population is derived
# from the tree (see OWN_AREAS), so a new file that is not matched by any row
# is UNCLASSIFIED, and unclassified is a hard finding with a bound of zero --
# the same idiom propagation.test.sh uses, for the same reason: a list is an
# opt-in, and the omission is exactly the dodge the audit exists to close.

# --- the receivers ----------------------------------------------------------
# Each row: <name> <probe verdict>. A receiver must be a project that EXISTS,
# because "belongs elsewhere" aimed at nowhere is how mechanism gets parked
# here in the first place.
#
# verified 2026-08-08 via `gh repo list hf7y --limit 60 --json name`
OWN_RECEIVERS="
scheduler       hf7y/scheduler exists
senechal        hf7y/senechal exists
verbs           hf7y/verbs exists (the meta-repo; cut its first build 2026-08-05)
vim-arcade      hf7y/vim-arcade exists
ecosim          hf7y/ecosim exists
gardien         hf7y/gardien exists
bibliothecaire  hf7y/bibliothecaire exists
bashify         NO REPO -- see OWN_HOMELESS below
office          NO REPO -- see OWN_HOMELESS below
"

# --- the receivers that do not exist yet ------------------------------------
# Two foreign areas name a receiver that has no repository. That is not a
# reason to call them realisateur's; it is the finding. `gh repo list hf7y`
# on 2026-08-08 returned 45 repositories and neither of these was among them.
#
#   bashify   28 commits, its own bin/, lib/, man/, skel/ and 7-file test
#             suite, living as a subdirectory of another project. It is the
#             generator every other project's verb surface is cut by.
#   office    office-economy/ says so itself, in its own README's first
#             sentence: "Staged by realisateur, 2026-07-30, FOR ADOPTION INTO
#             THE OFFICE ON nomac." One commit ever. Nothing adopted it.
#
# A homeless receiver is counted FOREIGN, not exempt -- the number this audit
# ratchets must not improve by declaring a receiver imaginary.
OWN_HOMELESS="bashify office"

# --- the areas the audit derives its population from ------------------------
# Mechanism only. Root *.md, *.idea and archive/ are prose and are priced by
# bin/markdown-cost.sh, which is a different question with a different guard.
OWN_AREAS="
bin
hooks
provision
bashify
fable-like
office-economy
.github/workflows
.claude/commands
"

# --- THE LEDGER -------------------------------------------------------------
# Rows are `<path-prefix> <owner> <reason>`, longest prefix wins. Owner
# `realisateur` means MISSION-UNIQUE: no other project could hold it without
# becoming realisateur. Any other owner means DELEGABLE, and the reason must
# say what makes it that project's rather than merely adjacent to it.
#
# NOTE FOR ANY FUTURE EDITOR: this is a newline-separated data string consumed
# by a `while read` loop, NOT shell code. A `#` inside the quotes closes
# nothing and comments nothing. Comments go above the assignment -- the trap
# propagation-set.sh records having fallen into, and its test caught, as 20
# lines of "command not found".

# ---- MISSION-UNIQUE: sense, triage, scaffold -------------------------------
OWN_MINE="
bin/precipitation-scan.sh          realisateur PRECIPITATION.md's mechanism; ranks promotion signals across every project. Pure sense, and the doctrine names it.
bin/silence-audit.sh               realisateur the null-discriminator. UNIVERSE.md's Ashby reading names proprioception as the third unregulated interface; this is the regulator.
bin/hygiene-lint.sh                realisateur BUILD-DISCIPLINE.md's own mechanization, scanning every registered project for the seeded patterns. Auditing compliance is the half UNIVERSE.md assigned here.
bin/floor-check.sh                 realisateur THE-FLOOR.md's authority. An ecosystem-scoped readout whose whole value is being cross-project; no single project can hold it.
bin/reach-lint.sh                  realisateur asks whether a scaffolded project's command files can reach what they name. The scaffold contract is realisateur's output.
bin/thermostat-wiring.sh           realisateur measures whether the ecosystem matches a redesign or only describes it. Sense over the whole organism, which is this organ's definition.
bin/stamp-agent.sh                 realisateur writes a new project's bootstrap FOCUS.md. This IS the scaffolding step in README.md 3.
bin/restamp-discipline.sh          realisateur propagates the realisateur baseline into scaffolded projects. Seeding, per BUILD-DISCIPLINE.md's opening paragraph.
bin/make-bootstrap-branch.sh       realisateur rebuilds THE PLAY's starting line. THE PLAY is realisateur's own experiment about whether a FOCUS.md can direct an agent.
bin/ownership-audit.sh             realisateur this audit. Sense over what this repo owns; the organ examining itself.
bin/lib/ownership-set.sh           realisateur this ledger.
bin/tests/guard-estate.test.sh     realisateur a test over the guard POPULATION. The population is realisateur's senses; no one project owns it.
.github/workflows/tests.yml        realisateur this repo's own CI.
.claude/commands/ideate.md         realisateur the interactive triage pass. README.md 2 and UNIVERSE.md Law 1's enforcement point.
.claude/commands/nightly-batch.md  realisateur the unattended inbox pass. This is the mission in one file.
"

# ---- DELEGABLE -------------------------------------------------------------
OWN_THEIRS="
bin/install-shims.sh               senechal writes ~/.local/bin shims. CLAUDE.md's standing rule: the project that generates machine config owns it and senechal owns KNOWING it exists. senechal's installe already owns ~/.local/bin, and on 2026-08-07 three orphaned shims exited 127 because install-shims walks SOURCES and cannot express an orphan.
bin/notify-senechal.sh             senechal senechal's own front door, per CLAUDE.md. A project does not own another project's doorbell.
provision/monkey-vm.sh             senechal stands a VM up on a host. Host provisioning is estate work.
provision/monkey-tailscale.sh      senechal host network membership.
provision/monkey-nopasswd.sh       senechal host sudo policy.
provision/monkey-scheduler-system.sh scheduler installs the scheduler's system-side dispatch on a host.
bin/check-project-busy.sh          scheduler a live probe of whether a project's own dispatch run is mid-flight. Liveness of dispatch is the scheduler's fact; realisateur is a consumer of it.
bin/deploy-drift.sh                scheduler asks whether every DISPATCHER is running merged code. The dispatchers are the scheduler's.
bin/focus-commit.sh                scheduler exists solely because the scheduler's ~:30 autocommit watcher is the other writer. UNIVERSE.md split this pair across two repos in 2026-07-26; single-owner is now the doctrine.
bin/session-marker.sh              scheduler declares a human is live in a repo so dispatch defers. A dispatch input.
bin/pivot.sh                       scheduler installs and uninstalls ecosystem MOVEs, most of which are scheduler config. An installer is an effector.
bin/lib/conf.sh                    scheduler reads a scheduler conf. One commit ever; a reader of another project's file format.
bin/provision-selfdev-user.sh      scheduler adds a self-dev dispatch account to a host.
bin/setup-selfdev-project.sh       scheduler stands one dispatch account up end to end.
bin/land-selfdev.sh                scheduler stands the whole dispatch estate up on a bare host.
bin/wire-selfdev-git.sh            scheduler gives a dispatch account its git credentials.
bin/selfdev-gh-app.sh              scheduler the dispatch accounts' git credential helper.
bin/selfdev-gh-app-register.sh     scheduler registers the App a dispatch account authenticates as.
bin/cut-verb-build.sh              verbs cuts the build. provision/verbs-meta/README.md already says the workflow that calls it belongs at hf7y/verbs.
bin/install-verbs.sh               verbs the declared verb surface and its installer.
bin/install-verb-build.sh          verbs installs a pinned build from the meta-repo.
bin/relink-verbs-to-build.sh       verbs migrates ~/.local/bin off bashified branches onto the build.
bin/release-gate.sh                verbs decides whether tonight's build may be cut.
bin/release-ledger.sh              verbs grades the release channel.
bin/publish-release-verdict.sh     verbs publishes the release verdict.
bin/selfdev-release-tick.sh        verbs the consumer-side clock on the release channel.
bin/lib/verb-set.sh                verbs what verbs the ecosystem declares.
bin/lib/propagation-set.sh         verbs the dev/prod contract for the verb release channel. Its own header is an argument about hf7y/verbs' visibility.
provision/verbs-meta              verbs its own README says build-verbs.yml belongs at hf7y/verbs/.github/workflows/build-verbs.yml.
bin/claim-drift.sh                 vim-arcade asks whether a pull request grew after being presented as done. PR tooling.
bin/closeout-lint.sh               bashify generic session-durability lint. Nothing in it is about ideas, inboxes or scaffolding; every repo in the estate wants it, which is the definition of a verb.
bin/hardcoded-home-lint.sh         bashify generic shell lint. Same test.
bin/markdown-cost.sh               bashify generic diff-shape gate. Same test.
bin/suite-docs-lint.sh             bashify generic suite-hygiene lint. Same test.
bin/lib/cli-guard.sh               bashify the argument contract every bashified verb already needs.
hooks                              bashify a generic SubagentStop harness hook wrapping a generic lint.
bashify                            bashify a whole project -- generator, runtime, man page, skel and a seven-file suite -- living as a subdirectory. 28 commits. hf7y/bashify does not exist.
bin/ecosim-sensor-tick.sh          ecosim runs ecosim's sensors on a tick. Named for the project it serves.
office-economy                     office its own README: staged by realisateur for adoption into the office on nomac. One commit, 2026-07-30, never adopted.
fable-like                         bibliothecaire a read-only exhibit of a proposed file structure, dead since 2026-08-01. An archived artifact; the receiving archive UNIVERSE.md names is bibliothecaire.
.claude/commands/bashify.md        bashify the front door of the bashify generator.
.claude/commands/cloture.md        bashify the session-closing ritual, whose deterministic half is closeout-lint.sh. It travels with the lint.
.github/workflows/claim-drift.yml  vim-arcade CI for PR-drift tooling.
.github/workflows/verb-build-smoke.yml verbs CI for the verb build.
bin/tests/release-channel-wiring.test.sh verbs asserts the release channel is wired end to end.
bin/tests/verb-build-test.sh       verbs the verb build's own suite.
"

# --- lookup -----------------------------------------------------------------
# own_owner <path> -- prints `<owner> <reason>` for the longest matching row,
# or nothing (rc 1) when the path matches none. rc 1 IS the finding; a caller
# that swallows it has reintroduced the opt-in list this file refuses to be.
#
# A SUITE FOLLOWS ITS SUBJECT. bin/tests/X.test.sh is owned by whoever owns
# bin/X.sh -- derived, not listed, because a listed suite is a second place to
# forget and would let a foreign script's tests be quietly re-homed here while
# the script itself moved out. Suites whose name maps to nothing (a suite over
# a whole population rather than one script) still need an explicit row.
own_owner() {
  local p="$1" best="" bestlen=0 pre owner rest

  case "$p" in
    bin/tests/*)
      local b="${p#bin/tests/}"
      b="${b%.test.sh}"; b="${b%-test.sh}"; b="${b%.sh}"
      local cand
      for cand in "bin/$b.sh" "bin/lib/$b.sh" "bin/lib/$b-set.sh"; do
        [ "$cand" = "$p" ] && continue
        if own_owner "$cand" >/dev/null 2>&1; then own_owner "$cand"; return 0; fi
      done ;;
  esac

  while read -r pre owner rest; do
    [ -n "$pre" ] || continue
    case "$p" in
      "$pre"|"$pre"/*)
        if [ "${#pre}" -gt "$bestlen" ]; then bestlen=${#pre}; best="$owner $rest"; fi ;;
    esac
  done <<EOF
$OWN_MINE
$OWN_THEIRS
EOF
  [ -n "$best" ] || return 1
  printf '%s\n' "$best"
}

# own_is_receiver <name> -- is this a declared receiver?
own_is_receiver() {
  local n r rest
  while read -r r rest; do
    [ -n "$r" ] || continue
    [ "$r" = "$1" ] && return 0
  done <<EOF
$OWN_RECEIVERS
EOF
  return 1
}
