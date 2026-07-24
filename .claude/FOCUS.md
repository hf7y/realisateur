## Stability milestone

**REACHED 2026-07-24** — see below. Original bar:
**realisateur reliably turns inbox drops into scaffolded, scheduler-registered projects AND triages every idea active/parked/waiting against each project's milestone (park-by-default), with all three offline surveys wired into every pass** — status: reached
Done when:
- [x] inbox → infer → scaffold → scheduler-register loop runs unattended (proven: 6 projects scaffolded)
- [x] `bin/milestone-audit.sh` exists and the convention is documented (`STABILITY-MILESTONES.md`)
- [x] the offline surveys are wired into both command files (`milestone-audit` added to `/ideate` + `/nightly-batch`; nightly-batch already ran ecosystem-survey + hygiene-lint)
- [x] park-by-default triage APPLIED to real ideas for at least one full pass (2026-07-24: gardien/senechal/wtul each got a real milestone + explicit active/parked tagging against it — git-history-on-RAID and keybinding-parsing parked, naming-registry an explicit named exception, wtul's five deeper-integration items parked)
- [x] build-discipline baseline stamped into every registered project (2026-07-24: crt's dirty tree cleared, then stamped. **Correction, same night:** aedile was WRONGLY marked an edge case here — "no git repo, migrated/defunct" was never actually checked before being written down (same lesson as tonight's credential-gap mistake). It's real and active: tracked as a subdirectory of the `wavebucks` monorepo (`.git` lives at the parent, not `aedile/` itself — a real bug in `bin/scheduler`'s own repo-detection, routed to scheduler via the front door). Stamped its build-discipline checklist same night once corrected; its own milestone content is a separate per-project judgment call, queued below like crt's, not done in this pass)

