# The ecosystem, as of 2026-08-03

*A shallow audit, commissioned by Zach. Scope: what this thing is, how you
use it, what is operational on mandark, what is operational on dexter, and
what is nowhere.*

**Method.** Every figure below was produced by a command run on 2026-08-03
between 10:45 and 11:05 CDT. Nothing is quoted forward from
`ECOSYSTEM-SURVEY-2026-08-01.md` or `SNAPSHOT-mandark-dexter-2026-08-02.md`;
where this record contradicts them, this one was re-probed and they were not.
Several of their headline numbers are now wrong in the *good* direction, and
those corrections are called out by name in §7 — the recurring failure this
ecosystem records is a survey headline that was true once.

**Shallow means shallow.** This reads state. It does not read most source,
does not run the test suites, and does not open the `.idea` inbox. Where it
could not see something, it says BLIND rather than reporting nothing.

---

## 1. What the ecosystem is

It is one person's machine estate modelled as **an organism with organs**,
built out of two ideas that are worth separating because only one of them is
finished.

**Idea one — the organs.** Six long-lived repos, each owning one faculty,
named for a household role:

| organ | faculty | state today |
|---|---|---|
| **realisateur** | perception and judgment; owns the doctrine and the inbox | alive; this file lives here |
| **scheduler** | metabolism — the conf registry, `sync-crontab.sh`, the paced runner | alive; **dispatching nothing** |
| **senechal** | estate health — knows what machines exist and whether they are well | alive; **the one sensor that acts on a real domain** |
| **gardien** | durability — backups and their proof | alive, and **materially better than a week ago** |
| **bibliothecaire** | the library — a physical scanner to citable text | alive; **the only thing on the box doing real unattended work** |
| **ecosim** | instrumentation — the BLIND-vs-silence thesis | alive; ticking; **BLIND on 103 of 103 runs** |
| **basheur** | de-animation engine — turns agent prose into shell | alive; **6 commits unpushed** |

**Idea two — the verbs.** Above the organs sits a vocabulary of **25 French
verbs**, each a self-contained bash program with a man page as its contract.
This is the "bashify" layer: the project's stated direction is that faculties
should stop being agent prompts and become programs, so the estate can run
without a model in the loop. Each verb lives on a `bashified` branch in a
sibling `git worktree` of its owning repo — `senechal-verbs`,
`gardien-garde`, `scheduler-dose`, and so on.

The doctrine is in four files at realisateur's root, and it is genuinely the
load-bearing part: `UNIVERSE.md` (what the organism is, three laws),
`BUILD-DISCIPLINE.md` (the bar a change must clear), `THE-FLOOR.md` and
`THE-UNWIRING.md` (the current strategy: park self-development, keep the
work). The governing principle, stated in `UNIVERSE.md` and earned the hard
way, is: **a guard that is a paragraph is not a guard.** Prose decays;
enforcement does not.

## 2. How you use it

There is no daemon to talk to and no UI. The interface is your shell.

**The verbs are the interface.** All 25 are on `PATH` as symlinks into their
repos. Each takes a subcommand, prints a human-readable report, and — this is
the contract — **exits with a meaningful code**:

```
0  fine        2  usage error       5  BROKEN: I looked and it is wrong
6  BLIND: I could not see the domain, which is NOT "nothing to report"
```

The 6-vs-0 distinction is the whole thesis. A verb that cannot reach its
subject must say so rather than exit clean.

Verified today: **all 25 exit 2 on `--nonsense`.** (The 2026-08-01 survey
found four verbs exiting 0 on every flag. That regression is fixed.)

The vocabulary, by owner:

```
realisateur-verbs   arpente   survey the ecosystem and read its state
                    epluche   scrutinize the tree for hygiene defects
                    juge      perceive this system's state and judge what matters
senechal-verbs      ausculte  examine the estate for health
                    veille    keep watch over the household of machines
                    recense   census the executables installed under a home
                    installe  govern what is reachable from a prompt
                    lance     launch windows, browsers and panes
gardien-garde       garde     guard the estate's data: backups and their proof
                    fauche    clear a repo off this host once every byte is recoverable
                    transplante  relocate a repo so nothing still points at where it was
scheduler-dose      dose      apportion this ecosystem's scheduled work
                    arme      arm a recurring job that never spends
                    jauge     measure what was spent against what may be
                    rapporte  render the night's account of what was done
                    relis     proofread the files this ecosystem writes about itself
ecosim-verbs        sonde     probe the contracted sensors of this ecosystem
bibliothecaire-verbs  range verse glane cueille fonde trie accroche
vim-arcade-verbs    entraine  train the hands: vim motions as a game mechanic
```

