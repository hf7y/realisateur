# A cybernetic thesis for this ecosystem

*Research pass, 2026-07-28, Zach-directed. Branch
`research/ecosystem-cybernetics`. Nothing here is wired; the simulator is
pure stdlib Python at nice 19 and consumes no API quota, so the study
cannot starve the batch jobs it is studying.*

---

## Part I — The principle, stated before the model

Every regulator problem has the same shape:

```
    DISTURBANCE  ──▶  [ SYSTEM ]  ──▶  ESSENTIAL VARIABLES
                          ▲   │
                          │   ▼
                     EFFECTOR ◀── REGULATOR ◀── PROPRIOCEPTOR
```

Ashby's Law of Requisite Variety is nearly always quoted at the
**effector**: *only variety can destroy variety*. The regulator must have
at least as many distinguishable responses as the disturbance has states,
or some disturbance reaches the essential variables unregulated.

This ecosystem has taken that seriously for two years of doctrine. Every
named regulator — `usage-gate.sh` for quota, park-by-default for intake,
`focus-commit` for the multi-writer race, `push reason:` for silent push
failures — is an **effector-side** intervention, and `UNIVERSE.md` records
that friction dropped and stayed dropped at each interface where one was
built.

**The claim of this thesis is that the law binds identically, and
independently, at the sensor — and that this ecosystem has never once
applied it there.**

> A regulator cannot respond differently to two world-states that its
> sensor maps onto the same symbol. **Sensor variety upper-bounds effector
> variety**, no matter how capable the effector is.

The consequence is sharp and counter-intuitive, and it is the entire
finding:

> If sensors' blind spots are **correlated**, adding sensors adds no
> variety. Reconciling *N* co-blind sensors yields exactly the variety of
> one. The only remedy that adds variety is adding an **output symbol**.

### Why this is not academic

Every survey in this ecosystem has a two-symbol alphabet, `{OK, ALARM}`.
Reality has at least three states:

| world state | meaning | current symbol |
|---|---|---|
| `ABSENT` | looked, genuinely nothing there | `OK` |
| `UNREACHABLE` | domain exists, sensor cannot read it | `OK` or `ALARM` |
| `UNEXAMINED` | never looked at all | `OK` |

A 3→1 collapse. And it is not hypothetical: `scheduler status aedile`
prints *"no log yet"* while aedile has succeeded every night through
2026-07-27, because `bin/scheduler` resolves run state against `$HOME` and
aedile dispatches from `svc-vaporwave`. The conf already declares
`CRON_ACCOUNT="svc-vaporwave"`. **The sensor knows the domain exists and
still asserts a negative over it.**

### The principle, as a rule the ecosystem must adopt

> **A probe may only assert a negative over the domain it actually read,
> and must name that domain. Where it could not read, it must emit a
> distinct symbol — not its best guess in either direction.**

This is already half-written in `BUILD-DISCIPLINE.md` pattern 14. What was
missing is the reason it is *structurally* necessary rather than good
hygiene, and that reason is Ashby at the sensor.

---

## Part II — Toy models

Four runnable fragments. Each isolates one element of the loop.

### 1. The proprioceptor and the 3→1 collapse

```python
class Sensor:
    """domain = what it can actually read. alphabet = what it can say."""
    def __init__(self, domain, can_blind=False, fail_toward="ALARM"):
        self.domain, self.can_blind, self.fail_toward = domain, can_blind, fail_toward

    def read(self, project):
        if project.account not in self.domain:
            # World state is UNREACHABLE. With a 2-symbol alphabet every
            # possible answer is a lie; the only choice is WHICH lie.
            return "BLIND" if self.can_blind else self.fail_toward
        return "ALARM" if project.broken else "OK"
```

Two sensors, same code, one line of difference. `can_blind=False` is today.

### 2. The disturbance that makes it matter

```python
def disturb(projects, rng):
    for p in projects:
        if rng.random() < 0.02:          # a job silently breaks
            p.broken = True
        if rng.random() < 0.004:         # ACCOUNT DRIFT: the real killer.
            p.account = "service"        # it leaves the sensor's domain
                                         # and nothing announces it
```

Account drift is the disturbance this ecosystem actually suffered: aedile
and vkv-inventory moved to `svc-vaporwave` on 2026-07-20 and the sensors
never followed. No component failed. The topology moved.

