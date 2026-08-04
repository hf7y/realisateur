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

**Updated 2026-08-03: it is no longer a single machine.** The anatomy below
was written when everything ran on `mandark`, and the body it describes is
still right — but it now has a skeleton, and where an organ lives changed
what the organ could see (Law 4).

```
mandark   the laptop. 91% full, sleeps, travels. NO agent dispatch since
          2026-08-03. Still: the scanner, the SMB shares, the hourly estate
          check, the nightly backup SOURCE, and the human.
dexter    a Windows host. Inside it:
          - WSL2      jump host + backup DESTINATION (262G). Dispatches nothing.
          - monkey    the SELF-DEV host. One unix user per project. Ubuntu on
                      VirtualBox, disk on D:, starts at logon. `ecosim` runs
                      here on a six-hour tick.
          - nomac     the OFFICE. media-arts-collective, co-directed. Not ours
                      to touch, and deliberately a separate VM: its economy
                      gates execution on a wavebucks balance.
```

The rule the split encodes: **hardware-bound work stays where the hardware
is.** bibliothecaire's scanner cannot move, so bibliothecaire's *intake* half
cannot move; only its librarian half ever could. Any plan that says "move
project X to host Y" without naming which half is wrong on contact.

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

## The four laws

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
command surface. **In progress, ownership assigned 2026-07-27:** the
catabolic pass (below) — self-retirement + realisateur audit +
bibliothecaire archive, still shape-open, parked — and the scheduler
front-door consolidation as this law's first real proof, still
unstarted. *(status verified 2026-07-27 via realisateur `.scheduler/FOCUS.md`
— re-derive from there, not from this line, once it ages.)*

### Law 4 — One fact, one reader (established 2026-08-03; found by a second host)

A claim about the world is read by more than one thing, and the readers
drift apart silently. Nothing is broken at the moment they diverge — each
reader is individually correct — so nothing reports it, and the
divergence surfaces only when a reader runs somewhere the others never
did.

**Five instances in a single day**, all found on the day the ecosystem
first had a second host running agents:

| what | who disagreed |
|---|---|
| `conf_field` | `schedule/*.conf` **sourced** (`$HOME` expands) vs **grepped** (it does not). Broke `scheduler -i`, the front door. |
| bibliothecaire `backup-proof` | asserted against a backup tool that had been replaced — and was *correctly* reporting that nothing was backed up |
| `usage-gate` | read only the interactive-login credential; the unattended host uses `setup-token` |
| `notify-senechal`, `check-project-busy` | hardcoded `/home/zach`, on a host with no such user |
| ecosim `install-silence-audit.sh` | found by the dispatched agent, unprompted, the same day |

**Why a single-host ecosystem cannot detect this class at all:** every
reader agrees with every other when there is only one world. Divergence
is not observable from inside one machine. This is the deep reason the
migration mattered more than the throughput it bought — *the most
valuable thing `monkey` produced on day one was not a commit, it was
disagreement.*

**Enforced by:** a second host that actually runs the code (not a test
fixture standing in for one); `scheduler/tests/conf-field-witness.sh` and
`usage-gate-token-witness.sh`, both of which assert against the REAL
shipped confs rather than a mock, and both verified to FAIL on the
pre-fix tree — a test that does not fail on the broken version is not
evidence.

**The standing counter-measure**, and it is a habit rather than a script:
when a check reports something wrong, **probe the claim before repairing
the claimant.** bibliothecaire's `backup-proof` looked like stale config
pointed at a retired tool; re-pointing it would have been one step from
deleting the only copy of scans of physical books, because the check was
right and the corpus genuinely had no backup. A failing check is evidence
about the world, not only about itself.

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

**A third interface, found 2026-07-27: realisateur's own senses.** Ashby
assumes a regulator can act *and* can tell which state it is in. This
organism has spent its effort entirely on the first half. Every survey is
an independent partial read with no reconciliation between them, and on
2026-07-27 three of them disagreed about the same projects while a fourth
reported the ecosystem's most active organ (crt, 289 commits/7d) as its
deadest — because it read one of three dispatch surfaces. See
BUILD-DISCIPLINE.md pattern 14. **The organism has been growing its
effectors and its doctrine while leaving its proprioception unregulated,
and a body that cannot feel where its limbs are will act confidently into
furniture.** The failure is asymmetric in the expensive direction: these
tools fail toward *alarm*, and alarm is routed to the scarcest organ, so a
sensor defect is spent directly out of Zach's attention. Regulator queued
(`bin/sensor-agree.sh`, realisateur `.scheduler/FOCUS.md` 2026-07-27).

**The general form, worth stating once:** this ecosystem's doctrine has
been overwhelmingly about *whether work gets done and recorded* — wiring,
retiring, verifying, stamping. Almost none of it is about *whether what
the system believes about itself is true*. Those are different problems,
and the second one silently corrupts every judgment built on it,
including the triage decisions this file exists to justify.

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

**Enforced by:** `bin/precipitation-scan.sh` report B (re-arrival
candidates) plus the `(re-arrival: <dates>)` stamp, per
`PRECIPITATION.md` (2026-07-26). The scan surfaces candidate pairs and
their shared vocabulary; the shape-stability judgment stays human — and
the counter-case is now doctrine too: an idea returning in a *different*
shape each time gets its weight LOWERED, not raised.

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
  verbs. **Ownership decided 2026-07-27** (hybrid: each project
  self-retires its own FOCUS/QUESTIONS prose with realisateur-authored
  tooling; realisateur audits compliance, doesn't do the retiring;
  bibliothecaire narrowly widens to be the receiving archive) — but the
  mechanism's actual shape (trigger, output format, handoff) is still
  open, and the decision itself is parked, not active. Tracked in
  realisateur `.scheduler/FOCUS.md` 2026-07-25 and 2026-07-27.
  *(status verified 2026-07-27 via realisateur `.scheduler/FOCUS.md` —
  re-derive from there, not from this line, once it ages.)*
- ~~**Re-arrival sensor**~~ — **BUILT 2026-07-26** as
  `bin/precipitation-scan.sh`, wired into `ecosystem-survey.sh`, doctrine
  in `PRECIPITATION.md`. It landed larger than queued: alongside
  re-arrival it senses **interface clusters** (distinct asks across
  projects converging on one unregulated interface — the mechanized form
  of the Ashby reading above), and it demotes age to the weakest of five
  ranked signals. Deliberately NOT a composite score: a computed
  reordering is the silent reorder §4.5 forbids.
- **Multi-writer FOCUS-file regulator** — the other interface Ashby's
  reading flags as unregulated (the 2026-07-25 mega-burn test's one real
  collision was exactly this). Second exhibit 2026-07-26: the scheduler
  autocommit watcher adopted a live session's uncommitted FOCUS.md edits
  under a human's name while origin moved twice underneath the same
  session. Regulator now queued (realisateur `.scheduler/FOCUS.md`
  2026-07-26 race entry): honest attribution + live-session probe on
  scheduler's watcher half (via the front door), an atomic
  `focus-commit.sh` edit-commit-push helper with post-rebase content
  verification on realisateur's half.