**Where to start, in order.** `juge` — what matters right now. `arpente` —
the whole ecosystem's state. `ausculte` — is the estate healthy.
`garde media list` — is the data safe. `dose` — what is scheduled to run.

**The front doors.** Three things must never be done by hand, and each is a
command that does them correctly:

- `notify-senechal '<what changed>'` — whenever you change machine-wide
  config (cron, systemd, `~/.claude`, `~/.local/bin`). The project that
  generates machine config owns it; senechal owns *knowing it exists*.
- `focus-commit <repo> <msgfile> <file>...` — for `FOCUS.md` / `QUESTIONS.md`.
  These files have three concurrent writers and a bare `git add && commit &&
  push` has silently lost content four times.
- `check-project-busy <project>` — before writing directly into another
  project's files.

**Adding work.** `scheduler -i <project>` files an item through the front
door. Whether it ever *runs* is a separate question, answered in §3.

**One thing that does not work.** `man arpente` → *No manual entry*. All 25
man pages exist in their repos (`*-verbs/man/*.1`), but no install step puts
them on `MANPATH`, and `MANPATH` is unset. The layer whose stated contract is
"the man page is the contract" ships 25 contracts you cannot read with `man`.
Read them with `man -l <repo>/man/<verb>.1` until an installer exists.

---

## 3. Operational on mandark

Ubuntu 24.04.3, `6.8.0-136-lowlatency`, up 7 days 14 hours. Root filesystem
**466 G, 91 % used, 42 G free.** This is the laptop, and it does everything.

### Dispatch: three cron lines, zero projects

```
*/30  ecosim-sensor-tick                                  # arme:ecosim-sensors:MONITOR
0 */6 PACED_MAX_PER_TICK=1 usage-paced-runner.sh          # scheduler:...:RUNNER
*/15  scheduler sweep                                     # scheduler:...:SWEEP
```

All three fire — confirmed in syslog through 10:45 today. **But the rotation
is empty.** `schedule/_paced.conf` holds four participants (vim-arcade,
gardien, senechal, ecosim) and `_paced.dexter.conf` holds two (scheduler,
realisateur); **all six rows are `|0|`.** The paced runner wakes every six
hours and dispatches nothing. Self-development is parked, deliberately, and
this is what parked looks like from outside: the metabolism runs, and nothing
metabolizes.

> A trap worth writing down: `grep -l 'enabled=1' schedule/*.conf` matches
> both paced files and is **wrong** — it is hitting the string inside the
> explanatory comments, not a live row. Count rows
> (`grep -E '^[a-z].*\|1\|'`), not files.

### systemd --user: two live, one failed

- **`senechal-health.timer`** — active, hourly, last fired 10:34. Working.
- **`garde-nightly.timer`** — active, 03:33 daily. It ran this morning
  03:33:20 → 03:34:06, exit 0. **This is the one verb with a machine
  consumer:** `ExecStart=garde media run --all-pending`.
- **`hermes-gateway.service`** — **failed since 2026-08-02 10:38**, after
  consuming 25 min CPU and a 2.1 G memory peak. It is a WhatsApp/messaging
  gateway running out of `~/.hermes`, and it is declared in no project's
  footprint. Nothing in the ecosystem owns it.
- `front-door-watch.service` — now **disabled and inactive**, but the unit
  file is still installed and still points at `Projects/front-door`, a
  directory `fauche` deleted. Stopped, not retired.

### systemd system: bibliothecaire is the real workload

Three timers, all firing on schedule: intake every 15 min, OCR hourly, health
daily. A physical scanner writes to an SMB share and the pipeline turns pages
into citable text. It is hardware-bound and it is the only thing here
producing a deliverable a person would notice.

Its own health check **fails**, honestly and usefully — 10:02 today:

```
[FAIL] backup-proof        cannot prove anything is backed up: ssh dexter failed
[FAIL] pipeline-flow       2 gave up on OCR and can never be snapshotted
[FAIL] attestation-fresh   no all-green attestation has ever been recorded --
                           this pipeline has never been observed working end to end
```

Also failed system-wide: `postfix@-` and `usbmuxd`.

### Sensors: both loud, both largely unread

