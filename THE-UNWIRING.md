# THE UNWIRING — realisateur's brief on the whole move

*Written 2026-07-30 by `/ideate`, Zach-directed. This is realisateur's own
brief, assigned to it as the one party responsible for **theorizing the
entire move** rather than describing one project's part in it. gardien
(backup), senechal (unwiring), and basheur (mechanization) write their own
briefs about their own halves; this one is about why all three are the same
act.*

---

## 1. What is actually being done

Every self-developing agent comes off `mandark`. Their material — repos,
FOCUS.md, QUESTIONS.md, the 285 stranded ideas — is **pushed to GitHub
as-is, with no restructuring**, and backed up onsite in parallel (all of
`~zach`, not just the projects). Nothing is deleted. Nothing is rewritten
into a nicer shape on the way out. Then the wiring that made them *run* —
crontab, dispatch, `_paced.conf` rotation, `PATH` shims, autostart — is
removed.

One agent stays live: **basheur**, whose job is to convert what were agents
into inanimate bash utilities.

The office on `nomac` also survives, and that is not an exception — see §4.

## 2. Why this is not a shutdown

The distinction that makes this move coherent, and the one worth defending
when it gets fuzzy at 3am:

> **Self-dev parks. Work does not.**

An agent that develops itself is a process whose output is *a better version
of itself*. That is the thing being suspended. A utility that does a job, and
an employee that executes a work order, are both untouched by this — they
produce output that isn't themselves.

So the move is not "turn off the machines." It is **withdrawing the
self-improvement loop from a host it had outgrown**, and holding it in a
durable, inert form until there's a decided answer about where it should
live. `_paced.conf` already says this in its own header: *"PARKED, NOT
DELETED, and the distinction is load-bearing."*

## 3. Why now, and why this shape

Three facts made this the right move rather than a reaction:

1. **The valve was already shut.** `steward-survey` on 2026-07-30 reads
   **0 live / 17 dark, 285 open ideas stranded**. mandark's crontab was
   emptied 2026-07-29. The ecosystem has *already* not been developing
   itself for a day. This move makes an accidental state into a stated one,
   which is the entire difference between an outage and a decision.
2. **A reservoir behind a shut valve is a lie in slow motion.** Seventeen
   projects with weights, milestones, and backlogs, none of which tick.
   Every survey reports on them as if they were running. Left alone, the
   gap between stated intent and actual dispatch widens until no document
   in the ecosystem can be trusted. Parking them *on GitHub, as-is* stops
   the lie without destroying the inventory.
3. **The instrument that would drain the reservoir doesn't exist yet.**
   basheur's own milestone — one real contract, served, mechanized, **with
   token cost measured on both sides** — is `not-started`. The thesis that
   agent calls can be made unnecessary is **untested**. Building 17 agents'
   worth of future on an untested thesis is how the last accelerator ended.
   So: prove the thesis on one contract before betting the ecosystem on it.

## 4. Why nomac is not an exception

`nomac` is a VirtualBox guest on `dexter`. It was never on mandark. "Get
self-dev off mandark" does not reach it geographically, and does not reach
it in kind either: the office's employees execute **work orders**, they do
not develop themselves. Brian is not a self-dev agent; he is a worker with
a Maildir and a job.

The honest cost of keeping it: **two live agents, not one.** "basheur will
be the only agent I have" is true of self-dev and false of headcount. That
is stated here so no later session discovers it as a contradiction and
"fixes" it by killing one of them.

The office is also where the parked material eventually comes *back* —
M3's first directive is to document the ecosystem, and the 285 stranded
ideas are that directive's raw material. Parking is therefore not the
opposite of the office play; it is its input.

## 5. The order, and why the order is the point

**backup → brief → unwire.** Not concurrent, not reversed.

- **Nothing is torn down before it is described.** A brief written after
  the wiring is gone is written from memory and from a repo that no longer
  runs. Written before, it is written against a live system that can be
  probed.
- **Nothing is described before it is copied.** The backup is the only
  step whose failure is unrecoverable. Everything else can be redone.
- **A backup verified the same hour it is relied on has had no time to be
  wrong.** gardien owns this; the acceptance bar is *restorable*, not
  *completed*. "The rsync exited 0" is not the check — that is
  `BUILD-DISCIPLINE.md`'s first row, and it has fired in this ecosystem
  before.

## 6. Division of labour

| Party | Owns | Brief is about |
|---|---|---|
| **gardien** | Backup of all of `~zach`, onsite; GitHub push of each repo as-is | What was copied, what was verified restorable, what was skipped |
| **senechal** | Removing the wiring — crontab, dispatch, shims, autostart, systemd, markers | What was live, what is now retired, and the declaration that it is gone |
| **basheur** | Converting agents into inanimate bash utilities, one contract at a time | Which agent-shaped behaviours are mechanizable, and what one actually costs |
| **realisateur** | This document; the milestone chain; deciding who comes back and when | Why the whole move is one act |
| **office/nomac** | Unaffected; continues M1 | — |

realisateur **never executes** any of the above. It records and it asks.

## 7. What would make this move wrong

Stated in advance so it can be checked against, rather than rationalised
afterward:

- **basheur's thesis fails.** If the first real contract shows that
  mechanizing costs more tokens than it saves, or that the residue isn't
  re-runnable by a cold reader, then the ecosystem has been parked in
  favour of an instrument that doesn't work. **Falsifier, not a risk** —
  it is already written into basheur's own `DOCTRINE.md` as its third
  falsifier, and the milestone exists to test it. If it fails, the correct
  response is to un-park, not to keep mechanizing.
- **The park becomes a graveyard.** Parked is a state with an exit. If no
  session in a month promotes anything out of it, the reservoir wasn't
  parked, it was abandoned, and the honest move is to say so and retire
  ideas with reasons.
- **The backup was never restorable.** Covered by §5; named again here
  because it is the only failure mode with no recovery.
- **Two live agents becomes five.** The headcount in §4 is a ceiling, not
  a starting point. Each addition is a stated decision with a reason.

## 8. What is explicitly still open

- **Where self-dev is re-hosted, and how.** Deliberately undecided —
  "revisit later, clean slate" is the whole reason the material is being
  held inert rather than moved somewhere provisional.
- **Whether the 17 come back as agents at all**, or come back as basheur's
  utilities, or don't come back. Answering this early would prejudge
  basheur's milestone, which is the experiment.
- **Weights on re-enable.** Already settled as void: Zach, 2026-07-29,
  *"no weights remove"* — realisateur re-derives them fresh. The numbers in
  `_paced.conf` are history, not intent.
