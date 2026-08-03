# Clean up mandark, move self-dev to dexter — 2026-08-02

**Zach, this session:** *"lets wrap up the plan. clean up mandark, move
self-dev to dexter"* — plus three judgements closing the bashify pass, and a
hands-on `installe --force verb gardien garde` that cleared the last blocker.

**Method.** Every figure below was re-probed while writing, by running the tool
named beside it. Nothing is quoted forward from the 02:50 snapshot: several of
its numbers had already changed by the time this ran, and two of them had
changed *because the backup finally worked*.

---

## 0. The correction that reframes everything

`SNAPSHOT-mandark-dexter-2026-08-02.md` says the 03:33 backup "has not yet
run". It ran. **It failed**, exit 5, on `Projects` — the most important set on
the box, the night after THE FLOOR was declared 9/9 met.

And `THE-FLOOR.md` still opens with **"THE FLOOR IS MET — 9/9"**. Measured
tonight, `bin/floor-check.sh` said **NOT MET, 3 unmet 1 unproven**. The banner
is stale in exactly the way that file's own preamble warns about — *"when the
prose and the command disagree, the command wins"*. It disagreed within twelve
hours of being written, because the FLOOR was stamped at 03:02 and the thing
that broke gate 1.1 happened at 03:33.

Both documents were right when written. Neither was re-run.

---

## 1. What the backup failure actually was

The whole difference was one line:

```
+ realisateur/.git/logs/refs/stash
```

present at the destination, absent locally. A concurrent session stashed and
popped during the copy window; git deletes that reflog when the stack empties.
rsync copied it at 03:39:48; by the local hashing at 03:40:00 it was gone.

**That was not a one-night race, and this is the finding.** `rsync_args`
carries no `--delete` — deliberately, because a backup that deletes propagates
an accidental `rm` to the only copy you have. So a file that is ever copied and
then deleted locally stays at the destination *forever*, and the verify was a
symmetric `diff -u` of the two hash lists. **`Projects` was set to fail every
single night, permanently, from its first run.** Measured on the real set:
not one stale path but **59** — 34 wtul, 10 secretaire-verbs, 10 secretaire,
4 abletim, 1 realisateur, nearly all deleted git refs.

The promise is asymmetric, so the verdict must be. garde claims *"everything I
have is copied and proven"*, never *"the destination is identical to me"*:

| | |
|---|---|
| MISSING — a local file the destination lacks | **BROKEN** |
| DIFFERENT — same path, different bytes | **BROKEN** |
| EXTRA — a path only the destination has | **STALE**, reported, not broken |

### Then the fix armed a second bug

With every set finally proven, `garde media run --all-pending` found an empty
pending list, fell through to `verb_die`, and exited 2 — so
`garde-nightly.service` **failed for being completely healthy**, and told the
caller to pass the flag the caller had just passed. It would have fired every
night from the first clean night onward. It was armed by the backup starting
to work.

**Now:** 17/17 sets `ok x1`, 0 PENDING, `garde media audit` exit 0,
`garde-nightly.service` `Result=success status=0`.

---

## 2. mandark — what changed

| | before | after | how |
|---|---|---|---|
| backup sets proven | 12/17, 5 PENDING | **17/17, 0 PENDING** | `garde media list` |
| `garde-nightly.service` | failed (exit 5) | **success (0)** | `systemctl --user show` |
| failed user units | 2 | **1** | `systemctl --user list-units --state=failed` |
| FLOOR gate 2.2 restore | UNPROVEN | **MET** | `floor-check.sh --restore` |
| purge-guard findings | 9 | **4** | `bashify/lib/branch-purge.sh` |
| gardien Law 3 call sites | 3 | **1** | `grep verb_gap_or_summon bin/garde` |
| `garde` contract test | 7 passed **1 failed** | **7/0** | `test/contract-test.sh` |
| stale entries on PATH | `scheduler.bak.2026-07-28` | **retired** | `installe --force retire` |
| senechal footprint | 4 stale `retiring` rows | **`retired`** | `ausculte dead-config` |

**Not touched, deliberately:**

- **Disk at 91%** (400G/466G, 42G free). The top consumers are all your data —
  `Project Archive` 127G, `Ardour` 65G, `deedee dump` 32G, `plasma-vault` 39G,
  `Music` 41G. Nothing here is mine to delete. Only `~/.local/share/Trash`
  (686M) is obviously reclaimable.
- **`dcp-gate-site`'s untracked `docs/milestone-2-update.md`** — a founder
  voice-memo distillation from 2026-08-01, not build debris. It *is* backed up
  (it lives under the `Projects` set) but it is not in git.
