# PHILOSOPHY AND CRITIQUE — what I claimed, what the data did to it

> **New here? Read [`ELI5.md`](ELI5.md) first** — this argument in small
> words, no jargon, same conclusions and same confessions.

Companion to `TECHNICAL-MANUAL.md`. That document says what ran; this one
says what I believed before it ran, what the numbers did to those beliefs,
and where I think the beliefs were badly formed regardless of whether the
numbers agreed with them.

The order matters. Hypotheses first, verdicts second, critique third —
and the critique is harshest exactly where the verdict was most flattering.

---

## I. The governing principle

Before any arm was coded, one principle was fixed, taken from theory
rather than from the ecosystem:

> **A regulator can only absorb the variety it can perceive.**

Ashby's Law is usually invoked on the effector side — the controller needs
as many responses as the environment has states. The claim here is that
the ecosystem's binding constraint sits one stage earlier. Zach is the
scarcest organ, so the interesting question is not "can he act on enough
distinct situations" but "does he ever learn that a distinct situation
exists." A regulator whose sensor maps three world-states onto one symbol
has already lost the variety, irrecoverably, before any decision is made.

The concrete instance: `scheduler status` is `$HOME`-scoped. Projects
under `svc-vaporwave` are not read. `ABSENT`, `UNREACHABLE`, and
`UNEXAMINED` all render as `OK`. Three states, one symbol. Everything
downstream — the report, the burn-rate governor, Zach's attention — is
regulating against a description that cannot represent the failure.

This is not a bug that a more careful implementation avoids. It is what
happens when a sensor's symbol set is smaller than its world's state set,
and no amount of care inside the sensor fixes it.

---

## II. The three paradigms, and why three

One paradigm produces confirmation. The instruction was to generate
adversarial information, so three mutually hostile theories were given
arms in the same simulation and judged by the same mechanical falsifier.

**P1 — Ashby (cybernetics).** *Instrument the sensor.* Variety in must
match variety out. Add the missing symbol.

**P2 — Perrow (normal accidents).** *Instrumentation is itself an accident
participant.* In an interactively complex, tightly coupled system, safety
devices add interactions and become part of the next accident. The real
prescription is a **coupling** intervention — insert slack — not a
complexity one.

**P3 — Hayek (knowledge problem).** *The centre is missing an input that
cannot be sent to it.* If the knowledge is of particular circumstances of
time and place, no improvement to central sensing is the primary remedy;
move the decision to where the knowledge already is.

P2 and P3 are not decoration. Each predicts that P1's remedy — the thing I
built, `silence-audit.sh` — is at best secondary and at worst harmful. If
the study had only run P1 arms it would have been an elaborate way of
agreeing with myself.

---

## III. The seven hypotheses, stated as registered

Registered 2026-07-28T01:35:02, before any generation ran. `prereg.py`
refuses to overwrite them, so what follows is what I actually committed
to, not what I would now prefer to have said.

**H1 (Ashby).** Ashby's Law binds at the SENSOR, not only the effector.
Adding sensor *output symbols* reduces unregulated disturbance more than
adding more *sensors* does, because sensors here share a correlated blind
spot and reconciling N co-blind sensors yields the variety of one.
*Falsifier:* C reduces undetected ticks by <30% vs A, or the CI spans zero.

**H1b (Ashby, self-attacking).** The BLIND advantage is not an artifact of
assuming a BLIND report always cures the blind spot; it survives a hostile
parameterisation where BLIND leads to a structural fix only 20% of the
time.

**H2 (Ashby, predicting a null).** More sensors, reconciled, does NOT help
when blind spots are correlated — the queued `sensor-agree.sh` remedy
addresses the wrong invariant.

**H3 (Perrow).** Perrow's corollary — that adding safety devices to an
interactively complex, tightly coupled system makes it worse — *does*
transfer here, **contradicting bibliothecaire's own `normal-accidents.md`
brief**, which argues it does not because the guards sit outside the
control path. *(Registered as written. §IV corrects the "contradicting"
framing — the brief is narrower than I characterised it, and I had not
re-read it when I registered this. The hypothesis stands unedited because
`prereg.py` refuses; the correction lives downstream where it belongs.)*

**H4 (Perrow).** Perrow's actual prescription is a coupling intervention.
Loosening coupling should beat instrumenting, using no new sensors at all.

**H5 (Hayek).** No improvement to central sensing can be the primary
remedy. Local self-repair should beat the best central-sensing arm.

**H6 (Hayek).** Decentralisation and null-discrimination are complements,
not substitutes: local repair handles what the centre cannot see, BLIND
handles what local organs cannot know is systemic.

---

## IV. What the data did

Ten disturbance regimes × two fault-mode universes × 30 seeds. Verdict
tables in the manual; the substance:

