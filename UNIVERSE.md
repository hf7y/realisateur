# UNIVERSE.md — what this organism is and how it metabolizes

*(2026-07-25, human-directed `/ideate` session. Sibling doctrine to
`STABILITY-MILESTONES.md` and `BUILD-DISCIPLINE.md`. Those govern one
project's bar and one build's hygiene; this governs the whole ecosystem's
shape. Prompted by Zach's own framing: "What is this organism and how
does it want to metabolize or grow?" — asked while filing, in a single
breath, a feature request, a bug report, a rewrite, and philosophy about
the scheduler front door. That simultaneity is data, not noise; see the
corollary under Law 1.)*

## The anatomy

A single-user machine ecosystem is one organism, not a workplace.

- **Zach** — the only decider. Simultaneously the organism's environment
  (the source of all disturbance: new ideas, moved targets) and its
  scarcest organ (the rate-limiting enzyme — every `> ` reply, every
  blocker, every judgment call passes through one person's attention).
- **scheduler** — metabolism. Turns quota into cycles, cycles into
  commits. Pure mechanism by standing doctrine (2026-07-22): it enforces
  weights, it never sets them.
- **realisateur** — perception and judgment. Senses (the offline
  surveys), triages (park-by-default), records. It never decides; the
  human decides.
- **The projects** — organs. Each with its own stability-milestone bar
  and its own parked reservoir.
- **git + FOCUS/QUESTIONS files** — tissue and chemical signaling.
  Every friction incident in the accumulated dialog residue (stranded
  commits, merge conflicts, stale clones, layered rewrites) happened in
  this tissue, at an interface between writers.

## The three laws

Each law is only real to the extent it is paired with a mechanism.
Prose decays; enforcement doesn't (this file's own doctrine).

### Law 1 — Admission control (established 2026-07-23)

Intake is free (`scheduler -i`), building is quota-gated and shared,
so the backlog diverges regardless of build speed. Weight bumps slow
divergence; only pruning changes its sign.

**Enforced by:** park-by-default triage against each project's current
milestone (`/ideate` §4, `/nightly-batch`), `bin/milestone-audit.sh`.

**Corollary — the four-streams intake is the system working.** A human
prompt that is simultaneously bug report, feature request, rewrite, and
philosophy is full-spectrum sensing, not indiscipline to serialize.
The system's job is to route the streams (bug → fix now, feature →
reservoir, rewrite → convergence test below, philosophy → this file),
never to ask the human to pre-sort them.

### Law 2 — The reservoir is not debt (established 2026-07-20/23)

A free-fed reservoir is supposed to grow. Debt is only parked ideas
masquerading as active commitments. The health metrics are the active
set's size and whether its oldest item drains — never the reservoir's
size.

**Enforced by:** active/parked/waiting tagging, `bin/ecosystem-survey.sh`
oldest-open ranking, the reservoir-signal line in `milestone-audit.sh`.

### Law 3 — Retirement pressure (named 2026-07-25; the previously missing one)

The ecosystem regulates its backlog but not its surfaces. Adding a
legend line, a verb, a view is free in the moment; removing one never
happens on its own, because no session is ever *about* removing one.
So surfaces only ratchet up. The 2026-07-25 exhibit: scheduler's front
door — 1,968 lines, ~20 verbs, five overlapping "show me things" views,
a 118-line `usage()`, a 12-line legend before the first row of data —
every addition individually justified in some session's residue, nothing
ever retired. That bloat is not a discipline failure; it is the **cost
signature of Law 1 working**: when a redesign is parked, need leaks out
as accretion onto whatever surface already exists. An organism that only
anabolizes is a tumor. Catabolism must be a first-class pathway, not a
checklist afterthought.

**Enforced by (today):** only BUILD-DISCIPLINE's "new mechanism names
what it retires" row — which has never been applied to output text or
command surface. **Queued, not built:** the catabolic pass (below), and
the scheduler front-door consolidation as this law's first real proof.

## The cybernetic reading (Ashby)

