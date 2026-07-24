# Stability milestones — realisateur's admission-control convention

This is realisateur's answer to **vision debt** (see `.claude/FOCUS.md`,
2026-07-23 vision-debt strategy entry). The honest number: idea intake via
`scheduler -i` is zero-cost and unbounded; clearing is quota-gated and
shared across ~12 projects. The backlog therefore diverges at −6 to −10
items/week *regardless of build speed*. You cannot out-build a free,
unbounded idea faucet.

The lever that changes the sign is **admission control, not throughput**:
move most arriving ideas *out of the active build set* at near-zero cost
(park them), instead of trying to build them all down. A stability
milestone is the criterion that makes "park by default" decidable.

## The core idea

Every project has exactly **one current stability milestone**: the
smallest coherent "stable v1 core" bar which, once true, means the project
does its core job reliably and can be left to iterate slowly. It is a WIP
limit expressed as a goal:

- An idea **required to reach the current milestone** is `active` — fine to
  build now, fine for nightly-batch to iterate on unattended.
- An idea **beyond the current milestone** is `parked` by default — kept
  visible in the reservoir, but NOT built now. It is revisited when the
  milestone is reached (and a new one is set) or when the user explicitly
  promotes it.

Parking is the load-bearing act, not building.

## The status vocabulary

Three states, one shared vocabulary (this is the same vocabulary the
BLOCKERS.md taxonomy needs — see "Relationships" below; unify, don't build
twice):

- **`active`** — needed to reach the current milestone. Counts toward the
  active set, which should stay small.
- **`parked`** — a real idea, past the current milestone. Part of the
  reservoir, *not debt*. A growing parked reservoir is the expected shape
  of a healthy idea pipeline, not a failure.
- **`waiting`** — blocked on something external (hardware arriving, a human
  decision, another project). Not actionable now; not the same as parked
  (parked is a *choice*, waiting is a *dependency*).

Tag ideas inline in `FOCUS.md`/`QUESTIONS.md` the same way entries are
already tagged `(nightly-batch)`/`(realisateur)`: e.g.
`- **2026-07-20 (parked):** …` or `- **2026-07-22 (waiting: DAC arrives Tue):** …`.
An untagged dated idea is treated as `active` — so the *default* for
anything you decide to keep-but-not-build-now is an explicit `(parked)`
tag.

## What to measure (and what not to)

- **Track (1): active-set size per project.** Keep it small. A long active
  list is the real debt — it's WIP you've implicitly committed to.
- **Track (2): is the oldest `active` item draining?** Vision debt is
  visible here: active items that never move.
- **Do NOT track backlog/parked count as debt.** A reservoir fed for free
  is supposed to grow (settled: chezz `/ideate` 2026-07-20). Counting it as
  debt is what makes the problem look unsolvable when it isn't.

## Where a milestone lives — the canonical format

A `## Stability milestone` section near the top of each project's
`.claude/FOCUS.md`. Required shape (so `bin/milestone-audit.sh` can parse
it offline):

```
## Stability milestone
**Current:** <one-line "stable v1 core" bar> — status: not-started | in-progress | reached
Done when:
- [ ] <criterion>
- [ ] <criterion>
Ideas beyond this bar are PARKED by default (see realisateur/STABILITY-MILESTONES.md).
```

- The `**Current:**` line MUST end with `status: not-started`,
  `status: in-progress`, or `status: reached` — that token is what the
  audit reads.
- `Done when:` is a checklist of the concrete, checkable criteria. When
  every box is checked, the status is `reached`.

## The park-by-default triage rule

When triaging any idea — a fresh `scheduler -i`/inbox drop, or an existing
backlog bullet — realisateur (`/ideate` interactively, `/nightly-batch`
unattended) asks one question first:

> Is this idea required to reach the project's **current** stability
> milestone?

- **Yes →** it's `active`; proceed as normal (build it in a nightly pass,
  or queue it in the active set).
- **No →** **park it by default**: tag it `(parked)`, leave it visible in
  the reservoir, and do NOT build it now. State one line of why it's past
  the milestone. Promoting a parked idea into the active set is always a
  deliberate, stated decision (never a silent reorder) — same rule as the
  oldest-first override in `ideate.md` §4.5.

