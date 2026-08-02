# Snapshot: mandark and dexter — 2026-08-02, ~02:50 CDT

**Method.** Every number below was re-probed at the time of writing, not read
out of an earlier document. Where something could not be probed it says so
rather than carrying a stale figure forward — the recurring failure this
ecosystem records is a survey headline that was true once.

**Deliberately out of scope, by request:** everything vaporwave (the
`svc-vaporwave` account and its jobs, `aedile`, `vkv-inventory`,
`/srv/vaporwave-reports`, the office/`nomac`/wavebucks work) and everything on
dexter's **Windows** side (VirtualBox, `C:`/`D:`, scheduled tasks, autologon).
This is the two Linux userlands only. Their absence here is a scope decision,
not a claim that they are idle.

---

## mandark — the working host

Ubuntu 24.04.3, kernel `6.8.0-136-lowlatency`, 7 GiB RAM, root filesystem
466 G at **91 % used**. Reachable on the tailnet. This is the laptop: it
sleeps, it travels, and senechal's own config already declares it
`expect: intermittent`.

### What actually dispatches

Three executable cron lines, all generated rather than hand-written:

| schedule | command | tag |
|---|---|---|
| `*/30` | `ecosim-sensor-tick` | `arme:ecosim-sensors:MONITOR` |
| `0 */6` | `PACED_MAX_PER_TICK=1 usage-paced-runner.sh` | `scheduler:...:RUNNER` |
| `*/15` | `scheduler sweep` | `scheduler:...:SWEEP` |

**But nothing is enabled to run.** `schedule/_paced.conf` has **0** rows with
`enabled=1`, so the paced runner ticks against an empty rotation. Six projects
are registered (`ecosim`, `gardien`, `realisateur`, `scheduler`, `senechal`,
`vim-arcade`); none is live. Self-dev is parked, deliberately, and this is
what parked looks like from the outside: the dispatcher runs and dispatches
nothing.

THE FLOOR wants that surface to be **2** lines. It is 3.

### systemd --user

- `senechal-health.timer` — **active**, hourly. Its alert path is KDE Connect
  plus `notify-send`, so it needs a live session bus.
- `garde-nightly.timer` — **armed for 03:33**, and as of 02:50 it has **never
  run**: `LAST` is `-` and its journal is empty. Tonight is its first attempt.

### Backups

`garde media list` reports 17 sets against destination `dexter-d`. Twelve are
`ok x1`. **Five are `PENDING`:** `Downloads`, `Pictures`, `Projects`, and the
two added today — **`git-remotes` (54 M, 14 bare repos, which were in no
backup set at all until now)** and `ecosystem1` (8.8 M, the Obsidian vault).
The second destination, Pegasus, is `online: false`.

So: media is largely copied; the things that would be unrecoverable are queued
but not yet copied. Nothing has been restore-tested. `garde.json` is
gitignored live config — it is not in any repo.

### Repositories

Twenty repos under `~/Documents/Projects`, and they are in good order:

- **0 host-only branches and 0 ahead-of-origin, across all twenty.** Re-run of
  the doctrinal test, not `@{u}`. This is the precondition on ever moving a
  repo off this host, and it is currently satisfied.
- Every origin is a real remote; none is a local path.
- One dirty tree: **`dcp-gate-site`** (1 file, on `master`).
- The `*-verbs` repos sit on their `bashified` branches, as intended.

### Guards and harness

All ten realisateur-owned shims resolve, plus the verbs (`arme`, `dose`,
`garde`, `fauche`, `transplante`, `juge`, `veille`, `sonde`, `ausculte`, …).
No dangling symlinks in `~/.local/bin`.

`~/.claude` is wired: `SessionStart`/`SessionEnd` → `session-marker.sh`,
`SubagentStop` → `subagent-closeout.sh`, and **7 `permissions.deny` rules**
covering `git push` to `main`/`master`, both `HEAD:` forms, and all three
force-push forms.

**A finding worth keeping.** Until this morning the working checkout of
realisateur was **14 commits behind `origin/main`**. Work had been merged; the
checkout every shim on PATH reads had never pulled. So `closeout-lint` had no
`--repo`, `hooks/` did not exist locally, and the `SubagentStop` hook had been
silently taking its degraded fallback path — announcing on stderr that it was
not checking unpushed commits, into a stream nobody reads. *Merged is not
deployed*, and the consumer here is a working tree, not a ref. Fixed by
fast-forwarding and re-running `install-shims.sh`.

**A second, from the same morning.** Two pull requests that never conflicted
produced a broken `install-shims.sh`: one added `BIN_DEST`/`CMD_DEST` as
environment overrides together with the test that needs them, the other edited
the same block from the older base. Git merged both cleanly and the hardcoded
lines won. The test then ran the installer against the **real** `~/.local/bin`
and `~/.claude/hooks` while asserting things about a temp directory. A clean
merge is not a correct merge, and neither branch's tests could have caught it.

