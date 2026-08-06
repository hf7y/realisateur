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
invites that error.

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

`provision/monkey-vm.sh --check`, run **on dexter, 2026-08-03**, against the
real hypervisor:

```
== monkey VM provisioning (--check) ==
  OK      VBoxManage 7.2.12r174389
  OK      basefolder drive /mnt/d present, 2699G free (disk declared 120G, dynamic)
  ..      verifying ISO sha256 (3247 MB, this takes a moment)
  OK      ISO checksum matches the published SHA256SUMS
  MISSING VM 'monkey' does not exist yet
  OK      nomac exists and is untouched by this script (different VM, different disk, different port)

check only. Nothing changed.
```

`bin/land-selfdev.sh --check`, run **on mandark, 2026-08-03** (mandark is not
the target; this is the script proving it reads a real host correctly):

```
  OK      git / python3 / node / claude on PATH
  OK      ~/.local/bin exists and is on PATH
  OK      systemd --user is running          OK  linger enabled
  MISSING no schedule/_paced.mandark.conf; this host falls back to the shared
          _paced.conf, which currently has 0 enabled rows (inert, but give this
          host its own file before arming anything)
  OK      claude credential present, mode 600
  OK      GitHub read path works             OK  gh is authenticated
  OK      42G free on $HOME
check only, nothing changed: 12 ok, 1 missing, 0 bad
```

### Phase 3, run 2026-08-03

Host capacity, from `VBoxManage list hostinfo` (the `powershell.exe` probe
returned nothing under non-interactive ssh; VirtualBox already knows):

```
Processor core count: 8
Memory size:          30439 MByte
Memory available:     16413 MByte
```

So 6144 MB / 4 vCPU is comfortable: nomac 4 G + monkey 6 G + WSL's ceiling
still fits inside 30 G, with 16 G free at the time of creation.

`--dry-run` confirmed the three things it exists to confirm, before anything
installed:

```
hostname                    = monkey.selfdev.local
auxiliaryBasePath           = D:\VirtualBox VMs\monkey\Unattended-f3eda250-...
postInstallCommand          = ...printf "%s\n" "ssh-ed25519 AAAA...selfdev-monkey" > /home/zach/.ssh/authorized_keys...
detectedOSVersion           = 24.04.4 LTS "Noble Numbat"
```

— the short hostname is `monkey`, the basefolder took effect on **D:**, and the
post-install quoting survived assembly through two shells with the key on one
line. Then `--create`, and the VM as registered:

```
CfgFile="D:\VirtualBox VMs\monkey\monkey.vbox"     memory=6144  cpus=4
"SATA-0-0"="D:\VirtualBox VMs\monkey\monkey.vdi"
nomac: memory=4096  VMState="running"              <- untouched
```

**Two corrections earned during this phase, both recorded because they were
wrong in the confident direction:**

1. **The reachability hint.** This script "corrected" the ancestor's
   `127.0.0.1` to a derived default-route address. On dexter the correction was
   **wrong and the ancestor was right**: WSL2 here has localhost forwarding, so
   `127.0.0.1:2225` reaches the guest, while the derived `192.168.0.1` (the LAN
   router, not the Windows host) refuses. The address depends on WSL2's
   networking mode, which the script cannot know — so it now **probes both and
   prints what answered**.
2. **An open port is not a finished install.** The first readiness watch fired
   the moment 2225 accepted a connection, and key auth was then refused —
   because Ubuntu's *installer environment* answers on 22 before the
   post-install command has written `authorized_keys`. The witness is the first
   successful key auth returning `hostname -s` == `monkey`, not the first open
   socket.

### Phase 6–7, run 2026-08-03 — the milestone

`land-selfdev.sh --land` as `ecosim`: 8 checkouts (4 repos + their `bashified`
worktrees), 24 commands on PATH, **0 BAD**. Three private repos needed
credentials, so four **per-repo deploy keys** were issued — `ecosim`
read-write, the other three read-only. Least privilege per repo, which one
account-wide PAT could not express. Read verified on all four; write verified
by a `--dry-run` push that authenticated and created nothing.

Armed, then witnessed. The three witnesses, and the negative one:

```
ROTATION host=monkey conf=.../_paced.monkey.conf [host-scoped for monkey] slots=1 :: ecosim
FROZEN, but ecosim is EXEMPT ... (host=monkey, rule=ecosim@monkey) -- proceeding
DISPATCH [0/1] ecosim -> .../bin/scheduler-run ecosim batch
DONE ecosim rc=0 (835s)
```

- **the sha:** `278b4ee` on `origin/main` of `hf7y/ecosim`, confirmed from
  **mandark** — work left the VM.
- **unattended:** a cron-fired run under a stripped environment returned
  `verdict=RUN http_code=200`, proving HOME, PATH and the `settings.json`
  token all resolve with nothing inherited from a login shell.
- **negative:** mandark `:RUNNER` = 0, dexter = 0. mandark's dispatcher was
  retired by conf (`_runner.mandark.conf` blanking `RUNNER_CRON`), not by
  hand-editing a crontab the next `--apply` would regenerate.