**senechal `estate-health.sh`** — hourly, exit FAILED, 5 checks failing. It
correctly reaches every machine on the estate (dexter, potato, ha-pi, router,
octopi all PASS), flags `/` at 91 %, 110 pending package updates, a required
reboot, and each failed unit by name with the command to inspect it. It is a
good sensor.

It also has **one blind spot that matters**: it reports
`SKIP gardien.service not installed for your user — no backup is configured
at all`. That is false. Backups moved to `garde-nightly.timer` and are
running. The health sensor is still looking for the retired mechanism, so the
estate's backup status is invisible to the estate's health check.

**ecosim `ecosim-sensor`** — every 30 min since 2026-07-29.
**103 runs, verdict=BLIND, rc=3, on 103 of them. No other verdict has ever
been recorded.** Its CRIT lines are all
`relocation.DECLARED_ABSENT subject=<project> host=dexter` — seven projects
declared for dexter that do not exist there — plus
`quota.BLIND_NO_GATE_LINE subject=dexter | no verdict lines`. The sensor is
not malfunctioning. It is correctly reporting that the thing it was pointed
at was never built (§4).

### Repositories: clean, with two real gaps

Nineteen checkouts — 12 top-level repos plus 7 `bashified` verb worktrees.

- **All clean but one:** `dcp-gate-site` has 1 modified file on `master`.
- **All at their origin tip but two.**
- **`basheur` is 6 commits ahead of `origin/main`** — `residue: verb-page
  attempt 024`–`029`. Those six commits exist on one disk.
- **`realisateur`'s working checkout is 12 commits behind `origin/main`.**

That last one is the same defect recorded and fixed on 2026-08-02, recurred
within a day. It matters more than it looks: `~/.local/bin` symlinks point
into *the working checkout*, so every shim on `PATH` is running code from
before `bbf0eb3`. Merged is not deployed, and the consumer here is a working
tree, not a ref.

### Guards and harness

All 34 `~/.local/bin` symlinks resolve — **no dangling symlinks.** `~/.claude`
is wired: `SessionStart`/`SessionEnd` → `session-marker.sh`, `SubagentStop` →
`subagent-closeout.sh`, and `permissions.deny` rules blocking pushes to
`main`/`master` and all force-push forms.

Orphan `*-loop.sh` scripts in `~/.local/bin` naming projects with no directory
on disk: **3** — `chezz-bug-sweep-loop.sh`, `vkv-inventory-bug-sweep-loop.sh`,
`wtul-batch-loop.sh`. (Was 8 on 08-01.)

### Data durability — the biggest improvement, and a real bug

**The good news, and it is substantial.** `garde` holds a 17-set manifest with
a local+remote md5 ledger per set. The two things the 08-01 survey named as
unrecoverable are now **copied and hash-verified**:

- `git-remotes` — 6,773 files, verified 2026-08-02 03:43, empty diff
- `ecosystem1` (the Obsidian vault) — 1,028 files, verified 2026-08-02 21:34

Fifteen of 17 sets have an empty `md5diff`. `Projects` has 59 differences,
**all classified `EXTRA`** — files at the destination that no longer exist
locally, which `garde` correctly calls STALE, not broken, because it never
passes `--delete`. Two sets (`Abecedarian`, `.config`) have non-empty diffs
predating the classifier and are therefore **unclassified — split unknown**.

The single-copy crisis of 08-01 is closed. `basheur` now has a real GitHub
remote (it had none), and the vault and bare repos are on a second disk.

**The bug.** `garde media run --all-pending` — the exact command
`garde-nightly.service` runs — **reports success when it can see nothing at
all.** In `bin/garde:99`, `pending_sets()` does:

```sh
dest_reachable "$d" || continue     # unreachable destination → skipped
```

so when no destination is reachable, no set is *emitted* as pending, the
target list is empty, and it takes the empty-list branch added 2026-08-02:

```
garde: nothing pending -- every set is already copied and proven      (exit 0)
```

That is what happened at 03:34 today, with dexter unreachable. `garde media
list` gets the same situation exactly right — it counts reachable
destinations and calls `verb_blind` — but the nightly path does not.

**Consequence:** the last real backup activity was 2026-08-02 21:34. Two
nights have since reported "every set is already copied and proven" while
copying nothing. The failure this ecosystem's own thesis is *about* — silence
reported as health — is live inside its durability tool, on the code path a
timer runs unattended.

The fix is one condition: `--all-pending` with zero reachable destinations
must exit 6, not 0.

### Also true

