# Handoff — 2026-08-06 vision session

*Written to be read cold. Everything below was re-probed on the live machines
between 16:00 and 17:20 UTC on 2026-08-06; nothing is quoted from a conf file's
own prose. Sources: `260806-zach-reply.txt` (morning), `260806-zach-vision-chat.txt`
(afternoon), and four subagent runs.*

**This doc is disposable and knows it.** Zach's standing instruction is that
scope like this ultimately becomes GitHub issues. Converting it is task #1 below.

---

## 1. Where we are, in one paragraph

The ecosystem's dispatch had no feedback loop — six autonomous projects on
`monkey` waking 4×/day (briefly 10×/day) and re-dispatching regardless of
whether the last run accomplished anything. Today we stopped the over-dispatch,
paused three of six accounts, resolved a duplicated production pipeline, fixed a
close-out gate that had **never once been passable**, and produced a written
evaluation of what the scheduler actually does. Everything raised today is
merged. The next phase is a build, not a cleanup: **backlog-as-sensor** — make
backlog countable (GitHub issues), then let cadence derive from it.

---

## 2. Decisions Zach locked today — do not relitigate

1. **`monkey` is strictly DEVELOPMENT.** (Corrects the morning note's typo, which
   said production.) It consumes its own *stable, versioned build outputs* as
   tooling — never real-time self-dev output. Same for `mandark`, `potato`,
   `dexter` WSL.
2. **Anything user-facing moves off the dev hosts** — bibliothecaire's intake,
   the whisper server, etc. Revisit trigger: *too many VMs, or ssh in/out
   becomes major friction.*
3. **Disposable clones and `reset --hard` are ending.** Zach: *"This should
   happen today. It's urgent enough."* Self-dev runs inside per-user accounts
   now; the clone was faking isolation those accounts already provide.
4. **The Obsidian vault keeps its private GitHub remote for now.** Backup
   ecosystem is blocked on hardware (no RAID). Not permanent. Revisit trigger:
   running out of remote space. Long-term preference is offline + excerpt-and-
   destroy, which dissolves the IP question via fair use.
5. **`BLOCKED` verdict vocabulary is essential**; weight should be tuned from
   backlog.
6. **Agent D's workflow question is parked** until after this sprint.
7. **Budget ≠ metabolism.** Token budget is a *money* question (what Zach wants
   to spend). Metabolism is what the organism does with its energy — and
   critically, it should **pace the build to Zach's bandwidth**: if he can't
   clear issues fast enough, builds must not become runaway introspections
   elaborating low-value but unblocked areas.

---

## 3. Immediate work remaining

### URGENT — Zach named these as today's work

| # | Task | Notes |
|---|---|---|
| 3.1 | **Kill disposable clones + `reset --hard`** | Zach: "urgent enough", "should happen today". `reset --hard` was *eating the thermostat work* — ecosim's auto-stash contained `PARADIGM 4 (verdict designs)` + a supervisor history-loss fix + 87 lines of tests, stashed and abandoned unread for days. Fix in `sweep-loop-common.sh` / `scheduler-run`. |
| 3.2 | **`/tmp` isolation fix** | Recommended: `pam_namespace` polyinstantiated `/tmp` (one line in `/etc/security/namespace.conf`) — the real Unix answer, and the accounts are already separate users. Cheap fallback: `TMPDIR=$HOME/tmp` + `umask 077` in the runner env. Already filed as senechal issue **#107**. |
| 3.3 | **vim-arcade deploy key + root cause** | Zach wants the *provisioning mechanism* fixed, not the instance: "Provisioning new accounts is repeatable enough it should have a reliable mechanism." Ask explicitly whether this was hand-work that produced user error. |
| 3.4 | **bibliothecaire intake: pause or fix health** | Zach: "not in active use." `bibliothecaire-intake-health.service` is in **`failed`** state on mandark — the unit whose only job is to say the pipeline works. monkey's three timers are already disabled; **mandark's three are still live.** Decide: pause mandark's intake, or dispatch a subagent at the health failure. |

### THE BUILD — backlog-as-sensor (multi-day; scope today, carry the rest)

Zach's framing: *"We do this and then get a number for gh issues."* The forensic
reaping pass converts prose backlog into countable GitHub issues; the number
then drives cadence. His ecosystem mapping:

- **bibliothecaire** — filing
- **ecosim** — monitoring the numbers and the feedback
- **scheduler** — actually running the mechanism
- **vim-arcade** — displaying the numbers to Zach

**⚠ STALE PREMISE — flag this before anything else.** Zach wrote *"This may be
basheur again, which is good."* **basheur no longer exists.** No binary at
`~/.local/bin/basheur`, no repo at `~/Documents/Projects/basheur`; retired
2026-08-05 after 26 summons that could not reach their own unblocking step. The
batching need is real; the vehicle is gone and must be re-chosen. *(This is
Zach's own premise-decay motif landing on Zach, which is worth saying out loud
rather than quietly routing around.)*

