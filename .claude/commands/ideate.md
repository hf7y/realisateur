---
scope: user
description: Interactive cross-project vision/triage pass -- surface state across the whole ecosystem (or one project), ask direct design questions, record decisions, queue priority. Does not scaffold or build.
argument-hint: "[project-name]"
---

This is realisateur's interactive counterpart to `/nightly-batch`
(unattended, builds). Where nightly-batch scaffolds and implements,
`/ideate` triages, prioritizes, and records -- modeled directly on
`chezz/.claude/commands/ideate.md`, generalized here across every
scheduler-registered project instead of one. Default posture: surface,
ask, record, queue -- **not build, not scaffold**. Say so explicitly if
asked to do something this command is designed to defer -- "that's a
nightly-batch job, want me to queue it or just do it now?" is a fine
thing to say; silently building anyway is not.

**This posture holds for the rest of THIS conversation, not just the
first response.** `/ideate` is a one-shot slash command with no harness-
enforced "mode" -- nothing stops drift into build-mode on a later prompt
in the same session unless the model itself keeps holding the line. If a
follow-up prompt later in this same conversation asks for something
build-shaped, treat it the same as if it arrived in the first message:
name it explicitly ("that's a nightly-batch job...") rather than quietly
switching into building because enough turns have passed that the
original `/ideate` framing feels distant. This is a real limitation, not
fully solved by prose alone -- see `IDEATE-WORKFLOW-REVISION.md` at the
repo root for the open question about a harder, hook-based guarantee.

**Per-session tuning via `$ARGUMENTS`:** if invoked with a project name
(`/ideate crt`, `/ideate senechal`), scope this session to that one
project's vision/backlog -- read only its own FOCUS.md/QUESTIONS.md plus
its `scheduler status` output plus its FOCUS.md `## Stability milestone`,
skip the ecosystem-wide survey. If
invoked with no argument, run the full ecosystem sweep below. Either way
this is the same command, same file, same conventions -- only the scope
of step 1 changes.

## 1. Orient

**Ecosystem-wide (no argument):** run `bin/precipitation-scan.sh` (offline,
no AI cost) for promotion signals, and `scheduler status <project>` for any
project you are about to touch. `ecosystem-survey`,
`milestone-audit` and `steward-survey` were RETIRED 2026-08-07
as four re-implementations of one registry enumeration that nothing ran; each
project's stability milestone is read from its own FOCUS.md
`## Stability milestone` section, convention in `STABILITY-MILESTONES.md`.
(`hygiene-lint` ran here until it was retired: hf7y/realisateur#265.)

**Single-project (`$ARGUMENTS` given):** run
`"/home/zach/Documents/Projects/scheduler/bin/scheduler" status <project>`
directly instead of the full survey -- same offline-first data, scoped
to just that project. Read that project's own FOCUS.md and
QUESTIONS.md in full -- `.scheduler/` for migrated projects, legacy
`.claude/` otherwise; the scheduler's `focus/<project>.md`
and `questions/<project>.md` symlinks resolve this, or derive the real
path from `schedule/<project>.conf`'s `PROJECT_REPO_PATH` +
`SCHEDULER_SUBDIR`).

Either way: don't trust a prior session's own claims about status --
this step's whole point is starting from what the survey/status actually
found, not a stale mental model.

## 2. Find what's actually worth surfacing

Not everything the survey turns up needs a question. Sort into:
- **Urgent, small, low-ambiguity** (a stranded commit, a bare-remote
  permission issue, an expired scheduler registration) -- flag clearly,
  propose the fix, don't implement unless told to.
- **Real design forks** -- multiple plausible directions for one idea,
  or a genuinely open fork already flagged in some project's own
  `QUESTIONS.md`/`FOCUS.md` (the "design fork, needs a proposal" pattern
  gardien/senechal already use). These are what `AskUserQuestion` is for.
  Ground each question in what the survey/status actually showed, not
  vibes -- cite the project, the dated entry, how long it's sat open.
