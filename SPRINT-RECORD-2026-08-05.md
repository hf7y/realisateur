# SPRINT-MANDARK-OFF — the overnight record

*Written 2026-08-05, 00:00–01:30 CDT, against `SPRINT-MANDARK-OFF-20260805.md`
(merged as #52). Its §7 says to distrust every confident number in it,
including its own. Executing it produced **three corrections to the plan and
two to my own filings**, which is the main thing this record is for.*

**Every command output below was captured on the machine. Where I state a
conclusion I did not verify myself, I say so.**

---

## 1. What is staged, and why nothing landed

**I can open PRs. I cannot land them.** Both routes to `main` are refused by the
harness classifier — not by the ecosystem:

```
gh pr merge 53 --repo hf7y/realisateur --squash   -> Blocked by classifier
git push origin sensor-archive:main               -> Blocked by classifier
```

Same class as the known `installe --force` block. It applies to every phase of
this sprint. So the night's output is a **merge queue**, not a migration.

I did not work around it. Editing a live checkout by hand would be the
hand-copy-deploy anti-pattern and would leave an uncommitted change in a script
cron runs every 30 minutes.

### The queue, in merge order

| # | PR | What | Evidence |
|---|---|---|---|
| 1 | `senechal#22` | **`installe` reads a build, not a dev clone.** The gate — unpins 125M. | 56 pass / 0 fail (baseline 53/0). New tests fail against old `installe`, so they test the change rather than restate it. |
| 2 | `scheduler#26` | A foreign rotation row must not spend the tick's dispatch slot. | Fixture proves both the fix and the hang it avoids. |
| 3 | `scheduler#27` | Monitor the build that 125M of deletions rest on. | Both conf rows parse; command exists; exit 1 confirmed live. |
| — | `realisateur#53` | Durable sensor archive. | **Already merged and live.** |

All three open PRs are `MERGEABLE` / `CLEAN`. None of these repos has CI, so
nothing gates them but review.

## 2. Corrections to the plan, found by executing it

### 2.1 The J1 fix as specified would have hung

The plan said "change only `usage-paced-runner.sh:267`" — stop the not-runnable
SKIP incrementing `dispatched`. But that counting is **load-bearing for
termination**, which the EXPIRED branch states outright: *"so an all-expired
rotation still terminates the tick loop."* Deleting it spins forever when no row
is runnable, re-probing the usage gate each lap.

Shipped instead: **split the counter.** `dispatched` (quota, bounded by
`MAX_PER_TICK`) vs `examined` (termination, bounded by rotation length).
Verified both directions on a four-row fixture.

### 2.2 Phase 3's premise was inverted — in the sprint's favour

The sprint doc says of the five registered-not-armed projects: *"**None of the
five has one** [a FOCUS.md] … This is the real work of phase 3 and it is not
scriptable."*

**All five have a FOCUS.md, and a QUESTIONS.md.** They are at `.claude/`. The
`.scheduler/` 404 only means they have not set `SCHEDULER_SUBDIR`, which
`sync-crontab.sh:635` defaults to `.claude`.

So Phase 3 is a **mechanical path migration**, not brief-authoring. Filed as
`scheduler#28`.

### 2.3 chezz was never broken

Its missing `run.log` read as a fault. Verified independently: home created
`2026-08-05 02:11:51 UTC`, scheduler clone 02:21, and the runner creates its
state dir as its first act. It had simply never reached a tick. **Its
first-ever dispatch was the 06:00 UTC tick tonight.** Do not "fix" it.

## 3. Corrections to my own filings, same night

Recorded because the estate's failure record is mostly confident answers that
were wrong, and two of tonight's were mine.

### 3.1 I overstated the `.claude/` permission gate

I filed `scheduler#28` claiming legacy-path projects are blocked from writing
their briefs. `baudin/README.md` (23rd pass) disproves it:

> **`.claude/FOCUS.md` is writable; the "blocked" claim does not reproduce.**
> Re-probed rather than quoted: a filesystem append *and* the harness Edit path
> both succeeded on the first try.

baudin had spent **five consecutive passes** recording the edit as blocked and
staging a hand-patch for a human — *"the checklist never caught up because the
edit was believed blocked."*

So I re-probed sequestria too, rather than leaving my own "should be re-probed"
hanging. Cloned it and used the harness Edit path on `.claude/FOCUS.md` — the
exact file and mechanism its `PROCESS.md` calls *"a standing tool-permission
restriction… not a transient glitch"*. **It succeeded on the first try.**
Reverted immediately; nothing committed or pushed.

*Limitation, stated plainly:* that was an interactive session with broad
latitude, not an unattended nightly agent, and the gate is documented as
context-sensitive. It disproves "unconditionally protected", not "a nightly
pass would succeed".

| project | claim | retested? |
|---|---|---|
| baudin | 5 passes blocked | **yes — 6th re-probed, wrote fine** |
| nine-speakers | blocked passes 3–7 | **yes — self-resolved same night**, *"harness-level, intermittent"* |
| sequestria | *"standing… not a transient glitch"* | **yes, tonight — did not reproduce** |
| crt / groc-mangr | no claim | — |

**Every claim that has ever been retested has failed to reproduce. No project
has a confirmed standing block.** So the original framing — migrate nine
projects to escape a gate — is unsupported. `SCHEDULER_SUBDIR=".scheduler"`
stays defensible as tidying, not as unblocking.

**The finding that survives is about belief:** three separate projects recorded
a hard block, each stopped testing it, and each was wrong. That belongs in
whatever brief tells a nightly agent how to report a blocker — *re-probe before
recording a block, and record the probe, not the conclusion.*

### 3.2 I reported a local-only branch as at-risk

`fauche` flagged `vim-arcade` branch `fix-main-red` as having no origin
counterpart. I wrote that it "would be LOST". Checking rather than assuming:

```
$ git merge-base --is-ancestor fix-main-red origin/main   -> YES
$ git rev-list --count origin/main..fix-main-red          -> 0
```

Fully merged. Nothing to rescue; `git branch -d` will accept it. `fauche` was
being conservative, not reporting loss.

## 4. The sharpest new evidence: the 06:00 UTC tick

All four monkey accounts, same tick:

```
[ecosim]         SKIP chezz          -> PACED_MAX_PER_TICK (1) reached
[bibliothecaire] SKIP vim-arcade     -> PACED_MAX_PER_TICK (1) reached
[vim-arcade]     SKIP bibliothecaire -> PACED_MAX_PER_TICK (1) reached
[chezz]          SKIP ecosim         -> PACED_MAX_PER_TICK (1) reached
```

**Zero dispatches in a six-hour cycle.** Every account passed the gate
(`verdict=RUN`, 7d at 35% with slack), took its one slot, spent it on another
account's row, and yielded. No quota shortage. Nothing frozen. It does not
self-correct — cursors advance one row per tick per account, so a de-phased
rotation stays de-phased.

This also corrects `scheduler#14`, which found the same mechanism yesterday but
concluded *"each runner therefore only ever dispatches itself"*. It does not
dispatch itself; the foreign row eats the slot first. That reframes the issue
from log noise into lost dispatches.

**A corollary:** the gate read `7d util=0.350` identically before and after. The
intent was to measure per-batch quota cost at this tick; that was impossible
because no batch ran. **A rotation that dispatches nothing is indistinguishable
from one being throttled, in the quota data itself.** `ROTATION EXHAUSTED`
(added in #26) is what makes those tellable apart.

## 5. Step 0 — what it became

Wiring ecosim *into* bibliothecaire is refused by **both** projects' contracts,
verified verbatim:

- ecosim `SENSOR-CONTRACT.md` §5 — *"No cross-repo writes. A sensor reads other
  projects; it writes only into `ecosim/sensors/` and its own stdout."*
- bibliothecaire `CONTRACT.md:108` — *"export an ingest command that other
  projects call | **refused**"*, and separately refuses *"write into a
  consumer's repo rather than flagging the handoff."*
- ecosim's account cannot reach bibliothecaire at all (403, no deploy key); its
  own `.scheduler/QUESTIONS.md:24` records the failed attempt.

The **intent** — durable telemetry — was achievable and more urgent than
assumed. `run.log` is trimmed to 5000 lines every run and was at **4811**: about
2.6 days, in a non-git state dir, on the host whose clones this sprint deletes.
**The migration had no durable record of itself.**

Delivered: an append-only, never-trimmed `archive.jsonl` fed by
`ecosim-sensor run --json` — the archival mode the contract documents and
nothing had wired up — written into **realisateur's own** state dir. No repo
boundary crossed, no contract overridden. Live and self-sustaining:

```
{"ts": "...T00:57:51-05:00", "record": "run", "rc": 3, "json_rc": 0, "lines": 75}
{"ts": "...T01:00:21-05:00", "record": "run", "rc": 3, "json_rc": 0, "lines": 75}
```

The second was written by cron, unattended.

Two exit codes because they disagree: `run` → 3 (BLIND), `run --json` → 0 on
identical state. `--json` does not honour SENSOR-CONTRACT v1 §2. Recorded rather
than reconciled, so the discrepancy stays visible in the data. Filed `ecosim#29`.

Known cost, filed by the same session that introduced it (`realisateur#55`):
**853 KB/day ≈ 304 MB/year**, unbounded. Should rotate monthly and gzip.

The bibliothecaire half stays a **prose drop through the documented door**
(`archive/<project>/<date>-<topic>.md`, a per-drop judgment its CONTRACT does
support) — not a telemetry pipe.

## 6. Re-derived inventory

Against the installed build, on the machine:

```
27 symlinks -> BUILD-VERB      (migrate with P1)
 9 symlinks -> NOT IN BUILD:
     ecosim-sensor       -> ecosim        the ONLY pin on ecosim (6.5M)
     basheur             -> basheur       the ONLY pin on basheur (4.3M)
     canon               -> space-canon   the only pin on space-canon (1.6M)
     bashify, ecosim-sensor-tick          -> realisateur (stays)
     scheduler, usage-gate.sh,
     usage-paced-runner.sh,
     scheduler-dev-cycle.sh               -> scheduler (stays)
```

Two corrections to the sprint doc's Phase 4: **`bashify` points into
realisateur, not basheur**, so it does not pin basheur — only `basheur` does.
And **`canon` → space-canon** appears in no plan document, conf, or rotation.

**space-canon is unrecoverable**: zero git remotes, not on GitHub (404), 14
commits, 1.6M — the same class as `dog`. Its `canon` symlink was created
**2026-08-05 00:12**, during this sprint window, and is not in `installe`'s
manifest: a *new* instance of the unowned-symlink shape Phase 0 exists to
retire. **Do not delete space-canon; give it a remote before any sweep.**

## 7. P1 is proven against the real build

The build is installed on mandark (`current -> 2026-08-05T040843Z`, *"verified:
32 verb(s), all present and executable"*). No `~/.local/bin` symlink was
touched. Against a scratch `INSTALLE_BIN`:

```
installed ok=32 failed=0
32 of 32 point into verb-builds/current
--help witness from /tmp with no dev clone: 32 ok, 0 broken
```

The witness checks exit 126/127, empty output, and `no such file` / `cannot
open` / `line N:` — the *"`lib/verb.sh` was not carried"* failure §7.4 records,
where `-f && -x` passed on a build where nothing could run. It includes
`installe` installing **itself** from the build, which is the bootstrap the
migration needs.

**Why not `install-verb-build.sh --link`**, which the sprint doc prescribes: it
skips every name it does not already own — all 28 on mandark — and reports that
as *"left alone"*. It would have looked like partial success and migrated
nothing.

## 8. P2 preconditions `fauche` found and the plan did not

`fauche check` says **KEEP on all four**:

```
vim-arcade      branch 'fix-main-red' has no origin/fix-main-red  (safe, §3.2)
vim-arcade      worktree .vim-arcade-worktrees/issue-46   <- a HIDDEN dir
bibliothecaire  2 prose file(s) have no note in the vault
senechal        1 prose file(s) have no note in the vault
```

My own worktree count (7) **missed a hidden directory** `fauche` found
immediately. §7.2 is right: believe it over any hand check.

## 8b. Phase 4 — what each remaining pin actually needs

`fauche check` on the three repos P1 does *not* free:

**ecosim (6.5M) — the cleanest.** Its only `fauche` objection is its own verb
worktree, which P1 removes. The real blocker is that `ecosim-sensor` is not a
declared verb, so the build cannot carry it.

`sonde` looked like the answer — ecosim's declared verb, already in the build,
same vocabulary (`list|contract|run|sweep|selftest`). It is not a drop-in:

```
$ sonde run --json | head -1
BLIND ecosim.rotation.BLIND_HOST_UNREADABLE ...   <- line protocol, flag ignored
$ sonde --json run | head -1
                                                   <- NOTHING, exit 6
$ ecosim-sensor run --json | head -1
{"ts": "...", "sensor": "rotation", "symbol": "BLIND_HOST_UNREADABLE", ...}

$ sonde run; echo $?          -> 6
$ ecosim-sensor run; echo $?  -> 3
```

`--json` is advertised in `sonde --help` and wired to nothing — and the
`--json run` form emits *nothing at all* with a code meaning "blind", which is
indistinguishable from the sensors failing to look. The exit vocabularies also
differ (verb `6 blind` vs contract `3 BLIND`), so the tick's `0/1/2/3` map would
report every run as an unmapped anomaly. Filed `ecosim#30` with both routes
(teach `sonde`, or declare `ecosim-sensor`); choosing is ecosim's call.

**basheur (4.3M).** `fauche`: *"branch 'main' is 6 commit(s) ahead of
origin/main"* — verified against GitHub directly, 6 ahead / 0 behind, a clean
fast-forward. All six are `residue: verb-page attempt NNN (summon exit 0)`,
i.e. its own test residue. **Push before deleting.** Separately, `basheur` is
installe-owned but has **no `bashified` branch**, so the build cannot carry it
either — the declare-or-retire question stands.

*(A correction: I first reported basheur's only remote as a local bare repo on
the same disk. Wrong — `git remote -v | head -2` truncated the list and hid
`origin`. It has a GitHub origin. Third self-correction of the night, and the
same species as the other two: a truncated or conservative reading taken as a
finding.)*

**space-canon (1.6M) — genuinely unrecoverable.** `fauche`: *"no 'origin'
remote: there is nowhere to recover this from"*, *"branch 'master' has no
origin/master: it exists only on this host"*, and **30 prose files unvaulted**.
No `bashified` branch. Not on GitHub. **Give it a remote before any sweep
touches `~/Documents/Projects`.**

## 9. Phase 3 readiness — all five surveyed

| project | verdict | why | default branch |
|---|---|---|---|
| **crt** | **READY** | richest offline backlog: dead-code sweep, a real port-8993 collision, two critical scripts with no tests. Its recorded blocker is *dexter's* spend limit — **dexter is out of the picture now**, so re-probe. | `main` |
| **baudin** | **READY** | issue #1 + CONTRACT.md's two named "cheapest summons". Milestone hardware-blocked, software work exists. | `master` |
| groc-mangr | THIN | milestone needs Zach to buy groceries. **Default-branch bug**, below. | ⚠️ `feature/receipt-ocr` |
| nine-speakers | THIN | milestone is entirely hardware + Zach's ears; the simulation codebase is explicitly parked. | `main` |
| sequestria | THIN | every avenue ends at a money fence; its gate claim is unverified. | `main` |

**Arm `crt` first, `baudin` second.**

**All five share one identical agent-doable task** — open issue #1 on each
(`lib/verb.sh` cannot return the exit 7 its CONTRACT promises; parent
`realisateur#44`). Deliberately left unfixed: it is the right *first* task for
those projects' own nightly agents, not something to take from them.

### `groc-mangr#2` — a trap worth generalising

Its default branch is `feature/receipt-ocr`. `sweep-loop-common.sh:107` resolves
an unset `BRANCH` from *"origin's own default HEAD"*, which `:65` also makes
*"the branch this job resets to **and pushes**"*. Measured:

```
main vs feature/receipt-ocr:  ahead_by=9  behind_by=0
FOCUS.md latest date:  main 2026-07-29  |  default 2026-07-24
```

An armed agent would read a five-day-stale brief whose already-answered
questions still show as open placeholders, and push to a feature branch.
**"Does the default branch match where the brief lives?" belongs in the arming
checklist** — invisible from inside a conf, free to check.

## 10. Quota

The sprint doc treats quota as the binding constraint. Tonight it was not, and
the reason is worth recording.

```
00:00 CDT  7d util=0.330
01:30 CDT  7d util=0.350
```

**20 points over 90 minutes**, against a 27-point budget to the doc's 0.60 hard
floor — and most of that was subagent dispatches, not interactive turns; util
was flat across several stretches of hands-on work. **The binding constraint
tonight was the merge block, not quota.**

## 11. Machine changes made, all reversible

- Installed the verb build: `~/.local/share/verb-builds`, `current ->
  2026-08-05T040843Z`. **No symlink repointed.** Declared (`senechal#23`).
  Revert: `rm -rf ~/.local/share/verb-builds`.
- Recorded pre-state for the eventual relink:
  `~/.local/share/verb-relink-pre-2026-08-05.tsv` (40 symlinks) and
  `installe/manifest.pre-2026-08-05.tsv` (28 rows).
- Removed 4 stale worktrees left in this job's tmp by earlier runs
  (`tick-revert`, `github-front-door`, `disable-fixed-cron`, `idea-title-length`)
  — all verified merged first; three were squash-merge false negatives whose
  PRs (#21, #22, #24) are merged.
- All live checkouts left clean: `scheduler 0`, `senechal 0`, `realisateur 0`.

## 12. Attribution

`realisateur#53` merged tonight. **I did not merge it** — my merge was refused,
twice. Every actor in this estate is `hf7y`, so no tool can distinguish them,
and §7's closing note is that a session crediting itself with merges it did not
make has already happened once. This record claims only what it can show a
command for.
