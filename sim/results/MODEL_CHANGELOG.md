# Model changelog

Every change to the model AFTER results exist is recorded here. A model
edited after seeing results and not declared is indistinguishable from
HARKing, so this file is part of the method, not documentation of it.

Hypotheses are never edited — `prereg.py` refuses. Only the model changes,
and only with a stated reason that is about faithfulness, never about the
direction of a result.

---

## v1 — initial model (generation 1, 40 seeds x 400 ticks)

As registered. Sensors read a domain and emit `{OK, ALARM}` or, in the
treatment arms, `{OK, ALARM, BLIND}`.

**Observed defect:** `A_baseline` reached `attention_wasted_frac = 0.95`
and `false_alarm = 2755`. Cause: an unreachable project re-fired its alarm
**every tick**, with no acknowledgment, so the two service-account
projects permanently saturated Zach's attention budget of 2. The baseline
was not merely bad, it was pathological, and arm C won by default.

## v2 — `alarm_ack` (declared before any hypothesis was judged)

Added an acknowledgment set: an alarm about a project is queued once and
not re-queued until that project's state genuinely changes (it breaks
again, is fixed, or its blind spot is cured). This is what a real operator
does — you do not re-triage the same open alarm daily.

**Why this is a correction and not tuning:** it makes the baseline
*better*, not worse. It removes an advantage from the arm I expected to
win. A tuning-toward-the-answer edit would go the other way.

**Effect:** `A_baseline` undetected_ticks 4557 → 3148, wasted 0.95 → 0.29.
Arm C still wins, by 88% rather than by saturation artifact.

**Retained:** generation 1 (`gen001.json`) is kept as v1 data. It is not
deleted, so the correction is auditable rather than merely asserted.

---

## Declared confounds (registered WITH the hypotheses, not after)

- **H1 / `blind_cure_p`.** A BLIND report cures the blind spot with
  probability 1.0 by default, which hands arm C a trivial win. `C_hostile`
  sets it to 0.2, and **H1b** exists solely to attack H1 on this axis.
  H1 is not credible unless H1b also holds.

- **H5 / `local_fix_p`.** Hayek's arm has a free parameter with no
  empirical anchor. Its result should be read as "decentralisation is
  competitive at plausible rates", never as a measured quantity.

- **Arm ranking vs effect magnitude.** The disturbance regime is tuned so
  that account drift matters, which is why effect sizes are large. The
  ordering of arms is far more trustworthy than any single number — except
  for the `A == B` identity, which holds by construction and does not
  depend on parameterisation at all.