Every *persistent* friction in the residue marks an interface where
disturbance variety exceeds regulator variety. Where a regulator got
built — `usage-gate.sh` for quota, park-by-default for intake,
`push reason:` diagnostics for silent push failures — friction at that
interface dropped and stayed dropped. As of 2026-07-25 two interfaces
still lack their regulator: **multi-writer FOCUS/QUESTIONS files**
(named open question, not solved here) and **the tool surface** (Law 3,
regulator now queued). When new friction recurs somewhere, ask "what
regulator is missing at this interface," not "who slipped."

## The moving target: instrument it, don't fight it

Zach's standing condition (2026-07-20, his own words): *"my ideas
outpace implementation of stable versions so the target is always
moving."* The question posed 2026-07-25: should good practices try to
work around that, or is it the truth of the ecosystem?

It is the truth, and the practices here already do something better
than working around it — it just had no name until now:

**Re-derivation convergence is the crystallization test.** You cannot
dam the stream (freeze the vision), and rigid roadmaps just pretend it
isn't moving. But when the same idea re-arrives independently in the
same shape, the target has stopped moving *there*. Proof case: the
scheduler three-view front door, designed 2026-07-20 (scheduler FOCUS.md
item 0, parked), re-derived by Zach near line-for-line on 2026-07-25
with no memory of the parked mockup in front of him. Re-arrival in the
same shape is a stronger "ready to build" signal than age (oldest-first),
enthusiasm (newest-first), or any self-report of certainty. It converts
the moving target from a failure mode into the organism's own sensing
apparatus: **ideas circulate as residue until they precipitate, and
re-arrival is the precipitation.** Conversely, an idea that returns in a
*different* shape each time is still dissolving — that is exactly the
"bigger, still-forming dream" case already handled by low `_paced.conf`
weight (§4.6 of `/ideate`).

The Daoist stance follows: practices are banks, not dams. Their job is
to lower the cost of change flowing through, and to notice where the
water keeps returning. For interfaces specifically, Laozi 11: thirty
spokes share one hub — it is the emptiness that makes the wheel useful.
A glance screen's value is in what it omits.

**Enforced by (today):** nothing — this session applied the test by
hand. **Queued, not built:** the re-arrival sensor (below).

## The three timescales (a universe-wide channel rule)

The organism runs on three timescales, and every human-facing surface
must keep them in separate channels, never blended:

1. **Operations** — what is metabolizing now/next, and the dials that
   pace it.
2. **Obligation** — what is blocked on the one decider. In VSM terms,
   the algedonic channel: short, loud, unmixed with anything else,
   because the human is the scarcest organ.
3. **Identity** — vision, milestones, per-project detail and reply.

The scheduler front-door redesign (`scheduler` / `scheduler blockers` /
`scheduler <project>`) is the first surface rebuilt on this rule. Any
future interface — reports, dashboards, dexter-side tooling — inherits
it: if a screen mixes obligation into operations, the human has to scan
everything to find what actually needs them.

## Queued, not built (this file names its own gaps)

- **Catabolic pass** (Law 3's recurring enforcement) — a retirement
  discipline, e.g. every Nth `/ideate` names one surface to shrink,
  generalizing "names what it retires" from mechanisms to text and
  verbs. Shape open. Tracked in realisateur `.claude/FOCUS.md`
  2026-07-25.
- **Re-arrival sensor** (the convergence test's enforcement) — on
  intake/triage, check the reservoir for a prior same-shape entry; a
  convergence hit is a stated promotion trigger, stronger than
  oldest-first. Candidate shape: an offline `bin/` sense like the
  existing surveys. Shape open. Tracked in the same FOCUS.md entry.
- **Multi-writer FOCUS-file regulator** — the other interface Ashby's
  reading flags as unregulated (the 2026-07-25 mega-burn test's one real
  collision was exactly this). Second exhibit 2026-07-26: the scheduler
  autocommit watcher adopted a live session's uncommitted FOCUS.md edits
  under a human's name while origin moved twice underneath the same
  session. Regulator now queued (realisateur `.claude/FOCUS.md`
  2026-07-26 race entry): honest attribution + live-session probe on
  scheduler's watcher half (via the front door), an atomic
  `focus-commit.sh` edit-commit-push helper with post-rebase content
  verification on realisateur's half.