- **issues:** #26 and #27 filed by `ecosim@monkey`, labelled `question`,
  answered by Zach on GitHub, consumed and closed.

**The near-miss worth keeping.** The first read of this run said "no commit was
produced" — because ecosim's HEAD in `~/Documents/Projects` was unchanged. The
batch works in a **dedicated clone** at `~/.local/share/ecosim-nightly-batch/repo`.
A successful first dispatch was one step from being recorded as a failure,
because the witness was pointed at the wrong repo.

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

## 8.1 Account #2, and the three things only a second account could find

`bibliothecaire@monkey`, uid 3002, landed and armed 2026-08-04. Five repos,
25 verbs, `freeze-check` returning 0 EXEMPT from monkey's own clone, and a
`0 */6` runner line in its crontab. §10 says a single host hides defects that
only a *second host* reveals; the same is true one level down, and account #2
found three in an afternoon.

**1. The credentials were a memory, not a script.** ecosim's four deploy keys,
its `config.selfdev`, and twelve `url.insteadOf` lines were all hand-made and
written down nowhere. Zach, on being shown them: *"we can't do this for every
install."* Now `bin/wire-selfdev-git.sh`, called per repo by `land-selfdev.sh`
from the loop that already derives repos from `schedule/<p>.conf`. The
non-obvious step in it is `ssh-keyscan`: a fresh account has no `known_hosts`,
and an unattended clone against an unknown host key does not prompt — it
**fails**, looking exactly like a bad key. `provision-selfdev-user.sh` now also
copies the **gh** credential, which an account needs twice over: to register
its own deploy keys, and because the request queues these projects run on ARE
GitHub issues.

**2. `notify-senechal` cannot work from a self-dev account, and this is
structural.** `installe` exited **8** on all 25 verbs — *"UNDECLARED:
notify-senechal ran and failed; the change stands, the estate was not told."*
The cause is not a bug: the estate's front door **pushes to `hf7y/senechal`**,
and a self-dev account holds a **read-only** deploy key there, on purpose. Two
correct rules meet and one has to give:

> least privilege says the account may not write senechal; the estate protocol
> says every machine-config change must be filed with senechal.

**This affects `ecosim` identically** — it was simply never noticed, because
ecosim's verbs were installed during a root sitting by a user who could push.
Three ways out, none taken here because the choice is Zach's: give self-dev
accounts read-write on senechal (cheapest, and gives up the least-privilege
claim); route `notify-senechal` through `gh issue` instead of a push (keeps
least privilege, needs the gh credential §8.1(1) now copies, and makes the
front door work from any host that can reach GitHub); or accept exit 8 and
file from a host that can push, which is what was done on 2026-08-04 and does
not scale. **Until it is decided, every verb install on every self-dev account
reports a failure that is not one.**

**3. The PATH trap, again.** `land-selfdev.sh` over a non-interactive ssh could
not find `installe` even though the symlink existed: Ubuntu's `.profile` adds
`~/.local/bin` only at **login**, and `ssh host 'cmd'` is not one. The same
trap is already recorded for hand-running scheduler jobs on dexter. It presents
as `FATAL: installe is not on PATH` from a script that just linked it.

