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
.agent-project                     realisateur the registry marker this repo both defines and carries. cut-verb-build.sh resolves it across every non-archived repo in one GraphQL query; a project declaring itself in its own tree is the same shape as declaring a verb.
bin/tests/registry-marker.test.sh  realisateur the witness for that derivation, and specifically for the property that a BLIND marker query records NO registry rather than an empty one.
bin/lib/not-a-spend.tsv            realisateur the signed escape from bashify's purge scorer. A vendor-mention ledger is a judgement about what may leave this repo for a bashified branch, which is realisateur's own distribution question; the sibling bin/lib/not-a-verb.tsv is classified here for the same reason.
bin/tests/not-a-spend.test.sh      realisateur the witness for that ledger, and it re-greps every signed file so a row that becomes false fails the build here rather than somewhere downstream.
bin/precipitation-scan.sh          realisateur PRECIPITATION.md's mechanism; ranks promotion signals across every project. Pure sense, and the doctrine names it.
bin/silence-audit.sh               realisateur the null-discriminator. UNIVERSE.md's Ashby reading names proprioception as the third unregulated interface; this is the regulator.
bin/retired/hygiene-lint.sh        realisateur BUILD-DISCIPLINE.md's own mechanization, scanning every registered project for the seeded patterns. RETIRED and UNWIRED 2026-08-14, Zach-directed: it discovered projects through the scheduler schedule directory, so an estate-wide hygiene check could only see repos one unrelated project had registered, and saw none at all on a host with no scheduler checkout. Kept under bin/retired/ so its ideas can be mined; hf7y/realisateur#265 names them. Auditing compliance is still the half UNIVERSE.md assigned here, so this ROW stays even though the mechanism is unwired.
bin/monkey-vdi-to-internal.sh      realisateur moves monkey's virtual disk off a failing external drive onto the VM host's internal storage. monkey is realisateur's self-dev host (MONKEY.md) and this repo already owns the provisioning that stands its accounts up.
bin/monkey-watch.sh                realisateur publishes monkey's liveness from dexter, the VM host, so the report survives the guest being down. Same ownership as the host it watches; hf7y/realisateur#274 is why it exists.
bin/lib/monkey-watch-merge.py      realisateur merges dexter's host-side view onto monkey-status-collect.py's document. A separate file rather than a heredoc inside monkey-watch.sh: the merge is where the published page's contract lives.
bin/retired/hygiene-lint.test.sh   realisateur follows bin/retired/hygiene-lint.sh into retirement. A test for an unwired script is unwired too; it is kept for the same reason the script is, so a future rebuild has its assertions to read.
bin/floor-check.sh                 realisateur THE-FLOOR.md's authority. An ecosystem-scoped readout whose whole value is being cross-project; no single project can hold it.
bin/reach-lint.sh                  realisateur asks whether a scaffolded project's command files can reach what they name. The scaffold contract is realisateur's output.
bin/sunset-coordinator-files.sh    realisateur removes a retired coordination surface (.scheduler/, FOCUS.md, QUESTIONS.md, BLOCKERS.md) from any repo, producers first. Estate-scoped like bin/floor-check.sh one row up: no single project can retire a convention every project carries, and the convention being retired -- scheduler#66's -- was realisateur's to notice was still live.
bin/tests/sunset-coordinator-files.test.sh realisateur follows its subject, bin/sunset-coordinator-files.sh.
bin/thermostat-wiring.sh           realisateur measures whether the ecosystem matches a redesign or only describes it. Sense over the whole organism, which is this organ's definition.
bin/shellcheck-lint.sh             realisateur mechanizes BUILD-DISCIPLINE.md's FIRST row -- fails loud, no exit-0 no-ops -- which is the same claim hygiene-lint.sh has and the same reason. SC2164, SC2181, SC2086 and SC2115 ARE the silent-failure class that document names; this is that row with an exit code. Auditing compliance is the half UNIVERSE.md assigned here.
bin/tests/shellcheck-lint.test.sh  realisateur follows its subject.
bin/gh-sign.sh                     realisateur the WRITE half of decision-rot.sh's own predicate. Its ancestor bin/gh-comment.sh was vim-arcade's because vim-arcade owned the stamp GRAMMAR (#77); this file cuts the grammar down to a marker, and what is left has exactly one consumer in the estate -- realisateur's sensor, which cannot date an answer without telling an agent's reply from Zach's under one shared token. A sensor that must manufacture its own discriminator owns it; same argument as bin/silence-audit.sh.
bin/tests/gh-sign.test.sh          realisateur follows its subject.
bin/tests/lib/harness.sh           realisateur the assertion vocabulary this repo's own suites run on. Mission-unique: it exists because 51 of 54 suites had re-declared it, which is a fact about THIS tree's suites and travels nowhere.
bin/no-worktree-lint.sh            realisateur mechanizes a standing instruction -- no more worktrees after tonight, 2026-08-06 -- that three production scripts had quietly undone by the time it was five days old. Auditing compliance with a rule the human set is the same half of UNIVERSE.md that hygiene-lint.sh and shellcheck-lint.sh serve; the estate-wide subject -- realisateur's own bin/, bashify's generator, and scheduler's dev loop all created worktrees -- is what makes it no single consumer's.
bin/tests/no-worktree-lint.test.sh realisateur follows its subject.
bin/run-suites.sh                  realisateur runs this repo's own suite population from tests.yml, quarantine-aware (#316). Local, unpropagated CI plumbing for this repo's build, not a bashified generic.
bin/run-suites.quarantine          realisateur the data run-suites.sh reads; follows its subject.
bin/tests/run-suites.test.sh       realisateur follows its subject.
bin/selfdev-agent-survey.sh        realisateur asks whether each self-dev account does what its own dispatch prompt claims. Sense over the whole fleet, and realisateur owns the self-dev account contract that prompt is measured against.
provision/dexter/README.md         realisateur declares where work lives on dexter and what may run there. Same organ as MONKEY.md, which this repo already holds: naming the host layout is triage, and the document sits beside the compose files it governs.
bin/dexter-liveness.sh             realisateur asks whether dexter is serving what it is declared to serve. Same claim as bin/publish-monkey-status.sh's row one line down -- realisateur owns the host layout document (provision/dexter/README.md) and the probes over it -- and the alarm belongs with the declaration it checks, not with the services it names.
bin/tests/dexter-liveness.test.sh  realisateur follows its subject.
bin/dexter-service-deploy.sh       realisateur ships a service from a repo to dexter's /srv. The container channel is the service-side twin of the verb release channel, and realisateur owns the propagation contract for both. The SERVICES it carries stay their own projects' -- this is the road, not the freight.
bin/tests/dexter-service-deploy.test.sh realisateur follows its subject.
bin/publish-monkey-status.sh       realisateur publishes what the self-dev fleet actually did, to a page anyone can read. Same claim as bin/selfdev-agent-survey.sh's row -- realisateur owns the self-dev account contract, so the readout over the whole fleet is realisateur's -- and it publishes SENSE, where verbs' publish-release-verdict.sh publishes the release channel's own act.
bin/monkey-status-collect.py       realisateur follows its subject: the half of publish-monkey-status.sh that runs as root on the self-dev host. Python because it walks /etc/passwd, two files per account and a JSON ledger, and shells out for none of it.
bin/playbook.sh                    realisateur carries a self-dev account's standing brief between a human and an unattended run. The brief is part of the self-dev account contract -- the same contract selfdev-agent-survey.sh measures compliance with -- and no single project can own the door its own dispatch reads through.
bin/served-not-cloned.sh           realisateur asks whether mechanism reaches an account by being served or copied. The release channel and the propagation contract are realisateur's, so the probe that says whether the estate actually uses them is too.
bin/tests/served-not-cloned.test.sh realisateur follows its subject.
bin/verb-kind-lint.sh              realisateur asks whether every command in a build says which channel it ships on. A close call, so the argument: bin/cut-verb-build.sh is verbs' because it CUTS -- it acts. This one reads a tree and reports, which is the sense/act line the mission test above draws, and it is the same shape as served-not-cloned.sh two rows up: the release channel's effectors are verbs', the probes over it are realisateur's.
bin/tests/verb-kind-lint.test.sh   realisateur follows its subject.
bin/wire-release-channel.sh        realisateur installs the verb-build bootstrap and its clock on an existing account. realisateur owns the release channel end to end -- cut, install, tick and the propagation contract -- so the door onto it is realisateur's too.
bin/tests/selfdev-agent-survey.test.sh realisateur follows its subject.
bin/repo-settings-provision.sh     realisateur asks whether the estate matches a claim its own doctrine states as settled fact -- thermostat-wiring.sh's question, on a different claim. The SETTINGS are vim-arcade's subject, the way the scheduler redesign is scheduler's; measuring the whole registry against a stated claim, and naming where it is only described, is the sense-over-the-organism half UNIVERSE.md assigns here.
bin/tests/repo-settings-provision.test.sh realisateur follows its subject.
bin/branch-protection-provision.sh realisateur asks the same question as bin/repo-settings-provision.sh's own row, on the claim next to it: claim-drift --convention states 'gh pr merge --auto --squash' as the sanctioned path, and on a repo with no required check that command silently self-merges (#288). Measuring the whole roster against a claim this repo's doctrine states as settled fact is the sense-over-the-organism half UNIVERSE.md assigns here. It names no check context of its own -- it reads each repo's -- so it takes on no other project's CI as a subject.
bin/tests/branch-protection-provision.test.sh realisateur follows its subject.
bin/verbs-refresh.sh               realisateur asks, on the consumer side, the question bin/wire-release-channel.sh installs the answer to: which build is this host on, how old is it, and is there a newer one. Same claim as that row -- realisateur owns the release channel end to end, cut, install, tick and the propagation contract -- and this is the tick for the one host that has no cron to carry it. Every write is delegated to bin/install-verb-build.sh (verbs'), so it owns the QUESTION and none of the mechanism.
bin/tests/verbs-refresh.test.sh    realisateur follows its subject.
bin/selfdev-permissions-provision.sh realisateur declares what a self-dev account is permitted to do unattended, and converges the fleet onto it. Same claim as bin/selfdev-credentials.sh's and bin/install-honey-plugin.sh's own rows: realisateur owns the self-dev account CONTRACT being measured, not the accounts themselves -- scheduler owns the accounts and their dispatch, and nothing here creates, arms or dispatches one. It writes another account's ~/.claude/settings.json, which is machine-wide config senechal must be told about.
bin/tests/selfdev-permissions-provision.test.sh realisateur follows its subject.
bin/discipline.sh                  realisateur prints the realisateur baseline at the point of use. RETIRED bin/restamp-discipline.sh 2026-08-14: propagation-by-stamping produced 11 byte-identical CORRUPTED copies and a source 36 lines behind its own copies, while the drift check reported OK. Owning the baseline never meant owning a copy of it in every repo.
bin/port-markdown-cost.sh          realisateur propagates bin/markdown-cost.sh (bashify's, per its own row below) into a repo that has not been bashified yet -- the seeding door restamp-discipline.sh used for the wider baseline before it was retired, aimed at one named guard.
bin/consigne                       realisateur mechanizes PROSE-REAPING.md's second half. THE CLOSE CALL, WRITTEN DOWN BECAUSE IT WAS NEARLY DECIDED THE OTHER WAY: the deposit path forwards to bibliothecaire's lib/consign-prose.sh, so a first draft of this row said \`bibliothecaire\` -- and the audit answered FLAG [parked], correctly. Forwarding to a mechanism is not owning it; the two lines that exec it are a door, and the SUBSTANCE of this file is \`status\`, which hashes every vault note against the repo it came from and reports what is sitting in both places. That is sense over the whole estate's vault -- 26 DUPLICATED files across six projects when it was written -- and the vault is every project's narrative, not the library's private tree. bibliothecaire owns the deposit; realisateur owns the reaping doctrine the deposit is half of, and this ledger's own rule decides it: a file whose substance is one repo's judgement is that repo's file. Same rationale as bin/floor-check.sh -- an ecosystem-scoped readout no single project can hold.
bin/tests/consigne.test.sh         realisateur follows its subject.
bin/tests/bashify-coin.test.sh     bashify follows its subject -- bashify/lib/coin.sh. It sits in bin/tests/ rather than bashify/test/ for a reason worth recording: bashify/test/verify-*.sh is run by NO workflow (hf7y/realisateur#157, seven suites, one already red), and .github/workflows/tests.yml globs bin/tests/*.sh only. A suite for the estate's only new-verb door, filed where nothing executes it, would be the exact failure this repo keeps naming -- a test only a person who already knew its filename would ever run. Ownership follows the subject; LOCATION follows the runner, until #157 gives bashify/test/ a workflow of its own. NOTE for the next editor: this ledger is a double-quoted shell string, so a plain double quote in a row silently truncates it -- one added on 2026-08-11 turned 1 unclassified file into 128.
bin/ownership-audit.sh             realisateur this audit. Sense over what this repo owns; the organ examining itself.
bin/lib/ownership-set.sh           realisateur this ledger.
bin/tests/guard-estate.test.sh     realisateur a test over the guard POPULATION. The population is realisateur's senses; no one project owns it.
.github/workflows/tests.yml        realisateur this repo's own CI.
.claude/commands/ideate.md         realisateur the interactive triage pass. README.md 2 and UNIVERSE.md Law 1's enforcement point.
.claude/commands/nightly-batch.md  realisateur the unattended inbox pass. This is the mission in one file.
bin/selfdev-credentials.sh         realisateur asks whether each self-dev account's credentials match one declared baseline, side by side across the fleet. Same claim as bin/selfdev-agent-survey.sh's own row, extended from the dispatch-prompt contract to the credential shape -- realisateur owns the self-dev account contract being measured, not the accounts themselves. --apply converges by delegating to wire-selfdev-git.sh, scheduler's own effector, never reimplementing a credential mutation of its own.
bin/install-honey-plugin.sh        realisateur installs the token-cost harness every self-dev account's sessions run under, and verifies it by RUNNING the SessionStart hook as the account rather than by checking that files exist. Same claim as bin/selfdev-credentials.sh's own row: realisateur owns the self-dev account contract being measured, not the accounts themselves -- scheduler owns the accounts and their dispatch, and nothing here touches either.
bin/selfdev-app-key.sh             realisateur places the ONE self-dev GitHub App credential host-wide at /etc/selfdev, and retires the per-account copies. Same claim as bin/selfdev-credentials.sh's own row -- realisateur owns the self-dev account CONTRACT, and which App this host mints tokens as -- with where that key lives -- is part of it. It writes /etc on the self-dev host, which is machine-wide config senechal must be told about, and it deletes nothing except under its own separate --retire-copies flag.
bin/lib/selfdev-app-key.sh         realisateur the resolution order bin/selfdev-app-key.sh, bin/selfdev-gh-app.sh and bin/selfdev-credentials.sh all read -- follows its subject, the way bin/lib/ownership-set.sh follows this audit. It exists because that one fact was spelled four different ways in four scripts (realisateur#209).
bin/tests/selfdev-app-key.test.sh  realisateur the witness for the two above; follows them.
bin/lib/selfdev-credentials-set.sh realisateur the baseline bin/selfdev-credentials.sh reads from -- follows its subject, the way bin/lib/ownership-set.sh follows this audit.
bin/lib/api-restamp.sh             realisateur the GitHub-API fallback transport bin/restamp-discipline.sh falls back to when git push cannot reach a foreign repo (#256) -- follows its subject, the way bin/lib/conf.sh follows restamp-discipline.sh's own conf reads.
bin/tests/api-restamp.test.sh      realisateur follows its subject.
"

# ---- DELEGABLE -------------------------------------------------------------
OWN_THEIRS="
bin/install-shims.sh               senechal writes ~/.local/bin shims. CLAUDE.md's standing rule: the project that generates machine config owns it and senechal owns KNOWING it exists. senechal's installe already owns ~/.local/bin, and on 2026-08-07 three orphaned shims exited 127 because install-shims walks SOURCES and cannot express an orphan.
bin/notify-senechal.sh             senechal senechal's own front door, per CLAUDE.md. A project does not own another project's doorbell.
bin/tests/notify-senechal-footer.test.sh senechal follows its subject, and doubly so: what it asserts is senechal's FOOTER_RE -- the gate tools/issue-janitor.py closes issues on -- and when a senechal checkout is present it imports that module and checks against the real thing. The row is not merely inherited from the doorbell; the property under test lives in senechal's repo.
provision/monkey-vm.sh             senechal stands a VM up on a host. Host provisioning is estate work.
provision/monkey-tailscale.sh      senechal host network membership.
provision/monkey-nopasswd.sh       senechal host sudo policy.
provision/monkey-scheduler-system.sh scheduler installs the scheduler's system-side dispatch on a host.
bin/check-project-busy.sh          scheduler a live probe of whether a project's own dispatch run is mid-flight. Liveness of dispatch is the scheduler's fact; realisateur is a consumer of it.
bin/deploy-drift.sh                scheduler asks whether every DISPATCHER is running merged code. The dispatchers are the scheduler's.
bin/focus-commit.sh                scheduler exists solely because the scheduler's ~:30 autocommit watcher is the other writer. UNIVERSE.md split this pair across two repos in 2026-07-26; single-owner is now the doctrine.
bin/session-marker.sh              scheduler declares a human is live in a repo so dispatch defers. A dispatch input.
bin/stamp-verb-build.sh            realisateur records WHICH VERB BUILD produced a commit, via the pin reader realisateur already owns. The artifact-provenance half of the release channel this project runs; no consumer owns knowing what it was running.
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
bin/release-gate.sh                verbs decides whether tonight's build may be cut.
bin/release-ledger.sh              verbs grades the release channel.
bin/publish-release-verdict.sh     verbs publishes the release verdict.
bin/selfdev-release-tick.sh        verbs the consumer-side clock on the release channel.
bin/lib/verb-set.sh                verbs what verbs the ecosystem declares.
bin/lib/not-a-verb.tsv             verbs the recorded exceptions to that declaration rule, read by cut-verb-build.sh on every cut. It follows its subject.
bin/lib/propagation-set.sh         verbs the dev/prod contract for the verb release channel. Its own header is an argument about hf7y/verbs' visibility.
provision/verbs-meta              verbs its own README says build-verbs.yml belongs at hf7y/verbs/.github/workflows/build-verbs.yml.
bin/claim-drift.sh                 vim-arcade asks whether a pull request grew after being presented as done. PR tooling.
bin/deferral-ledger.sh             vim-arcade asks whether a pull request declares its deferred work. PR tooling, same door as claim-drift.
bin/tests/deferral-ledger.test.sh  vim-arcade follows its subject.
.github/workflows/deferral-ledger.yml vim-arcade follows its subject.
bin/defere.sh                      vim-arcade files an issue and prints the ledger line. Issue tooling; the estate's front door for routing a finding to an owner.
bin/path-provenance-audit.sh       senechal asks whether every PATH entry has an owner and a source. senechal owns knowing what exists on a machine -- Zach reassigned this class explicitly on 2026-08-07.
bin/tests/path-provenance-audit.test.sh senechal follows its subject.
bin/closeout-lint.sh               bashify generic session-durability lint. Nothing in it is about ideas, inboxes or scaffolding; every repo in the estate wants it, which is the definition of a verb.
bin/retire-check.sh                realisateur mechanizes cloture.md step 3's own by-hand grep (#166), same door as hygiene-lint.sh -- auditing compliance with a doctrine this project wrote, first used against this repo before any estate-wide adoption is warranted. Unlike closeout-lint.sh it is not yet wired into any command (#187's .claude/ write gate) or accepted onto the payload ratchet, so it stays realisateur's own tool rather than a claimed bashify verb.
bin/decision-rot.sh                realisateur SENSES the ecosystem and TRIAGES what it senses -- the mission test's own first two verbs. It reads the issue trackers and reports which of Zach's answers nobody took up; it decides nothing and writes nothing. Squarely this organ's.
bin/tests/decision-rot.test.sh     realisateur follows its subject.
bin/rot-ratchet.sh                 realisateur the ratchet half of bin/decision-rot.sh: same organ, same estate-wide sensing, and it reads that script's own --json rather than restating anything.
bin/tests/rot-ratchet.test.sh      realisateur follows its subject.
.github/workflows/rot-ratchet.yml  realisateur the runner for bin/rot-ratchet.sh, which had none: same organ, and it is the clock that makes that guard grade anything at all.
bin/directive-prose.sh             realisateur enforces THIS repo's own doctrine -- a decision must exist where a consumer reads it (#294) -- against this repo's diffs, on retire-check.sh's precedent. It becomes a bashify generic once the copier that carries it exists (#305), not on the day it is written.
bin/tests/directive-prose.test.sh  realisateur follows its subject.
bin/hardcoded-home-lint.sh         bashify generic shell lint. Same test.
bin/markdown-cost.sh               bashify generic diff-shape gate. Same test.
bin/suite-docs-lint.sh             bashify generic suite-hygiene lint. Same test.
bin/lib/cli-guard.sh               bashify the argument contract every bashified verb already needs.
hooks                              bashify a generic SubagentStop harness hook wrapping a generic lint.
bashify                            bashify a whole project -- generator, runtime, man page, skel and a seven-file suite -- living as a subdirectory. 28 commits. hf7y/bashify does not exist.
bin/ecosim-sensor-tick.sh          ecosim runs ecosim's sensors on a tick. Named for the project it serves.
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
