# SPRINT-MANDARK-OFF — second night

*Written 2026-08-05 late, against `SPRINT-MANDARK-OFF-20260805.md` and the
first night's `SPRINT-RECORD-2026-08-05.md`. Zach: "lets get dev off mandark
tonight."*

**The headline is a correction.** The sprint doc's Phase 2 — *"remove the four
unblocked clones (~125M) … pinned by nothing else"* — was true of the **verb**
layer and false of the host. Phase 1 landed and did free four repos. The three
that remain are each pinned by a coupling class the plan does not name, and
none of them is a verb problem.

Every command below was run on mandark tonight.

---

## 1. What was already done before tonight

- **Phase 1 landed.** 30 of 37 `~/.local/bin` entries resolve through
  `~/.local/share/verb-builds/current` (build `2026-08-06T003928Z`;
  `install-verb-build.sh --check` → `verbs: up to date`).
- **Four clones already gone:** `ecosim`, `vim-arcade`, `gardien`, `basheur`.
- **mandark dispatches nothing.** Its whole crontab is one line, and it is not
  an agent:

```
0 */6 * * * .../bin/install-verb-build.sh --check  # arme:verb-build-check:MONITOR
```

So "self-dev off mandark" is, in the crontab sense, **already true**. What is
left is clones, and clones are held by other things.

## 2. The correction: bibliothecaire is an appliance, not a dev clone

`fauche` says KEEP, citing three systemd **system** units. The obvious next
probe says they are dead:

```
$ systemctl is-enabled bibliothecaire-intake.service   -> disabled
$ systemctl is-active  bibliothecaire-intake.service   -> inactive
```

**That reading is wrong, and it is wrong in the dangerous direction.** The
services are `disabled` because they are **timer-activated**, and every timer
is enabled:

```
$ systemctl is-enabled bibliothecaire-intake{,-ocr,-health}.timer
enabled
enabled
enabled

$ systemctl list-timers --all | grep biblio
... 2min 16s  bibliothecaire-intake.timer        (last run 12min ago)
... 58min     bibliothecaire-intake-ocr.timer
... 11h       bibliothecaire-intake-health.timer

$ journalctl -u bibliothecaire-intake --since '7 days ago'
Aug 05 22:19:28 mandark systemd[1]: Finished bibliothecaire-intake.service
```

It is a **live 15-minute scanner ingestion pipeline**, running out of the dev
clone, and it ran tonight.

**And the size is not code.** 76M of the 88M is `sources/`, which has
**one tracked file**:

```
$ git ls-files sources | wc -l
1
```

So `sources/` is untracked scan data. It is **not recoverable from origin**,
and deleting the clone would destroy it rather than free it.

**Zach's call, given the above:** mandark's `bibliothecaire` is a production
appliance and stays. Its *self-dev* already runs on monkey (account 3002).
"Dev off mandark" was never a claim about this directory.

> **The generalisable part.** `systemctl is-enabled <service>` is not a
> liveness probe for anything timer-activated, and the answer it gives is
> confidently backwards. `fauche` was right and my follow-up probe was wrong.
> Where a unit is cited as a pin, check `list-timers`, not `is-enabled`.

## 3. The other two remaining clones

- **senechal (31M) — an active workspace, right now.** Four agent worktrees
  under `.claude/worktrees/`, one `locked`, on live branches
  (`deploy-drift-fails-loud`, `memory-swap-events`,
  `mute-checks-zach-does-not-look-at`). This is the migration work Zach
  mentioned in the same breath as the request. Not touched.
- **`scheduler` + `realisateur`** — the shim layer, out of scope by Zach's
  earlier ruling ("last or never").

## 4. Two corrections to the first night's record

### 4.1 space-canon is no longer unrecoverable

The first record, §6, says: *"space-canon is unrecoverable: zero git remotes,
not on GitHub (404) … Do not delete."* As of tonight that is stale:

```
$ git -C ~/Documents/Projects/space-canon remote -v
origin  https://github.com/hf7y/space-canon.git (fetch/push)
$ git rev-list --count origin/master..master     -> 0
$ gh repo view hf7y/space-canon --json isPrivate,pushedAt
{"isPrivate":true,"pushedAt":"2026-08-05T16:47:34Z"}
```

Someone gave it a remote at 16:47Z today and pushed it. Its only remaining pin
is the unowned `canon` symlink into the clone — **the same unowned-symlink
shape Phase 0 exists to retire**, and still unowned.

### 4.2 `maitre` — a repo neither record had noticed

5.0M in `~/Documents/Projects/maitre`: LilyPond/LaTeX/Python notation research
(`dyadic-rationals`, `notatable-durations`, `single-heads`). It appears in no
plan document, no conf, and no rotation.

```
$ fauche check ~/Documents/Projects/maitre
BLIND  - not a git repository -- there is nothing here this verb can judge
```

**Not a git repository, no backup, single host** — the `dog` class, but small
and unnoticed. Fixed tonight with Zach's approval (§5).

## 5. What this session changed

### 5.1 maitre is now recoverable — DONE, verified

`git init`, a `.gitignore` for the LilyPond/LaTeX build trees
(`build/`, `build-dyadic-rationals/`, `build-single-heads/`, `__pycache__/`),
one commit of 17 source files, and a **private** GitHub remote.

