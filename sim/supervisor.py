#!/usr/bin/env python3
"""
supervisor.py -- the unattended overnight driver.

Runs generation after generation on a PRE-REGISTERED mutation schedule,
judges every hypothesis mechanically after each one, and writes a rolling
STATUS.md that a check-in can read in five seconds.

DESIGN COMMITMENTS, each for a stated reason:

1. NO AI, NO NETWORK. The usage-paced runner gates Tier 2 dispatch on burn
   rate (observed HOLD at 14% of the 7d window tonight). A study that spent
   tokens would starve the very batch jobs it is studying. This is pure
   stdlib arithmetic and runs at nice 19.

2. THE MUTATION SCHEDULE IS FIXED IN ADVANCE. Generations sweep the
   disturbance regime -- break_rate, drift_rate, attention, blind_cure_p --
   so a result cannot be an artifact of one lucky parameter choice. Picking
   the next mutation after seeing the last result is how you garden a
   p-value into existence; the schedule removes that freedom from me.

3. IT SURVIVES ME. If my session dies, the science continues: this is a
   detached process writing to disk. The hourly check-ins are ANALYSIS,
   not execution. Nothing in the experimental loop depends on a model
   being awake to drive it.

4. EVERY GENERATION LOG OPENS WITH THE HYPOTHESIS, printed by
   prereg.announce(). Zach's instruction was "always name your hypothesis
   out loud"; this is the mechanism that makes it impossible not to.

5. IT REPORTS BLIND. A generation whose falsifier cannot be evaluated is
   INCONCLUSIVE-BLIND, never silently absent -- the same discipline the
   study is about.
"""
from __future__ import annotations
import json, os, sys, time, itertools
import experiment, prereg
from ecosim import ARMS

HERE = os.path.dirname(os.path.abspath(__file__))
RESULTS = os.path.join(HERE, "results")
STATUS = os.path.join(RESULTS, "STATUS.md")
LOG = os.path.join(RESULTS, "supervisor.log")

HYPOS = ["H1", "H1b", "H2", "H3", "H4", "H5", "H6"]

# ---- the pre-registered mutation schedule ------------------------------
# Each entry is a disturbance regime. The point is robustness: if the
# ranking of arms is stable across every regime, it is not a parameter
# artifact. If it flips somewhere, THAT is the finding -- the boundary
# condition is more interesting than the main effect.
MUTATIONS = [
    ("baseline",      {}),
    ("high_break",    {"break_rate": 0.06}),
    ("low_break",     {"break_rate": 0.005}),
    ("high_drift",    {"drift_rate": 0.02}),
    ("no_drift",      {"drift_rate": 0.0}),
    ("scarce_zach",   {"attention": 1}),
    ("rich_zach",     {"attention": 5}),
    ("weak_cure",     {"blind_cure_p": 0.2}),
    ("idea_flood",    {"idea_rate": 0.6}),
    ("tight_quota",   {"slots_per_tick": 2}),
]


def log(msg: str):
    os.makedirs(RESULTS, exist_ok=True)
    line = f"[{time.strftime('%Y-%m-%dT%H:%M:%S')}] {msg}"
    with open(LOG, "a") as f:
        f.write(line + "\n")
    print(line, flush=True)