**New milestone, per STABILITY-MILESTONES.md's Lifecycle (a reached bar means set the next one, not stop):**
**Current:** every scheduler-registered project with a real git repo has a declared `## Stability milestone` of its own, AND park-by-default triage has held across more than one live pass (not just its first exercise) — status: in-progress
Done when:
- [x] gardien, senechal, wtul, scheduler each have a declared milestone (2026-07-24)
- [x] crt got its own dedicated `/ideate crt` pass (2026-07-24) — milestone set (core voice loop + Book Game funnel reliable on potato), park-by-default triage applied against it (dual-tier/Vosk STT eval, bare-metal migration, refactor/docs/polish, wake-judge autonomy, Gemini fallthrough, dexter NPU parked; see crt's own `.claude/FOCUS.md`). This is also the pass that satisfies the next line's "different project than gardien/senechal/wtul" requirement.
- [x] home-assistant got its own dedicated `/ideate home-assistant` pass (2026-07-24) — milestone set (core automations reliable + remote HTTPS access), park-by-default triage applied against it (new device integrations, phased sun-matched circadian rework, kitchen task-lighting design, half-bulbs-off question, wall-switch alternatives, cosmetic entity re-id parked; see home-assistant's own `.claude/FOCUS.md`).
- [ ] the remaining 7 (chezz, nine-speakers, sequestria, vim-arcade, vkv-inventory, groc-mangr, **aedile**) get theirs — incrementally, one per-project judgment call at a time (NOT a bulk-invent — aedile is a real nonprofit Apps Script project — DM-tier bump/triage tuning, scenario library, institutional-memory design — with enough of its own domain nuance to deserve a real pass, not a guessed bar)
- [x] at least one more live `/ideate` pass exercises park-by-default triage on a DIFFERENT project than gardien/senechal/wtul, confirming the mechanism generalizes rather than being a one-off (crt, 2026-07-24, see above)
- [ ] scheduler's own milestone (2026-07-24, see its `.scheduler/FOCUS.md`) reaches `in-progress` → visibly progressing, not stalled — a live signal the engine side of tonight's split is actually working, not just designed

Ideas beyond this bar are PARKED by default (see realisateur/STABILITY-MILESTONES.md):
git-as-archive (Backlog), the `scheduler -i`→realisateur triage-routing hook, and the BLOCKERS.md taxonomy unification (routed to scheduler 2026-07-23) are all `(parked)` — real, past this milestone, revisit when it's reached.

---

**2026-07-24 (`/nightly-batch`, ~04:00 pass): inbox cleared (one artifact, already resolved), no new project scaffolded.**

Only inbox artifact was `Correction-to-the-chezz-wtul-c-20260724-032158.idea` -- its full content (chezz/wtul deploy keys verified working, no credential gap, real cause is the spend-limit-cutoff pattern) was already folded into this file's own credential-gap-correction entry below (commit `a09c5b1`, same night, ahead of this pass). Nothing left to do but archive it -- no new decision, no new build. All three offline surveys came back substantively unchanged from the last recorded pass (crt's 24 hygiene FLAGs still pre-existing/already-flagged there; milestone-audit still 5 declared/8 missing/1 no-focus, no reached triggers; vision-debt ranking still topped by the three 2026-07-18 home-assistant entries). QUESTIONS.md: both open blocks (crt dirty-tree, aedile/vkv-inventory recovery) still unanswered, left untouched. Park-by-default triage not exercised this pass -- no live new-project/new-addition candidate in tonight's inbox.

**2026-07-24 (`/nightly-batch`): inbox cleared, no new project scaffolded, chezz/wtul FOCUS.md formatting fixed.**

Ran the three offline surveys first (clean: crt's 27 FLAGs are its own
pre-existing dirty-tree/exec-bit/silent-pipe issues, already flagged,
not touched). QUESTIONS.md: two already-answered/already-folded blocks
(bare-remote chown, incubation-audit reweight) removed as processed; the
crt-dirty-tree block is still unanswered, left in place. Five inbox
artifacts at the repo root, all already-decided or realisateur's-own-
process notes rather than new ideas needing a fresh project:
`Build-the-stability-milestone-*.idea` (already built, see the section
above), `look-at-Document-Project-Archi-*.idea` (already reconciled,
`/ideate` shipped 2026-07-22, remainder stays parked), `Spec-out-a-more-
principled-eco-*.idea` (already routed to scheduler 2026-07-23),
`incubation-decisions-2026-07-22.conf` (applied then superseded
2026-07-23) — all archived. `FOCUS-md-formatting-compliance-*.idea`
(flagged by scheduler 2026-07-22: chezz's FOCUS.md was prose/HTML-
comment-only, wtul had no real FOCUS.md) was genuinely actionable:
wrote `FOCUS-FORMAT.md` (canonical spec, matches what
`extract_next_items()` in `bin/scheduler` actually parses), added a
real `## Priority queue` section to chezz's FOCUS.md (existing comment
content untouched), fleshed out wtul's FOCUS.md into a thin pointer
into `ROADMAP.md` (kept as the real detail doc, to avoid drift).
Committed in both projects' own repos, tagged `(realisateur)`; **could
not push either** — both use real GitHub remotes (`git@github.com:hf7y/
{chezz,wtul}.git`) this environment has no publickey credentials for
(same "prefer local bare remote, GitHub needs real credentials" bar
`SCHEDULER.md`/this file's Backlog section already names) — commits sit
local, will push on each project's own next scheduled dispatch, or push
by hand if that's wanted sooner. **Milestone checklist note:** this pass
did NOT exercise park-by-default triage against a live idea (nothing in
tonight's inbox was a genuine new-project or new-addition candidate) —
that checklist item stays unchecked, not falsely marked done.

**2026-07-24 (this sprint — vision + concurrency fix + first live triage pass, sequenced per plan):**

- **Concurrency fix shipped (realisateur's half).** `bin/check-project-busy.sh`
  (flock-probes a project's own scheduler job locks, zero AI cost) wired
  into `/ideate` step 4's cross-write bullet — don't edit another
  project's FOCUS.md/QUESTIONS.md while its own automation holds the
  lock. Scheduler's half (dispatch/push robustness) is routed, not
  hand-fixed — see below.
- **Root cause: CORRECTED 2026-07-24, was wrong the first time.** Original
  claim (this same night, earlier): chezz/wtul's stranded commits were a
  credential gap (dispatch environment lacking GitHub SSH access). That
  was never actually tested against the real keys before being routed to
  scheduler — a later pass caught it (zach: "don't they have deploy?"),
  verified directly (`ssh -T`, a real test push), and found chezz/wtul
  already have working, write-verified deploy keys. **No credential gap
  exists.** The real explanation for the original stranded commits is the
  already-documented account-wide spend-limit-cutoff pattern (2026-07-20):
  a run's commit lands, the push doesn't happen because the run got cut
  off by quota exhaustion mid-cycle, not because credentials were
  missing. Real fix (already queued in scheduler's own FOCUS.md): make a
  stale/incomplete push loud in `scheduler status`/`sweep.log`, not new
  credentials. **Lesson for next time:** verify a diagnosis against real
  state (an actual `ssh -T`/test push here) before routing it to another
  project as fact or writing it into memory — a plausible-sounding
  explanation that fits the symptom isn't the same as a tested one.
  `bin/check-project-busy.sh` (below) is unaffected by this correction —
  it solves a different, real problem (cross-writing into a live run's
  files) regardless of what was actually wrong with the pushes.
- **First real park-by-default triage pass.** gardien, senechal, and
  wtul (the three projects this sprint's design-fork decisions touched)
  each got their first `## Stability milestone` — the prerequisite the
  checklist above was waiting on. Hit and fixed a real parser trap along
  the way: the `**Current:**` bar+status must be one physical line, not
  wrapped Markdown — documented in `STABILITY-MILESTONES.md` now so the
  next 8 missing-milestone projects don't repeat it.
- **Remaining sprint work, split per tonight's "both, sequenced" call:**
  - *Triage-hardening:* **DONE, same session.** Both bootstrap exit
    conditions were met (convention exists + a live pass proved park-by-
    default out), so `schedule/_paced.conf`'s `scheduler`/`realisateur`
    weight dropped 3→1 — stated explicitly in that file's own comment
    and in the commit, not a silent reweight.
  - *Scaffold-hardening:* 8 more projects still show `missing` in
    `milestone-audit.sh` (chezz, crt, home-assistant, nine-speakers,
    sequestria, vim-arcade, vkv-inventory, groc-mangr). Per the standing
    "not a bulk-invent" rule, populate incrementally during each
    project's own `/ideate <name>` pass — crt specifically blocked until
    its dirty-tree flag (still open in QUESTIONS.md) is cleared.
- **Blockers only the user can clear:** crt's dirty tree (needs a human
  or crt's own batch to commit-or-clean it — realisateur can't touch it
  meanwhile); whether the dispatch environment actually gets GitHub
  credentials is scheduler's design call but the credential material
  itself (deploy key generation, `known_hosts`) needs a human step no
  agent should do unattended.

**2026-07-24 (`/ideate` ecosystem pass — decisions recorded, nothing built):**

- **scheduler-milestone open question: RESOLVED — engine participates.**
  Decided the engine should get a stability milestone too, not be treated
  as exempt mechanism. Routed via `scheduler -i scheduler` (front door,
  per step 5) rather than hand-edited — scheduler itself now owns whether
  that lands as a `.scheduler/FOCUS.md` `## Stability milestone` section
  or a `milestone-audit.sh` fix to also read `.scheduler/`.
- **gardien's git-history-on-RAID fork: DECIDED — git remote + partial
  clone.** Folded into gardien's own FOCUS.md/QUESTIONS.md
  (`(realisateur)`-tagged). Real synchronicity worth naming here too:
  this is the same underlying shape as this repo's own parked
  "git-as-archive" idea below (empty working root, full history lives in
  git) — if gardien builds the remote/partial-clone mechanism first,
  revisit git-as-archive against it rather than designing from scratch.
- **senechal's "keeper of names and places" fork: SCOPED, not just
  decided.** Naming-convention registry only (new file in senechal's own
  repo, senechal's to name); canonical-shared-location half (lilypond
  library, GitHub tidy-up) explicitly split out as a separate later idea.
  Folded into senechal's own FOCUS.md/QUESTIONS.md.
- **wtul's metadata-API either/or: DECIDED — Discogs, token already in
  hand.** Only part (a) of that 2026-07-18 bundle; (b)/(c)/(d) (catalog
  spreadsheet, printer model, web-photo/OCR) remain genuinely open.
- **Flagging, not fixing:** chezz and crt both show stranded local
  commits from FAILED nightly runs (not pushed to origin, per `scheduler
  status`) — separate from crt's already-flagged dirty-tree stop.
  home-assistant's last run divergence check also printed an empty
  remote-hash field, possibly a reporting glitch rather than a real
  issue. None acted on this pass.
- **Vision-debt state, unchanged:** oldest open dated items are still the
  three 2026-07-18 home-assistant entries — same as last check, not
  drained, not obviously grown either (no new dated items older than
  those surfaced this pass).

**2026-07-24: stability-milestone convention BUILT + wired — active follow-ups (queued, not done):**

- **Milestone population is standing per-project triage work, NOT a
  bulk-invent.** `milestone-audit.sh` shows **11 projects `missing`** a
  `## Stability milestone` section. Populate each incrementally during that
  project's own `/ideate <name>` or nightly triage pass — the bar is a
  per-project judgment call, not something to invent in one sweep. Do the
  projects realisateur is about to build against first, and the
  stable-vs-dream-flagged ones (nine-speakers/sequestria/senechal) early,
  since their `_paced.conf` weight already depends on that judgment.
- **The 2 `no-focus` cases are edge cases, not population targets:**
  `aedile` (no git repo — migrated/defunct) and `scheduler` (keeps its
  FOCUS under `.scheduler/`, not `.claude/`, because it's the *engine*, not
  a scaffolded project). `milestone-audit.sh` assumes `.claude/FOCUS.md`, so
  it reads scheduler as no-focus — a known limitation. **Open question:**
  does the engine participate in the milestone convention at all, or is it
  exempt? Decide before treating scheduler's no-focus as a gap to fix.
- **Reweight decision (the one open pacing call):** scheduler + realisateur
  stay at weight 3 until park-by-default triage runs on **≥1 live pass and
  proves out**, then drop toward 1 per `_paced.conf`'s exit note. Waiting on
  evidence, not on a decision.

**2026-07-23 (`/ideate` — vision-debt strategy, standing doctrine):**
The honest number (scheduler DESIGN-NOTES 2026-07-23): intake is zero-cost
and unbounded (`scheduler -i`), clearing is quota-gated and shared 12 ways,
so the backlog diverges at **−6 to −10 items/week regardless of build
speed**. Conclusion, decided this session:

- **This is a queue-stability problem, not a throughput one.** You cannot
  out-build a free, unbounded idea faucet. Weight bumps slow divergence;
  they never reverse its sign. **Pruning (admission control) is the only
  lever that changes the sign** — it moves arrivals *out of the active set*
  at near-zero cost instead of building them down.
- **Backlog count is the WRONG health metric.** A reservoir fed for free
  *should* grow (already settled: chezz 2026-07-20, a growing backlog is
  the expected shape). Vision debt is only debt when parked ideas
  masquerade as active commitments. Track instead: **(1) active/build-now
  set size per project (cap it), (2) is the oldest *build-now* item
  draining.** Parked-reservoir size is not tracked as debt.
- **Primary discipline = milestone-gated parking.** Each project gets **one
  current stability milestone** (its "stable v1 core" bar — this is the
  recovered "ready to go on its own"/VSM status). Realisateur's triage
  default becomes: *is this idea within the current milestone? If not →
  PARK it* (visible, zero dev cost). Parking is the load-bearing act, not
  building. QUEUED next build (nightly-batch, not this pass): a per-project
  stability-milestone convention + the park-by-default triage step.
- **The weight-3 bump is a BOOTSTRAP, not steady-state.** scheduler +
  realisateur at weight 3 only buys time to stand the pruner up. **EXIT:
  drop both toward 1 once the milestone convention exists AND triage parks
  by default** (mirrored in `_paced.conf`'s comment so it can't silently
  become permanent skim on operational slack).
- **Synchronicity to unify, not build twice:** this "active vs. parked vs.
  waiting" status need is the *same* as the parked `Spec-out-a-more-
  principled-eco` idea (BLOCKERS.md blocking/waiting/fyi taxonomy). One
  status vocabulary should serve vision items and blockers alike — routed
  to scheduler via `scheduler -i scheduler` this session (it's a
  scheduler-convention proposal, front-door per ideate.md §5).

**2026-07-23 (`/ideate` reform pass — three standing decisions):**

- **Identity: realisateur is a steward with sensory organs, not a second
  engine.** The doctrine is "scheduler runs things; realisateur
  perceives → judges → records." Its three offline deterministic auditors
  (`bin/hygiene-lint.sh`, `bin/ecosystem-survey.sh`, `bin/incubation-
  audit.sh`) stay in this repo *deliberately*: they are realisateur's
  senses, not scheduler mechanism misfiled here. The test for what belongs
  in realisateur vs. what goes through scheduler's `-i` front door: does it
  feed a *judgment* (perception/triage/prioritization → realisateur) or is
  it *engine mechanism* the ecosystem runs regardless of judgment
  (timing/dispatch/templates → scheduler)? The auditors inform judgment;
  they don't act on their own. This resolves the "pure mechanism living in
  the vision repo" tension by naming the seam rather than moving code.

- **Weighting reframes around "near a stable core" vs. "bigger still-forming
  dream" (supersedes the incubation-audit graduation framing).** `_paced.conf`
  weight is higher for ideas close to a defined, near-term shape (safe to
  iterate fast unattended) and lower for ideas likely to morph before
  anything built survives (slower pace, NOT "don't build"). Applied
  2026-07-23: **nine-speakers 2→1** — its physical-rig half is a forming
  dream, so the 2026-07-22 "graduation candidate = clean build momentum"
  call conflated momentum with nearness-to-stable. **groc-mangr stays 2**
  (conventional app, no forming-dream flag; re-confirm at next audit). The
  broader incubating/graduation weights the audit applied remain a separate
  open question — see QUESTIONS.md.

- **git-as-archive: consciously parked (see Backlog bullet below).** The
  empty-root-when-idle aesthetic is a real "needs its own design pass," not
  a near-term build. Recorded as deliberately deferred so it stops reading
  as forgotten.

**2026-07-22: `/ideate` added — realisateur's interactive vision/triage
counterpart to `/nightly-batch`, cross-project by design.** Refines the
scheduler/realisateur relationship being worked out this session:
scheduler stays a pure mechanism (timing, pacing via `_paced.conf`'s new
`weight` field — see `docs/priority-weight.md` in the scheduler repo);
realisateur owns interpreting vision — feature requests, cross-project
synchronicities, and "stable build vs. bigger dream" pacing judgments
(vision debt, named 2026-07-20 in `chezz/.claude/commands/ideate.md`
4.5, from the user's own words: *"my ideas outpace implementation of
stable versions so the target is always moving"*). `/ideate` is
interactive-only (surface/ask/record/queue, never build/scaffold — that
stays `/nightly-batch`'s job), works ecosystem-wide by default or scoped
to one project via `$ARGUMENTS`, and is the vehicle for the cross-write
relationship: realisateur writes tagged `(realisateur)` entries directly
into another project's own FOCUS.md/QUESTIONS.md, distinct from that
project's own `(nightly-batch)`/`(bug-sweep)` entries. `bin/ecosystem-
survey.sh` (new, offline-first, no AI — reuses `scheduler status
<project>` per registered project plus a "oldest open dated idea"
ecosystem ranking) backs both this command's step 1 and
`/nightly-batch`'s own orient step now. See `.claude/commands/ideate.md`
for the full shape, including the explicit oldest-first-override
principle (a newer idea CAN jump an older parked one when justified —
state why, don't reorder silently).

Current focus: process whatever's sitting in the inbox (repo root artifacts
not yet archived — see `.claude/commands/nightly-batch.md` step 1 for how
to tell) and turn each viable idea into a real, scaffolded project wired
into the scheduler ecosystem the same way realisateur itself is.

realisateur has no web tracker (like `crt`), so there is no
`NIGHTLY:`-flagged-report convention here — scope is purely this file plus
whatever's physically sitting in the inbox.

**Policy: build maximally autonomously.**

- Pick the most reasonable interpretation of a dropped artifact and act on
  it — scaffold the project, don't just write up what it might be.
- A new project gets its own directory under `~/Documents/Projects/`, its
  own git repo, and (if it's an agent/codebase project that would benefit
  from unattended iteration) its own scheduler registration, following
  exactly the process `SCHEDULER.md` documents for realisateur itself.
- Archive the source artifact once acted on (or once a real decision was
  made not to act on it) so it's not re-processed next time.
- Flag what got built and why in `.claude/QUESTIONS.md` and in the report
  — the flag IS the review point, not a request to build.

- **2026-07-22 (from wtul questions-pane diagnosis):** `vkv-inventory`'s
  `command-nightly-batch.md` never runs `collect-feedback.sh --consume`
  against its own `.claude/QUESTIONS.md`, the same append-only-reply gap
  just fixed in wtul's and the scheduler's own nightly-batch commands (see
  scheduler's `.scheduler/FOCUS.md` backlog for the full writeup). Add the
  same Orient-step fix to vkv-inventory's command file, or confirm it's
  already covered elsewhere before skipping it.

## Realisateur's own process (not inbox ideas — see nightly-batch.md step 3)

- **2026-07-20: "Look into scheduler's idea logic, unite with the habit of
  echoing ideas into text files here" — already solved, no project
  needed.** `scheduler -i realisateur "idea text"` (`~/.local/bin/scheduler`,
  `cmd_idea()`) already special-cases realisateur: instead of writing into
  a FOCUS.md backlog section like every other registered project, it drops
  a real `<slug>-<timestamp>.idea` file at this repo's root — the exact
  same artifact shape as manually echoing a note here. The CLI is the
  unification; nothing new to build. One real gap the CLI's own output
  names: it does NOT `git add`/`commit`/`push` for you, so a dropped idea
  sits invisible to the scheduler's dedicated clone until someone commits
  it by hand (this bit the first three ideas — see `f8f244d`/`7886409`).
  Worth raising with Zach directly: either fold the commit+push into
  `cmd_idea()` itself (small, safe, lives in `~/.local/bin/scheduler` —
  outside this repo), or just keep it a manual step. Source note archived
  as `archive/look-into-scheduler-s-idea-log.idea`.
  **Follow-up, same day: fixed on the scheduler side** — `cmd_idea()` now
  auto-commits (never auto-pushes) for the realisateur path too, same as
  every other project's idea-drop.

- **2026-07-20 (Zach, via `scheduler -i realisateur`): realisateur is
  meant to eventually own abstract visioning across projects, not just
  scaffolding — see the inbox item this generated
  (`look-at-Document-Project-Archi-*.idea`, chezz's `/ideate` command as
  the reference model) for the concrete proposal.**
  **PARTIALLY SHIPPED 2026-07-23 (reconciled):** the
  `/ideate`-for-every-project half of this landed 2026-07-22 (built when
  prompted, not unprompted) — see this file's top entry and
  `.claude/commands/ideate.md`. What remains OPEN from the source idea:
  whether `scheduler -i` should route through realisateur to triage
  whether a dropped note is a next-action-item vs. a vision to incubate
  (the "is scheduler's `-i` proper?" fork) — still unbuilt, still parked
  per scheduler's "hardening first" priority; do not build that
  `-i`→realisateur hook unprompted. What IS worth carrying forward
  regardless of that larger design fork: the "vision debt" pattern named the same session (ideas
  arrive faster than any implementation cadence can stabilize them) —
  named explicitly in chezz's own `ideate.md` now. If realisateur ever
  does take on abstract-visioning ownership, this pattern — making the
  gap between ideation and stable implementation visible rather than
  letting a queue grow silently — is a concrete design input for that
  role, not just chezz's problem.

## Reusable pattern worth applying to scaffolded projects: offline-first checks

**2026-07-22 (scheduler side):** `bin/scheduler status <project>` was
built as the reference implementation of a pattern worth carrying into
any project realisateur scaffolds — see the scheduler repo's
`docs/offline-first-checks.md` for the full writeup. Short version: build
a "how's this doing" check entirely out of deterministic scripts (git
status/ahead-behind/diverged, `bin/collect-feedback.sh` against any
report/blockers file, an awk pass over a QUESTIONS-style file, a log
tail) with **zero AI cost by default**, then layer AI on top only as
strictly optional extras — a one-shot read-only `claude -p` summary
(`--claude`) or a live session preloaded with the same report
(`--interactive`). If a new scaffolded project ends up with its own
FOCUS.md/QUESTIONS.md/report convention (i.e. follows this repo's own
shape), consider giving it the same three-mode status check rather than
defaulting straight to "spin up claude to check in" — reuse
`bin/collect-feedback.sh` directly (it's generic) and copy/source
`report_divergence()` from `bin/scheduler` for the git-health part.

## Backlog (recovered 2026-07-20 — see note below)

Zach's own reply, written directly into `~/reports/realisateur/LATEST.md`
after the first real nightly run, was NOT actually wired to reach this
project (that file gets wholly overwritten each run, and only
`.claude/QUESTIONS.md`'s `> ` convention is contractually read/acted on —
see `scheduler`'s own `docs/feedback-tags.md`). Recovered here by hand
before it was lost to the next overwrite:

- **Idea-incubation "steward"/"husbandry" logic, eventually.** For now,
  ideas auto-registering with the scheduler on scaffold (current
  behavior) is fine. Later: spend a few cycles establishing whether an
  idea is actually viable BEFORE promoting it to full autonomous
  development — aware of the Stafford Beer viable-systems-model framing.
  Wants an explicit project status meaning "ready to go on its own."
  Related, also later: senescence/retirement logic — a way to retire a
  project either because it never got off the ground or because it
  matured out of active development.
- **Prefer git-as-archive over a literal `archive/` folder, eventually.**
  Ideal aesthetic: this repo's root is empty when no ideas are currently
  incubating — an idea lives in the working tree only while incubating,
  then the fact that it was ever here lives in git history rather than a
  permanent `archive/` directory. Scheduler-owned files (FOCUS.md etc.)
  staying under a dot-prefixed folder (`.scheduler/` per the model
  scheduler itself uses) helps keep that clean look. Not designed
  further than this — a real "how" needs its own pass.
  **2026-07-23 (`/ideate`): consciously PARKED, not dropped.** Decided
  this is a genuine design pass of its own (idea-lifecycle in git history
  vs. a visible folder, plus moving scheduler-owned files under
  `.scheduler/`), not something to half-build inline. Revisit as a
  dedicated pass; the aesthetic goal above stands as the target.
- **The only real stop-and-wait bar: something that can't be reverted.** A
  commit, a branch, a new scheduler registration, a local bare git remote
  — none of these block you. What does: a real message to a person outside
  this loop, spending real money, deleting something with no backup, or
  registering against a REAL GitHub remote with credentials that could leak
  (prefer a local bare remote per `SCHEDULER.md` unless a GitHub remote is
  clearly already the right call). If genuinely unsure, that's the
  `.claude/QUESTIONS.md` case — but err toward "revertible, proceed."
