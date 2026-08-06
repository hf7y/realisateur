# Scheduling system: what it actually does

**Written 2026-08-06 for Zach. Nothing here was changed — this is a read-only
evaluation.** Every claim below was re-probed against the live machines between
16:00 and 16:15 UTC on 2026-08-06. Where a conf file's own prose says one thing
and the machine does another, the machine wins and the disagreement is named.

Read sections 1–3 to understand the system. Section 4 is a proposal to accept or
reject. The archaeology is in the appendix, deliberately last.

---

## The short version

You have six autonomous projects on one machine. Each wakes up four times a day,
does a pass, writes down whether it accomplished anything, and goes back to
sleep. **Nothing reads what it wrote down.** The note goes in a file that only
gets deleted at the start of the next run.

That is the whole problem, and it is smaller than it looks. It is not that the
feedback signal is missing — it exists, it is honest, and it is well-designed.
It is that the wire from the sensor to the boiler was never connected. There is
exactly one place in ~432 lines of dispatcher where a verdict changes behaviour,
and it is the rarest verdict of the three.

Today's live evidence, and it is stark:

- **bibliothecaire recorded `DONE` on six consecutive dispatches** — "bar met,
  stop dispatching, this is success" — and was re-dispatched every single time.
- **ecosim recorded `CONTINUE` twelve times today**, each honestly, because real
  backlog exists that only moves on external input. Re-dispatched every time.
- Those are **opposite verdicts producing identical behaviour.** A system in
  which "I'm finished" and "I'm stuck waiting for you" and "I'm making progress"
  all mean *dispatch again in six hours* is not measuring anything. That is the
  clearest one-sentence statement of the gap.

You also have a second, quieter problem: **most of the machinery is inert.**
Weights, rotation position, and round-robin allocation do nothing at all on the
only host that dispatches. Two of the three hosts dispatch nothing. Your
overcomplication and your lack of reflexiveness are the same fact — effort went
into an allocation layer that turned out not to be reachable, and none went into
the feedback layer.

---

## What fires what — the diagram, in prose

**The machine that matters is `monkey`. It is the only one dispatching agents.**

On monkey there are six Unix accounts — `ecosim`, `bibliothecaire`,
`vim-arcade`, `chezz`, `crt`, `baudin` — one per project. Each account's home
directory is mode 0700, so no account can read or execute anything in another's
home. **This permission fact turns out to determine the entire behaviour of the
scheduler**, which is not something anyone designed.

Each account has exactly one cron line, identical in shape:

```
0 */6 * * * PACED_MAX_PER_TICK=1 /home/<acct>/Documents/Projects/scheduler/bin/usage-paced-runner.sh
```

So four times a day — 00:00, 06:00, 12:00, 18:00 UTC — **all six accounts wake
up at the same instant** and each runs *its own private copy* of the same
dispatcher script, out of *its own private clone* of the scheduler repo.

Each copy then reads the same shared rotation file, `_paced.monkey.conf`, which
lists all six projects. And here is the mechanism, traced through one real tick:

1. The runner takes a lock — but the lock is in the account's own home, so it
   is **per-account, not host-wide**. Six dispatchers can and do run at once.
2. It asks the usage gate whether there is spare quota. (Today: always yes —
   see the knob table.)
3. It walks the six-row rotation looking for a row to run. Five of those six
   rows point at a command under *another* account's 0700 home, which it cannot
   execute, so it logs `SKIP <project> -- command not runnable here` and moves
   on. It re-probes the quota gate before each of these skips.
4. It reaches its own row, checks the freeze allowlist, dispatches itself, and
   stops — because `PACED_MAX_PER_TICK=1`.

**So each account dispatches only itself, every tick, forever.** There is no
allocation happening. The rotation pointer proves it: `ecosim`'s pointer file
reads `0` and `chezz`'s reads `3` — each account's own index — and they will
read the same thing after every future tick, because the lap always ends on the
account's own row. It is a fixed point, not a rotation.

