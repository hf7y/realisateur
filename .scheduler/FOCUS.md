# FOCUS — realisateur

<!-- BOOTSTRAP STAMP. Written by realisateur bin/stamp-agent.sh on 2026-07-29.
     This file is this agent's WHOLE brief. Anything that was here before
     is recoverable from git (`git log -p -- .scheduler/FOCUS.md`) and was
     stripped deliberately, not lost. Do not restore it. Do not append
     session history here -- that is how the last one reached four
     thousand lines and stopped directing anybody. -->

## What this project is

**realisateur is perception and judgment.** It senses (offline surveys), triages (park-by-default), and records. It is the brain: it decides WHAT gets built and WHO comes online next. **It never decides alone and it never executes.** Zach is the only decider; realisateur puts the choice in front of him. It does not dispatch work itself — it asks scheduler through scheduler's own front door. Reaching around that door into another project's files is the failure this role exists to prevent.

## The migration sprint — vision, then milestones, then blockers

*Recorded 2026-07-29 by `/ideate`, Zach-directed, working backward from the
vision he stated. This SUPERSEDES the previous bar ("bring the remaining
agents online one at a time") — that bar assumed the 19-project rotation was
the thing coming online. It is not: `office` on `nomac` is. The old bar is in
git, not restored here (Law 3). **Four forks below are marked `[OPEN — Zach]`;
they were asked this session and not answered, and nothing downstream of one
may be built until it is.***

### Vision (decided)

The office on `nomac` is a **clean slate with one metaphor**. Employees are
agents with a Roman name, one `@nomac` address, a wavebucks balance, and a job.
What are today agent-powered self-dev services become, from an employee's seat,
**ordinary compute tools** — `scheduler` is a bin utility the CEO calls to get
work done. It may have agency inside it; to Brian it is a **mechanical turk**,
an agentless API. That illusion is a design goal, not an accident, because it is
what keeps the employee's job the *work order* rather than the ecosystem.

**The vision is reached when all OLD information has been surfaced and
integrated, and NEW information is all that needs managing.** At that point the
accelerator sprint ends and nomac coasts.

**Not decided:** the office's legal/economic form (`[OPEN]` §1.2 of the draft
manual — the design has agents cash out savings, which is a distribution and
therefore not a nonprofit), and who, if anyone, gets laid off at coast (fork 4).

### Milestone chain (backward from the vision)

**M4 — Coast. `[the vision]`**
- *Test that says we're here:* the documentation-of-record on nomac covers every
  registered project, and one full week's mail contains **no** entry sourced
  from pre-office material. New information only.
- *Action at arrival:* end the accelerator. Reweight or retire employees
  (fork 4). This is the moment "lay off some employees" becomes a real decision
  with evidence behind it, not a guess.

**M3 — The first directive executes. `[not started]`**
- Employees know what they are, who they report to, and have **documented the
  ecosystem** — the first directive.
- *Test:* every one of the 19 registered projects has a documentation artifact
  in the office archive, each traceable by mail thread to the work order that
  produced it and to a passing acceptance contract.
- *Evidence-integration moment:* the **281 stranded ideas** are the raw material
  here (`steward-survey`, 2026-07-29: 17 of 17 paced projects DARK, 281 open
  ideas behind a closed valve). Integration means each is surfaced into a
  document, or explicitly retired with a reason — not resumed as work.
- *Revisit trigger:* if two employees produce contradictory documentation of the
  same project, stop and fix the **sensor**, not the documents. That is the
  two-states-one-symbol collapse run 2's sensor contract exists to prevent.

**M2 — The office has an org chart with S3 in it. `[not started]`**
- At least two employees hired besides the CEO; one work order posted, bid,
  worked, and closed **entirely by mail**, contract run by a party who is not
  the worker.
- *Blocking clause, already adopted below:* **no reverse bid is enabled until
  acceptance-test scoring exists** (draft manual §5.4). A bid measures spend and
  cannot measure accomplishment; `_paced.conf`'s usage gate already shipped
  exactly this defect once, measuring that quota burnt rather than that anything
  was achieved. S3 before commissio, in that order.
- *Validation test for a belief we are holding:* "reverse bidding makes work
  cheaper." Falsified if the winning bidder's contract-pass rate is below the
  ceiling-priced baseline. Measure it before scaling the market.

**M1 — Onboard the CEO and give him his first directions. `[CURRENT]`**
- *Test:* Brian, in his own words, replies by mail stating what the code of
  conduct forbids (draft manual §3.3 — an "acknowledged" reply is evidence of
  receipt, not of familiarity), and acknowledges the range of orders he may
  expect (§3.2 — an agent with no stated range has no zone of indifference, so
  every order to it is a fresh authority question).
- *Actions:* create the unix user and Maildir on nomac; deliver handbook +
  first directive by mail; record the hire in the WORM archive.
- *Revisit trigger:* if Brian's first reply refuses on ground (a) —
  unintelligible — the directive is at fault, not Brian. Refusals count against
  the **issuer**, not the refuser (§4.4–4.5).