- **Already-settled** -- matches a standing decision already in some
  project's own FOCUS.md. Don't re-litigate; note it's unchanged.
- **Synchronicities** (ecosystem-wide sessions only) -- two or more
  projects' "next up"/backlog entries pointing at overlapping ground
  (same feature shape, same underlying mechanism, same blocked
  dependency). Flag these as a distinct category -- they're the
  highest-leverage kind of finding this command can produce, since no
  single project's own nightly-batch has the cross-project view to
  notice them.

## 3. Ask, don't guess

For genuine forks or synchronicities, ask directly (`AskUserQuestion`, up
to 4 per call, options with real tradeoffs grounded in what was actually
found). Don't scaffold or implement speculatively while waiting.

## 4. Record and queue, don't build

**Park-by-default triage (do this for every idea before recording it).**
Against the target project's *current* stability milestone (its open
`milestone`-labelled issue), judge each idea: is it required to reach that
milestone? If **yes** it's `active`; if **no**, tag it `(parked)` (or
`(waiting: <dep>)` if it's blocked externally, not by choice) and record
one line of why it's past the bar. Parking is the default for anything
beyond the current milestone -- see `STABILITY-MILESTONES.md`. The metric
that matters is the *active*-set draining, not the parked reservoir
shrinking (a free-fed reservoir is supposed to grow). Promoting a parked
idea into the active set is a deliberate, stated decision, same as the
oldest-first override in §4.5 -- never a silent reorder.

**Standard entry shape -- vision, then milestones, then blockers.**
Zach's repeated ask (2026-07-24, `revise-the-ideate-workflow-*.idea` --
see `IDEATE-WORKFLOW-REVISION.md` at the repo root for the full context)
is that this structure should be `/ideate`'s own default, not something
restated by hand each session. When a session records a real direction
(not just a one-line decision), shape the issue as:
1. **Vision** -- the actual goal in plain terms, and how much of it is
   decided vs. still explicitly open (name what's NOT decided yet, don't
   let silence imply it is).
2. **Milestone chain** -- numbered, working backward from the vision:
   current step (in-progress), next step (not yet started), later steps
   (undecided), and anything explicitly not queued yet. Each step should
   be concrete enough that "is this idea required for the current step"
   is answerable -- that's what park-by-default triage above actually
   needs.
3. **Blockers** -- anything blocking the CURRENT milestone step
   specifically, tagged by who can clear it (human-only step vs.
   buildable-now), not a generic backlog dump.


For each decision, the destination is a command, never a file:

- **About realisateur's own scope** — file an issue on `hf7y/realisateur`
  carrying the decision and its rationale.
- **About machine-wide config** (crontab, `~/.claude` settings hooks,
  systemd, autostart, WM config, markers under `~/.local/share`) — run
  `notify-senechal '<what, where, who owns it>'`. Standing rule:
  realisateur owns what it generates, senechal owns knowing it exists. It
  files a labelled issue on `hf7y/senechal` with `gh` and reads it back to
  confirm it landed, so it needs no clone of that repo and no push access
  to it — and therefore no busy-deferral either.
- **About another project** — file an issue on **that project's** tracker,
  labelled `from:realisateur` so it reads as ecosystem-informed rather than
  that project's own agent noticing something locally. The provenance label
  is a sensor, not decoration: every actor in this estate is `hf7y`, so
  authorship cannot answer "did a human ask for this, or did an agent find
  it", and an unlabelled issue errors toward dispatching more.

  `check-project-busy <project>` gates DIRECT writes into another repo's
  files. Filing an issue is a front door and carries its own regulator, so
  it does not need the check.

## 4.5. Vision debt -- watch it, and know when to override oldest-first