Also corrected here: `land-selfdev.sh` reported `install-shims.sh failed` for a
**FLAG** — `subagent-closeout.sh` installed but not referenced in
`settings.json`, so it never fires. True finding, deliberately not auto-fixed
(that file is the human's), but it is a gap, not a failure, and it now says so.

## 8.2 Account #3 (`chezz`), and the tick that stopped being a race

**The tick.** `_runner.monkey.conf` went from `0 */6` to `0,30 * * * *` on
2026-08-04. Its header had explicitly refused this, on the premise that
mandark, dexter and monkey all draw on ONE weekly quota, so a faster tick here
wins a race rather than adding throughput. Re-probed before the edit:
`crontab -l | grep -c scheduler-paced-runner:RUNNER` is **0 on mandark**
(retired by conf, `RUNNER_CRON=""`) and **0 on dexter**. monkey is the only
host that dispatches anything — there is nobody to race. And the cron was never
the guard: `usage-gate.sh` is, on every tick, whatever the cron says. **The
cron decides how often we ask; the gate decides how often the answer is yes.**
On the only dispatching host, asking more often converts quota that would have
expired unused into work, which is what `usage-paced-runner.sh` is for.
Immediate cause: five corpus research requests (bibliothecaire #8–#12) wanted
to be through the queue by morning, and `0 */6` with `PACED_MAX_PER_TICK=1` is
four dispatches a day.

**`chezz` is registered and staged, one flag short of armed.** It had been
*deregistered* — `_paced.conf`'s footer still lists it under "Rows removed
here" while line 116 pointed at a `schedule/chezz.conf` that had been deleted.
That dangling reference is now repaired. The repo is public, `main`, already
carrying `.scheduler/FOCUS.md`; the consign header's source path
(`~/Documents/Project Archive/chezz`) is **gone**, so the GitHub remote is the
only canonical copy and this is a clone rather than a rescue.

Its rotation row is `|0|`, and that 0 is the only thing between it and
dispatching. Not caution — an enabled row whose command path does not exist
makes every runner on the host log `SKIP chezz -- command not runnable` on
**every** tick, which at 30-minute ticks is ~48 lines a night of a failure that
is not one, in the same `run.log` being read to see how the research went.

**`bin/setup-selfdev-project.sh` — one root command per new account.** The
answer to *"what is keeping this from being automated?"* was that the three
things needing root were the same requirement three times, spread across three
sittings (create the account; install a key so the rest could be driven; copy
the gh credential). This sequences those plus the unprivileged remainder —
provision, hands key, four per-repo deploy keys, land — and **stops before
arming**, because a rotation row is a judgment about a shared weekly quota.
`--no-key` declines the ssh grant; the grant is not a privilege increase (that
key can already sudo to root, hence to the account) but it is real, so it is
a flag rather than a silent step.

## 8.3 Account #4 (`vim-arcade`), the first real run of `setup-selfdev-project.sh`, and the bug it found

**Zach, 2026-08-04: vim-arcade is the next self-dev participant dispatching
from monkey, instead of chezz.** chezz stays exactly where 8.2 left it —
registered, staged, rotation row and FREEZE exemption both present, `|0|`.
Park, never delete: deleting either would re-arm the fixed-cron suppression
that `_paced.conf`'s own header says keys on rotation *membership*, not the
enabled flag.

**The account already existed.** `vim-arcade`, uid 3000 (lowest free in the
3000–3099 band; `ecosim` holds 3001), was created as PR #27's own witness run
for `provision-selfdev-user.sh` — the PR body's example output is literally
`OK vim-arcade can spend a token under a cron-shaped environment`. That
witness call is real capability, not a fixture: it left a working account
with home `0700`, linger on, no sudoers entry, and a live Claude credential.
Re-running `provision-selfdev-user.sh vim-arcade --apply` against it was a
clean no-op (5 ok / 0 missing / 0 bad, nothing to change).

**What 8.1 and 8.2 built was never actually run end to end, and account #4 is
what finally ran it.** `bin/setup-selfdev-project.sh` (the "one root command"
8.2 describes) had shipped but had no witness of its own — chezz's account
does not exist yet, so its row could not be armed by this script or any other.
Invoking it for real, as `sudo bash <bibliothecaire's realisateur
checkout>/bin/setup-selfdev-project.sh vim-arcade --apply`, got through step
1 (account, idempotent-OK) and step 2 (hands key installed) and then **failed
every unprivileged call in steps 3 and 4**:

```
bash: line 1: /home/bibliothecaire/.../wire-selfdev-git.sh: Permission denied
```

**The cause.** `$HERE` is wherever the script itself was invoked from — in
practice an *existing* project account's own realisateur checkout, since the
hands account holds no project clones (§2). Every project home is `0700` by
design ("repos and working state are isolated per project" — §3, and
`provision-selfdev-user.sh`'s own comment on the same mode). So `sudo -u
vim-arcade` could not even **read** bibliothecaire's copy of
`wire-selfdev-git.sh`, let alone execute it — a permissions boundary working
exactly as designed one account over, presenting as a broken install. Fixed
by staging the two unprivileged sibling scripts into the **new** account's
own home (`$HOME_DIR/.selfdev-setup`, owned by it, mode 700) before calling
them as it, rather than reaching across into whichever account happened to
invoke the script.

**Verified live, without touching another account's checkout.** The fix was
tested by copying the patched `setup-selfdev-project.sh` (plus its three
unchanged siblings) to `/tmp` on monkey — not into bibliothecaire's or
ecosim's repos, staying inside this task's scope limits — and re-running
`--apply`. Result: four per-repo deploy keys (read-only realisateur,
scheduler, senechal; read-write vim-arcade), each proven with a live `git
ls-remote` witness over its own ssh alias, not just a file check:

```
OK      WITNESS: GitHub served hf7y/vim-arcade over github-vim-arcade
```

`land-selfdev.sh --land` then finished **17 ok, 3 missing, 0 bad**, landed at
scheduler HEAD `874a58e`. The three MISSING are the same known-benign shape
8.1 already recorded for account #2: `systemd --user` unavailable under the
stripped `env -i` cron-shaped environment, the standing `install-shims.sh`
FLAG (`subagent-closeout.sh` installed but not referenced in `settings.json`
— that file is the human's, deliberately not auto-fixed), and one `UNOWNED`
verb (`installe` itself, hand-made, not yet in its own manifest — the same
bootstrap gap every account hits). The `sync-crontab.sh` preview for
vim-arcade had **zero `ERROR [` lines**. `/tmp` on monkey was cleaned up
after; `~/.selfdev-setup` remains inside vim-arcade's own home, which is
unremarkable — same shape as the checkouts `land-selfdev.sh` itself puts
there.

**Not armed by this account work.** `setup-selfdev-project.sh` stops exactly
where its own header says it stops: no crontab written, no rotation edit.
Arming is the separate, reviewed `schedule/_paced.monkey.conf` /
`schedule/FREEZE` change (this same change set, in the scheduler repo),
merged through review rather than as a side effect of landing an account.

---

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
