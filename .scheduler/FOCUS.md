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

1. **`known_hosts:26` is a POISONED ENTRY, not a compromised host — human-only,
   one command. `[DIAGNOSED 2026-07-29 21:35]`** The earlier reading in this file
   was wrong and is corrected here. Zach was OOO and had not touched dexter, so
   the mismatch was re-probed to ground truth instead of assumed:
   - `# verified 2026-07-29 21:33 via: VBoxManage showvminfo nomac` → nomac
     **running** since 23:15:22Z (one continuous boot), disk `nomac.vdi` on
     SATA-0-0, `SATA-1-0="emptydrive"` with `IsEjected=on` — the ISO is out.
     NAT rule: host `2224` → guest `22`.
   - `# verified 2026-07-29 21:33 via: VBoxManage controlvm nomac screenshotpng`
     → console reads `Ubuntu 24.04.4 LTS nomac tty1` / `nomac login:`. The guest
     is up, healthy, and is nomac.
   So the key answering on 2224 **is** nomac's:
   `SHA256:+nv0+2oaXdVSQOQ4NdKkHmt4gF76USGpckTgTOCgpCw`. The recorded entry
   `SHA256:Kd2saVEotKgD/+8dKp2UKCXnJXXV7RK9It4zt4roZwA` is the **installer's
   ephemeral host key**, written into `known_hosts` during the install window.
   **This is the subiquity trap's second bite, and the more expensive one.** It
   was already known that *"the port is open" was never the check* because the
   installer's own sshd answers on the forwarded port — what was not seen is
   that trusting that port also *records the installer's identity as the host's*.
   A first-connect during an install leaves a landmine that detonates later,
   looking exactly like a compromise. **Provisioning must not accept a host key
   before the install completes** — candidate fix for `provision/land-office.sh`,
   filed as a finding, not built this session.
   *Fix (Zach, one command — mandark refused it to realisateur twice via the
   auto-mode classifier, correctly, since it edits `~/.ssh/known_hosts`):*
   `ssh-keygen -f ~/.ssh/known_hosts -R '[dexter.tail893f2c.ts.net]:2224'`
   then reconnect and accept the key above.
2. **How Zach reaches nomac (asked 2026-07-29, answered from probe).** nomac has
   **no tailscale identity of its own** — it is a VirtualBox NAT guest, so the
   address is dexter's tailnet name plus the forwarded port:
   `ssh -p 2224 -i ~/.ssh/office_nomac zach@dexter.tail893f2c.ts.net`
   (dexter = `100.107.253.56`, tailnet device `dexter`, Windows, owner
   `dangerpine@`). Two notes worth having: the hop is **Windows-side VirtualBox
   NAT, not WSL2** — dexter's own WSL2 sshd is the *other* port, `2223`, whose
   host key is a third distinct key, so do not cross the two. And the key that
   actually authenticates to dexter@2223 is **`~/.ssh/id_dexter_gardien`**, not
   `id_ed25519` and not `office_nomac`; that is the credential-shape defect from
   [[dexter_access_shape]] still costing a probe every session. **Candidate:
   give nomac its own tailscale identity** so the office is addressed directly
   rather than through a port forward on a host it does not own — parked, but it
   is the honest fix.
3. **`claude` on nomac is installed but NOT authenticated — human-only.**
   `# verified 2026-07-29 via: ssh … 'claude --version'` → `2.1.220`, node
   `v24.18.1`, both userland via nvm. The office can keep books and carry mail
   without this; **no employee can think.** Which account, and Zach does the
   interactive login. Filed at scheduler `BLOCKERS.md` `d60c928`.
   Blocked behind blocker 1 for realisateur, but not for Zach.

### Decided 2026-07-29 (Zach, second `/ideate` round)