### 3. The regulator, and why alarms are not free

```python
def regulate(queue, zach):
    budget = zach.attention_per_tick          # THE scarce organ
    queue.sort(key=lambda x: 0 if x[1] == "ALARM" else 1)
    for project, symbol, truth in queue:
        if budget <= 0: break
        budget -= 1
        if symbol == "ALARM" and truth == "BROKEN":
            project.broken = False            # a real fix
        elif symbol == "ALARM":
            zach.wasted += 1                  # artifact: spent on nothing
        elif symbol == "BLIND":
            for s in sensors: s.domain.add(project.account)   # STRUCTURAL
```

The asymmetry is the point. An `ALARM` is paid **per incident, forever**.
A `BLIND` is paid **once** and removes the blind spot. That is why the
added symbol is not merely more honest — it changes the *cost class* of
the fix from recurring to structural.

### 4. The effector

```python
def dispatch(projects, slots):
    for p in sorted(projects, key=lambda p: -p.weight)[:slots]:
        if p.broken:      # consumes a slot, produces nothing
            continue
        p.active.pop(0)   # one idea drains
```

A broken job still burns a dispatch slot. That is what makes an
*undetected* breakage expensive rather than merely invisible — the
ecosystem keeps paying quota for a job that cannot work.

---

## Part III — Three paradigms, deliberately adversarial

A single philosophical grounding that confirms its own remedy is worth
very little. So the study runs three, each with a *different prescription*,
each able to beat the others. All three come from bibliothecaire's own
briefs.

### P1 — Ashby (requisite variety)
**Prescription:** add sensor output symbols.
**Adversarial claim against it:** it is another central mechanism.

### P2 — Perrow (normal accidents)
**Prescription:** reduce **coupling**, do not add devices. Perrow's
corollary is explicit that adding safety devices to an interactively
complex, tightly coupled system makes things *worse* — each device is one
more component with its own failure modes.

This directly contradicts P1, and it also contradicts bibliothecaire's own
`normal-accidents.md`, which argues the corollary does *not* transfer here
because the ecosystem's guards "sit at commit and validation boundaries,
outside the thing they watch." **That argument had never been tested.**
The model gives it a knob (`device_fault_p`) and lets it be wrong.

### P3 — Hayek (the knowledge problem)
**Prescription:** decentralise. Hayek's claim is structural, not about
speed: *the centre is missing an input that cannot be sent to it.*
Knowledge of the particular circumstances of time and place does not
survive generalisation. If true, **no** improvement to central sensing can
be the primary remedy — including P1's. Organs must regulate themselves.

This is the sharpest attack on P1 available, which is why it is here.

---

## Part IV — Method

Pre-registered, mechanically judged, and deliberately hostile to itself.