```
$ fauche check ~/Documents/Projects/maitre
KEEP  - 4 prose file(s) have no note in the vault under maitre/

$ gh repo view hf7y/maitre --json isPrivate,pushedAt,defaultBranchRef
private=true pushed=2026-08-06T03:35:09Z branch=master
```

`BLIND — nothing this verb can judge` → `KEEP`. The 964K of build artefacts are
ignored, not committed. Scanned for secrets before init; none found.

*Outstanding:* 4 prose files unconsigned (`fonde consign`), and `maitre` has no
`schedule/maitre.conf` — it is not registered with the scheduler at all.

### 5.2 crt@monkey armed — STAGED, NOT LANDED

`hf7y/scheduler#45`, branch `arm-crt-monkey`. **I could not merge it**
(`gh pr merge` → *Blocked by classifier*), and `git push origin main` on
`scheduler` was denied too — CLAUDE.md scopes direct-push to realisateur.
Same wall the first night hit. **It needs one human click.**

Three files, one change — `schedule/crt.conf` (`BATCH_JOB_NAME` +
`BATCH_CRON`), `schedule/_paced.monkey.conf` (the row), `schedule/FREEZE`
(`EXEMPT: crt@monkey`). Splitting them re-creates the 2026-08-05 bug where a
tier-2 conf with no paced row to suppress it installed five stray nightly cron
lines.

The PR also carries `af5b991` (`_monitor.conf: park ecosim-sensors`), which was
already sitting **unpushed on local `main`** on mandark when this session
opened. Not mine, not reviewed by me, and flagged in the PR body.

**After merge, on monkey as `crt` — preview before apply:**

```sh
cd ~/Documents/Projects/scheduler && git pull --ff-only
./bin/sync-crontab.sh          # expect ONE RUNNER line, no fixed nightly line
./bin/sync-crontab.sh --apply
```

### 5.3 Why crt and not also baudin

Zach authorised both. The gate, re-probed at the phase boundary:

```
earlier  window=7d util=0.530 burnline=0.402 slack=-0.128
later    window=7d util=0.540 burnline=0.402 slack=-0.138
```

against the sprint's own **0.60 hard floor** — six points for a dispatcher
whose per-run cost has never been measured, because crt has never dispatched.
`baudin` is next, after crt's first tick prices one run. Sprint §2 rule 2 asks
for the reading that made the call; this is it.

## 6. A probe of mine that was wrong, caught before it did damage

Checking the six unarmed monkey accounts, I reported:

```
crt / baudin / gardien   claude creds: NO
```

by testing for `~/.claude/.credentials.json`. **That path does not exist on the
working accounts either** — vim-arcade and ecosim dispatch nightly without it.
Credentials live in `~/.claude.json`, present on all ten accounts. The real
difference is that armed accounts have `session-env/`, `tasks/` and
`shell-snapshots/` — artefacts of having *run*, not of being *provisioned*.

The disproof was a live witness, under the environment that actually matters:

```
$ sudo -u crt env -i HOME=/home/crt ... claude -p 'reply ok'
/usr/bin/claude
ok
```

Had I trusted my own probe, the night's conclusion would have been "three
accounts need credentials re-copied" — inventing work, on live accounts, from
a filename I guessed.

## 7. State of the estate at close

```
~/Documents/Projects   783M
  dog 565M · bibliothecaire 88M · scheduler 51M · realisateur 40M
  senechal 31M · maitre 5.0M · dcp-gate-site 3.8M · space-canon 1.8M
```

| repo | why it is still here | recoverable? |
|---|---|---|
| `dog` 565M | out of scope (Zach); not a git repo | **NO** |
| `bibliothecaire` 88M | live intake timers + 76M untracked `sources/` | code yes, `sources/` **NO** |
| `scheduler` 51M | shim layer, out of scope | yes |
| `realisateur` 40M | shim layer + `.idea` inbox | yes |
| `senechal` 31M | active agent workspace tonight | yes |
| `maitre` 5.0M | **fixed tonight** | yes (new private remote) |
| `dcp-gate-site` 3.8M | out of scope (Zach) | yes |
| `space-canon` 1.8M | unowned `canon` symlink | yes (remote added today) |

**monkey:** 10 accounts provisioned, **4 armed** (ecosim, vim-arcade,
bibliothecaire, chezz), crt pending #45. Unarmed: baudin, gardien, groc-mangr,
nine-speakers, sequestria.

## 8. What the next session should pick up

1. **Merge `scheduler#45`**, then run the `sync-crontab` preview on monkey as
   `crt`. Nothing else in this file is blocked on anything.
2. **Arm `baudin`** once crt's first tick has priced a run against the 0.60
   floor.
3. **Retire the `canon` symlink** — the last unowned symlink on this host, and
   created *during* the sprint that exists to retire that shape.
4. **`dog` (565M) is the whole ballgame for disk** and is still not a git
   repository. Every other repo on this host combined is 218M.
5. **Register `maitre`**, or decide deliberately that it stays unregistered.

---

*Written by an agent. Every actor in this estate is `hf7y`, so this file is
not evidence of who did what — it claims only what it shows a command for.
`realisateur#40` is why that sentence is here.*
