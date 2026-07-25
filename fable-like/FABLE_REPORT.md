# FABLE REPORT — an honest accounting of the ecosystem

*2026-07-25. Sources: realisateur's full doc set (doctrine, journals, commands,
bin/), scheduler's registry + engine + DESIGN-NOTES + live run logs from the
night of 07-24→25, on-disk survey of all four project roots, and the 15
registered confs. Signals were read, not vibes.*

---

## TL;DR

You have built something genuinely unusual: a self-developing ecosystem with a
real theory of itself — vision debt as a queue-stability problem, admission
control as the only sign-changing lever, mechanical guards over reminders,
and an engine/judgment split that most teams of ten never articulate. The
doctrine is better than most professional platform teams'.

The failures are almost all the same failure: **you don't consistently apply
your own doctrine to the layer that runs the doctrine.** Silent orphaning of
two projects for four days, a wrapper zoo the generic entrypoint was supposed
to retire, a stale services/ view lying pleasantly since 07-18, your most
active repo living in a folder named "Archive," flagged one-line fixes left
unapplied, journals growing past human rereadability. Every one of these has a
name in BUILD-DISCIPLINE.md. The checklist audits the projects; nobody audits
the auditor.

---

## What you're doing right

1. **The vision-debt analysis is correct and rare.** "You cannot out-build a
   free, unbounded idea faucet" — treating backlog as a reservoir, tracking
   active-set drain instead of backlog size, making parking the load-bearing
   act. Most people never stop treating this as a throughput problem. You did
   the math (−6 to −10/week regardless of build speed) and changed levers.

2. **Guards over reminders, and you mean it.** flock probes before cross-writes,
   crontab managed blocks with 23 timestamped backups, weight enforced by
   literal round-robin repetition, hygiene-lint scanning for the six failure
   signatures, dirty-tree-is-a-stop. The doctrine is *mechanized*, not framed
   on a wall.

3. **Retrospectives that actually generalize.** crt's 186-commit first week
   became BUILD-DISCIPLINE.md, stamped into every new scaffold before first
   `git add`. One project's pain became everyone's checklist. That's the whole
   point of a retrospective and almost nobody completes the loop.

4. **Epistemic self-correction, in writing.** The credential-gap retraction
   ("a plausible-sounding explanation that fits the symptom isn't the same as
   a tested one") is recorded as a lesson, not buried. Same for the reverted
   aedile carve-out, the abandoned Compute Stick with a do-not-resume marker,
   "SUPERSEDED same day" entries everywhere. Your history doesn't lie to you.

5. **The autonomy bar is crisp.** What never blocks (commits, branches, local
   bare remotes, registrations) vs. what always does (messages to humans, money,
   irreversible deletion, leakable credentials). Local bare remotes in
   `~/git-remotes/` are an elegant credential-free autonomy primitive.

6. **Offline-first sensing.** All three surveys are bash/git/awk, zero AI cost,
   run *before* reasoning, output framed as "signals, not verdicts." The
   cheap/expensive layering is exactly right.

7. **The aesthetic is real and consistently applied.** French for the personal
   household, Roman for the collective; the empty-desk vision; append-only dated
   prose. It's not decoration — naming carries ownership semantics (senechal as
   keeper of names, aedile as public-works magistrate).

8. **Host scoping done properly.** `_paced.<hostname>.conf`, dexter as an
   independent dispatcher with a git-shell-only deploy key, physical-side-effect
   projects excluded from concurrency experiments, the sweep tick deliberately
   not quota-gated because it's free.

---

## What you're doing wrong

Ranked by cost, each named in your own vocabulary.

1. **Silent failure at the system layer.** aedile and vkv-inventory were
   disabled 2026-07-20 for a migration that never completed; zero dispatch for
   four days, discovered by accident. Your #1 rule ("the #1 cost multiplier")
   has no enforcement above the single-project level: nothing anywhere asserts
   *"enabled project ⇒ recent report."* One ~40-line cron script closes the
   class (see `projects/scheduler/bin/liveness-audit.sh`). Related unlouded
   smells from one single night's log: an uninvestigated `rc=1` at 00:19, the
   `[legacy absolute path]` defect stamped on every rotation line, chezz's
   staleness check no-op'ing during the mega-burn, mandark's log showing crt
   dispatches after crt supposedly moved to dexter.