**The signal ladder is now formalized in `PRECIPITATION.md` and sensed by
`bin/precipitation-scan.sh`.** Read
its three reports during orient, before triaging. In short: age is the
WEAKEST of five signals; re-arrival-in-the-same-shape is the strongest;
an idea that re-arrives in a DIFFERENT shape each time gets its weight
lowered, not raised; and a cross-project cluster is answered by naming
the missing regulator, not by promoting the cluster's members. Confirming
a candidate means stamping it (`(re-arrival: <dates>)` / `[iface: <x>]`)
so the judgment becomes durable fact instead of being re-inferred next
run. The rest of this section is the standing rule that ladder serves.

Same pattern chezz's `/ideate` named originally (2026-07-20, your own
words: *"my ideas outpace implementation of stable versions so the
target is always moving"*): a backlog that only grows is not this
command failing, it's the expected shape of the problem. What would be a
failure is letting the gap stay invisible -- `precipitation-scan.sh`'s
oldest-first ranking exists exactly so it can't hide.

**But oldest-first is a signal, not a rule realisateur is bound by.**
Realisateur's whole value here is the cross-project view a single
project's own nightly-batch doesn't have -- which means it's also the
one position positioned to correctly judge when a NEWER idea deserves to
jump ahead of an older parked one: it unblocks something currently
active, it synchronizes with a direction another project is already
moving in, or the older item has aged specifically because it turned out
to be a bigger/vaguer dream rather than a near-term build (see "stable
build vs. bigger dream" below). When overriding oldest-first, **say so
explicitly** -- which older item got passed over and why -- in the
project's own FOCUS.md entry or weight-change rationale, not just in this
session's chat output. A silent reorder is indistinguishable from
forgetting the older item existed; a stated one is a real prioritization
decision future sessions can trust.

## 4.6. Stable build vs. bigger dream -- the distinction that drives pacing

When triaging any idea (a fresh inbox drop nightly-batch would otherwise
scaffold, or an existing backlog entry), explicitly judge which of these
it is:
- **Close to a working, stable core** -- the project (or this specific
  idea within it) has a defined, near-term shape; building it now is
  unlikely to be discarded by the idea itself changing shape later. Fine
  to leave at normal/higher priority weight, fine for nightly-batch to
  keep iterating on it unattended.
- **Part of a bigger, still-forming dream** -- the idea is more likely to
  morph substantially before anything built against its current shape
  would survive (sequestria's brand direction, nine-speakers' physical
  rig, senechal's "keeper of names and places" half are current examples
  already flagged this way in their own FOCUS.md/QUESTIONS.md). Lower
  priority weight is the right lever, not "don't build at all" --
  slower-paced iteration is exactly what avoids sinking dev cycles into
  something that gets discarded once the vision itself settles.

This judgment is what the weight field in `_paced.conf` is FOR --
recording it there (with rationale) is how this distinction actually
changes what gets built when, not just how it's talked about.

## 5. Cross-project proposals about scheduler ITSELF go through the front door

If something learned here is really about `scheduler`'s own engine (a
new mechanical knob it should support, an engine bug, a template other
projects should get) -- propose it via `scheduler -i scheduler "<the
proposal>"`, same as any other project would. Don't hand-edit scheduler's
engine code directly from an ideate session (it may have concurrent work
in flight, and realisateur isn't scheduler's owner) -- this is distinct
from step 4's per-project FOCUS.md/QUESTIONS.md cross-writes and the
`_paced.conf` weight field, both of which ARE realisateur's to touch
directly.

## 6. Commit, push, and stop

Commit realisateur's own code and doc changes here; findings and decisions
went to issues in §4 and need no commit. Push everything pushable; note
anything that couldn't push rather than
silently leaving it unmentioned. End with a short summary: what's now
queued and where, any weight changes made and why, current ecosystem-wide
vision-debt state (oldest open item, whether it grew or drained since
last check), and explicitly confirm no project was scaffolded and no
feature code was written (or, if the user asked for an inline exception,
name it and confirm it's separate from the queue).
