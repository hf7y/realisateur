# MONKEY.md — where self-dev lives

*The shape of the self-dev plane after it leaves mandark. Sprint opened
2026-08-03, Zach-directed. Sibling to `THE-UNWIRING.md` (which said self-dev
would park) and `THE-FLOOR.md` (which says what must hold before anything is
armed). This one says **where it runs instead**.*

**Status: phases 0–3 landed (the VM exists and is installing), phases 4–9 not started.** Every command output
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

**Not yet captured, because those phases have not run:** the VM's own
`land-selfdev.sh --check`, monkey's `crontab -l`, and the goal-C witness sha.

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

- **H1 — build the VM** (WSL/Windows). Probe host RAM
  (`powershell.exe -NoProfile -c "(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory"`
  — WSL reporting 14 GiB *implies* 32 GB but is unprobed; if 16 GB use
  `MONKEY_RAM_MB=4096`). Generate `~/.ssh/selfdev_monkey`. Then `--check` →
  `--dry-run` → **read the generated `Unattended-*` user-data** → `--create`.
- **H2 — root inside monkey**, then the interactive `claude` and `gh` logins,
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

  **Still unproven:** it has not survived a real logon. By this file's own
  standard that means hoped for, not configured — the milestone is met when a
  logout/login brings monkey up unattended, and not before.

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

- **A second project user.** Before project #2 exists, decide the dispatcher
  topology — N users each with a `scheduler` clone means N dispatchers against
  one quota. Likely a dedicated dispatcher account with a `runas`-scoped sudoers
  rule, not blanket NOPASSWD. No account is created now; an unused account is a
  ghost.
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

*Every figure here was produced by a command on the date given. Where a phase
has not run, this file says so.*