Parking is not "don't build, ever." It's "build later, at the deliberate
pace a still-forming or post-v1 idea deserves" — the same distinction as
the `_paced.conf` weight lever (`docs/priority-weight.md`).

## Lifecycle: what happens when a milestone is `reached`

When every `Done when:` box is checked, the project has a stable core. Do
one of two things — explicitly:

1. **Set a new milestone.** Promote the parked ideas that belong in the
   next coherent bar into the new active set; the rest stay parked. This is
   the deliberate re-admission step.
2. **Graduate to slow iteration / maintenance.** The project needs no
   near-term milestone; drop its `_paced.conf` weight and let it iterate
   slowly on parked ideas as slack allows. (This is the concrete meaning of
   the recovered-backlog "ready to go on its own" / viable-systems idea, and
   the natural home for the senescence/retirement idea in the same bullet.)

## Rolling this out while the ecosystem runs concurrently

Other projects' nightly-batch loops run concurrently with realisateur's,
and realisateur cross-writes into their files. Git makes this safe for
*correctness and recoverability* — nothing is unrecoverable. The residual
risks are narrower, and each has a mitigation that fits the existing model:

- **(a) Concurrent edits to shared files realisateur touches.** Keep every
  cross-write **small and committed immediately** — never leave another
  project's repo dirty between edits (a half-written FOCUS.md is what races
  a concurrent nightly run). This is the same lesson that skipped `crt`
  during the 2026-07-23 checklist backfill: a dirty tree is a stop, not a
  thing to edit around.
- **(b) Projects running against a convention that's changing under them.**
  While the bootstrap is live and this convention is still settling, treat
  changes to it as **versioned and backward-compatible**: a project's
  existing `## Stability milestone` section must keep parsing even as the
  convention grows. Add fields, don't repurpose the `status:` token or the
  section heading. `milestone-audit.sh` degrading gracefully (no-focus /
  missing / UNRECOGNIZED rather than crashing) is part of this contract.
- **(c) Slower iteration from the weight skim.** Accepted residual cost of
  the weight-3 bootstrap — bounded by the stated exit condition in
  `_paced.conf`, not open-ended.
- **(d) Catching (a)/(b) before they bite.** Lean on `hygiene-lint.sh`'s
  stranded-commit / dirty-tree checks — they already flag exactly the
  divergence a raced cross-write would produce. Running the three surveys
  at the top of every pass is what surfaces it early.

## Relationships (name what this supersedes / connects to)

- **Supersedes the incubation-audit "graduation-candidate" framing.**
  `bin/incubation-audit.sh` scored projects `incubating|graduation-candidate`
  to suggest a weight. That axis is now subsumed: `status: in-progress` ==
  incubating, `status: reached` == graduated. **`bin/milestone-audit.sh` is
  the canonical status signal going forward**; incubation-audit is legacy
  (kept for its reproducible weight-suggestion pass, not re-wired into
  nightly-batch). Don't grow both.
- **Shares the status vocabulary the BLOCKERS.md taxonomy needs.** The
  `active`/`parked`/`waiting` split is the same distinction the parked
  `Spec-out-a-more-principled-eco` idea wants for BLOCKERS.md
  (`blocking`/`waiting`/`fyi`). One vocabulary should serve both — routed to
  scheduler via `scheduler -i scheduler` on 2026-07-23. When scheduler
  builds the glance/status taxonomy, this is the vision-item half of it.
- **Depends lightly on FOCUS.md having parseable structure.** The open
  `FOCUS-md-formatting-compliance` idea (chezz has no bulleted section,
  wtul has no FOCUS.md at all) means the audit will report `no-focus` /
  `no-milestone` for those until they're reformatted. That's a signal, not
  a blocker — the audit degrades gracefully.

## The mechanical check

`bin/milestone-audit.sh` (offline, no AI, dry-run) reports, per registered
project: whether a milestone is declared, its current bar + status, and a
`(parked)`-tag count as a rough active-vs-reservoir signal. Same stance as
`hygiene-lint.sh`/`ecosystem-survey.sh` — its findings are **signals, not
verdicts**. Run it at the top of every `/ideate` and `/nightly-batch` pass,
alongside the other two surveys.
