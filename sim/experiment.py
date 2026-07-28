#!/usr/bin/env python3
"""
experiment.py -- runs arms across many seeds, computes effect sizes with
bootstrap confidence intervals, and refuses to report a comparison for
which no hypothesis was pre-registered.

Pure stdlib. No AI, no network. Deliberately cheap so it can run for hours
at nice 19 without competing with the scheduler's batch jobs for CPU, and
without consuming ANY API quota -- the usage-paced runner gates Tier 2 on
burn rate, so a study that cost tokens would starve the very jobs it is
studying.

STATISTICS NOTE (why bootstrap rather than a t-test)
----------------------------------------------------
The per-seed metrics here are counts and ratios, often skewed and
occasionally zero-inflated (a run where nothing broke). A Welch t-test
assumes approximate normality of the sampling distribution of the mean,
which is defensible at n>=30 but obscures how ugly the underlying
distribution is. A percentile bootstrap makes no distributional assumption
and degrades honestly: with too few seeds the interval is simply wide,
which is the correct message rather than a spuriously small p-value.
"""

from __future__ import annotations
import json, os, sys, time, random, statistics
from ecosim import Ecosystem, arm, ARMS, PARADIGM_OF
import prereg

RESULTS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")


def run_arm(name: str, seeds: int, ticks: int, overrides: dict | None = None) -> list:
    out = []
    cfg = dict(arm(name))
    if overrides:
        cfg.update(overrides)
    for s in range(seeds):
        out.append(Ecosystem(cfg, seed=s).run(ticks))
    return out


def _boot_ci(vals_t, vals_c, iters=2000, seed=7):
    """Percentile bootstrap CI on the FRACTIONAL change of the mean,
    (treat - ctrl) / |ctrl|. Returns (effect, lo, hi)."""
    rng = random.Random(seed)
    mt, mc = statistics.fmean(vals_t), statistics.fmean(vals_c)
    denom = abs(mc) if mc else 1.0
    eff = (mt - mc) / denom
    diffs = []
    nt, nc = len(vals_t), len(vals_c)
    for _ in range(iters):
        bt = statistics.fmean(rng.choices(vals_t, k=nt))
        bc = statistics.fmean(rng.choices(vals_c, k=nc))
        d = abs(bc) if bc else 1.0
        diffs.append((bt - bc) / d)
    diffs.sort()
    lo = diffs[int(0.025 * len(diffs))]
    hi = diffs[int(0.975 * len(diffs)) - 1]
    return eff, lo, hi


def compare(treat: list, ctrl: list, metric: str) -> dict:
    vt = [r[metric] for r in treat if r.get(metric) is not None]
    vc = [r[metric] for r in ctrl if r.get(metric) is not None]
    if not vt or not vc:
        return {"n": 0, "treat_mean": None, "ctrl_mean": None,
                "effect": 0, "ci_low": 0, "ci_high": 0}
    eff, lo, hi = _boot_ci(vt, vc)
    return {
        "n": min(len(vt), len(vc)),
        "treat_mean": round(statistics.fmean(vt), 3),
        "ctrl_mean": round(statistics.fmean(vc), 3),
        "treat_sd": round(statistics.pstdev(vt), 3),
        "ctrl_sd": round(statistics.pstdev(vc), 3),
        "effect": round(eff, 4),
        "ci_low": round(lo, 4),
        "ci_high": round(hi, 4),
    }


def generation(gen: int, seeds: int, ticks: int, arms=None, tag="") -> dict:
    """One generation = every arm run across `seeds` seeds."""
    arms = arms or ARMS
    t0 = time.time()
    data = {a: run_arm(a, seeds, ticks) for a in arms}
    rec = {
        "gen": gen, "tag": tag, "stamp": time.time(), "seeds": seeds,
        "ticks": ticks, "elapsed": round(time.time() - t0, 1),
        "paradigm_of": {a: PARADIGM_OF.get(a, "?") for a in arms},
        "summary": {
            a: {m: (round(statistics.fmean([r[m] for r in rs if r.get(m) is not None]), 3)
                    if any(r.get(m) is not None for r in rs) else None)
                for m in ("undetected_ticks", "mttd", "attention_artifact",
                          "attention_real", "attention_blind",
                          "attention_wasted_frac", "drain_ratio", "trust",
                          "false_clean", "false_alarm", "local_fixes")}
            for a, rs in data.items()
        },
        "raw": {a: rs for a, rs in data.items()},
    }
    os.makedirs(RESULTS, exist_ok=True)
    with open(os.path.join(RESULTS, f"gen{gen:03d}{('_'+tag) if tag else ''}.json"), "w") as f:
        json.dump(rec, f)
    return rec


def judge_all(rec: dict, hypotheses: list) -> list:
    """Evaluate each registered hypothesis against this generation."""
    out = []
    for hid in hypotheses:
        h = prereg.get(hid)
        if not h:
            continue
        t, c = h["arms"]
        if t not in rec["raw"] or c not in rec["raw"]:
            out.append({"hid": hid, "verdict": "INCONCLUSIVE-BLIND",
                        "why": f"arms {t}/{c} not present in this generation"})
            continue
        st = compare(rec["raw"][t], rec["raw"][c], h["metric"])
        out.append(prereg.judge(hid, st, results_stamp=rec["stamp"]))
    return out


if __name__ == "__main__":
    gen = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    seeds = int(sys.argv[2]) if len(sys.argv) > 2 else 60
    ticks = int(sys.argv[3]) if len(sys.argv) > 3 else 400
    rec = generation(gen, seeds, ticks)
    print(json.dumps(rec["summary"], indent=2))
