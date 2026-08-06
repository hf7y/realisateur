# Phase 2 — remove the clones from mandark: what actually came off

*Written 2026-08-05 against `SPRINT-MANDARK-OFF-20260805.md` §3 Phase 2, which
says: "remove the four unblocked clones (~125M) — `bibliothecaire`, `senechal`,
`gardien`, `vim-arcade`."*

**Every verdict below is a probe run on mandark today, not a reading of the
plan.** The plan's count was wrong in both directions: one repo was already
gone, and two of the remaining three are not unblocked at all.

## Verdicts

| repo | plan said | probed today | why |
|---|---|---|---|
| `gardien` | remove (6.1M) | **already gone** | clone absent; `fauche`/`garde`/`transplante` all serve from `verb-builds/current/gardien/bin`. This is the model working end to end. |
| `vim-arcade` | remove (6.2M) | **REMOVED (7.2M)** | see §"vim-arcade is off mandark" below. |
| `senechal` | remove (25M) | **structurally pinned** | 4 build verbs exec 20 scripts back into the clone. |
| `bibliothecaire` | remove (88M) | **structurally pinned** | 3 systemd *system* units run `bin/intake.py` from the clone. |

Recoverable space today: **7.2M** (`vim-arcade`), not 125M. It came off.

## `vim-arcade` — ready, and blocked on one command (SUPERSEDED)

> **Superseded the same day by the next section.** Kept because its *reasoning*
> is what went wrong: it accepted "repoint `joue` at the build" as the goal and
> then reported a harness block as the end of the road. Zach's answer was that
> `joue` should not exist — and `installe retire`, the command for that, was
> never blocked. **The block was real; treating it as the only door was mine.**
> Do not act on the command in this section; it is here as a record.