`scheduler sweep` runs every 15 minutes and mails ~7 KB of output to a local
MTA that is in a failed state (`postfix@-`). Every sweep's output is
discarded. `Pegasus` remains `online: false`. **No restore has ever been
tested** — copies are proven by hash, but nothing has been read back.

---

## 4. Operational on dexter

**Nothing. And today, mandark cannot reach it at all.**

Dexter appears on the tailnet as `100.107.253.56`, node type **windows**,
`active; direct 192.168.2.2:41641`. The Windows host is up and answering.

The Linux userland is not:

```
nc 100.107.253.56 22    → OPEN     (Windows sshd; publickey denied for zach)
nc 100.107.253.56 2223  → REFUSED  (the WSL2 sshd — down)
ssh -p 2223 dexter      → Connection refused
```

Two independent faults, and it is worth keeping them apart:

1. **The WSL2 sshd is down.** Refused by IP, so this is not name resolution.
   Port 2223 is the WSL2 sshd holding the `mandark-to-dexter-gardien` key;
   port 22 is Windows. (That distinction is itself a recorded lesson — four
   sessions once misfiled it as a missing credential.)
2. **MagicDNS is broken on mandark.** `getaddrinfo for host "dexter"` →
   *Temporary failure in name resolution*, and `tailscale status` warns
   *"Tailscale can't reach the configured DNS servers."* Anything resolving
   the bare name `dexter` fails independently of (1).

Everything downstream follows from this: `garde`'s only online destination is
unreachable, so backups are BLIND; bibliothecaire's `backup-proof` fails;
ecosim's `relocation` checks report seven projects DECLARED_ABSENT on dexter.

**What was true of dexter's userland when last seen (2026-08-02), and there is
no evidence any of it changed:** no project directory of any kind; `~/.local/bin`
holds only `claude`, `node`, `npm`, `npx`; `~/.config/systemd/user/` empty and
`Linger=no`; zero executable crontab lines; **none of the guard commands
installed** — no `notify-senechal`, no `check-project-busy`, no
`focus-commit`, no `scheduler`. It does hold a live Claude credential and a
file-based `gh` token, and it has 16 cores, 14 GiB RAM and 953 G free — more
of every resource than mandark.

Config for dexter is elaborate and entirely aspirational: `_paced.dexter.conf`
(two participants, both `|0|`), `_runner.dexter.conf` (a `*/30` tick),
`_sweep.dexter.conf` (a deliberate opt-out). Hundreds of lines of carefully
reasoned host-scoped policy, describing a host that runs nothing.

**The honest summary:** dexter is a bigger, quieter machine that serves as
mandark's backup destination and nothing else — and today it is not even
doing that.

---

## 5. What is nowhere

Things this ecosystem believes in that exist in no running form on either
host:

- **Self-development.** Six registered participants, zero enabled, on both
  hosts. The paced runner and the sweep tick both run; the rotation they
  drive is empty. Roughly 220 open ideas sit behind that valve.
- **The verb layer as machinery.** 25 verbs, ~34 PATH symlinks, and exactly
  **one machine consumer** (`garde-nightly.service`). Nothing else — no cron
  line, no other unit, no git hook, no scheduler conf — invokes a verb. The
  layer is a very good CLI for a human, and almost nothing else calls it.
  (This is an improvement on 08-01, when the count was zero.)
- **`man <verb>`.** 25 man pages written, none installed.
- **Anything on dexter.** No repo, no scheduler, no guard command, no unit,
  no cron line.
- **Installability.** Of seven bashified utilities, only `realisateur` ships
  an installer. There is no way to put this ecosystem onto a bare machine,
  which is precisely why dexter is empty despite being the better host.
- **A tested restore.** Copies are hash-proven; no byte has ever been read
  back and used.
- **A second backup destination.** `pegasus` is `online: false`. The 91 %-full
  NVMe and one unreachable WSL2 share are the entire durability story.
- **An end-to-end attestation for bibliothecaire.** Its own health check:
  *"this pipeline has never been observed working end to end."*
- **An owner for `hermes-gateway`.** A failed service, 25 min of CPU, in no
  project's declared footprint.
- **Visibility into the second user account.** `svc-vaporwave` (uid 1001) has
  a live user manager running. Reading its crontab needs a password, so
  whether it still dispatches is **BLIND from here** — it was confirmed
  dispatching nightly on 08-01. Out of scope by request on 08-02; recorded
  here as unknown rather than as absent.

---

## 6. The shape of it

