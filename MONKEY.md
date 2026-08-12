# MONKEY.md — where self-dev lives

*The shape of the self-dev plane after it leaves mandark. Sprint opened
2026-08-03, Zach-directed. Sibling to `THE-UNWIRING.md` (which said self-dev
would park) and `THE-FLOOR.md` (which says what must hold before anything is
armed). This one says **where it runs instead**.*

**Status: MILESTONE MET, 2026-08-03. `ecosim` dispatches unattended from monkey
and files its questions as GitHub issues.** All phases have run; §10 records
what that cost and what it did not buy. Every command output
quoted below was captured on the date shown. Where a phase has not run, this
file says so rather than describing what it would print — `THE-FLOOR.md` opens
with a correction about a pass that scored itself by "reading the specification
instead of running the mechanization", and this is the document that most
invites that error. **2026-08-12: mandark stopped serving the `scheduler` verb** — five shims retired, held at 29 undeclared by `bin/path-provenance-audit.ratchet`; clone removal staged, unrun. This supersedes §9's `realisateur`/`scheduler` bullet for `scheduler` alone: monkey holds the only clone, so that bullet's two-host divergence is closed for it by construction. `realisateur#203` carries the probe outputs.

---

## 1. Why

Self-dev is parked everywhere and runs nowhere: six registered participants,
all `enabled=0`, on a paced runner that wakes every six hours and dispatches
nothing. The estate has excellent detection and no actuation, on one laptop
disk at 91%.

The answer is not to un-park on mandark. It is to give self-dev its own host.

**This move sidesteps the U0 gate; it does not close it.** U0
(`realisateur/.scheduler/FOCUS.md:171`) gates **parking seventeen projects** in
favour of an unproven instrument — *"Parking 17 projects in favour of an
unproven instrument is the failure mode."* Relocating self-dev is a different
act and does not require basheur proven. Recorded here explicitly so that no
later reader mistakes a landed `monkey` for a satisfied U0. **U0's box —
token cost measured on both sides, not estimated — remains open.**

## 2. The topology

```
dexter  (Windows host, 16 cores, D: 3.7T)
├── WSL2 Ubuntu 26.04, sshd :2223
│     holds /mnt/d/gardien-media  (261G, mandark's backups)
│     jump host + backup destination. NOT a dispatcher.
│
├── VirtualBox "nomac"   :2224   4G/2cpu, disk on C:
│     the OFFICE. media-arts-collective, Tyler co-directs.
│     users zach + romulus. UNTOUCHED BY THIS SPRINT.
│
└── VirtualBox "monkey"  :2225   6G/4cpu, disk on D:      <- NEW
      hostname -s == "monkey"   (load-bearing, see §4)
      ├── zach    uid 1000  sudo     the HANDS account. No project clones.
      │           ~/.claude/         the ONE interactive login
      └── ecosim  uid 3001  NO sudo  linger=yes, home 0700
                  ~/.claude/.credentials.json 0600  (provisioned copy)
                  ~/Documents/Projects/{realisateur,scheduler,senechal,
                                        senechal-verbs,ecosim}
```

**Why a second VM rather than renaming nomac.** nomac is a business host,
co-directed, sized for the office, disked on the 103 G `C:` partition, and its
`/usr/local/bin/think` refuses to run at a zero wavebucks balance — self-dev
dispatch would inherit a simulated economy as a precondition. What is reused is
the office's **provisioning code**, which is proven, not its instance.

**One unix user per project.** The username is simultaneously the unix account,
the `PROJECT` in `schedule/<p>.conf`, and the first column of
`_paced.monkey.conf`. One name, three surfaces. uids **3000–3099**, clear of the
human 1000s and of the office's `romulus`=1001.

**Project users get no sudo.** A deliberate divergence from `romulus`, which has
blanket NOPASSWD because it binds a port and manages a service. A self-dev user
needs nothing outside `$HOME`. `ecosim.conf` declares `AUTONOMY_TIER="medium"`
because a mistaken `--commit` there rewrites every project's `CLAUDE.md`;
passwordless root on top of that is indefensible. If a nightly run believes it
needs root, that is a finding to surface, not a capability to pre-grant.

## 3. Credentials, and the hazard in them

One Claude identity. Zach logs in interactively once as `zach@monkey` (headless
VM ⇒ device-code flow, not a browser redirect), then the credential is
provisioned per project user:

```sh
install -d -m 700 -o ecosim -g ecosim /home/ecosim/.claude
install -m 600 -o ecosim -g ecosim \
        /home/zach/.claude/.credentials.json /home/ecosim/.claude/.credentials.json
sudo -u ecosim -H claude -p 'reply with the single word ok'    # witness, same sitting
```

**Say the cost out loud:** all project users share one credential, therefore one
quota. Isolation of repos and working state is real; isolation of *spend* is
not, and cannot be under this decision.

**The hazard:** the OAuth credential refreshes and expires. A copied file goes
stale, and the failure mode is dispatch that runs and silently produces nothing
— the same "reports clean while dead" shape as the `garde` bug fixed in phase 0.
Automatic refresh propagation is an explicit **non-goal**; the mitigation is that
re-running those two `install` lines is a ten-second fix, and the goal-C witness
(a new sha on GitHub) is what notices its absence.

## 4. Two things that are load-bearing and do not look it

**(a) `hostname -s` must be exactly `monkey`.** `usage-paced-runner.sh:163-171`
resolves `schedule/_paced.$(hostname -s).conf` and **falls back to the shared
`_paced.conf` when there is no host file**. On a new host that fallback is not a
default — it is mandark's rotation. A hostname of `Monkey` or `monkey-selfdev`
would silently dispatch another machine's projects. `bin/land-selfdev.sh` checks
this, and grades it by *what would be inherited*: a fallback onto a file with
enabled rows is `BAD`, onto an inert one merely `MISSING`.

