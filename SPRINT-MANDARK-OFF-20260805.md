# SPRINT: mandark down, monkey up — overnight, quota-paced

*Opened 2026-08-05 by Zach: "migrate max number of repos off mandark, over to
monkey, get self-dev up for as many as possible. overnight sprint, paced around
usage quotas."*

**Written to be read cold.** Every number below was produced by a command on
2026-08-05 and the command is shown. Re-probe before acting on any of them —
this document's own §7 is a list of times a confident number was wrong.

Siblings: `VERB-DISTRIBUTION.md` (how a verb reaches a host), `MONKEY.md`
(where self-dev lives), `THE-FLOOR.md` (what must hold before arming).

---

## 1. The one thing that gates everything

`installe` (senechal `bin/installe:194-213`) installs a verb by creating a
**`bashified` worktree of a full dev clone**:

```sh
tree="$PROJECTS/$project-verbs"
git -C "$repo" worktree add "$tree" bashified
```

So `~/.local/bin/installe` → `senechal-verbs/bin/installe` → a worktree of
`~/Documents/Projects/senechal`. **Installing a verb build frees nothing until
this changes.** Verified 2026-08-05:

```
$ readlink ~/.local/bin/installe
/home/zach/Documents/Projects/senechal-verbs/bin/installe
```

**The change:** link from `~/.local/share/verb-builds/current/<project>/bin/<verb>`
instead of from a worktree. `bin/install-verb-build.sh --link` already does
exactly this and already refuses to clobber anything `installe` owns — it was
written to stop short of this decision, not to make it.

**What it unblocks, in one move:** bibliothecaire 88M, senechal 25M, gardien
6.1M, vim-arcade 6.2M ≈ **125M across four repos**, because those four are
pinned by *nothing else*.

This is the first task of the sprint. Nothing downstream of it is worth
starting first.

## 2. Quota, and why this sprint is pace-limited rather than time-limited

Read at sprint open:

```
$ scheduler/bin/usage-gate.sh
window=7d util=0.330 burnline=0.266 slack=-0.064 status=allowed resets_in_min=7399
window=5h util=0.070 burnline=0.234 slack=+0.164 status=allowed resets_in_min=229
# RUN -- slack available (tightest 7d at 33% vs burn-line 27%, -6pts)
```

**Read that carefully: the 7-day slack is NEGATIVE.** We are already burning
ahead of an even-burn pace, with ~5.1 days left in the window. It says
`allowed` anyway, and the reason is the load-bearing fact of this sprint:

- `schedule/_usage.conf` sets **`USAGE_RUSH_BEFORE_RESET_MIN=10080`** — seven
  days, the *entire* 7d window — against the gate's documented default of
  `120`. So `rush` is **permanently true and the even-burn hold never fires**.
- `USAGE_CEILING=0.99`. The only real stop is a hard 99% ceiling and a
  `rejected` status.
- The `flock` is **per account** (`STATE_DIR="$HOME/.local/share/$JOB_NAME"`),
  so the four monkey accounts can dispatch in the same tick and nothing on
  that host serialises them.

**Consequence for an overnight run: the gate will say RUN essentially until the
quota is gone.** It is a resource ceiling, not a pacer. Anyone treating a
`RUN` verdict as "there is room to spare" will find the ceiling with the
sprint half-finished. See `realisateur#46` (deferred) for the metabolism/quota
split that would fix this properly — **do not** attempt that fix inside this
sprint; it is explicitly post-migration.

### The pacing rules for this sprint

1. **Probe before each phase, not once at the start.** `usage-gate.sh` costs
   ~23 Haiku tokens. Record `util`, `burnline`, `slack` in the sprint log at
   every phase boundary.
2. **Hard floor: stop adding dispatchers at 7d util ≥ 0.60.** That is a
   sprint rule, not a mechanism — nothing enforces it. Write down the reading
   that made you stop.
3. **Arm new accounts one at a time, never in a batch.** Each new account is a
   new dispatcher against one shared quota, and the per-account lock means
   concurrency is unbounded by design.
4. **Prefer `--check` / preview modes.** Every tool in this estate has one, and
   they cost no agent tokens.
5. **The human-driven work in §3 costs quota too.** An interactive session
   spends the same budget and is gated by nothing.

## 3. Phase order

Each phase states its own done-condition. Do not start the next until the
previous one's witness has actually been produced.

### Phase 0 — repoint `joue` (5 minutes, no quota)

`~/.local/bin/joue` is a **hand-installed symlink into a dev clone**, owned by
nothing and invisible to `install-verbs.sh` — the same unowned-symlink shape as
scheduler's 2026-07-29 dispatch outage.

```
$ readlink ~/.local/bin/joue
/home/zach/Documents/Projects/vim-arcade/joue
```

