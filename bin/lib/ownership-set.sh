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
crt             hf7y/crt exists (private, pushed 2026-08-12; probed 2026-08-14 via gh repo view)
bashify         NO REPO -- see OWN_HOMELESS below
"

# --- the receivers that do not exist yet ------------------------------------
# One foreign area names a receiver that has no repository. That is not a
# reason to call it realisateur's; it is the finding. `gh repo list hf7y`
# on 2026-08-08 returned 45 repositories and it was not among them.
#
#   bashify   28 commits, its own bin/, lib/, man/, skel/ and 7-file test
#             suite, living as a subdirectory of another project. It is the
#             generator every other project's verb surface is cut by.
#
# There were two. `office` is gone -- not by being reclassified, which is the
# dodge R4 exists to close, but because office-economy/ LEFT THE TREE on
# 2026-08-08 (vault: ecosystem1/realisateur/RETIRED-2026-08-08.md). A homeless
# receiver disappears when its files do, and in no other way: the number this
# audit ratchets must not improve by declaring a receiver imaginary.
OWN_HOMELESS="bashify"

# --- the areas the audit derives its population from ------------------------
# Mechanism only. Root *.md, *.idea and archive/ are prose and are priced by
# bin/markdown-cost.sh, which is a different question with a different guard.
OWN_AREAS="
bin
hooks
provision
bashify
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
#
# A BACKTICK PAIR INSIDE THE QUOTES IS COMMAND SUBSTITUTION, not shell code
# either but executed all the same: OWN_MINE/OWN_THEIRS are double-quoted, so
# bash runs whatever sits between a `` `...` `` pair and splices in its
# output before the string is ever read. The consigne row lost the words
# `bibliothecaire` and `status` this way (confirmed live 2026-08-11 --
# sourcing this file printed two "command not found" errors and the row's
# prose was silently missing both words). Escape a literal backtick as \` or
# it disappears the same way.

# ---- MISSION-UNIQUE: sense, triage, scaffold -------------------------------
#
# THE COUNTER-ARGUMENT FOR bashify, weighed and recorded rather than omitted,
# because the rows above are a judgement and the next reader deserves the other
# side. bin/hardcoded-home-lint.sh sits under `bashify` described as a "generic
# shell lint", and running shellcheck over a tree is at least as generic --
# hf7y/scheduler#77 asks for exactly this guard, which is the definition of a
# verb by this ledger's own test.
#
# What settles it the other way: the portable part is about forty lines of the
# two hundred. The VALUE is .shellcheckrc's disable list and the ratchet, and
# both are a judgement about which codes are idiom in THIS codebase, argued
# from THIS codebase's incidents. bin/lib/propagation-set.sh makes the same
# call for the same reason and #77 is written as a PORTED COPY with a
# re-derived list, not a propagated one. A file whose substance is one repo's
# judgement is that repo's file.
#
# Noted because the ownership ratchet ALSO pushed this way -- `bashify` would
# have added ~374 foreign lines against a bar that --accept can only lower, so
# that classification would stand red indefinitely. That pressure is not the
# reason given above, and if a reader decides the bashify case is stronger,
# the honest move is to raise the bar deliberately, not to leave the row
# wrong.
OWN_MINE="
.agent-project                             realisateur
bin/tests/registry-marker.test.sh          realisateur
bin/lib/not-a-spend.tsv                    realisateur
bin/tests/not-a-spend.test.sh              realisateur
bin/precipitation-scan.sh                  realisateur
bin/silence-audit.sh                       realisateur
bin/monkey-vdi-to-internal.sh              realisateur
bin/monkey-watch.sh                        realisateur
bin/lib/monkey-watch-merge.py              realisateur
bin/floor-check.sh                         realisateur
bin/reach-lint.sh                          realisateur
bin/sunset-coordinator-files.sh            realisateur
bin/tests/sunset-coordinator-files.test.sh realisateur
bin/thermostat-wiring.sh                   realisateur
bin/shellcheck-lint.sh                     realisateur
bin/tests/shellcheck-lint.test.sh          realisateur
bin/carry-drift.sh                         realisateur
bin/carry-drift.ratchet                    realisateur
bin/tests/carry-drift.test.sh              realisateur
bin/gh-sign.sh                             realisateur
bin/tests/gh-sign.test.sh                  realisateur
bin/tests/lib/harness.sh                   realisateur
bin/no-worktree-lint.sh                    realisateur
bin/tests/no-worktree-lint.test.sh         realisateur
bin/run-suites.sh                          realisateur
bin/run-suites.quarantine                  realisateur
bin/tests/run-suites.test.sh               realisateur
bin/selfdev-agent-survey.sh                realisateur
provision/dexter/README.md                 realisateur
bin/dexter-liveness.sh                     realisateur
bin/tests/dexter-liveness.test.sh          realisateur
bin/dexter-service-deploy.sh               realisateur
bin/tests/dexter-service-deploy.test.sh    realisateur
bin/publish-monkey-status.sh               realisateur
bin/monkey-status-collect.py               realisateur
bin/playbook.sh                            realisateur
bin/served-not-cloned.sh                   realisateur
bin/tests/served-not-cloned.test.sh        realisateur
bin/verb-kind-lint.sh                      realisateur
bin/tests/verb-kind-lint.test.sh           realisateur
bin/wire-release-channel.sh                realisateur
bin/tests/selfdev-agent-survey.test.sh     realisateur
bin/repo-settings-provision.sh             realisateur
bin/tests/repo-settings-provision.test.sh  realisateur
bin/branch-protection-provision.sh         realisateur
bin/tests/branch-protection-provision.test.sh realisateur
bin/tests/ci-provision.test.sh             realisateur
bin/verbs-refresh.sh                       realisateur
bin/tests/verbs-refresh.test.sh            realisateur
bin/selfdev-permissions-provision.sh       realisateur
bin/tests/selfdev-permissions-provision.test.sh realisateur
bin/selfdev-hooks-provision.sh             realisateur
bin/tests/selfdev-hooks-provision.test.sh  realisateur
bin/discipline.sh                          realisateur
bin/port-markdown-cost.sh                  realisateur
bin/consigne                               realisateur
bin/tests/consigne.test.sh                 realisateur
bin/tests/bashify-coin.test.sh             bashify
bin/ownership-audit.sh                     realisateur
bin/lib/ownership-set.sh                   realisateur
bin/tests/guard-estate.test.sh             realisateur
.github/workflows/tests.yml                realisateur
.claude/commands/ideate.md                 realisateur
.claude/commands/nightly-batch.md          realisateur
bin/selfdev-credentials.sh                 realisateur
bin/install-honey-plugin.sh                realisateur
bin/selfdev-app-key.sh                     realisateur
bin/lib/selfdev-app-key.sh                 realisateur
bin/tests/selfdev-app-key.test.sh          realisateur
bin/lib/selfdev-credentials-set.sh         realisateur
bin/lib/api-restamp.sh                     realisateur
bin/tests/api-restamp.test.sh              realisateur
"

