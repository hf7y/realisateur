#!/usr/bin/env python3
"""
prereg.py -- the forcing mechanism. Zach's instruction, 2026-07-28:
"always name your hypothesis out loud. first thing, wire up a mechanism to
force you to do that."

This is that mechanism, and it is deliberately a GUARD rather than a
convention, for the reason this whole ecosystem keeps relearning: a prose
rule ("remember to state your hypothesis") is verified by someone
remembering to verify it, and lasts about a day. See BUILD-DISCIPLINE.md
pattern 3 (layer-not-replace) and Zach's own 2026-07-28 naming of
"LAYER NOT RETIRED".

WHAT IT FORCES
--------------
1. A hypothesis must be REGISTERED BEFORE any result file for that
   experiment exists. The registry stores a monotonic sequence number and a
   wall-clock stamp; the runner refuses to execute an unregistered
   experiment. You cannot run first and narrate after.

2. A hypothesis is INVALID unless it carries a FALSIFIER -- a concrete,
   machine-checkable predicate that would make it WRONG. "I expect C to do
   better" is not admissible. "C reduces undetected_ticks by >50% vs A, and
   is falsified if the reduction is <50% or the 95% CI spans zero" is.

3. After results land, `judge()` evaluates the falsifier MECHANICALLY and
   writes SUPPORTED / FALSIFIED / INCONCLUSIVE. The experimenter does not
   get to grade their own homework -- BUILD-DISCIPLINE pattern 9.

4. HARK detection (Hypothesizing After Results are Known): if a hypothesis
   is registered with a stamp later than the results it claims to predict,
   it is marked HARKED and excluded from the confirmatory set. It may still
   be recorded as EXPLORATORY, which is honest and useful, but it is never
   silently promoted to a prediction.

5. BLIND is a first-class outcome here too, for the same reason as in the
   model: an experiment whose falsifier could not be evaluated (missing
   metric, zero samples) reports INCONCLUSIVE-BLIND, never "supported".
"""

from __future__ import annotations
import json, os, time, hashlib
from dataclasses import dataclass, asdict, field
from typing import Optional

REG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results", "prereg.jsonl")


@dataclass
class Hypothesis:
    hid: str                 # stable id, e.g. "H1"
    paradigm: str            # which philosophical grounding it comes from
    claim: str               # the assertion, in plain words, said OUT LOUD
    prediction: str          # what we expect to see in the metrics
    falsifier: str           # what result would make this WRONG
    metric: str              # the metric the falsifier is evaluated on
    arms: list               # arms compared, [treatment, control]
    direction: str           # "lower_better" or "higher_better"
    min_effect: float        # minimum effect size to count as support (fraction)
    stamp: float = field(default_factory=time.time)
    seq: int = 0
    confound: str = ""       # known confounds, declared UP FRONT

    def key(self) -> str:
        return hashlib.sha1(f"{self.hid}|{self.paradigm}|{self.claim}".encode()).hexdigest()[:12]


def _load() -> list:
    if not os.path.exists(REG):
        return []
    out = []
    with open(REG) as f:
        for line in f:
            line = line.strip()
            if line:
                out.append(json.loads(line))
    return out


def register(h: Hypothesis) -> dict:
    """Register BEFORE running. Refuses to silently overwrite."""
    os.makedirs(os.path.dirname(REG), exist_ok=True)
    existing = _load()
    for e in existing:
        if e["hid"] == h.hid:
            raise SystemExit(
                f"prereg: {h.hid} already registered at {time.ctime(e['stamp'])}.\n"
                f"  Registered claim: {e['claim']}\n"
                f"  A hypothesis is not editable after registration -- that is the\n"
                f"  entire point. Register a NEW id (e.g. {h.hid}b) if the thinking\n"
                f"  changed, so the record shows it changed and when."
            )
    if not h.falsifier.strip():
        raise SystemExit("prereg: REFUSED -- no falsifier. An unfalsifiable "
                         "hypothesis is not a hypothesis, it is a hope.")
    h.seq = len(existing) + 1
    with open(REG, "a") as f:
        f.write(json.dumps(asdict(h)) + "\n")
    return asdict(h)