Above that sits a **freeze allowlist** (`schedule/FREEZE`), which is real and
does refuse. Every tick logs `FROZEN, but <project> is EXEMPT ... proceeding` —
that line is the allowlist working, not a warning.

**On `mandark` (this laptop):** nothing dispatches agents at all. The crontab
contains only comments and two empty sentinel blocks. The runner is installed
(`~/.local/bin/usage-paced-runner.sh` symlinks into the repo) but has **never
executed once** — there is no `run.log` under
`~/.local/share/scheduler-paced-runner/` at all. What *does* fire on mandark is
unrelated to self-dev: `senechal-health.timer` hourly, `garde-nightly.timer`
at 03:30, and bibliothecaire's three intake timers.

**On `dexter`:** nothing. The crontab holds a `PATH=` line and no jobs.
`~/Documents/Projects/scheduler` **does not exist on that host** and neither does
the runner. `schedule/_paced.dexter.conf` still carries two rows; they are
unreachable twice over — both are `enabled=0`, and there is no dispatcher to
read them.

**And one more, which is the important structural point:** until 16:00 UTC
today an *hourly* dispatcher was firing that appears in **no crontab and no
systemd unit on any host** — it was a session-scoped harness cron. It called
each project's batch command directly, skipping the runner and the quota gate
entirely. Its fingerprint is still visible: ecosim's verdict file is stamped
`15:20:36` today, but the scheduler's own `run.log` records no dispatch at
15:20 — or at any time after 12:00. The scheduler's log records **three**
dispatches of ecosim today; ecosim's own sweep log narrates **twelve passes**.

This is worth naming as a *class*, not an incident: **the scheduler's audit
tools all read crontabs, so any dispatcher that is not a crontab is invisible
to every check you have.** The gap between 3 and 12 is exactly the size of that
blind spot. Confirmed dead as of this writing — nothing on monkey has touched a
sweep log since 15:26 UTC, so the :07 hourly did not fire at 16:07.

---

## 1. What actually fires — with witnesses

| Host | Dispatcher | Status | Witness (run 2026-08-06 ~16:10 UTC) |
|---|---|---|---|
| monkey | 6 × `0 */6 * * *` runner lines, one per account | **LIVE** | `sudo -u <acct> crontab -l` — one `scheduler-paced-runner:RUNNER` line each, all six identical but for the home path |
| monkey | `bibliothecaire-intake.timer` (15 min) | **LIVE** | `systemctl list-timers` — next 16:18:57, last 16:03:57 |
| monkey | `bibliothecaire-intake-ocr.timer` | **LIVE** | same — next 16:20:32 |
| monkey | `bibliothecaire-intake-health.timer` (daily) | **LIVE, and the service is FAILED** | `systemctl list-units` — `bibliothecaire-intake-health.service loaded **failed** failed` |
| monkey | zach's crontab, root crontab, `/etc/cron.d` | **empty** | `no crontab for zach`; `no crontab for root`; cron.d holds only `e2scrub_all`, `sysstat`, `.placeholder` |
| monkey | per-account user timers | **none relevant** | all six accounts show only `launchpadlib-cache-clean.timer` |
| mandark | zach crontab | **EMPTY** | comments + two empty `scheduler-managed` / `arme-managed` sentinel blocks |
| mandark | `usage-paced-runner.sh` | **installed, never run** | symlink exists; `~/.local/share/scheduler-paced-runner/run.log` **does not exist** |
| mandark | `senechal-health.timer` | **LIVE** hourly | `systemctl --user list-timers` — last 10:35:28 CDT |
| mandark | `garde-nightly.timer` | **LIVE** 03:30 daily | same — last 03:35:20 CDT |
| mandark | `bibliothecaire-intake{,-ocr,-health}.timer` | **LIVE** | `systemctl list-timers` — intake next 11:13:17 CDT |
| mandark | `bibliothecaire-intake-health.service` | **FAILED** | `systemctl list-units` — failed on this host too |
| dexter | crontab | **no jobs**, `PATH=` only | `crontab -l` |
| dexter | scheduler checkout / runner | **absent entirely** | `ls: cannot access '/home/zach/Documents/Projects/scheduler': No such file or directory` |
| — | hourly harness cron (:07) | **DELETED 16:00Z today** | verdict files stamped 15:20 with no matching `run.log` entry; no sweep-log activity after 15:26 |

