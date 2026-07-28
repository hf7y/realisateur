# TECHNICAL MANUAL — ecosim overnight run, 2026-07-27/28

> **New here? Read [`ELI5.md`](ELI5.md) first** — the whole study in small
> words, including the four things it got wrong.

Audience: another agent picking this up cold. This file tells you what
exists, how to run it, what actually ran, and where the traps are. It is
deliberately factual; the interpretation lives in
`PHILOSOPHY-AND-CRITIQUE.md` next to it.

Everything described here is on branch `research/ecosystem-cybernetics`,
checked out as a worktree at
`/home/zach/Documents/Projects/realisateur-research-ecosim`. **Nothing in
this tree is wired to anything.** No cron entry, no systemd unit, no
`~/.local/bin` symlink, no scheduler `.conf`. It runs only when a human or
an agent invokes it by path.

---

## 1. What this is

A discrete-tick agent simulation of the realisateur/scheduler ecosystem,
built to test one claim: that this ecosystem's binding constraint is
**sensor variety, not effector capacity** — Ashby's Law applied at the
input side rather than the output side.

The concrete thing being modelled is a real bug found by hand earlier the
same night: `scheduler status` is `$HOME`-scoped, so projects living under
the `svc-vaporwave` account are not read at all, and the report renders
them the same way it renders healthy ones. Three distinct world-states —
`ABSENT`, `UNREACHABLE`, `UNEXAMINED` — collapse into the single symbol
`OK`. The simulator asks what that collapse costs, and whether the
remedies on the table actually fix it.

No AI, no network, pure stdlib arithmetic, `nice 19`. It cost zero tokens
and did not contend with the paced scheduler jobs.

---

## 2. File map

```
sim/
  ecosim.py       core model: Symbol, World, Project, Sensor, Zach, Ecosystem
  prereg.py       hypothesis registry + mechanical judge (the forcing gate)
  register_h.py   the 7 hypotheses, registered 2026-07-28T01:35:02
  experiment.py   run_arm / bootstrap CI / compare / generation / judge_all
  supervisor.py   overnight driver, label=main
  clone_sup.py    parallel variant, label=clone (imports supervisor, mutates
                  MUTATIONS in place before calling main)
  results/        100 generation JSONs, 3 history files, STATUS.md, logs,
                  MODEL_CHANGELOG.md
bin/
  decide.sh       7 remediation options, dry-run by default
THESIS.md         the long-form argument
```

Also relevant, on a *different* branch (`staging/silence-audit`, worktree
`realisateur-staging-silence-audit`): `bin/silence-audit.sh` and
`bin/install-silence-audit.sh`. That is the buildable artifact; this repo
is the evidence for it. They were kept apart on purpose so the simulator's
results could not be used to justify installing something mid-flight.

---

## 3. The model, precisely

### Symbols and worlds

```python
class Symbol(Enum):  OK, ALARM, BLIND      # what the sensor emits
class World(Enum):   HEALTHY, BROKEN, UNREACHABLE   # what is true
```

The entire study lives in the gap between these two enums. A two-symbol
sensor cannot represent `UNREACHABLE` and must map it onto `OK` or
`ALARM`. Which one it picks is the `fail_toward` parameter, and **that
parameter turned out to matter more than any hypothesis** (see §7 and the
critique doc).

### Sensor

`ecosim.py:117-124` — the collapse, in one line:

```python
fail_toward: Symbol = Symbol.ALARM

def read(self, p: Project) -> Symbol:
    if p.account not in self.domain:
        if self.can_blind:
            return Symbol.BLIND
        return self.fail_toward          # a 3->1 collapse, in one line
    if p.broken:
        return Symbol.ALARM
    return Symbol.OK
```

`domain` is a set of account names. `correlated_blindness=True` (the
default) gives every sensor the *same* domain — the modelling claim that
four `$HOME`-scoped sensors are four copies of one blind spot, not four
sensors. `correlated_blindness=False` hands each sensor a different
domain; that is arm `B2`.

### Reconciliation

`ecosim.py:235-243`. Union rule, deliberately the most generous reading of
the queued `sensor-agree.sh` design: ALARM if any sensor alarms, else
BLIND if any says BLIND, else OK. If the finding survives the charitable
rule it is not an artifact of a stingy one.

### Zach

A scarce organ with `attention` slots per tick. Spends them on queued
items. `spent_on_artifact` counts attention burned on things that were not
real problems; `spent_on_real` counts the rest. `attention_wasted_frac`
is the ratio.

