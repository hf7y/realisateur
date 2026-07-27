# PRECIPITATION.md — how an idea earns promotion

*(2026-07-26, human-directed `/ideate` session, Zach's framing: "formalize
the re-ordering of vision based on strategies developed in UNIVERSE.md…
if a request hits an inbox multiple times, how can it get boosted up? is
there a way to score adjacent features to see that there's a cluster
emerging?" Sibling doctrine to `UNIVERSE.md` (what the organism is),
`STABILITY-MILESTONES.md` (when a project is solid) and
`BUILD-DISCIPLINE.md` (when a build is done). Those three answer "what,
when, done." This one answers **"why this one, now."**)*

Enforced by `bin/precipitation-scan.sh`. Doctrine without a mechanism
decays — UNIVERSE.md's own rule, and this file was written with its
mechanism, not before it.

## The problem this replaces

Until now the ecosystem had exactly one queue signal — **oldest-first**,
ranked by `bin/ecosystem-survey.sh` — plus a licence to override it
(`/ideate` §4.5) with no stated basis for when. UNIVERSE.md had already
demoted oldest-first in principle without giving it a successor:

> Re-arrival in the same shape is a stronger "ready to build" signal than
> age (oldest-first), enthusiasm (newest-first), or any self-report of
> certainty.

So the override was doing the real work while the ranking got the
mechanism. This file names the full signal set and gives each one a
sense, a stamp, and a stated consequence.

## Not a score. A ladder.

There is deliberately **no composite priority number**. A computed score
that reorders the queue is precisely the silent reorder `/ideate` §4.5
forbids — indistinguishable from forgetting the older item existed, and
it would quietly move weight-setting from the human to a formula.
Scheduler enforces weights and never sets them; realisateur senses and
never decides. A number would break both.

Instead: **signals are ranked, each authorizes a stated action, and
every promotion is written down.** Ties are broken by the human.

## The five signals, strongest first

### 1. Re-arrival — the same idea returns in the same shape

The crystallization test (UNIVERSE.md). An idea that re-arrives
independently in the same shape has stopped moving *there*, and is ready
to build regardless of its age.

**Repetition alone is not the signal — repetition × shape stability is.**
This is the sharp edge of Zach's "hits the inbox multiple times"
question, and the answer is not simply yes:

- Same shape, again → **promote.** Strongest signal in the ecosystem.
- **Different shape each time → the opposite: lower the weight.** A
  returning-but-morphing idea is a still-forming dream (`/ideate` §4.6),
  and building against this week's shape wastes the cycles. Frequency
  here measures *agitation*, not readiness.

A naive "boost on repeat" rule would invert the doctrine on exactly the
ideas it matters most for. Shape is the discriminator; a human or session
reads the pair and judges it. No script can.

**Sensed by:** report B (`precipitation-scan.sh`), same-project pairs
ranked by shared informative vocabulary.
**Stamped as:** `(re-arrival: 2026-07-20, 2026-07-25)` on the entry.
**Authorizes:** promotion past older items, stated per §4.5.

### 2. Cluster — different ideas converge on one interface

Several *distinct* asks, across *different* projects, landing on the same
place. Per UNIVERSE.md's Ashby reading, that is the signature of an
interface whose disturbance variety exceeds its regulator variety.

**A cluster's output is not a reordering — it is a new entry.** Do not
promote the members. Name the missing regulator they are all leaking
around, file it as one item that subsumes them, and mark the members
`subsumed by [[<regulator>]]`. Promoting the members individually treats
N symptoms and leaves the interface unregulated, which is how they got
there in the first place.

This is not a new procedure so much as a mechanized one: the multi-writer
FOCUS-file regulator was found exactly this way by hand — three separate
friction incidents (a mega-burn collision, the autocommit watcher
misattribution, a stale-clone divergence), one unnamed cause. The scan
now surfaces that shape before three incidents accumulate.

Ask **"what regulator is missing at this interface"** — never "who
slipped."

**Sensed by:** report C, cross-project stars.
**Stamped as:** `[iface: <name>]` on each member.
**Authorizes:** filing a new regulator entry, and weight for it.

### 3. Active-set unblock

The idea unblocks something currently metabolizing, or synchronizes with
a direction another project is already moving in. Realisateur's standing
cross-project justification, unchanged from `/ideate` §4.5.

**Sensed by:** no mechanism (human/session judgment from the surveys).
**Authorizes:** promotion, stated.

### 4. Milestone-gate

The idea is required by the project's current stability milestone. This
is the park-by-default triage already in force — not really a promotion
signal so much as the gate everything else has to argue past.

**Sensed by:** `bin/milestone-audit.sh`.

### 5. Age — oldest-first

The weakest signal, and explicitly a *floor*, not a ranking: its job is
to make sure nothing rots invisibly, not to decide what gets built. It
retains one privilege the others don't have — it is the only signal that
speaks for an item nobody is currently excited about.

**Sensed by:** `bin/ecosystem-survey.sh`.

## The counter-signal: shape drift

Named explicitly so it can't be quietly skipped. An entry that re-arrives
in a *different* shape each time gets its weight **lowered**, with the
drift stated. This is the catabolic half of signal 1, and without it
"re-arrival" degenerates into "whatever Zach mentioned most recently,"
which is newest-first wearing a lab coat.

## Stamping — why inference must become fact

Reports B and C are inference over prose. They are noisy by construction
and will stay noisy.

The fix is not a better algorithm, it is **accretion**: when a session
confirms a candidate, it writes the finding into the file — a
`(re-arrival: <dates>)` stamp or an `[iface: <name>]` tag. Report A then
reads those back as *fact*, needing no inference at all.

Unstamped, every judgment is re-derived from scratch next run and lost.
Stamped, precision accumulates exactly on the entries that mattered, and
nothing is demanded at intake time — intake stays free (Law 1), which is
the whole reason the reservoir works.

Same discipline as BUILD-DISCIPLINE's `# verified <date> via <command>`:
the claim and its basis travel together.

## What a promotion must say

Non-negotiable, from `/ideate` §4.5 — a stated promotion is a decision
future sessions can trust; a silent one is indistinguishable from
forgetting. In the project's own FOCUS.md (not just session chat):

1. **Which signal** fired, and its evidence (dates for re-arrival, member
   list for a cluster).
2. **What it passed over** — the older item(s) it jumped, by name.
3. **Why now.**

## Running it

    bin/precipitation-scan.sh            # all three reports
    MIN_SCORE=0.20 bin/…                 # narrow report B
    HUBFRAC=0.08 bin/…                   # sharpest clusters
    INCLUDE_LOGS=1 bin/…                 # include machine pass-journal entries

Wired into `bin/ecosystem-survey.sh`, so every `/ideate` and
`/nightly-batch` orient step runs it. Zero AI cost, offline-first, writes
nothing.

By default it scores only **human-origin** entries — inbox arrivals
(`via \`scheduler -i\``) and human-directed sessions. The machine's own
pass journal ("inbox empty, nothing to build") repeats by construction;
scoring it fills report B with the system detecting its own heartbeat.

## Known limits (stated, not hidden)

- **Vocabulary overlap is a proxy for aboutness, and a crude one.** Two
  entries can share terms and mean different things. Every finding in B
  and C is a candidate to read, never a verdict.
- **Long omnibus session records are excluded as hubs** (`HUBFRAC`) —
  they touch everything, so they join every cluster to every other. The
  excluded list is printed rather than silently dropped. A real signal
  living only inside an omnibus entry will be missed until it is filed as
  its own entry.
- **No transitive clustering.** A~B and B~C does not make A~C; chaining
  collapsed 205 of 211 entries into one "cluster" on the first run.
  Clusters are stars around a seed, so a genuinely large diffuse cluster
  will be reported as several overlapping stars.
- **It cannot judge shape stability** — the one thing signal 1 actually
  turns on. That judgment is human, by design, and the tool's job is to
  put the two entries side by side with their shared terms so the call
  takes a glance instead of an archaeology session.
