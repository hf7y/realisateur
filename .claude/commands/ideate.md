---
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

**Per-session tuning via `$ARGUMENTS`:** if invoked with a project name
(`/ideate crt`, `/ideate senechal`), scope this session to that one
project's vision/backlog -- read only its own FOCUS.md/QUESTIONS.md plus
its `scheduler status` output plus `bin/milestone-audit.sh <project>`,
skip the ecosystem-wide survey. If
invoked with no argument, run the full ecosystem sweep below. Either way
this is the same command, same file, same conventions -- only the scope
of step 1 changes.

## 1. Orient

**Ecosystem-wide (no argument):** run `bin/ecosystem-survey.sh` (offline,
no AI, ~2s) -- per-project git health/open-questions/last-run outcome,
plus the ranked "oldest still-open dated idea per project" vision-debt
signal. **Then run `bin/milestone-audit.sh`** (offline) -- each project's
current stability milestone + status + reservoir signal; this is what
makes step 4's park-by-default triage decidable (you can't judge `active`
vs `parked` without the current bar in front of you). See
`STABILITY-MILESTONES.md`. Also read this repo's own
`.claude/FOCUS.md`/`QUESTIONS.md`.

**Single-project (`$ARGUMENTS` given):** run
`"/home/zach/Documents/Project Archive/scheduler/bin/scheduler" status <project>`
directly instead of the full survey -- same offline-first data, scoped
to just that project. Read that project's own `.claude/FOCUS.md` and
`.claude/QUESTIONS.md` in full (via the scheduler's `focus/<project>.md`
and `questions/<project>.md` symlinks, or the real path from
`schedule/<project>.conf`'s `PROJECT_REPO_PATH`).

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
Against the target project's *current* stability milestone (from
`milestone-audit.sh`), judge each idea: is it required to reach that
milestone? If **yes** it's `active`; if **no**, tag it `(parked)` (or
`(waiting: <dep>)` if it's blocked externally, not by choice) and record
one line of why it's past the bar. Parking is the default for anything
beyond the current milestone -- see `STABILITY-MILESTONES.md`. The metric
that matters is the *active*-set draining, not the parked reservoir
shrinking (a free-fed reservoir is supposed to grow). Promoting a parked
idea into the active set is a deliberate, stated decision, same as the
oldest-first override in §4.5 -- never a silent reorder.

For each decision:
- **About realisateur's own scope** -- write into this repo's own
  `.claude/FOCUS.md` (decision + rationale) same as any other project.
- **About another project** -- first run `bin/check-project-busy.sh
  <project>` (offline, ~instant -- flock-probes that project's own
  scheduler job locks). If it reports `BUSY: <job-name>`, that project's
  own automation is mid-run against the same files RIGHT NOW -- **defer
  the cross-write** (note the decision in this session's chat/report
  instead, cross-write next session) rather than risk editing FOCUS.md/
  QUESTIONS.md out from under a live nightly-batch/bug-sweep pass. This is
  realisateur's own half of the 2026-07-24 concurrency finding (see
  FOCUS.md) -- scheduler owns making dispatch/push itself robust;
  detecting "don't step on a live run" before cross-writing is
  realisateur's job specifically because it's the one thing reaching into
  other projects' files from outside their own automation.
  If free, write directly into THAT project's own
  `.claude/FOCUS.md`/`.claude/QUESTIONS.md` (realisateur owns this
  cross-write relationship, unlike chezz's `/ideate`, which must go
  through scheduler's `-i` front door for anything outside itself).
  Tag the entry so it reads as ecosystem-informed rather than the
  project's own agent noticing something locally -- prefix with
  `(realisateur)` the same way entries are already tagged
  `(nightly-batch)`/`(bug-sweep)`/`(via scheduler -i)`, e.g.
  `- **YYYY-MM-DD (realisateur):** <text>`. If a mirror/summary is worth
  keeping in realisateur's own `QUESTIONS.md` too (so the ecosystem-wide
  view doesn't require opening every project), add a short cross-link
  there pointing at the real entry -- don't duplicate the full text in
  both places.
  - **`aedile`/`vkv-inventory` note (revised 2026-07-24, via `/ideate`;
    supersedes the same-day front-door-only carve-out).** Both run under
    `svc-vaporwave` for dispatch, but their real vision docs are
    git-tracked in each project's own GitHub remote regardless of
    whether zach@mandark's interactive working copy exists --
    confirmed for aedile: `aedile/.scheduler/FOCUS.md`/`QUESTIONS.md`
    (not `.claude/`, deliberately gitignored in the shared `wavebucks`
    monorepo since it's co-owned with Tyler's unrelated projects -- see
    [[wavebucks_org_structure]]) are tracked and pushed normally. So the
    mandark-copy-closing concern doesn't actually block a direct
    cross-write: clone `git@github.com:media-arts-collective/wavebucks.git`
    (or `inventory-app.git` for vkv-inventory, which just uses plain
    `.claude/` -- it's its own dedicated repo, no shared-collaborator
    concern at all) fresh with zach's own existing GitHub access if
    mandark's copy is gone, write/commit/push the same as any other
    registered project's direct-cross-write privilege above. **The
    `scheduler -i <project>` front door stays available as a documented
    fallback** (e.g. if you'd rather realisateur never hold push access
    to a shared repo at all) -- but it's an option, not the default, for
    these two.
- **Priority weight** -- if this session's findings justify it, edit
  `schedule/_paced.conf`'s weight field for the affected project(s)
  directly (see `docs/priority-weight.md` in the scheduler repo). This
  is scheduler's own file, but the weight field itself is explicitly
  realisateur's to set -- that's not covered by the "go through the
  front door" rule below, which is about scheduler's *engine* logic, not
  this specific per-project knob.

## 4.5. Vision debt -- watch it, and know when to override oldest-first

Same pattern chezz's `/ideate` named originally (2026-07-20, your own
words: *"my ideas outpace implementation of stable versions so the
target is always moving"*): a backlog that only grows is not this
command failing, it's the expected shape of the problem. What would be a
failure is letting the gap stay invisible -- `bin/ecosystem-survey.sh`'s
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

Commit realisateur's own `.claude/FOCUS.md`/`QUESTIONS.md` changes here;
commit each touched project's own FOCUS.md/QUESTIONS.md changes in THAT
project's repo (separate commits, separate repos -- don't bundle). Push
everything pushable; note anything that couldn't push (e.g. the
bare-remote permission issue some repos hit 2026-07-22) rather than
silently leaving it unmentioned. End with a short summary: what's now
queued and where, any weight changes made and why, current ecosystem-wide
vision-debt state (oldest open item, whether it grew or drained since
last check), and explicitly confirm no project was scaffolded and no
feature code was written (or, if the user asked for an inline exception,
name it and confirm it's separate from the queue).