Two things worth flagging loudly, neither of which I changed:

> **URGENT-ish:** `bibliothecaire-intake-health.service` is in `failed` state on
> **both** mandark and monkey. That is the unit whose entire job is to tell you
> whether the intake pipeline is still working. A health check that is itself
> broken on every host it runs on is the failure mode where the pipeline dies
> silently later and nothing pages. This is separate from the scheduling
> question and wants its own look.

> The **same three intake timers are enabled and firing on both hosts** — the
> dev/production confusion of your Decision 2 has already reproduced onto a
> second machine. (Workstream A is disabling the monkey copies today.)

*Caveat on timing:* the six monkey crontabs were read at 16:10 UTC, in the same
minute Agent A was backing them up prior to removing three of them. The state
above is accurate as of the probe and is expected to change today for `chezz`,
`crt`, and `baudin`.

---

## 2. What each knob really does

| Knob | Verdict | Why — witness, not prose |
|---|---|---|
| `schedule/FREEZE` allowlist | **LOAD-BEARING** | Every dispatch on monkey logs `FROZEN, but <p> is EXEMPT in .../FREEZE (host=monkey, rule=<p>@monkey) -- proceeding`. A project not named there is refused at exit 1. `freeze-check.sh --selftest` asserts 17 cases including "non-exempt project must still be refused". This is the only knob that reliably gates anything. |
| `enabled` flag in `_paced.*.conf` | **LOAD-BEARING** | `usage-paced-runner.sh:194` — `[ "${enabled// /}" = "1" ] \|\| continue`. All six monkey rows are `1`; all four `_paced.conf` rows and both `_paced.dexter.conf` rows are `0` and dispatch nothing. |
| `WEIGHT` field | **INERT on monkey. Unreachable on mandark/dexter.** | Weight N works by repeating the row N times in the rotation pool (`usage-paced-runner.sh:209`). On monkey all six rows are weight 1 anyway; but even at weight 5, an account can only ever execute *its own* row, and `PACED_MAX_PER_TICK=1` stops after the first dispatch. Extra copies of a foreign row would only add extra `SKIP` lines. Weight allocates **nothing**. On mandark/dexter it is doubly moot — `_paced.conf` still carries carefully-audited weights (`senechal|0|3`, `gardien|0|2`, `ecosim|0|2`) on rows that are all disabled, on hosts with no dispatcher. |
| Rotation index (`rotation.idx`) | **INERT on monkey. Unreachable elsewhere.** | It is a **fixed point**: `ecosim`'s pointer reads `0`, `chezz`'s reads `3` — each its own index — and the lap always ends there, because the account skips all five foreign rows and then dispatches itself. Verified by pointer file *and* by log order: chezz's tick walks `crt, baudin, ecosim, bibliothecaire, vim-arcade` and then dispatches `chezz` at `[3/6]`, every tick, identically. |
| Round-robin allocation generally | **INERT on monkey** | Follows from the two rows above. Six independent dispatchers each running a one-element rotation is not a rotation. The 0700 home permissions are doing the "allocation", and they allocate one slot per project per tick, unconditionally. |
| `usage-gate.sh` / `jauge` | **LOAD-BEARING in code, but configured nearly wide open** | It genuinely runs — every tick logs a real probe (`http_code=200`, live utilisation). But `schedule/_usage.conf` sets `USAGE_CEILING=0.99` and `USAGE_RUSH_BEFORE_RESET_MIN=10080`. 10080 minutes is seven days — the *entire* 7-day window — so the even-burn "you're on pace, hold" brake is **permanently disabled**. Witness: every gate line today reads `rush=True`, and it returned RUN at 65% utilisation against a 45% burn-line. Only ≥99% utilisation or a hard `rejected` status will hold. It is a circuit breaker, not a thermostat. It was also bypassed entirely by the hourly harness cron. |
| `bin/verdict.sh` | **The sensor is LOAD-BEARING and correct. Two of its three outputs are INERT.** | The script itself is well built — `--selftest` covers 8 cases and every classify branch is observed firing. The problem is downstream. See below. |
| `expires_at` metabolism | **REACHABLE ONLY VIA `IMPOSSIBLE`. Never once fired.** | `usage-paced-runner.sh:393` — the *only* branch that stamps `expires_at` is `if [ "$vrc" -eq 3 ]`, i.e. an explicit `IMPOSSIBLE`. All six accounts' `expires_at` files hold ordinary future dates (2026-08-10 through 08-13) written by the normal dead-man-switch renewal, not by a brake. No account has ever declared `IMPOSSIBLE`. The one brake in the system has never engaged. |

