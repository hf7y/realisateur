#!/usr/bin/env python3
"""
ecosim.py -- a toy cybernetic model of THIS ecosystem.

Pure stdlib, deterministic given a seed, no AI, no network. It is designed
to run for hours on a nice-19 background process without competing with the
scheduler's own batch jobs for either CPU or API quota.

=======================================================================
THE PRINCIPLE (stated before the model, because the model encodes it)
=======================================================================
Ashby's Law of Requisite Variety is normally quoted at the EFFECTOR:
"only variety can destroy variety" -- the regulator R must have at least
as many distinguishable responses as the disturbance D has states, or some
disturbance passes through to the essential variables unregulated.

The claim this simulator exists to test is that the law binds identically,
and independently, at the SENSOR:

    A regulator cannot respond differently to two world-states that its
    sensor maps onto the same symbol. Sensor variety therefore upper-bounds
    effector variety, no matter how capable the effector is.

This has a sharp, counter-intuitive consequence which is the whole point:

    If the sensors' blind spots are CORRELATED, adding more sensors does
    not add variety. Reconciling N sensors that share a domain restriction
    yields exactly the variety of one of them. The only remedy that adds
    variety is adding an OUTPUT SYMBOL -- the ability to say "I could not
    look" as something distinct from "I looked and saw nothing."

The ecosystem currently has, at every sensor, a two-symbol alphabet:
{OK, ALARM}. Three world-states -- ABSENT (really nothing there),
UNREACHABLE (could not read the domain), UNEXAMINED (never looked) -- all
map to OK. That is a 3->1 collapse, and it is why `scheduler status`
reports aedile as never-run while aedile has succeeded nightly.

=======================================================================
THE ANATOMY (mapped to UNIVERSE.md's own organism model)
=======================================================================
  Disturbance  : idea arrival, job failure, account drift, domain erosion
  Effector     : scheduler dispatch (quota-gated, weight-ranked)
  Proprioceptor: the surveys -- each reads a DOMAIN and emits a SYMBOL
  Regulator    : Zach's attention (the scarce organ) + weights + parking
  Essential
  variable     : the active backlog draining, and true failures detected

Zach is modelled as BOTH environment (source of disturbance) and the
rate-limiting organ (finite attention per tick), exactly as UNIVERSE.md
describes him. This is the model's most important structural commitment:
alarms are not free. Every artifact alarm consumes the same scarce
resource a real failure would have needed.
"""

from __future__ import annotations
import random
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional


# ----------------------------------------------------------------- symbols

class Symbol(str, Enum):
    """A sensor's output alphabet. The independent variable of this study."""
    OK = "OK"          # "I read the domain and it is healthy"
    ALARM = "ALARM"    # "I read the domain and something is wrong"
    BLIND = "BLIND"    # "I could not read the domain" -- the added symbol


class World(str, Enum):
    """Ground truth a sensor is trying to report on."""
    HEALTHY = "HEALTHY"
    BROKEN = "BROKEN"          # a real failure, deserves attention
    UNREACHABLE = "UNREACHABLE"  # domain exists but sensor cannot read it


# ----------------------------------------------------------------- entities

@dataclass
class Project:
    """An organ. Has its own backlog, milestone bar, and dispatch surface."""
    name: str
    account: str = "primary"     # which account dispatches it
    weight: int = 1
    active: list = field(default_factory=list)
    parked: list = field(default_factory=list)
    broken: bool = False         # ground-truth: is its job actually failing?
    broken_since: Optional[int] = None
    dark: bool = False           # not dispatching at all
    commits: int = 0

    @property
    def backlog(self) -> int:
        return len(self.active)


@dataclass
class Sensor:
    """
    A proprioceptor. The two variables that matter:

      domain    -- the set of accounts it can actually read. THIS is where
                   the real ecosystem's bug lives: every survey reads
                   $HOME, i.e. domain == {"primary"}.
      alphabet  -- whether BLIND is available to it.

    A sensor without BLIND, asked about a project outside its domain, must
    answer OK or ALARM. Both are lies. Which lie it tells is the
    `fail_toward` parameter, and BUILD-DISCIPLINE pattern 14 records that
    these tools fail toward ALARM -- the expensive direction, because alarm
    is routed to the scarcest organ.
    """
    name: str
    domain: set
    can_blind: bool = False
    fail_toward: Symbol = Symbol.ALARM

    def read(self, p: Project) -> Symbol:
        if p.account not in self.domain:
            # The world-state is UNREACHABLE. What can this sensor say?
            if self.can_blind:
                return Symbol.BLIND
            return self.fail_toward          # a 3->1 collapse, in one line
        if p.broken:
            return Symbol.ALARM
        return Symbol.OK