- **`~/.local/bin` is in no backup set**, and it holds **22 `unknown` entries**
  plus `wtul-batch-loop.sh.pre-scheduler-migration.2026-07-27`, which I
  verified is **not in wtul's git history** — genuinely single-copy.
  `installe` refused to retire it and **the refusal is correct**. It cannot be
  added as a garde set without a schema change: the manifest derives the
  destination directory from the source *basename*, so `~/.local/bin` would
  land as `bin`, and there is no field to say otherwise.

---

## 3. dexter — what it has now

The 2026-07-29 teardown was deliberate (*"kill it all. this is bootstrap.sh
and go"*), with a 50M snapshot kept on mandark. dexter has been sitting at a
clean slate waiting for a bootstrap that did not exist.

**The reason it did not exist, found by running it:** `install-shims.sh`
hardcodes `REPO=/home/zach/Documents/Projects/realisateur`. Invoked on dexter
as `bash ~/realisateur/bin/install-shims.sh`, it pointed at a directory that
does not exist there, printed two FLAGs about hooks it could not find,
installed **nothing**, and **exited 0** — while `~/.local/bin` was still
exactly `claude node npm npx`. An exit-0 no-op in the one script whose job is
making the guards exist, which is precisely why the snapshot could say
*"nothing in the ecosystem knows how to install itself onto a bare machine"*
while realisateur was the only project shipping an installer.

The override was always there and the comment at `:38` even anticipates this
use (*"a second host wants its own stable path here, set once"*). What was
missing is that **a source of truth nobody validated is indistinguishable from
the right one until nothing is installed**. It now exits 5 and says so.

**On dexter now** — all under `~zach`, no root, no systemd units, no cron:

- `~/scheduler` (`c4af7ef`), `~/realisateur` (`bbf0eb3`)
- **10 ecosystem guards** on PATH where the snapshot found zero:
  `check-project-busy closeout-lint ecosystem-survey focus-commit hygiene-lint
  milestone-audit notify-senechal precipitation-scan silence-audit
  steward-survey`
- `~/.claude/commands/{bashify,cloture,ideate}.md`
- `~/.claude/hooks/subagent-closeout.sh` — **installed but NOT wired.** dexter
  has no `settings.json` referencing it, so it will never fire. Declared as a
  gap rather than counted as coverage.

**And the open question that answered itself.** `q-586b67` records dexter's
usage gate returning `401/no_headers` for **332 ticks, including a 319-tick
unbroken streak over ~57 hours** in which that host dispatched nothing and
raised nothing. Re-probed tonight from dexter:

```
verdict=HOLD binding=7d http_code=200 util=0.990 slack=-0.019
```

**`http_code=200`.** The credential refreshed 2026-08-01/02 fixed it. The
*escalation* question `q-586b67` asks — should a sustained ERROR be louder
than a HOLD — is untouched and still open; only the instance is gone.

---

## 4. Why self-dev is not armed tonight, and what arming it needs

Three independent reasons, none of them "I ran out of time":

1. **The gate says HOLD.** 7d window at **99.0% util** vs burn-line 96.9%,
   slack **−2.1pts**, `allowed_warning`, resets in ~5h. The paced runner would
   refuse to dispatch anything tonight. Arming into that is spending the
   reset, not testing the system.
2. **Moving the cron line off mandark breaks THE FLOOR as written.** Gate 1.2
   is `disp="$(crontab -l | grep -c 'usage-paced-runner')"` and requires
   **exactly 1 on this host**. Remove mandark's line and mandark reports 0 →
   NOT MET. The checker is host-local and assumes the dispatcher lives where
   it runs. Moving the dispatcher requires making gate 1.2 estate-aware — a
   change to a milestone's own mechanization, which is yours to approve, not
   mine to slip in while doing something else.
3. **The resumption contract binds.** *"One project enabled at a time... A
   second project is unparked only after the first has completed seven
   consecutive clean nights."* Plus its named live hazard: gardien's last run
   ended `outcome=NOT-DONE` with no verdict, so the runner **re-dispatches it
   every tick and spins** the moment anything is armed.

**Good news on the policy question.** This is not a new decision.
`_paced.dexter.conf` already records **"HOST POLICY (REVERSED 2026-07-28,
Zach-directed): dexter is the DEFAULT execution host. Move everything that can
move."** And the conf's own caveat — *"self-dev stays single-host until [the
open question] is answered"* — is **stale**: `.scheduler/QUESTIONS.md:118`
answers it, *"**2026-07-24** should dexter self-develop `scheduler`? → **yes,
safe** once every cycle pushes `origin/main` immediately after merging; review
is revert-based, not a pre-push gate."* The prose in the conf outlived its own
blocker.

### The switchover, in order

1. Wire `subagent-closeout.sh` into dexter's `~/.claude/settings.json`. It is
   installed and inert; an unwired guard on the host about to run unattended
   agents is worse than no guard, because the roster says it is covered.