def write_status(history: list):
    """A five-second read. Deliberately small -- an hourly check-in that
    needs to parse megabytes will stop happening."""
    lines = ["# ecosim -- rolling status", "",
             f"updated: {time.strftime('%Y-%m-%d %H:%M:%S')}",
             f"generations complete: {len(history)}", ""]

    if history:
        last = history[-1]
        lines += [f"## latest generation: {last['gen']} (regime: {last['tag']})", "",
                  "| arm | paradigm | undetected | wasted% | drain | trust |",
                  "|---|---|---|---|---|---|"]
        for a, m in last["summary"].items():
            lines.append(
                f"| {a} | {last['paradigm_of'].get(a,'?')} | {m['undetected_ticks']:.0f} "
                f"| {m['attention_wasted_frac']:.2f} | {m['drain_ratio']:.3f} | {m['trust']:.2f} |")
        lines.append("")

    # verdict tally across ALL generations -- the confirmatory record
    tally = {}
    for h in history:
        for j in h.get("judgments", []):
            tally.setdefault(j["hid"], []).append(j["verdict"])
    lines += ["## hypothesis verdicts (across all regimes)", "",
              "| id | paradigm | SUPPORTED | FALSIFIED | INCONCL | claim |",
              "|---|---|---|---|---|---|"]
    for hid in HYPOS:
        v = tally.get(hid, [])
        h = prereg.get(hid) or {}
        lines.append(
            f"| {hid} | {h.get('paradigm','?')} | {v.count('SUPPORTED')} | "
            f"{v.count('FALSIFIED')} | "
            f"{sum(1 for x in v if x.startswith('INCONCL'))} | "
            f"{h.get('claim','')[:70]}... |")
    lines.append("")
    lines.append("Robustness reading: a hypothesis is only credible if it holds "
                 "across REGIMES, not generations. Repeated SUPPORTED in one "
                 "regime is one result measured many times.")
    with open(STATUS, "w") as f:
        f.write("\n".join(lines))


def main():
    seeds = int(os.environ.get("SEEDS", "60"))
    ticks = int(os.environ.get("TICKS", "400"))
    rounds = int(os.environ.get("ROUNDS", "6"))
    label = os.environ.get("LABEL", "main")

    log(f"supervisor start label={label} seeds={seeds} ticks={ticks} "
        f"rounds={rounds} mutations={len(MUTATIONS)}")
    for hid in HYPOS:
        log("\n" + prereg.announce(hid))

    history = []
    gen = int(os.environ.get("GEN0", "10"))
    for rnd in range(rounds):
        for tag, mut in MUTATIONS:
            t0 = time.time()
            # apply the mutation to every arm
            data = {}
            for a in ARMS:
                data[a] = experiment.run_arm(a, seeds, ticks, overrides=mut)
            rec = {
                "gen": gen, "tag": f"{label}:{tag}", "round": rnd,
                "stamp": time.time(), "seeds": seeds, "ticks": ticks,
                "mutation": mut, "elapsed": round(time.time() - t0, 1),
                "paradigm_of": {a: __import__("ecosim").PARADIGM_OF.get(a, "?") for a in ARMS},
                "summary": {
                    a: {m: (round(sum(r[m] for r in rs if r.get(m) is not None) /
                                 max(1, sum(1 for r in rs if r.get(m) is not None)), 3)
                            if any(r.get(m) is not None for r in rs) else None)
                        for m in ("undetected_ticks", "mttd", "attention_artifact",
                                  "attention_real", "attention_blind",
                                  "attention_wasted_frac", "drain_ratio", "trust",
                                  "false_clean", "false_alarm", "local_fixes")}
                    for a, rs in data.items()},
                "raw": data,
            }
            rec["judgments"] = experiment.judge_all(rec, HYPOS)
            os.makedirs(RESULTS, exist_ok=True)
            with open(os.path.join(RESULTS, f"gen{gen:03d}_{label}_{tag}.json"), "w") as f:
                json.dump(rec, f)
            slim = dict(rec); slim.pop("raw")
            history.append(slim)
            with open(os.path.join(RESULTS, f"history_{label}.json"), "w") as f:
                json.dump(history, f, indent=1)
            write_status(history)
            vs = " ".join(f"{j['hid']}={j['verdict'][:5]}" for j in rec["judgments"])
            log(f"gen{gen} [{label}:{tag}] {rec['elapsed']}s :: {vs}")
            gen += 1
    log(f"supervisor done label={label} generations={len(history)}")


if __name__ == "__main__":
    main()