### Disturbances

`break_rate` (a project breaks), `drift_rate` (a project migrates to
another account — this is the disturbance the sensor is blind to),
`idea_rate` (backlog inflow), `slots_per_tick` (throughput cap).

### The eleven arms

| arm | paradigm | what it is |
|---|---|---|
| `A_baseline` | control | 1 sensor, 2 symbols — today's ecosystem |
| `B_more_sensors` | P1_ashby | 4 sensors, 2 symbols, correlated blind spots — the queued remedy |
| `B2_decorrelated` | P1_ashby | 4 sensors, 2 symbols, *different* domains — the charitable version of B |
| `C_blind_symbol` | P1_ashby | 1 sensor, 3 symbols — this study's proposal |
| `D_both` | P1_ashby | 4 sensors, 3 symbols |
| `C_hostile` | P1_ashby | C with `blind_cure_p=0.2` — C attacked on its free parameter |
| `P_devices` | P2_perrow | 4 sensors that can themselves misfire (`device_fault_p=0.05`) |
| `P_slack` | P2_perrow | baseline sensing, coupling loosened (`slack=0.35`) — Perrow's actual prescription |
| `P_slack_devices` | P2_perrow | does slack rescue the devices? |
| `H_local` | P3_hayek | local agents fix locally (`local_fix_p`), no sensor change |
| `H_local_blind` | P3_hayek | local fixing *and* the BLIND symbol |

Three paradigms were used deliberately to generate adversarial rather than
confirmatory evidence: Ashby says *instrument the sensor*, Perrow says
*instrumentation is itself an accident participant, loosen the coupling
instead*, Hayek says *the centre cannot receive this input at all, so move
the decision to where the knowledge is*. They make incompatible
predictions, which is the point.

### Metrics returned per seed

`undetected_ticks`, `detected`, `mttd`, `false_clean`, `false_alarm`,
`attention_artifact`, `attention_real`, `attention_blind`, `trust`,
`ideas_in`, `ideas_done`, `drain_ratio`, `backlog`, `local_fixes`,
`attention_wasted_frac`.

`undetected_ticks` is the primary endpoint for every hypothesis.

---

## 4. The forcing mechanism (`prereg.py`)

Built first, before any simulation code, because the instruction was
"always name your hypothesis out loud — first thing, wire up a mechanism
to force you to do that."

- `register()` **refuses to overwrite** an existing hypothesis id. You
  cannot revise a hypothesis after seeing data; you can only register a
  new one.
- `register()` **refuses an empty falsifier.** The message is the design
  rationale: an unfalsifiable hypothesis is not a hypothesis, it is a
  hope.
- `require()` hard-fails any run whose hypothesis is not registered.
- `judge()` evaluates the stored falsifier **mechanically** against the
  generation's numbers and returns one of `SUPPORTED`, `FALSIFIED`,
  `INCONCLUSIVE`, `INCONCLUSIVE-BLIND`, `HARKED`. No model judgment
  enters here; the verdict is arithmetic.
- `announce()` renders a hypothesis for saying out loud. `supervisor.py`
  calls it for all seven at startup, so every log opens with them.

`INCONCLUSIVE-BLIND` exists because a study about null-discrimination that
silently omitted unevaluable results would be committing its own subject
matter.

---

## 5. How to run it

From `sim/`:

```
python3 register_h.py                 # idempotent; refuses to overwrite
SEEDS=30 TICKS=200 ROUNDS=5 LABEL=main  python3 supervisor.py
SEEDS=30 TICKS=200 ROUNDS=5 LABEL=clone GEN0=500 python3 clone_sup.py
```

Env knobs: `SEEDS` (default 60), `TICKS` (400), `ROUNDS` (6), `LABEL`
(main), `GEN0` (10).

Overnight both were launched detached at `nice 19`, stdout to
`results/main.out` and `results/clone.out`.

**Trap:** both supervisors write the same `results/STATUS.md`. Last writer
wins. The clone finished 95 seconds after main, so the STATUS.md on disk
shows only the clone's tally; main's is recoverable from
`history_main.json` but is *not* in the status file. Fix before any rerun:
make STATUS path label-scoped.

---

## 6. What actually ran