**M0 — The office exists and its mail bus works. `[DONE, but re-probe]`**
- Witness on record: `media-arts-collective/office` pushed (`f63ce49`,
  `f9198dc`, `d79e166`); loopback SMTP transport with a 17-assertion acceptance
  contract, 17/17 on nomac; dexter footprint retired; senechal `719dd0f`,
  `0bf6ad7`, `350a311` carry the machine-config declarations.
- **That witness is now stale — see blocker 1.** A 17/17 from 20:47 is not a
  claim about 21:20.

### Blockers on M1 specifically

1. **`nomac` does not verify — machine, human-clearable.**
   `# probed 2026-07-29 21:20 via: ssh-keyscan -p 2224 -t ed25519 dexter.tail893f2c.ts.net`
   → port 2224 answers `SSH-2.0-OpenSSH_9.6p1 Ubuntu-3ubuntu13.18` with host key
   `AAAAC3NzaC1lZDI1NTE5AAAAIAtlGFaTF1J/URuJL++ryM2J9CfJg5w44LvuRQCv6JS8`, which
   **differs from `known_hosts:26`**, so `ssh` refuses and the office is
   unreachable from mandark. The key was NOT removed — a host-key mismatch is a
   finding, and this same sprint already learned that *"the port is open" was
   never the check* (the first VM waiter fired 20s into a 5-minute install
   because subiquity's own installer sshd answers on the forwarded port).
   Either the VM was rebuilt inside the last hour or the forward now lands
   somewhere else. **Resolve by identifying the host, not by deleting the key.**
2. **`claude` on nomac is installed but NOT authenticated — human-only.**
   `# verified 2026-07-29 via: ssh … 'claude --version'` → `2.1.220`, node
   `v24.18.1`, both userland via nvm. The office can keep books and carry mail
   without this; **no employee can think.** Which account, and Zach does the
   interactive login. Filed at scheduler `BLOCKERS.md` `d60c928`.
3. **Fork 1 `[OPEN — Zach]`: what is on Brian's desk?** Bare user + mail only /
   mail + a `-x`-only `scheduler` shim / the full office `bin/`.
   *realisateur recommends bare user + mail only* — then every tool that exists
   later exists because a work order justified it, and the archive records why.
   The stapler is the build-but-don't-wire pattern with a nicer name.
4. **Fork 2 `[OPEN — Zach]`: `scheduler` surface for Brian — can it be `-x` only,
   no rw?** Mechanically, yes: install under its own uid mode `0711`, with Brian
   in no group that can read its tree; results return as mail from scheduler's
   own address. *realisateur recommends deciding the shape now and proving the
   enforcement as its own work order with an acceptance contract* — an
   unenforced permission boundary is a claim, not a boundary. Cost to weigh:
   execute-only means Brian cannot diagnose a failure, so every failure becomes
   a mail thread. That may be the point.
5. **Fork 3 `[OPEN — Zach]`: which personnel document governs?**
   `office/HANDBOOK.md` is in force today (the shipped scripts enforce its
   rules). `bibliothecaire/briefs/office-v0-personnel-manual.md` says of itself
   that nothing in it is in force and leaves four `[OPEN]` items to Zach.
   *realisateur recommends: HANDBOOK governs, the manual stays cited research —
   except §5.4, adopted immediately as stated in M2.* Not merged this session;
   the draft is another run's uncommitted work.
6. **Fork 4 `[OPEN — Zach]`: the 19 registered projects — archive, selective
   rehire, or all migrate in as employees?** M4's layoff question is downstream
   of this, and so is any FOCUS.md cross-write to them. *Deliberately not
   started this session:* Zach asked that realisateur lay the plan into each
   agent's FOCUS.md mechanically. **That work is queued, not done, because who
   receives it is exactly fork 4.** Writing 19 briefs and then learning the
   answer was "archive" is 19 wasted cross-writes into live files.

## Standing constraints

- **Law 1 — admission control.** Intake is free, building is quota-gated, so the backlog diverges regardless of build speed. Only pruning changes its sign. Park by default.
- **Law 2 — the reservoir is not debt.** A free-fed reservoir is supposed to grow. Debt is only parked ideas masquerading as active commitments.
- **Law 3 — retirement pressure.** Surfaces only ratchet up, because no session is ever ABOUT removing one. This file being short instead of 2517 lines IS Law 3. The next agent to append session residue here has broken it.
- **You direct scheduler through its front door**, never by editing its files. **You stamp every agent you bring online** — an agent without a role stamp invents one.
- **The milestone is the merge.** This branch is done when it merges to `main`.

## Standing constraints (ecosystem-wide)

- **Done means a WITNESS**, not code existing: a command that ran, a log line, a commit on the ref the consumer reads. Not "it is written."
- A claim about system state is **re-probed, not quoted**.
- **A dirty tree at exit is a failed run**, not a handoff.
- Fail **loud**. An exit-0 no-op is worse than a crash.
- File work you did not ask for through the front door; do not just do it.