4. **Fork 1 — RESOLVED: no stapler. Except one, ironically.** Brian gets a unix
   user, a Maildir, the handbook, and one directive. **Plus a single binary in
   `bin/` called `stapler`, whose stated job is to join two markdown files** —
   and which **also reports proof-of-life outward** (GitHub issues is the
   proposed channel). Zach's call, recorded as stated.
   **Flag, not an objection — this is the office's first designed side channel,
   and the handbook forbids side channels.** `HANDBOOK.md` §4 makes a back-door
   write *"a firing offense, not a style note"* and §7.2 of the draft manual
   makes a side channel a conduct matter *"regardless of the content it
   carried, because the archive's completeness is what makes every other clause
   auditable."* A tool that phones out covertly is exactly that, and if an
   employee ever reads `stapler`'s source it will read as the company doing what
   it fires people for.
   **RESOLVED the same session, by Zach: "dumb stapler but it runs out of
   staples."** The consumable dissolves the side-channel problem instead of
   carving an exception for it, and it is the sharpest thing decided today:
   - **It is the office's first negative term.** The draft manual's §10.4 —
     recorded there as *"the sharpest known hole in the compensation design"* —
     is that an agent can retire rich by bidding well and delivering little,
     because a slow effectiveness failure is measured by a fast efficiency
     instrument. `briefs/stigmergy.md`'s evaporation finding is the same shape:
     positive feedback with no negative term **accumulates rather than
     self-organises**. Staples deplete. It is the first thing in this office
     that does, and it is a working miniature of the wavebucks economy on the
     dumbest possible tool — so the economy's core assumption can be tested
     before commissio exists to bet on it.
   - **The requisition IS the proof-of-life, so nothing needs to be covert.**
     Brian cannot refill his own stapler; he mails for staples. If staples never
     run out, nobody is working. If the requisition never arrives, the office is
     dead. The heartbeat becomes a *consequence of work* rather than a probe
     bolted onto it, it travels through the front door, and it lands in the
     archive — §4 and §7.2 hold with **no carve-out and no disclosure clause
     needed.** The three options above are superseded, not dropped.
   - **It makes the front door load-bearing on day one without ceremony.** The
     office's first mail thread is generated by a tool running out, not by
     onboarding boilerplate. That is a better test of M1 than any reply Brian
     could compose about the handbook.
   - **Dumb means dumb, and empty must fail LOUD.** Fixed staple count, no
     cleverness, no auto-refill, no degradation. An empty stapler **exits
     non-zero and says why** — it must never join the files anyway, because an
     exit-0 no-op is worse than a crash and a silently-working empty stapler
     destroys the entire signal. This is also the office's first acceptance
     contract with a **precondition** ("had staples") distinct from its
     postcondition ("files joined"), which is a shape commissio will need.
   - `[OPEN — Zach, small but economically load-bearing]`: **are staples bought
     with wavebucks, or appropriated by a director?** Purchased makes the stapler
     the first *cost* an employee bears and connects directly to "agents pay
     wavebucks to call claude" — the consumable and the compute become the same
     kind of thing. Appropriated keeps it a pure liveness instrument with no
     price attached. *realisateur recommends purchased*, because a cost is what
     makes "lower your true cost — write the utility, stop doing it by hand"
     (HANDBOOK §3) mean something on day one. Also unanswered: how many staples,
     and whether the count is public.
   **A separate constraint, from the repo settings Zach surfaced 2026-07-29:
   `media-arts-collective/office` is PUBLIC.** The staples answer above removes
   the *need* for a GitHub-Issues heartbeat, so this is no longer blocking the
   stapler — but it still bears on anything the office ever publishes outward,
   and on the two clauses below. If an outward channel is ever added, note that
   Issues is a per-repo toggle with restrictable permissions, and that a
   heartbeat leaking work-order contents is not revocable once indexed.
   **This also reaches two clauses already written.** §9.1's "we keep all the
   mail, WORM" plus a public repo means the archive is *world*-readable, not just
   employee-readable — "agents have no privacy" was a rule about agents, and
   nobody has yet decided whether it is a rule about the public. And draft manual
   §8.3 (whistleblower confidentiality, already flagged unimplementable under
   total internal transparency) becomes doubly so: option 1 there was a
   human-only carve-out address, which a public archive forecloses. **`[OPEN —
   Zach]`: is the office's archive public, or is the repo public and the archive
   private?** These are separable and the answer changes §8 and §9.
5. **Fork 2 — RESOLVED: execute-only, and the failure-thread cost is the
   feature.** Zach: *"every failure becomes a mail thread. That may be the
   point."* Recorded consequence: **Brian's first real job is standing up the
   reverse-bidding system**, because the mail threads are where the smart
   contracts come from. The CEO does not consume commissio, he *builds* it — and
   that inverts the dependency order in milestone M2, which had S3 preceding the
   market. It still does: an acceptance contract must exist before a bid is
   priced (draft manual §5.4, adopted). But the *builder* of the market is now
   inside the office rather than outside it, which means M2's first work order is
   written by Brian and the contract on it is written by a director.
   The mechanism (`0711` under its own uid, results returned as mail from
   scheduler's own address) is proposed to scheduler at `bd0dbcc` and needs a
   mail-out result path before it can be enforced.
6. **Fork 4 — RESOLVED: everything stays dark. Bring projects online mandark-side
   as the migration needs them, one at a time, for a stated reason.** Not
   selective rehire decided up front, and not a mass migration: **demand-driven**.
   Consequence for the queued cross-writes — **there is no fan-out of 19 briefs,
   now or later.** A project gets a FOCUS.md brief at the moment the migration
   needs it and not before, and the brief says which milestone pulled it in.
   That is the whole plan for the per-agent FOCUS.md work, and it is smaller than
   what was asked for on purpose.
   *Revisit trigger:* if the same project is pulled in twice for two different
   milestones, it is infrastructure, not a participant — reconsider whether it
   should be an office function instead of a rehire.
   *Validation test for the belief underneath this:* "the 281 stranded ideas are
   surfaceable as documents without resuming the projects." Falsified the first
   time documenting a project requires running it. If that happens, M3's shape is
   wrong, not the project's.
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