**H2 held, uniformly, and it is the load-bearing result.** `A_baseline`
and `B_more_sensors` are identical to the digit — 889 undetected ticks
each in the baseline regime, and identical in all twenty cells. Four
sensors sharing one domain have the variety of one. This holds *by
construction*, which is both its strength and its weakness: it is
parameter-independent, and it is therefore not really an empirical finding
so much as a demonstration that the model encodes the claim. Its value is
that it makes the claim *legible*, not that it tests it.

The practical consequence is real regardless: `sensor-agree.sh`, queued in
`UNIVERSE.md` as the remedy for proprioception, buys nothing against the
correlated case. It is a reconciliation mechanism for a disagreement
problem, deployed against an agreement problem. Four sensors that all say
`OK` about `svc-vaporwave` agree perfectly and are all wrong.

**H1 and H1b held** — C beats A by ~92% on undetected ticks, and the
hostile version (`blind_cure_p=0.2`) still beats A by ~83%. The remedy
survives its own worst parameterisation, which is the only reason I would
report H1 at all.

**H3 held — Perrow's corollary transfers.** `P_devices` is worse than
baseline on wasted attention in every regime (0.54 vs 0.29 at baseline;
trust 0.46 vs 0.82).

I registered H3 as *contradicting* bibliothecaire's `normal-accidents.md`
brief. Having since read the brief carefully rather than from memory, that
framing was too strong and I am correcting it here. The brief argues the
corollary doesn't transfer because its guards — `focus-commit`,
`--require-sources`, `--require-briefs` — "sit at commit and validation
boundaries, outside the thing they watch." That is right, and its test —
*does this guard sit inline in the control path?* — is the correct test.

The brief simply didn't have a second class of guard in view, and for that
class its own test returns the opposite answer. A misfiring **monitor**
emits an alarm, the alarm consumes Zach, and Zach is the thing that decides
what happens next. **Zach is the control path.** So a guard whose output
lands in his attention is inline in exactly the brief's sense, and fails at
the worst moment — when he is already saturated. `focus-commit` fails
closed with a red exit code and consumes nobody; a sensor does not.

So the usable distinction is not "commit-boundary vs runtime" but **"does
this guard's output consume the scarce regulator?"** Filed to
bibliothecaire 2026-07-28 (`506ca1d`) as a suggested edit, not an applied
one — it is that project's artifact and its author makes the call.

**H4 was falsified almost everywhere** — 19 of 20 cells. `P_slack` is
*worse* than baseline on undetected ticks (1154 vs 889), better on `mttd`
(1.437 vs 0.00, though see the mttd caveat), and better on drain. This is
the cleanest thing the night produced: **slack buys latency tolerance, not
detection.** Loosening coupling makes a missed signal less costly per
tick; it does nothing about whether the signal is ever emitted. Perrow's
prescription and Ashby's address different failures, and the data
separates them sharply.

**H5 was falsified in 6 of 10 regimes and supported in 3** —
`high_break`, `no_drift`, `scarce_zach`. That pattern is the most
interesting result here and I did not predict it. Local repair wins where
the *volume* of local problems is high or where Zach is scarcest; central
sensing wins where the disturbance is *drift* — accounts migrating —
because drift is precisely the thing local organs cannot see is systemic.
Hayek's claim is not wrong; it is scoped, and the scope boundary is
whether the disturbance is local or structural.

**H6 held everywhere.** `H_local_blind` reaches 5 undetected ticks at
baseline against 70 for the best central arm and 169 for the best local
arm. Complements, not substitutes — and the complementarity is large, not
marginal.

---

## V. First-order critique

### The label was wrong, and it was wrong in my favour

`ecosim.py:117` sets `fail_toward = Symbol.ALARM`. The arm named
`A_baseline` — documented in the code as "today's ecosystem" — therefore
fails *loud*. The real `scheduler status` fails *silent*. It renders
unreadable accounts as fine. That is the entire bug the study exists to
model, and the arm named after it modelled the opposite.

The clone run, launched as a "tweak," set `fail_toward_ok=True`. It is not
a tweak. **It is the faithful model, and the main run is the counterfactual.**

I built the honest arm as the variant and the flattering arm as the
control, and then labelled the flattering one "today's ecosystem." I did
not notice until writing this document, which means the overnight
check-ins would not have caught it either — they were reading STATUS.md,
and STATUS.md does not show `fail_toward`.

The consequence is not that the conclusions reverse. Under the faithful
fault mode, H1 gets **falsified in 2 of 10 regimes** (`high_break`,
`scarce_zach`) rather than holding in 10 of 10. C still wins overall. But
"holds universally" and "holds in 8 of 10 with a named boundary" are
different claims, and I would have reported the first.

### The result I did not register is the best one

Same arm, baseline regime, two fault modes:

| | undetected | false_clean | false_alarm | wasted | trust |
|---|---|---|---|---|---|
| fail toward ALARM | 889 | 0 | 718 | 0.29 | 0.82 |
| fail toward OK | 688 | 1062 | 0 | **0.00** | **1.00** |