**(b) `$HOME` expands in one conf family and not the other.**

| file | read how | `$HOME` |
|---|---|---|
| `schedule/<project>.conf`, `_runner*.conf`, `_sweep*.conf` | **sourced** | expands |
| `schedule/_paced*.conf`, `_monitor.conf` | `while IFS='\|' read` | **does not** |

So `PROJECT_REPO_PATH="$HOME/Documents/Projects/ecosim"` is correct and portable,
while `_paced.monkey.conf`'s command column must stay an absolute literal. This
is not visible from either file, which is why it is written down here and
asserted in `scheduler/tests/meta-cmd-preflight-witness.sh`.

## 5. What landed (phases 0–2)

**Phase 0.1 — mandark's stale checkout.** `realisateur`'s working checkout was
12 commits behind `origin/main` for the second time in two days, and
`~/.local/bin` shims exec scripts *inside that checkout*. Fast-forwarded to
`bbf0eb3`; `install-shims.sh --check` then reported all 10 shims, 3 commands and
1 hook in sync, so no machine-wide change was needed.

**Phase 0.2 — `garde` reported success while blind.** *(gardien PR #1)*
`pending_sets()` skips unreachable destinations, so with nothing reachable the
pending list was empty and indistinguishable from "everything proven":

```
before:  garde: nothing pending -- every set is already copied and proven    rc=0
after:   garde: BLIND: no destination is reachable; 'nothing pending' here
         would mean 'I could not look', not 'every set is proven'            rc=6
```

It had fired that way at 03:34 that morning with dexter down; the last real copy
had been 2026-08-02 21:34. Both directions asserted in `test/media-test.sh`
(50/50, contract 7/7). **This matters more once self-dev leaves mandark**: a
WSL2 distro stops when Windows logs out, so the backup destination is *designed*
to be intermittently absent, and the nightly job was treating absent as proven.

**Phase 1 — scheduler can now stand up on a bare host.** *(scheduler PR #6)*
Both shipped meta confs named a path outside the repo that nothing in the repo
creates, so a fresh clone omitted the runner tick — and since it is the only
agent-dispatching line, the whole generated block came out empty. A total
dispatch outage, announced as one stderr line, from a command exiting 0.
`meta_cmd_resolve()` lets a conf name the copy the repo ships:

```
/abs/path     unchanged      bin/foo.sh -> $SCHED_DIR/bin/foo.sh      foo  unchanged (PATH)
```

Plus `PROJECT_REPO_PATH` → `$HOME/...` in seven sourced confs. Witness 25/25.
*Caught while writing it:* `schedule/scheduler.conf` is a **symlink** into
`.scheduler/`, and `sed -i` replaces a symlink with a regular file — the conf was
silently detached and left two copies to drift, visible only as "91 insertions"
for a one-line change. Restored, and the witness now asserts the symlink
survives.

**Phase 3/6 artifacts authored** — `provision/monkey-vm.sh` and
`bin/land-selfdev.sh` (§7).

## 6. Captured output

Reaped 2026-08-10 (`PROSE-REAPING.md`): point-in-time provisioning
transcripts from the 2026-08-03 monkey-VM build, held at the time as
evidence the scripts worked, not a live invariant. Full text:
`ecosystem1/realisateur/MONKEY-CAPTURED-OUTPUT-AND-ACCOUNT-NARRATIVES-20260810.md`.

## 7. The two scripts

**`provision/monkey-vm.sh`** — a copy of `vkv/office/provision/nomac-vm.sh`
(office `a7fbbe5`), not a shared dependency: `office` is Tyler's co-directed
repo and a shared script couples the business to the dev plane. Three changes
beyond values:

- `createvm --basefolder "D:\VirtualBox VMs"` — the disk on D:. The VDI path is
  *derived* from `CfgFile`, so snapshots and logs follow for free.
- `win_to_wsl()` replaces a hardcoded `s|C:\\|/mnt/c/|`, which produced a wrong
  path for any drive that is not C:.
- **`vbm() { ... < /dev/null | ... }`** — found by running the script as
  `ssh dexter 'bash -s' < monkey-vm.sh`: execution stopped dead after the version
  line because `VBoxManage.exe`, a Windows process inheriting stdin, **ate the
  remaining 200 lines of the script**. It looked exactly like a crash. gardien's
  own suite already asserts this class ("an ssh that reads stdin sits on the
  collision path without `-n`"); this is the same bug wearing a hypervisor. The
  ancestor has the same latent defect — it never fired because that script was
  always run as a file, never piped.

**`bin/land-selfdev.sh`** — `--check` (default, writes nothing) / `--land`.
Modelled on `land-office.sh`. It clones realisateur and scheduler, then
**derives every other repo from `schedule/<p>.conf`'s `REPO_URL`** rather than a
typed list (`bin/lib/verb-set.sh`'s thesis: derive from repo state). It breaks
the `installe` chicken-and-egg with the one symlink `install-verbs.sh` already
prints, reuses both realisateur installers unchanged, and then **stops**: it
runs `sync-crontab.sh` in preview and prints the `--apply` command for a human.
Arming dispatch is the one step that spends a shared quota.

## 8. What remains (phases 3–9)

Three human sittings; everything else is scriptable.

- **H1 — DONE.** Build the VM (WSL/Windows). Probe host RAM
  (`powershell.exe -NoProfile -c "(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory"`
  — WSL reporting 14 GiB *implies* 32 GB but is unprobed; if 16 GB use
  `MONKEY_RAM_MB=4096`). Generate `~/.ssh/selfdev_monkey`. Then `--check` →
  `--dry-run` → **read the generated `Unattended-*` user-data** → `--create`.
- **H2 — DONE.** Root inside monkey, then the interactive `claude` and `gh` logins,
  then the credential copy. Create `~/.local/bin` *before* ecosim's first login
  (Ubuntu's `.profile` only adds it if it exists at login time). Harden sshd:
  `PasswordAuthentication no`, `PermitRootLogin no` — the NAT hostfwd binds every
  Windows interface, and this is the control that holds regardless of firewall.
- **H3 — autostart. SETTLED 2026-08-03, Zach: LOGON start is the milestone,
  not boot.** Installed as `monkey-vm.bat` in the Startup folder, with a guard
  that no-ops if the VM is already running (verified: run while up leaves
  exactly one VM, still reachable). Filed with senechal; retire by deleting
  that one file.

  **Why logon and not boot.** A boot-time Scheduled Task needs the Windows
  password stored in Task Scheduler, and it would bring monkey up while dexter
  WSL2 — the jump host *and* the backup destination — is still down, since
  WSL2 also only starts at logon. Making the VM strictly more available than
  the host around it buys nothing and hides the dependency. (`VBoxAutostart`
  was also never exercised on this box: `nomac` has `autostart-enabled=off`.)

  **PROVEN 2026-08-03T21:26Z. Milestone met.** Zach restarted dexter's Windows
  host and logged in. Evidence, and it is a controlled result rather than an
  inference — the same host, the same shutdown, one VM with the Startup entry
  and one without:

  | | |
  |---|---|
  | Windows went down | monkey's prior session logged `RUNNING → SUSPENDING` (VirtualBox saves state on Windows shutdown) |
  | WSL2 started | 21:26:02Z |
  | **monkey restored** | **21:26:04Z — two seconds after logon** |
  | **nomac** (no Startup entry) | **still `saved`** — did not come back |

  The guest reporting a longer uptime than the host is expected: a restored VM
  continues its clock from the save point, so uptime is *not* a witness here
  and the VBox log is. Read `VBox.log` for `Log opened` + `Restoring`, not
  `uptime`, if this is ever re-checked.

Then arm: `_paced.monkey.conf` with one enabled row (`ecosim|1|1|<abs path>`),
`_runner.monkey.conf` (`0 */6`, `PACED_MAX_PER_TICK=1`), `_sweep.monkey.conf`
(`SWEEP_TICK_CRON=""`), and `schedule/FREEZE` carrying `EXEMPT: ecosim@monkey`.
**Delete mandark's runner cron line** rather than trusting an empty rotation — an
empty rotation still ticks four times a day and still probes `usage-gate.sh`
against the shared budget.

**Witness, don't wait:** force one tick, then collect a runner log showing
`PACED_CONF_SRC = host-scoped for monkey`, a commit on `origin/main` of
`hf7y/ecosim` confirmed **from mandark** by `git ls-remote`, and an
`observation`-labelled issue. Plus the negative witness — zero RUNNER lines on
mandark and dexter — because proving the other hosts are quiet is what makes
"single dispatcher" a measurement rather than an intention.

**Honest limit on the kill switch:** nothing on monkey pulls `scheduler`, so
`FREEZE` is not a remote kill switch for monkey until something does. The real
one is `ssh -p 2225 ecosim@... crontab -r`.

## 9. Accepted risks and deferred decisions

**D: is now a correlated failure.** 261 G of mandark's backups and `monkey.vdi`
share one physical disk, and those backups have no second copy. The monkey half
is fine by design — monkey holds nothing unique, and *if D: dies it is rebuilt by
`monkey-vm.sh --create` + one root block + `land-selfdev.sh --land`, and nothing
is lost*. The backup half is pre-existing and this sprint concentrates more value
on the same spindle. **The mitigation is deliberately not taken this sprint**;
recorded so it is a decision rather than an oversight. Pair it with the Pegasus
cold power-cycle, the only path to a second destination.

**Backups mean less once self-dev leaves mandark.** gardien keeps backing up
mandark's `~/Documents/Projects`, but once ecosim's authoritative history is
GitHub + monkey, mandark's clone is a stale copy: the backup keeps succeeding and
keeps meaning less. A follow-up sprint, named not fixed.

**Shared quota across three dispatch-capable hosts.** Mitigated by FREEZE
(mechanical, not conventional), by deleting mandark's runner line, and by
`PACED_MAX_PER_TICK=1` at `0 */6`. Residual: an interactive `claude` session on
any host also spends the budget, and nothing gates that.

**Deferred, each with its real question stated:**

- ~~**A second project user.**~~ **DECIDED 2026-08-03, Zach — see §9.1 below.**
  The dispatcher topology question is answered: N dispatchers is fine, because
  the thing being protected is a quota and the quota already has its own
  sensor.
- **Man pages.** 25 verbs ship `man/<verb>.1`, `MANPATH` has no ecosystem entry,
  and every page tells its reader `man <verb>` for the contract. The real
  question: *does `installe`'s contract extend to `man/`, or does a second verb
  own pages?* `installe` declines it today and calls extending it a contract
  change. One sentence, not a sprint — but not a side-quest on the ecosystem's
  single verb-installing chokepoint either.
- **`lib/verb.sh` is forked.** Six repos at `73c1c8ad` (matching
  `bashify/skel`); `gardien-garde` unique at `82b283ad` and *richer* — it is the
  only copy with `verb_refuse`/exit 7, `verb_gap_or_summon` and
  `verb_record_cost`. Whether to backport is open.
- **`garde.json` portability.** Gitignored, hand-authored, travels nowhere. Not
  solved: gardien is simply not installed on monkey, and monkey's durability
  story is "rebuild", not "restore".
- **`realisateur`/`scheduler` self-developing on monkey.** Their clones live
  there and are used; they stay human-driven. `scheduler-dev-cycle.sh` merges to
  local main *and pushes to origin the same cycle*, and two hosts on one
  scheduler history is the divergence the freeze exists to prevent.
- **`svc-vaporwave`.** "All self-dev off mandark" is **not verifiable** while
  that account's crontab needs a password to read. It was confirmed dispatching
  nightly on 2026-08-01. Either read and retire it, or record it as knowingly
  out of scope — but do not let this document claim a clean mandark it cannot
  prove.

---

---

Account-landing narratives for #2 (`bibliothecaire`), #3 (`chezz`), #4
(`vim-arcade`) — reaped 2026-08-10, same vault file as §6 above. The
mechanical traps they found (PATH-at-login, chown-final-component,
cross-account `sudo -u` permission wall, dedicated-clone witness gap) are
carried forward as comments in `bin/provision-selfdev-user.sh`,
`bin/setup-selfdev-project.sh`, `bin/land-selfdev.sh` themselves, not here.


## 9.1 The dispatcher topology, decided (2026-08-03, Zach)

**Zach, 2026-08-03:** *"I don't fully understand the topology hang. Just give
every account the creds to run and block new agents from spawning when too
close to threshold. we had something like that working fine on mandark."*

**The hang was a category error, and the correction is worth keeping.** §9 and
`schedule/_paced.monkey.conf`'s header both framed the problem as *counting
dispatchers*: N project users each with their own `scheduler` clone is N
dispatchers against ONE weekly quota, therefore N must not exceed 1 until
someone designs a single-dispatcher topology (a dedicated dispatcher account
with `runas`-scoped sudoers was the sketch).

But **nothing was ever protecting the quota by counting dispatchers.** The
protection is `scheduler/bin/usage-gate.sh`, and it does not count anything
local. It spends ~23 Haiku tokens on a live probe and reads Anthropic's
**unified rate-limit headers** — `anthropic-ratelimit-unified-{5h,7d}-*` —
which are **account-wide**: web, Slack, cron, every machine, every unix user,
every interactive session. Its own header says so and names that as the
requirement, not a side effect. Its exit code IS the verdict (0=RUN, 1=HOLD,
2=ERROR, and every caller must treat ERROR as HOLD), it holds above
`USAGE_CEILING` (0.85) and below an even-burn pace line, and it honours the
5-hour and 7-day windows independently, deferring to whichever binds.

So a second account does not dilute the guard. Both accounts probe the same
account-wide utilisation and both see the second one's spend. This is what was
already "working fine on mandark" — mandark and dexter shared one budget under
this same gate, which is why `_usage.<host>.conf` exists at all. **Adding
accounts scales the number of things asking permission; it does not scale what
they are asking about.**

**Two residuals, carried knowingly rather than designed away:**

1. **The flock is per-account, not global.** `usage-paced-runner.sh` sets
   `STATE_DIR="$HOME/.local/share/$JOB_NAME"` and locks `run.lock` inside it,
   so `ecosim`'s lock and `bibliothecaire`'s lock are different files and two
   accounts CAN dispatch in the same tick, and nothing on this host serialises
   them.

   > **CORRECTED 2026-08-04.** This paragraph originally said the race was
   > bounded because "`USAGE_CEILING` 0.85 leaves 15% of headroom for the race
   > to eat". **That was wrong.** 0.85 is `usage-gate.sh`'s *built-in default*;
   > `schedule/_usage.conf` overrides it with **`USAGE_CEILING=0.99`** and
   > **`USAGE_RUSH_BEFORE_RESET_MIN=10080`**. 10080 minutes is seven days — the
   > entire 7-day window — so the rush-before-reset policy is **permanently in
   > force and the even-burn pacing hold never applies**. Every gate line on
   > this host reads `rush=True`, which is the observable that should have
   > prompted the check. Pacing is not protecting this quota; a 0.99 ceiling
   > and a `rejected` status are, and that is the whole list — roughly **1% of
   > headroom, not 15%**.
   >
   > The error mattered twice: it is the justification written into
   > `_paced.monkey.conf` for tolerating the per-account lock, *and* it was
   > leaned on to raise this host's tick to every 30 minutes the same night
   > (reverted after ~9h, scheduler `7f4a99e`).

   So before a third dispatcher: at ~1% headroom with no pacing hold, the
   ceiling barely absorbs the *second* concurrent account. Either serialise
   the accounts with a **host-wide** lock rather than the current `$HOME`-scoped
   one, or restore the pacing hold by lowering `USAGE_RUSH_BEFORE_RESET_MIN`
   toward its documented `120`. Neither is done; both are named.
2. **Interactive sessions still spend the budget ungated** — unchanged from
   §9, and it is the same residual, not a new one.

**What this decision does NOT grant.** Credentials to run, not privilege.
`bin/provision-selfdev-user.sh` still writes no sudoers file for a project
account and prints that absence as an action. "Give every account the creds"
means the shared Claude credential is copied in so the account can spend a
token — which is exactly what that script automates and what it exists to stop
being reconstructed from memory.

---

*Every figure here was produced by a command on the date given. Where a phase
has not run, this file says so.*

---

## 10. What the milestone cost, and what it did not buy

*Added 2026-08-03 on reaching it. The point of this section is that the
milestone is real and narrow, and neither half should be overstated.*

**What is true now.** One project, on one host, dispatching itself on a
six-hour tick behind a freeze that refuses everything else, filing its
questions where a human already reads. mandark runs no agent dispatch at all.

**What it does not mean.** Seventeen other projects are still parked. Nothing
about `ecosim@monkey` proves the second participant works — and the second one
is where the interesting problem is, because N project users each with their
own `scheduler` clone is N dispatchers against ONE weekly quota. That trigger
is written down in §9 and has not been touched.

### The pattern this milestone kept finding

Five separate defects on the day, all one shape: **one fact, two readers.**

| what | who disagreed |
|---|---|
| `conf_field` | `schedule/*.conf` sourced (`$HOME` expands) vs grepped (it does not) |
| `backup-proof` | bibliothecaire asserted against a backup tool that had been replaced |
| `usage-gate` | read only the interactive-login credential; the host uses `setup-token` |
| `notify-senechal` / `check-project-busy` | hardcoded `/home/zach`, on a host with no such user |
| ecosim's own `install-silence-audit.sh` | found by the dispatched agent, unprompted, same day |

Each was invisible until a *second host* ran the same code. A single-host
ecosystem cannot detect this class at all — every reader agrees with every
other because there is only one world. **The most valuable thing monkey
produced on day one was not a commit. It was disagreement.**

And the scale is measured, not guessed: **17 of 23 scripts in
`realisateur/bin` still hardcode `/home/zach/Documents/Projects` in code.**
Two are fixed. Fifteen will do the wrong thing, or nothing, on any host that
is not mandark.

### Known-broken, recorded rather than smoothed over

- **Answers do not flow back in.** The issues channel is built to PUSH: a human
  types answers locally, `scheduler` posts them and adds `answered`. Zach
  answered directly on GitHub, which is the intended direction, and **nothing
  consumes that**. Worse, `gh issue list --label question --state open` does
  not filter `answered`, so an answered-but-open issue is re-rendered as an
  unanswered question. #26 and #27 were closed by hand for exactly this reason.
- **`gh issue create` fails** for the `ecosim` token — its GraphQL metadata
  lookup needs `Contents: Read`, which the fine-grained PAT deliberately lacks.
  Every call `scheduler` itself makes works; an agent reaching for the
  convenience command will not.
- **`NO-VERDICT`** was fixed by asking for one (`scheduler#11`) but the fix has
  not yet been exercised by a real cycle.
- **`hermes-gateway`** remains failed on mandark and in no footprint entry —
  the only machine-scoped unit in the estate with no declared owner.

---

## 9.2 Three decisions Zach made on GitHub, consumed 2026-08-05

These were answered **on the issues themselves** — the intended direction —
and then sat unconsumed, which is the failure this file's own "Answers do not
flow back in" note predicted. They are recorded here because an answer that
lives only in an issue comment is one `gh issue close` away from being lost,
and because §8.1's third way out of the `notify-senechal` bind was explicitly
"until it is decided". Each is quoted verbatim; the reading that follows is
an interpretation and is marked as one.

**(a) Passwordless sudo for hands accounts — `realisateur#32`.**

> *"yes this is the standard. zach should always have nopasswd sudo on vms."*

So `provision/monkey-nopasswd.sh` is not a monkey one-off. **§2's "project
users get no sudo" is unchanged** and the distinction is now explicit: the
rule binds `ecosim`/`bibliothecaire`/`chezz`/`vim-arcade` (uid 3000–3099),
never the `zach` hands account. The cost §32 asked to be decided with in view
still stands and is accepted: anything that can execute as `zach@<vm>` has
root there, including any holder of `selfdev_monkey`.

**(b) Secrets reaching an unattended provisioning run — `realisateur#33`.**

> *"we need to set up permissions from the start. vms should be totally
> controllable via their host (passwordless sudo etc)."*

Read as: the answer to "how does a secret reach the run" is to need fewer
secrets — a VM is controlled *from its host* over an already-trusted path,
rather than by shipping credentials into it. The convention the scripts
already follow (secrets by environment, never argv, never a tracked file)
survives unchanged. **Not settled by this**: `TS_AUTHKEY` is a *third-party*
credential that host trust cannot substitute for, so the original blocker
recurs for tailnet keys specifically. See (c).

**(c) Joining the tailnet at install time — `realisateur#31`.**

> *"Let's make this a one-click touch from zach's side, either typing in his
> pw or commenting on a gh issue for approval. Nothing special about monkey."*

Two things, and the second is the larger one. The install stays **attended at
exactly one point** — a human approval, not a stored key. And *"nothing
special about monkey"* is a general instruction: this is the shape for any
self-dev host, so the step belongs in the shared provisioning path rather
than in a monkey-named script.

**"Commenting on a gh issue for approval" is a mechanism this estate does not
have yet.** It would make an issue comment a *control plane*, not just a
record — a provisioning run that blocks, asks, and resumes on approval.
Nothing here does that today, and building it is not a side-quest: it is the
same channel the self-dev accounts already file questions on, which is
precisely why it is attractive. Named, not built.

### The residue on dexter, measured 2026-08-05

`realisateur#37` and `#38` both concern dexter, and the numbers had drifted
since they were filed, so they were re-probed rather than quoted:

```
~/realisateur   main, clean, behind 51
~/scheduler     main, clean, behind  6
crontab         1 non-comment line (a bare PATH=). No dispatcher.
~/Documents/Projects/   does not exist
```

Note the path: dexter's checkouts are at `~/realisateur` and `~/scheduler`,
**not** under `~/Documents/Projects`. Two probes in one sitting reported
"the checkout is gone" from looking in the mandark location, which is the
same wrong-ref witness error this estate keeps paying for.

The consequence is sharper than "a stale clone". dexter's `~/.local/bin`
shims exec scripts *inside* `~/realisateur`, so every ecosystem command on
that host — `notify-senechal`, `focus-commit`, `silence-audit` — currently
runs **51 commits behind**, successfully and silently. Nothing on dexter
pulls, and nothing ever has.

*(A third probe in the same sitting reported all those shims dead at rc=127.
They are not: `~/.local/bin` is absent from a non-interactive ssh PATH, which
is the trap already recorded for hand-running scheduler jobs on dexter. The
shims work when PATH is set.)*

## 9.3 Decisions Zach locked 2026-08-06 — do not relitigate

*From the vision session (`260806-zach-reply.txt`, `260806-zach-vision-chat.txt`).
Recorded here rather than in a handoff doc because a handoff is disposable by
construction and these are constraints on future work. Each carries its
revisit trigger: a decision with no stated trigger is one that will be argued
again from scratch, which is the thing §9.2 was written to stop.*

**(a) `monkey` is strictly DEVELOPMENT.** This corrects the morning note's
typo, which said production. Same for `mandark`, `potato`, `dexter` WSL. A dev
host consumes its own **stable, versioned build outputs** as tooling — never
real-time self-dev output. This is the rule the stale verb-build breaks in
practice: production ran a build cut hours before the merge it needed, and the
`ecosim-sensor` binary was absent from it entirely (`ecosim#34`).

**(b) Anything user-facing moves off the dev hosts.** bibliothecaire's intake,
the whisper server, and anything else a person depends on. **Revisit trigger:**
too many VMs, or ssh in/out becoming major friction.

**(c) Disposable clones and `reset --hard` are ending.** Zach: *"This should
happen today. It's urgent enough."* Self-dev runs inside per-user accounts;
the clone was faking an isolation those accounts already provide for real.
**Done** — `scheduler#53`, merged `d71363c`. `reset --hard` is replaced by
salvage-then-restore: work a previous run left behind is committed to a
`salvage/*` branch and **pushed** before anything is moved, and a run whose
salvage cannot be pushed **aborts with the work intact**. The motivating loss:
ecosim's auto-stash held PARADIGM 4 (verdict designs), a supervisor
history-loss fix and 87 lines of tests, unread for days.

**(d) The Obsidian vault keeps its private GitHub remote for now.** The backup
ecosystem is blocked on hardware (no RAID); this is not permanent. **Revisit
trigger:** running out of remote space. Long-term preference is offline plus
excerpt-and-destroy, which dissolves the IP question via fair use.

**(e) The `BLOCKED` verdict vocabulary is essential**, and its weight should be
tuned from backlog. Note this is currently unbuildable as stated: verdicts are
destroyed at dispatch, so "the same blocker twice" is *structurally
unobservable* rather than merely unimplemented. The append-only ledger is the
precondition — `scheduler#54`.

**(f) Agent D's workflow question is parked** until after this sprint.

**(g) Budget is not metabolism.** Token budget is a *money* question — what
Zach wants to spend. Metabolism is what the organism does with its energy, and
critically it should **pace the build to Zach's bandwidth**: if he cannot clear
issues fast enough, builds must not become runaway introspections elaborating
low-value but unblocked areas. Currently conflated in one usage gate —
`realisateur#81`, `scheduler#56`.

**(h) `chezz` stays paused** (un-pause 2026-08-13). The afternoon note left
this ambiguous — *"we can pause chezz self-dev pending audit or leave it since
dispatch is down to 6-hourly"* — and it was already paused. Confirmed
2026-08-06: paused is what he wants. The deep audit is still wanted; his hunch
is the massive test suite, and his first idea is to **run testing separately
and non-agentically**. chezz must learn how much it can chew in 120 turns.

**(i) bibliothecaire's intake on mandark is PAUSED**, not fixed —
`bibliothecaire#22`. *"Not in active use."* monkey's three timers were already
disabled. Pausing mandark's three needs root and is queued for Zach. Two real
health failures survive the pause and are recorded on that issue: nothing
proves the corpus is backed up, and `attestation-fresh` misdiagnoses its own
cause.

**(j) The shared OAuth token rotation is DEFERRED**, by Zach's explicit choice
on 2026-08-06 — *"save token rotation for later."* The exposure is real and
stands recorded: one token sits in plaintext in all six monkey accounts'
`~/.claude/settings.json`, and it was printed into a session transcript on
2026-08-06 while checking bibliothecaire's permissions. Not a hazard that
decays on its own; it waits until he picks it up.

## 11. Identity — the App, and what deploy keys never gave us

Opened 2026-08-07, Zach-directed. Front door: **`bin/selfdev-gh-app.sh`**.
Witness: **`bin/tests/selfdev-gh-app.test.sh`** (22 cases, offline).

§8.1(1) made the self-dev credentials a script instead of a memory. It did not
make them a **name**. Deploy keys grant **access** and confer no **identity**: a
deploy-key push is attributed to whatever author string the commit carries, so
agent work and human work are indistinguishable in `git log` and in the GitHub
UI. Every rule in `CLAUDE.md` about an unattributable push, or an autocommit
adopting an agent's edit *"under a human's name"*, is downstream of that one
missing distinction. A GitHub App installation has its own actor —
`<slug>[bot]` — and **GitHub** makes the attribution, so it cannot be spoofed by
setting `user.email`.

**The App that exists.** `monkey self-dev`, owned by `@hf7y`, **App ID
4520255**, registered 2026-08-07. Registration is not installation and neither
is capability: as of this writing it has **no private key and is installed
nowhere**, so none of this is live. `--check` reports that rather than calling a
configured-but-inert App wired.

**What it does not solve.** App permissions are per-**App**, not per-repo. One
App cannot be read-write on a project's own repo and read-only on
`realisateur` — deploy keys can express that and this cannot. So this is an
**addition** to `wire-selfdev-git.sh`, not a replacement. In particular
*"one App per account, read-write on its own repo, read everywhere else"* is
**not expressible**: an App installed across all the repos with `contents:write`
is write on **all** of them. The permission is a property of the App, and the
installation only chooses which repos it applies to.

**The roster, decided 2026-08-07 (Zach).** One App **per account**, four of
them, in this order: `ecosim` (uid 3001) first, then `bibliothecaire` (3002),
`chezz`, `vim-arcade` (3000). Per-account Apps are the whole point — a single
shared App collapses all four into one bot name, and "which agent pushed this"
becomes unanswerable again, which is the question §11 exists to answer.

> **SUPERSEDED later the same day — see §11.1.** Zach reversed this to *one
> App, fleet-wide* (`unattended-monkey`, App **4521586**). Read §11.1 before
> acting on the per-account roster above; it is kept here for the reasoning,
> not as a live instruction.

**App 4520255 (`monkey self-dev`) is ecosim's**, renamed. It was registered
2026-08-07 under the one-App assumption, and a name that says `monkey` fits a
host, not an account. Renaming is free **only while it has no key and no
installation**: the rename changes the slug, and the slug is the bot login and
the noreply email that every commit is attributed through. Rename it after a
single commit exists and that history is orphaned from the actor. So: rename
now, or never.

GitHub App names are **globally unique across all of GitHub**, not per-owner —
`ecosim self-dev` may simply be taken, and the fallback is a qualified form
like `hf7y ecosim self-dev`. The slug follows the name, so pick it once.

**The play (recommended).** One **writer** App per self-dev account — Contents
RW, Pull requests RW, Issues RW, Metadata R — installed on **that account's own
repo only**. Then *keep the existing read-only deploy keys* for `realisateur`,
`scheduler` and `senechal`. Universal read is already solved, correctly and
per-repo, by wiring that is already live and already tested; an App cannot
express it better and a second shared App would mean one key copied across
every account. This also turns the §11 rewrite trap into a lever: remove the
`url.insteadOf` rewrite for the account's **own** repo only, and leave the
read-only ones on ssh, which is exactly where they belong. Cost: N Apps for N
accounts, no shared key, per-account attribution, and the privilege split
ecosim was given by hand on 2026-08-03 preserved unchanged.

The alternative — a single App, RW everywhere — is defensible if every account
is equally trusted (least privilege here guards against an agent going wrong,
not an attacker). It costs per-account attribution: every account pushes as the
same bot. A *reader/filer* App (Contents R, Issues RW) is only worth registering
if the deploy keys are being retired outright.

Inside any one App, `--repos a,b` narrows a single mint below the installation's
repo list; it is the only least-privilege lever available there.

**How much of this automates.** Re-probed against GitHub's REST docs
2026-08-07, not remembered:

| step | automatable? |
|---|---|
| create the App, obtain the `.pem` | **yes** — manifest flow, one human click |
| install it on repos | **no** — no endpoint creates an installation; one human click |
| key placement, `gh-app.conf`, `--wire`, `--check` | yes |

**Two browser clicks per account, and no more.** `bin/selfdev-gh-app-register.sh`
does the first: it builds the manifest, serves a local callback, and exchanges
the returned code for the App id, slug and private key, writing the `.pem` at
mode 600 and the `gh-app.conf` beside it. Witness:
`bin/tests/selfdev-gh-app-register.test.sh` (25 cases, offline, stubbed API).

The manifest flow is also the **only** way to obtain a private key
programmatically — no endpoint mints one for an App that already exists. An App
registered by hand can therefore never have its key scripted, which is why App
4520255 is best deleted and re-created through this script rather than kept.

The manifest code is **single-use and expires in one hour**. If the exchange
fails, the App exists on GitHub with a key nobody holds: delete it and re-run.
The script says so on that path rather than exiting quietly.

Run it where the **browser** is (mandark), then carry the `.pem` to the
account — GitHub redirects the browser, so the callback must be reachable from
it. `--manifest-only` writes the form and stops, for a host with no browser.

```sh
bin/selfdev-gh-app-register.sh ecosim --repo ecosim     # writer, one per account
```

**Setup, by hand.** Only needed if not using the register script above. Steps
1–3 are on github.com and cannot be scripted.

1. *Permissions & events* → Repository permissions, per the split above. Set
   them **before** installing; adding one later leaves the installation pending
   a human approval.
2. *Private keys* → *Generate a private key*. The `.pem` downloads **once**:
   `install -m 600 -D <downloaded>.pem ~/.config/selfdev/monkey-self-dev.pem`,
   then delete the download. It is a bearer credential and must never reach a
   tracked file. Same class of hazard as §9.3(j)'s plaintext OAuth token, and it
   is worth not repeating that one.
3. *Install App* → `@hf7y` → **Only select repositories**. Not "All
   repositories": the installation's repo list is an App's only per-repo scoping.
4. `~/.config/selfdev/gh-app.conf` on the self-dev account —
   `SELFDEV_APP_ID`, `SELFDEV_APP_KEY`, `SELFDEV_GH_OWNER`. Environment
   variables of the same name **win over the file**, so a scheduler job can carry
   a different App without editing anything.
5. `selfdev-gh-app.sh --check` — authenticates the App, resolves the
   installation, mints a real token, counts the repos in scope, prints the bot
   identity. This is the line that proves GitHub answers.
6. `selfdev-gh-app.sh --wire` — git credential helper plus the bot's
   `user.name` / `user.email`.

**The trap in step 6.** `wire-selfdev-git.sh` writes `url.insteadOf` rules
rewriting `github.com` onto per-repo **ssh aliases**. Where both are wired,
**ssh wins and the credential helper is never consulted** — silently, so pushes
keep working and keep landing under the old attribution. `--wire` detects the
rewrites and says so. Switching a repo means removing its rewrite by hand
(`git config --global --unset-all url."git@github-<repo>:hf7y/<repo>.git".insteadOf`),
per repo, deliberately: a repo that should stay on a read-only deploy key keeps
its rewrite.

**Tokens.** One hour, minted on demand from the private key, cached mode-600
under `$XDG_CACHE_HOME/selfdev-gh-app` keyed by App and repo scope and expired
five minutes early (git invokes a credential helper on *every* remote
operation). Nothing long-lived is stored. `--jwt` prints the App JWT alone,
because GitHub answers a malformed JWT with a bare 401 that is indistinguishable
from a revoked key.

**Open.** §8.1(2) recorded `installe` exiting **8** on self-dev accounts because
`notify-senechal` needed a push to `hf7y/senechal` and self-dev holds a
read-only key there. That script has since moved to `scheduler -i` and no longer
pushes, which is why the reader App above grants Issues RW mostly for the
request queues. **Re-probe the exit code on a self-dev account before claiming
this is fixed** — it is quoted here, not verified.

## 11.1 One App, fleet-wide — decided and installed 2026-08-07 (Zach)

This supersedes the per-account roster in §11. **One App**, `unattended-monkey`,
App id **4521586**, bot `unattended-monkey[bot]`, owner `@hf7y`, installation
**152065281**. Every self-dev account holds the same key, and therefore **every
repo with a user on monkey is writable by every account**. That is the accepted
trade, not an oversight.

**Why the reversal.** Per-App identity buys **cryptographic** attribution —
GitHub itself asserts which App pushed, and it cannot be spoofed. But the
question actually being asked here is only ever bookkeeping: *"which agent did
this?"* A per-agent **commit author** answers that for free, in `git log`, with
no second App, no second key, and no second installation click. Paying N Apps
for a property nobody is relying on is the wrong trade. Zach, verbatim: *"every
repo writable, anything with a user on monkey, which will eventually be the
entire ecosystem of verbs and more. I'll keep adding self-dev repos to this
App... In theory they don't need to be able to build the toolchain. agree."*

**In scope as of 2026-08-07** — 10 repos, verified from the App's own side by
minting an installation token and reading `GET /installation/repositories`
(count and names below are that response, not the `204`s that produced it):

`hf7y/baudin`, `hf7y/bibliothecaire`, `hf7y/chezz`, `hf7y/crt`, `hf7y/ecosim`,
`hf7y/gardien`, `hf7y/groc-mangr`, `hf7y/nine-speakers`, `hf7y/sequestria`,
`hf7y/vim-arcade`

One per uid 3000–3099 account on monkey. Every account had a matching
`hf7y/<name>` repo; none was missing, and none was invented.

**Deliberately out of scope, and to stay that way:**

- **The toolchain** — `realisateur`, `scheduler`, `senechal`. Explicit
  decision: agents do not need to build the toolchain. Read access to these is
  already solved, per-repo and correctly, by the read-only deploy keys
  (§11, "The play"), and that wiring is unchanged.
- **`hf7y/verbs`** — public (`private=false`), so its payload needs no
  credential at all, and the cut is performed by GitHub Actions **inside that
  repo**, not by any agent holding this key.

**Adding the next repo requires a *classic* PAT.** `PUT
/user/installations/152065281/repositories/{repository_id}` → `204`. Get the id
from `gh api /repos/hf7y/<name> --jq .id`. It needs admin on the repo. The trap,
**measured 2026-08-07**: an **OAuth-app token — which is what `gh auth login`
yields — gets `403` from this endpoint even while carrying `repo` scope**, with
the message `You do not have permission to modify this app on hf7y.` That
message reads like a missing-admin problem and is not; it is the token *class*.
Whoever onboards the next repo needs to know this or they will conclude the
endpoint is broken and go looking for a permission that is already granted. Use
a classic PAT with `repo` scope; Zach keeps one at `~/.config/selfdev/pat`
(mode 600, never to be copied, never to reach monkey or a tracked file). Pass it
by environment, never as an argv token.

Adding is reversible: `DELETE` the same endpoint.

**Revisit triggers.** A decision with no trip-wire is a decision nobody
revisits. Reopen the one-App-vs-per-App question when **either** of these is
true:

1. **verb-class self-dev and end-user self-dev become meaningfully different —
   *and there is a problem*.** The divergence alone is not the trigger; the
   trigger is divergence that costs something. Blanket write across both classes
   is fine while the classes are interchangeable.
2. **`realisateur` itself starts self-developing on monkey.** At that moment the
   toolchain exclusion above stops being free, and "every account can write
   every repo" would mean an agent can rewrite the tooling that constrains it.
   That is a different risk from the one this decision accepted.