# ---- DELEGABLE -------------------------------------------------------------
OWN_THEIRS="
bin/install-shims.sh                       senechal
bin/notify-senechal.sh                     senechal
bin/tests/notify-senechal-footer.test.sh   senechal
provision/monkey-vm.sh                     senechal
provision/monkey-tailscale.sh              senechal
provision/monkey-nopasswd.sh               senechal
provision/monkey-scheduler-system.sh       scheduler
bin/check-project-busy.sh                  scheduler
bin/deploy-drift.sh                        scheduler
bin/focus-commit.sh                        scheduler
bin/session-marker.sh                      scheduler
bin/stamp-verb-build.sh                    realisateur
bin/pivot.sh                               scheduler
bin/lib/conf.sh                            scheduler
bin/provision-selfdev-user.sh              scheduler
bin/setup-selfdev-project.sh               scheduler
bin/land-selfdev.sh                        scheduler
bin/wire-selfdev-git.sh                    scheduler
bin/selfdev-gh-app.sh                      scheduler
bin/selfdev-gh-app-register.sh             scheduler
bin/cut-verb-build.sh                      verbs
bin/install-verbs.sh                       verbs
bin/install-verb-build.sh                  verbs
bin/release-gate.sh                        verbs
bin/release-ledger.sh                      verbs
bin/publish-release-verdict.sh             verbs
bin/selfdev-release-tick.sh                verbs
bin/lib/verb-set.sh                        verbs
bin/lib/not-a-verb.tsv                     verbs
bin/lib/propagation-set.sh                 verbs
provision/verbs-meta                       verbs
bin/claim-drift.sh                         vim-arcade
bin/lib/body-grammar.sh                    vim-arcade
bin/tests/body-grammar.test.sh             vim-arcade
.github/workflows/deferral-ledger.yml      vim-arcade
bin/defere.sh                              vim-arcade
bin/path-provenance-audit.sh               senechal
bin/tests/path-provenance-audit.test.sh    senechal
bin/closeout-lint.sh                       bashify
bin/retire-check.sh                        realisateur
bin/decision-rot.sh                        realisateur
bin/tests/decision-rot.test.sh             realisateur
bin/rot-ratchet.sh                         realisateur
bin/tests/rot-ratchet.test.sh              realisateur
.github/workflows/rot-ratchet.yml          realisateur
bin/directive-prose.sh                     realisateur
bin/tests/directive-prose.test.sh          realisateur
bin/hardcoded-home-lint.sh                 bashify
bin/markdown-cost.sh                       bashify
bin/lib/cli-guard.sh                       bashify
hooks                                      bashify
bashify                                    bashify
bin/ecosim-sensor-tick.sh                  ecosim
.claude/commands/bashify.md                bashify
.claude/commands/cloture.md                bashify
.github/workflows/claim-drift.yml          vim-arcade
.github/workflows/verb-build-smoke.yml     verbs
bin/tests/release-channel-wiring.test.sh   verbs
bin/tests/verb-build-test.sh               verbs
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
#
# own_derived_from <path> -- prints the path whose row gave <path> its owner,
# when the owner was DERIVED rather than declared for <path> itself; rc 1 when
# nothing derived it. Same rule as the branch below, and deliberately the ONLY
# copy of the candidate list: bin/ownership-audit.sh has to ask which file a
# derived one follows (a suite for a script already here is not a new foreign
# path), and a second list over there would be a second answer to drift from.
own_derived_from() {
  local p="$1" b cand
  case "$p" in
    bin/tests/*) : ;;
    *) return 1 ;;
  esac
  b="${p#bin/tests/}"
  b="${b%.test.sh}"; b="${b%-test.sh}"; b="${b%.sh}"
  for cand in "bin/$b.sh" "bin/lib/$b.sh" "bin/lib/$b-set.sh"; do
    [ "$cand" = "$p" ] && continue
    if own_owner "$cand" >/dev/null 2>&1; then printf '%s\n' "$cand"; return 0; fi
  done
  return 1
}

own_owner() {
  local p="$1" best="" bestlen=0 pre owner rest sub

  # No recursion hazard: own_derived_from only ever answers for bin/tests/*,
  # and every candidate it hands back is bin/*.sh or bin/lib/*.sh, which it
  # refuses on sight.
  if sub="$(own_derived_from "$p")"; then own_owner "$sub"; return 0; fi

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