The 08-01 survey's central finding was *detection is excellent, actuation is
absent*. Two days later that is still the shape, with one genuine crack of
daylight: **`garde` got wired.** A verb now has a timer, it runs unattended,
and it moved the two most important unbacked-up things onto a second disk.
That is the first time a faculty in this ecosystem went from prose to
mechanism to *scheduled* without stalling at step two.

And the very same wiring produced this record's sharpest finding: the moment
a verb actually ran unattended, it exposed a silent-success path that a
human running `garde media list` would never have hit. That is not an
argument against wiring. It is the argument *for* it — the bug was always
there, and only dispatch could find it.

What has not changed: nothing dispatches work. The organism senses, judges,
records, and backs itself up, and does no work of its own. The sensors are
correct and unread — a health check FAILED hourly for days, a sensor BLIND
103 consecutive times, 7 KB of sweep output mailed nightly into a dead MTA.

The one asymmetry worth acting on is dexter. It has more of every resource,
it is credentialed, and it holds the only second copy of this estate's data.
It is empty because nothing here knows how to install itself onto a bare
machine — and today it is unreachable, which means the estate is running on
one 91 %-full disk with no verified second copy and a backup job that reports
success regardless.

---

## 7. Corrections to the prior records

Re-probed today; these prior statements are no longer true.

| prior claim | source | today |
|---|---|---|
| basheur has no GitHub repository; single-copy | 08-01 §5 | **False now.** `origin` = `https://github.com/hf7y/basheur.git`. 6 commits unpushed. |
| `git-remotes` and `ecosystem1` in no backup set | 08-01, 08-02 | **Fixed.** Both copied and md5-verified 2026-08-02. |
| 5 backup sets PENDING | 08-02 | **Superseded.** 15 of 17 have empty diffs; the current all-PENDING display is a BLIND artifact of an unreachable destination. |
| four verbs exit 0 on `--nonsense` | 08-01 §4(a) | **Fixed.** All 25 exit 2. |
| `~/.local/bin/silence-audit` is a dangling symlink | 08-01 §4(c) | **Fixed.** Regular file; zero dangling symlinks. |
| 8 orphan `*-loop.sh` scripts | 08-01 §5 | **3.** |
| the verb layer has zero machine consumers | 08-01 §1 | **One:** `garde-nightly.service`. |
| `gardien.service` failing nightly since 07-24 | 08-01 §5 | **Retired.** Unit gone; `garde-nightly.timer` replaced it and succeeds. |
| `front-door-watch.service` active, looping on a deleted path | 08-01 §5 | **Disabled and inactive;** unit file still installed. |
| `crt-whisper-server.service` active on `0.0.0.0:8991` | 08-01 §5 | **Gone.** No such unit. |
| dexter reachable on 2223 | 08-02 | **False today.** Connection refused by IP; MagicDNS also broken. |
| garde-nightly had never run | 08-02 | **It runs.** And its success is not trustworthy — §3. |

---

## 8. Re-derive this yourself

```sh
crontab -l | grep -v '^\s*#' | grep -v '^\s*$'         # what dispatches
grep -E '^[a-z].*\|1\|' scheduler/schedule/_paced*.conf # enabled participants (NOT grep -l enabled=1)
systemctl --user list-timers --all                      # user-level jobs
systemctl --user list-units --state=failed
systemctl list-units --state=failed
garde media list                                        # data safety (exit 6 = BLIND)
journalctl --user -u senechal-health -n 60 | grep -E 'FAIL|WARN'
grep -o 'verdict=[A-Z]*' ~/.local/share/ecosim-sensor/run.log | sort | uniq -c
nc -z -w5 100.107.253.56 2223                           # dexter's WSL2 sshd
for v in $(ls ~/.local/bin); do $v --nonsense >/dev/null 2>&1; \
  [ $? = 0 ] && echo "BAD $v"; done                     # fail-loud check
```

For each repo, `git status --porcelain` and
`git rev-list --left-right --count @{u}...HEAD` — and check the **working
checkout**, not just the ref, because the shims read the checkout.

---

## 9. What this record does not cover

- The `.idea` inbox (42 files, all filed 2026-07-28/29, unmoved since).
- Milestones and `WAITING-ROOM.md` parking state.
- Everything `svc-vaporwave` — needs a password to read.
- Dexter's Windows side.
- Test suites, and any source beyond `bin/garde`'s pending logic.
- Whether the copies in `garde`'s ledger can actually be restored.

*Recorded 2026-08-03 on mandark. Every number produced by a command; where a
domain could not be read, this file says BLIND rather than reporting nothing.*