2. **Layer-not-replace, at home.** `bin/scheduler-run` exists precisely to
   retire the per-project wrappers; ~20 legacy `*-loop.sh` scripts still live in
   `~/.local/bin` and `_paced.conf` still points at them. `morning-report.sh`
   deprecated but present. `incubation-audit.sh` superseded but present.
   `services/` superseded by the glance but still regenerable and stale since
   07-18. MIGRATION.md documents the path; the migration just doesn't finish.
   Your own rule: a new mechanism names what it retires — then must actually
   retire it.

3. **The directory structure lies, and the fix keeps slipping.** Your single
   most active repo (scheduler, 185 commits/7d) lives in "Project Archive"
   beside genuinely dead material and a 1.1 GB mp4. Four roots; wtul bare in
   `~/Documents`; a stranded, unregistered `Projects/FOCUS.md` holding your
   best UX idea (the empty desk). Normalization was *decided* 2026-07-24 —
   it's queued as one big batch, which is why it hasn't moved. Do it one
   project per pass; scheduler first, since its name is the biggest lie.

4. **Flagged-not-applied one-liners.** aedile's missing
   `SCHEDULER_SUBDIR=".scheduler"` means milestone-audit has misreported it
   as "no focus" *every single pass* while a 21 KB FOCUS.md sits there; the
   questions symlink points at the wrong file. Both known, both one line, both
   unapplied. A survey whose known-wrong output you read daily trains you to
   ignore the survey — that's how guards rot into noise.

5. **Journals are approaching write-only.** DIGEST.md 256 KB, DESIGN-NOTES.md
   88 KB, realisateur's FOCUS.md 56 KB / 2,000+ lines. Append-only honesty is
   right; unbounded single files are not. Standing doctrine mixed with dated
   log means every reader (human or nightly agent, every run, at token cost)
   re-wades through superseded text. Split doctrine-files (edited in place)
   from journals (append, roll up monthly with an index).

6. **Parked-by-velocity, not parked-by-choice.** The 07-24 parking criterion
   was "no milestone AND low commits" — so the unmilestoned set and the parked
   set are the same set, and "parked" is standing in for "never triaged."
   Your own doctrine: parked is a *choice*. Six projects lack milestones;
   until each parked project has a bar, re-admission is undefined and the
   reservoir framing is unfalsifiable.

7. **The human queue has no teeth.** BLOCKERS.md accumulates (sweep ownership
   only just assigned), and human-only steps stall invisibly: svc-vaporwave
   crontab — a 15-minute task — pending 5 days and silently costing two
   projects all their dispatch; wtul's deploy key half-staged. The taxonomy
   you already routed (blocking/waiting/fyi = active/parked/waiting) fixes the
   *display*; what's missing is **age on blocking items, shown daily**. An
   autonomous ecosystem's real SPOF is the human step nobody re-surfaces.

8. **Format-by-parser-quirk.** The FOCUS format is defined by what an awk
   heuristic tolerates; the milestone one-physical-line trap bit three projects
   in one day. When a format gotcha bites repeatedly, the parser is wrong, not
   the projects. Either loosen the parser or make the lint say "join these two
   lines" — UNRECOGNIZED is a silent failure with a loud name.