### The finding that matters: `DONE` does nothing

`bin/verdict.sh`'s header states its contract plainly:

```
#   0  DONE     -- bar met; stop dispatching, this is success
```

**The runner never reads that exit code.** `usage-paced-runner.sh` captures it
into `vrc` (line 373), logs it (line 374), and then branches on exactly one
value:

```bash
if [ "$vrc" -eq 3 ]; then     # GAVE-UP -- the only branch
```

There is **no `vrc -eq 0` branch anywhere in the file.** `DONE` and `NOT-DONE`
take a byte-identical path to the end of the loop. "Stop dispatching, this is
success" is implemented as: log the word, dispatch again in six hours.

The live witness, chezz, from its own `run.log`:

```
2026-08-06T06:26:25 DONE chezz rc=0 outcome=DONE (1576s)
2026-08-06T12:00:08 DISPATCH [3/6] chezz -> .../scheduler-run chezz batch
2026-08-06T12:18:17 DONE chezz rc=0 outcome=NOT-DONE (1089s)
2026-08-06T12:18:17 NO-VERDICT chezz -- ran with no verdict written
```

And the broader witness, which is worse than the single case — **`DONE` was
recorded 9 times across 4 accounts today and never once stopped a dispatch:**

```
bibliothecaire  DONE, DONE, DONE, DONE, DONE, DONE   (6 consecutive, all re-dispatched)
baudin          DONE, DONE                            (2 for 2)
crt             NOT-DONE, DONE
chezz           DONE at 06:26, re-dispatched 12:00
```

bibliothecaire is the cleanest illustration in the estate: it has said "I am
finished" every single time it has ever been asked, for two days, and the
scheduler has never registered the answer.

*(Note the second-order effect in the chezz trace: the 12:00 run wrote **no
verdict at all** — `NO-VERDICT`. The runner names this distinctly, which is good
design, and then treats it identically, which is the same gap. An agent that
learns its verdict changes nothing has no reason to keep writing one.)*

---

## 3. The measurement gap

Your framing — *"a boiler driven by a timer rather than a thermostat"* — is
precisely right, and I want to sharpen it: **you do not have a sensor problem.
You have a wiring problem.** I went looking for what is missing and found that
almost everything needed is already being recorded, honestly and in detail.

### What IS already recorded