Also open in this workstream:
- **Triage is not FIFO.** Zach: *"first in ideas may be obviated before they can
  be realized."* Needs a re-ordering/consolidating pass ahead of batch work, or
  a milestone buffer layer between his shifting ideas and execution.
- **Rotation redesign.** Either dispatch happens at the *system* level, or
  accounts simply aren't aware of one another. Telling six self-dev users about
  five peers they cannot see is pointless. (Today's evaluation proved weight and
  rotation index are wholly inert on monkey — see §6.)
- **chezz deep audit** (project-specific, like bibliothecaire's). Zach's hunch:
  the massive test suite. First idea: **run testing separately and
  non-agentically**. chezz must learn how much it can chew in 120 turns.

---

## 4. Zach blockers — only he can move these

1. **Merge/close nothing — he already did.** All PRs from today are merged
   (realisateur #74–#77, scheduler #51–#52, ecosim #33). Nothing is queued on him
   for review right now.
2. **chezz: paused or resumed?** Currently **paused** (1 week, un-pause
   2026-08-13). His afternoon note says *"We can pause chezz self-dev pending
   audit or leave it since dispatch is down to 6-hourly"* — ambiguous, and it is
   already paused. Confirm that's what he wants.
3. **`bibliothecaire` intake on mandark** — §3.4. Pause vs. fix is his call.
4. **Rotate the shared OAuth token.** One token is in plaintext in all six
   monkey accounts' `~/.claude/settings.json`, and it was printed into a session
   transcript today while checking bibliothecaire's permissions. My error.
5. **`dog` (565M) is still not a git repository** and is the whole disk story —
   every other repo on mandark combined is 218M. Out of scope by his earlier
   ruling; flagged because nothing else moves it.

---

## 5. Questions Zach asked — answered here, so the next session doesn't re-derive

**Q: "Does senechal know about monkey users and monkey system config? Is it a
trap to store that in prose rather than design a mechanism to check it with a
provenance timestamp?"**

**Answered: it is exactly the trap he suspected.** `senechal.json`'s
`remote_hosts` array contains **only `dexter`**. `monkey` is not in it at all. So
senechal has no mechanical view of monkey's users or system config — it knows
only what `notify-senechal` has told it, which is *prose in GitHub issues*
(today's landed as senechal **#108/#109/#110**). Those issues have creation
timestamps but no re-verification mechanism, so they are provenance-stamped
assertions that decay silently. A `remote_hosts` entry for monkey is the
mechanical fix.

**Q: "The shared-checkout hazard is not fully clear to me. Disposable worktrees
solves this, right?"**

**Mostly yes, with one real gap.** Worktrees give each agent its own working
directory and branch, so concurrent writers stop clobbering each other's files —
that part is solved, and it worked today: four agents ran in parallel with zero
collisions. The gap is that **`git status` in the shared checkout still shows
everyone's untracked files**, because untracked files aren't branch-scoped. That
is why every agent today tripped a "dirty tree" close-out flag on *your* open
vim buffer and reply file. Two of them independently proposed the same fix
(`*.swp`/`*.swo` in `.gitignore`), which landed in #76. The deeper point: a
close-out check that reads the shared working tree cannot distinguish "this
agent left a mess" from "a human is typing", so the check needs to be
branch-scoped, not tree-scoped.

**Q: "Is ecosim running off its own dev tools? Should PR #33 be followed by a
new pull of the hf7y verb set?"**

**Yes to the second, and the situation is worse than he thinks.** The installed
`ecosim-sensor-tick` correctly reads from the *build*
(`~/.local/share/verb-builds/current/ecosim/bin/ecosim-sensor`), not a dev clone
— that part of the dev/prod split is working as designed. But `current` points
at build `2026-08-06T003928Z`, cut at 00:39 UTC, **hours before #33 merged**. And
running it right now gives:

```
BLIND ecosim-sensor-tick.WRAPPER_NO_SENSOR
  path=.../verb-builds/current/ecosim/bin/ecosim-sensor
  | sensor binary missing or not executable
```

So the sensor is not merely un-fixed in production — **it is absent from the
build entirely.** A new verb-set build must follow the merge. This is a clean,
live demonstration of his own point that the dev/prod split and the slow rhythm
of waiting for the nightly matter for system health. He also asks whether
`ecosim-sensor run` should be a French verb; worth dispatching `consulte` on the
naming principle.

**Q: "What is a mechanical way of enforcing a decay on WebFetch permission?"**

Open — carry into the next conversation. The shape he wants generalizes: see §7.

---

## 6. Verified state snapshot — do not re-probe, this is fresh

```
monkey runner lines   ecosim 1  bibliothecaire 1  vim-arcade 1
                      chezz  0  crt            0  baudin     0      PAUSED
schedule/FREEZE       EXEMPT: ecosim@monkey, bibliothecaire@monkey,
                              vim-arcade@monkey        (3 of 6, on main)
biblio intake timers  monkey: NONE     mandark: 3 LIVE  (health svc FAILED)
biblio permissions    allow: [WebSearch, WebFetch]   env block preserved
harness cron          none  (the 10x/day sweep is dead)
_paced.conf           284 lines -> 66, four rows preserved at enabled=0
silence-audit         BLIND(0 projects) -> audited 196 mechanism(s); 46 FLAG(s)
open PRs              realisateur: none    scheduler: none
```

**Findings from the evaluation (realisateur `SCHEDULING-EVALUATION-2026-08-06.md`):**

- **`DONE` does nothing.** There is no `vrc -eq 0` branch anywhere in the
  432-line dispatcher. `DONE` was recorded **9 times across 4 accounts** in one
  day and never once stopped a dispatch; bibliothecaire said `DONE` on **six
  consecutive runs** and was re-dispatched every time.
- **The verdict is destroyed at dispatch**, so no verdict outlives its own run
  and "same blocker twice" is *structurally unobservable* — not unimplemented.
  The missing piece is an append-only **ledger**, not a sensor.
- **Weight and rotation index are wholly inert on monkey.** Each account runs its
  own runner copy and skips the other five rows (`command not runnable here`,
  homes are 0700), so `rotation.idx` is a fixed point. The 0700 permissions are
  doing the allocation.
- **The usage gate is a circuit breaker, not a thermostat** —
  `USAGE_CEILING=0.99` and `USAGE_RUSH_BEFORE_RESET_MIN=10080` (the whole 7-day
  window) leave the even-burn brake permanently off.
- **The scheduler cannot see any dispatcher that is not a crontab.** Today that
  hid a 10×-over-rate sweep for a full day: scheduler log said 3 ecosim
  dispatches; ecosim's own log narrated 12.

---

## 7. Vision threads to pick up

**A. Expiration dates as a first-class mechanism.** Zach's strongest new idea:
*"every mechanism, all prose, should have mechanically wired expiration dates…
'Good until', 'good as long as': those imply a dynamism that feels more tuned to
the pace of my thought."* He wants the balance between agents re-auditing
everything every run and agents taking things at face value. `silence-audit` is
the motivating case — **it never worked, and once installed it kept running.**
Mechanisms should have to prove their keep; if one is useful, we need to know
that and renew it *before* its absence hurts. Note this also answers the WebFetch
decay question, and it is worth a `consulte` for primary sources.

**B. Get real data on premise half-life.** He wants the reaping pass to *measure*
how long a premise actually holds, giving a baseline before building the
expiration mechanism. Concretely: for each reaped paragraph, when was it written
and when did its premise expire?

**C. Separate the money question from the metabolism question.** Burn-line/quota
is about what Zach wants to spend. Metabolism is about pacing the build to
**Zach's bandwidth for clearing issues**. These are currently conflated in one
usage gate.

**D. The premise-moved failure mode.** Every inert mechanism found today was
*correct when written* and lost its premise underneath it (round-robin was real
on mandark, where one user ran every project). The code kept running and kept
emitting plausible output. Zach: *"I am a chaotic principal and my ideas move
much faster than execution."* He proposes a buffer layer — a clear milestone, or
an agent that re-orders and consolidates issues against the big vision ahead of
batch work. This is not in `BUILD-DISCIPLINE.md` yet and probably should be.

**E. The reaping criterion.** *Does this paragraph describe a premise that still
holds?* Live trap → stays in repo. Narrative of why a decision was right at the
time → vault. Prose defending a mechanism whose premise expired → **delete the
mechanism**, not just the paragraph. Landed in `PROSE-REAPING.md` (#76).

---

## 8. Traps for whoever picks this up

- **basheur is gone.** See §3. Re-choose the vehicle.
- **`notify-senechal` files GitHub issues now**, not senechal's `FOCUS.md`. Do
  not hand-write the note.
- **`silence-audit --strict` now genuinely fails** with 46 real flags on
  realisateur. That is the honest state, newly visible — not a regression.
- **Do not `git add -A` in realisateur.** Zach edits files there live; three
  agents hit this today and all three correctly refused to sweep.
- **`systemctl is-enabled <service>` is not a liveness probe** for anything
  timer-activated. Use `list-timers`.
- **Re-probe subagent claims.** All four agents today reported honestly and two
  volunteered corrections to their own earlier findings — but the discipline is
  what made that legible, not luck.