9. **Names have a keeper but no registry.** Two unrelated bibliothécaires exist
   right now (crt's parked catalog split vs. the inbox "page 92"). Naming is a
   stated aesthetic with an assigned owner (senechal) and zero mechanism. A
   20-line NAMES.md consulted before scaffold is the whole fix.

10. **Senechal is quietly becoming three projects** (environment journal, keeper
    of names/places, shared-host footprint registry) at weight 1. Each mission
    is legitimate; unbounded prose missions on a low-weight project is how
    important things become nobody's job. Make the footprint ledger a file
    format hygiene-lint can diff; put names in the shared registry; keep the
    journal as the milestone-bearing core.

---

## The fable-like restructure, in one paragraph

One root (`projects/`), an `archive/` whose name tells the truth, the empty-desk
vision realized as `desk/` (morning glance + human queue with ages),
`.scheduler/` standardized everywhere so `SCHEDULER_SUBDIR` and the
sensitive-file gate both disappear, a liveness guard wired into the engine,
doctrine split from journal, a name registry, and a milestone in every project
— proposed ones marked `PROPOSED (fable)` for the six that have none. The vkv
subtree is symlinked, not moved, because Tyler co-owns it.

---

## Per-project report cards

**scheduler** — *A−, the engine is good; the housekeeping isn't.* Paced governor,
host scoping, mutex/registry separation, crontab hygiene: all strong. Fix: the
liveness guard; finish the wrapper migration; delete services/; investigate the
07-25 00:19 rc=1; compact the journals; move out of "Project Archive."

**realisateur** — *A−, the doctrine organ works; feed it its own medicine.* The
milestone convention, park-by-default, and cross-write protocol are the
ecosystem's best ideas. Fix: process the two inbox artifacts (36+ hours old);
build the two queued lints; split FOCUS.md doctrine from journal; name registry.

**crt** — *B+, healthiest builder, one open question.* Discipline source case,
hardware verified, freshness probe in place. Fix: explain mandark's 07-24 23:58
crt dispatches (double-dispatch or stale log — verify, don't assume), then make
single-host dispatch a runner-enforced invariant.

**chezz** — *B−, the elder without a bar.* Runs nightly at weight 1 with no
milestone — motion without direction. Fix: milestone; `.claude/`→`.scheduler/`;
retire its legacy wrapper; make the staleness check fail loud; re-admit or
explicitly park the sweep tier (paused "pending" for 6 days).

**home-assistant** — *B, right autonomy posture, oldest debt.* Correctly low-tier
and burst-excluded. Fix: drain or honestly re-tag the three 2026-07-18 items —
the ecosystem's oldest active debt; make burst exclusion a conf flag; rename
`home_assistant` → `home-assistant` on disk when it moves roots.

**wtul** — *B, real tool, tangled logistics.* Discogs decided, deploy key works
on mandark. Fix: name the one remaining human step for the dexter move in
BLOCKERS (gh install or web-UI key); keep the thin FOCUS list pointing at
ROADMAP.md explicitly; finish `.scheduler/` migration (already in BLOCKERS).

**gardien** — *A, the model citizen.* Autonomy bar applied perfectly (temp-dir
testing, human-verified mounts). Waiting on hardware, correctly tagged. Fix:
nothing structural — record the rejected fork option in one line.

**senechal** — *B, mission creep at weight 1.* Three missions in prose. Fix:
footprint ledger as FOOTPRINTS.tsv (lint-diffable); names into the shared
registry; milestone around the rebuild-in-one-sitting core.

**groc-mangr / sequestria / nine-speakers / vim-arcade** — *C+/incomplete, parked
by default rather than choice.* All four lack milestones, so parking was a
velocity artifact. Proposed bars now exist in their fable FOCUS files
(one shopping trip; a fence-compliant brand brief; a headless 9-node belief sim;
one playable level). vim-arcade is the cheapest re-admission; nine-speakers has
the cleanest dream/buildable split; sequestria's hard fences are exemplary.

**aedile** — *D for the system around it, not the project.* Silently orphaned
5 days; two known one-line fixes unapplied; a human-only 15-minute step is the
sole blocker for a real nonprofit's email ops. The wrapper itself (review-gated,
worktree-based) is thoughtful. Fix: crontab install, the two one-liners,
liveness guard so this class can't recur.

**vkv-inventory** — *D+, same orphaning, plus a broken contract.* Its runs never
consume QUESTIONS.md answers — the one channel you're contractually promised is
severed at its endpoint. Fix: dispatch + `collect-feedback.sh --consume`.

**bibliothecaire / secretaire (inbox)** — *pending, one warning each.*
bibliothecaire: resolve the name collision before scaffolding. secretaire:
email credentials cross the autonomy bar — inventory and read-only utilities
first; the access-model fork is Zach's call in /ideate, not a nightly batch's.

---

## Propagation

`inject-suggestions.sh` (this folder) writes each project's relevant findings
as a dated `(fable-review)` section into its real FOCUS.md, honoring your own
protocol: busy-check first, append-only, small, one commit per repo, dry-run by
default. Review with `--diff`, apply with `--apply`, commit with `--commit`.
Nothing runs against a repo mid-dispatch; nothing is left dirty.

---

## Postscript — a finding that happened while writing this report

At 2026-07-25 02:00, while this folder was being written, the scheduler's sweep
autocommitted every in-progress `.md` file here as ~38 separate commits labeled
**"Human edit via scheduler"**. Two problems, live-demonstrated: (1) the label
is wrong — these were agent writes in an interactive session, so the provenance
record now lies; (2) the sweep commits *mid-session, half-written* working
files, which is exactly the "dirty tree is a stop" hazard pointed the other
direction — the engine edited history out from under a live session. Suggested
fix: the autocommit should skip a repo whose session lock / recent-mtime says
someone is actively working, and its label should say what it actually knows
("sweep autocommit: uncommitted changes found"), not guess "Human edit".