| | |
|---|---|
| launched | 2026-07-28 ~01:40 |
| finished | main 03:01:54, clone 03:03:29 |
| generations | 100 (50 main + 50 clone) |
| per generation | 11 arms × 30 seeds × 200 ticks |
| regimes | 10 (baseline, high_break, low_break, high_drift, no_drift, scarce_zach, rich_zach, weak_cure, idea_flood, tight_quota) |
| rounds per regime | 5 |
| failures | none after gen002 |
| token cost | zero |

Earlier artifacts kept for audit: `gen001.json` (model v1, superseded),
`gen002_v2ack.json` (v2 verification), `history_smoke.json`.

Parameters were reduced from the planned 60 seeds × 400 ticks × 6 rounds
because `bibliothecaire`'s OCR load drove load average to 28 and was
starving the runs. The choice was to yield rather than compete. This
reduces statistical power and is declared, not hidden.

### The determinism trap — read this before quoting any n

**The 5 rounds per regime are byte-identical.** Verified:

```
rounds of main:baseline = 5
all summaries identical: True
```

`run_arm` seeds from `range(seeds)`, so every round re-runs the same 30
seeds. The 100 generations are therefore **20 distinct experimental
cells** (10 regimes × 2 fault-mode variants), each n=30 seeds, each
measured five times. Rounds add wall-clock and confidence in
reproducibility; they add **zero** statistical power.

Any statement of the form "supported in 50 generations" means "supported
in 10 regimes, replicated 5× each." The `STATUS.md` tally columns say
`50` and are, in that sense, actively misleading. Fix before rerun: derive
the round's seed offset from the round index.

---

## 7. Results

### Verdicts by regime — main (`fail_toward=ALARM`)

Every cell is 5 identical rounds; `5S` means supported in all five
replicas of that one cell.

| hid | baseline | high_break | low_break | high_drift | no_drift | scarce | rich | weak_cure | idea_flood | tight_quota |
|---|---|---|---|---|---|---|---|---|---|---|
| H1  | S | S | S | S | S | S | S | S | S | S |
| H1b | S | S | S | S | S | S | S | S | S | S |
| H2  | I | I | I | I | I | I | I | I | I | I |
| H3  | S | S | S | S | S | S | S | S | S | S |
| H4  | F | F | F | **I** | F | F | F | F | F | F |
| H5  | F | **S** | F | F | **S** | **S** | F | I | F | F |
| H6  | S | S | S | S | S | S | S | S | S | S |

### Verdicts by regime — clone (`fail_toward=OK`)

| hid | baseline | high_break | low_break | high_drift | no_drift | scarce | rich | weak_cure | idea_flood | tight_quota |
|---|---|---|---|---|---|---|---|---|---|---|
| H1  | S | **F** | S | S | S | **F** | S | S | S | S |
| H1b | S | S | S | S | S | S | S | S | S | S |
| H2  | I | I | I | I | I | I | I | I | I | I |
| H3  | S | S | S | S | S | S | S | S | S | S |
| H4  | F | F | F | F | F | F | F | F | F | F |
| H5  | F | **S** | F | F | **S** | **S** | F | I | F | F |
| H6  | S | S | S | S | S | S | S | S | S | S |

`H2`'s uniform `INCONCLUSIVE` is **the predicted outcome**, not a failure.
H2 predicts a null, and its registered falsifier says so explicitly. The
judge has no `CONFIRMED-NULL` verdict, so a correct prediction renders in
the column that looks like a non-result. That is a presentation defect in
`STATUS.md`, not a scientific one.

### Representative numbers — main, baseline regime, mean over 30 seeds

| arm | undetected | mttd | wasted | drain | trust | local fixes |
|---|---|---|---|---|---|---|
| A_baseline | 889 | 0.00 | 0.29 | 0.187 | 0.82 | 0 |
| B_more_sensors | **889** | 0.00 | 0.29 | 0.187 | 0.82 | 0 |
| B2_decorrelated | 507 | 0.00 | 0.50 | 0.206 | 0.45 | 0 |
| C_blind_symbol | 70 | 0.006 | 0.00 | 0.222 | 1.00 | 0 |
| D_both | 70 | 0.006 | 0.00 | 0.222 | 1.00 | 0 |
| C_hostile | 151 | 0.539 | 0.00 | 0.223 | 1.00 | 0 |
| P_devices | 930 | 0.00 | 0.54 | 0.182 | 0.46 | 0 |
| P_slack | 1154 | 1.437 | 0.31 | 0.166 | 0.81 | 0 |
| P_slack_devices | 1120 | 0.881 | 0.57 | 0.168 | 0.46 | 0 |
| H_local | 169 | 2.327 | 0.36 | 0.224 | 0.72 | 17.7 |
| H_local_blind | **5** | 0.057 | 0.00 | 0.224 | 1.00 | 0.7 |