| Signal | Where | Quality |
|---|---|---|
| Explicit outcome verdict + one-line reason + timestamp + host | `~/.local/share/scheduler-verdict/<project>` | **Excellent.** Structured `KEY=VALUE`. Agents write thoughtful reasons — ecosim's current one names the exact unblocking conditions. |
| Dispatch/outcome/duration per run | `~/.local/share/scheduler-paced-runner/run.log` | **Good.** Timestamped, has wall-clock duration, distinguishes `NO-VERDICT` from `CONTINUE`. |
| Quota utilisation at each dispatch decision | same `run.log`, the `RUN` lines | **Good.** Live utilisation, burn-line, which window binds. |
| Full narrative of what the pass did and found | `~/.local/share/<job>-nightly-batch/sweep.log` | **Very rich.** ecosim's log literally counts its own repetitions: *"the seventh consecutive pass to confirm the same static state."* |
| Human-readable per-day report | `~/reports/<project>/YYYY-MM-DD.md` + `LATEST.md` | Present and current. |
| Commits produced by the run | git history in each account's clone | Available. |
| Token spend | `bin/token-usage.sh` | Exists, 10.8K, standalone. |

That is enough to compute *"did this run accomplish anything"* several
independent ways: verdict, commit count, and the agent's own zero-delta
self-assessment all agree today.

### What is missing — verified, not assumed

I checked whether *anything* consumes these signals to influence a future
dispatch. It does not.

- **The only reader of `scheduler-verdict/` state is `bin/verdict.sh` itself**,
  called by the runner. Nothing else in the repo touches that directory.
- **Every reader of `sweep.log` is a display tool** — `unprinted-facts.sh`,
  `build-services-view.sh`, and `bin/scheduler`'s status viewer. They render it
  for a human. None returns a value into a dispatch decision.
- **Nothing reads `~/reports/` at all** outside the agents that write them.
- **`token-usage.sh` is not invoked by the runner.** Per-run cost is never
  compared against per-run value, because per-run value is never computed.
- **The verdict is destroyed before it can accumulate.** `verdict.sh clear` runs
  at dispatch (line 362), deliberately, so a stale verdict can't be misread as
  current. Correct in isolation — but it means **there is no history**. The
  system is structurally incapable of noticing "same verdict twice in a row",
  which is exactly the thing you asked for.

So the gap is precisely this: **every signal a thermostat would need is measured
and then thrown away. There is one consumer of one signal, and it fires only on
the verdict no agent has ever issued.** The missing component is not a sensor.
It is a *ledger* — somewhere a verdict survives its own run — and a *policy*
that reads it.

**The three inputs the system has and cannot use:**

1. **The agent's own verdict** — `DONE` is ignored entirely.
2. **Repetition** — no verdict outlives its run, so "same again" is invisible.
3. **Blocked-on-human** — there is no vocabulary for it. `CONTINUE` currently
   means both "I made progress, more to do" and "I am stuck until Zach answers".
   ecosim is forced to use the same word for both, and does so correctly.

---

## 4. A proposed improvement — for you to accept or reject

**Not built. Nothing below exists.** I have tried to make it small, because the
diagnosis is that the system already has too many mechanisms and too few wires.

### 4a. Delete first

This addresses your *"both overcomplicated and not reflexive enough"* directly:
the overcomplication and the unreflexiveness are the same budget spent wrong.
Every item here is inert *today* — deleting it removes reading burden and the
risk of an agent reasoning from a mechanism that does nothing.

| Delete / retire | Why it's safe |
|---|---|
| **The weight field** and `weight-audit.sh` | Allocates nothing on the only dispatching host, and cannot allocate anything while each account can execute only its own row. It is a sophisticated answer to a question the 0700 homes already answered. |
| **The rotation pointer and round-robin loop** | A fixed point per account. Six one-element rotations. The runner could simply say "run my row if permitted" and lose no behaviour. This would also delete the entire two-counter `dispatched`/`examined` complexity, and the five wasted quota probes per tick that the foreign-row skips currently cost. |
| **`_paced.dexter.conf`** | Two disabled rows on a host with no scheduler checkout and no runner. |
| **The 5 redundant gate probes per tick** | Falls out of the above. Currently every account probes the API six times per tick to dispatch once. |
| **Keep but park:** `_paced.conf`'s four disabled mandark rows | Per your note that mandark scheduler should be "removed as much as possible" pending the realisateur-as-nursery vision. Park, don't delete — that file's own header records the trap where deleting a row re-armed a fixed nightly cron. |

