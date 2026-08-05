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
| `vim-arcade` | remove (6.2M) | **one command away** | sole pin is `~/.local/bin/joue -> ~/Documents/Projects/vim-arcade/joue`. The build's `joue` is self-contained and verified (below). The command that repoints it is classifier-blocked. |
| `senechal` | remove (25M) | **structurally pinned** | 4 build verbs exec 20 scripts back into the clone. |
| `bibliothecaire` | remove (88M) | **structurally pinned** | 3 systemd *system* units run `bin/intake.py` from the clone. |

Realistic recoverable space today: **7.2M** (`vim-arcade`), not 125M.

## `vim-arcade` — ready, and blocked on one command

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