`A == B` to the digit, in every regime, in both fault modes. This is the
identity the whole study exists to demonstrate, and it holds **by
construction**: four sensors sharing one domain have the variety of one.
It does not depend on any parameter choice, which makes it the single most
robust result here and also the least surprising one.

### The result nobody registered a hypothesis for

Comparing the same arm across the two fault modes, baseline regime:

| | undetected | false_clean | false_alarm | wasted | trust |
|---|---|---|---|---|---|
| A_baseline, `fail_toward=ALARM` (main) | 889 | **0** | 718 | 0.29 | 0.82 |
| A_baseline, `fail_toward=OK` (clone) | 688 | **1062** | 0 | **0.00** | **1.00** |

The fail-toward-OK baseline scores *perfectly* on trust and wasted
attention while telling 1062 outright lies and carrying 688 undetected
ticks. Every dashboard metric improves; the world gets worse.

This matters for interpretation because **the clone, not main, is the
faithful model of the real ecosystem.** `scheduler status` renders
unreadable accounts as fine — it fails toward OK. The arm labelled
`A_baseline` in the main run fails toward ALARM, which no part of the real
system does. See the critique doc, §"The label was wrong."

---

## 8. Known defects, ranked

1. **Rounds are replicas, not samples** (§6). Inflates every reported n by
   5×. Fix: offset seeds by round index.
2. **`A_baseline` mislabelled.** `fail_toward` defaults to `ALARM`
   (`ecosim.py:117`); the real system fails toward OK. The clone run is
   the faithful one and should be promoted to primary.
3. **Shared `STATUS.md`.** Two writers, last wins, main's tally lost from
   the status file.
4. **`mttd` conditions on detection.** `mttd=0.0` for `A_baseline` does
   not mean instant detection; it means the only things it ever detected
   were detected instantly, and the 889 undetected ticks are not in the
   denominator. Arms that detect *more* look *worse* on `mttd`
   (`C_hostile` 0.539, `H_local` 2.327). Do not read `mttd` as a quality
   metric without conditioning on `detected`.
5. **`false_clean` is structurally zero** in the entire main run, because
   `fail_toward=ALARM` makes a false-clean impossible. A metric that reads
   0 for 50 generations because it cannot fire is exactly the silence this
   study is about, and it sat in the output unremarked until the write-up.
6. **`tight_quota` is a near-null mutation.** Its summary is identical to
   `baseline` on 10 of 11 metrics; only `drain_ratio` moves. It consumed
   10 of 100 generations and tested nothing about sensing.
7. **`H5`'s `local_fix_p` has no empirical anchor** (declared with the
   hypothesis, not after). Read H5 as "decentralisation is competitive at
   plausible rates", never as a measured quantity.
8. **`blind_cure_p=1.0` by default** hands arm C a trivial win. `C_hostile`
   and `H1b` exist to attack exactly this, and both survive — but the
   default remains generous.

Defects 1–3 are mechanical and should be fixed before any rerun. Defects
4–5 change how existing numbers should be *read*, not whether they are
correct. Defects 6–8 were declared in advance.

---

## 9. If you are continuing this

Do not edit the hypotheses. `prereg.py` will refuse, and that refusal is
load-bearing. Register new ids (H7…) and let the old verdicts stand.

Do record any model change in `sim/results/MODEL_CHANGELOG.md` before
judging anything with the changed model. There is one prior entry (v1→v2,
`alarm_ack`) that shows the expected form, including the test that it is a
correction and not tuning: **it made the baseline better, not worse.**

Highest-value next runs, in order:

1. Fix the seed offset, promote the clone's fault mode to `A_baseline`,
   rerun. This changes what the primary comparison *is*, so it needs new
   hypothesis ids rather than reusing H1.
2. Register a hypothesis about the fail-mode asymmetry itself (the §7
   table). It is the strongest observation of the night and it is
   currently unregistered, i.e. it is an observation and not a result.
3. Add a regime that perturbs `correlated_blindness` continuously rather
   than as a boolean, to find where B stops being identical to A.

---

*Verified 2026-07-28 by re-reading `results/` on disk after both
supervisors exited; no state in this document is quoted from the earlier
session's memory.*