What survives is: an allowlist, an enabled flag, a quota circuit-breaker, and a
verdict. That is a system you could hold in your head.

### 4b. Add one thing: a verdict ledger

One file per project, appended to rather than overwritten:

```
~/.local/share/scheduler-verdict/<project>.history
2026-08-06T06:26:25Z  DONE      chezz   1576s  "backlog/questions/checks unchanged"
2026-08-06T12:18:17Z  NO-VERDICT chezz  1089s  ""
2026-08-06T15:25:59Z  DONE      chezz     44s  "tenth same-day dispatch, all clean"
```

`verdict.sh clear` keeps consuming the *live* verdict — that safety property is
correct and shouldn't change. It just appends to the ledger on its way out.
This is a handful of lines and it is the enabling change for everything below,
because it is the thing that makes *repetition* observable.

### 4c. Then wire three rules — one per ask

**(i) "Pace proportional to backlog."** This is the one that needs a real
decision from you, because *backlog* has to become a number the agent reports,
not something the scheduler guesses. Proposal: the verdict gains a field the
agent fills in from what it already computes — open issues + unanswered
questions + open milestone criteria, say — and dispatch interval derives from
it:

| Reported backlog | Next dispatch |
|---|---|
| 0 (or verdict `DONE`) | 7 days (a heartbeat, not a work pass) |
| 1–2 items | 24 hours |
| 3+ items | 6 hours (today's rate) |

Note that this **subsumes** and replaces the weight mechanism you'd be deleting
in 4a — but with a number the project derives from its own state each run,
rather than a number a nightly audit script writes into a conf file. That is
"config read from one source" applied to pacing. It is also **exactly your
eventual goal of per-project cadence**, arrived at as a consequence rather than
as a separate feature: cadence stops being configured and starts being
*measured*.

**(ii) "Same blocker twice in a row → slow metabolism."** With the ledger, this
is a two-line check at dispatch: if the last N verdicts have identical
`REASON`s, back off exponentially — 6h, 12h, 24h, 48h, cap at weekly. Crucially
this should be **backoff, not a stop**: ecosim's situation is genuinely
temporary, and the existing `expires_at` brake is too blunt (it requires a human
to `rm` a file to resume). A project that repeats itself should get quieter, not
die.

This is the rule that fixes ecosim today. Seven identical zero-delta passes
would have moved it to a weekly heartbeat after the third, saving nine dispatches
and their quota — without anyone deciding ecosim was finished, because it isn't.

**(iii) "Blocked on human-input should stop triggering."** Add a fourth verdict
value, `BLOCKED`, distinct from all three current ones:

- `CONTINUE` — I made progress, more to do → normal cadence
- `DONE` — bar met → long heartbeat *(and this must finally be honoured)*
- `BLOCKED` — real work remains but **only external input moves it** → stop
  dispatching; wake on a change to the named input, or on a weekly poll
- `IMPOSSIBLE` — cannot be done → brake, as today

`BLOCKED` requires a reason naming *what* it waits on, the same way `IMPOSSIBLE`
already requires one — that refusal-without-a-reason discipline in `verdict.sh`
is good and should be copied. ecosim's current verdict is already written in
this vocabulary; it just had no word for it and had to say `CONTINUE`:

> *"real backlog remains but only moves on external input (Zach answer,
> differently-credentialed session, or new inbox artifact)"*

That is a `BLOCKED` verdict with a fully-specified wake condition, written by an
agent that had no way to express it. The mechanism is being *asked for* by the
agents already.

### 4d. The invisible-dispatcher hole