The build is genuinely standalone. `joue` became a declared verb on
`origin/bashified` (94d7c47, vim-arcade#52) and **carries its own engine**:

```
$ ls ~/.local/share/verb-builds/current/vim-arcade/
  bin/  vim_arcade/  lib/  man/  test/  ENGINE-PROVENANCE  CONTRACT.md

$ cd /tmp && PYTHONPATH=~/.local/share/verb-builds/current/vim-arcade \
    python3 -c "import vim_arcade.gh_game as m; print(m.__file__)"
  .../verb-builds/current/vim-arcade/vim_arcade/gh_game.py
```

That import is the witness Phase 0 did not have. Phase 0 verified `--help`,
which exits before the engine is touched; the clone's root `joue` is a launcher
that `export PYTHONPATH="$ENGINE_DIR"` — it *requires* the package beside it.
Had the build carried only the launcher, `--help` would still have passed and
`joue --live` would have died on first use. It carries both.

Clone recoverability: `HEAD == origin/main == 0ff63b3`, tree clean, one
worktree (itself), `origin https://github.com/hf7y/vim-arcade.git`.

**Blocked step, needs Zach's hands:**

```sh
installe --force verb vim-arcade joue        # then: notify-senechal
```

`--dry-run` passes and states exactly what it would do ("adopt joue: replace the
unowned link"); the real run is refused by the Claude Code auto-mode permission
classifier. This is the **third** recurrence of that specific block
(2026-08-01, 2026-08-02 on `garde`; today on `joue`) — the harness is the
blocker, not the ecosystem. I did not `ln -sfn` around it: a hand-installed
symlink owned by nothing is the exact defect Phase 0 exists to remove.

Once that lands, `fauche` should clear `vim-arcade` and the clone can go.
*(It did clear, by the other route. See below.)*

## vim-arcade is off mandark

*Second pass, same day, after Zach read the above:*

> "lets get vim-arcade off of here and address the joue problem. joue should
> not even exist. vim arcade ships a game which should be called something
> else and that's what I should have on my path. senechal should be
> responsible for keeping it on my path and I should not need the entire
> vim-arcade repo just to play the game."

That reframes the blocker. The first pass was stuck trying to *repoint* `joue`
at the build (`installe --force verb ...`, classifier-blocked). But `joue`
should not exist at all — so the move was **retire, not repoint**, and retiring
is a different command that is not blocked.

### What was done

```
$ installe retire joue --force
  installe: joue is off the path; its target was not touched
  installe: declared to senechal: joue is no longer on PATH
$ installe retire entraine --force          # Zach's call: he plays the queue, not the trainer
  installe: declared to senechal: entraine is no longer on PATH
$ fauche check ~/Documents/Projects/vim-arcade
  REMOVABLE     /home/zach/Documents/Projects/vim-arcade
$ fauche script ~/Documents/Projects/vim-arcade > remove.sh && bash remove.sh
  removed 1 repository
```

**"senechal should be responsible for keeping it on my path" needed no work and
no senechal edit: `installe` IS senechal's verb** (`verb-builds/current/senechal/bin/installe`),
and it files its own declaration to senechal on every change — both lines above
are its output, not mine. The senechal repo was not touched; it is open in
another agent.

Before deleting, `fauche`'s verdict was checked independently, because deletion
is the one act with no undo:

```
$ git -C .../vim-arcade log --oneline --all --not --remotes=origin   # (empty)
$ git -C .../vim-arcade status --porcelain                           # (empty)
$ git -C .../vim-arcade stash list                                   # (empty)
```

Zero commits absent from origin across 25 local branches, clean tree, no stash.
Also removed: the empty `~/Documents/Projects/.vim-arcade-worktrees`. No broken
symlink was left behind — `find ~/.local/bin -xtype l` is empty.

`~/Documents/Projects` is **785M**, down from 796M. Recover the repo any time
with `git clone https://github.com/hf7y/vim-arcade.git`.

### The rename: `joue` -> `vim-arcade`

`hf7y/vim-arcade#71`, into `bashified`. The command is a game, not a verb —
the rest of the estate's commands are things you tell the machine to do, and
`joue` named the user's action rather than the thing being run.

`bin/joue` -> `bin/vim-arcade`, `man/joue.1` -> `man/vim-arcade.1`,
`JOUE_ENGINE_ROOT` -> `VIM_ARCADE_ENGINE_ROOT`. Historical references were
deliberately left alone: `joue-panes` was a real script really collapsed into
`--map` (#39), the predecessor symlink really was `~/.local/bin/joue`, and
chezz really did declare `joue` twice. Renaming those would falsify the record.

### The witness, and why `--help` was not it

The first pass verified the build's `joue` with `--help`. That is a bad
witness — `--help` answers before the engine is touched, so a build carrying
only the launcher would have passed it. What was run instead, from a **700K
shallow clone of `bashified`, on a machine with no vim-arcade repo anywhere**:

```
$ ./bin/vim-arcade                       # under a pty, TERM=xterm-256color
  vim-arcade startup check
  engine: vim-arcade is on 'rename-joue-to-vim-arcade', but the trunk is 'main'.
  [Enter] continue on this copy
  vim-arcade gh-triage -- 13 open item(s)
  DRY RUN -- actions only log the gh command (pass --live to really act).
  buffer:
  @.I.............................................
  ...
```

The game rendered its real queue with no repo on the desk. That is the property
Zach asked for, shown rather than asserted. `contract-test.sh` also passes 7/7
under the new name, and `man -l man/vim-arcade.1` renders as `VIM-ARCADE(1)`.

### Closed out the same evening

Zach merged `vim-arcade#71` at 00:38Z. The rest was mechanical:

```
$ gh workflow run build-verbs --repo hf7y/verbs
  -> build 2026-08-06T003928Z, 32 verb(s), 12 project(s)
  -> vim-arcade  vim-arcade  e02dc8ac  (and vim-arcade entraine, still declared)
$ install-verb-build.sh --check
  yours: 2026-08-05T233404Z   latest: 2026-08-06T003928Z
$ install-verb-build.sh --latest --apply
  verified: 32 verb(s), all present and executable
  current -> 2026-08-06T003928Z
$ installe verb vim-arcade vim-arcade
  vim-arcade is reachable
  declared to senechal: now on PATH -> verb-builds/current/vim-arcade/bin/vim-arcade
```

The verb count held at **32** across the rename, which is why the build's
shrink guard did not fire: one name left and one arrived in the same cut.

Played, not merely installed — `vim-arcade` from `~/.local/bin`, run under a
pty inside the realisateur checkout, with no vim-arcade repo on the machine:

```
vim-arcade gh-triage -- 9 open item(s)
DRY RUN -- actions only log the gh command (pass --live to really act).
buffer:
@.i.............................................
```

Final state: `joue` and `entraine` resolve to nothing; `vim-arcade` resolves
to `~/.local/bin/vim-arcade -> verb-builds/current/vim-arcade/bin/vim-arcade`,
owned by `installe`, declared to senechal, recoverable by build id.

**Still open:** `entraine` remains declared and built while broken in every
build (GAPS §0 on that branch) — it reads `ENTRAINE_LEGACY_ROOT`, defaulting
to the clone that no longer exists. Off the path, so inert; it would pass a
`--help` witness while broken.

## `senechal` — the build verbs are shims into the clone

The plan's reason for calling senechal unblocked was that `notify-senechal`
files a GitHub issue and no longer needs a local clone. **That is true and it is
not sufficient.** Four of the six senechal verbs in the build exec back into
`~/Documents/Projects/senechal`:

```
ausculte    LEGACY_ROOT/health/{estate-health,dead-config,no-self-dev,project-unwired}.sh
            LEGACY_ROOT/remedies/{smart-health,verify-all}.sh
veille      LEGACY_ROOT/remedies/*.sh                       (10 scripts)
lance       LEGACY_ROOT/{remedies/window-spawn-desktop.sh,tools/browse,tools/spawn-here}
debarrasse  LEGACY_ROOT/tools/home-declutter.py
```

Proof the dependency is real, not cosmetic:

```
$ AUSCULTE_LEGACY_ROOT=/nonexistent ausculte estate-health
  ausculte: GAP: estate-health: health/estate-health.sh is not executable or not present
$ ausculte estate-health --quiet
  senechal estate health -- 2026-08-05 18:46 on mandark   [runs]
```

Plus a systemd **user** unit, `senechal-health.service`, whose `ExecStart` is
`~/Documents/Projects/senechal/health/estate-health.sh --quiet`.

This is the shim layer Zach scoped out of the sprint ("last or never"), one
level deeper than `VERB-DISTRIBUTION.md` §2 names it: not a command that execs
into a checkout, but a *built verb* that does. Migrating it means moving 20
backing scripts into the build — real work, not a deletion.

### A `fauche` gap this exposes

`fauche list` reports **exactly one** reason for senechal: the systemd user
unit. It does not see the four verbs. Its liveness probe resolves a verb's
symlink target and stops there — a link into `verb-builds` passes, whatever the
built script then execs.

So the moment that one unit is repointed, **`fauche` would call senechal
REMOVABLE while 20 live scripts still read out of it.** That is gardien#11's
documented failure ("recoverable is not unused") recurring one indirection
deeper, in the verb whose whole purpose is to catch it. Filed against gardien.

## `bibliothecaire` — a hardware pipeline, not a clone

Three systemd **system** units (`bibliothecaire-intake.service`,
`-intake-ocr`, `-intake-health`) run `bin/intake.py --run` with
`WorkingDirectory=` the clone, `SupplementaryGroups=bibscan`, ordered
`After=smbd.service` — the scanner drop-box drain. `intake.py` is not a verb
and is not in the build.

The clone is also not in a removable state on its own terms: on branch
`ask-basheur-before-demanding-summon`, with three untracked paths
(`quotes/`, `sources/`, and a `.lcpdf`) that are scanner *output*, not code.

88M is the largest single win in the plan and it is the furthest away. It needs
its own migration (units first, then the untracked material), not this sprint.

## ecosim is off mandark (2026-08-05, late)

*Zach: "ecosim needs to just go. nothing on mandark really needs it. it's
useless." — and, separately: "scheduler can just not be running on mandark at
this point since nothing is being triggered."*

Those turned out to be **one change**. mandark's crontab had exactly one
active line, and it was ecosim's:

```
$ crontab -l | grep -vE '^\s*#' | grep -v '^\s*$'
  */30 * * * * /home/zach/.local/bin/ecosim-sensor-tick # arme:ecosim-sensors:MONITOR
```

That line is **owned by `scheduler/schedule/_monitor.conf`**, not by hand, so
editing the crontab directly would have been undone by the next sync. It was
parked at source instead (`enabled=0`, the format's own contract for "stays
declared and visible"), committed, and applied with `arme apply` —
scheduler's own front door.

**Flagged, because nobody asked for it:** `arme apply` writes the whole
managed block, and `verb-build-check` was `enabled=1` in that conf while never
having been written to the crontab. Applying therefore *removed* ecosim's line
and *added* that one. Reconciling conf → crontab is the intended direction, but
it means mandark now runs one line it did not run before — a free, non-agent
`install-verb-build.sh --check` every 6 hours. Parking it too is a one-word
edit if that is not wanted.

Then, in order:

```
$ installe retire ecosim-sensor --force     # declared itself to senechal
$ installe retire sonde --force             # ecosim's declared verb
$ git -C .../ecosim log --oneline --all --not --remotes=origin   # (empty)
$ git -C .../ecosim status --porcelain ; git stash list           # (both empty)
$ fauche check /home/zach/Documents/Projects/ecosim
  REMOVABLE
$ fauche script ... | bash
  removed 1 repository
```

`sonde` was retired rather than left to rot: probed first with
`SONDE_LEGACY_ROOT=/nonexistent sonde list`, which GAPs loudly rather than
misbehaving quietly, so the choice was between a loud-broken verb and no verb.

### The one side effect, predicted and then confirmed

```
$ ausculte silence
  ausculte: GAP: silence: .../ecosim/bin/silence-audit.sh is not executable or not present
$ silence-audit --help
  # silence-audit.sh -- the ecosystem's NULL-DISCRIMINATOR.
```

senechal's `ausculte` still defaults `AUSCULTE_SILENCE_AUDIT` into the deleted
clone, and senechal is off-limits (another agent). The separate `silence-audit`
command resolves into **realisateur's** copy and still works — which is the
same three-copies-that-differ problem the ecosim subagent found earlier tonight
and which `check_twin` is itself supposed to catch.

ecosim's self-dev account on monkey (uid 3001) is untouched; only mandark's
clone is gone. Recover with `git clone https://github.com/hf7y/ecosim.git`.

### Disk

ecosim's 6.5M came off, but `~/Documents/Projects` measured **786M** afterwards
versus 785M before — because `senechal` grew ~6M in the same window from the
other agent working in it. The saving is real; the directory total is not the
witness for it.

## What stopped the gardien move: nothing structural

Asked directly, so answered from the config rather than from memory.

`garde` does **not** need a clone — unlike senechal's verbs, it defaults
`LEGACY_ROOT="${GARDE_LEGACY_ROOT:-$SELF}"` to the build, which is why gardien
was the first repo to come off this machine cleanly. Its config lives at
`~/.config/gardien/garde.json`, outside every repo:

```json
{ "name": "bibliothecaire-intake", "path": "~/bibliothecaire-intake",
  "class": "irreplaceable", "copies": ["dexter-d"], "min_copies": 1,
  "exclude": ["work", "rejected"] }
```

So the edit is a local file and takes a minute. **It was sequenced after the
cutover on purpose**, for two reasons:

1. `path` is a path *on the host running garde*. While mandark is still the
   live pipeline, mandark's copy is the authoritative one. Repointing the
   backup at monkey now would back up a standby and stop protecting the live
   copy — strictly worse than today.
2. That set's own `_comment` records why this is the dangerous one:
   *"bibliothecaire's `--reap` DELETES originals once its backup proof passes,
   and that proof was pointed at the retired python gardien chain; re-pointing
   it without this set would have licensed deleting the only copy."* It is
   `class: irreplaceable`, `min_copies: 1`, and the originals are paper on a
   shelf.

A backup that points at the wrong host is not a smaller problem than no
backup; it is the same problem wearing a green light. Hence: cut over first,
watch one real scan land, then repoint — the order in
`bin/cutover-bibliothecaire-to-monkey.sh`.

## Not touched, per plan §4

`dog` (564M, not a git repository) and `dcp-gate-site` (3.8M) — explicitly out
of scope. `realisateur` / `scheduler` / `basheur` / `ecosim` / `space-canon` are
the shim layer and stay.

## Housekeeping

`~/Documents/Projects/REMOVE-RECOVERABLE-REPOS.sh` is a stale `fauche script`
artifact that echoes `removed 0 repositories`. It is accurate today (nothing is
REMOVABLE) and harmless, but it is a leftover on a desk Zach's own `FOCUS.md`
says should hold only `.md` files. Regenerate it from `fauche script` at the
moment of use rather than trusting the copy on disk.