1. **Hypotheses registered before any result exists.** `sim/prereg.py`
   refuses to run an unregistered experiment, refuses a hypothesis with no
   falsifier ("an unfalsifiable hypothesis is not a hypothesis, it is a
   hope"), refuses to overwrite a registered claim, and marks anything
   registered after its results as `HARKED`.
2. **The falsifier is evaluated by code, not by me** — `BUILD-DISCIPLINE`
   pattern 9, applied to my own reasoning.
3. **A fixed mutation schedule.** Ten disturbance regimes (break rate,
   drift rate, attention scarcity, idea flood, quota tightness, weak cure).
   Choosing the next mutation after seeing the last result is how a p-value
   gets gardened into existence; the schedule removes that freedom.
4. **Bootstrap CIs, not t-tests** — the metrics are skewed counts, and a
   percentile bootstrap degrades honestly (wide interval) instead of
   producing a spuriously small *p*.
5. **A parallel clone with one structural tweak** — sensors fail toward
   `OK` (silent) instead of `ALARM`. Pattern 14 asserts fail-toward-alarm
   is the expensive direction. That assertion has never been tested either.
6. **`INCONCLUSIVE-BLIND` is a verdict.** An unevaluable falsifier is never
   scored as support — the study obeys its own thesis.

### Declared model corrections

**v2 (`alarm_ack`), declared after generation 1, before any judgement.**
Generation 1 let an unreachable project re-fire its alarm every tick, so
the baseline drowned (`attention_wasted_frac` 0.95) and arm C won
trivially. Real operators acknowledge an alarm and stop re-triaging it.
This is a correction to an obviously wrong mechanism, not tuning toward a
desired answer — recorded here because a model edited after seeing results
and not declared is indistinguishable from HARKing. **No hypothesis was
altered.** Generation 1 is retained as v1 data.

**Declared confound on H1.** A `BLIND` report cures the blind spot with
probability `blind_cure_p` (default 1.0), which hands arm C a trivial win.
`C_hostile` sets it to 0.2 and **H1b** exists solely to attack H1.

---

## Part V — Findings so far

*(One generation, 40 seeds × 400 ticks, v2 model. The overnight run sweeps
all ten regimes; treat these as provisional.)*

| arm | paradigm | undetected | wasted% | drain | trust |
|---|---|---|---|---|---|
| `A_baseline` | control | 3148 | 0.29 | 0.151 | 0.73 |
| `B_more_sensors` | P1 | **3148** | 0.29 | 0.151 | 0.73 |
| `C_blind_symbol` | P1 | **379** | 0.00 | 0.222 | 1.00 |
| `C_hostile` | P1 | 461 | 0.00 | 0.223 | 1.00 |
| `P_devices` | P2 | 3192 | **0.60** | 0.139 | 0.30 |
| `P_slack` | P2 | 3661 | 0.32 | 0.119 | 0.74 |
| `H_local` | P3 | 454 | 0.43 | 0.222 | 0.38 |
| `H_local_blind` | P3 | **17** | 0.00 | 0.223 | 1.00 |

**1. `B_more_sensors` is byte-identical to `A_baseline`.** Not "slightly
better" — *identical*, across every metric and every seed. Four sensors
that share a domain restriction have exactly the variety of one. This is
the modelled form of why `sensor-agree.sh` cannot fix the aedile bug, and
it is the study's most load-bearing result because it is not a
statistical claim at all: it is an identity.

**2. The BLIND symbol survives hostile parameterisation.** `C_hostile`
(cure works only 20% of the time) still cuts undetected ticks ~85%. H1's
declared confound does not explain the effect.

**3. Perrow's corollary DOES transfer — bibliothecaire's brief is wrong
on this point.** `P_devices` is worse than baseline on every axis, and
more than doubles wasted attention (0.29 → 0.60). The brief argued the
guards sit outside the control path and so cannot participate in the
accident. But a *sensor* is not outside the control path when its output
is routed to the scarcest organ: a spurious alarm consumes exactly the
resource a real failure needed. **This is adversarial information the
ecosystem did not have, and it should be fed back into the brief.**

**4. Perrow's own prescription fails here.** `P_slack` is *worse* than
baseline (3661 vs 3148). Slack helps when the problem is propagation
speed; here the problem is that the signal is absent, and delaying an
absent signal does nothing. H4 falsified.

**5. P1 and P3 are complements, not rivals.** `H_local` (454) does not
beat `C_blind_symbol` (379) — H5 falsified in the baseline regime, though
it flipped under `high_break` in smoke testing, so the boundary condition
is real and interesting. But `H_local_blind` reaches **17** — an order of
magnitude better than either alone. Local repair handles what the centre
cannot see; BLIND handles what a local organ cannot know is systemic.

### What this says about the real ecosystem

The recommendation is **not** "make `scheduler status` read the other
account." It is the narrower and safer half:

> **Stop asserting a negative over a domain you never read.** Emit BLIND,
> name the domain.

And the second recommendation, from finding 5: the ecosystem should stop
treating central sensing and project autonomy as competing investments.
The model says they are super-additive.

---

## Part VI — Honest limits

- A toy model is an argument, not evidence about the world. Its value is
  that it makes an argument *precise enough to be wrong*.
- Effect sizes here are enormous (~88%) because the model's disturbance is
  tuned so that account drift matters. Direction is more trustworthy than
  magnitude.
- Finding 1 is the exception and is worth more than the rest: an identity
  does not depend on parameterisation.
- `H_local`'s `local_fix_p` is a free parameter with no empirical
  anchor. P3's showing should be read as "decentralisation is competitive",
  never as a measured quantity.
- The clone arm (fail-toward-OK) tests pattern 14's central assertion.
  If failing *silent* proves cheaper than failing toward alarm, a load-
  bearing piece of this ecosystem's doctrine is wrong, and I would rather
  find that out than not.