### What is broken or unread right now

- `ausculte dead-config` exits **6 — BLIND**. It cannot read a crontab it
  needs, so it reports "I cannot see", not "nothing to report".
- `reach-lint --strict` exits 1 on 5 `scope-undeclared` FLAGs, all in other
  repos' `.claude/commands/*.md`.
- `hygiene-lint --strict` exits 1 on ~63 FLAGs across 6 projects.
- `closeout-lint --strict --repo` on realisateur exits **6**: one linked
  worktree unexamined. Structural, not a fault — see the note on BLIND below.
- `~/.local/bin/scheduler.bak.2026-07-28` is still on PATH: a standalone
  118 KB dispatcher that needs no other file to run.
- `bibliothecaire`'s three system timers are live and firing on schedule
  (intake every 15 min, OCR hourly, health daily). This is the one product on
  the box doing real work unattended, and it is hardware-bound: a physical
  scanner writing to an SMB share, with OCR ceilings tuned to this machine's
  7 GiB after a real OOM kill.

### Data that exists in one place

`~/git-remotes` 54 M · `~/bibliothecaire-intake` 1.4 G · `~/ecosystem1` 8.8 M.
The first two have never been copied anywhere. On a disk at 91 %.

---

## dexter — the WSL2 userland

Ubuntu 26.04 LTS, kernel `6.18.33.2-microsoft-standard-WSL2`, **16 cores,
14 GiB RAM, 953 G free**, up 5 days 8 hours. Reachable unattended from mandark
over the tailnet on **port 2223** (port 22 is the Windows sshd — the
distinction that four sessions once misfiled as a missing credential).

### What is on it

Nothing. This is not a figure of speech:

- `~` holds dotfiles only. **No project directory of any kind.**
- `~/.local/bin` holds exactly `claude`, `node`, `npm`, `npx`.
- `~/.config/systemd/user/` is **empty**. `Linger=no`.
- crontab has **0** executable lines.
- The only systemd timers are three Ubuntu stock ones.

**Nothing on dexter dispatches, and nothing on dexter is scheduled to.**

### What it does have

- A **live Claude credential** (`~/.claude/.credentials.json`, written
  2026-08-01, carries a refresh token).
- A working **`gh` token in a file** — `hf7y`, scopes including `repo`.
  File-based, so it survives cron with no session bus.
- `/dev/kvm` present. **No** qemu, virt-install, docker or podman.
- `sudo` requires interactive authentication. No unattended root.

### What it lacks that matters

**None of the ecosystem guard commands exist there** — `notify-senechal`,
`check-project-busy`, `focus-commit`, `silence-audit`, `scheduler`,
`closeout-lint` are all MISSING. Any machine-scoped change made on dexter
today goes unfiled and unannounced, because the command that would file it is
not installed.

That is the shape of the whole gap: dexter is a capable, reachable,
credentialed host with **more** RAM, cores and disk than mandark, and it
cannot receive this ecosystem because nothing in the ecosystem knows how to
install itself onto a bare machine. Of the seven bashified utilities, only
`realisateur` ships an installer.

---

## The two together

| | mandark | dexter (WSL2) |
|---|---|---|
| role | working host, does everything | bare, does nothing |
| RAM / cores | 7 GiB | **14 GiB / 16** |
| free disk | 9 % of 466 G | **953 G** |
| always on | no — a laptop that sleeps | distro dies on reboot until logon |
| dispatch | 3 cron lines, 0 projects enabled | none |
| guards installed | all | **none** |
| Claude credential | yes | yes |
| unattended root | — | **no** |

`gardien`'s backups run **from** mandark **to** dexter, so the two hosts are
already coupled in the one direction that matters: dexter is where mandark's
data survives. Nothing runs *on* dexter to make use of that.

## Open, and known

- The 03:33 backup has not yet run, and no restore has ever been verified.
- The cron surface is 3 where the current milestone wants 2, and clearing the
  third needs a password.
- One project must be enabled for the rotation to mean anything; it is
  correctly blocked behind a verified backup.
- A repo cannot be reaped or relocated until `fauche` learns to check machine
  footprint — its `BINDIR` is assigned and never used.

**On BLIND, since it now gates.** From inside a linked worktree, `git worktree
list` always reports the main checkout, so a BLIND count of 1 is *normal* and
carries no information. Every repo probed today — realisateur, its worktree,
senechal — returned exactly 1. The signal is the trend, not the value, which
is why watching it was handed to ecosim rather than wired into a hook that
would otherwise refuse every run.
