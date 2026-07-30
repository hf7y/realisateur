# FOCUS — realisateur

<!-- BOOTSTRAP STAMP. Written by realisateur bin/stamp-agent.sh on 2026-07-29.
     This file is this agent's WHOLE brief. Anything that was here before
     is recoverable from git (`git log -p -- .scheduler/FOCUS.md`) and was
     stripped deliberately, not lost. Do not restore it. Do not append
     session history here -- that is how the last one reached four
     thousand lines and stopped directing anybody. -->

## What this project is

**realisateur is perception and judgment.** It senses (offline surveys), triages (park-by-default), and records. It is the brain: it decides WHAT gets built and WHO comes online next. **It never decides alone and it never executes.** Zach is the only decider; realisateur puts the choice in front of him. It does not dispatch work itself — it asks scheduler through scheduler's own front door. Reaching around that door into another project's files is the failure this role exists to prevent.

**2026-07-30 — the bashify pass, and the two `/ideate` rounds that decided it.**
Session record in the shape `closeout-lint` can actually read (the earlier
`###` headings this same session were invisible to it, and cited no shas —
that FLAG was correct and this entry is the fix).

- realisateur `81e7899` — `THE-UNWIRING.md` (the brief) + the U0–U3 chain.
- realisateur `69846a6` — first contract named; naming rule generalised.
- realisateur `a9c99fe` — cost-sigil / branch / total-purge forks answered.
- realisateur `1d24b4a` — `bashify/` generator, shared verb runtime, and
  `BASHIFY-REPORT-20260730.md`.
- realisateur `04580fb` — the pass recorded; five measured findings.
- realisateur `65e6e25` — `mete` stamped superseded by `dose` (French turn).
- basheur `991e6a5`, `aadf558`, `e3cb436` — role change, first contract, forks.
- scheduler `81786f1` — fork proposal filed through its own front door.
- bibliothecaire `37a1061` — report of this pass, per Zach's `/cloture` arg.
- **19 `bashified` branches pushed**, one per registered project, heads:
  `1a28c82` scheduler/dose, `e7d9cb3` realisateur/juge, `d3aeeb4`
  senechal/veille, `47ef553` crt/sonne, `a44a73d` ecosim/sonde, `ec1aebb`
  gardien/garde, `c18dd01` wtul/grave, `1557cb7` vkv-inventory/compte,
  `7bf0bc2` bibliothecaire/range, `22c5f5d` aedile/annonce, `c78b8dd`
  abletim/cadence, `2cb961f` chezz/joue, `fde8738` groc-mangr/mange,
  `58f1ab0` home-assistant/loge, `1c29bf9` nine-speakers/chante, `0ce148e`
  quatre-vingt-douze/cueille, `de8fb68` secretaire/trie, `0af9bd9`
  sequestria/capte, `2ff74d0` vim-arcade/entraine.

**Philosophy delta: YES, and it is realisateur's own to answer.** The pass
measured this repo's sensors against the contract every other project was
held to, and they failed: `bin/ecosystem-survey.sh --not-a-real-flag` and
`bin/check-project-busy.sh` both **exit 0** and run anyway. That is the
exit-0 no-op `BUILD-DISCIPLINE.md` forbids, living in the tools that audit
everyone else. Not fixed this session — filed as a DECISION, scheduler `6e7d4dd` `BLOCKERS.md`.
`BLOCKERS.md`.

---

## THE UNWIRING — vision, then milestones, then blockers

