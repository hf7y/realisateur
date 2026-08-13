# Stability milestones — realisateur's admission-control convention

This is realisateur's answer to **vision debt** (see `.scheduler/FOCUS.md`,
2026-07-23 vision-debt strategy entry). The honest number: idea intake via
`scheduler -i` is zero-cost and unbounded; clearing is quota-gated and
shared across ~12 projects. The backlog therefore diverges at −6 to −10
items/week *regardless of build speed*. You cannot out-build a free,
unbounded idea faucet.

The lever that changes the sign is **admission control, not throughput**:
move most arriving ideas *out of the active build set* at near-zero cost
(park them), instead of trying to build them all down. A stability
milestone is the criterion that makes "park by default" decidable.

## What a bar IS — the canonical definition (Zach, 2026-07-28)

Stated directly by Zach during a realisateur `/ideate` pass, and adopted
here as **the** definition rather than as one heuristic among several:

> **Real life output gathers real life input; the next milestone is
> recommended based on deep vision integrated with that input.**

Read it as three claims, each of which rules something out.

**1. The bar's output must reach real life.** Not a passing suite, not a
merged branch, not a deployed artifact nobody used. Something must happen
*outside the repo* — a purchase made earlier than it would have been,
nine speakers audible in a room, a stranger's order, a paste that didn't
mangle. A bar satisfiable entirely from inside the project is not a bar;
it is a proxy, and a proxy is precisely what stays green while the thing
it stands for fails. This is the same failure the ecosystem's whole
sensor layer exists to catch (see `PRECIPITATION.md`, and
`silence-audit`'s BLIND path) — a milestone is the *product-side*
instance of it.

**2. The purpose of real output is to GATHER REAL INPUT.** This is the
part that is easy to skip and is load-bearing. Shipping into the world is
not the end of the loop; it is the only way to acquire information that
did not previously exist anywhere in the project — how Zach actually
shops, how the room actually sounds, what a real customer actually wants,
which vim command he actually reaches for. No amount of unattended
iteration generates that input. It has to be *collected*, and only a
real-world output collects it. **A milestone is therefore an instrument,
not a finish line:** its job is to make the project learn something it
could not otherwise have known.

**3. The NEXT milestone is derived from that input, integrated with the
deep vision — not from either alone.** Two failure modes are being ruled
out at once. Setting the next bar from the vision alone reproduces the
moving-target problem (Zach, 2026-07-20: *"my ideas outpace
implementation of stable versions so the target is always moving"*) — the
project chases an idea that keeps reshaping because nothing real ever
constrains it. Setting it from the input alone is drift: pure
responsiveness, a project that becomes whatever its last data point
suggested. The recommendation comes from holding both — what was learned,
read against what this is ultimately for.

### What this implies in practice

- **Reaching a milestone should CHANGE the project's beliefs**, not merely
  complete a task list. If a bar could be reached without anyone learning
  anything, it was the wrong bar.
- **A human-witness criterion is not a concession to unmeasurability** —
  it is usually where the real input enters. Write it as a `(waiting:
  <human>)` checkbox deliberately, not apologetically.
- **A bar reachable entirely by unattended nightly work is suspect.** It
  probably measures the project's inside, not its outside.
- **Setting the next milestone is an `/ideate`-shaped act, not a
  nightly-batch one** — it needs the integration step in claim 3, which
  requires the human and the cross-project view.
- Where a bar is genuinely blocked from reaching real life (fences,
  hardware, credentials), say so and tag the blocked steps — do NOT
  substitute a proxy bar that can be reached. A blocked real bar is
  honest; a reachable fake one is the failure this definition names.

The four bars declared 2026-07-28 (`groc-mangr`, `nine-speakers`,
`sequestria`, `vim-arcade`) are the reference examples — each replaced a
researched, internally-satisfiable candidate with a real-world one. Read
them together if the definition above is unclear in the abstract.

**A citation request for the underlying idea has been filed with
`bibliothecaire`** (2026-07-28) — this definition is currently stated in
Zach's own words and grounded only in this ecosystem's own experience,
and it deserves primary-source footing.

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

**An issue labelled `milestone`** on the project's own tracker, one open
at a time. Its body carries the shape below.

The canonical home used to be a `## Stability milestone` section near the
top of each project's `FOCUS.md`. That surface was retired by
hf7y/scheduler#66 on 2026-08-07, which leaves `bin/milestone-audit.sh`
parsing a file that no longer exists in a migrated repo -- it reports
`no-focus` and reads as "no milestone declared" rather than "I am looking
in the wrong place". Flagged as hf7y/realisateur#229; the shape itself is
unchanged and still what the audit expects to parse:

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
- **The whole bar + status must be on ONE physical line** — `bin/
  milestone-audit.sh` finds it with `grep -m1`, so wrapping the bar text
  across multiple Markdown lines (even though it reads fine rendered)
  makes the line lack its own `status:` token and reports UNRECOGNIZED.
  Long bar text is fine; line breaks in it are not (hit and fixed
  2026-07-24 across gardien/senechal/wtul's first real milestones).
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

## Relationships

**Supersedes the incubation-audit "graduation-candidate" framing.**
`bin/incubation-audit.sh` scored projects `incubating|graduation-candidate`
to suggest a weight. That axis is subsumed: `status: in-progress` ==
incubating, `status: reached` == graduated. `bin/milestone-audit.sh` is the
canonical status signal; incubation-audit is legacy. Don't grow both.

**Reaped 2026-08-13, 49 lines.** Two sections went: a concurrent-rollout
risk register written while this convention was still settling (it is
settled), and a relationships block tying this vocabulary to the
`BLOCKERS.md` taxonomy and to `FOCUS.md` formatting compliance. Both of
those surfaces are retired, so both blocks were prose defending mechanisms
that no longer exist — `PROSE-REAPING.md` §1, third row. The one rule worth
keeping out of the rollout register is general, and is stated once here:
**never leave another project's repo dirty between edits.** A dirty tree is
a stop, not a thing to edit around.

## The mechanical check

`bin/milestone-audit.sh` (offline, no AI, dry-run) reports, per registered
project: whether a milestone is declared, its current bar + status, and a
`(parked)`-tag count as a rough active-vs-reservoir signal. Same stance as
`hygiene-lint.sh`/`ecosystem-survey.sh` — its findings are **signals, not
verdicts**. Run it at the top of every `/ideate` and `/nightly-batch` pass,
alongside the other two surveys.