2. Make FLOOR gate 1.2 estate-aware — "exactly one dispatcher **in the
   estate**", or mandark declares dexter owns it. **Needs your call.**
3. Install the RUNNER cron line on dexter with an explicit `PATH=` (cron
   supplies one, non-interactive ssh does not — that trap has bitten before),
   with `_paced.dexter.conf` rows still `enabled=0`. The dispatcher then ticks
   and dispatches nothing, which is what parked looks like and is safe.
4. Remove the RUNNER line from mandark → mandark drops **3 cron lines to 2**,
   sensor + sweep, which is the FLOOR's stated floor.
5. Clear gardien's `NOT-DONE` verdict, or leave gardien unpaced.
6. Enable **exactly one** project in `_paced.dexter.conf` — `realisateur` is
   the row already written for it — and watch seven nights.

Steps 1, 3, 4 are mechanical once step 2 is decided. Step 2 is the only one
that needs a human, and it is the one that actually constitutes "self-dev now
lives on dexter".

---

## 5. What needs Zach

**A. Two things block THE FLOOR, and both are outside my remit.**

- `hermes-gateway.service` — failed since 10:38 today, `Cannot connect to
  127.0.0.1:3000`, after burning 25min CPU / 2.1G peak. It is your WhatsApp
  bridge, not ecosystem machinery. Either start the bridge or
  `systemctl --user disable --now hermes-gateway.service`. It is the **only**
  remaining failed unit, and it alone holds gates 1.1 and 3.3.
- `basheur` sits **+6 unpushed** on `main` — auto-generated
  `residue: verb-page attempt NNN` commits. Gate 2.1 names basheur as the
  motivating incident for that gate existing. One `git -C ~/Documents/Projects/basheur push`
  clears it, but pushing another project's `main` is not something this repo's
  push permission covers.

**B. Gate 1.2 estate-awareness** — §4 step 2. One line once decided.

**C. `~/.local/bin` has no second copy**, and cannot get one without a garde
manifest change (§2). 22 unowned entries; at least one proven single-copy.
Worth a decision: add a `remote`/`as` field to the set schema, or accept it.

**D. Deferred, unchanged from the last pass:** the stale *"4 call sites"* in
`bashify/skel/lib/verb.sh:97,101` is now **doubly** stale — it was 3, and after
tonight it is **1**. Fixing it still marks all 6 adopted repos DRIFTED until a
mass re-sync, so it is still deliberately not done incidentally.

---

## 6. The bashify pass, closed

Your three judgements, applied:

- **`scheduler bin/arme` — "detect vendor names."** The guard gives. Its
  lines 141/148 *are* the spend detector. Generalised into a new class,
  `EXEMPT-SUBJECT-MATTER`: the purge promise is about **provenance** (a branch
  must not carry evidence of the agent that made it), never about **domain**.
  The test that keeps it honest — *would removing the name leave the tool able
  to do its job?* Yes → it is a trace, remove it. No → it is the subject, it
  gets a row. All five judgements have that shape; the four you did not rule
  on individually are extended from the same principle, each revertible by
  deleting one row. **9 findings → 4.**
- **The sentence you quoted against `arme` was already dead.** `bashify.sh`
  documented the exemption as bounded three ways, one being *"never to a vendor
  name"* — a bound deleted on 2026-08-02 when the exemption was rebased on
  byte-identity. The comment 40 lines below says so. The repealed rule went on
  reading as live doctrine and was cited as one. Now stated as deleted.
- **"agree to remove one-shots, or deprecate."** `media remote` and `backup`
  are now plain `verb_gap` — neither reaches a model, with or without
  `--summon`. Both design questions are written out in gardien's `GAPS.md`,
  where a question asked once belongs. Law 3: **3 call sites → 1**. The
  survivor, `media dedup`, is the one that genuinely recurs and fits a
  contract.

The 4 remaining purge findings are all **defects**, and three of them are one
defect: gardien's Law 3, stated / commented / executable. They clear together
when `media-dedup` is authored and gardien adopts the union runtime. They are
deliberately not exempted — a Law 3 violation recorded as an exemption is the
guard reporting green on the one thing it exists to catch.

---

## 7. How to re-derive everything here

```sh
bin/floor-check.sh --restore              # the authority, not this file
bashify/lib/branch-purge.sh               # the 4
gardien-garde/test/media-test.sh          # 48 assertions
gardien-garde/test/contract-test.sh bin/garde
bin/tests/install-shims.test.sh           # 11, incl. E1-E3 bare-machine
garde media list && garde media audit
systemctl --user list-units --state=failed
ssh dexter 'ls ~/.local/bin; ~/scheduler/bin/usage-gate.sh'
```

Nothing above is stored. A hand-stored copy of a derivable thing is how the
2026-07-27 shim gap happened — and how this file's own §0 correction became
necessary twice in one day.