The fail-toward-OK system scores **perfectly** on wasted attention and
trust while telling 1062 lies. Every metric a dashboard would show
improves. Fewer undetected ticks, zero false alarms, perfect trust. And
the world is worse.

This is the thesis stated more sharply than any of my seven hypotheses
state it, and it is **not a result** — it is an observation, because I
never registered a hypothesis about it. `prereg.py` is doing its job by
denying it the status of a finding. The correct move is to register it and
rerun, not to promote it in the write-up. I am flagging it here precisely
so it cannot be quietly upgraded later.

It also names the failure mode in one line: **a silent sensor optimises
every observable metric.** Any regime that rewards a dashboard will select
for silence.

### `false_clean` read zero for fifty generations and I did not notice

Under `fail_toward=ALARM` a false-clean is structurally impossible, so the
metric could not fire. It sat in every summary table reading `0.0`,
indistinguishable from "no false cleans occurred" — the exact 3→1 collapse
the study is about, committed by the study's own instrument, in the study's
own output, unremarked for two hours.

That is the second time this project has done this. `silence-audit.sh`
originally keyed its BLIND check on a counter that real crontab lines
inflated, so an empty `schedule/` directory reported clean — the detector
committing the defect it exists to detect. The pattern is not carelessness;
it is that **a null-discriminating instrument must discriminate nulls in
its own output**, and neither of these did until someone read them by hand.

There is a design conclusion in that: a metric that reads zero should have
to say *why* — `0 (possible)` versus `0 (structurally unreachable)`. That
is a small change to `experiment.py` and probably the most valuable one
available.

### Five rounds that were one round

The 5 rounds per regime are byte-identical; `run_arm` re-seeds from
`range(seeds)` every time. So `STATUS.md` reports "SUPPORTED 50" for a
result established in ten cells and re-measured five times each.

Nothing about this is fraudulent — the per-cell result is real, the
bootstrap CIs are over 30 genuine seeds — but the tally column is the kind
of number that survives into a summary and gets read as power it does not
have. I wrote that column. Had the check-ins run hourly as planned, they
would have watched a counter climb and read it as accumulating evidence.

### The winning arm is the one whose parameter I invented

`H_local_blind` wins everything, and `local_fix_p` has no empirical
anchor. I declared this confound *with* the hypothesis rather than after,
which is the right procedure and does not make the number mean more. H5's
regime-dependence is credible because the *pattern* across regimes is
structured (drift vs volume) rather than monotone in the parameter. H6's
magnitude is not credible as a magnitude. It should be read as
"complementary, direction confident, size unknown."

### Ten generations spent on a mutation that mutated nothing

`tight_quota` produces summaries identical to `baseline` on 10 of 11
metrics; only `drain_ratio` moves. It tests throughput, and every
hypothesis is about detection. That is 10% of the night's compute
answering a question nobody asked. The pre-registered mutation schedule
was the right mechanism — it removed my freedom to pick the next regime
after seeing the last — but a fixed schedule fixes bad choices as firmly
as good ones.

### What the honest overall verdict is

Stated as plainly as I can:

1. **Reconciling co-blind sensors adds no variety.** Confident. True by
   construction, which limits how much it is a *finding*, but it is
   directly actionable: `sensor-agree.sh` is aimed at the wrong invariant.
2. **A third symbol substantially reduces undetected disturbance.**
   Confident in direction, including under hostile parameterisation and
   under the faithful fault mode; the "universal" framing is wrong, there
   are two named regimes where it fails.
3. **Slack does not substitute for sensing.** Confident. Cleanest result.
4. **Adding fallible sensors is worse than adding none.** Confident, and
   it contradicts a brief this ecosystem already holds.
5. **Local repair and null-discrimination are complements.** Confident in
   direction, uncalibrated in magnitude.
6. **Central vs local is decided by whether the disturbance is drift or
   volume.** Unregistered, emergent, the most interesting thing here, and
   therefore the thing most in need of a fresh hypothesis rather than a
   paragraph in a report.

### And the meta-point

Every defect above is a **silence**: a metric that could not fire, a label
that could not be seen from the status file, a replica that looked like a
sample, a regime that perturbed nothing. None of them threw an error. The
run completed cleanly, on schedule, with a green log — and it was wrong in
four separate ways that only reading the output by hand surfaced.

That is the study's own subject matter, reproduced in the study, at
roughly the rate the study predicts. I would treat that as the strongest
available evidence for the thesis and the weakest possible endorsement of
the method that produced it.

---

*Written 2026-07-28 against `results/` re-read from disk after both
supervisors exited. No hypothesis was edited; `prereg.py` would refuse.
Corrections to the model, if any follow from this, belong in
`sim/results/MODEL_CHANGELOG.md` before anything is re-judged.*