@dataclass
class Zach:
    """The scarce organ. Finite attention; artifact alarms consume it."""
    attention_per_tick: int = 2
    spent_on_artifact: int = 0
    spent_on_real: int = 0
    spent_on_blind: int = 0
    trust: float = 1.0   # falls as artifacts accumulate -- the alarm-fatigue term


# ----------------------------------------------------------------- the model

class Ecosystem:
    def __init__(self, cfg: dict, seed: int = 0):
        self.rng = random.Random(seed)
        self.cfg = cfg
        self.t = 0
        self.zach = Zach(attention_per_tick=cfg.get("attention", 2))

        accounts = cfg.get("accounts", ["primary", "service"])
        n = cfg.get("n_projects", 18)
        self.projects = []
        for i in range(n):
            # ~2 of 18 live on the service account, matching aedile+vkv today
            acct = accounts[1] if (i % 9 == 8 and len(accounts) > 1) else accounts[0]
            self.projects.append(Project(name=f"p{i:02d}", account=acct))

        self.sensors = self._build_sensors(cfg)

        # metrics
        self.undetected_ticks = 0     # sum over ticks of live-but-unseen breakages
        self.detected = 0
        self.detect_latencies = []
        self.false_clean = 0          # sensor said OK about an unreadable domain
        self.false_alarm = 0          # sensor said ALARM about a healthy/unreadable one
        self.dispatches = 0
        self.ideas_in = 0
        self.ideas_done = 0
        self.local_fixes = 0
        self._deferred = []      # Perrow slack buffer
        self._acked = set()      # alarm acknowledgment (model correction v2)

    def _build_sensors(self, cfg) -> list:
        """
        ARM CONFIGURATION. This is the experiment's independent variable.

        n_sensors  -- the "add more sensors / reconcile them" remedy
                      (realisateur's queued sensor-agree.sh)
        can_blind  -- the null-discriminator remedy (this study's proposal)
        correlated -- whether the sensors share a domain restriction.
                      TRUE is the real ecosystem: every survey is $HOME-
                      scoped, so they are blind in exactly the same place.
        """
        n = cfg.get("n_sensors", 1)
        can_blind = cfg.get("can_blind", False)
        correlated = cfg.get("correlated_blindness", True)
        accounts = cfg.get("accounts", ["primary", "service"])
        out = []
        for i in range(n):
            if correlated:
                dom = {accounts[0]}
            else:
                # decorrelated: each sensor sees a different random subset,
                # so union coverage grows with n. The generous case for the
                # "just add more sensors" remedy.
                dom = set(self.rng.sample(accounts, k=max(1, len(accounts) - 1)))
            # The parallel clone's structural tweak. BUILD-DISCIPLINE
            # pattern 14 observes that these tools fail toward ALARM, and
            # argues that is the expensive direction because alarm is routed
            # to the scarcest organ. That is an ASSERTION about which
            # direction costs more, and it has never been tested. The clone
            # arm flips it: sensors fail toward OK (silent) instead.
            # If failing-silent turns out CHEAPER, the ecosystem's stated
            # reason for treating pattern 14 as its worst shape is wrong.
            ft = Symbol.OK if cfg.get("fail_toward_ok", False) else Symbol.ALARM
            out.append(Sensor(f"s{i}", domain=dom, can_blind=can_blind,
                              fail_toward=ft))
        return out

    # ------------------------------------------------------------ dynamics

    def _disturb(self):
        c = self.cfg
        for p in self.projects:
            # idea arrival -- free intake, Law 1
            if self.rng.random() < c.get("idea_rate", 0.25):
                p.active.append(self.t)
                self.ideas_in += 1
            # a job silently breaks
            if not p.broken and self.rng.random() < c.get("break_rate", 0.02):
                p.broken = True
                p.broken_since = self.t
                self._acked.discard((p.name, Symbol.ALARM))
            # account drift: a project migrates to the service account,
            # leaving the $HOME-scoped sensors' domain without anyone noticing
            if self.rng.random() < c.get("drift_rate", 0.004):
                others = [a for a in c.get("accounts", []) if a != p.account]
                if others:
                    p.account = self.rng.choice(others)

    def _sense(self) -> list:
        """Run every sensor over every project; return the alarm queue."""
        queue = []
        for p in self.projects:
            reads = [s.read(p) for s in self.sensors]
            # Reconciliation rule: ALARM if any sensor alarms; BLIND if any
            # says BLIND and none alarms. This is the generous reading of
            # sensor-agree.sh -- it takes the union, i.e. best possible case.
            if Symbol.ALARM in reads:
                sym = Symbol.ALARM
            elif Symbol.BLIND in reads:
                sym = Symbol.BLIND
            else:
                sym = Symbol.OK

            truth = (World.UNREACHABLE
                     if all(p.account not in s.domain for s in self.sensors)
                     else (World.BROKEN if p.broken else World.HEALTHY))

            if sym is Symbol.OK and truth is not World.HEALTHY:
                self.false_clean += 1
            if sym is Symbol.ALARM and truth is not World.BROKEN:
                self.false_alarm += 1

            if sym in (Symbol.ALARM, Symbol.BLIND):
                # MODEL CORRECTION v2, declared 2026-07-28 AFTER generation 1
                # and BEFORE any hypothesis was judged. Generation 1 let an
                # unreachable project re-fire its alarm every single tick, so
                # the baseline drowned (attention_wasted_frac 0.95) and arm C
                # won trivially. Real operators acknowledge an alarm and stop
                # re-triaging it until its state changes; `ack` models that.
                #
                # This is a correction to an obviously-wrong mechanism, not a
                # tuning-toward-the-desired-answer. It is recorded here, and
                # in results/MODEL_CHANGELOG.md, because a model edited after
                # seeing results and not declared is indistinguishable from
                # HARKing. No hypothesis was altered; all seven remain as
                # registered at 01:35:02, and gen1 is retained as v1 data.
                if self.cfg.get("alarm_ack", True):
                    if (p.name, sym) in self._acked:
                        continue
                    self._acked.add((p.name, sym))
                queue.append((p, sym, truth))
        return queue

    def _regulate(self, queue):
        """
        Zach spends attention. Ordering matters: an ALARM looks urgent, a
        BLIND looks like a gap. The model gives ALARM priority, which is
        what a human actually does -- and is precisely why fail-toward-alarm
        is the expensive failure direction.
        """
        budget = self.zach.attention_per_tick
        queue.sort(key=lambda x: 0 if x[1] is Symbol.ALARM else 1)
        for p, sym, truth in queue:
            if budget <= 0:
                break
            budget -= 1
            if sym is Symbol.ALARM and truth is World.BROKEN:
                # a real fix
                self.zach.spent_on_real += 1
                self.detect_latencies.append(self.t - (p.broken_since or self.t))
                p.broken = False
                p.broken_since = None
                self._acked.discard((p.name, Symbol.ALARM))
                self.detected += 1
            elif sym is Symbol.ALARM:
                # artifact: attention spent on a premise that does not exist
                self.zach.spent_on_artifact += 1
                self.zach.trust = max(0.3, self.zach.trust - 0.01)
            elif sym is Symbol.BLIND:
                # BLIND names the domain it could not read, so the fix is
                # "extend the sensor" -- structural, not per-incident.
                #
                # DECLARED CONFOUND (registered with H1 before any run): if
                # a BLIND always and instantly cures the blind spot, arm C
                # wins trivially and the result is an artifact of the model,
                # not a finding. `blind_cure_p` makes the cure probabilistic
                # and `blind_cost` makes it non-free, so the advantage has
                # to survive a hostile parameterisation. The sensitivity
                # sweep over blind_cure_p is what makes H1 credible.
                self.zach.spent_on_blind += 1
                if self.rng.random() < self.cfg.get("blind_cure_p", 1.0):
                    for sen in self.sensors:
                        sen.domain.add(p.account)
                    self._acked.discard((p.name, Symbol.BLIND))

    def _perrow_device_noise(self, queue):
        """
        PARADIGM 2 -- Perrow. Every added safety device is itself a
        component: it has its own failure modes and adds one more
        unfamiliar interaction. Perrow's corollary is that in an
        interactively complex, tightly coupled system, adding devices makes
        things WORSE. bibliothecaire's normal-accidents brief argues this
        does NOT transfer here, because the ecosystem's guards sit outside
        the control path ("a guard that cannot participate in the accident
        is not the kind of guard Perrow is warning about").

        That argument is a HYPOTHESIS, not a fact, so the model gives it a
        knob and lets it be wrong. `device_fault_p` is the per-device
        chance of emitting a spurious alarm each tick -- i.e. of the guard
        participating in the accident after all.
        """
        p_fault = self.cfg.get("device_fault_p", 0.0)
        if p_fault <= 0:
            return queue
        for s in self.sensors:
            if self.rng.random() < p_fault:
                victim = self.rng.choice(self.projects)
                queue.append((victim, Symbol.ALARM, World.HEALTHY))
        return queue

    def _hayek_local_regulation(self):
        """
        PARADIGM 3 -- Hayek. The centre is not merely slower; it is missing
        an input that cannot be sent to it. Knowledge of the particular
        circumstances of time and place does not survive generalisation, so
        no improvement to CENTRAL sensing can fix the problem in principle.
        The remedy is decentralisation: let the organ that holds the local
        knowledge act on it without routing through the scarce centre.

        In the model: a broken project repairs itself with probability
        `local_fix_p`, consuming NO central attention and requiring NO
        sensor to have seen it. This is adversarial to P1 by construction
        -- if it wins, better central sensors were the wrong investment.
        """
        p = self.cfg.get("local_fix_p", 0.0)
        if p <= 0:
            return
        for pr in self.projects:
            if pr.broken and self.rng.random() < p:
                self.detect_latencies.append(self.t - (pr.broken_since or self.t))
                pr.broken = False
                pr.broken_since = None
                self.detected += 1
                self.local_fixes += 1

    def _effect(self):
        """Scheduler dispatch: quota-gated, weight-ranked. Broken jobs do
        no work but still consume a slot -- that is what makes an undetected
        breakage expensive rather than merely invisible."""
        slots = self.cfg.get("slots_per_tick", 4)
        order = sorted(self.projects, key=lambda p: -p.weight)
        for p in order[:slots]:
            self.dispatches += 1
            if p.broken or p.dark:
                continue
            if p.active:
                p.active.pop(0)
                p.commits += 1
                self.ideas_done += 1

    def step(self):
        self.t += 1
        self._disturb()
        queue = self._sense()
        queue = self._perrow_device_noise(queue)
        # PARADIGM 2 -- coupling. Perrow's second dimension is slack: tight
        # coupling means "no buffer between two items", so a disturbance
        # propagates before anything can attend to it. `slack` defers a
        # fraction of the alarm queue by one tick, which is the coupling
        # intervention (what focus-commit did for the autocommit race)
        # rather than the complexity intervention (adding a sensor).
        slack = self.cfg.get("slack", 0.0)
        if slack > 0 and queue:
            keep, defer = [], []
            for item in queue:
                (defer if self.rng.random() < slack else keep).append(item)
            queue = self._deferred + keep
            self._deferred = defer
        self._regulate(queue)
        self._hayek_local_regulation()
        self._effect()
        # essential-variable accounting: every tick a real breakage stays
        # live is a tick of unregulated disturbance
        self.undetected_ticks += sum(1 for p in self.projects if p.broken)

    def run(self, ticks: int) -> dict:
        for _ in range(ticks):
            self.step()
        return self.metrics()

    def metrics(self) -> dict:
        lat = self.detect_latencies
        return {
            "ticks": self.t,
            "undetected_ticks": self.undetected_ticks,
            "detected": self.detected,
            "mttd": round(sum(lat) / len(lat), 2) if lat else None,
            "false_clean": self.false_clean,
            "false_alarm": self.false_alarm,
            "attention_artifact": self.zach.spent_on_artifact,
            "attention_real": self.zach.spent_on_real,
            "attention_blind": self.zach.spent_on_blind,
            "trust": round(self.zach.trust, 3),
            "ideas_in": self.ideas_in,
            "ideas_done": self.ideas_done,
            "drain_ratio": round(self.ideas_done / self.ideas_in, 3) if self.ideas_in else 0,
            "backlog": sum(p.backlog for p in self.projects),
            "local_fixes": self.local_fixes,
            # The single number this whole study is about: how much of the
            # scarce organ's attention was spent on nothing.
            "attention_wasted_frac": round(
                self.zach.spent_on_artifact /
                max(1, self.zach.spent_on_artifact + self.zach.spent_on_real), 3),
        }