def get(hid: str) -> Optional[dict]:
    for e in _load():
        if e["hid"] == hid:
            return e
    return None


def require(hid: str) -> dict:
    """Called by the runner. Hard-fails an unregistered experiment."""
    h = get(hid)
    if h is None:
        raise SystemExit(
            f"prereg: REFUSED to run '{hid}' -- no hypothesis registered.\n"
            f"  State the hypothesis first. This guard exists because a prose\n"
            f"  rule saying 'state your hypothesis' is checked by remembering."
        )
    return h


def judge(hid: str, stats: dict, results_stamp: Optional[float] = None) -> dict:
    """
    Evaluate the falsifier mechanically. `stats` is the output of
    experiment.compare(): {"treat_mean","ctrl_mean","effect","ci_low","ci_high","n"}
    """
    h = require(hid)
    verdict, why = "INCONCLUSIVE", ""

    if results_stamp and results_stamp < h["stamp"]:
        return {"hid": hid, "verdict": "HARKED",
                "why": "hypothesis registered AFTER the results it claims to "
                       "predict; recorded as exploratory, not confirmatory."}

    if not stats or stats.get("n", 0) == 0 or stats.get("treat_mean") is None:
        return {"hid": hid, "verdict": "INCONCLUSIVE-BLIND",
                "why": "falsifier could not be evaluated -- missing metric or "
                       "zero samples. This is BLIND, not support."}

    eff = stats["effect"]           # signed fractional change, treat vs ctrl
    lo, hi = stats["ci_low"], stats["ci_high"]
    crosses_zero = lo <= 0 <= hi

    want = h["min_effect"]
    if h["direction"] == "lower_better":
        improved = -eff            # positive == treatment lowered the metric
    else:
        improved = eff

    if crosses_zero:
        verdict = "INCONCLUSIVE"
        why = f"95% CI [{lo:.3f}, {hi:.3f}] spans zero -- no reliable effect."
    elif improved >= want:
        verdict = "SUPPORTED"
        why = f"effect {improved:.3f} >= min_effect {want}, CI [{lo:.3f},{hi:.3f}]."
    else:
        verdict = "FALSIFIED"
        why = (f"effect {improved:.3f} < min_effect {want} "
               f"(CI [{lo:.3f},{hi:.3f}]) -- the falsifier fired.")

    return {"hid": hid, "verdict": verdict, "why": why,
            "paradigm": h["paradigm"], "claim": h["claim"], "stats": stats}


def announce(hid: str) -> str:
    """Render a hypothesis for saying OUT LOUD. Used by the supervisor so
    every generation's log literally opens with the claim being tested."""
    h = require(hid)
    L = [
        "=" * 70,
        f"HYPOTHESIS {h['hid']}  [paradigm: {h['paradigm']}]  (seq {h['seq']})",
        "=" * 70,
        f"CLAIM      : {h['claim']}",
        f"PREDICTION : {h['prediction']}",
        f"FALSIFIER  : {h['falsifier']}",
        f"METRIC     : {h['metric']}  ({h['direction']}, min effect {h['min_effect']})",
        f"ARMS       : {h['arms'][0]} (treatment) vs {h['arms'][1]} (control)",
    ]
    if h.get("confound"):
        L.append(f"CONFOUND   : {h['confound']}")
    L.append(f"REGISTERED : {time.ctime(h['stamp'])}")
    L.append("=" * 70)
    return "\n".join(L)


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "list":
        for e in _load():
            print(f"{e['seq']:>3} {e['hid']:<6} [{e['paradigm']:<18}] {e['claim'][:80]}")
    elif len(sys.argv) > 2 and sys.argv[1] == "show":
        print(announce(sys.argv[2]))
    else:
        print(__doc__)