`joue` became a declared verb on 2026-08-05 (vim-arcade #52/#53, merged) and is
in the build. Verified running from the build with no dev clone:

```
$ cd /tmp && PYTHONPATH= ~/.local/share/verb-builds/current/vim-arcade/bin/joue --help
joue -- play your live GitHub issue/PR queue as a vim-arcade level
```

**Done when:** `joue` resolves through `verb-builds/current` and
`~/Documents/Projects/vim-arcade` can be removed. This is the cheapest proof
the build works in daily use, before four repos are bet on it.

### Phase 1 — `installe` reads a build (the gate, §1)

**Done when:** all 32 `~/.local/bin` verbs resolve through
`~/.local/share/verb-builds/current`, `install-verbs.sh` reports the declared
set present, and `bibliothecaire-verbs`, `senechal-verbs`, `gardien-garde`,
`vim-arcade-verbs` are gone as worktrees.

**Refuse to proceed if** the build is stale or unverified. `install-verb-build.sh
--check` exits **3 = BLIND**, which is *not* "up to date".

### Phase 2 — remove the four unblocked clones (~125M)

`bibliothecaire`, `senechal`, `gardien`, `vim-arcade`.

Run `fauche` first and **believe it over any hand-rolled check** (§7.2).
Deletion stays a human's act — `fauche` writes a script and never runs it.

**Done when:** the four are gone, every verb still runs, and
`notify-senechal` still works (it no longer needs a senechal clone —
scheduler#22 / realisateur#51, merged 2026-08-05).

### Phase 3 — self-dev for the five registered-not-armed projects

`baudin`, `crt`, `groc-mangr`, `nine-speakers`, `sequestria` were registered
2026-08-05 (`scheduler#19`, `#21`). Each has a `schedule/<p>.conf` with Tier 2
**deliberately blank** (`BATCH_JOB_NAME=""`, `BATCH_CRON=""`) — that is what
"registered, not armed" means mechanically.

Each needs three things, in order:

1. **An account on monkey.** One root command:
   `sudo bash ~/realisateur/bin/setup-selfdev-project.sh <p> --apply`
   (run **on monkey**; it resolves siblings via `dirname $0` so it cannot be
   piped over ssh. A current realisateur checkout lives at
   `/home/zach/realisateur` on monkey for exactly this.)
   It stops before arming, on purpose.
2. **A `.scheduler/FOCUS.md`.** **None of the five has one**, and
   `BATCH_PROMPT` runs `/nightly-batch`, which builds against FOCUS.md's
   stated priorities. Arming without it dispatches an agent at nothing.
   *This is the real work of phase 3 and it is not scriptable.*
3. **A rotation row + a FREEZE line.** `_paced.monkey.conf` row `<p>|1|1|<abs
   path>` and `EXEMPT: <p>@monkey` in `schedule/FREEZE`. Then, as that user on
   monkey: `git pull --ff-only && ./bin/sync-crontab.sh --apply`.
   **Always preview `sync-crontab.sh` before `--apply`** (§7.3).

**Pace this phase by the §2 rules.** Five new accounts would take monkey from
4 dispatchers to 9 on one quota, with a per-account lock. Expect to arm
**two or three**, not five, and record the gate reading that decided it.

**Done when:** each armed account has produced a commit on its own
`origin/main` **confirmed from another host**, and a `question`/`idea` issue
filed on its own repo. A crontab line is not a witness.

### Phase 4 — the remainder, and what stays

- `ecosim` 6.5M — **1** non-verb command: `ecosim-sensor`.
- `basheur` 4.3M — **2** non-verb commands: `basheur`, `bashify`.

  *(Both counts were higher in this file's first draft. `ecosim-sensor-tick`
  resolves into realisateur, not ecosim, and `garde` is gardien's declared verb
  — already covered by the build. Re-derived with the build manifest as the
  filter, which is the only way to tell "non-verb command" from "verb I have
  not installed yet". Recount before acting: this is exactly the class of
  number §7 says to distrust, including in this file.)*

**Staying, per Zach 2026-08-05 ("last or never; scope the shim layer as
something separate that comes later"):**

- `realisateur` 39M — 12 non-verb commands + 4 `~/.claude` references.
- `scheduler` 50M — 13 non-verb commands + a crontab line.

These are the **shim layer**: `install-shims.sh`-generated commands that exec
scripts *inside* the checkout. The verb build does not cover them, and that is
a fourth coupling `VERB-DISTRIBUTION.md` §2 does not name. Out of scope here.

**Explicitly out of scope (Zach): `dog` (566M) and `dcp-gate-site` (3.8M).**
`dog` is *not a git repository* — 566M with nothing to clone it back from.
Both were hand-initialised while self-dev was parked; reconciliation is later
work, not this sprint. **Do not delete either.**

## 4. Where things stand at sprint open

```
$ du -sh ~/Documents/Projects            796M
  dog 566M · bibliothecaire 88M · scheduler 50M · realisateur 39M
  senechal 25M · ecosim 6.5M · vim-arcade 6.2M · gardien 6.1M
  basheur 4.3M · dcp-gate-site 3.8M
```

Already true, verified today:

- **monkey: 4 accounts armed** — `ecosim` (3001), `vim-arcade` (3000),
  `bibliothecaire` (3002), `chezz` (3003), each with 1 RUNNER cron line.
- **dexter: cleared.** `~/realisateur`, `~/scheduler` and 10 shims removed;
  `~/.local/bin` is exactly `claude node npm npx`. Kept: `~/.ssh/selfdev_monkey`
  (the only path to monkey) and `/mnt/d/gardien-media` (261G of backups).
- **The front door is GitHub.** `scheduler -i` and `notify-senechal` file
  issues; neither writes a local clone. That is what unpinned senechal.
- **The verb build works end to end.** `hf7y/verbs`, nightly `30 1 * * *`,
  latest `build/2026-08-05T040843Z` = **32 verbs / 12 projects / 1.9M**, all
  passing a `--help` witness.

## 5. Procedures, verified today

```sh
# quota, before every phase
~/Documents/Projects/scheduler/bin/usage-gate.sh

# cut a build by hand (CI does this nightly)
gh workflow run build-verbs --repo hf7y/verbs && gh run watch <id> --repo hf7y/verbs

# consumer side
install-verb-build.sh --check            # exit 3 = BLIND, NOT "up to date"
install-verb-build.sh --latest --apply
install-verb-build.sh --list
install-verb-build.sh --rollback <id>    # local only, needs no network

# a new self-dev account (ON MONKEY, as root)
sudo bash ~/realisateur/bin/setup-selfdev-project.sh <p> --check
sudo bash ~/realisateur/bin/setup-selfdev-project.sh <p> --apply

# after any rotation change, as that user on monkey
cd ~/Documents/Projects/scheduler && git pull --ff-only
./bin/sync-crontab.sh            # PREVIEW FIRST, ALWAYS
./bin/sync-crontab.sh --apply

# recoverability before deleting anything
fauche                            # believe it over any hand check
```

**ssh to monkey/dexter is non-interactive: `~/.local/bin` is NOT on PATH.**
Export it explicitly or commands "do not exist".

## 6. Open decisions this sprint must not silently make

- **Does the build carry the shim layer?** If yes, mandark can eventually shed
  `realisateur` and `scheduler` too. If no, "no repos but senechal" is
  unreachable and should stop being described as the goal. Zach: scope it
  separately, later.
- **`realisateur`'s `.idea` inbox** stays a local file on purpose — its nightly
  batch consumes those files, so producer and consumer must move together.
- **`resolve_focus_path()` in `bin/scheduler` now has no callers** (scheduler#22).
  Remove it or give it a stated purpose.
- **`realisateur#46`** — splitting tempo out of `usage-gate.sh`. Deferred
  post-migration by title. Do not pick it up here, but §2 is why it exists.

## 7. Five ways a confident answer was wrong today

Read this before trusting anything, including this file.

1. **A credential can be correct and not be the one in use.** The first real
   CI build refused with 17 `Repository not found` lines and was diagnosed as a
   missing PAT permission. The PAT was correct; `actions/checkout` had
   persisted a repo-scoped `GITHUB_TOKEN` as a local `extraheader` that beat
   the global `insteadOf` rewrite. The disproof was already in the same log.
2. **A hand-rolled recoverability check said `dog` was safe to delete.** It is
   not a git repository. `fauche` caught it. Use the estate's guard, not a
   fresh one.
3. **Fixing a bug armed five projects.** Broken `BATCH_PROMPT` quoting had been
   *accidentally suppressing* five nightly cron lines; repairing the quoting
   installed them on a live host. "The errors are gone" is not a finish line.
   Caught only because `sync-crontab` was previewed before `--apply`.
4. **A witness that passed on a completely broken build.** The assemble check
   was `-f && -x`; every verb existed, was executable, and could not run
   (`lib/verb.sh` was not carried). It now runs each verb's `--help`.
5. **A reference scan reported senechal as pinned by nothing**, minutes after
   `notify-senechal` had written into its working tree. The pin was
   *runtime-derived* from a conf field, invisible to grep.

**And an attribution problem that affects every record this sprint produces:**
`realisateur#40`. A session closeout on 2026-08-05 credited this session with
merging two PRs and closing two issues it did not touch. Every actor is `hf7y`,
so no tool can distinguish them. **Sprint logs written by agents are not
evidence of who did what.** Prefer a probe over a report, including over this
file.

---

*Sprint opens with §3 Phase 0. If quota is tight, Phase 0 alone is worth the
night: it retires the last unowned symlink on this host and proves the build in
daily use.*