# ----------------------------------------------------------------- arms

def arm(name: str) -> dict:
    """The four experimental arms. A is today's ecosystem."""
    base = dict(n_projects=18, accounts=["primary", "service"], attention=2,
                idea_rate=0.25, break_rate=0.02, drift_rate=0.004,
                slots_per_tick=4, correlated_blindness=True)
    arms = {
        # A -- status quo: one $HOME-scoped sensor, two symbols
        "A_baseline":      dict(base, n_sensors=1, can_blind=False),
        # B -- the queued remedy: more sensors, reconciled. Still 2 symbols,
        #      still correlated blind spots.
        "B_more_sensors":  dict(base, n_sensors=4, can_blind=False),
        # C -- this study's proposal: ONE sensor, but three symbols
        "C_blind_symbol":  dict(base, n_sensors=1, can_blind=True),
        # D -- both
        "D_both":          dict(base, n_sensors=4, can_blind=True),
        # B' -- the charitable version of B: decorrelated blind spots.
        #       Included so the finding cannot be dismissed as rigging.
        "B2_decorrelated": dict(base, n_sensors=4, can_blind=False,
                                correlated_blindness=False),

        # ---- PARADIGM 2: Perrow. Adding devices vs adding slack. ----
        # P_devices: four sensors that can themselves misfire. Perrow's
        #   prediction is that this is WORSE than the baseline.
        "P_devices":       dict(base, n_sensors=4, can_blind=False,
                                device_fault_p=0.05),
        # P_slack: baseline sensing, but coupling loosened. Perrow's
        #   prescription -- buffer, don't instrument.
        "P_slack":         dict(base, n_sensors=1, can_blind=False, slack=0.35),
        # P_both: does slack rescue the added devices?
        "P_slack_devices": dict(base, n_sensors=4, can_blind=False,
                                device_fault_p=0.05, slack=0.35),

        # ---- PARADIGM 3: Hayek. Decentralise instead of sensing. ----
        # H_local: NO sensor improvement at all; organs self-repair locally.
        "H_local":         dict(base, n_sensors=1, can_blind=False, local_fix_p=0.10),
        # H_local_blind: does local regulation still need the BLIND symbol,
        #   or does it make central sensing irrelevant? This is the direct
        #   P1-vs-P3 contest.
        "H_local_blind":   dict(base, n_sensors=1, can_blind=True, local_fix_p=0.10),

        # ---- hostile parameterisation of C, to attack our own result ----
        # C_hostile: BLIND only cures the blind spot 20% of the time.
        "C_hostile":       dict(base, n_sensors=1, can_blind=True, blind_cure_p=0.2),
    }
    return arms[name]


ARMS = ["A_baseline", "B_more_sensors", "B2_decorrelated", "C_blind_symbol",
        "D_both", "C_hostile",
        "P_devices", "P_slack", "P_slack_devices",
        "H_local", "H_local_blind"]

PARADIGM_OF = {
    "A_baseline": "control", "B_more_sensors": "P1_ashby",
    "B2_decorrelated": "P1_ashby", "C_blind_symbol": "P1_ashby",
    "D_both": "P1_ashby", "C_hostile": "P1_ashby",
    "P_devices": "P2_perrow", "P_slack": "P2_perrow",
    "P_slack_devices": "P2_perrow",
    "H_local": "P3_hayek", "H_local_blind": "P3_hayek",
}


if __name__ == "__main__":
    import json, sys
    a = sys.argv[1] if len(sys.argv) > 1 else "A_baseline"
    ticks = int(sys.argv[2]) if len(sys.argv) > 2 else 500
    print(json.dumps(Ecosystem(arm(a), seed=1).run(ticks), indent=2))