Independent of the thermostat, and cheap: **the scheduler cannot see any
dispatcher that isn't a crontab.** Today that hid a 10×-over-rate hourly sweep
for a full day from every audit tool. Whatever else happens, dispatch should be
counted *at the point of execution* — the runner and the batch wrapper both
stamping a run ledger — so that "how often did this actually run" is answered by
observation rather than by re-reading the configuration that was supposed to
cause it. This is the "re-probe, don't quote" discipline applied to your own
dispatch rate.

### 4e. What this does not solve

Stated plainly so it isn't discovered later:

- **It does not fix chezz.** chezz's runs are 1,089–2,540 seconds and hitting
  turn ceilings; that is a batch-sizing problem (your Decision 4) and backoff
  will only make an oversized batch happen less often.
- **It does not decide `DONE`'s semantics for a permanent steward.** If
  bibliothecaire is genuinely finished six times running, is it finished, or is
  its bar too low? The mechanism will surface that question loudly rather than
  answer it — which I think is the right division of labour, but it is a
  question that will land on you.
- **The backlog number in (i) is only as good as the agents' honesty about it.**
  On today's evidence they are strikingly honest — ecosim counted its own
  repetitions and argued against dispatching itself again. That is the asset
  this design is betting on, and it is worth naming as a bet.

---

## Appendix: archaeology

Kept short and last, per the prose-reaping principle.

**Why the rotation is a fixed point.** The rotation was designed on mandark,
where one user ran every project and round-robin genuinely allocated between
them. Moving to monkey's one-account-per-project model in early August preserved
the code and destroyed its premise: a rotation only allocates if one dispatcher
can run every row. The 2026-08-05 two-counter fix (`dispatched` vs `examined`)
is a careful, well-reasoned repair to a symptom of this — foreign rows were
consuming dispatch budget — and its own comment measures the 4× throughput
recovery. It is good work on a mechanism that had already become decorative. The
comment block explaining it is now ~40 lines guarding a loop that could be
deleted outright.

**Why `DONE` was never wired.** `verdict.sh` was built 2026-07-29 to solve a
real, narrower problem: `rc=1` conflated "hit max-turns with work left" against
"concluded it cannot be done", and the ecosystem had no braking at all. The
asymmetry it establishes — *absence of a verdict is never GAVE-UP* — is
deliberate and correct; the failure mode of the opposite default is an ecosystem
that shuts down because a machine rebooted. `IMPOSSIBLE` got wired because
braking was the presenting problem. `DONE` was specified in the same header, in
the same commit, and simply never had a consumer written. It has been documented
as load-bearing and inert simultaneously for eight days.

**Why the quota gate is wide open.** `USAGE_CEILING=0.99` and
`USAGE_RUSH_BEFORE_RESET_MIN=10080` were set to arm six dispatchers on one
quota. Rush-before-reset is a sound policy — unused weekly quota doesn't roll
over — but at 10080 minutes it covers the whole window and never turns off, so
the even-burn brake is permanently disengaged rather than engaged near the reset.
This is a knob doing something reasonable at a value that makes it a no-op.

**The `_paced.conf` prose problem, quantified.** ~200 lines of commentary around
four live rows, every one disabled. `FREEZE` is 82 lines around 6 exemption
lines. The FREEZE file's own header contains the best available statement of why
this matters — it records two prose restatements of its roster that were both
stale within two days, and concludes that *"a number in prose beside a list is a
promise nobody keeps."* That file then demonstrates the failure it warns about:
the chezz block had to be corrected in place because it told readers the
exemption "ARMS NOTHING BY ITSELF" the day after chezz was armed.

---

*Probes run 2026-08-06 16:00–16:15 UTC across mandark, monkey, dexter. Sources:
`scheduler/bin/{usage-paced-runner,verdict,freeze-check,usage-gate}.sh`,
`schedule/{FREEZE,_paced.*.conf,_usage.conf}`, per-account `run.log`,
`sweep.log`, and `scheduler-verdict/` state on monkey.*
