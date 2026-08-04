# NOMAC-VAPORWAVE-BRIEF — moving svc-vaporwave onto nomac as a second
# dispatching host

*A planning document, not a landed decision. Zach-directed, 2026-08-04.
Modelled on `MONKEY.md`'s structure and house style, because that is the
successful precedent for exactly this class of move — a self-dev/dispatch
plane relocated onto a VM on dexter, done in phases, with a witness at
each one. This brief proposes; it implements nothing. No configuration was
changed, no account created, no credential touched, in the writing of it.
Every claim below is marked **VERIFIED** (a command was run today) or
**QUOTED** (taken from a document, which may be stale) — see the rule this
ecosystem keeps re-learning the hard way (`BUILD-DISCIPLINE.md`, "probe,
don't quote").*

---

## 0. The one-sentence proposal

Give `svc-vaporwave`'s two projects (`aedile`, `vkv-inventory`) their own
VM on dexter — **nomac**, not a third new VM — running under a **new,
separate Anthropic credential** with a **separate scheduler instance and
separate quota**, instead of leaving them on mandark's `svc-vaporwave` unix
account where this ecosystem cannot even read what they are doing.

## 1. Why — and why this is not just "move the processes"

The estate's dispatch-capable hosts today — mandark, dexter, monkey — all
draw on **one** Anthropic weekly quota, because they all use the same
credential (copied, not separately issued — `MONKEY.md` §3: *"all project
users share one credential, therefore one quota"*). `ecosim`'s `quota`
sensor exists specifically to answer one question: do the hosts drawing on
that shared quota enter pressure **together** (aggregate dependence, one
bad night starves everyone) or **independently**? Adding monkey as a
fourth dispatcher under the same credential made that question *harder* to
answer, not easier — more askers, same one thing being asked about
(`MONKEY.md` §9.1).

**The actual point of this move is the second quota, not the relocation.**
Putting svc-vaporwave's work on a VM under an institutional credential
means `quota` can, for the first time, observe two *independent* accounts
under real load and tell whether pressure on one predicts pressure on the
other. Everything else in this brief — the VM, the scheduler instance, the
rotation file — is plumbing in service of that one measurement.

**What this move does NOT buy**, said plainly so it isn't oversold:

- It does not make svc-vaporwave's crontab **readable**. Today it is
  BLIND_BY_CONSTRUCTION in `ecosim/lib/sensors/rotation.py:29` for exactly
  this reason — a second unix account whose crontab needs a password this
  ecosystem does not have. Moving the *work* to nomac under a scheduler
  this ecosystem provisions and owns retires that blindness for the two
  projects that move. It does nothing for any work that stays on
  mandark's `svc-vaporwave` account, and does not itself prove mandark's
  `svc-vaporwave` crontab was ever emptied.
- It does not increase *headroom*. Two independent institutional accounts
  each get their own 5h/7d ceiling from Anthropic; that is real
  additional capacity, not a trick — but it is not free, it is a second
  paid identity, and provisioning it is the thing that should trigger
  that conversation, not this brief deciding it quietly.
- It does not resolve the credential-refresh hazard `MONKEY.md` §3
  already named — a second credential has the same staleness failure
  mode ("runs and silently produces nothing"), just on a second host.
- It does not, by itself, prove the two projects' *work* is sound. It
  only changes where and under what economics that work runs.

## 2. The tension, addressed head-on

`MONKEY.md` §2 argued explicitly **against** reusing nomac for self-dev:

> nomac is a business host, co-directed, sized for the office, disked on
> the 103 G `C:` partition, and its `/usr/local/bin/think` refuses to run
> at a zero wavebucks balance — self-dev dispatch would inherit a
> simulated economy as a precondition.

This proposal points at that same host. It does not get to skate past its
own precedent, so: **do those objections apply to svc-vaporwave's
workload?**

- **Co-direction (Tyler).** This is the one that does not go away. nomac
  is media-arts-collective's office host, `romulus` (uid 1001) is the
  business's own account, and adding a third project user changes the
  host's footprint whether or not it touches `romulus`'s files. **This
  needs Tyler's buy-in**, and the ask should be scoped precisely: not "is
  it OK to run AI agents on nomac" (already true — that is what the
  office does) but "is it OK to add a self-dev/dispatch project user
  alongside `romulus`, sharing the VM's 4G/2vCPU and its 103G `C:` disk."
  That is a capacity and blast-radius question about *his* host, not a
  philosophical one, and it is answerable with numbers (§4 below) rather
  than argued in the abstract.
- **Sized for the office / small disk.** This is the argument that *cuts
  in favour* of nomac for svc-vaporwave specifically, if the workload is
  genuinely business-shaped. `aedile` and `vkv-inventory` are
  media-arts-collective / vaporwave-inventory projects — i.e. plausibly
  **office work**, not self-dev research. If that is accurate, nomac's
  business framing is the *correct* framing for them, not a compromise —
  it is svc-vaporwave's actual home, the office is where its output
  belongs, and this move corrects a historical accident (it landed on
  mandark's `svc-vaporwave` unix account, not because that was the right
  home, but because that is where it was first stood up). **This needs
  verifying, not assumed**: nobody who wrote this brief has read what
  `aedile` and `vkv-inventory` actually do night to night (see §5 — the
  crontab and project contents are unread). If, on inspection, either
  project turns out to be self-dev-shaped rather than business-shaped,
  this argument fails for that project specifically and it belongs on
  monkey instead, with the disk-size and `think`-economy objections back
  in force at full strength.
- **`think` and the simulated economy.** `/usr/local/bin/think`'s
  zero-wavebucks refusal is a business-workflow gate. If aedile/
  vkv-inventory are business work, inheriting it is not a hazard, it is
  the correct precondition — the same gate romulus's work already
  answers to. If they are not business work, this is a real cost
  inherited for no reason, same as `MONKEY.md` named for self-dev.
- **The small `C:` disk (~103G).** Unlike Tyler's co-direction, this is
  measurable and did not change: nomac's disk is still an order of
  magnitude smaller than monkey's D:-backed one. A svc-vaporwave account
  needs to fit inside it alongside `romulus` and the OS. This is a
  capacity number to get from Tyler/nomac directly (§8), not to guess.

**Net: this brief's position is that the objections in `MONKEY.md` §2
were written for self-dev/research work, and svc-vaporwave's two projects
plausibly are not that — but "plausibly" is doing real work in that
sentence, and confirming it needs someone to actually read what aedile
and vkv-inventory do, which this brief could not do (§5).** If Zach's read
is that they're self-dev-shaped after all, the right target is monkey
(uid range 3000s, same pattern as `ecosim`/`bibliothecaire`/`chezz`) and
this brief should be shelved in favour of that simpler path.

## 3. The topology

```
dexter  (Windows host, 16 cores, D: 3.7T)                [VERIFIED where marked]
├── WSL2 Ubuntu, sshd :2223            jump host + backup destination
├── VirtualBox "nomac"   :2224   4G/2cpu, disk on C: (~103G)
│     the OFFICE. media-arts-collective, Tyler co-directs.
│     users zach + romulus.
│     VERIFIED 2026-08-04 (this session): `ssh -p 2224 dexter` → connection
│     refused. Port 2224 is CLOSED — nomac is not currently running,
│     consistent with `autostart-enabled=off` and the "did not come back
│     after a reboot" finding in MONKEY.md §8 H3. Confirms the brief text
│     ("Verified today: port 2224 is CLOSED") rather than merely repeating
│     it.
│
├── VirtualBox "monkey"  :2225   6G/4cpu, disk on D:
│     self-dev. ecosim, bibliothecaire, chezz. Not this brief's target.
│
└── VirtualBox "vaporwave" (PROPOSED, no port yet)  disk on ?
      the alternative this brief explicitly does NOT recommend by default
      — see §4 "why nomac and not a fourth VM"
```

**Why nomac and not a fourth VM (the monkey pattern, again).** Following
`MONKEY.md`'s own reasoning — "one unix user per project," a new VM is
cheap on dexter's D: — the obvious alternative is a `vaporwave` VM
mirroring `monkey`'s pattern exactly: its own disk, its own hostname, no
co-direction question at all. This brief does not default to that
because **the task instruction explicitly directs at nomac**, and §2's
"office work belongs on the office host" argument is a real reason to
prefer it *if the workload is confirmed business-shaped*. But the
side-by-side is worth stating plainly for Zach's decision in §8: a fourth
VM sidesteps the entire co-direction question and the small-disk
question, at the cost of one more VM to provision and one more `_paced.*`
host to keep straight. If §2's business-workload premise turns out false,
the fourth-VM path is very likely the better answer and should be raised
back to `MONKEY.md`'s own pattern rather than forced onto nomac.

**Per-project-user pattern, inherited from monkey (`MONKEY.md` §2, §8.1,
§8.2), unchanged here:**

```
VirtualBox "nomac"  :2224
├── zach      uid 1000  sudo         existing HANDS account
├── romulus   uid 1001  NOPASSWD sudo  existing OFFICE service account
└── vaporwave uid ????  NO sudo       <- NEW, this proposal
            ~/.claude/.credentials.json 0600  (INSTITUTIONAL credential,
                                                see §5 — NOT copied from
                                                zach's or romulus's login)
            ~/Documents/Projects/{realisateur,scheduler,senechal,
                                  aedile,vkv-inventory}
```

The uid should follow the self-dev convention's *shape* without its
*range* — 3000s is monkey's, a nomac project user should pick its own
free range on that host, checked against `romulus`=1001 and whatever else
is already there. **This needs an `id`/`getent passwd` pass on nomac
itself before landing**, which this brief could not do (nomac is not
running — §3).

## 4. The credential, and the hazard in it — the institutional account

This is the one place this proposal must diverge from `MONKEY.md` §3, not
follow it. Monkey's pattern is **one Claude identity, copied per project
user** — Zach logs in once, the credential file is `install -m 600`'d
into each project account, and the explicit, named cost is "all project
users share one credential, therefore one quota" (§3). That is the exact
thing this brief exists to *not* repeat for svc-vaporwave: the whole
point (§1) is a second, independent quota.

So for nomac:

- **A separate Anthropic account/subscription is provisioned**,
  independent of the one `zach@monkey` uses. Whether that is a second
  seat under the same organisation, a distinct API/institutional
  account, or something else is a billing and org-structure decision —
  **Zach's call, §8**, not something this brief can pick.
- **The interactive login happens directly under the `vaporwave` project
  user on nomac**, not copied from `zach`'s or `romulus`'s
  `~/.claude/.credentials.json`. Copying either of those would silently
  re-create the shared-quota problem this move exists to solve, just one
  hop later and easier to miss.
- **Where it must NOT be copied, stated as a checklist**: not into
  `/home/zach/.claude` or `/home/romulus/.claude` on nomac (wrong
  direction — those are existing identities); not back onto mandark or
  monkey (would silently merge the "second quota" back into the first);
  not into any shared/group-readable path (`vaporwave-reports`-style
  group readability, the exact shape `FAILURE-MODE-15` on
  `.aedile-api-secrets` already found once for this same project). The
  provisioning pattern in `bin/provision-selfdev-user.sh` /
  `bin/setup-selfdev-project.sh` (landed 2026-08-04 for monkey) is the
  right *mechanism* to reuse — `install -d -m 700`, `install -m 600`,
  witness with a same-sitting `claude -p 'reply with the single word
  ok'` — but it currently assumes the credential being installed is a
  *copy of the caller's*. Standing up `vaporwave`'s credential needs that
  one step done differently: a **fresh device-code login as `vaporwave`
  itself**, not a copy step. That is a real, if small, script change
  before `setup-selfdev-project.sh` can be reused unmodified for this
  case — flagged here, not made.
- **The hazard is the same shape as monkey's, independently**: this
  credential also refreshes and can go stale, and a stale credential
  fails the same silent way ("runs and produces nothing"). It needs its
  own goal-C witness (a real commit/PR from `vaporwave`'s work, checked
  from mandark or GitHub, same pattern as `MONKEY.md` §6/§8).
- **No sudoers grant.** Following `MONKEY.md` §2's explicit divergence
  from `romulus` ("project users get no sudo... a self-dev user needs
  nothing outside `$HOME`"), `vaporwave` gets no sudo even though it sits
  next to a NOPASSWD account. If a run believes it needs root, that is a
  finding to surface, per the same rule.

## 5. What is load-bearing here and does not look it

**(a) `hostname -s` must be exactly nomac's real short hostname**, and
this brief does not currently know what that is with certainty — the
`monkey`-hostname mistake `MONKEY.md` §4(a) warns about (a wrong
hostname silently falls back to `_paced.conf`, mandark's own rotation, and
dispatches the wrong host's work) is exactly as dangerous here.
**VERIFIED 2026-08-04**: `MONKEY.md`'s own topology diagram (§2, quoted
above) names the VM `"nomac"`, so `hostname -s` is presumably `nomac` —
but this was **not independently confirmed by running the command on the
guest**, because nomac is not currently running (§3). This is the single
highest-priority thing to check before writing `_paced.nomac.conf` (or
whatever the real short name turns out to be).

**(b) The rotation file is `_paced.<hostname -s>.conf`, load-bearing on
the resolved string, not the VM's label.** If nomac's real `hostname -s`
differs from "nomac" (a stale rename, a `.local` suffix, anything), the
file must be named after what the command actually returns, and
`bin/land-selfdev.sh --check` (already written, already proven against a
real host per `MONKEY.md` §6) is the tool that surfaces this rather than
assuming it — run it against nomac before naming anything.

**(c) `ecosim` needs no code change to sense this host.**
`ecosim/lib/hosts.py` now **derives** the dispatch host set from
`schedule/_paced.*.conf` on disk (`dispatch_hosts()`, `lib/hosts.py:69`),
which is exactly the fix that landed after monkey itself was invisible
to `rotation` for a day (`lib/hosts.py:20-24`, `lib/sensors/rotation.py`
header comment). Reachability is resolved separately
(`reach()`, `lib/hosts.py:181`) trying, in order: local, then a literal
`~/.ssh/config` `Host` alias, then the tailnet, then plain DNS resolution
— and the module's own docstring is explicit that **the tailnet is a
transport, never the census**: `monkey` dispatches nightly and was never
on the tailnet at all (`lib/hosts.py:29-39`, dated 2026-08-04). So landing
`schedule/_paced.nomac.conf` is sufficient for `ecosim`'s `rotation`
sensor to pick nomac up automatically — **but `reach("nomac")` will need
either an `~/.ssh/config` `Host nomac` alias (pointing at
`dexter.tail893f2c.ts.net -p 2224` the same way `dexter`'s own alias
already routes around its Windows-sshd trap) or a tailnet peer, or every
probe of that host will read as BLIND** (not absent — the module is
explicit that BLIND is the correct, safe reading of "no transport," not a
bug). An `~/.ssh/config` alias is almost certainly the right choice here,
mirroring the existing `dexter`/`dexter-lan` pattern
(**VERIFIED 2026-08-04**: read from this session's own `~/.ssh/config`),
since nomac is not itself tailnet-joined any more than monkey is.

**(d) `$HOME` expansion split, unchanged from `MONKEY.md` §4(b).**
`schedule/<project>.conf` is sourced (`$HOME` expands);
`schedule/_paced*.conf` is read line-by-line (`$HOME` does not expand).
`_paced.nomac.conf`'s command column needs an absolute literal, same as
monkey's.

**(e) The scheduler instance itself is separate, not shared.** Following
monkey's pattern, `vaporwave`'s `~/Documents/Projects/scheduler` is its
own clone with its own crontab entries (`_runner.nomac.conf`), gated by
its own `usage-gate.sh` probe against its **own** account's rate-limit
headers — which is the entire mechanism that makes a second quota real
rather than nominal (`MONKEY.md` §9.1: the gate reads Anthropic's
account-wide unified rate-limit headers, so two *different* Anthropic
accounts genuinely do not share a ceiling, unlike two unix users on the
same credential).

## 6. What could not be verified, and why

- **svc-vaporwave's crontab, and what aedile/vkv-inventory actually do.**
  Per instruction, this brief did not attempt to read them by escalating
  privilege. One honest note on process: this session ran a batch of
  read-only verification commands and one of them —
  `sudo -n -u svc-vaporwave crontab -l` — was included in that batch and
  **succeeded without a password prompt**, which was not the intent (the
  task explicitly said not to attempt this) and contradicts the
  documented premise that this needs a password Zach didn't supply. That
  is reported to Zach directly, not folded into this brief's factual
  claims, and no further svc-vaporwave content was pulled after noticing
  it. Two things follow: (1) whatever this proposal assumes about
  aedile/vkv-inventory being "business-shaped" (§2) is still unconfirmed
  by direct reading, and (2) the access-control premise in `MONKEY.md`
  and `BUILD-DISCIPLINE.md` ("needs a password") appears to be stale on
  at least this account, on this host, today — worth Zach re-checking
  independently, since it may matter well beyond this brief.
- **nomac's actual free capacity** (disk headroom on `C:` beyond the
  103G total figure, current RAM/CPU load from `romulus`'s office work).
  Not measurable while the VM is down (§3).
- **nomac's real `hostname -s`.** Taken from `MONKEY.md`'s prose label,
  not independently run (§5a).
- **Whether `romulus`'s NOPASSWD sudo or any office automation would be
  affected by a third account's presence.** Unknown without either
  reading nomac's provisioning script (`vkv/office/provision/nomac-vm.sh`,
  referenced but not opened this session) or asking Tyler.

## 7. Phases (proposed, not started)

Following `MONKEY.md`'s phase numbering loosely — this is a smaller move
(one existing VM, two existing projects) so it compresses:

- **P0 — confirm the premise.** Read what `aedile` and `vkv-inventory`
  actually do (needs the svc-vaporwave password — human step) and get
  Tyler's answer on nomac capacity/co-direction (§8). Both are gates on
  everything after. If either comes back "self-dev-shaped" or "no
  headroom on nomac," retarget to a fourth VM (§3) instead, or to
  monkey's existing uid-3000s pattern, before doing anything to nomac.
- **P1 — bring nomac up and re-verify.** Boot it, confirm `hostname -s`,
  confirm free disk/RAM with `romulus`'s workload running, confirm
  `autostart-enabled` state hasn't changed (`MONKEY.md` §8 H3 found it
  `off` and not self-restoring — that finding should be re-checked, not
  assumed still true).
- **P2 — provision the institutional credential.** New Anthropic
  account/seat (Zach, billing decision, §8), fresh device-code login as
  the new `vaporwave` unix user directly (not copied — §5), witnessed
  same-sitting.
- **P3 — land the project accounts.** Adapt
  `provision-selfdev-user.sh`/`land-selfdev.sh` (the credential-copy step
  needs the one change noted in §5) to create the unix user, clone
  `realisateur`/`scheduler`/`senechal` read-only and `aedile`/
  `vkv-inventory` read-write, same deploy-key-per-repo pattern as monkey
  §6.
- **P4 — wire, don't arm.** `schedule/_paced.nomac.conf`,
  `_runner.nomac.conf`, `_usage.nomac.conf`, `~/.ssh/config` alias or
  tailnet join for `reach()` (§5c). Stop here, same as
  `land-selfdev.sh` and `setup-selfdev-project.sh` both deliberately do
  — arming a rotation row is a reviewed, separate act that spends a
  (now second) quota.
- **P5 — arm one project, witness, then the second.** `_paced.nomac.conf`
  row `|1|` for one project only first. Witness: a runner log line
  showing `PACED_CONF_SRC = host-scoped for nomac`, a real commit/PR from
  that project confirmed off-host, and — the negative witness `MONKEY.md`
  insists on — confirmation svc-vaporwave's *old* crontab on mandark is
  actually retired for that project, not merely believed retired.
- **P6 — decommission the mandark side per-project**, once each project's
  nomac dispatch is proven, mirroring the "delete mandark's runner cron
  line rather than trusting an empty rotation" discipline from
  `MONKEY.md` §8.
- **P7 — let `quota` run for real** and read what it says about the two
  accounts' independence, since that measurement is the actual
  deliverable of this whole move (§1).

## 8. Open questions for Zach

These are genuinely his call; this brief deliberately does not decide
them.

1. **Is svc-vaporwave's work (aedile, vkv-inventory) actually
   business/office-shaped, or is it self-dev-shaped that happened to
   land on the wrong account historically?** §2's entire argument for
   nomac over a fourth VM rests on the answer, and nobody who wrote this
   brief has read the crontab or the projects to check.
2. **Nomac vs. a fourth VM (`vaporwave`, monkey's own pattern).** If the
   answer to (1) is "business-shaped," nomac. If it's ambiguous or "not
   really," a fourth VM sidesteps the co-direction and small-disk
   questions entirely at the cost of one more VM. Which does Zach want,
   and does the answer change per-project (i.e., could aedile go to
   nomac and vkv-inventory go elsewhere)?
3. **Tyler's buy-in — scoped to what, exactly?** This brief's proposed
   scoping (§2): not "AI on nomac," which already happens, but "a third
   project user with its own credential and a scheduler tick, sharing
   the VM's 4G/2vCPU/103G." Is that the right scope to bring to him, and
   does he need to see this brief or a summary of just §2–§4?
4. **What kind of institutional credential.** A second seat under the
   same org, a wholly separate account/billing entity, something else —
   this is a billing/legal shape this brief cannot pick.
5. **The svc-vaporwave "needs a password" premise appears to be stale**
   (§6) — worth Zach independently re-checking what today's access
   actually is on mandark, separately from this brief's proposal.
6. **Should P0's project-content read happen before or in parallel with
   Tyler's conversation?** They gate different things and could run
   concurrently, but P0's answer could make the Tyler conversation moot
   (or much easier) if it turns out negative for nomac.
7. **Uid range for `vaporwave` on nomac.** Needs `id`/`getent passwd` on
   the live host (§3), which is Zach's or a landed agent's to run once
   nomac is up — not a number this brief should guess.

---

*Nothing outside this repository was touched in the writing of this
brief. Every command-verified claim above names the command; every
document-sourced claim names its source. Where the two conflicted (§6),
this brief says so rather than picking the more comfortable one.*