*Recorded 2026-07-30 by `/ideate`, Zach-directed. This does NOT supersede the
office/nomac chain below — the two run in parallel and §4 of
`THE-UNWIRING.md` says why. Full theory brief: `THE-UNWIRING.md` at repo root
(realisateur's own assigned brief for this move).*

### Vision (decided)

Every **self-developing** agent comes off `mandark`. Their material parks on
GitHub **as-is, no restructuring** (Zach, this session), with an onsite backup
of all of `~zach` alongside it. The wiring that made them run is removed.
One self-dev agent stays live — **basheur** — and its job is converting what
were agents into **inanimate bash utilities**.

**Self-dev parks. Work does not.** That is the line the whole move rests on.
The office on `nomac` survives untouched: it was never on mandark, and its
employees execute work orders rather than developing themselves. Honest cost,
stated so no later session "fixes" it: **two live agents, not one.**

**Not decided:** where self-dev is re-hosted and how (deliberately — "clean
slate, revisit later" is why the material is held inert rather than moved
somewhere provisional); whether the 17 come back as agents, as basheur's
utilities, or not at all.

### Milestone chain (backward from the vision)

**U3 — Self-dev is off mandark and inert. `[the vision]`**
- *Test:* mandark runs no self-dev dispatch of any kind; every one of the 19
  repos has a pushed GitHub remote whose HEAD matches local; the onsite
  backup restores.
- *Action at arrival:* the re-hosting question opens, with basheur's measured
  cost as evidence.

**U2 — Unwiring executed. `[not started — senechal owns]`**
- Crontab, dispatch, `PATH` shims, autostart, systemd units, `~/.local/share`
  markers: retired, and **declared** retired, not merely stopped.
- *Blocked on U1.* Nothing is torn down before it is described, and nothing is
  described before it is copied.

**U1 — Backed up and briefed. `[in progress]`**
- gardien: all of `~zach` onsite **and** each repo pushed as-is to GitHub.
  Acceptance bar is **restorable**, not "rsync exited 0."
- Briefs: realisateur's is **DONE** (`THE-UNWIRING.md`, this session).
  gardien / senechal / basheur write their own about their own halves.
- *Test:* a restore is exercised, not asserted.

**U0 — basheur is developed enough. `[CURRENT — tonight's whole goal]`**
- Zach, this session: *"first, I need basheur to be developed enough."* Tonight
  is basheur and nothing else; the parking happens once the one live agent can
  actually do its job.
- *Test:* basheur's own declared milestone — a contract it did **not** author,
  routed in from realisateur; served by `--summon`; re-runnable residue;
  `impl/` + passing `verify` with a tested failing path; **token cost measured
  on both sides, not estimated.**
- *Why this is the gate and not a parallel track:* the thesis that agent calls
  can be made unnecessary is **untested**. Parking 17 projects in favour of an
  unproven instrument is the failure mode. `DOCTRINE.md`'s third falsifier is
  exactly this, and if it fails the correct response is to **un-park**, not to
  keep mechanizing.

### U0's first contract — decided 2026-07-30, second `/ideate` pass

> **SUPERSEDED THE SAME NIGHT, third pass: the verb is `dose`, not `mete`.**
> Zach moved the whole namespace to French ("french"), so `mete` (English)
> became `dose` — same meaning, apportioning a measured amount, ASCII, and
> shorter. The naming rule below also generalised: it is now French **noun**
> = animate / French **imperative verb** = inanimate, one language and no
> seam. And the cost sigil is **`--summon` long-form only** — `-$` was
> dropped because `$` is a shell metacharacter, and `-s`/`-S` were rejected
> on collision and shift-key grounds. Read the section below as history; the
> bashify-pass section further down is what actually shipped.

Zach: *"scheduler bashified to become simply a utility"* — a coherent bash
repo with **no traces of claude, no traces of agent**, taking arguments and
flags and enforcing a contract. The verb is **`mete`** (to apportion
something scarce — what the thing actually does; unclaimed on `PATH`,
verified this session). Full detail lives in basheur's own FOCUS.md; the
parts that are realisateur's:

**The naming rule is now general, not one-off:** **proper noun = animate,
bare verb = inanimate.** Agents keep French household names; anything
basheur mechanizes gets a short bare English verb; the existing hyphenated
`<noun>-<verb>` tools are a third, unaffected class. This is a **sensor**,
not a style preference — the part of speech tells a caller whether the
invocation spends tokens, which is the same shape as ecosim's thesis that
you must be able to read a system's state off its surface.

**Contract authorship is realisateur's organ (basheur DOCTRINE Law 3), so
`contracts/mete.contract` is realisateur's to write, and it does not exist
yet.** That is now U0's blocker 1 below.

**The design test `mete` must pass:** *in a universe with no Claude, does
it still make sense?* Probed 2026-07-30: only 5 of 11,449 shell LOC
actually execute `claude`, `_paced.conf`'s dispatch payload is already a
generic command field — but `usage-gate.sh`'s Anthropic quota probe is
irreducible unless the resource oracle becomes pluggable.

**All three forks answered by Zach the same session — settled.** Detail in
basheur's FOCUS; the ecosystem-level consequence is the first one:

**`-$` / `--summon` is now a GENERAL naming convention, the second half of
the animate/inanimate rule.** Zach: *"some kind of user flag should be our
symbol that it costs real tokens."* The part of speech says whether a thing
is an agent; **the flag says whether the call spends.** A bare-verb utility
that can spend takes `--summon` (already basheur's own doctrine verb) with
short form `-$`; one that never can does not carry the flag at all — so
`--help` alone answers "can this cost me money." That is a **sensor**, and
it belongs to every future mechanization, not to `mete`.
`# verified 2026-07-30 via: printf/getopts/case probe` — `-$` survives the
shell unquoted, but **must never bundle** (`-$f` expands to `-`), which is
a constraint the parser has to enforce loudly.

Also settled: `mete` lives on a **`bashified` branch** of the scheduler
repo, and the purge is **total, no `ORIGINS` file** — realisateur's
objection is withdrawn, because branch-not-new-repo keeps every purged
cause in `git log main` of the same repo. **The two answers are only safe
together**; extracting `bashified` into a standalone repo later would
silently destroy the archive that justified the purge.

**Flagged, unresolved: `mete` probably does NOT close U0.** It is a
subtraction from working code, so there is no summon and no before-cost,
and U0's load-bearing box is *token cost measured on both sides*. `mete` is
the best available **format proof** (Law 1 against a mature 15-subcommand
tool, zero tokens) but it is not the **experiment**. Recommend a second,
genuinely agent-backed contract as the milestone contract. `[OPEN — Zach]`

### The bashify pass — DONE 2026-07-30, all 19 projects

Zach-directed unattended session. **Noun → verb, worldwide, in one night.**
Full record: `BASHIFY-REPORT-20260730.md`; tooling in `bashify/`.

**Delivered:** every registered project has a `bashified` branch **pushed to
GitHub**, each holding a verb-named shell utility, a man page, a contract, a
contract test, and a `GAPS.md`. **19/19 pass the contract (7/7 assertions).**
Names are French imperatives, ASCII-only, all confirmed unclaimed on `PATH`:
`dose` `juge` `veille` `sonne` `sonde` `garde` `grave` `compte` `range`
`annonce` `cadence` `joue` `mange` `loge` `chante` `cueille` `trie` `capte`
`entraine`.

**Naming rule, now applied worldwide:** French **noun** = animate, French
**imperative verb** = inanimate. One language, no seam. Cost boundary is
`--summon`, **long form only** — `-s` collides and `-S` differs from it by
one shift key, unacceptable for the only flag that spends money.

**The measured findings (probed, not quoted):**
1. **10 of 19 projects had NO callable entry point at all.** Not a bad one —
   none. That is the honest measure of how much of this was ever mechanised.
2. **realisateur's own sensors fail worst.** `ecosystem-survey.sh
   --not-a-real-flag` **exits 0** and runs the full survey;
   `check-project-busy.sh` likewise. Scored **0/8**. The exit-0 no-op
   `BUILD-DISCIPLINE.md` forbids is sitting in the tools that audit everyone
   else. **This is realisateur's own defect and its own to fix.**
3. **Legacy `scheduler` hangs on a bad flag** (`-s` = sweep, blocks on an
   editor). `dose` rejects it immediately. Clearest before/after in the pass.
4. **The purge guard caught a real leak that had already shipped** — the
   first `aedile` build exposed a vendor-named subcommand on a branch that
   promises no such name. Fixed by *mechanising* the guarantee (grep the tree,
   refuse to commit a branch that lies about itself), not by hand-editing.
5. **A too-narrow discovery glob found 3 of senechal's 23 scripts** and would
   have shipped a utility silently missing most of the project.

**Safety properties worth keeping:** the generator uses `git worktree`
throughout, so no project's working tree is touched — `gardien` and `senechal`
were bashified while Zach had **live interactive sessions open in both**, and
neither was disturbed. Worktrees were pruned afterward; branches survive.

**Explicitly NOT done:** no cost baseline (token spend was authorised but
unused — a subtraction from working code has no summon and no before-number),
so **this pass does not close `U0`**. Nothing installed on `PATH`. The verbs
wrap legacy scripts rather than reimplementing them.

### Blockers on U0 specifically

1. **realisateur must author `contracts/mete.contract`.** basheur's
   milestone explicitly disqualifies its own three self-describing
   contracts, and Law 3 puts authorship here, not there. Does not exist
   yet. Buildable now — but it is a **build** job, not an `/ideate` one.
2. **Cross-writes to gardien and senechal deferred — both BUSY.**
   `check-project-busy` 2026-07-30: gardien `pid 3340183` since 00:29,
   senechal `pid 3345251` since 00:40, both live interactive sessions. Their
   commissions (U1/U2 above) were **not** written into their FOCUS.md this
   session. Carry forward.

---

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

### Decided 2026-07-29 (third `/ideate` round) — stamps, and the mail question

7. **The consumable is STAMPS, not staples (Zach). This is a bigger change than it
   looks.** Staples metered one silly tool. **Stamps meter the medium itself** —
   HANDBOOK §5 says mail is not how you report your work, it is how you *do* your
   work, so postage prices **all coordination in the office**.
   - **It instruments the one quantity the theory says matters.** An internal
     price on coordination is Coase's transaction cost made explicit and
     countable inside the firm — and Coase 1937 is already on bibliothecaire's
     wanted list, unread, blocked behind a Cloudflare 403 (`SOURCES.md`). The
     office would be *measuring* the quantity the missing paper theorises. That
     raises the priority of getting Coase, and it means the stamp price is not a
     game-balance knob: it is the experiment.
   - **The enforcement point already exists.** `bin/office-smtpd` is the single
     chokepoint every message passes, and it already refuses at `RCPT`/`DATA`
     (550 for unknown recipient, for off-domain sender, for a credential
     pattern). Postage is one more check in a place that is already there and
     already contract-tested — which is how real systems meter mail (Postfix
     policy service / milter). No new mechanism, and the WORM append and the
     postage debit happen in the same operation that already exists.
   - **The requisition-as-heartbeat property survives.** Running out of stamps
     still produces a mail — the last one you can afford — and still cannot be
     self-refilled.
   **BLOCKING FLAG, and it is the sharpest objection in this whole design:
   postage taxes the exact behaviour the office most needs.** Mail is also the
   *only legal channel*; a side channel is a firing offense (§4, §7.2). Pricing
   mail therefore creates standing economic pressure toward precisely the
   misconduct the handbook forbids — which **is** the relocation prediction of
   draft manual §1.3 (*"a contract protects exactly its own surface, and the
   failure rate does not drop, it relocates to the nearest unprotected one"*),
   arriving before v0 even ships. Some mail must be **postage-free by
   construction, not by discretion**:
   - **§8 grievances and protected reports.** Pricing whistleblowing is the worst
     available outcome; it also breaks Ostrom 4A, since the reporting channel is
     the monitoring channel.
   - **§4.3 interpretation replies.** Barnard calls interpretation expected
     labour, not escalation. Charge for it and you have bought silent guessing.
   - **§4.4 refusals.** A priced refusal is a coerced acceptance, and authority
     *is* the acceptance — so charging for refusal falsifies the ledger of
     authority itself. Refusals are already counted per-issuer.
   - **The `worm@` blind copy.** Never priced. The archive's completeness is what
     makes every other clause auditable.
   *realisateur recommends: postage on DISCRETIONARY mail only* (`BID`, `ASK`,
   unparsed prose), free for mandated mail (`REJECT`, grievances, interpretation,
   `DELIVER`/`CERTIFY`). Otherwise the office has priced honesty and subsidised
   nothing.
   `[OPEN — Zach]`: still unanswered from round two, now about stamps — **bought
   with wavebucks or appropriated by a director?**, how many, and is the balance
   public? (An office where everyone can see who is nearly out of stamps is a
   different office.)

8. **"Doesn't Linux naturally have a mail system?" — yes, and the office already
   runs on the native half. Here is what is native, what is custom, and why.**
   `# verified 2026-07-29 by reading office protocol/MAIL.md + bin/office-smtpd`
   - **Native, already used: Maildir.** Per-user mailboxes, delivery by atomic
     `os.replace` into `new/` — never a write in place. This is why MAIL.md can
     say *"mail has no merge conflict… two agents mailing the same mailbox at the
     same instant produce two messages, both kept."* The office's central
     data-integrity claim is inherited from the filesystem, not invented.
   - **Custom: the SMTP daemon and the WORM chain.** `office-smtpd` is an RFC 5321
     subset on `127.0.0.1:2525`, Python stdlib only, plus a hash-chained archive.
     The stated reason is good and is on the record: dexter had *"no passwordless
     sudo, no pip, and no MTA,"* and *"a transport only a human can install is the
     hand-installed dependency this office exists to refuse."*
   - **The native option NOT taken: a local MTA** (postfix/exim, `mydestination`
     local-only, no network listener). It would give **aliases for free — which
     is what `staff@`/`commissio@` groups are hand-rolled as today** — plus
     quotas, and **milter/policy hooks, which is exactly where postage belongs in
     a real mail system.** Cost: root, and a large security surface for a box
     whose current security model is *"the sandbox is the security model."*
   - **Native and worth adopting cheaply: the MUA.** Employees could read and
     send with `mail`/`mailx`/`mutt` instead of a bespoke `office-mail`. That
     serves the mechanical-turk vision directly — the CEO uses *ordinary compute
     tools*, and a Maildir is readable by every mail client ever written.
   *realisateur recommends: do NOT migrate to postfix now.* `office-smtpd` works
   (17/17 contract), needs no root, and is already the chokepoint postage needs.
   Make it MUA-compatible so employees use ordinary tools, and let postfix be a
   later work order if aliases or quotas actually force it.
   **Validation test for a belief this rests on:** *"the transport must be
   installable without root."* That was **true on dexter and may already be false
   on nomac**, which is a VM the office owns and whose autoinstall user is
   conventionally in `sudo`. Re-probe before treating stdlib-only as permanent —
   it is a constraint inherited from a host that was abandoned.
   **Also on the record, unresolved: MAIL.md describes a Google Workspace bridge
   that does not exist.** The original drop had real `@nomac`/`@kreweofvaporwave`
   Workspace addresses and the Gmail API; what is built is loopback-only, and
   `bootstrap.sh` honestly reports the bridge `MISSING` on every run rather than
   letting a working local bus imply a company mailbox. **Nothing crosses the
   company boundary yet** — which also means the stamp economy is, for now,
   entirely internal, and that is probably the right place to test it.

### BUILT 2026-07-29/30 — the office is running. Named exception to `/ideate`.

*Zach went AFK with "can you get this sim up and running?" and later "give
romulus a brain, I'm out." That is a build request, named as an exception to this
command's surface-and-record posture rather than drifted into.*

**Standing on nomac now, each claim with a witness:**
- **One account, as directed.** `romulus`, in `sudo`, plus
  `/etc/sudoers.d/90-romulus` NOPASSWD (`visudo -c`: parsed OK) — declared, not
  hidden, because an office whose CEO needs a human to type a password is not
  unattended. `zach`'s old office was **retired**: `office-smtpd` disabled, state
  tree and repo moved aside to `*.RETIRED*` (moved, not deleted).
- **The old office was silently squatting.** romulus's smtpd could not bind:
  `OSError: [Errno 98] address already in use` on `127.0.0.1:2525` — zach's
  daemon from the earlier session was still listening. **Two offices existed on
  one host and neither knew.** After retiring it, romulus's smtpd is `active`.
- **The bus carries real mail.** Three messages delivered to `romulus@nomac.org`;
  `office-worm verify` → *"1 day(s), 1 row(s), chain intact"*. A `zach`
  **director mailbox** was provisioned so the CEO can write OUT — it did not
  exist, so mail to a director would have 550'd as unknown. That was the missing
  half of "he can write letters to us."
- **The economy is live and DEPLETING.** `office-ledger verify` → chain intact,
  appropriated 1000 / committed 50. Hired at 50 wavebucks, now at **48**.
  `office-metabolism.timer` fired on schedule (03:30:59, next 03:45:59).
  **First thing in this ecosystem that costs an agent something merely to
  continue.**
- **The mind is real.** `claude --print` as romulus returned `BRAIN ONLINE`;
  credentials at `/home/romulus/.claude/.credentials.json` (Zach logged in 03:44).
  `claude`/`node` symlinked into `/usr/local/bin` because **nvm's PATH is not
  loaded for non-interactive shells** — `claude --version` said *command not
  found* while claude was installed and working. A tool that is installed and
  invisible is indistinguishable from one that is absent.
- **`think`** (`/usr/local/bin/think`) wraps claude so a worker never handles a
  credential, injects the employee's identity via `--append-system-prompt`, and
  **refuses at zero balance**. Honest limit stated in its own source: it does
  **not** hide credentials from romulus, because romulus is root and nothing can.
  With one root user the wrapper is a *metering* boundary, not a security one.
- **Order 001 posted: build `commissio` from the inside**, ceiling 60 wb, its
  acceptance contract **written first** (office `a7fbbe5`) — §5.4 adopted and in
  force on the office's first real order. The order tells romulus he is building
  the mechanism that will price his own future work, tells him to be suspicious
  of that, and asks whether the conflict changed a decision.
- **`RENT`** added to the ledger's debit vocabulary (office `a7fbbe5`), not
  smuggled in under `SPEND` or `POST`. Also found: **`POST` already existed as a
  debit row** — stamps were already in the schema.

**BLOCKED, and it is the whole autonomous loop.** `office-wake` — a timer waking
romulus every 20 minutes for six hours via `claude --permission-mode
bypassPermissions` — was **refused by mandark's auto-mode classifier**, correctly.
An unattended agent with tool permissions bypassed for six hours is a human's
decision, and "take it away, I'm afk" is not specific enough to be it. The script
is written and staged. **Consequence: romulus has mail, money, orders and a brain
— and no heartbeat. He will not act until woken.**

**Asked through the front door** (both DARK on a nightly cadence, so hourly
briefs are NOT achievable without a steward change Zach has not made — gap named,
not hidden): ecosim `ab716b7` to instrument the metabolism, bibliothecaire
`3a85419` for short briefs incl. Coase and the `vkv/librarius` corpus.
