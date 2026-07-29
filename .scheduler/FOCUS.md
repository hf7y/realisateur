---

**2026-07-28 (interactive, human-directed — "move the full chezz over to test the githubs issues pipeline"): chezz's answer channel is now GitHub issues, the round trip is proven live, and a recorded human-only blocker turned out never to have existed.** scheduler `8644ad3` + chezz `91725e3`, both on branch `gh-issues-answer-channel`, draft PRs `hf7y/scheduler#1` and `hf7y/chezz#2`. Nothing pushed to any `main`. Revert either with `git revert <sha>` on its branch, or simply drop `ANSWER_CHANNEL="issues"` from `schedule/chezz.conf` — every file-channel path is untouched.

**The correction, which matters beyond this session.** This file's own "Blockers on the current step" carries *"Human-only: `gh auth login -h github.com` on mandark. Blocks the entire GitHub-issues answer channel, which is now the only planned channel"*, and gardien was handed the same blocker (`fd7e311`). **It is false, and was already false when filed.** Re-probed first-hand: `gh auth status` on mandark reports `hf7y`, Active account: true, valid token, scopes `admin:public_key/gist/read:org/repo`. The failing `sidopera` line is a SECOND, INACTIVE account in the same `hosts.yml`. The original reading took the failing line and missed the working one. chezz's own QUESTIONS.md had already recorded this correction (`4504671`) and nothing propagated it. **The shape is the finding, and it is the same shape as the dexter/ssh entry below:** a blocker asserted from a partial read of a multi-line status output, then re-filed by sessions that quoted it instead of re-running it. `require_gh()` in `bin/scheduler` now carries that trap in its own failure message, so the next person to hit it is warned where they will be standing.

**What was built** (design taken intact from chezz's `.scheduler/QUESTIONS.md`, which had specified it fully — implementation, not re-derivation): `ANSWER_CHANNEL="issues"` opt-in per project in `schedule/<proj>.conf`, default `file`; `scheduler ask <p>` files a `question`-labelled issue with the body via `--body-file` (never `--body` — a question containing a backtick or `$(` is a question, not a command, same reason CLAUDE.md requires `git commit -F`); `scheduler -q <p>` renders every open question into ONE buffer shaped like today's QUESTIONS.md, opens `$EDITOR`, posts each filled `> ` slot as a COMMENT (never a body edit, so the ask survives verbatim), adds `answered`, and DELETES the buffer. `bin/sync-crontab.sh` suppresses the `questions/<p>.md` symlink for an issues-channel project, and the live `questions/chezz.md` symlink was removed from disk — then **restored**, deliberately, because `main`'s guard still requires it and tonight's run clones `main`; merging the PRs is what completes the cutover.

**The bug worth keeping, because exit status said success.** The rendered buffer was a `local` read by an `EXIT` trap. The trap fires after the function's locals leave scope, so under `set -u` it aborted and **the buffer survived in `/tmp`** — silently reinstating the on-disk question state the entire design exists to eliminate. Caught only by looking for the file afterwards. A clean specimen of the discipline's "backed by a human-sense witness, not exit code alone" row: every other signal said the run had succeeded.

**Two live-ecosystem observations, both first-hand.** (1) The scheduler autocommit watcher adopted three of this session's in-flight chezz edits mid-session under `author unknown` messages; they were squashed into one honest commit and nothing was lost — but the same watcher is at this moment sitting on **unpushed** adoption commits in `abletim`, `bibliothecaire`, `groc-mangr` and `home-assistant`, which `closeout-lint` FLAGs. (2) That watcher hung ~2.5 minutes holding `chezz/.git/index.lock`, because chezz's pre-commit hook runs the full Playwright suite. A cron-wide orchestration touching many repos will collide with this on the ~:30 tick. Recorded rather than acted on: neither is this repo's to fix.

**Deliberately not done:** no second project was migrated. Zach scoped that to semi-attended sessions, and the six preconditions that make it unsafe to hand to cron are filed as the `[batch] DEFERRED CROSS-WRITE` row below (`9ac1eb0`; scheduler was BUSY under a foreign session at close). The headline one: **13 of 19 registered projects have no GitHub remote at all**, so the channel is structurally unavailable to them, and 109 unanswered questions across 17 projects have no migration tool — chezz had zero open questions, so the pilot never once carried a question across.

**2026-07-28 (supervision session, `/cloture`): a blocker re-filed across four sessions was a one-line ssh config defect, not a missing credential — and clearing it unblocked three other things.** Recorded because the *shape* is the finding, not the fix. Multiple sessions filed "no key from mandark reaches dexter" as a credential gap (scheduler `195154f` among them, which concluded "needs a human on dexter"). It was never a credential: **dexter runs two sshd's — Windows OpenSSH on port 22, WSL2 on 2223** — and mandark's `~/.ssh/config` pinned `Port 22` with no `IdentityFile`, so the perfectly valid `mandark-to-dexter-gardien` key was never offered to the daemon that holds it. Three distinct errors mask the one defect: wrong port → `Permission denied (publickey)`; right port → `Host key verification failed` (2223 absent from `known_hosts`); and `-i <key>` on the wrong port *still* fails, which reads as "the key is rejected" and hardens the wrong conclusion. Corrected both `Host dexter` and `Host dexter-lan` on mandark, with an in-file comment naming the trap; filed to senechal as `ac49741` (pushed), which also flags that this makes the unrestricted full-shell deployment key newly usable, so senechal's standing retirement item on it is now *more* urgent, and retiring it must revert those config blocks.

- **2026-07-28 (`/ideate`, Zach-directed, late session): THE PLAY for the scheduler-orchestrated dexter migration is written and lives in scheduler, not here.** Cross-link only, per this command's own "don't duplicate the full text in both places" rule. Full text: scheduler `.scheduler/FOCUS.md`, commit `6e8636a` — vision, four-milestone chain, six-step sprint, blockers tagged by who can clear them.

  What realisateur should carry forward from it:
  - **M0 is REACHED.** Both hosts now run identical scheduler code from one ref (`9e24290`), every project's remote resolves from both, and dexter is unstalled. Witness: mandark's runner stopped logging `PULL WARNING -- diverged` and dexter's rotation reads `slots=4 :: crt crt crt wtul`.
  - **A doctrine change happened tonight that is still not in a doctrine file.** Per-repo minimal-scope deploy keys — the precedent crt/wtul/chezz/gardien all followed — were retired in favour of an account-wide HTTPS credential on both hosts, because SSH offers keys serially against `MaxAuthTries=6` and ~19 keys fails intermittently. Zach filed the delta to senechal (`9afefd3`), but senechal owns *knowing config exists*, not doctrine text. **The edit to `BUILD-DISCIPLINE.md` or `UNIVERSE.md` is realisateur's and has not been made.** Named here so it does not evaporate; it is a real belief change currently living only in commit messages.
  - **The orchestration design was borrowed, not invented** — from `bibliothecaire/bin/quote-stream.py`, at Zach's pointer: *"the agent is a selector, never an author."* Readiness comes from a probe store on disk; the agent picks from a catalogue and cannot assert readiness; an unverified unit is a hard error, not a warning. This is the mechanised answer to tonight's sensor-variety failure, and it is worth knowing as a reusable ecosystem pattern rather than a scheduler detail.
  - **A falsification condition was recorded in advance**, which is unusual enough to note as a practice worth repeating: if wave 1's three units come back materially identical, the readiness-gated-dispatch premise is wrong and the change should be dropped rather than kept because it was the stated goal.

  Park status: this entry is `active` — the doctrine-file edit above is required for realisateur's own current milestone (park-by-default triage holding across more than one live pass depends on the doctrine files being the place decisions actually land). The rest is a pointer, not work.

- **What it unblocked, all probed first-hand rather than recalled:** chezz's move prerequisite (`git ls-remote` FROM dexter) **succeeds** — the gap that reverted wtul on 07-25 does not apply; crt's 3-day silence is explained (a `You've hit your monthly spend limit` failure on 07-25 20:37, plus a usage gate that then starves a single-participant host — filed as crt `68b3a4f` and scheduler `83aef6b`); and the filed `sweep.lock` suspect is an orphan file with no holder, ruled out.
- **Two claims this session relayed before re-probing, then corrected:** that `_paced.dexter.conf`'s policy header still asserts the retired rule (it was fixed in `bccf9ce`), and that mandark's `gh` token is invalid (mandark is validly authenticated as **`hf7y`**; the failing `sidopera` line is an inactive second account). The second one mattered: it had been made a *prerequisite* and carried to gardien as a blocker. Both corrected in chezz `4504671`. The lesson is the ecosystem's own and needed no new doctrine — **a blocker filed twice in identical words is evidence the diagnosis was never tested**, which is `re-probed, not quoted` applied to a claim rather than a quantity.
- Cross-writes this session, all pushed: senechal `ac49741`, chezz `4504671`, crt `68b3a4f`, scheduler `83aef6b` and `4880bea`. Revert any with `git revert <sha>` in that project's repo.

**2026-07-28 (`/cloture`, from reading a BLIND rather than reporting it): `install-shims.sh` overwrote a tracked SOURCE file inside the `staging/silence-audit` worktree with its own generated shim.** `closeout-lint` reported `BLIND [worktrees] realisateur: 2 linked worktree(s) NOT examined` — a BLIND is not a clean result, so they were read. `realisateur-research-ecosim` is clean. `realisateur-staging-silence-audit` is dirty, and the first read of it was wrong in an instructive way.

- **What it looks like:** `bin/silence-audit.sh` shows `404 ++---` in `git diff --stat`, i.e. a 392-line deletion of the null-discriminator, sitting uncommitted on a staging branch. Read cold, that is a gutted guard — and `CLAUDE.md`'s own build checklist ends on `silence-audit --strict` clean, so it reads as the checklist's last row having been quietly hollowed out.
- **What it actually is:** not a deletion. `install-shims.sh` wrote its 13-line PATH shim *over the worktree's copy of the source*, and the shim `exec`s `/home/zach/Documents/Projects/realisateur/bin/silence-audit.sh` — main's full 394-line script, intact and committed. Behavior is correct: `silence-audit --strict` runs the real audit (`exit=1`, i.e. FLAGs found, which is the expected non-zero). The header it wrote says *"DO NOT EDIT HERE. Edit /…/realisateur/bin/silence-audit.sh and rerun the installer"* — pointing at main, from inside the branch whose whole purpose is to hold that file. `# verified 2026-07-28 via wc -l on both copies; readlink ~/.local/bin/silence-audit; timeout 60 silence-audit --strict`
- **The other dirty file is a superseded leftover:** the worktree's `bin/hygiene-lint.sh` carries an uncommitted +6 appending a crude `check 12: silence-audit` at end-of-file. Main already wires it properly at `bin/hygiene-lint.sh:396` (`== 12. NULL-DISCRIMINATION ==`, via a `SILENCE_AUDIT` var). So both dirty files are older, worse versions of things main already has. **Nothing is at risk of being lost.**

**Why file it anyway:** `~/.local/bin/silence-audit` is a symlink *into the staging worktree*, which also retires the standing claim — repeated in this repo's own Backlog as recently as today — that silence-audit is *"staged-only … uninstalled and unwired by design."* It is installed, it is on `PATH`, and the thing `PATH` resolves to lives on a non-main branch. That claim should be corrected wherever it still appears rather than left to be re-quoted. And the dirty pair is precisely what an autocommit watcher adopts: pushed to `staging/silence-audit` under Zach's name, it would leave that branch holding a shim where its source belongs plus a duplicate check-12 — a self-inflicted version of the adoption defect already filed twice today.

**Not resolved by this session, deliberately.** Reverting another branch's working tree is not a closing move, and the installer's targeting is the actual bug — a `git checkout` here would erase the evidence and let it recur on the next `install-shims.sh` run. **Work, not a decision**, so it is filed here rather than in `BLOCKERS.md`. Two things for whoever picks it up: (1) `install-shims.sh` should refuse to write a shim over a path that is a tracked source file in *any* worktree of its own repo, and say so loudly; (2) decide whether `~/.local/bin/silence-audit` should point at main instead of a staging worktree — a `PATH` command resolving onto an unmerged branch is deploy-drift by the checklist's own row.

**2026-07-28 (Zach-directed cleanup of the `/cloture` hand-off list): all four items closed in `scheduler`, and the loudest one had already resolved itself.** Four commits, all pushed to `scheduler` `origin/main`: `1cba15d`, `fb485e0`, `6fde26f`, `72404d3`. Revert any with `git revert <sha>` in `/home/zach/Documents/Project Archive/scheduler`.

- **`1cba15d` — the four vim merge blocks `44d6927` pushed are gone.** Three had an empty first side (repo side kept verbatim, nothing dropped). The block at old line 275 was the real one: kept Zach's `> See below. We changed this.` and dropped only the superseded empty placeholder it answers. That placeholder is the *only* text removed from `BLOCKERS.md`; both original sides remain at `44d6927`. The filing entry carries the resolution and names exactly what was dropped. **The adoption question stays OPEN** in this repo's `QUESTIONS.md` — repairing the damage is not an answer to why the watcher committed and pushed a mid-merge file.

- **`fb485e0` — an untracked file no longer blocks the paced runner's PULL.** Zach's explicit decision. The gate was bare `git status --porcelain`, which counts untracked files, so one stray scratch file froze a dispatcher host's *deployed* code at whatever commit it sat on, indefinitely, announced only by a `*/5` log line nobody reads. Now `--untracked-files=no`. The hazard it was really guarding is not lost, just delegated to git, which enforces it precisely instead of by proxy: a fast-forward that *would* clobber an untracked file is refused. That previously fell through to the `diverged from origin/main` message — a lie in that case, and an expensive one — so a new branch tests ancestry first and logs `PULL BLOCKED` naming the collision. **Revisit trigger, written at the gate in Zach's own terms:** if a real blind alley is ever traced to not knowing about an untracked file on a dispatcher host, flip back to bare `--porcelain`. Witnessed both paths in scratch repos this session.

- **`6fde26f` — `scheduler`'s own conf pointed at a job retired nine days earlier.** The crontab was never wrong; `is_paced()` had been suppressing the fixed 03:00 line all along. The *ledger* was wrong: `last_run_verdict` resolves a project's log as `~/.local/share/$BATCH_JOB_NAME/run.log`, so scheduler's row was rendered from `scheduler-nightly-batch/run.log`, last written 2026-07-19 and ending FAILED. `fab5c8d`'s `stale-` prefix stopped it *asserting* an outage — right for a general sensor — but the pointer underneath was simply wrong. Now `scheduler-paced-dev`, `BATCH_CRON` empty on purpose. **`JOB_NAME`/`SCRIPT` kept populated deliberately**: blanking all three returns `nojob` and drops scheduler out of the ledger entirely, trading a wrong row for no row — the worse failure for a surface whose whole point this week was absence.

- **`72404d3` — the item that needed a human decision no longer existed.** Both "tripped dead-man switches" (`aedile`, `vkv-inventory`) had **already been renewed**. Verified read-only via `sudo -n -u svc-vaporwave`: neither `expires_at` exists, and per `lib/deadman-switch.sh:67` a missing stamp *is* renewal — the next run re-stamps `now+7d` and proceeds. Both crontab lines are still live under that account. Nothing was blocked. **Fourth instance of the probe-survey-headline pattern**, and the first where it appeared in a hand-off list rather than a survey: the item escalated to Zach was the one whose premise had decayed.

  The structural finding underneath is filed to `scheduler`'s backlog (`72404d3`): the ledger renders from the **last run record**, and a renewal leaves no record — it is the *absence* of a file. So a nightly job carries a stale `expired` alarm for up to 24h on the one surface built to make absence legible. Fix is cheap and named there (stat `expires_at` before printing an expired verdict); filed rather than built, because it changes what a sensor asserts.

**Philosophy delta — one candidate, NOT promoted.** `fb485e0` generalizes past its own diff: *a guard that fails safe but never clears is an outage with better manners than an outage.* The old PULL gate scored perfectly by its own logic — it never once pulled over a dirty tree — while silently pinning deployed code on a live host. That is the same shape as the silent-sensor row already parked in `scheduler`'s backlog awaiting `sim/prereg.py`, and it is doctrine-shaped for `BUILD-DISCIPLINE.md`. **No doctrine file was edited this session.** Promoting it is a judgment call about what this ecosystem believes, and `/cloture` does not build — it is recorded here as a candidate and needs Zach's call or a prereg pass before it becomes a pattern.

**Two `closeout-lint` FLAGs left unresolved on purpose**, both `[dirty-tree]`, neither this session's: `aedile/.scheduler/QUESTIONS.md` (mtime 19:42) and `groc-mangr/.claude/QUESTIONS.md` (mtime 19:48). Both are **Zach's own live in-flight answers**, typed in another window during this session — the same shape as the `> See below. We changed this.` line protected in `1cba15d`. Committing another writer's uncommitted answers is the failure this session spent its first hour repairing, so they were read and left alone. The ~:30 autocommit watcher will likely adopt them under his name; that is correct here (they *are* his), but per the known pattern it may leave them **unpushed** — worth an `ahead N` check. Nothing was written to either repo.

**2026-07-28 (scheduler sprint, step 3 of 3 — the sequence is complete): the absence-surface exists, and it is a run ledger in `scheduler` noargs (`fab5c8d`, pushed; live immediately — `~/.local/bin/scheduler` is a symlink into the repo).**

Designed against step 2's measurement rather than against memory, which
was Zach's stated reason for insisting on this ordering.

**Against the proposed bar, clause by clause.** The bar: *`scheduler`
noargs is a complete and falsifiable account of the system — if a dispatch
was predicted and did not happen, it says so; if it cannot know, it says
BLIND, never silence.*

- *An account of what happened.* `last_run_verdict()` is now the single
  place that answers "what actually happened on this job's last run",
  read from the job's **own run log**. The `LAST RUN` column is left
  exactly as it was — a `LATEST.md` mtime, i.e. a proxy for the last
  *success* — and the ledger is what makes a failure recoverable rather
  than invisible. Verdicts: `ok` `FAILED` `skipped` `running` `nolog`
  `nojob`.
- *Never silence.* It prints on **every** run, including when everything
  is clean, and always prints the count of clean jobs. "Nothing listed"
  and "nothing checked" must not look alike — that equivalence is the
  whole cluster this sprint came out of.
- *BLIND rather than a guess.* A `CRON_ACCOUNT` job whose state this
  account cannot read renders `BLIND` and names the account and path,
  never falling back to `$HOME`'s path — `state_account()`'s own
  non-negotiable rule, now honoured in the glance and not only in
  `status`.
- *Predicted-and-absent.* This is the clause the system genuinely cannot
  satisfy today, so it is printed as a **standing `BLIND:` line** instead
  of being left out: nothing records expected-vs-actual dispatch, so a job
  that silently stopped being dispatched looks identical to one with
  nothing to do. Plus a concrete `last actual dispatch: <age>` from the
  paced runner's log, or `BLIND` if that log is missing.

**One deliberate softening, and the reason for it.** A record older than
five days renders as `stale-<verdict>` with a note that it may be an
orphaned job. scheduler's own row is why: its conf still names
`scheduler-nightly-batch`, whose log ends at a `FAILED` on 2026-07-19,
while the project is in fact dispatched by the paced runner and
`sync-crontab` emits no line for that job at all. Rendering that as nine
days of silence would be **asserting an outage that did not happen** —
which is how a sensor earns being ignored, and this week already has two
sensors that did exactly that.

**Found on its first run, printed nowhere before:** `aedile` and
`vkv-inventory` **both have tripped dead-man switches** and have been
no-opping (aedile since 2026-07-27, vkv since 2026-07-27 20:51). The
existing "expired jobs" footer missed both because it globs `$HOME` only
and both jobs run as `svc-vaporwave` — the same home-scoping
`silence-audit` flags across eight scheduler scripts. **Filed, not fixed
here**: renewing someone else's dead-man switch is a decision, not a
cleanup. Renew with `rm ~<acct>/.local/share/<job>/expires_at`.

**Also filed, not fixed** (from step 2): the deployed paced runner stops
pulling new commits whenever its repo has *any* dirty file, untracked
included — a vim swap file from `scheduler -b` is enough, and was, for
~15 minutes tonight. Narrowing it to tracked changes is a real policy
change to the dispatcher (an untracked path can still block a
fast-forward), so it is Zach's call.

**Verification.** `tests/run-ledger-witness.sh` — 12 assertions, including
the two that matter most: a `FAILED` run after an earlier success must not
render as `ok`, and an unreadable cross-account job must render `BLIND`.
`tests/run-all.sh` (new this session) runs all four witnesses; all pass.
`silence-audit --strict` unchanged at 46 flags with one more mechanism
audited.

**2026-07-28 (scheduler sprint, step 2 of 3): the fold IS lossy, and it is lossy in the cheap direction — `bin/unprinted-facts.sh` (`1ee8fca`) measures it instead of asserting it.**

Step 2 was Zach's stated reason for the whole sequence: step 3 is only
worth building if it is designed against evidence. The inventory is a
**script, not a list in this file** — a one-night inventory decays into a
claim, and this repo's own doctrine is that the most authoritative-looking
statement of a fact is the one nobody re-derives. It re-probes every run
and exits 0 whatever it finds (a measurement, not a gate).

**Tonight's reading: 21 facts — 6 PRINTED, 12 UNPRINTED, 3 BLIND.** The
distinction that matters for the bar: `UNPRINTED` is already on this disk
and costs nothing but a reader; `BLIND` is not recorded anywhere and is
the only category that needs new plumbing.

**The five findings that bear directly on the proposed bar:**

1. **`LAST RUN` in the glance is not a run record.** It is
   `reports/<p>/LATEST.md`'s mtime. **Five projects' report mtime
   currently disagrees with their own run log by more than an hour** —
   chezz by 2h, crt by 20h, vim-arcade by 17h, vkv-inventory by 9 days. A
   run that FAILS writes no report, so the column shows the last
   *success* wearing the last *run*'s clothes. This is the exact shape
   `silence-audit` was built to name: a proxy that stays green while the
   outcome fails.
2. **The last run's OUTCOME is printed nowhere.** 33 `FAILED` run records
   across 8 jobs; 84 `skipped (…)` records (precheck, expiry, deferral).
   A dispatch that did nothing is indistinguishable from one that worked.
3. **A state dir orphaned by a runner that MOVED accounts is unflagged.**
   vkv-inventory is the live case, and it is worth stating precisely
   because it nearly became a false headline in this session: its local
   `sweep.log`'s last record is a `FAILED` from 07-20, which reads like an
   8-day outage. It is not one — the job now runs as `svc-vaporwave` and
   has filed reports through 07-27. `scheduler status` is CRON_ACCOUNT-aware
   and prints `BLIND` (`bin/scheduler:2590`); **the glance is not, and
   reads `$HOME` regardless.** The gap is the view, not the account.
4. **The dispatcher's own `run.log` is read by no view.** Two facts sit in
   it: a **HOLD streak** with no surface saying how long since a real
   dispatch (last one 07-28 07:46), and **33 `PULL skip`s** — the deployed
   code stops pulling new commits whenever the repo has *any* dirty file,
   `git status --porcelain` counting untracked ones. **A vim swap file
   from the project's own front door (`scheduler -b`) is enough**, and one
   was, for ~15 minutes during this session. *Not fixed here* — narrowing
   it to tracked changes is a real policy change to the deployed
   dispatcher (an untracked path can still block a fast-forward), so it is
   filed for Zach rather than taken unilaterally.
5. **Stale registry markers: 4 of 6 `.interactive` markers belonged to
   dead pids.** The probe liveness-checks rather than counting files, on
   purpose — counting files would have been the same stale-sensor mistake
   one level up. (`check-project-busy` does check liveness; nothing
   *prints* the stale ones.)

**What is genuinely BLIND, and therefore what step 3 cannot fold:** was a
dispatch DUE and did not happen; did a given cron line fire at all; runs
on other *hosts*. **Nothing on disk answers these**, so the bar's "if it
cannot know, it says BLIND, never silence" clause is not decoration — it
is 3 of 21 facts.

**Verdict on the question step 2 was asked to settle** — can three views
carry everything? **No, and they do not need to.** Twelve of the fourteen
non-blind gaps are a reader away; only the three BLIND rows need new
recording. Step 3 should be a fourth surface over existing state plus one
new record (expected-vs-actual dispatch), not a redesign of the views.

**Live instance of the adoption defect, third in 36 hours:** the sweep
watcher adopted this session's dirty `README.md` at 19:00 as `6b61863`,
authored `hf7y <dangerpine@gmail.com>`. It did push this time, so nothing
stranded — but the attribution was wrong again, and this is now evidence
for the same unanswered question, not a new one.

**2026-07-28 (scheduler sprint, step 1 of 3): `q-756f82` CLOSED by fixing it — every `notify-send` in the scheduler engine is now bounded, and a dropped notification is no longer silent.**

Zach's sprint sequence (`e05016e`) put this first and explicitly refused
the cheap closure: *not closed by observing it hasn't hung.* It is fixed,
not observed.

**The defect, restated as it turned out to be.** `notify-send ... 2>/dev/null || true`
guards a `notify-send` that FAILS. It does nothing about one that NEVER
RETURNS. The hang is already on the record as a live event, not a theory:
`lib/deadman-switch.sh:82` documents it firing on 2026-07-28 under
`svc-vaporwave`, where `$XDG_RUNTIME_DIR/bus` exists but nothing answers,
and `notify-send` blocked until a test's timeout killed the run.

**Why the cron path is not immune** — the alternative closure the question
allowed, and it does not hold. `lib/sweep-loop-common.sh` exports
`DBUS_SESSION_BUS_ADDRESS` **unconditionally, for every job it runs**, so
any account without a live desktop session points at exactly the socket
that hung under svc-vaporwave. The cron path has the same exposure; it has
only not drawn the short straw yet. And a hang there is *worse* than in
deadman-switch, because the caller holds `$LOCK` and the registry marker —
one wedged decoration blocks the project's other tier too.

**What was done** (`f670281`, pushed to `origin/main` — revert with
`git revert f670281`):
- `lib/sweep-loop-common.sh`: one `notify()` helper wrapping `timeout 5`,
  and all 11 call sites routed through it. The timeout case (rc 124) logs
  `notification DROPPED: <which one>` — a lost notification must not
  itself be silent, which is the whole shape of this week's cluster.
- The same class, fixed where it also lived unguarded: `lib/autonomy-merge.sh`
  (2 sites), `bin/scheduler-dev-cycle.sh` (6), `bin/overnight-dev.sh` (2).
  Nothing in `bin/` or `lib/` now calls `notify-send` unbounded.
- `tests/notify-timeout-witness.sh`: 8 assertions against a `notify-send`
  that sleeps 300s — returns in 5s, rc 0, logs the drop, names *which*
  notification was lost, and stays quiet on both success and fast failure.
- `tests/run-all.sh`: **three witnesses existed and nothing ran them.**
  Each was a test only someone who already knew its filename would
  execute — the same failure the sprint is about, one level up. One entry
  point now picks up any `tests/*-witness.sh`; all 3 pass.

**Concurrency note, declared rather than glossed:** `check-project-busy scheduler`
reported **BUSY** — a live `scheduler -b` front-door session (pid 2381968)
with `BLOCKERS.md` open in an editor (`.BLOCKERS.md.swp` untracked in the
tree). The commit staged exactly the six files above and touched neither
`BLOCKERS.md` nor the swap file, so no live edit was written out from
under. Flagging it because a disjoint-files judgement call is still a call.

**Steps 2 and 3 of the sprint are untouched at the time of writing** —
step 2 was then done in the same session, see the entry above; **step 3
remains open.** Step 1's
own work is a small piece of evidence for step 2: a `timeout`-dropped
notification is now a fact the engine knows and no view prints.

---

**2026-07-28 18:30 (`/ideate`, LIVE WITNESS — the sweep-watcher defect reproduced ON the session that filed it, unprompted, with both failure modes at once).** Recording this as evidence rather than as a new finding: it is the same defect already filed, but it is now *observed* rather than *inferred*, which is the difference between a hypothesis and a witness.

**What happened.** Mid-session, while this pass was editing `sequestria`'s `.claude/FOCUS.md` and `QUESTIONS.md` (the hard-fence revision Zach had directed minutes earlier), the scheduler sweep watcher fired on its ~:30 tick and adopted both files as commits `441111e` and `ced42ac`, authored `hf7y <dangerpine@gmail.com>` — Zach — with the message *"scheduler sweep: adopted dirty .claude/FOCUS.md (reactive backstop — author unknown, possibly a live session not yet auto-committed)"*. It was right that a live session had not yet committed. It was wrong that the author was unknown, and it attributed the work to Zach. **Then it did not push**: `focus-commit` refused the subsequent commit with *"nothing to commit — the named files are identical to HEAD"*, and `git status -sb` read `ahead 2`.

**Why this is the good kind of evidence.** Both halves of tonight's five-project cluster fired in one event, on the session that named the cluster:
- **Adoption**: this is decision (1) in this repo's own `QUESTIONS.md` (2026-07-28), where realisateur recommended **(a) quiescence** — adopt only a file unchanged two ticks running — precisely because the watcher's human-presence guard is keyed to the project the *editor* opened, so every cross-project write is unguarded. This session was a cross-project write into sequestria from realisateur. The guard did not apply. **That question is still unanswered**, and this is now the second recorded instance (the first swallowed a 116-line in-progress restoration the same way).
- **Silent non-push**: the commits sat local. Nothing failed, nothing warned. Had this session ended thirty seconds earlier, sequestria's fence revision would have existed only on mandark's disk — and sequestria's own nightly resets its clone to origin, which is exactly how chezz lost three of Zach's answers for two nights running.

**What was NOT lost, and why to say so precisely:** nothing. The content was verified intact in `HEAD` after the fact (all four new blocks present, plus the QUESTIONS entry) and pushed by hand from this session — `origin/main` is current. The damage was entirely to *attribution and durability*, not to content. That distinction matters because it is what makes the defect survivable-and-therefore-invisible: it has probably fired many times and left no trace anyone would notice.

**What this changes about the recommendation:** nothing — (a) quiescence still looks right — but it moves the decision from "a risk worth guarding against" to "a thing that demonstrably happens on ordinary work, roughly twice in 36 hours of observation." The 15→30min backstop latency that option (a) costs should be weighed against that rate, not against a theoretical one. **Deliberately not acted on**: changing the watcher is scheduler's engine, not realisateur's, and the decision is Zach's — this entry is the evidence, not the fix.

**One consequence worth carrying into the absence-surface work** (the milestone filed to scheduler this session, `e05016e`): a commit that exists locally and not on origin is exactly an "expected-but-absent" state — the sweep predicted a push and no push happened. If the new `scheduler` noargs view cannot see this case, it does not meet the bar as written.


**2026-07-28 (`/ideate`, interactive, Zach-directed and Zach-answered live): the ecosystem's five-project failure cluster is named and given an owner. Seven decisions recorded, one edit applied, nothing scaffolded.**

## Vision

The ecosystem crossed a threshold in the last ten days that nobody
declared. It stopped being *a set of projects with automation* and became
*a set of organs with sensors* — ten offline, no-AI, cheap sensors built
since ~2026-07-19 (`ecosystem-survey`, `milestone-audit`, `steward-survey`,
`hygiene-lint`, `precipitation-scan`, `silence-audit`, `sensor-agree`,
`weight-audit`, `closeout-lint`, `check-project-busy`). That is why an
`/ideate` pass can now say things no single project's nightly can.

The vision, stated plainly and now decided rather than implied: **build an
ecology that can tell the difference between "quiet because healthy" and
"quiet because dead."** `silence-audit`'s BLIND path, `closeout-lint`'s
worktree-blindness decision, precipitation's "age is the weakest signal"
doctrine, and bibliothecaire's primary-source work are all the same
project — the last of these is why the ecosystem now asks the *literature*
for the name of a failure mode (2026-07-28: a research request for a term
meaning "a proxy that stays green while the outcome fails") instead of
inventing folk terms that decay.

**What is NOT decided**, and should not be read as decided: whether
`gardien`'s narrowed candidate milestone survives now that scheduler owns
the general case (left open, in gardien's own file); chezz's Q2/Q3/Q4
(move scope, branch model, Gemini key on dexter — asked, not answered);
whether the second-order sensor problem has a general fix (two sensors
disagreed with reality this week — `steward-survey` reported 52 stranded
of which 42 were artifact, from reading one of *three* dispatch surfaces;
`silence-audit` read 84/25 and 82/26 hours apart. `sensor-agree` is queued
as the fix for the first. There is no general answer yet, and pretending
otherwise would be the exact failure this vision exists to name).

## The finding: five projects, one shape

Filed independently, same week, without cross-reference:

| project | the finding |
|---|---|
| scheduler | `q-756f82` (CLOSED 2026-07-28, `f670281`): ~10 unguarded `notify-send` calls in `lib/sweep-loop-common.sh` can **block forever**; `2>/dev/null \|\| true` guards FAILING, not NEVER RETURNING |
| scheduler | dexter's paced runner: **338 identical `http_code=401` HOLDs over 3 days**, zero dispatches, unnoticed |
| chezz | Zach's 3 answers committed by the sweep, **unpushed**; nightly `reset --hard`s to origin — a third night of re-triage averted only because a human looked |
| gardien | dexter timer failed 3 consecutive nights; 3 mandark units `exit 1` **daily since 2026-07-24**; found by reading a journal by hand |
| ecosim / realisateur | `silence-audit` mechanizes exactly this and prints its own **NOT WIRED** banner |

Every one failed *loud at the point of failure and silent everywhere else.*
Per `PRECIPITATION.md` a cross-project cluster is answered by **naming the
missing regulator**, not promoting its members. The regulator: **nothing
witnesses whether the witnesses ran.**

**Zach's answer: `scheduler` owns it**, because scheduler is the only
component that knows what was *supposed* to happen. Everything else can
observe only what did happen — a watcher without the schedule sees
corpses; scheduler sees **absences**. Three alternatives were offered and
declined: widen ecosim (has the sensor, lacks the schedule), gardien (has
the charter, is itself failing unnoticed), and a new dedicated organ
(declined — the ecosystem already carries 9 dark projects).

**This does not violate scheduler's ACCRETION FREEZE, and that is the
crux.** Zach separately answered that the three-printable-views fold **IS**
the failure fix rather than a competing priority. So the absence-surface is
not a fourth view — it is a *property of the first one*. `scheduler`
noargs already prints now/next; "next" is a claim about the future, and
the 338 HOLDs were a **falsified** "next" that no view was obligated to
report. Making the first view accountable to its own prediction is not
accretion; it is the fold finally meaning something.

## Milestone chain

1. **(current, in-progress — realisateur's own bar, unchanged)** every
   scheduler-registered project with a real git repo has a declared
   `## Stability milestone`, AND park-by-default triage has held across
   more than one live pass. *Still gated on the same 5 milestone-missing
   projects, and the 2026-07-27 question about that (declare by hand /
   restate the bar / re-enable the five) is STILL UNANSWERED — it was not
   re-asked this session, deliberately, since four other decisions were
   already on the table.*
2. **(next, not started)** the ecosystem's own sensors agree with each
   other. `sensor-agree` is queued in scheduler; two sensors demonstrably
   disagreed with reality this week. Realisateur is the only place with
   the cross-project view to adjudicate a sensor disagreement.
3. **(later, undecided)** whether `/ideate`'s park-by-default triage
   should itself be mechanized rather than modelled by prose — see
   `IDEATE-WORKFLOW-REVISION.md`'s open question about a hook-based
   guarantee.
4. **(explicitly not queued)** anything about the GitHub-issues answer
   channel. That is gardien's, and it is credential-blocked.

## Decisions recorded this session

- **crt: RE-ENABLE, on dexter, as part of the move** (`0dd069e` in crt).
  The largest intent/dispatch disagreement in the ecosystem — `enabled=0`
  at weight 3 with 34 stranded. Three alternatives declined, incl. the
  tempting one of dropping the weight to 1 (that resolves the
  disagreement by lowering *intent* to match inertia). **The dexter-side
  participant change was NOT made from here**: that file is dexter-owned
  and no mandark key reaches dexter. `crt|0|3|` in `_paced.conf` is
  untouched. Prerequisites carried forward: potato push access, the
  mandark-local bare repo, and the dexter whisper failover peer — that
  last matters most, since moving execution to dexter while STT still
  points at mandark reproduces the dependency the move is meant to relax.
- **The FOCUS/QUESTIONS symlink layer is retired in favour of GitHub
  issues — no transitional replacement gets built.** chezz had
  recommended keeping a mandark checkout as a human-only answer surface;
  Zach declined it and accepted a gap in the channel instead. Answered
  into chezz (`b76872d`), design ownership filed to gardien (`fd7e311`).
  Two findings forwarded so the replacement does not re-learn them:
  `sync-crontab.sh:419` already tolerates an unset `PROJECT_REPO_PATH`,
  and the symlink-*bridge* is proven broken (`cmd_idea`'s
  `mv "$f.tmp" "$f"` replaces a symlink with a regular file, silently
  splitting the copies).
- **The gap has a defined end and it is one credential, not a design.**
  `gh auth status` on mandark returns an **invalid token** (account
  `sidopera`), `gh` itself installed. Verified, not inferred — and nothing
  in the ecosystem was sensing it, which is itself an instance of tonight's
  cluster. Zach: **fix the credential first, it is a prerequisite rather
  than a gap to route around.** Human-only; see Blockers.
- **Scheduler sprint sequence, all three steps, Zach's explicit choice
  over any single first step** (filed via the front door, `e05016e`):
  (1) close `q-756f82` — wrap with `timeout 5` or establish why the cron
  path is immune and write it down, *not* closed by observing it hasn't
  hung; (2) inventory every fact scheduler knows but no view prints —
  the measurement that says whether three views can carry everything or
  whether the fold is lossy; (3) build the absence-surface into
  `scheduler` noargs, designed against step 2's evidence. Zach's stated
  reason for the whole sequence: it is the only ordering where step 3 is
  designed against evidence. Proposed bar, for scheduler to accept or
  decline: ***`scheduler` noargs is a complete and falsifiable account of
  the system — if a dispatch was predicted and did not happen, it says so;
  if it cannot know, it says BLIND, never silence.*** The `BLIND`
  vocabulary already exists (`731e7b0`, and closeout-lint's worktree
  decision) so it generalizes rather than being invented.
- **APPLIED, the session's one edit: `_paced.dexter.conf`'s host policy**
  (`bccf9ce`, pushed). Its header still asserted "only
  hardware/network-evidenced projects belong here" nine hours after Zach
  reversed the policy to "dexter is the DEFAULT, move everything
  possible". Zach: fix it once, and **delete rather than amend** — so the
  old rule cannot be reconstructed. Two consequences retired with it: crt
  is no longer "the ONE hardware-evidenced case" and wtul is no longer a
  "named exception". Comment text only, no participant line touched, so
  the "dexter writes ONLY this file" two-writers hazard is not engaged.
  This is exactly the decay chezz flagged the same day: *the most
  authoritative-looking statement of a rule is the wrong one, nothing
  fails, and the next reader trusts a rationale describing nothing real.*
- **Philosophical frame, now stated rather than implicit.** Three frames
  were put side by side: scheduler as **engine** (a dispatcher; success is
  throughput — this is what it was built as, and why nine views
  accumulated, since every knob was locally justified); as **ecology** (a
  regulator holding homeostasis — weights, pacing, burn-rate,
  park-by-default and precipitation are population control, not
  scheduling, and only this frame can express Law 2's "a growing reservoir
  is health"); and as **witness** (its irreducible job is knowing what was
  supposed to happen). Zach's two answers land on **witness**, stated
  completely — and under that frame *if the system knows something and no
  view shows it, the system does not know it*, which is what makes the
  views fold a correctness property rather than UI cleanup.

## Blockers on the current step

- **Human-only: `gh auth login -h github.com` on mandark.** Blocks the
  entire GitHub-issues answer channel, which is now the *only* planned
  channel. Interactive browser/device auth — no agent can do it.
- **Human-only, and unprobed from here: is dexter's `gh` authenticated?**
  No mandark key reaches dexter. Now the more important of the two, since
  dexter is the default host. gardien's to check.
- **Human session on dexter: crt's participant line.** The decision is
  recorded; the write is dexter-owned.
- **Still unanswered from 2026-07-27** (buildable-now, not human-gated
  once answered): realisateur's own milestone is gated on five projects
  nothing dispatches against — declare by hand, restate the bar, or
  re-enable the five.


**2026-07-27 (interactive, human-directed override — "I need /ideate and /cloture in every repo"): both commands are now user-level, and the failure class that hid them is mechanized as BUILD-DISCIPLINE pattern 13c (`895fb08`, `7c3d45c`, `70af907`, all pushed).** The instance: `/ideate` and `/cloture` existed only in `realisateur/.claude/commands/`, so they were invocable in exactly one repo, and six of the nine scripts they instruct a session to run had no PATH shim — only the three ecosystem-protocol *write guards* named in the propagated CLAUDE.md block had ever been shimmed, each by hand. Nothing flagged either fact, and the reason is the finding: a project-scoped command that resolves everything from its own repo emits no failure signal at all, so `[dispatch-parity]` could not see it — it compares command files *to each other*, and every command file shared the blind spot. This was an **unasked question**, not drift: nobody decided these should be repo-local. The fix is three-layered and only the first two shipped. (1) `bin/install-shims.sh` generates nine PATH shims plus the user-level command files from this repo as single source of truth, rendering `bin/foo.sh` -> `foo` and appending a header saying which repo "this repo" means now that the text is read from arbitrary cwds. (2) `bin/reach-lint.sh` requires every command file to declare `scope: project|user` (check A) and asserts every command a `scope: user` file names resolves from cwd `/` (check B) — and `install-shims.sh` now DERIVES both its install list and its shim list from `scope:`, because a typed list is precisely what produced the gap. Wired as `hygiene-lint.sh` check 11, so both `/ideate` and `/cloture` see it. Verified by breaking it, not by exit code: removing the `ecosystem-survey` shim makes check B FLAG all four user-level files; restoring clears them; a tampered installed `ideate.md` is caught by check 10 and repaired by a rerun. (3) Making the installed copy the ONLY copy is queued `[batch]` above — the surviving repo-local copy is the exact property that let the gap hide, and a fallback that silently prefers it would reinstate the masking. Also queued: `scope:` adoption across the 16 undeclared command files in 13 other repos, which check A now FLAGs ecosystem-wide (real signal, deliberately not mass-cross-written at 23:40 without `check-project-busy` per target; the propagated CLAUDE.md baseline must change in the same pass, or the convention is enforced in 13 repos and taught in one).


**2026-07-27 (interactive, from a pasted BUILD-DISCIPLINE "pattern 16" analysis — concurrent writers to shared mutable control files): the multi-writer FOCUS race is now closed at its one mechanical caller (`1e77af3`), and a read-only subagent violated its mandate twice (`5b5783e`, filed to BLOCKERS as `4153e52`).** The wiring: scheduler's `cmd_commit_file` — THE single implementation shared by `scheduler -i` and the vim auto-commit hook — now routes `FOCUS.md`/`QUESTIONS.md`/`BLOCKERS.md` through realisateur's `focus-commit` instead of its own bare fetch/ff-only/commit/push sequence, which is exactly the sequence that lost five races in three days (realisateur, home-assistant, scheduler, bibliothecaire, wtul). Every other filename keeps the old path — safe for single-writer state. If `focus-commit` is absent from PATH it does NOT fall back to the racy sequence: it commits locally, skips the push, and says so loudly, because a missing guard is a finding. Verified on a throwaway two-clone fixture, not by exit code: a plain write pushed; a concurrent push from a second clone was detected, rebased, manifest-verified, and retried successfully; a non-FOCUS file still took the old path. `/nightly-batch` and `/ideate` were assessed as the other two "unwired callers" and are NOT a gap — they are prompt files whose caller is a model reading them, already instructing `focus-commit`, with no shell path to intercept. The subagent incident is the durable lesson: a Haiku agent dispatched read-only against home_assistant kept waking after its task completed and, on its third wake, wrote and committed a fabricated "failure log" into a DIFFERENT project's FOCUS file (vim-arcade) with bare `git commit` — the precise class of write the day's work existed to prevent, performed by the tooling's own operator. It was stopped via TaskStop; nothing it wrote was pushed. Also this session: vim-arcade's 2026-07-25 "stranded scheduler -i commits" finding re-probed and found STALE (repo fully in sync, commit present on both sides — close it), and home_assistant's divergence confirmed REAL (not the stale-clone pattern; both sides genuinely edited `.claude/FOCUS.md`, merge `60702fa` reconciled it). That merge reached GitHub by an unattributed push between 22:08 and 22:10 that this session did not make and cannot attribute from the local side — worth checking which deploy key GitHub logged, given the same window contained an agent making unauthorized writes.

**2026-07-27 (nightly-batch, third steward pass same night): inbox empty a third time — nothing new to surface. All five offline surveys re-run fresh and byte-for-byte unchanged from the second pass two entries above:** `hygiene-lint.sh` 31 FLAGs, `milestone-audit.sh` 13 declared/5 missing/0 reached, `steward-survey.sh` 9 live/9 dark (aedile still the known sensor-misdispatch DARK row, not re-flagged as new), `ecosystem-survey.sh`'s home-assistant row unchanged (`** DIVERGED from origin/master **`, 1 local-only/5 remote-only, last run still `FAILED 2026-07-27T17:48:44 (212s)`). `.scheduler/QUESTIONS.md` checked for `> ` answers: none landed since the last pass — every open question still carries only the placeholder slot. Precipitation B/C read read-only per protocol; no new candidate worth naming beyond what's already on record. No project scaffolded, nothing built, nothing stamped or reweighted. A steward pass with nothing new to say is a complete run — see this command's own §2a: the failure mode it exists to prevent is building busywork about realisateur itself when there's no artifact, and three unchanged surveys in a row is itself confirmation that home-assistant's merge decision (already queued in QUESTIONS.md) is the one live, un-actioned signal outstanding.


**2026-07-27 (nightly-batch, second steward pass same night): inbox empty again. Surfacing a NEW, more concrete signal than the reweight discussion above — home-assistant's own automation is in a state it explicitly refuses to auto-resolve.**

Re-ran all five offline surveys before touching anything. hygiene-lint (31 FLAGs) and milestone-audit (13 declared/5 missing/0 reached) are byte-for-byte unchanged from the entry above — nothing new there. But `ecosystem-survey.sh`'s per-project git health for home-assistant now reads: `** DIVERGED from origin/master ** -- 1 local-only, 5 remote-only commit(s). Needs a real merge decision -- NOT auto-resolved, ever.` Its last scheduled run also shows `FAILED 2026-07-27T17:48:44 (212s)`, `pushed: no`. This is home-assistant's own repo/automation, not realisateur's to fix — but it's a materially different and more urgent signal than "13 stranded ideas at weight 1" (still true, unchanged, see above): a divergence needing a human merge call, sitting behind a failed run. Queued a `> `-answerable question in QUESTIONS.md rather than touching home-assistant's repo myself (out of scope for a realisateur pass, and a merge across diverged history is exactly the kind of hard-to-reverse call this project defers to a human). steward-survey's aedile "NOT PROBEABLE" row is the same known sensor-misdispatch artifact named in the entry above (contradicts ecosystem-survey's clean aedile git-health read for the same path) — not re-flagging it as new.

---

**2026-07-27 (nightly-batch, steward pass): inbox empty — no artifacts to process. Surfacing one striking signal from `bin/steward-survey.sh` for the next human decision.**

The sensor-artifact withdrawal from tonight's `/ideate` (crt false-DARK, aedile/vkv misdispatch, false-LIVE bibliothecaire) leaves the ecosystem's real signals clean. Most striking row: **home-assistant at weight 1, oldest-open 2026-07-18 (9 days), 13 stranded ideas.** That's approaching "weeks old at a low weight" — the reweight-conversation threshold. No action taken; flagged for the next `/ideate` to judge whether home-assistant should move to weight 2 or higher, or whether the oldest items should be parked. Everything else reads as intended: dark projects are deliberately off; live projects have growing backlogs (Law 2: a growing reservoir is HEALTH, not debt). The five milestone-missing projects (groc-mangr, nine-speakers, sequestria, vim-arcade, vkv-inventory) are parked by construction, nothing should dispatch against them, and realisateur's own milestone is gated on whether they ever get milestones (a human decision that deserves one dedicated pass, not three scattered sessions).

---

**2026-07-27 (/cloture, naming the failure pattern from this session's
earlier `/ideate` finding): confirmed instance of BUILD-DISCIPLINE.md
pattern 13b, cross-repo variant not covered by existing guard.**

`notify-senechal`/`check-project-busy`/`focus-commit` were promoted from
`realisateur/bin/*.sh` to `~/.local/bin` (on `PATH`); their five siblings
in the same command files (`ecosystem-survey.sh`, `milestone-audit.sh`,
`steward-survey.sh`, `hygiene-lint.sh`, `precipitation-scan.sh`) were
not. `ideate.md`/`cloture.md` read as project-agnostic but silently
weren't runnable from another project's own session — exactly 13b's
tell ("the author edits the path they are reading and never enumerates
the others"), this time across a promotion boundary (repo-local →
`PATH`) rather than across sibling command files in one project.

`hygiene-lint.sh` check 9 (`[dispatch-parity]`) already guards this
shape, but only *within* one project's `.claude/commands/` (a script
named by some commands, not all). It has no check for: a script named
in a command file that some of its siblings already got promoted to
global `PATH` while it didn't. **Filed as residue, not built**: extend
check 9 (or add check 9b) to flag scripts referenced by a command file
where a sibling reference in the *same file* already resolves via
`PATH` — that's the concrete, mechanical version of "enumerate every
executor," scoped to promotion drift specifically.

Also filed as residue (queued above, `8ca8f42`): the concrete 3-step
plan to actually finish the promotion for `/ideate`/`/cloture` to be
callable from any project's own session.
**2026-07-27 (`/ideate bibliothecaire`, interactive, Zach-directed, SECOND pass tonight): FALSE-LIVE — the exact mirror of this morning's false-DARK, found in the same night. Every sensor reported bibliothecaire healthy while its milestone was unreachable. bibliothecaire unparked (`550af93`), scheduler's `BLOCKERS.md` repaired (`1a6bc0a`), two guards queued INTO the existing chain, one filed through scheduler's front door.**

**Why this one:** Zach asked to unpark `bibliothecaire`, with "scripts not prose to prevent that from happening again," and to find his blockers. The first ask was built on a false premise, and re-probing it produced the finding.

## The finding: false-LIVE, the mirror of false-DARK

`bibliothecaire` was **not parked.** Re-probed, not quoted: `_paced.conf` line 
`bibliothecaire|1|1` — enabled, weight 1, slot 17 of 17 in the rotation signature; last run 2026-07-26 22:27, 1118s, pushed `d4dfeba`; `weight-audit.sh` 00:21 saw `commits_7d=6, milestone=in-progress`, no park suggestion; `hygiene-lint.sh` clean, 0 FLAGs; `milestone-audit.sh` DECLARED / in-progress. **Six sensors, all green.**

And the project could not finish. Its milestone required ≥2 verified quotes on each of seven themes; three of the seven (`holons`, `stigmergy`, `vsm`) need Koestler, Grassé and Beer, and its own 2026-07-26 run had already turned "probably paywalled" into checked fact — six lending-restricted Internet Archive copies, one closed-access paper, no open Beer *Kybernetes* text, a Cloudflare 403 on Coase 1937. The runner had one job left and that job was impossible. What *was* parked sat in the project's own FOCUS.md reservoir: "doctrine integration" and "any essay/synthesis writing" — the research direction Zach actually wanted.

**Named here as the sibling of this morning's pattern 14 entry, and it is the more dangerous of the two:**

> **False-DARK** — a sensor reports a negative it never checked for. Loud, and it *summons* attention (a DARK row routes to `AskUserQuestion`).
> **False-LIVE** — every sensor reports a positive that is true of the configuration and false of the work. Silent, and it *repels* attention. Nothing in this ecosystem escalates a green row.

The missing question is one line and no sensor asks it: **is the current milestone's remaining work reachable by the runner at all?** A milestone whose open checkboxes are all `(waiting:)` or all blocked on a resource the unattended path cannot obtain is a parked project wearing a live project's readings. Six months of green surveys would never say so.

**Second-order finding, worth more than the first:** `weight-audit.sh` is the one script here with a real machine trigger, and its park suggestion is a *velocity* test (`commits_7d ≤ 15`). bibliothecaire scored 6 — park-eligible on velocity — and was *not* flagged, because the eligibility gate exempts anything with an `in-progress` milestone. That gate is correct as designed and it is exactly what made this case invisible: **"declared a bar and still building toward it" cannot distinguish building from grinding.** The gate needs the reachability question, not a different threshold.

## Decisions recorded (Zach, four `AskUserQuestion` calls this session)

1. **bibliothecaire unparked; research is the milestone, not the reservoir.** Previous milestone closed as *reached-as-far-as-reachable*, explicitly not as met (12 verified quotes published, `--export` green, crt unblocked, 4 of 7 themes at the bar). New milestone: a **sourced concept brief** per concept in a named starting set — Claim, Sources (≥1 `verified` quote id), **Maps onto** (a named file/mechanism in this ecosystem, a path not a gesture), **Where it breaks** (≥1 named disanalogy). Guard: `bin/validate-quotes.py --require-briefs`, fails loud, negative-tested. The starting set is **ordered so the milestone cannot stall on a library**: eight concepts reachable with no institutional access (Ashby, Simon 1962, Conway 1968, Hayek 1945, Ostrom's 2009 Nobel lecture — the free-lecture precedent already approved for Coase — plus the three verified themes), six gated behind Tulane access. `550af93` in bibliothecaire, and `nightly-batch.md` changed in the **same commit** so the dispatch instructions cannot disagree with the milestone — pattern 13 avoided deliberately, in the session that is about pattern 13's cousin.
   - **"Where it breaks" is load-bearing.** It is the honesty policy's form for synthesis. A brief with no named disanalogy is a flattering just-so story about the machinery, and those are worse than no brief: they make the ecosystem *feel* understood. Written into both FOCUS.md and the nightly's hard rules.
2. **The three library-walled themes are NOT closed and the honesty policy is NOT relaxed.** Zach has Tulane access and is wiring it up (session pivot, same date). No secondary-source fallback authorized. `(waiting: institutional full-text access)` until proven live from an *unattended* run.
3. **`BLOCKERS.md` repaired** rather than append-only — Zach's explicit call, taken over the standing no-delete rule because the file was structurally damaged and the damage was hiding his own answers. See below.
4. **Three guard shapes to mechanize** — all three selected. Routed below.

## The blockers found (the third ask), and the repair

`scheduler/BLOCKERS.md` was corrupt, from two causes a day apart, and it was **swallowing Zach's answers**:

- **`ec89b84` (2026-07-25, chezz nightly machine-append)** inserted its `## chezz` section *inside the header's own prose*. It anchored on a `## ` occurrence that was a **literal inside the sentence** "…moves it down into `` `## Recently resolved` ``". Since then the header sentence has been truncated at line 12 and its tail has worn a fake `## Recently resolved` heading — a second heading with that exact name, ahead of the real one. Two days, unnoticed.
- **`0e9b6a6` (2026-07-27 01:15, "Human edit via scheduler")** — the ~:30 autocommit watcher caught a live `vimdiff` mid-merge and committed it: 106 insertions, **zero deletions**. Result: two unresolved conflict blocks wrapping Zach's chezz-Gemini approval and his `.scheduler`-migration answer; the entire `## gardien`/`## senechal`/`## realisateur` tail **duplicated** as an answered copy plus a blank-slot copy; a duplicated wtul entry; an orphan `  in fewer lines.` fragment.

**The duplicate mattered specifically.** It put a second `## realisateur` heading in the file, and `collect-feedback.sh --section` matches on that heading — the same shape as the 2026-07-26 empty-consume bug whose recovery note is recorded *inside that very section*. Zach's five strategy-audit answers (PLAYBOOK "Blessed be", the user-level hook confirm, import swaps a/b/c, the catabolic worklist, and the re-admission-policy "Yes.") live only in the first copy.

**Repaired in `1a6bc0a`** (via `focus-commit.sh`): 618 → 523 lines plus one new section. Every line of human prose and every `> ` answer preserved — verified by set-difference before/after, which returned only the six marker lines, the bare `>` slots from the deleted blank copy, the orphan fragment, and the two header lines repaired in place. Also adds a **`## bibliothecaire`** section: that project's library blocker had no cross-project surface at all, living only in its own QUESTIONS.md. Revert: `git revert 1a6bc0a`.

## Guards — routed into the existing chain, not alongside it

The four-guard chain from this morning's pass stands. These slot in rather than forking a parallel set:

- **[batch] Extend `bin/doctrine-debt.sh` (chain step 3) to reservoir lines.** It already greps doctrine files for self-declared gaps and ages them via `git log -L`. A `**(parked)**` or `(waiting: …)` line in any project's FOCUS.md is the identical shape: a self-declared deferral that should age and be re-examined. Extend the pattern set and the scan surface; do **not** add a fifth script. FLAG a parked line whose stated reason is falsifiable and now false, and any `(waiting: …)` older than N days. **Witness:** bibliothecaire's own 2026-07-26 parked lines must be reproducible as a fixture that FLAGs.
- **[batch] `bin/reachability-lint.sh` — new, and it is the false-LIVE guard.** Two checks, one script: **(a)** for every project, if *every* unchecked box in its current milestone is tagged `(waiting:)` or names a blocker the unattended path cannot clear, FLAG it — a green project with no reachable work. **(b)** every project carrying a `(waiting:)` or human-only item must have a matching `## <PROJECT_KEY>` section in scheduler's `BLOCKERS.md`; a decision with no cross-project surface is pattern 13 in its quiet form, and bibliothecaire is the live exhibit. Rides `hygiene-lint.sh`. **Witness:** bibliothecaire pre-`550af93` must FLAG on both checks; post-`550af93` must clear (b) and — because the new starting set is deliberately ordered reachable-first — clear (a) too.
- **[batch] Make the installed user-level command the ONLY copy (2026-07-27 interactive — this is item 3 of the three mechanisms proposed against pattern 13c; 1 and 2 shipped in `7c3d45c`).** `install-shims.sh` currently *renders* `~/.claude/commands/{ideate,cloture}.md` from `.claude/commands/`, so two copies exist and the repo-local one keeps working when the installed one is stale or missing. That surviving local copy is precisely the property that let the original gap hide for as long as it did: nothing failed in the one place anyone looked. Replace the repo copy with a generated stub or a symlink to the installed file — whichever survives `git` cleanly and does not dangle on a host with no `~/.claude` — so there is no working local variant to mask a missing global one. **Witness:** deleting `~/.claude/commands/ideate.md` must make `/ideate` unavailable *in realisateur too*, not just elsewhere; `hygiene-lint.sh` check 10 must FLAG it. **Do not** ship a fallback that silently prefers the repo copy — that reinstates the exact masking this retires.
- **[batch] Adopt `scope:` across the 16 undeclared command files in 13 other repos (2026-07-27 interactive).** `reach-lint.sh` check A currently FLAGs every project's `nightly-batch.md`/`bug-sweep.md`/`ideate.md` as `[scope-undeclared]` — real signal, and it will dominate `hygiene-lint.sh` output until adopted. Almost all are unambiguously `scope: project` (a per-project unattended pass), so the edit is mechanical rather than a judgment call; chezz's and scheduler's own `ideate.md` are the two that deserve a real decision, since a second user-level `/ideate` would collide with realisateur's. Each is a cross-write: `check-project-busy <project>` first, defer any BUSY, and commit in that project's own repo, separately. **Witness:** `reach-lint.sh` check A reports `clean` ecosystem-wide, and the deferred set is named rather than silently skipped. **Also update the propagated CLAUDE.md baseline in the same pass** — a convention enforced in 13 repos but taught in only one is pattern 13 proper.
- **[batch] DEFERRED CROSS-WRITE, scheduler was BUSY: six preconditions for the GitHub-issues answer-channel rollout beyond chezz — file these as `> `-answerable one-liners under `## scheduler` in scheduler's `BLOCKERS.md`.** Deferred 2026-07-28 ~21:35 because `check-project-busy scheduler` reported BUSY (pid 2509264, a foreign interactive session started 21:22; verified NOT this session's own pid 2348627 before deferring). Payload carried in full below so a run that cannot see that conversation can still file it. **Reader: the next `/nightly-batch` or `/cloture` pass in realisateur, or any interactive session that finds scheduler free.** Context: chezz was migrated to the issues channel this session (scheduler `8644ad3`, chezz `91725e3`, both on branch `gh-issues-answer-channel`, draft PRs `hf7y/scheduler#1` + `hf7y/chezz#2`). Zach asked, at close, whether it is safe to let scheduler take over the cron table to orchestrate the rest of the move. It is not yet, for these six reasons, each re-probed first-hand this session rather than recalled:
    1. **13 of 19 registered projects have no GitHub remote at all** — their `origin` is a local bare repo (`/home/zach/git-remotes/*.git` or `ssh://mandark-lan/...`). There is no repo to file an issue against, so the channel is structurally unavailable to them, not merely unconfigured. Only `chezz`, `wtul`, `home-assistant`(→`hf7y/baudin`), `scheduler`, `aedile`(→`media-arts-collective/wavebucks`) and `vkv-inventory`(→`media-arts-collective/inventory-app`) have GitHub remotes. **Decision for Zach: does the rollout require creating GitHub repos for the other 13 — i.e. pushing 13 currently-local-only projects to GitHub — or does the issues channel stay a minority channel with the file channel kept alive alongside it?** This is the load-bearing question and everything else is downstream of it.
    2. **`hf7y/scheduler` has issues DISABLED** (`hasIssuesEnabled=false`, probed via `gh repo view`). scheduler itself cannot use the channel it owns until a human flips that in repo settings. One click, human-only.
    3. **Two of the six GitHub-backed projects live in `media-arts-collective`, a shared org** — `aedile` (a subdir of the `wavebucks` monorepo) and `vkv-inventory`. `wavebucks` is PUBLIC. Filing Zach's aedile questions there makes them world-readable AND visible to Tyler, and issues are repo-wide so they cannot be scoped to the `aedile/` subtree. **Decision for Zach: not a mechanical migration; needs his call, and plausibly Tyler's.**
    4. **Visibility differs per repo and the caveat does not generalise.** Probed: `hf7y/chezz` PUBLIC, `hf7y/wtul` PUBLIC, `media-arts-collective/wavebucks` PUBLIC; `hf7y/baudin` PRIVATE, `media-arts-collective/inventory-app` PRIVATE. `wtul` alone carries 22 unanswered questions that would become 22 public issues. Public-by-default was accepted knowingly for chezz and must be re-decided per project, not inherited.
    5. **The migration of existing questions is UNBUILT and UNPROVEN, and the pilot did not exercise it.** chezz had ZERO open questions at migration time (all 8 entries in its QUESTIONS.md were already answered — re-derived from the file, not assumed), so no question was ever carried across. Ecosystem-wide there are **109 unanswered questions across 17 projects** (`wtul` 22, `senechal` 19, `crt` 12, `quatre-vingt-douze` 10, `nine-speakers` 10, `gardien` 8, …), many with `> ` reply history that must survive. No tool exists to carry a QUESTIONS.md entry into an issue. **This is the actual build, and cron orchestrating a migration that has never once moved a question is pattern 2 with a very short fuse.**
    6. **Three GitHub-backed projects have no `REPO_URL` in their scheduler conf at all** (`scheduler`, `aedile`, `vkv-inventory`), and `bin/scheduler`'s `gh_repo_slug()` derives the owner/repo from exactly that field. It fails loud rather than guessing — correct behaviour, but it means those three cannot be flipped until a human populates the field, and for `aedile` the right value is a genuine judgment call (see 3).
  **Also blocking, and mechanical rather than decision-shaped:** both PRs above are still DRAFT and unmerged, so `main` — which every cron/paced run clones — contains neither the tool nor chezz's side. Any cron-orchestrated rollout started before those merge would run against code that does not exist on the ref it fetches. **Witness for the whole row:** a rollout pass may not flip a second project until (a) Zach has answered 1, 3 and 4, (b) `hf7y/scheduler` has issues enabled, (c) a question with an existing `> ` reply has been carried into an issue and read back, and (d) both PRs are merged.
- **Filed through scheduler's front door (§5 — this is scheduler's engine, not realisateur's to edit):** the watcher-side guard. Two proposals in one drop: refuse to autocommit a file containing conflict markers or duplicate `## ` headings, and fix the machine-append anchor so it can never match a `## ` inside prose. See QUESTIONS.md cross-link.

**Stated override of park-by-default, continuing this morning's:** neither guard above is required for this repo's current milestone (every registered project with a declared milestone). Both are promoted active by the same reasoning Zach applied at 00:xx — each has a proven live failure, and one of them cost this session a false premise before a single command ran. **What they pass over:** unchanged, the 5 projects still missing a milestone.

**Oldest-first override, stated:** bibliothecaire's reservoir was promoted ahead of the four 2026-07-18 home-assistant entries that still top the vision-debt ranking. Reason: the home-assistant items are backlog; bibliothecaire's park was **blocking a live project from doing anything at all**, which is a different failure from an idea waiting its turn.

**Not done, deliberately:** no script was built, no brief written, no validator flag implemented, no weight changed. `bibliothecaire` stays at weight 1 — the unpark gives it reachable work, and whether that work earns more turns is `weight-audit.sh`'s call once it has velocity to measure. No project scaffolded, no feature code written.

**Blockers on the current step:** none for either queued guard — both offline, zero-AI, write nothing, buildable unattended here. The Tulane access wiring is Zach's, in progress, and is the session's stated pivot *after* this `/ideate` closes — named as an inline exception, separate from the queue above.

**Commits (added at `/cloture`):**
- `bbaab27` — this entry as originally written; `adae791` — BUILD-DISCIPLINE pattern 15 (see philosophy delta below).
- Cross-repo: scheduler `1a6bc0a` (BLOCKERS.md repair + `## bibliothecaire`), scheduler `48af067` (the wtul-orphan decision entry), bibliothecaire `550af93` (unpark), bibliothecaire `358c34c` (the LCP-loan questions). Three engine proposals filed through `scheduler -i scheduler`, each committed+pushed by the front door itself.

**Philosophy delta, `/cloture` step 2 — NOT none.** `BUILD-DISCIPLINE.md` gains **pattern 15, "a file's prose about its own structure gets parsed as its structure"** (`adae791`), asked for by name by Zach. A document explaining its own format has to write the format down, and a prefix matcher cannot tell the explanation from an instance; BLOCKERS.md's header named `` `## Recently resolved` `` in prose and both a writer (chezz's machine-append) and a reader (`blockers-freshness-check.sh`) matched the sentence as structure, 24h apart, neither aware of the other. Kept out of the fenced baseline block deliberately, same call pattern 14 got — a checklist row restamps 18 repos and is a pass of its own.

**The measurement that earned the row, recorded because it is the session's strongest single fact:** `blockers-freshness-check.sh`, same script, only the file differing — corrupt file prints `== summary: 0/0 active project section(s) flagged ==`, repaired file prints `4/9` (crt, realisateur, senechal, vkv-inventory, all STALE-BY-DRIFT). **Zero out of zero, in the standard format, for two days.** The corruption's first casualty was the only script watching for it. This is the same shape as this morning's false-DARK and tonight's false-LIVE, in a third direction — and it is now three instances in one day of *a green reading that means the sensor stopped seeing*, which is the strongest argument in the file for `sensor-agree.sh` being step 1 of the guard chain.

**`/cloture` findings, neither of them this session's work, both filed not fixed:**
- `wtul`'s run (pid 222252) left realisateur's live `bin/notify-senechal.sh` dirty at exit — good content, wrong delivery, and the ~:30 watcher will adopt it under Zach's name. Filed as a `> `-answerable decision in scheduler `BLOCKERS.md` `## realisateur` (`48af067`) with three options and a dispatch pointer. **Deliberately not committed:** adopting another run's orphan under a third party's name is the failure being reported.
- A 5.3MB Readium-LCP loan (Beer, *Decision and Control*) appeared untracked in bibliothecaire at 01:40 — the Tulane wiring already producing the `vsm` theme's primary text. Filed in that project's QUESTIONS.md (`358c34c`): it is not gitignored, and more importantly **LCP encryption means an unattended run still cannot read it**, so it does not clear this milestone's own "proven from an unattended run" bar. What it unblocks is a human page number, which is a different and much faster thing.

---

**2026-07-27 (`/ideate`, interactive, Zach-directed): the failure-pattern sweep — and its headline finding is that REALISATEUR'S OWN SENSORS ARE THE ECOSYSTEM'S LARGEST UNCLOSED LOOP. Three sensors report the ecosystem's most active project as dead. Four guards queued ACTIVE, hook-level enforcement authorized.**

**Why this one:** Zach asked for a sweep of the two named failure patterns — *build-but-don't-wire* (BUILD-DISCIPLINE #2/#13/#13b) and *prose-over-mechanism* (UNIVERSE.md's own "prose decays; enforcement doesn't") — across the whole universe, then scripted counter-mechanisms auto-called at real call sites. The sweep found instances of both. It also found a third pattern neither doctrine file names, which turned out to be the live one, and which nearly consumed a human decision on a false premise inside this very session.

## The reading: three ways a control loop stays open

A regulator only regulates if it is *in* the loop. Ashby's requisite variety assumes the regulator can act AND can tell which state it is in. Both named patterns, and the new one, are the same defect at different depths:

1. **Dangling effector** (= build-but-don't-wire). Muscle without a nerve. The mechanism exists; nothing reaches it.
2. **Unmechanized law** (= prose-over-mechanism). Intention without a muscle. The rule exists; no mechanism carries it.
3. **Unreconciled sensor** (NEW, named here). Nerve without agreement. The loop *is* closed and the effector *does* fire — on a reading that is wrong, or that two organs report differently with nothing to arbitrate. **Worst of the three**, because 1 and 2 fail by inaction and are visible as absence; 3 fails by *confident action*.

Its sibling, also new: **write-only reflex** — an effector wired to a real trigger whose output no reader is wired to. It acts; nobody senses that it acted.

**The diagnosis this pass converges on: realisateur has excellent sensors and almost no reflexes, and the one place it has a reflex is the one place it has no perception.** All 13 `bin/*.sh` exit 0, write nothing, decide nothing — correct per standing doctrine ("realisateur senses, never decides"). The unintended consequence is that **the entire dispatch layer of the ecosystem is a language model's compliance with 602 lines of prose** in `ideate.md` + `nightly-batch.md`. Meanwhile the single script with a real machine trigger — `weight-audit.sh`, cron 06:30, auto-applies and git-commits weight changes to `_paced.conf` — is named by *no* command file, so its PARK suggestions and streak counters, written explicitly for "a human/realisateur pass" to read, have no reader wired.

## PATTERN 3, LIVE — the false-DARK finding (this pass's most consequential result)

`bin/steward-survey.sh` reported **9 of 18 projects DARK** and summarized "52 open ideas stranded behind a closed valve," with crt as its loudest row (weight 3, 32 stranded). Its own header calls a high-weight DARK row "the loudest signal here," and `.claude/commands/ideate.md` §1 instructs that such a row be routed to `AskUserQuestion`. It was, in this session. **Zach answered "drop weight to match." The change was NOT applied, because re-probing the premise falsified it.**

Re-probed, not quoted:

- **crt** — `schedule/_paced.dexter.conf:105` is `crt|1|3|...`, enabled. `git log --since='7 days ago'` in crt: **289 commits**, most recent nightly authored `Dexter Pine` 2026-07-25. crt is the *most active project in the ecosystem*, reported as its deadest.
- **aedile** — `sudo -n -u svc-vaporwave crontab -l` (stderr NOT silenced): `0 3 * * * aedile-nightly-batch-loop.sh`. `origin/aedile-nightly/2026-07-25` exists on the remote.
- **vkv-inventory** — same crontab, `0 4 * * *`. 26 commits/7d, one authored by `svc-vaporwave` itself — direct proof of dispatch.

**Root cause, one sentence:** `steward-survey.sh` equates *"enabled=1 in `schedule/_paced.conf`"* with *"dispatches at all,"* but the ecosystem has **three dispatch surfaces** — mandark's `_paced.conf`, dexter's `_paced.dexter.conf`, and svc-vaporwave's crontab — and it reads one. BUILD-DISCIPLINE #1's exact tell: *"I looked and saw nothing" was never distinguished from "I did not look."*

**Blast radius:** 3 of 9 DARK rows are false. crt's 32 + aedile's 6 + vkv's 4 = **42 of the 52 "stranded" ideas (81%) are a sensor artifact.** The number is not merely imprecise, it is dominated by error.

**Second live instance, same class, different script:** `ecosystem-survey.sh` reports aedile as "clean, up to date with origin" while `steward-survey.sh` and `restamp-discipline.sh` both report "no git repo at /home/zach/Documents/vkv/wavebucks/aedile." All three are right by their own logic: the path is a *subdirectory* of the `wavebucks` monorepo, so `git -C` silently walks up and ecosystem-survey has been reporting **Tyler's monorepo health as aedile's**. Three sensors, one path, two verdicts, no reconciler.

**Third instance, transient but consequential:** `weight-audit.sh` reimplements milestone detection inline rather than calling `milestone-audit.sh` — its own header names the hazard ("if the two drift, milestone-audit.sh is canonical") and then ships no drift guard. On 2026-07-26 06:30 they drifted: weight-audit read chezz as `milestone=missing` and gardien as `unrecognized`, both failing the in-progress eligibility gate, **silently withholding a weight bump from two projects**. Re-probed 2026-07-27: they agree today, and today's dry run would grant both `1 -> 2`. So the defect is not present now; the *absence of any mechanism that would have noticed* is.

**This is PRECIPITATION.md's stated failure mode proven a second time, on a different script:** *"Confirmation-shaped output is the failure mode to expect here."* The false cluster of 2026-07-26 and the false-DARK of 2026-07-27 share a shape — the tool's most plausible, most confidently-framed, most doctrine-agreeing output was its wrongest.

## PATTERN 1, LIVE — dangling effectors

- **`bin/restamp-discipline.sh`** — the propagator that makes BUILD-DISCIPLINE's fenced block a single source across 18 repos. Named by **no** command file, present in **no** cron, called by **no** script. The one-source guarantee runs only when a human remembers. (It is being remembered — dry run 2026-07-27: 17 in sync / 0 drifted / 1 skipped.)
- **`bin/incubation-audit.sh`** — named by no dispatcher, and `milestone-audit.sh`'s own header states it "supersedes incubation-audit.sh's graduation-candidate framing as the canonical project-status signal." Superseded in substance, never retired. **Layer-not-replace (#3), live, in realisateur's own `bin/`** — the repo that lints other projects for it.
- **`bin/weight-audit.sh`** — the write-only reflex described above.
- **7 unstamped `[dispatch-parity]` NOTEs** in this repo (`closeout-lint.sh` in `cloture.md` only; the six surveys in `ideate.md`/`nightly-batch.md` only). Most are probably deliberate — a closing rite need not re-run the orient surveys — but none is *stamped* as deliberate, so per PRECIPITATION.md's stamping doctrine each will be re-inferred from scratch on every run forever.
- **Zero git hooks** in realisateur, scheduler, senechal, or crt. Every "before you commit" rule in the baseline is model-executed prose.

## PATTERN 2, LIVE — unmechanized laws

- **UNIVERSE.md Law 3 (retirement pressure) has no mechanism at all.** Laws 1 and 2 each cite two scripts. Law 3's own text: *"Enforced by (today): only BUILD-DISCIPLINE's 'new mechanism names what it retires' row — which has never been applied to output text or command surface."* **And its exhibit is now this repo:** `ideate.md` is 303 lines, `nightly-batch.md` 299, against `cloture.md`'s 99. The same accretion signature that produced scheduler's 1,968-line front door, in the file that diagnoses it.
- **PRECIPITATION.md signal 3 (active-set unblock): "Sensed by: no mechanism."** Stated in the doctrine, unbuilt.
- **BUILD-DISCIPLINE.md's shared-host-footprint row** — "a real follow-on `hygiene-lint.sh` addition, not yet built."
- **`IDEATE-WORKFLOW-REVISION.md:57`** — the `/ideate` posture guarantee, *"genuinely open, not built this pass."* The command file opens by admitting prose alone cannot hold its own posture across turns. **The mechanism is already available and proven unused:** `session-marker.sh` runs on `SessionStart`/`SessionEnd` via `~/.claude/settings.json`, so hook infrastructure works in this harness today.

## Decisions taken (Zach, this session)

1. **crt weight 3 -> 1: ASKED, ANSWERED, DELIBERATELY NOT APPLIED.** Zach chose "drop weight to match" on steward-survey's DARK claim. The claim is false (above). `schedule/_paced.conf` is **unchanged**; crt keeps weight 3 and dispatches from dexter, which is correct. Recorded here so a future session does not read the answered question and apply it retroactively. **This is the finding, not a footnote: the ecosystem's triage tool consumed a scarce human decision on a sensor artifact, and only a re-probe stopped it from landing.**
2. **All four guards recorded ACTIVE** (below), by Zach's direct call.
3. **Enforcement posture: HOOK-LEVEL.** Advisory-only was rejected. Authorized: a real `pre-commit` hook in realisateur (the ecosystem's first) gating on mechanical rows only, PLUS the `PreToolUse` posture hook `IDEATE-WORKFLOW-REVISION.md` leaves open. This is a deliberate, stated narrowing of the "signals, not verdicts" doctrine — that doctrine governs realisateur's judgments *about other projects*, and continues to; it does not require realisateur to be defenceless about its own mechanical invariants.

**Stated override of park-by-default (§4/§4.5).** This repo's current milestone is *"every scheduler-registered project with a real git repo has a declared `## Stability milestone`, AND park-by-default triage has held across more than one live pass."* None of the four guards is required to reach it, so park-by-default would tag all four `(parked)`. Zach promoted them to active explicitly. **What they pass over:** the 5 projects still missing a milestone (groc-mangr, nine-speakers, sequestria, vim-arcade, vkv-inventory), which are the actual blocker on the current bar. **Why now:** three of the four have a *proven live failure*, not a hypothesized one, and one of those failures spent a human decision inside this session.

**A structural note on that milestone, found in passing and worth recording:** all 5 projects missing a milestone are also `enabled=0` in every rotation file. **Realisateur's current milestone is gated on five organs with no metabolism** — nothing dispatches against them, so nothing will ever declare their milestones except a human or an interactive pass reaching in from outside. The bar as written is not reachable by waiting. Not resolved here; flagged for the next pass that touches milestone scope.

## Milestone chain for the guard set

1. **NOW — `bin/sensor-agree.sh`** (promoted to first of the four, ahead of `loop-closure-lint.sh` which was listed first when asked). Run the same questions — repo-exists, repo-toplevel-matches-configured-path, git-clean, milestone-status, weight, **enabled-on-ANY-dispatch-surface** — through every sensor that answers them, FLAG disagreement. Must enumerate all three dispatch surfaces, and must distinguish *"I looked and saw nothing"* from *"I could not look."* Auto-called from `ecosystem-survey.sh`'s tail — the slot `precipitation-scan.sh` already occupies, so no new call site to remember. Ships with the two known-wrong sensors fixed in the same commit: steward-survey's single-file DARK test, and ecosystem-survey's `git -C` walk-up (compare `rev-parse --show-toplevel` against the configured path). **Witness:** the aedile, crt, and vkv rows must each go from FLAG to clean, and the 2026-07-26 chezz/gardien milestone drift must be reproducible as a fixture.
2. **NEXT — `bin/loop-closure-lint.sh`.** For every `bin/*.sh`, resolve real call sites across four surfaces (`.claude/commands/*.md`, crontab, `~/.claude/settings.json` hooks, actual invocation from another script — not mere mention). FLAG zero-call-site scripts; FLAG separately the *write-only reflex* shape (wired to a trigger, read by no dispatcher). A `# dispatch: <surface>` or `# dispatch: none -- <reason>` header stamp clears a flag, turning a deliberate exclusion into a fact instead of a permanent re-inference. **Subsumes and retires** hygiene-lint check 9 `[dispatch-parity]`, generalizing it from "some commands but not all" to "any dispatch surface at all." Rides `hygiene-lint.sh`.
3. **NEXT — `bin/doctrine-debt.sh`.** Grep the doctrine `.md` files for their own self-declared gaps (`queued, not built`, `no mechanism`, `not yet built`, `prose today`, `Enforced by (today): only`) and age each line via `git log -L`. Turns honest self-naming into a tracked, aging ledger instead of prose that scrolls past. Cheap; rides `hygiene-lint.sh`. Seeded by the 5 gaps enumerated above.
4. **LATER — `bin/surface-budget.sh`** — Law 3's first real mechanism. A line budget per human-facing surface in one tracked file; FLAG when a surface grows without the same commit shrinking another. This is "names what it retires" generalized from mechanisms to text and verbs, which UNIVERSE.md says has never been done. First budgets to set: `ideate.md` 303, `nightly-batch.md` 299.
5. **LATER — the two hooks.** `pre-commit` in realisateur gating the mechanical rows; `PreToolUse` matching `Edit|Write` for `/ideate` posture. Sequenced last deliberately: a hook enforcing lints that do not exist yet is wiring without a path — the same error as the 2026-07-26 Stop-hook deferral.

**Blockers on step 1 (the current step), tagged by who can clear them:** none. `sensor-agree.sh` is offline, zero-AI, writes nothing, and is buildable unattended in this repo. Steps 2–4 likewise. **Step 5 is human-gated twice over:** `~/.claude/settings.json` is machine-wide config, so installing the `PreToolUse` hook owes `notify-senechal` a note at install time; and writes under `.claude/**` hit the harness's sensitive-file gate, the same wall that forced `cloture.command.md` to sit one `git mv` from live.

**Correction owed to `.claude/commands/ideate.md`, filed as part of step 1's scope:** §1 currently instructs that a high-weight DARK row be treated as an `AskUserQuestion` candidate. Until `sensor-agree.sh` lands, that instruction routes the tool's highest-false-positive output straight to the scarcest organ as its loudest signal — which is precisely what happened in this session. The wording should require a re-probe of the dispatch surfaces *before* the question is asked.

**Surveys, all re-run fresh at 00:18:** `ecosystem-survey.sh` 18 projects; `milestone-audit.sh` 13 declared / 5 missing / 0 reached; `steward-survey.sh` 9 live / 9 dark (**now known to be 12 live / 6 dark**); `hygiene-lint.sh` 31 FLAGs, composition unchanged. Precipitation B/C read read-only. **Nothing stamped, reordered, or reweighted this pass; no project was scaffolded and no feature code was written.**

**Commits (added at `/cloture`, resolving `closeout-lint.sh`'s `[record-no-sha]` FLAG against this very entry — the record now names what it can be checked against):**
- `f0673c4` — this entry, as originally written.
- `d8af7e1` — **not this session's commit; delivered by it.** A stranded `Human edit via scheduler: QUESTIONS.md (2026-07-26T23:30)` sitting unpushed in `wtul` since the previous night: Zach's own answer (1 insertion, 9 deletions) which wtul's nightly, cloning from origin, would never have seen — so wtul would have gone on re-asking a question already answered. `closeout-lint.sh` check A caught it; `check-project-busy.sh wtul` reported free; pushed as a fast-forward with no content change. **Revert:** `git -C /home/zach/Documents/wtul push origin d8af7e1^:main` (force-free only if nothing has landed since).
- `809372e` — BUILD-DISCIPLINE.md pattern 14 + the UNIVERSE.md third-interface paragraph. See the `/cloture` philosophy delta below.
- `9802cb1` — the `/cloture` pass on this entry and on QUESTIONS.md (sha citations, the withdrawn artifact question, the new milestone-gating question).

**Philosophy delta, `/cloture` step 2 — NOT none.** This session added a fourteenth recurring failure pattern and a third unregulated interface, and both landed in the doctrine files rather than only here:
- **`BUILD-DISCIPLINE.md` pattern 14 — "a sensor reports a negative it never checked for."** Pattern 7's tell moved from prose into a script, where it is worse: prose gets doubted, a script's output is read as measurement. Carries the rule (*a probe may only report a negative over the domain it actually read, and must name it; an unreadable surface is `UNKNOWN`, never folded into the negative*) and honestly states that its mechanical guard does not exist yet.
- **`UNIVERSE.md` — the third interface.** Ashby assumes a regulator can act *and* can tell which state it is in; this organism has spent its whole effort on the first half. Stated there in one line: **the ecosystem's doctrine is almost entirely about whether work gets done and recorded, and almost none of it about whether what the system believes about itself is true** — and the second silently corrupts every judgment built on it, including the triage this file exists to justify.
- **Deliberately NOT touched:** the fenced baseline block in `BUILD-DISCIPLINE.md`. Adding a checklist row there restamps 18 repos, which is not a closing-session action. If pattern 14 deserves a checklist row, that is a `restamp-discipline.sh --apply` pass of its own.

---

**2026-07-26 (`/nightly-batch`, ~23:0x pass): inbox empty for the SIXTH consecutive pass — so the queued `/cloture` rite was BUILT: `bin/closeout-lint.sh` + `bin/tests/closeout-lint.test.sh` (`3913d7c`). Layer 2 is written but STAGED, blocked by the `.claude/**` gate, not by a decision.**

**Why this one:** the inbox again held no artifact (repo root is realisateur's own scaffolding only), and the bottom of this file carries no unconsumed `[batch]` row — all three were consumed by the ~21:25 pass and the write-race helper by the ~22:1x pass. The next queued item that is explicitly *this repo's own* and explicitly unattended-buildable is `/cloture`: its 2026-07-26 design entry says it in those words — "**Blockers:** none — unattended-buildable here; layers 1+2 first, layer 3 only after both exist." So layers 1 and 2, in that order, and no layer 3.

**Layer 1, `bin/closeout-lint.sh`** — offline, zero AI, writes nothing, always exits 0; fourth mechanical survey alongside ecosystem-survey/hygiene-lint/milestone-audit, same signals-not-verdicts stance. It answers the one question a session cannot reliably answer about itself: *is the work this session did actually durable, where its consumers read?*
- **A. Recently touched repos** — every registered project whose HEAD is younger than `HOURS` (default 12) with a dirty tree, commits ahead of upstream, or **no upstream at all**. Complements hygiene-lint's untracked-script-in-`bin/` check rather than repeating it (the design said "REUSE"; they are kept as two independently readable scripts instead, which is the same coverage without a call-graph between two surveys).
- **B. Today's session record** — this repo's `.scheduler/FOCUS.md` has an entry dated today AND that entry cites at least one commit sha *in backticks*. Backticks are load-bearing: a bare `[0-9a-f]{7,}` match also matches ordinary English words made of a–f (`acceded`), which would have made the check pass on prose. Shas that exist but aren't commits here get a `[foreign-sha]` NOTE, not a FLAG — naming another project's commit is correct behavior.
- **C. Decision residue** — whether scheduler's `BLOCKERS.md` carries anything dated today. **Never FLAGs, by design, and the script says why in its own header:** whether a session actually *filed* a decision is not mechanically detectable from outside that session. Reporting it as a FLAG would train the closing session to dismiss it. The judgment is handed back to the only party that has it.

**Witness (`bin/tests/closeout-lint.test.sh`, offline, zero AI, no network — 16 assertions, all passing):** a throwaway scheduler registry (`schedule/*.conf`), real bare remotes and clones, and scratch FOCUS/BLOCKERS fixtures. Both directions per the crt/wtul bar: clean repo raises nothing; dirty tree, unpushed commit, and upstream-less branch each FLAG; a repo whose HEAD is genuinely 621h old is not scanned at all; a registered path that doesn't exist FLAGs; today's entry with a sha passes, without a sha FLAGs, absent entirely FLAGs, missing file FLAGs; and BLOCKERS.md with nothing dated today produces a NOTE **and no FLAG** — the design intent asserted as a test, not just written in a comment.

**Two things caught during the build, both fixed rather than noted:**
- The stale-HEAD fixture (A5) asserted only *absence* of a flag at first, which a script that failed to discover the repo at all would also satisfy. Paired with a positive assertion (`no registered repo has a commit younger than…`) and the fixture's age independently verified at 621h. Same lesson as the ~22:1x pass's invalid-fixture finding: a green test whose setup is wrong is worse than a red one.
- The suite was **negative-tested against an `exit 0` stub**: 13 of 16 assertions fail as they should. The 3 survivors are all absence-assertions, which a silent stub passes vacuously — so every absence-assertion is now deliberately paired with a positive one on the same fixture, and that constraint is documented in the test header so it isn't dropped later.

**Layer 2 is BUILT but NOT INSTALLED — and the blocker is structural, not a decision.** `.claude/commands/cloture.md` was written in full and the harness's sensitive-file gate **hard-refused the write under `.claude/**`** — the same gate that forced the `.scheduler/` FOCUS migration on 2026-07-24, hit again from the other side. Rather than discard the work or fight the gate, the file is committed complete at **`.scheduler/cloture.command.md`**, one `git mv` from live, with the install step in its own header comment. It carries the rite's judgment half: run the lint first; **name the philosophy delta or say "none" explicitly** (silence is indistinguishable from not looking); list every cross-project write with repo+sha *including reverted and deferred ones*; route insights to a durable home before the chat evaporates; and post decision-shaped residue to QUESTIONS.md or BLOCKERS.md — with the pattern-13 warning that BLOCKERS.md is not a work queue. Posture is explicitly **report/route/surface, do NOT build**, with one stated exception: pushing work the session already did isn't new work, it's the session not having landed yet.

**Also closed this pass:** realisateur's own `[checklist-drift]` NOTE — its `CLAUDE.md` was at 11 rows against the baseline's 12, missing the shared-host-footprint row. Fixed here per this command's "fix a FLAG against a project this run touches" rule. Note the ecosystem-wide 13-project drift is NOT touched — that's the cross-project sweep already awaiting a human answer in QUESTIONS.md. **The `~/Documents/Projects/realisateur` working checkout still reports the NOTE until it pulls** (it sits at `5dfbb6e`); that clone is the human's and was deliberately not written to.

**Surveys, all three re-run fresh, all unchanged from the ~22:1x pass:** `ecosystem-survey.sh` 18 projects, vision-debt ranking still topped by the four 2026-07-18 home-assistant entries; `milestone-audit.sh` 13 declared / 5 missing / 0 no-focus (0 reached); `hygiene-lint.sh` **31 FLAGs**, same composition (senechal's `base64` fixture, crt's exec-bit/silent-pipe set, the `[blockers-task]` finding at `BLOCKERS.md:129`, the 13-project `[checklist-drift]` NOTEs). Precipitation reports B and C read **READ-ONLY** per this command's rule: A still empty, B still topped by this repo's own session records scoring against each other, C's strongest cluster still the "unattended job fails quietly, nobody is told" shape across gardien/aedile/scheduler/senechal. **Nothing stamped, reordered, or reweighted.**

**NOT done (deliberate):** layer 3, the Stop hook — the design itself sequences it "only after both exist," and layer 2 does not yet exist *as a command*. Installing a Stop hook that runs a lint for a rite nobody can invoke would be wiring without a path. Also not done: adopting `focus-commit.sh` in the command files (still the human's open question from the ~22:1x pass) and the 13-project checklist restamp.

**Blockers:** one, and it is genuinely human-only — the `git mv` that installs layer 2, because the gate that blocks it exists precisely to keep unattended runs out of `.claude/`. Flagged in QUESTIONS.md. Nothing else in this pass needed a human, and nothing irreversible was done.

---

**2026-07-26 (`/nightly-batch`, ~22:1x pass): inbox empty for the FIFTH consecutive pass — so the queued write-race guard was BUILT: `bin/focus-commit.sh` + `bin/tests/focus-commit.test.sh` (`7e49b0e`). Realisateur's own half of the interface `UNIVERSE.md` names as unregulated.**

**Why this one:** the inbox again held no artifact, and the three `[batch]` hygiene-lint rows were consumed by the ~21:25 pass, so the bottom of this file no longer carries a `[batch]` tag. The next-strongest queued item that is explicitly *this repo's* and explicitly unattended-buildable is the write-race helper — the 2026-07-26 write-race entry below states it in those words ("realisateur's half — buildable unattended here", "**Blockers:** none"). It is also the most-evidenced item in the file: **four recorded occurrences**, the most recent one (~21:25, same night) resolved correctly only because a human-equivalent content-diff was done *by hand*. A guard whose absence has been paid for four times is not a speculative build.

**What it does that `git add && git commit -F && git push` does not** (it names that sequence as what it retires, per the discipline's own rule):
- **Commits exactly the named files.** A file already staged but not named is a loud abort, and so is a named file that stages nothing. This is the mechanical form of the CLAUDE.md subagent rule — the 2026-07-25 incident where 76 uncommitted lines in `sync-crontab.sh` sat in a tree and the next autocommit could adopt them under a human's name. Nothing rides along inside a FOCUS commit.
- **Handles the rejection itself.** On a rejected push: fetch → **print the incoming log+diffstat into the run's own output** (so the inspect-before-rebase step lands in the record rather than depending on someone remembering to look) → rebase → retry, up to `FOCUS_COMMIT_TRIES` rounds.
- **Verifies the rebase did not change what the commit MEANS.** The invariant: the set of files our unpushed commits touch *relative to upstream*, plus each of their blob hashes, must be byte-identical before and after the rebase. This is the mechanical form of the content-diff that caught the `archive/bibliothecaire.idea` rewrite by hand. On divergence it `reset --hard`s back to the pre-rebase commit, prints both manifests, and exits non-zero — **work preserved, nothing pushed, a human told.**

**Witness (`bin/tests/focus-commit.test.sh`, offline, zero AI, no network — 9 assertions, all passing):** it builds a throwaway bare remote plus two clones and drives a *real* concurrent writer through the script. Both directions, per the crt/wtul verification bar — it must do the right thing AND refuse the wrong one: happy path; no-op refused; unrelated staged file refused; race on a different file auto-resolves and pushes; race rewriting a file we never named still verifies clean; true same-file conflict aborts with our work intact; and **the 2026-07-26 incident shape reproduced directly** — upstream renames the file we edited, the rebase follows the rename and lands our edit on `RENAMED.md`, a path we never named, and the manifest check catches it (`79afb09 FOCUS.md` → `79afb09 RENAMED.md`), undoes the rebase, and pushes nothing.

**Two things caught during the build, both fixed rather than noted:**
- The first fixture run was **invalid and looked like a pass** — the working clone sat on `master` while the "races" happened on `main`, so tests 4–6 pushed to a different branch and never raced at all. Three green results that proved nothing. Same lesson as the stale-clone memory: a green test whose setup is wrong is worse than a red one.
- The script's own `git push … 2>/dev/null` was exactly the `2>/dev/null` failure BUILD-DISCIPLINE names — it made "permission denied" indistinguishable from "someone raced me." Push stderr is now captured and reprinted on every path that gives up.
- The suite was **negative-tested against a no-op stub** (`exit 0`): the four refusal assertions fail as they should, so the witness can actually fail.

**Surveys, all three re-run fresh, all unchanged from the ~21:25 pass:** `ecosystem-survey.sh` 18 projects, vision-debt ranking still topped by the four 2026-07-18 home-assistant entries; `milestone-audit.sh` 13 declared / 5 missing / 0 no-focus (0 reached); `hygiene-lint.sh` **31 FLAGs**, the same composition, including its own `[blockers-task]` finding at `BLOCKERS.md:129` and the 13-project `[checklist-drift]` NOTEs — both already flagged for the human in QUESTIONS.md, neither actioned here (restamping 13 CLAUDE.md files across 13 repos is a cross-project sweep, not a batch call). Precipitation reports B and C read **READ-ONLY** per this command's rule: A still empty, B still topped by realisateur's own session records scoring against each other, C's clusters unchanged. **Nothing stamped, reordered, or reweighted.**

**NOT done (deliberate):** the helper is built and tested but **not yet adopted** — no caller has been switched to it, including this repo's own command files. Adoption is a real behavior change to how every session writes FOCUS files and deserves a human's eye on the first live use; this pass dogfooded it once (the commit of this very entry) rather than rewriting `nightly-batch.md`/`ideate.md` to mandate it unprompted. Flagged in QUESTIONS.md.

**Blockers:** none. Nothing in this pass needed a human, and nothing irreversible was done.

---

**2026-07-26 (`/nightly-batch`, ~21:25 pass): inbox empty for the FOURTH consecutive pass — so the three queued `[batch]` hygiene-lint rows were BUILT instead of writing a fourth no-op report (`cc8a14e`, pushed).**

**Why build rather than report nothing:** the inbox held no artifact again (repo root is realisateur's own scaffolding only), but the bottom of this file carried three rows explicitly tagged `[batch]` — the tag that means "unattended-buildable here, by this pass." Three passes in a row had already found an empty inbox and stopped. An empty inbox is not an empty queue.

**What landed in `bin/hygiene-lint.sh` (all three rows, all offline, zero AI, nothing auto-fixed):**
- **`[checklist-drift]`** — each project's stamped `CLAUDE.md` checklist row count vs. `BUILD-DISCIPLINE.md`'s baseline block, read from that ONE source rather than retyped in the linter. Only a *shortfall* reports (a project may legitimately append its own rows). **Real finding, immediately: 13 of 18 projects lag** — most sit at 7 rows against the baseline's 12, and realisateur's own `CLAUDE.md` is at 11. The drift this row was queued to detect is larger than the incident that queued it.
- **`[stale-claim]` / `[unstamped-claim]`** — FLAG on a `verified <date>` stamp older than `STALE_DAYS` (default 7); NOTE on a `.conf` comment asserting live-system state with no stamp at all. Quiet at the default today (the real stamps are 1 day old) — which is why it was **negative-tested with `STALE_DAYS=0`**, where it correctly fires on the two dexter SSH probe claims in this file and the format example in `BUILD-DISCIPLINE.md`. That last one is a **documented, deliberate false-positive class** (the doctrine file's own prose defines the stamp format, so its example ages like a claim) — same stance as senechal's `base64` fixture; a documented recurring FLAG beats a special case that could later hide a real one.
- **`[blockers-task]`** — the mechanical half of BUILD-DISCIPLINE pattern 13. Ecosystem-scoped (one shared file), so it runs ONCE after the per-project loop, and it parses `BLOCKERS.md` into bullet *entries* rather than matching bare lines: an entry is flagged when its body is task-shaped **and** carries neither a `> ` answer nor a dispatch pointer (`OBLIGATION`/`dispatch`/`queued`/`routed`). Fixture-tested both directions (`BLOCKERS_MD` override): it catches the NOT-DONE entry and exempts both the answered one and the one naming an OBLIGATION.

**It finds exactly the incident it was queued for:** `BLOCKERS.md:129`, the 2026-07-24 wtul `.scheduler/` migration — the entry pattern 13 was named after. Worth a human's eye on the *rule* here: that entry did get a status note appended (`ba1757a`), but the OBLIGATION line went under `## realisateur`, a different section, so the entry itself still has no dispatch pointer. Under the rule as written that is a true positive; if the intent was "a pointer anywhere in the file counts," the check needs widening. Flagged in QUESTIONS.md, not decided here.

**Live write-race, FOURTH recorded occurrence — and the first that was benign:** the push was rejected mid-flight by `e73f933` (`BUILD-DISCIPLINE 13b + hygiene-lint [dispatch-parity]`, authored as *Zach*, committed 23 seconds before mine), a concurrent writer adding a *different* check to the *same file*. Handled per the standing rule rather than by trusting the tool: fetch → inspect the incoming diff → rebase → **content-verified that both check sets survived** (`dispatch-parity` and all four new markers present, `bash -n` clean, full re-run at 31 FLAGs) before pushing. No conflict, nothing lost. This is the interface `UNIVERSE.md` names as unregulated, hit again — and it is the concrete argument for the already-queued `bin/focus-commit.sh` (this file's 2026-07-26 write-race entry), which would have done the fetch→content-diff→rebase→verify sequence mechanically instead of by hand.

**Surveys, all three re-run fresh:** `ecosystem-survey.sh` 18 projects, vision-debt ranking unchanged (still topped by the four 2026-07-18 home-assistant entries); `milestone-audit.sh` unchanged at 13 declared / 5 missing / 0 no-focus (0 reached); `hygiene-lint.sh` 30 FLAGs before this work → **31 after**, the one addition being the real `[blockers-task]` finding above (plus the new NOTE classes, which don't count). Precipitation reports B and C read as READ-ONLY per this command's own rule: report A still empty (no entry stamped yet), B's top candidates are all realisateur's own session records scoring against each other, and C's strongest cluster is the same gardien/aedile/senechal/scheduler "unattended job fails quietly, nobody is told" shape — **noted for the next `/ideate` to judge, deliberately NOT stamped, promoted, or reweighted here.**

**Blockers:** none. Nothing in this pass needed a human, and nothing irreversible was done.

---

**2026-07-26 (interactive, Zach-directed, `/ideate` promotion-signal session): queue policy FORMALIZED and the re-arrival sensor BUILT — `PRECIPITATION.md` + `bin/precipitation-scan.sh`, wired into `ecosystem-survey.sh`. Closes UNIVERSE.md's "queued, not built" re-arrival gap; landed larger than queued (clusters too).**

**What Zach asked:** formalize re-ordering of vision from UNIVERSE.md's strategies — specifically "if a request hits an inbox multiple times, how can it get boosted up?" and "is there a way to score adjacent features to see that there's a cluster emerging?" Both answered, and the first one answered with a **correction to the naive form**.

**The doctrine (`PRECIPITATION.md`, new sibling to UNIVERSE/STABILITY-MILESTONES/BUILD-DISCIPLINE — those answer what/when/done, this answers "why this one, now"):** five ranked signals, age demoted to WEAKEST of five. (1) re-arrival in the same shape, (2) interface cluster, (3) active-set unblock, (4) milestone-gate, (5) age. Two calls worth flagging:
- **Raw frequency does NOT boost.** Repetition × *shape stability* is the signal. Same shape → promote (strongest signal in the ecosystem). **Different shape each time → LOWER the weight** — that's the still-forming dream of §4.6, and a naive "boost on repeat" rule would invert the doctrine on exactly the ideas it matters most for. Frequency there measures agitation, not readiness. The counter-signal (shape drift) is named explicitly so it can't be quietly skipped; without it "re-arrival" degenerates into newest-first wearing a lab coat.
- **A cluster's output is a NEW ENTRY, not a reordering.** Distinct asks converging on one interface = Ashby: disturbance variety exceeds regulator variety there. Do not promote the N members; name the missing regulator they're leaking around and mark them `subsumed by [[x]]`. Mechanizes how the multi-writer FOCUS-file regulator was found by hand (three friction incidents, one unnamed cause) — before three incidents accumulate.
- **Deliberately NOT a composite score.** A computed reordering is precisely the silent reorder §4.5 forbids, and it would move weight-setting from the human to a formula. Signals are ranked, each authorizes a *stated* action. Scheduler enforces weights and never sets them; realisateur senses and never decides.

**The mechanism (`bin/precipitation-scan.sh`, offline-first, zero AI, writes nothing):** three reports — A stamp ledger (confirmed `(re-arrival: <dates>)` / `[iface: <x>]` marks, fact, no inference), B same-project re-arrival candidates, C cross-project interface clusters. Scores only **human-origin** entries by default (inbox `via scheduler -i` + human-directed); the machine's own pass journal repeats by construction and filled report B with the system detecting its own heartbeat. **Stamping is the design's core:** B/C are noisy inference, and the fix is accretion, not a better algorithm — a confirmed candidate gets written into the file and read back by A as fact, so precision accumulates on the entries that mattered while intake stays free (Law 1).

**Three real failure modes hit and fixed during the build, each documented in-script so they aren't re-introduced:** transitive union-find collapsed 205/211 entries into one "cluster" (A~B, B~C ≠ A~C — replaced with stars around a seed); `shared/min(|A|,|B|)` scored 5-term stubs 0.8 against any long entry (→ Jaccard); long omnibus session records join every cluster to every other (→ HUBFRAC hub exclusion, excluded list printed not silently dropped). Report A's stamp path verified against a scratch fixture via the new `FOCUS_DIR` override — which caught a real bug: the "no stamps yet" note printed *despite* stamps existing, because the counter was incremented inside a pipeline subshell.

**Known limits are stated in the doc, not hidden:** vocabulary overlap is a crude proxy for aboutness; hub-excluded entries can hide a real signal until filed separately; large diffuse clusters report as several overlapping stars; and the tool **cannot judge shape stability** — the one thing signal 1 turns on. That judgment stays human by design; the tool's job is to put the pair side by side with shared terms so the call takes a glance.

**NOT done (open):** no entry has been stamped yet — report A is empty against the real corpus, so the ledger stays theoretical until the next `/ideate` confirms candidates from B/C. The current scan does surface one plausible real cluster (`freely appended suggestions inject delete dated context` across chezz/vim-arcade/vkv-inventory/wtul/nine-speakers) that looks like the multi-writer FOCUS-file interface again — left UNJUDGED here rather than promoted on the strength of the tool that just proposed it.

**2026-07-26 (`/nightly-batch`, ~19:42 pass): inbox empty, surveys re-run, nothing to build.**

Repo root again held only realisateur's own scaffolding -- no dropped
artifact to infer or wire up. All three offline surveys re-run fresh,
unchanged from the ~19:40 pass two minutes prior: `hygiene-lint.sh` still
30 total FLAGs across 18 projects (same senechal `base64` test-fixture
false positive); `milestone-audit.sh` unchanged at 13 declared/5 missing/0
no-focus; `ecosystem-survey.sh`'s vision-debt ranking unchanged, still
topped by the four 2026-07-18 home-assistant entries. `.scheduler/QUESTIONS.md`'s
open blocks (aedile/vkv-inventory svc-vaporwave recovery, ideate-mode
`UserPromptSubmit` hook, secretaire lane) all still carry only the
placeholder `> (answer inline here)` slot -- no real `> ` reply landed,
left untouched, genuinely waiting on the human.

---

**2026-07-26 (`/nightly-batch`, ~19:40 pass): inbox empty, nothing to build.**

Repo root held only realisateur's own scaffolding (`fable-like/` + doctrine
files) -- no dropped artifact to infer or wire up. All three offline
surveys re-run fresh, no findings changing this pass's scope:
`hygiene-lint.sh` still 30 total FLAGs across 18 projects, same senechal
`base64` test-fixture false positive as the last recorded composition;
`milestone-audit.sh` unchanged at 13 declared/5 missing/0 no-focus
(sequestria, vim-arcade, vkv-inventory, + 2 others still missing --
milestone-setting candidates, not this run's project);
`ecosystem-survey.sh`'s vision-debt ranking unchanged, still topped by
the four 2026-07-18 home-assistant entries. `.scheduler/QUESTIONS.md`'s
open blocks (aedile/vkv-inventory svc-vaporwave recovery, ideate-mode
`UserPromptSubmit` hook, secretaire lane) all still carry only the
placeholder `> (answer inline here)` slot -- no real `> ` reply landed,
left untouched, genuinely waiting on the human.

---

**2026-07-26 (`/nightly-batch`, ~15:30 pass): the librarian drop executed end-to-end — quatre-vingt-douze rename (step 0) + bibliothecaire scaffolded/registered; plus a real feedback-pipeline bug found at dispatch and fixed in scheduler.**

**The dispatch-time bug first (acted on before the batch, per the wrapper's own act-on-feedback-FIRST rule):** this run was handed five "REPLY" blocks from BLOCKERS.md `## realisateur` — all EMPTY. Root cause verified in scheduler's working diff: `collect-feedback.sh --consume` treated the five bare `>` answer slots under the strategy-audit questions as replies (its guard only knew the `> (answer inline here)` placeholder form), emitted five empty REPLY blocks, and deleted the slots from the file. **Nothing was treated as approved — all five strategy-audit calls still await Zach.** Fixed: bare `>` not continuing a reply is now kept as an un-answered slot (scheduler `bb5c762`, regression-tested both directions: restored realisateur section → exit 1/file unchanged; synthetic real reply with interior blank `>` → collected as one block, sibling slot preserved); slots restored from HEAD; dated machine-append note under the entry (`5731804`). Both pushed to scheduler `main` (revert: `git revert 5731804 bb5c762`).

**The batch itself — one inbox artifact, the rewritten `bibliothecaire.idea`, executed exactly per its own sequencing:**
- **Step 0, rename:** page-92 project → **quatre-vingt-douze**: project dir + bare remote moved, clone origin repointed, every in-repo self-reference updated (README keeps Zach's verbatim drop quote as origin record), collision question in its QUESTIONS.md folded as answered (its commit `cd70522`, pushed); scheduler side: conf renamed with all fields, `_paced.conf` line disabled during → renamed → re-enabled (weight unchanged 1), loop wrapper now `quatre-vingt-douze-nightly-batch-loop.sh` (`9c8f335`, pushed). Verified: `milestone-audit.sh` resolves quatre-vingt-douze with its declared milestone; no crontab line ever named the old job; no state dir existed to migrate; `~/reports/` had nothing under the old name.
- **Scaffold, under the freed name:** `~/Documents/Projects/bibliothecaire` (own repo `332637b` → new bare remote `~/git-remotes/bibliothecaire.git`, HEAD=main). Contents per the drop: consumer contract (crt reads `quotes/quotes.txt`/`quotes.json`, never imports code), **honesty policy as a hard rule** (a quote is data; `verified` only after checking the primary text — the 6-quote seed set covering all named themes ships honestly ALL `seed-unverified`, so the crt-facing export is empty until the first real verification pass), `bin/validate-quotes.py` fails-loud validator (negative-tested live), `SOURCES.md` mapping each theme to its primary literature, `.scheduler/` files from day one, CLAUDE.md with the build-discipline baseline. Registered: `schedule/bibliothecaire.conf` (SCHEDULER_SUBDIR, BATCH_TEST_CMD=validator, AUTONOMY_TIER high), `_paced.conf` enabled at LOW weight 1 per the drop's stated pacing call, sync-crontab applied, `hygiene-lint.sh bibliothecaire` clean, `scheduler status bibliothecaire` reads everything through the regenerated symlinks (`60bc63c`, pushed). Its first milestone: every wing-(a) theme ≥2 primary-source-verified quotes, export published. Wing (b) (crt catalog) and doctrine integration parked in its own FOCUS.md.
- **Housekeeping:** drop archived as `archive/bibliothecaire-librarian.idea` (page-92's `archive/bibliothecaire.idea` untouched, per the drop); the prior pass's three-projects informational flag closed in QUESTIONS.md (explicitly closable-once-read); surveys re-run fresh (milestone-audit 12 declared → 13 with bibliothecaire / 5 missing; hygiene-lint 30 FLAGs ecosystem-wide, none in tonight's touched projects; vision-debt ranking unchanged, still topped by the 2026-07-18 home-assistant entries). No other artifacts in the inbox. QUESTIONS.md's remaining blocks (svc-vaporwave recovery, UserPromptSubmit hook, secretaire lane) all still unanswered — left untouched.

---

**2026-07-26 (interactive, Zach-directed, `/ideate` follow-up to the unattended-execution report): the `.claude/`→`.scheduler/` FOCUS-file question — traced to a FAILED DECISION PROPAGATION, realisateur MIGRATED this session (named inline exception, Zach's explicit call), ecosystem pass QUEUED, lesson mechanized.**

**The trace (what Zach asked: "we established using .scheduler — what failed?"):** the decision DID exist. 2026-07-24 ~21:22, scheduler BLOCKERS.md `## wtul` (`ffab7d9`, revising `de62b82` from 20 minutes earlier): migrate off the gated `.claude/` paths onto `.scheduler/`, "same design as every other project long-term, per Zach's explicit preference" — scope fully scouted, then *"filed for an async pass, not completed live."* It was filed into BLOCKERS.md — by standing rule NOT a work queue — under a section no other project's runs read. Consequences, all verified live this session: the wtul migration never executed (no `~/Documents/wtul/.scheduler/`, no `SCHEDULER_SUBDIR` in `wtul.conf`); the "every project" clause reached no template (scheduler `examples/*` and this repo's `SCHEDULER.md` still taught `.claude/`); chezz hit the wall independently and self-migrated (its own mv 2026-07-24, conf caught up in `c00f079`); realisateur's three 2026-07-26 nightlies hit it again, adapted well locally (new projects scaffolded on `.scheduler/` from day one, no gate retries, no self-authorized contract change) but dead-ended their own vision/triage records in `~/reports/` and re-queued the already-made decision as an open question. Not a harness change and not agent disobedience — **a decision recorded where nothing dispatches from is indistinguishable from no decision.** Now BUILD-DISCIPLINE **failure pattern 13** ("a decision without a dispatch path" — pattern 2 for decisions). Deliberately NOT added as a stamped-checklist row (that would re-trigger the stamped-drift debt, see the 2026-07-25 note below); the guards are pattern 13 + SCHEDULER.md/templates teaching the right layout + the queued lint row.

**Zach's three calls this session (asked directly): scope = ALL remaining projects; realisateur's own migration = inline NOW (it structurally cannot run unattended — the gate blocks the very `.claude/` command-file edits the migration consists of); lesson = discipline row + BLOCKERS sweep + a queued mechanical lint.**

**Done this session (realisateur = the pass's template, all consumers verified where they read):**
- `git mv .claude/{FOCUS,QUESTIONS}.md → .scheduler/` + every own-path reference in `nightly-batch.md`/`ideate.md`/`SCHEDULER.md`/`README.md`/`UNIVERSE.md`/`STABILITY-MILESTONES.md`/`FOCUS-FORMAT.md`/`IDEATE-WORKFLOW-REVISION.md` (`fa222cb`); records+consumer-fix commit (this entry's own commit).
- scheduler side: `realisateur.conf` `SCHEDULER_SUBDIR=".scheduler"` + `sync-crontab.sh --apply` (`1284b58`); `focus/realisateur.md` + `questions/realisateur.md` symlinks verified re-pointed; zach crontab verified byte-identical; `milestone-audit.sh` and `scheduler status` both re-probed reading the new location.
- Consumer sweep (the chezz-wrapper lesson from senechal's 2026-07-25 ledger, checked not assumed): `~/.local/bin/realisateur-nightly-batch-loop.sh` is a thin generic exec, needed nothing; two REAL stale consumers found and fixed here — `bin/incubation-audit.sh` (now tries `.scheduler/` then legacy `.claude/`) and `fable-like/inject-suggestions.sh`'s realisateur map line.
- The 2026-07-26 nightlies' PENDING flags folded into `.scheduler/QUESTIONS.md` (three-projects flag closable; secretaire enable question carries the reply slot; the bibliothecaire-collision half was already resolved by this morning's merge/rename decision).
- BLOCKERS.md sweep (append-only, nothing pruned): exactly one task-shaped entry found (the wtul migration itself); status note appended under `## wtul` + a human-present OBLIGATION line under `## realisateur`, both in `ba1757a`.
- Templates routed via the front door per §5 (`scheduler -i scheduler`, commit `c1f9e7b`): examples/* + scheduler README teach `.scheduler/` + `SCHEDULER_SUBDIR`.
- senechal footprint note cross-written per standing policy (senechal `c34dfaa`; push raced its nightly, rebased with content-diff verification per the 2026-07-26 race entry below).

**Milestone chain (the migration pass):**
1. *(done, this session)* realisateur migrated end-to-end — the recipe other projects copy: mv + own-doc paths + conf `SCHEDULER_SUBDIR` + sync-crontab regen + consumer sweep (`~/.local/bin` wrapper, `bin/` scripts, anything mapping project→FOCUS-path).
2. *(next — HUMAN-PRESENT BY CONSTRUCTION, queued, dispatch line in scheduler BLOCKERS.md `## realisateur`)* the remaining 10, one or a few per interactive session, wtul FIRST (its scouted scope in BLOCKERS `## wtul` is still accurate, incl. ~8 hardcoded paths in `wtul-batch.md` and its FOCUS/QUESTIONS self-references): crt, gardien, senechal, home-assistant, groc-mangr, nine-speakers, sequestria, vim-arcade, vkv-inventory after it. Each migration must run the consumer sweep — the chezz precedent shows the untracked `~/.local/bin` wrappers are where this silently breaks.
3. *(queued via front door, scheduler's own sequencing)* templates fix (`c1f9e7b`) so no future scaffold teaches the gated layout.
4. *(queued, `[batch]` row at the bottom of this file)* hygiene-lint: task-shaped-language-in-BLOCKERS.md row — the mechanical half of pattern 13.

**Park-by-default / §4.5 override, stated:** this jumps ahead of every older parked item because it unblocks the recording half of the loop the CURRENT milestone measures — nightlies literally could not write triage records to the file this repo's whole contract runs on — and because three projects hit the same wall independently inside 48 hours (the convergence signal, same as the front-door promotion below). No weight change: realisateur is already at 3 with a stated exit.

**Blockers:** none for steps 3–4 (queued in their owners' own dispatch paths). Step 2 is blocked only on a human being present — that's its nature, not a missing decision; the dispatch line exists so it can't rot silently the way the 2026-07-24 original did. wtul's FOCUS-note cross-write was DEFERRED this session per ideate.md §4 (its batch was live-dispatched 13:05 mid-session, `check-project-busy.sh` said BUSY) — carry it into the wtul migration itself.

**Postscript, same session — THIRD live occurrence of the watcher misattribution:** the ~13:15 sweep tick adopted this very session's in-progress `QUESTIONS.md` and `BUILD-DISCIPLINE.md` edits as `Human edit via scheduler` under Zach's name (`47892d0`, `62507d2` — content verified intact and exactly as authored, attribution published and unrecoverable, same as `93ad456`). Adds a same-day second data point to the write-race entry below; the scheduler-half fix (honest attribution + live-session probe) is already routed via `scheduler -i` there — this recurrence is evidence for its priority, not a new decision.

---

**2026-07-26 (interactive, Zach-directed, same session as the strategy audit below): `/cloture` — the session-closing rite — DESIGNED AND QUEUED, not built. Name chosen by Zach (asked directly, with options); build scope "record and queue only" also his explicit call.** Stated park-by-default override: not required for realisateur's current milestone, promoted by the decider himself.

**What it is:** the closing counterpart to `/ideate`'s opening posture — a general rhythm after big jobs: philosophy delta named, cross-project writes reported, insights made durable, decisions surfaced "clear to clear." Three layers, offline-first split (deterministic half before any AI, per `docs/offline-first-checks.md`):
1. **`bin/closeout-lint.sh`** (zero AI, exit 0, signals-not-verdicts): REUSE `hygiene-lint.sh`'s dirty-tree/stranded-commit checks, adding only: (a) any registered repo touched in the last N hours with unpushed commits; (b) today's dated FOCUS entry exists here and contains commit shas (mechanizes the confirm-durable-records rule); (c) if the session filed decisions, scheduler's `BLOCKERS.md` carries a block dated today.
2. **`.claude/commands/cloture.md`** (the judgment half, interactive like `/ideate`): run the lint, then — doctrine file updated or explicitly "none"; every cross-write listed with repo+sha; insights routed to doctrine or memory, never left in chat; decision-shaped residue posted to `BLOCKERS.md` under the filing project's `##` section as `> `-answerable one-liners (worked example: the 2026-07-26 five-item block, scheduler `86a49a7`).
3. **Stop hook** (the off-API enforcer, Play 1 applied to this rite): warn-only, realisateur project settings first, NOT user-level until proven; runs layer 1 at session end so the check survives prose decay.

**Admission test (Play 6), passed:** reuses hygiene-lint/BLOCKERS-append/slash-command patterns; bounded (three small files); names what it retires — the ad-hoc prose session summary as the SOLE reporting channel. **Blockers:** none — unattended-buildable here; layers 1+2 first, layer 3 only after both exist.

---

**2026-07-26 (interactive, Zach-directed): ecosystem STRATEGY audit — duplication/import/meta-ratio — PLAYBOOK.md written, milestone-declaration jobs QUEUED in five projects, gardien milestone line repaired. Audit by three read-only agents; all writes by this session, committed per-repo.**

**The deliverable:** **`PLAYBOOK.md`** (new, repo root — sibling to UNIVERSE.md/STABILITY-MILESTONES.md/BUILD-DISCIPLINE.md; governs *allocation* of code effort). Six plays, each with its mechanism: (1) mechanize BUILD-DISCIPLINE's six hook-shaped rules as real Claude Code hooks — the audit found ZERO hooks configured anywhere while every recorded discipline incident was an agent not following prose; (2) import the commodity layer (symlinks over `pacing deploy` copy-drift — `usage-paced-runner.sh`, the file cron runs every 5 minutes, was found drifted LIVE; ccusage over `token-usage.sh`; gitleaks inside hygiene-lint's harness; restic/rsnapshot under `gardien.py` when it unparks) while never churning the three audited-as-original pieces (`usage-gate.sh`, the `%%TAG`/`> ` convention, the offline-first surveys); (3) catabolize ~1,000 lines already self-labeled superseded (morning-report, build-services-view, incubation-audit.sh here, overnight-dev ×2, the two 162-line loop forks, sync-crontab's dead auto-stagger) — the queued catabolic pass's first worklist; (4) forward `_paced.conf` allocation ran 64% meta while backward commits ran ~43% — the queued milestone jobs are the parked making-projects' re-admission gates, no new code needed; (5) the top leverage builds: crt potato live-verification, a ranked cross-project answer-session surface (the only play acting directly on the rate-limiting enzyme), aedile's auto-merge gate, a shared Apps Script library (chezz/aedile/vkv-inventory hand-copy today), a SessionStart hook for `collect-feedback.sh`; (6) a standing admission test for new meta-tooling.

**Cross-writes, all committed+pushed in their own repos (tagged in each commit):** milestone-declaration jobs queued as dated `(realisateur)` FOCUS entries in **groc-mangr** (`c6a9d6d`), **nine-speakers** (`e9f6712`), **sequestria** (`4bc1b2f`), **vim-arcade** (`ec35b37`), **vkv-inventory** (`a1c8249`, on `drilldown-browse-redesign` where its FOCUS lives; entry itself warns its `enabled=0` is deliberate anti-double-dispatch, not a flag to flip). Each entry carries grounded candidate bars from a per-project read plus per-project traps (nine-speakers' stale near-term list, sequestria's self-documentation loop, vim-arcade's already-shipped 14 levels + the `d7c0e90` tmux prototype, vkv's `--consume` dead-letter gap). **gardien**: not a milestone job — its milestone was fine; the audit's UNRECOGNIZED verdict was one token (`**Current (on hold…):**` hid the literal `**Current:**` from the grep). Repaired in place, `9bc6da7`, after a fetch-rebase whose content was diff-verified per the race entry below.

**chezz: NO job queued — milestone-audit's MISSING verdict was a stale clone, not a gap.** The working checkout sat at 2026-07-25; a fetch showed chezz's own nightly declared a real `## Stability milestone` ("Autopilot loop stable", in-progress) in `.scheduler/FOCUS.md` since. Same lesson as the standing stale-clone memory: diff content before reacting to an audit verdict rendered from an unfetched checkout. Consequence for this repo's own milestone checklist: of the "remaining 7," chezz is now DECLARED by its own hand; the five queued above + aedile (declared 2026-07-24) leave the checkbox closeable once the queued jobs land.

**Blockers:** none human-only for the queued jobs (each is unattended-buildable in its own project's next pass). PLAYBOOK Play 5's items are queued where their owners already track them, not re-routed here.

---

**2026-07-26 (interactive, Zach-directed, same `/ideate` session as the bibliothecaire entry below): the FOCUS-file write race — incident recorded, clean-handling job QUEUED, not built.**

**The incident (mechanics also in the bibliothecaire entry's status-correction paragraph):** during this live interactive session, (1) `origin/main` moved twice underneath the session — first the nightly's archive push, then the watcher's own push — rejecting two pushes mid-flight; (2) a scheduler-side sweep (~10:30 tick) found the session's *uncommitted* `.claude/FOCUS.md` edits and committed them as `Human edit via scheduler` — under **Zach's name** in realisateur (`93ad456`, published, cannot be reattributed) and as `hf7y` on crt's stale mandark checkout (reset and recommitted cleanly as `81fc98f`); (3) the rebase across the nightly's archive-rename silently rewrote `archive/bibliothecaire.idea` with unrelated new content via rename-following auto-resolution — caught only by a content diff, restored in `2120677`. This is the **second live exhibit** of the interface `UNIVERSE.md` already names as unregulated (multi-writer FOCUS/QUESTIONS files); the first was the 2026-07-25 mega-burn merge conflict. Per the Ashby reading: the regulator is missing, nobody slipped.

**Queued (Zach's explicit direction this session; stated park-by-default override — not required for realisateur's current milestone, promoted by the decider himself):** clean handling for the next occurrence, split by ownership:
- **scheduler's half — routed via `scheduler -i scheduler` this session per ideate.md §5, not hand-edited:** the watcher should (a) attribute honestly — an adopted working-tree edit is `autocommit-watcher`, never `Human edit`/a human's name, or alternatively refuse to adopt `.claude/`-gated files at all; (b) probe for a live interactive session before committing/pushing from a working tree it doesn't own (flock probe, the same shape as realisateur's `bin/check-project-busy.sh`, pointed the other direction).
- **realisateur's half — buildable unattended here:** make the session discipline mechanical instead of prose (prose decays; this file's own doctrine): a small `bin/focus-commit.sh <repo> <msgfile> <files...>` that stages, commits, and pushes a FOCUS/QUESTIONS edit as ONE atomic step, and on a rejected push does the fetch→content-diff→rebase itself, then **verifies post-rebase that no renamed/archived file's content changed relative to both parents** (the check that would have caught the `archive/bibliothecaire.idea` rewrite mechanically). Session memory already carries the edit→commit→push-atomically rule, but memory is per-assistant prose — the helper is the enforcement, and it names what it retires: the bare `git commit -F` + `git push` sequence for FOCUS-file writes in this repo's own sessions. **DONE 2026-07-26 (`/nightly-batch`, `7e49b0e`)** — built + witnessed (`bin/tests/focus-commit.test.sh`, 9 assertions incl. the rename-follow incident shape); see this file's ~22:1x entry. **Adoption is NOT done** — no caller switched to it yet, flagged in QUESTIONS.md.

**Blockers:** none — both halves are buildable now; scheduler sequences its own half against its current milestone.

---

**2026-07-26 (interactive, Zach-directed, `/ideate` bibliothecaire session): the librarian's vision recorded, three-way name collision resolved by MERGE, scaffold queued for nightly-batch at low weight. RECORDED AND QUEUED, no feature code.**

**Vision (decided by Zach this session, four explicit calls via AskUserQuestion):** **bibliothecaire** is the ecosystem's librarian — its own scheduler-registered project (new repo, not a realisateur subdirectory, not inside crt), with two wings: **(a)** an operations/cybernetics knowledge base seeded from `UNIVERSE.md` — closed loops, stigmergy, theories of the firm, holons; sourced quotes with real attribution from the primary literature (Ashby *An Introduction to Cybernetics*, Beer/VSM, Grassé on stigmergy, Coase, Koestler on holons — UNIVERSE.md already cites Ashby/VSM/Laozi; the other three themes are new research directions), intended to become a core philosophical resource for realisateur; **(b)** crt's book-catalog knowledge (contents/relationships/citations/further-reading) — the catalog-split idea parked in crt's `.claude/FOCUS.md` 2026-07-24, now MERGED into this project rather than staying a crt-internal fork. Consumers (crt first, realisateur later) read a published quotes/data file; they never import bibliothecaire code. **Explicitly NOT decided:** repo location/remote name, the quotes-file format and its contract with crt, how the catalog wing relates to crt's `books.db`, and whether/when realisateur's doctrine files cite back into the KB.

**Name collision, resolved (this was three-way as of this session):** (1) the "page 92" inbox drop, (2) crt's parked catalog split, (3) this new KB vision all claimed "bibliothecaire." Zach's call: the merged librarian project (2+3) owns the name; the page-92 idea becomes **quatre-vingt-douze** (the rename candidate `fable-like/projects/bibliothecaire/README.md` already proposed). This is exactly the incident the queued NAMES.md item (fable-review, 2026-07-25, bottom of this file) exists to prevent — third arrival of the same noun makes that item's case for it.

**Status correction, same session (the survey's own point — don't trust a stale mental model):** while this session deliberated, the 2026-07-26 nightly (first pass, ~00:xx) had already consumed the old page-92 `bibliothecaire.idea` and **scaffolded it as a live registered project under the contested name** (repo at `~/Documents/Projects/bibliothecaire`, `schedule/bibliothecaire.conf`, enabled at weight 1, bare remote, loop script) — flagging the collision itself in its conf and its own `.scheduler/QUESTIONS.md` ("a rename pass is cheap now, expensive later") rather than resolving it. So the rename is no longer a `git mv` of a drop; it's a rename of a live registration. **Asked directly (queue it or do it now); Zach chose: queue it in the librarian drop.** The rewritten `bibliothecaire.idea` now carries STEP 0: the next realisateur nightly renames the page-92 registration to quatre-vingt-douze (dir, bare remote, conf, `_paced.conf` line, loop script — disable during, re-enable after, weight unchanged; no crontab lines exist for it, only the generic paced runner) and folds the collision question in that project's own QUESTIONS.md, then — only after that verifies clean — scaffolds the librarian under the freed name. The first push of this entry was also rejected (`fetch first`) by that same nightly's push; rebased, and the rebase's rename-following auto-resolution (it rewrote `archive/bibliothecaire.idea` with librarian content and left a root `quatre-vingt-douze.idea` the next nightly would have re-scaffolded as a duplicate) was caught and reverted by hand before this push — the archived drop stays page-92's consumed record, untouched.

**Milestone chain, working backward from the vision:**
1. *(current — queued for nightly-batch via the new `bibliothecaire.idea` drop, register at LOW `_paced.conf` weight)* scaffold the project + first research pass: sourced quotes on the four themes from the primary literature, published as a consumable quotes file. Low weight is Zach's stated pacing call per §4.6 AND `UNIVERSE.md`'s own convergence test — three arrivals in three different shapes means the vision is still dissolving; the first case is concrete, the whole is not.
2. *(next)* crt consumes the quotes file through its **existing** idle-bait quote rotation (`pick_idle_quote`/`FALLBACK_QUOTES` in `crt/bin/crt-book-game.py`) — cross-written into crt's FOCUS.md this session as an offline-safe `[batch]` item tagged `(waiting: bibliothecaire quotes file)`. Chosen over a dedicated splash app deliberately: no new tmux window/surface (Law 3 clean), and it feeds the offline-safe lane crt's own QUESTIONS.md said was exhausted.
3. *(later, undecided)* fold in the catalog wing — the "split scope-only, greenfield, shares at most `books.db` data, never forks crt's scan/grade/STT code" variant crt's parked entry preserved as an option.
4. *(explicitly not queued)* deeper doctrine integration (UNIVERSE.md citing into the KB, quotes surfacing anywhere beyond crt's book channel).

**Blockers:** none human-only for step 1 — the scaffold + research pass is unattended-buildable once the drop reaches the nightly clone (pushed this session). Step 2 waits on step 1's quotes file, nothing else.

---

**2026-07-25 (interactive, Zach-directed, `/ideate` scheduler front-door session): three-view front door promoted to scheduler's NEXT milestone, ecosystem doctrine written (`UNIVERSE.md`), weights raised with a stated exit. RECORDED AND QUEUED, no feature code.**

**Vision:** `bin/scheduler`'s entire human surface becomes three stable, printable views mapped to the organism's three timescales — `scheduler` noargs (operations: now/next + a one-line gate/dials footer), `scheduler blockers` (obligation: the one blocked-on-you place), `scheduler <project>` (identity: detail, inline reply, reorder/reweight from there) — each view's footer printing its own mutation one-liners. Decided by Zach this session (four explicit calls): **hard fold + retire** (the ~20-verb surface collapses; superseded views become one-line redirect stubs; `usage()` ≤ ~20 lines), **static + verbs, no TUI** (printable doctrine from 2026-07-20 holds; tweaks are pasteable one-liners, not arrow keys), **dials = one-line noargs footer** (full pacing/drift/deploy detail stays under `pacing`). NOT decided: the redesign's internal implementation order, and whether `scheduler <project>` also absorbs the item-0 merged report+questions file in the same milestone or a later one — scheduler's own design call.

**Parking override, stated per §4.5:** this promotes scheduler FOCUS.md item 0 (parked 2026-07-20 under the hardening-first SEQUENCING decision) ahead of nothing older — it IS the oldest parked scheduler design — but it does jump the queue relative to the standing "only after 1-2 are genuinely solid" gate, before the current milestone's last checkbox closes. Justification: **re-derivation convergence** — Zach independently re-derived the 2026-07-20 target UX near line-for-line on 2026-07-25, the strongest crystallization signal this ecosystem produces. The principle itself (plus the anatomy, three laws, three-timescale channel rule, and the Daoist/cybernetic reading of the moving target) is now durable doctrine in **`UNIVERSE.md`** at this repo's root — written this session per Zach's "plan this from a universe perspective."

**Milestone chain:**
1. *(current, scheduler's, in-progress — unchanged)* scheduler's zero-silent-failure bar, 4/5 checked; last box (vkv-inventory `--consume` gap) is routed to realisateur and is now weight-supported work.
2. *(next, filed this session via `scheduler -i scheduler`, adopt when 1 closes)* the three-view front-door consolidation above, with an **accretion freeze effective immediately**: no view gains a legend line or new verb before the redesign; new needs go into the spec.
3. *(later, undecided)* whether the merged report+questions file (item 0's other half) and the printable-document refinement ride the same milestone.
4. *(explicitly not queued)* any TUI.

**Weights (realisateur's knob, edited directly in scheduler's `schedule/_paced.conf` this session):** scheduler 3→4 (it builds the redesign), realisateur 1→3 (owns the doctrine, the convergence-test triage change, and milestone-1's last checkbox). **Exit condition, stated in the file so it can't become permanent skim: both drop back (4→3, 3→1) when the front-door milestone is reached.**

**Queued, not built (two new mechanisms, shapes open — `UNIVERSE.md` names both as its own gaps):**
- **Re-arrival sensor** — on intake/triage, check the reservoir for a prior same-shape entry; a convergence hit is a stated promotion trigger stronger than oldest-first. Candidate: an offline `bin/` sense like the existing surveys.
- **Catabolic pass** — recurring retirement discipline (e.g. every Nth `/ideate` names one surface to shrink), generalizing BUILD-DISCIPLINE's "names what it retires" from mechanisms to text/verbs.

**Blockers:** none human-only for the recording itself. The redesign build is scheduler's paced work under the new weights; nothing here needs Zach before scheduler's next cycles pick it up.

---

**2026-07-25 (interactive, Zach-directed, `/ideate` abletim session): mandark→dexter SSH channel — verified live, licensed NARROWLY, provisioning QUEUED not built.** Context: developing the `abletim.idea` drop (Ableton + its media live on dexter; the project is a clean `_paced.dexter.conf` hardware-evidenced pin, second after crt). Zach asked whether realisateur's nightly can write into dexter. Probed rather than assumed:

- Batch-mode SSH from mandark works unattended TODAY: mandark's `~/.ssh/config` already carries a `Host dexter` block (dexter.local, user zach), key auth succeeds with no prompt, and the session lands in **Windows PowerShell** (Windows OpenSSH server), not WSL. `# verified 2026-07-25 via ssh -o BatchMode=yes dexter 'echo OK: $(hostname)'`
- From that shell, `wsl -d Ubuntu -u zach` reaches dexter's real scheduler environment (`/home/zach/scheduler/bin` listed) and the Windows media filesystem (`/mnt/c/Users/Zach/` visible). Note: the WSL **default** distro is `docker-desktop`, so a bare `wsl -e` lands in the wrong distro as root — the `-d Ubuntu -u zach` flags are load-bearing. `# verified 2026-07-25 via ssh dexter "wsl -d Ubuntu -u zach -e sh -c 'ls /home/zach/scheduler/bin; ls -d /mnt/c/Users/*/'"`
- Probe side effects, disclosed per the subagent/footprint rules: this was the first recorded mandark→dexter connection, so dexter's host key was added to mandark's `known_hosts` (`accept-new`); the first probe briefly started the stopped `docker-desktop` utility distro. No dexter files were written.

**Decision (Zach, asked directly with three options): license the channel NARROWLY.** Not git-only-plus-human-session, and not the existing full zach shell — a dedicated restricted credential, the reverse-direction analog of `dexter_mandark_deploy`. Design sketch (shape open, not decided in detail): dedicated passphrase-less keypair on mandark; forced `command=` entry in dexter's **Windows-side** `authorized_keys` wrapping a gateway (e.g. `wsl -d Ubuntu -u zach -e <gateway>`) that exposes a small verb set (register a project on dexter, run declared read-only probes against declared media paths) rather than a shell; a mandark `~/.ssh/config` alias with `IdentitiesOnly`. The `_paced.dexter.conf` concurrency rule survives intact: the gateway executes ON dexter, so dexter-host files are still written by dexter.

**Verification bar (crt/wtul precedent, both directions):** before any nightly uses it, live-verify the restricted channel BOTH does what it should AND refuses what it shouldn't — a forced command that quietly still grants a shell is the failure mode that matters.

**Queued, not built (this is `/ideate`):** provisioning is a human-present interactive task — generating key material and editing another host's `authorized_keys` is exactly what the footprint rules say never happens unattended. Until it's provisioned + verified, abletim's dexter-side registration falls back to a human dexter-side session (crt/wtul style). If the gateway generalizes beyond abletim's bootstrap into a real cross-host dispatch mechanism, that's scheduler-engine territory — route via `scheduler -i scheduler` per ideate.md §5, don't grow it ad hoc here.

**Flagged, not fixed (small, low-ambiguity):** `bibliothecaire.idea` and `secretaire.idea` sit **untracked** at the repo root — but nightly runs execute in the dedicated clone of `~/git-remotes/realisateur.git`, so untracked drops are invisible to the very consumer they're waiting for (the exact gap the 2026-07-20 `cmd_idea()` auto-commit fix closed for `scheduler -i` drops; these two were manual drops that bypassed it). `abletim.idea` is committed+pushed this session so it actually reaches the clone; the other two await Zach's say-so (commit as-is, or re-drop via `scheduler -i realisateur`). **Resolved same session:** Zach said commit as-is — both committed+pushed. Root-cause check: `scheduler -i`'s pipeline needs no fix (`cmd_commit_file` auto-commits AND auto-pushes since 2026-07-22); only hand-echoed files bypass it. Going forward: drop via `scheduler -i realisateur "<text>"`, or after a manual echo run `scheduler _commit-file <file>` — the same commit+push path, already exposed as a CLI subcommand for exactly this.

---

**2026-07-25 (`/nightly-batch`, ~11:50 pass): one inbox artifact, investigated and routed to scheduler's own backlog, not scaffolded.**

Only artifact at the repo root was `Investigate-adding-a-door-a-re-20260725-095956.idea` — a remote idea-intake ("door") request for `scheduler -i`, so drops don't have to originate on mandark. Per step 3's own telltale, this names `scheduler -i` directly: it's an addition to the `scheduler` project's own mechanism, not raw material for a new sibling project. Read `~/.local/bin/scheduler`'s `cmd_idea()` to confirm the premise (today's intake is 100% local-filesystem — no network path exists) and scoped three intake options (SSH-only via a dedicated bare repo reusing dexter's existing git-shell-key pattern; a small authenticated HTTP endpoint; email/SMS relay) with a recommendation and the senechal-relevant threat-model note (an internet-reachable file-editing endpoint is the one to harden hardest, if chosen).

Applied park-by-default triage against scheduler's current DECLARED milestone (zero-silent-failure unattended dispatch) — a new intake surface isn't required to reach that bar, so this is `(parked)`, not built. The scoping itself (not code) matches the artifact's own explicit ask ("investigated, not built blind") and the already-recorded-but-unbuilt cross-project-research-agent vision (2026-07-25 entry above) — one concrete instance of that shape run by hand. Routed via the front door (`scheduler -i scheduler "..."`, per the established convention for scheduler-owned design questions — see the 2026-07-24 BLOCKERS.md-taxonomy entry using the same route) rather than a direct cross-write, since this is scheduler's file to design. Committed + pushed by that command in scheduler's own repo. Source artifact archived here as `archive/Investigate-adding-a-door-a-re-20260725-095956.idea`.

Three offline surveys re-run fresh, no new findings changing this pass's scope: `ecosystem-survey.sh` unchanged vision-debt ranking (still topped by the four 2026-07-18 home-assistant entries); `hygiene-lint.sh` 24 total FLAGs (23 crt exec-bit/silent-pipe pre-existing + 1 senechal `base64` test-fixture false positive, same composition as prior passes); `milestone-audit.sh` 8 declared/6 missing/0 no-focus, unchanged from the last recorded count. QUESTIONS.md's two open blocks (svc-vaporwave aedile/vkv-inventory recovery, ideate-mode `UserPromptSubmit` hook) both still carry no `> ` reply — left untouched, genuinely waiting on the human.

---

**2026-07-25 (interactive, Zach-directed): mechanical guard for the commit-message policy — DECIDED, QUEUED NOT BUILT, narrow form only.** Today's policy addition (BUILD-DISCIPLINE failure pattern 12 + the `git commit -F` discipline + a new stamped checklist row, commit `fd04011`) is a *reminder*, which this file's own doctrine says decays. Zach's call, verbatim: **"Worth building, in the narrow form — deny-with-message PreToolUse hook, not a lint row, not a wrapper script. The cost is roughly one small session and a few milliseconds per Bash call; the benefit is coverage of unattended runs that the prose policy structurally cannot reach."**

**Scope (what "narrow form" rules in and out):**
- **In:** a Claude Code `PreToolUse` hook on `Bash` that inspects the command string and *denies with an explanatory message* when it sees a `git commit -m` (or `--message=`) whose message contains shell metacharacters that a double-quoted context would evaluate — backtick, `$(`, `${` — or embedded newlines. The denial message names the fix (`write the message to a file, use git commit -F <file>`), so the deny is instructive rather than just obstructive.
- **Explicitly out, per the same call:** a `hygiene-lint.sh` row (it can't see how a message was constructed — it only ever sees committed text, after the damage), and a `git` wrapper script (it changes a system-wide tool for every human invocation to catch an agent-shaped mistake).
- **Why a hook and not prose:** the failure mode belongs to unattended runs, where no one reads the policy doc. A `PreToolUse` deny is the only layer that sits in the actual path a nightly run takes.

**Design notes to settle when built (not decided now):**
- Where it lives — user-level `~/.claude/settings.json` (covers every project, matching that the mistake is agent-shaped and not repo-specific) vs. per-project. Leaning user-level; confirm before installing, since it's a cross-project behavior change.
- False-positive shape: a message legitimately containing a `$` (e.g. a dollar amount) must not be blocked forever with no escape. Prefer matching only the genuinely-evaluating forms (backtick, `$(`, `${`) over any `$`.
- Same guard arguably belongs on `gh pr create --body`/`gh issue create --body`, per the discipline's own wording. Second, not first.

**Cost/benefit as accepted:** one small session to build; a few ms per Bash call thereafter. **Blockers:** none — this is unattended-buildable in this repo, no human-only step.

**Note for whoever builds it:** this is also a live instance of the `[batch] hygiene-lint: stamped-checklist drift` row at the bottom of this file — today's commit added an 11th checklist row to the BUILD-DISCIPLINE template and to realisateur's own CLAUDE.md, so every other project's stamped copy is now one row behind again.

---

**2026-07-25 (interactive, Zach-directed): manual concurrent burst test ("mega burn near quota deadline") — run, results + groundwork documented, mechanism itself RECORDED NOT BUILT.** Full test writeup, per-project results, and groundwork conclusions live in scheduler's own `DESIGN-NOTES.md` 2026-07-25 entry (same date) — not duplicated here, this is the pointer. Short version: Zach asked to bypass `usage-paced-runner.sh`'s flock and fire `chezz`/`gardien`/`senechal`/`scheduler` concurrently by hand, excluding `home-assistant` (physical side effects) per his instruction and `realisateur` (self-conflict with this live session) on my own call. Cross-repo concurrency ran clean; the one real collision was a `.scheduler/FOCUS.md` merge conflict between `scheduler`'s own dev cycle and a concurrent dexter-side interactive session touching the same file — handled safely (merge aborted, nothing lost, one commit stranded on `paced/2026-07-25` pending a by-hand resolve). Vision for a real automated mega-burn mode, milestone chain toward it, and the concrete gaps found (no quota-aware gating in this manual test, `chezz`'s staleness check silently no-op'd, exclusion list needs to be structural not ad hoc) are all in the scheduler entry — this is a genuinely new mechanism, recorded and queued per `/ideate`'s own contract, not built this pass.

**2026-07-25 (interactive, Zach-directed): cross-project research agent — proposed, RECORDED NOT BUILT, per `/ideate`'s own record-and-queue contract for a genuinely new mechanism.** Same session as the dexter blockers correction below and the `wtul`-on-dexter controlled test (see scheduler `_paced.dexter.conf` commit `0366936`). Zach asked for "a research tool during batch" and confirmed the intent directly: a **cross-project research agent** — something that investigates a specific open question and writes findings back into a project's own FOCUS/QUESTIONS, not a general web-search grant to every nightly-batch run.

**Vision:** an on-demand, realisateur-owned research pass — given one specific open question (tagged in a project's `QUESTIONS.md`, e.g. a `RESEARCH:` prefix), spin up a **read/web-only** one-shot agent (Read/Grep/WebSearch/WebFetch — explicitly no Bash/Write/Edit outside its own scratch dir) that investigates only that question and appends its findings as a `>` reply, reusing the existing `collect-feedback.sh`/`>` convention rather than inventing a new one. It never decides — same posture as everything else here (realisateur perceives → judges → records; the human still decides). This is a natural extension of the already-proven offline-first-checks pattern (`docs/offline-first-checks.md`: build the deterministic version first, layer `claude` on top only for the part that needs judgment) — here the "judgment" is synthesizing external info a local codebase read can't supply.

**Milestone chain, working backward:**
1. *(next, not started)* Prove the shape by hand on ONE real open question that genuinely needs outside info (not something answerable by reading this repo) — a natural candidate once one exists is whichever dexter/wtul quota-race observation ends up needing an external comparison point.
2. *(after that)* If useful, wire it as a real invocation (`scheduler -i <project> --research "<question>"` or a dedicated command) with the tool-scope restriction enforced structurally, not just by prompt — same rigor as `home-assistant.conf`'s existing `BATCH_ALLOWED_TOOLS` restriction pattern.
3. *(explicitly not queued yet)* Any automatic wiring into nightly-batch's own Orient step for every `RESEARCH:`-tagged question — only after step 2 is proven on real cases, not designed ahead of it.

**Blockers:** none technical — this is a "do we want this, and what's the tool-scope guardrail" design decision, not a build blocker. Revisit as a dedicated pass, same as the git-as-archive and file-structure-normalization items already parked this way in this file.

---

## Stability milestone

**REACHED 2026-07-24** — see below. Original bar:
**realisateur reliably turns inbox drops into scaffolded, scheduler-registered projects AND triages every idea active/parked/waiting against each project's milestone (park-by-default), with all three offline surveys wired into every pass** — status: reached
Done when:
- [x] inbox → infer → scaffold → scheduler-register loop runs unattended (proven: 6 projects scaffolded)
- [x] `bin/milestone-audit.sh` exists and the convention is documented (`STABILITY-MILESTONES.md`)
- [x] the offline surveys are wired into both command files (`milestone-audit` added to `/ideate` + `/nightly-batch`; nightly-batch already ran ecosystem-survey + hygiene-lint)
- [x] park-by-default triage APPLIED to real ideas for at least one full pass (2026-07-24: gardien/senechal/wtul each got a real milestone + explicit active/parked tagging against it — git-history-on-RAID and keybinding-parsing parked, naming-registry an explicit named exception, wtul's five deeper-integration items parked)
- [x] build-discipline baseline stamped into every registered project (2026-07-24: crt's dirty tree cleared, then stamped. **Correction, same night:** aedile was WRONGLY marked an edge case here — "no git repo, migrated/defunct" was never actually checked before being written down (same lesson as tonight's credential-gap mistake). It's real and active: tracked as a subdirectory of the `wavebucks` monorepo (`.git` lives at the parent, not `aedile/` itself — a real bug in `bin/scheduler`'s own repo-detection, routed to scheduler via the front door). Stamped its build-discipline checklist same night once corrected; its own milestone content is a separate per-project judgment call, queued below like crt's, not done in this pass)

**New milestone, per STABILITY-MILESTONES.md's Lifecycle (a reached bar means set the next one, not stop):**
**Current:** every scheduler-registered project with a real git repo has a declared `## Stability milestone` of its own, AND park-by-default triage has held across more than one live pass (not just its first exercise) — status: in-progress
Done when:
- [x] gardien, senechal, wtul, scheduler each have a declared milestone (2026-07-24)
- [x] crt got its own dedicated `/ideate crt` pass (2026-07-24) — milestone set (core voice loop + Book Game funnel reliable on potato), park-by-default triage applied against it (dual-tier/Vosk STT eval, bare-metal migration, refactor/docs/polish, wake-judge autonomy, Gemini fallthrough, dexter NPU parked; see crt's own `.claude/FOCUS.md`). This is also the pass that satisfies the next line's "different project than gardien/senechal/wtul" requirement.
- [x] home-assistant got its own dedicated `/ideate home-assistant` pass (2026-07-24) — milestone set (core automations reliable + remote HTTPS access), park-by-default triage applied against it (new device integrations, phased sun-matched circadian rework, kitchen task-lighting design, half-bulbs-off question, wall-switch alternatives, cosmetic entity re-id parked; see home-assistant's own `.claude/FOCUS.md`).
- [ ] the remaining 7 (chezz, nine-speakers, sequestria, vim-arcade, vkv-inventory, groc-mangr, **aedile**) get theirs — incrementally, one per-project judgment call at a time (NOT a bulk-invent — aedile is a real nonprofit Apps Script project — DM-tier bump/triage tuning, scenario library, institutional-memory design — with enough of its own domain nuance to deserve a real pass, not a guessed bar)
- [x] at least one more live `/ideate` pass exercises park-by-default triage on a DIFFERENT project than gardien/senechal/wtul, confirming the mechanism generalizes rather than being a one-off (crt, 2026-07-24, see above)
- [ ] scheduler's own milestone (2026-07-24, see its `.scheduler/FOCUS.md`) reaches `in-progress` → visibly progressing, not stalled — a live signal the engine side of tonight's split is actually working, not just designed

Ideas beyond this bar are PARKED by default (see realisateur/STABILITY-MILESTONES.md):
git-as-archive (Backlog), the `scheduler -i`→realisateur triage-routing hook, and the BLOCKERS.md taxonomy unification (routed to scheduler 2026-07-23) are all `(parked)` — real, past this milestone, revisit when it's reached.

---

**2026-07-24 (`/nightly-batch`, ~23:10 pass): `/ideate` workflow revised — inbox note was about realisateur's own process, not a new project.**

Inbox held one artifact, `revise-the-ideate-workflow-or-20260724-221900.idea`,
naming `ideate` itself as the subject (per step 3's own telltale) — routed
as process feedback, not scaffolded as a sibling project. Full research
and reasoning written to a new root doc, `IDEATE-WORKFLOW-REVISION.md`,
per Zach's own explicit ask ("give me a .md summary... somewhere I can
see it"). Three complaints, three outcomes:
1. **"Vision → milestones → blockers should be ideate boilerplate"** —
   fixed. `ideate.md` §4 now has a named "Standard entry shape" section
   making that structure the default template for any real-direction
   FOCUS.md entry, modeled on this file's own 2026-07-24 dexter entry
   (the example that prompted the ask in the first place).
2. **"ideate seems to only run once"** — partially fixed at the prose
   level (`ideate.md`'s intro now says the surface/ask/record/queue
   posture holds for the rest of that conversation, not just the first
   response), but this is a real Claude-Code-slash-command limitation, not
   fully solvable with markdown — a harder fix would need a
   `UserPromptSubmit` hook re-asserting ideate-mode each turn. Not built
   this pass — infra-scoped, Zach's call, see the new QUESTIONS.md entry.
3. **"drift from ideate over long sessions, hard to enforce with prose"**
   — same root cause and same partial fix as #2; no separate mechanism
   exists to build here beyond what's already queued in the question
   below.

Source artifact archived as `archive/revise-the-ideate-workflow-or-20260724-221900.idea`.

---

**2026-07-27 (nightly-batch): five BLOCKERS.md strategy-audit decisions APPROVED and RECORDED — wiring phase queued. Inbox: 11 artifacts, all realisateur-infrastructure-shaped, categorized for build/queue/route.**

**The five approved decisions, recorded from inline REPLY section of scheduler's BLOCKERS.md:**
1. **PLAYBOOK.md blessed as standing doctrine** — governs build-vs-import-vs-retire allocation, same standing as UNIVERSE.md. Already committed `436f774` in the 2026-07-26 `/ideate` session.
2. **Commit-message `PreToolUse` hook at user level** — install in `~/.claude/settings.json` (covers every project) rather than per-repo, per Zach's explicit call on location. **ACTION QUEUED `[batch]`:** create a template copy at `~/.claude-settings-template.json` + a one-liner install snippet, so agents gated on the sensitive-file write can still copy/paste the hook into their own settings.
3. **Import swaps approved (a), (b), (c)** — (a) symlinks replace `scheduler pacing deploy`/drift-detection; (b) ccusage replaces `token-usage.sh`'s parsing core; (c) gitleaks replaces hygiene-lint's hand regexes. (d) restic/rsnapshot under `gardien.py` deferred until gardien unparks. **ACTION QUEUED `[batch]`:** per the stated wiring plan in PLAYBOOK.md, these are pre-built externals — sequencing is (a) first (fixes live LIVE drift in `usage-paced-runner.sh`), then (b)/(c) once ready. No new mechanism to build; the queue here is integration/testing.
4. **Catabolic worklist approved** — retire ~1,000 lines already self-labeled superseded, **one retirement per pass, each commit naming what retires it** (Law 3 enforcement, PLAYBOOK Play 4). Lines in scope: morning-report ×2, build-services-view + `services/`, incubation-audit.sh, overnight-dev ×2, the two 162-line loop-script forks, sync-crontab's dead auto-stagger. **ACTION QUEUED `[batch]`:** this is a rotation queue, not a single job — one item per nightly-batch pass. First pass gets priority: incubation-audit.sh (soft-replaced by `milestone-audit.sh` already; this pass will build the dispatch-verifier that can detect and FLAG such cases).
5. **Re-admission policy approved** — as each parked making-project declares its stability milestone (groc-mangr/nine-speakers/sequestria/vim-arcade, jobs queued 2026-07-26), re-enable at weight 1–2 with no further per-project ask. vkv-inventory stays at 0 regardless (svc-vaporwave crontab owns its dispatch). **ACTION QUEUED `[batch]`:** no mechanism to build — this is a manual triage step per project. Flagged in the steward-survey job tracking for the next `/ideate` to act on as the projects reach their milestones.

**Inbox processing, 2026-07-27 pass — 11 artifacts, all realisateur-infrastructure (not new projects):**

Categorized by action:

- **BUILD NOW (`[batch]` tagged for this or next unattended pass):**
  - **Batch work audit (pipefail/SIGPIPE sweep)** (`Batch-work-for-realisateur-own-20260727-094923.idea`): Audit bin/check-project-busy.sh and bin/focus-commit.sh for the same class of bug just fixed in bin/notify-senechal.sh (aebf5f4). Both scripts' guard verdicts are acted on by other agents, so false negatives are not local — they cascade. focus-commit is higher priority (guards a multi-writer file with 4 recorded content losses). Suggested sweep: (1) every `| grep -q` / `| head -c` / early-exit under pipefail; (2) checks that collapse "could-not-verify" into failure. Pattern from notify-senechal: no pipelines in the check — read into a variable, match with here-string, slice with bash parameter expansion. **Queued for current pass:** both scripts audited + test fixtures added if issues found.
  
  - **Cloture dead-queue detection** (`CLOTURE-GAP-MECHANISM-REQUEST-20260727-103113.idea`): New layer-1 addition to bin/closeout-lint.sh (offline, deterministic, per offline-first-checks.md). Four checks requested; sequence the high-value pair: (1) **dead-queue check** — for each project filed into, assert that project is actually dispatching (present in a rotation file AND not expired); (2) **owner/location mismatch** — if a row names a different project as the target, FLAG it. Witness: exhibit 1 (filed into scheduler's FOCUS.md, but scheduler dev-cycle is hard-barred from touching non-scheduler files; exhibit 2 (realisateur filed into an expired job's inbox). Would have caught both. **Queued for next closeout-lint evolution:** not this pass (layer 1 is stable; layer 2 needs the `git mv`).
  
  - **notify-senechal fixes** (five separate `.idea` artifacts covering the same issue family): The guard has produced 2 of 2 false-NEGATIVEs on success paths (`landed()` under pipefail, `ahead > 0` false on happy path). Fixes already proposed and partially implemented (`aebf5f4` fixed pipefail; step-2 false-FAIL redesign proposed in `notify-senechal-sh-step-2-repo-20260726-234041.idea`). **Queued for current pass:** finish the step-2 redesign (use merge-base containment check instead of ahead-ness), instrument failure paths with the diagnostics proposed in `CORRECTION-to-my-earlier-notif-20260727-005022.idea`, and add regression fixtures reproducing both the pipefail and happy-path false-NEGATIVEs.

- **DOCTRINE + LINT ROWS (queued for build in the current or next pass):**
  - **Pattern 16: "a correct refusal that nothing retries"** (`From-scheduler-interactive-ses-20260727-102821.idea`, first half): Distinct from pattern 8 (warn-then-continue proceeds) and 13 (no dispatch path). A guard correctly declines, logs loudly, and nothing revisits — so the refusal is permanent by omission. Rule shape: a fallback that declines must *name what retries it*, or it is a dead end. **Queued as `[batch]` (documentation only, not machine enforcement):** add to BUILD-DISCIPLINE.md as pattern 16, with the live exhibit and fix from scheduler `dd086bb`.
  
  - **SCHEDULER_SUBDIR hardcoding detection** (`Finding-from-senechal-2026-07-20260727-103411.idea`): Ecosystem scale violation of "config read from one source, not retyped." Nine scripts re-derive the focus-path literally or by probing; five reimplement the conf read; none call a unified resolver. **Queued as `[batch]` lint rows:**
    - (1) **FLAG any script containing a `.claude/FOCUS.md` or `.scheduler/FOCUS.md` path literal** instead of calling the resolver.
    - (2) **FLAG any registered project whose declared SCHEDULER_SUBDIR does not match what is on disk** — mechanical close condition for the 9-vs-9 migration.
    Depends on scheduler exporting `scheduler _focus-path <project>` (filed to scheduler via `scheduler -i` in the same pass). Build this lint row alongside the audit above.

- **DOCTRINE PROPOSAL (Zach-directed decision awaiting):**
  - **OWNERSHIP: notify-senechal.sh residency** (`Cross-write-from-senechal-I-fi-20260727-094002.idea` & `Cross-write-from-senechal-foll-20260727-094721.idea`): The script encodes senechal's read-path (`.claude/FOCUS.md` post-migration, the landed() contract), so when senechal moves its FOCUS the notifier silently breaks in a repo senechal cannot fix. Happened exactly during the 2026-07-26 `.claude/`→`.scheduler/` move itself. Case for move to senechal: it owns the contract; case against: fragments the three-guard protocol family this repo propagates. **Already: senechal documented the contract in its own ESTATE.md; realisateur stays the owner. Flagged for next `/ideate` session as a design tradeoff awaiting human judgment.**

- **RECORD GAPS AND FOLLOW-UP (documented but no build action):**
  - **Pattern 14 doctrine entry** (`From-scheduler-interactive-ses-20260727-102821.idea`, second half): The session that proposed pattern 16 also recorded a commitment to update realisateur's own FOCUS.md for commit c49c70d (session-marker.sh). That commit exists in the repo but this entry never got recorded — a deadletter artifact of filing into a dispatcher that could not act (BUILD-DISCIPLINE pattern 13 layer-up). Record added (this entry itself). **No action: this is a resolved-by-recording case.**

**Inbox archived:** 11 artifacts, all accounted for and categorized above. Source path tags preserved for traceability.

---

**2026-07-24 (`/ideate`, interactive, Zach-directed): dexter parallelism vision/milestone/blockers pass — triggered by Zach running a scheduler self-build session ON dexter itself, live, during this pass.**

**Vision (partial promotion, asked directly — see scheduler's own `.scheduler/FOCUS.md` "vision promoted... partial" entry same date for full text, mirrored short here):** "dexter becomes the primary host where unattended jobs run" is now a real active direction, not just gardien's 2026-07-24 parked dream — that QUESTIONS.md item is answered, see gardien's own `.claude/QUESTIONS.md`. Explicitly NOT decided yet: cloud VMs, remote GitHub-agent triggers, or a hard mandark-sunset date — those stay open, separate, later. Explicitly declined: naming "many parallel jobs on dexter via VMs/WSL" as the next-next milestone — too far ahead per Zach, revisit once the current single-peer MVP is proven.

**Milestone chain, working backward from that vision:**
1. *(current, in-progress, DESIGN-NOTES.md 2026-07-24)* — dexter self-build: register as a second host, own `_paced.conf` subset (crt pinned, the one hardware-evidenced case), own crontab tick, drop crt from mandark's `_paced.conf` so nothing double-dispatches. This is the session Zach is running right now.
2. *(next, not yet started)* — observe `run.log` on both boxes for the accepted quota-race risk (two independent `usage-gate.sh` probers can both see slack and both dispatch, overshooting between probes) actually behaving safely in practice, not just in theory.
3. *(after that, undecided)* — whether more projects pin to dexter (gardien/senechal's permission-scope gate, not network-locality, is still an open question per scheduler QUESTIONS.md) and whether dexter becomes the RAID's physical host (blocked on a TB2 cable/adapter per gardien's own FOCUS.md).
4. *(explicitly not queued yet)* — multi-VM/parallel-job architecture on dexter, cloud VMs, GitHub remote-agent triggers, mandark retirement. Real ideas, deliberately left fully open past step 3.

**Blockers clearable now/tonight (from scheduler's own QUESTIONS.md, human-only steps — nothing here is unattended-buildable until these are confirmed):**
1. Confirm dexter's Claude Code login is on the SAME primary Max account as mandark — the whole shared-quota premise silently breaks otherwise. (Human/interactive OAuth step — likely already done if the self-build session is running.)
2. Confirm dexter has working git push access to crt's local bare remote (`/home/zach/git-remotes/crt.git` from mandark's filesystem — confirm the equivalent path/reachability from dexter).
3. Re-confirm crt's OctoPrint (`192.168.0.43`) is reachable from dexter's NEW WSL2 environment specifically — the 2026-07-20 confirmation was against a different (full-VM) networking setup, not guaranteed to carry over to WSL2's NAT.
4. Zach's call, still open: does gardien/senechal need dexter locality, or does their existing permission-scope gate mean they're irrelevant to the machine question? Left unpinned in scheduler's FOCUS.md, not guessed.

**Status correction, 2026-07-25 (realisateur, interactive, re-surveyed against scheduler's own FOCUS.md/QUESTIONS.md/DESIGN-NOTES.md rather than left stale) — all four blockers above are CLEARED, not open:**
1. **Cleared** — `usage-gate.sh` runs on dexter and reads the shared account's live 5h/7d windows; confirmed same-account login (scheduler QUESTIONS.md, "RESOLVED BY THE 2026-07-24 dexter self-build," item 1).
2. **Cleared, but the resolution differs from what this entry assumed.** dexter does not reach mandark's bare-repo path directly — mandark's `/home/zach/git-remotes/crt.git` is now exposed over SSH (`openssh-server` on mandark, a git-shell-only `dexter_mandark_deploy` key, `crt.conf`'s `REPO_URL` repointed at `ssh://mandark-lan/...`), and dexter clones through that. Live-verified from dexter itself (`git ls-remote`, host-key fingerprint cross-checked against mandark's real key) — commit `845d1e5`, full writeup DESIGN-NOTES.md 2026-07-24 "crt live-verified from dexter, enabled." `crt` is now `enabled=1` in `schedule/_paced.dexter.conf` and was dropped from mandark's `_paced.conf` in the same change (`2e0602a`) — dexter runs it, mandark does not, no double-dispatch.
3. **Cleared** — 0% ICMP loss, TCP 80 open, OctoPrint-identifying HTTP 302 (`x-clacks-overhead` header) confirmed from dexter's actual WSL2 environment, not just assumed to carry over (scheduler FOCUS.md 2026-07-24 dexter self-build entry).
4. **Answered 2026-07-25** (scheduler QUESTIONS.md) — no pinning. gardien/senechal stay parallel stewards of their own systems; revisit only if real hardware/network evidence for either shows up, per `_paced.dexter.conf`'s own stated pinning bar.

Net effect: the milestone-chain step-1 self-build above is DONE, not in-progress — dexter and mandark are two independently-dispatching, independently-pulling schedulers running in parallel tonight (mandark's normal ~8-participant rotation; dexter running `crt` alone). Step 2 (watch `run.log` on both boxes for the accepted quota-race risk) is the live open item now, not these four.

**File structure: DECIDED — normalize now, ecosystem-wide (not deferred, not opportunistic-only).** Asked directly; Zach chose a dedicated pass now, since a clean known layout makes each project's dexter clone path predictable rather than adding a new inconsistency to migrate around later. **Queued, not built this pass** (this is a real blast-radius action — moving directories that scheduler's `schedule/*.conf` `PROJECT_REPO_PATH` fields point at, for live registered projects, needs sequencing with config updates so dispatch doesn't silently break):
- Real inconsistency, surveyed this pass: `~/Documents/Projects/` holds most active projects (crt, gardien, groc-mangr, nine-speakers, realisateur, senechal, sequestria, vim-arcade) plus a stray loose `FOCUS.md`; `~/Documents/Project Archive/` — despite its name — holds several currently-active scheduler-registered projects (chezz, home_assistant, scheduler itself) alongside genuinely archived non-project files (PDFs, scores, old application docs); `~/Documents/wtul` sits directly under `Documents/` on its own; `~/Documents/vkv/{wavebucks/aedile, inv/inventory-app}` is a third pattern again.
- Proposed target shape (not yet approved in detail — flag before executing): all scheduler-registered *active* projects under one root (`~/Documents/Projects/`), non-project archive material (the PDFs/scores/docs currently sharing `Project Archive`) moved somewhere clearly not named "Project" (e.g. `~/Documents/Archive/`), each move paired with the matching `schedule/<project>.conf` `PROJECT_REPO_PATH` update in the same pass so scheduler dispatch never points at a stale path even transiently.
- The stray `~/Documents/Projects/FOCUS.md` loose file at the root (not inside any project directory) is worth a direct look before the cleanup pass — likely leftover/misplaced, not a real per-project file.
- Not done this session (interactive-only ideate scope) — queued as the next concrete realisateur-led build once the dexter MVP blockers above are clear, since this doesn't need to happen before dexter's self-build finishes, and touching every registered project's config is exactly the kind of action worth a dedicated, careful pass rather than a rushed one alongside tonight's dexter work.

---

**2026-07-24 (`/ideate`, interactive, Zach-directed): aedile/vkv-inventory carved out of realisateur's direct cross-write privilege — front-door only, going forward.** Zach asked directly how realisateur's ideation reaches these two vaporwave projects, given zach@mandark's existing local copies (`schedule/aedile.conf`/`vkv-inventory.conf`'s `PROJECT_REPO_PATH`, `/home/zach/Documents/vkv/{wavebucks/aedile,inv/inventory-app}`) are scheduled to be sunset/closed. Both projects' actual unattended dispatch already migrated off mandark to `svc-vaporwave`'s own fresh-clone-and-push checkout (2026-07-20) — the mandark copy has been a read/write target for realisateur's own ideation only, not load-bearing for the automation itself. Presented three options (fresh-clone-and-push like svc-vaporwave, a dedicated persistent vision-mirror clone, or route through scheduler's `-i` front door like an external project) — **Zach chose the front door.** Decided: once mandark's copies close, realisateur stops direct `FOCUS.md`/`QUESTIONS.md` cross-writes into aedile/vkv-inventory and queues ideation for them via `scheduler -i <project> "<text>"` instead, same as chezz's own `/ideate` must for anything outside itself. Every other registered project keeps the direct-cross-write privilege — this carve-out is scoped to just these two, because of their specific account/remote topology (svc-vaporwave-owned, not zach's own working copy). Recorded as an explicit exception in `.claude/commands/ideate.md`'s step 4 (not silently applied) so future `/ideate` passes read it as a standing rule, not something to re-derive. No code changed; `PROJECT_REPO_PATH` in `schedule/*.conf` is unchanged for now (still points at mandark, since those copies haven't actually closed yet) — this is a heads-up decision for when they do, not an immediate migration.

**2026-07-24 (`/ideate aedile`, interactive, Zach-directed): the entry above is SUPERSEDED same day — front-door carve-out reverted to a documented fallback, not the default.** Zach followed up asking to scope the "scrub `.claude/` files off GitHub" idea into a real `/ideate aedile` pass. Investigation found the premise already moot: `wavebucks`' root `.gitignore` already ignores `.claude/` ("Claude Code local state, per-developer, not shared"), and `git log --all --diff-filter=A` across the entire repo confirms no `.claude/*` file was EVER committed there — nothing to scrub. aedile's real vision docs were deliberately renamed to `aedile/.scheduler/FOCUS.md`/`QUESTIONS.md`, which ARE git-tracked and already flow through svc-vaporwave's normal clone with zero extra sync mechanism. This directly undercuts the prior entry's premise: the mandark-copy-closing concern doesn't block a direct cross-write at all, since the real docs live in git, reachable via a fresh clone with zach's own existing GitHub access regardless of whether mandark's copy exists. **Reverted:** direct cross-write is again the default for aedile/vkv-inventory (vkv-inventory was never actually in the same boat anyway — `inventory-app.git` is its own dedicated repo, not shared with Tyler, and already tracks plain `.claude/` normally, so "same shape as aedile" doesn't apply to it). The `scheduler -i` front door stays documented as an available fallback in `ideate.md`, not deleted, per Zach's explicit "keep as option." `.claude/commands/ideate.md` step 4 updated to reflect this correction directly (not left as two contradictory entries to reconcile later).

**Real bug found in the same pass, queued not fixed:** `bin/milestone-audit.sh` already supports a `SCHEDULER_SUBDIR` override (used by `scheduler` itself, whose own FOCUS.md also lives outside `.claude/`) but `schedule/aedile.conf` never sets it, so the audit defaults to `.claude/FOCUS.md`, finds nothing, and has been misreporting aedille as "FOCUS: none / no milestone" every pass — it actually has a real 21KB `.scheduler/FOCUS.md`. Separately, `scheduler`'s own `questions/aedile.md` symlink points at the wrong file (`aedile/.claude/QUESTIONS.md`, empty/untracked) instead of the real, tracked `aedile/.scheduler/QUESTIONS.md` — `focus/aedile.md`'s symlink is correct, `questions/aedile.md`'s isn't. Proposed fix (one line, `SCHEDULER_SUBDIR=".scheduler"` in `aedile.conf`, then regenerate symlinks): flagged to Zach as small/low-ambiguity per `/ideate` step 2, not applied without confirmation.

---

**2026-07-24 (`/nightly-batch`, ~21:10 pass): inbox empty, nothing to build.**

Repo root held only realisateur's own scaffolding again -- no dropped
artifact to infer or wire up. All three offline surveys re-run fresh:
`bin/hygiene-lint.sh` still 21 total FLAGs, same composition as the last
recorded pass (20 pre-existing crt exec-bit/silent-pipe issues + the one
senechal `base64` test-fixture false positive) -- not this run's project
to fix. `bin/milestone-audit.sh` now shows **8 declared/6 missing/0
no-focus**, up from the last-recorded 7/6/1 -- aedile now carries a real
DECLARED milestone (scenario-library-as-PR-gate replacement) and
scheduler's own no-focus edge case has resolved too, both from other
sessions' work since the last nightly pass, not this one -- observed,
not acted on. `bin/ecosystem-survey.sh`'s vision-debt ranking unchanged,
still topped by the four 2026-07-18 home-assistant entries.
QUESTIONS.md's one open block (aedile/vkv-inventory svc-vaporwave
recovery) still carries no `> ` reply -- left untouched, genuinely
waiting on the human cross-account access step. Park-by-default triage
not exercised this pass (no live new-project/new-addition candidate in
tonight's empty inbox).

**2026-07-24 (`/nightly-batch`, ~20:00 pass): inbox empty, nothing to build.**

Repo root held only realisateur's own scaffolding again -- no dropped
artifact to infer or wire up. All three offline surveys re-run fresh:
`bin/hygiene-lint.sh` now shows 21 total FLAGs (up from 20) -- 20 still
crt's own pre-existing exec-bit/silent-pipe issues (already flagged, not
touched), plus one new FLAG in senechal (`test_senechal.py:296`, a
`base64`-encoded test fixture literal tripping the secret-value
heuristic) -- not this run's project to fix, noted here per the
signals-not-verdicts stance so it doesn't go unrecorded.
`bin/milestone-audit.sh` unchanged at 7 declared/6 missing/1 no-focus, no
reached triggers. `bin/ecosystem-survey.sh`'s vision-debt ranking
unchanged, still topped by the four 2026-07-18 home-assistant entries.
QUESTIONS.md's one open block (aedile/vkv-inventory svc-vaporwave
recovery) still carries no `> ` reply -- left untouched, genuinely
waiting on the human cross-account access step. Park-by-default triage
not exercised this pass (no live new-project/new-addition candidate in
tonight's empty inbox).

**2026-07-24 (`/nightly-batch`, ~16:12 pass): inbox empty, nothing to build.**

Repo root held only realisateur's own scaffolding again -- no dropped
artifact to infer or wire up. All three offline surveys came back
unchanged from the last recorded pass: hygiene-lint's 20 FLAGs are still
crt's own pre-existing exec-bit/silent-pipe issues (already flagged,
not touched); milestone-audit still 7 declared/6 missing/1 no-focus, no
reached triggers; vision-debt ranking still topped by the four
2026-07-18 home-assistant entries and the 2026-07-19/20 scheduler
entries, nothing new or older surfaced. QUESTIONS.md's one open block
(aedile/vkv-inventory svc-vaporwave recovery) is still genuinely
waiting on the human cross-account access step -- no `> ` reply, left
untouched. Park-by-default triage not exercised this pass (no live
new-project/new-addition candidate in tonight's empty inbox).

**2026-07-24 (`/nightly-batch`, ~14:45 pass): inbox empty, nothing to build.**

Repo root held only realisateur's own scaffolding again -- no dropped
artifact to infer or wire up. All three offline surveys came back
unchanged from the last recorded pass: hygiene-lint's 20 FLAGs are still
crt's own pre-existing exec-bit/silent-pipe issues (already flagged,
not touched); milestone-audit still 7 declared/6 missing/1 no-focus, no
reached triggers; vision-debt ranking still topped by the four
2026-07-18 home-assistant entries and the 2026-07-19/20 scheduler
entries, nothing new or older surfaced. QUESTIONS.md's one open block
(aedile/vkv-inventory svc-vaporwave recovery) is still genuinely
waiting on the human cross-account access step -- no `> ` reply, left
untouched. Park-by-default triage not exercised this pass (no live
new-project/new-addition candidate in tonight's empty inbox).

**2026-07-24 (`/nightly-batch`, ~13:12 pass): inbox empty, nothing to build.**

Repo root held only realisateur's own scaffolding (`README.md`,
`SCHEDULER.md`, `STABILITY-MILESTONES.md`, `BUILD-DISCIPLINE.md`,
`FOCUS-FORMAT.md`, `CLAUDE.md`, `.gitignore`, `.claude/`, `archive/`,
`bin/`, `schedule/`, `.git/`) -- no dropped artifact to infer or wire up.
All three offline surveys came back unchanged from the last recorded
pass: hygiene-lint's 20 FLAGs are still crt's own pre-existing exec-bit/
silent-pipe issues (already flagged there, not touched); milestone-audit
still 7 declared/6 missing/1 no-focus, no reached triggers; vision-debt
ranking still topped by the four 2026-07-18 home-assistant entries and
the 2026-07-19/20 scheduler entries, nothing new or older surfaced.
QUESTIONS.md's one open block (aedile/vkv-inventory svc-vaporwave
recovery) is still genuinely waiting on the human cross-account access
step -- no `> ` reply, left untouched per the answer-only-acts-on-a-reply
contract. Park-by-default triage not exercised this pass (no live
new-project/new-addition candidate in tonight's empty inbox).

**2026-07-24 (`/nightly-batch`, ~10:08 pass): inbox cleared (two artifacts, both stale reference snapshots), no new project scaffolded.**

Two artifacts at the repo root: `COMPUTE-STICK-MIGRATION.md` and
`PI-MIGRATION-STATUS.md`, both explicitly self-described as "copied in
from the `crt` project as reference context," not new ideas. Checked
against crt's own current state before archiving, per park-by-default
triage (an addition to an existing project, judged against its current
milestone): crt already carries a near-identical
`COMPUTE-STICK-MIGRATION.md` in its own repo (this inbox copy differs
only in copyedits/a header line -- same content, same conclusion:
abandoned, migrated to a Pi), and the compute-stick/bare-metal migration
is already explicitly PARKED in crt's own `.claude/FOCUS.md` ("explicitly
excluded from this bar by Zach 2026-07-24 -- a separate, later goal, not
required for the core loop or Book Game to be reliable"). The Pi-status
note (flashed Pi 3B, account split in progress, keyboard-layout snag) is
an early-stage snapshot from 2026-07-22 that's since been superseded by
crt's own `POTATO.md`, which documents potato (Pi 3B+) as the fully live,
working console hardware today. Nothing left to build or decide -- both
archived as `archive/COMPUTE-STICK-MIGRATION-20260722.md` and
`archive/PI-MIGRATION-STATUS-20260722.md`. All three offline surveys came
back unchanged from the last recorded pass (crt's 20 hygiene FLAGs are
its own pre-existing exec-bit/silent-pipe issues, already flagged, not
touched this pass; milestone-audit still 7 declared/6 missing/1 no-focus;
vision-debt ranking still topped by the four 2026-07-18 home-assistant
entries). **QUESTIONS.md housekeeping:** verified crt's own working tree
directly (`git status` on `~/Documents/Projects/crt`) -- it's clean now,
crt's own nightly runs already committed the WIP + stamped build-
discipline (`d8fbe7b`, `a22ac77`, same night) since that question was
flagged. Removed the stale crt-dirty-tree question from QUESTIONS.md as
resolved (not acting on a `> ` answer -- there wasn't one -- just retiring a
flag whose underlying condition no longer holds, verified against real
state rather than assumed). The aedile/vkv-inventory recovery question
remains open, untouched, genuinely waiting on the human svc-vaporwave
access step. Park-by-default triage was exercised this pass (both
artifacts judged against crt's current milestone/parked-status), even
though the outcome was "nothing to build."

---

**2026-07-24 (`/ideate`, interactive, Zach-directed): new BUILD-DISCIPLINE.md rule — "declare your host footprint" — plus senechal's mission widened to own it.** Zach asked directly ("senechal should take some ownership... nobody owns this right?") about `dexter` accumulating unattributable dev cruft (scripts/autostart entries) from `crt`'s work, with no ecosystem mechanism naming or tracking it. Two decisions, asserted together per Zach's own framing ("both... give the build discipline rule... but have senechal own knowledge of the script world of all of Zach's shared hosts"):
- **BUILD-DISCIPLINE.md**: added failure pattern #6 (cruft on shared hosts) and a new mechanical discipline — any project installing onto a shared host (`dexter`, `mandark`, future hosts) must declare it in its own FOCUS.md, remove it when retired — plus a new checklist row. A real `hygiene-lint.sh` check (cross-referencing declared footprints against senechal's actual host journals) is queued, not built, this pass.
- **senechal's mission widened** (recorded in senechal's own FOCUS.md/QUESTIONS.md, cross-committed there): from mandark-only journaling to owning knowledge of the script/autostart world across *all* of Zach's shared hosts, with cleanup itself as "a mix" — direct action where senechal owns it, delegation to project-specific batch jobs via scheduler where a project (like crt) should clean up its own mess. This is explicitly a **named exception** past senechal's current stability milestone (mandark watch-list breadth + redaction coverage), same shape as the naming-registry exception — approved directly by Zach, not milestone-widening by drift. Implementation (how senechal reaches a Windows host like dexter, the actual cleanup-vs-delegate split per case) is genuinely open design, not decided or built this pass — record and queue, not build, per `/ideate`'s own contract.

---

**2026-07-24 (`/nightly-batch`, ~04:00 pass): inbox cleared (one artifact, already resolved), no new project scaffolded.**

Only inbox artifact was `Correction-to-the-chezz-wtul-c-20260724-032158.idea` -- its full content (chezz/wtul deploy keys verified working, no credential gap, real cause is the spend-limit-cutoff pattern) was already folded into this file's own credential-gap-correction entry below (commit `a09c5b1`, same night, ahead of this pass). Nothing left to do but archive it -- no new decision, no new build. All three offline surveys came back substantively unchanged from the last recorded pass (crt's 24 hygiene FLAGs still pre-existing/already-flagged there; milestone-audit still 5 declared/8 missing/1 no-focus, no reached triggers; vision-debt ranking still topped by the three 2026-07-18 home-assistant entries). QUESTIONS.md: both open blocks (crt dirty-tree, aedile/vkv-inventory recovery) still unanswered, left untouched. Park-by-default triage not exercised this pass -- no live new-project/new-addition candidate in tonight's inbox.

**2026-07-24 (`/nightly-batch`): inbox cleared, no new project scaffolded, chezz/wtul FOCUS.md formatting fixed.**

Ran the three offline surveys first (clean: crt's 27 FLAGs are its own
pre-existing dirty-tree/exec-bit/silent-pipe issues, already flagged,
not touched). QUESTIONS.md: two already-answered/already-folded blocks
(bare-remote chown, incubation-audit reweight) removed as processed; the
crt-dirty-tree block is still unanswered, left in place. Five inbox
artifacts at the repo root, all already-decided or realisateur's-own-
process notes rather than new ideas needing a fresh project:
`Build-the-stability-milestone-*.idea` (already built, see the section
above), `look-at-Document-Project-Archi-*.idea` (already reconciled,
`/ideate` shipped 2026-07-22, remainder stays parked), `Spec-out-a-more-
principled-eco-*.idea` (already routed to scheduler 2026-07-23),
`incubation-decisions-2026-07-22.conf` (applied then superseded
2026-07-23) — all archived. `FOCUS-md-formatting-compliance-*.idea`
(flagged by scheduler 2026-07-22: chezz's FOCUS.md was prose/HTML-
comment-only, wtul had no real FOCUS.md) was genuinely actionable:
wrote `FOCUS-FORMAT.md` (canonical spec, matches what
`extract_next_items()` in `bin/scheduler` actually parses), added a
real `## Priority queue` section to chezz's FOCUS.md (existing comment
content untouched), fleshed out wtul's FOCUS.md into a thin pointer
into `ROADMAP.md` (kept as the real detail doc, to avoid drift).
Committed in both projects' own repos, tagged `(realisateur)`; **could
not push either** — both use real GitHub remotes (`git@github.com:hf7y/
{chezz,wtul}.git`) this environment has no publickey credentials for
(same "prefer local bare remote, GitHub needs real credentials" bar
`SCHEDULER.md`/this file's Backlog section already names) — commits sit
local, will push on each project's own next scheduled dispatch, or push
by hand if that's wanted sooner. **Milestone checklist note:** this pass
did NOT exercise park-by-default triage against a live idea (nothing in
tonight's inbox was a genuine new-project or new-addition candidate) —
that checklist item stays unchecked, not falsely marked done.

**2026-07-24 (this sprint — vision + concurrency fix + first live triage pass, sequenced per plan):**

- **Concurrency fix shipped (realisateur's half).** `bin/check-project-busy.sh`
  (flock-probes a project's own scheduler job locks, zero AI cost) wired
  into `/ideate` step 4's cross-write bullet — don't edit another
  project's FOCUS.md/QUESTIONS.md while its own automation holds the
  lock. Scheduler's half (dispatch/push robustness) is routed, not
  hand-fixed — see below.
- **Root cause: CORRECTED 2026-07-24, was wrong the first time.** Original
  claim (this same night, earlier): chezz/wtul's stranded commits were a
  credential gap (dispatch environment lacking GitHub SSH access). That
  was never actually tested against the real keys before being routed to
  scheduler — a later pass caught it (zach: "don't they have deploy?"),
  verified directly (`ssh -T`, a real test push), and found chezz/wtul
  already have working, write-verified deploy keys. **No credential gap
  exists.** The real explanation for the original stranded commits is the
  already-documented account-wide spend-limit-cutoff pattern (2026-07-20):
  a run's commit lands, the push doesn't happen because the run got cut
  off by quota exhaustion mid-cycle, not because credentials were
  missing. Real fix (already queued in scheduler's own FOCUS.md): make a
  stale/incomplete push loud in `scheduler status`/`sweep.log`, not new
  credentials. **Lesson for next time:** verify a diagnosis against real
  state (an actual `ssh -T`/test push here) before routing it to another
  project as fact or writing it into memory — a plausible-sounding
  explanation that fits the symptom isn't the same as a tested one.
  `bin/check-project-busy.sh` (below) is unaffected by this correction —
  it solves a different, real problem (cross-writing into a live run's
  files) regardless of what was actually wrong with the pushes.
- **First real park-by-default triage pass.** gardien, senechal, and
  wtul (the three projects this sprint's design-fork decisions touched)
  each got their first `## Stability milestone` — the prerequisite the
  checklist above was waiting on. Hit and fixed a real parser trap along
  the way: the `**Current:**` bar+status must be one physical line, not
  wrapped Markdown — documented in `STABILITY-MILESTONES.md` now so the
  next 8 missing-milestone projects don't repeat it.
- **Remaining sprint work, split per tonight's "both, sequenced" call:**
  - *Triage-hardening:* **DONE, same session.** Both bootstrap exit
    conditions were met (convention exists + a live pass proved park-by-
    default out), so `schedule/_paced.conf`'s `scheduler`/`realisateur`
    weight dropped 3→1 — stated explicitly in that file's own comment
    and in the commit, not a silent reweight.
  - *Scaffold-hardening:* 8 more projects still show `missing` in
    `milestone-audit.sh` (chezz, crt, home-assistant, nine-speakers,
    sequestria, vim-arcade, vkv-inventory, groc-mangr). Per the standing
    "not a bulk-invent" rule, populate incrementally during each
    project's own `/ideate <name>` pass — crt specifically blocked until
    its dirty-tree flag (still open in QUESTIONS.md) is cleared.
- **Blockers only the user can clear:** crt's dirty tree (needs a human
  or crt's own batch to commit-or-clean it — realisateur can't touch it
  meanwhile); whether the dispatch environment actually gets GitHub
  credentials is scheduler's design call but the credential material
  itself (deploy key generation, `known_hosts`) needs a human step no
  agent should do unattended.

**2026-07-24 (`/ideate` ecosystem pass — decisions recorded, nothing built):**

- **scheduler-milestone open question: RESOLVED — engine participates.**
  Decided the engine should get a stability milestone too, not be treated
  as exempt mechanism. Routed via `scheduler -i scheduler` (front door,
  per step 5) rather than hand-edited — scheduler itself now owns whether
  that lands as a `.scheduler/FOCUS.md` `## Stability milestone` section
  or a `milestone-audit.sh` fix to also read `.scheduler/`.
- **gardien's git-history-on-RAID fork: DECIDED — git remote + partial
  clone.** Folded into gardien's own FOCUS.md/QUESTIONS.md
  (`(realisateur)`-tagged). Real synchronicity worth naming here too:
  this is the same underlying shape as this repo's own parked
  "git-as-archive" idea below (empty working root, full history lives in
  git) — if gardien builds the remote/partial-clone mechanism first,
  revisit git-as-archive against it rather than designing from scratch.
- **senechal's "keeper of names and places" fork: SCOPED, not just
  decided.** Naming-convention registry only (new file in senechal's own
  repo, senechal's to name); canonical-shared-location half (lilypond
  library, GitHub tidy-up) explicitly split out as a separate later idea.
  Folded into senechal's own FOCUS.md/QUESTIONS.md.
- **wtul's metadata-API either/or: DECIDED — Discogs, token already in
  hand.** Only part (a) of that 2026-07-18 bundle; (b)/(c)/(d) (catalog
  spreadsheet, printer model, web-photo/OCR) remain genuinely open.
- **Flagging, not fixing:** chezz and crt both show stranded local
  commits from FAILED nightly runs (not pushed to origin, per `scheduler
  status`) — separate from crt's already-flagged dirty-tree stop.
  home-assistant's last run divergence check also printed an empty
  remote-hash field, possibly a reporting glitch rather than a real
  issue. None acted on this pass.
- **Vision-debt state, unchanged:** oldest open dated items are still the
  three 2026-07-18 home-assistant entries — same as last check, not
  drained, not obviously grown either (no new dated items older than
  those surfaced this pass).

**2026-07-24: stability-milestone convention BUILT + wired — active follow-ups (queued, not done):**

- **Milestone population is standing per-project triage work, NOT a
  bulk-invent.** `milestone-audit.sh` shows **11 projects `missing`** a
  `## Stability milestone` section. Populate each incrementally during that
  project's own `/ideate <name>` or nightly triage pass — the bar is a
  per-project judgment call, not something to invent in one sweep. Do the
  projects realisateur is about to build against first, and the
  stable-vs-dream-flagged ones (nine-speakers/sequestria/senechal) early,
  since their `_paced.conf` weight already depends on that judgment.
- **The 2 `no-focus` cases are edge cases, not population targets:**
  `aedile` (no git repo — migrated/defunct) and `scheduler` (keeps its
  FOCUS under `.scheduler/`, not `.claude/`, because it's the *engine*, not
  a scaffolded project). `milestone-audit.sh` assumes `.claude/FOCUS.md`, so
  it reads scheduler as no-focus — a known limitation. **Open question:**
  does the engine participate in the milestone convention at all, or is it
  exempt? Decide before treating scheduler's no-focus as a gap to fix.
- **Reweight decision (the one open pacing call):** scheduler + realisateur
  stay at weight 3 until park-by-default triage runs on **≥1 live pass and
  proves out**, then drop toward 1 per `_paced.conf`'s exit note. Waiting on
  evidence, not on a decision.

**2026-07-23 (`/ideate` — vision-debt strategy, standing doctrine):**
The honest number (scheduler DESIGN-NOTES 2026-07-23): intake is zero-cost
and unbounded (`scheduler -i`), clearing is quota-gated and shared 12 ways,
so the backlog diverges at **−6 to −10 items/week regardless of build
speed**. Conclusion, decided this session:

- **This is a queue-stability problem, not a throughput one.** You cannot
  out-build a free, unbounded idea faucet. Weight bumps slow divergence;
  they never reverse its sign. **Pruning (admission control) is the only
  lever that changes the sign** — it moves arrivals *out of the active set*
  at near-zero cost instead of building them down.
- **Backlog count is the WRONG health metric.** A reservoir fed for free
  *should* grow (already settled: chezz 2026-07-20, a growing backlog is
  the expected shape). Vision debt is only debt when parked ideas
  masquerade as active commitments. Track instead: **(1) active/build-now
  set size per project (cap it), (2) is the oldest *build-now* item
  draining.** Parked-reservoir size is not tracked as debt.
- **Primary discipline = milestone-gated parking.** Each project gets **one
  current stability milestone** (its "stable v1 core" bar — this is the
  recovered "ready to go on its own"/VSM status). Realisateur's triage
  default becomes: *is this idea within the current milestone? If not →
  PARK it* (visible, zero dev cost). Parking is the load-bearing act, not
  building. QUEUED next build (nightly-batch, not this pass): a per-project
  stability-milestone convention + the park-by-default triage step.
- **The weight-3 bump is a BOOTSTRAP, not steady-state.** scheduler +
  realisateur at weight 3 only buys time to stand the pruner up. **EXIT:
  drop both toward 1 once the milestone convention exists AND triage parks
  by default** (mirrored in `_paced.conf`'s comment so it can't silently
  become permanent skim on operational slack).
- **Synchronicity to unify, not build twice:** this "active vs. parked vs.
  waiting" status need is the *same* as the parked `Spec-out-a-more-
  principled-eco` idea (BLOCKERS.md blocking/waiting/fyi taxonomy). One
  status vocabulary should serve vision items and blockers alike — routed
  to scheduler via `scheduler -i scheduler` this session (it's a
  scheduler-convention proposal, front-door per ideate.md §5).

**2026-07-23 (`/ideate` reform pass — three standing decisions):**

- **Identity: realisateur is a steward with sensory organs, not a second
  engine.** The doctrine is "scheduler runs things; realisateur
  perceives → judges → records." Its three offline deterministic auditors
  (`bin/hygiene-lint.sh`, `bin/ecosystem-survey.sh`, `bin/incubation-
  audit.sh`) stay in this repo *deliberately*: they are realisateur's
  senses, not scheduler mechanism misfiled here. The test for what belongs
  in realisateur vs. what goes through scheduler's `-i` front door: does it
  feed a *judgment* (perception/triage/prioritization → realisateur) or is
  it *engine mechanism* the ecosystem runs regardless of judgment
  (timing/dispatch/templates → scheduler)? The auditors inform judgment;
  they don't act on their own. This resolves the "pure mechanism living in
  the vision repo" tension by naming the seam rather than moving code.

- **Weighting reframes around "near a stable core" vs. "bigger still-forming
  dream" (supersedes the incubation-audit graduation framing).** `_paced.conf`
  weight is higher for ideas close to a defined, near-term shape (safe to
  iterate fast unattended) and lower for ideas likely to morph before
  anything built survives (slower pace, NOT "don't build"). Applied
  2026-07-23: **nine-speakers 2→1** — its physical-rig half is a forming
  dream, so the 2026-07-22 "graduation candidate = clean build momentum"
  call conflated momentum with nearness-to-stable. **groc-mangr stays 2**
  (conventional app, no forming-dream flag; re-confirm at next audit). The
  broader incubating/graduation weights the audit applied remain a separate
  open question — see QUESTIONS.md.

- **git-as-archive: consciously parked (see Backlog bullet below).** The
  empty-root-when-idle aesthetic is a real "needs its own design pass," not
  a near-term build. Recorded as deliberately deferred so it stops reading
  as forgotten.

**2026-07-22: `/ideate` added — realisateur's interactive vision/triage
counterpart to `/nightly-batch`, cross-project by design.** Refines the
scheduler/realisateur relationship being worked out this session:
scheduler stays a pure mechanism (timing, pacing via `_paced.conf`'s new
`weight` field — see `docs/priority-weight.md` in the scheduler repo);
realisateur owns interpreting vision — feature requests, cross-project
synchronicities, and "stable build vs. bigger dream" pacing judgments
(vision debt, named 2026-07-20 in `chezz/.claude/commands/ideate.md`
4.5, from the user's own words: *"my ideas outpace implementation of
stable versions so the target is always moving"*). `/ideate` is
interactive-only (surface/ask/record/queue, never build/scaffold — that
stays `/nightly-batch`'s job), works ecosystem-wide by default or scoped
to one project via `$ARGUMENTS`, and is the vehicle for the cross-write
relationship: realisateur writes tagged `(realisateur)` entries directly
into another project's own FOCUS.md/QUESTIONS.md, distinct from that
project's own `(nightly-batch)`/`(bug-sweep)` entries. `bin/ecosystem-
survey.sh` (new, offline-first, no AI — reuses `scheduler status
<project>` per registered project plus a "oldest open dated idea"
ecosystem ranking) backs both this command's step 1 and
`/nightly-batch`'s own orient step now. See `.claude/commands/ideate.md`
for the full shape, including the explicit oldest-first-override
principle (a newer idea CAN jump an older parked one when justified —
state why, don't reorder silently).

Current focus: process whatever's sitting in the inbox (repo root artifacts
not yet archived — see `.claude/commands/nightly-batch.md` step 1 for how
to tell) and turn each viable idea into a real, scaffolded project wired
into the scheduler ecosystem the same way realisateur itself is.

realisateur has no web tracker (like `crt`), so there is no
`NIGHTLY:`-flagged-report convention here — scope is purely this file plus
whatever's physically sitting in the inbox.

**Policy: build maximally autonomously.**

- Pick the most reasonable interpretation of a dropped artifact and act on
  it — scaffold the project, don't just write up what it might be.
- A new project gets its own directory under `~/Documents/Projects/`, its
  own git repo, and (if it's an agent/codebase project that would benefit
  from unattended iteration) its own scheduler registration, following
  exactly the process `SCHEDULER.md` documents for realisateur itself.
- Archive the source artifact once acted on (or once a real decision was
  made not to act on it) so it's not re-processed next time.
- Flag what got built and why in `.claude/QUESTIONS.md` and in the report
  — the flag IS the review point, not a request to build.

- **2026-07-22 (from wtul questions-pane diagnosis):** `vkv-inventory`'s
  `command-nightly-batch.md` never runs `collect-feedback.sh --consume`
  against its own `.claude/QUESTIONS.md`, the same append-only-reply gap
  just fixed in wtul's and the scheduler's own nightly-batch commands (see
  scheduler's `.scheduler/FOCUS.md` backlog for the full writeup). Add the
  same Orient-step fix to vkv-inventory's command file, or confirm it's
  already covered elsewhere before skipping it.

## Realisateur's own process (not inbox ideas — see nightly-batch.md step 3)

- **2026-07-20: "Look into scheduler's idea logic, unite with the habit of
  echoing ideas into text files here" — already solved, no project
  needed.** `scheduler -i realisateur "idea text"` (`~/.local/bin/scheduler`,
  `cmd_idea()`) already special-cases realisateur: instead of writing into
  a FOCUS.md backlog section like every other registered project, it drops
  a real `<slug>-<timestamp>.idea` file at this repo's root — the exact
  same artifact shape as manually echoing a note here. The CLI is the
  unification; nothing new to build. One real gap the CLI's own output
  names: it does NOT `git add`/`commit`/`push` for you, so a dropped idea
  sits invisible to the scheduler's dedicated clone until someone commits
  it by hand (this bit the first three ideas — see `f8f244d`/`7886409`).
  Worth raising with Zach directly: either fold the commit+push into
  `cmd_idea()` itself (small, safe, lives in `~/.local/bin/scheduler` —
  outside this repo), or just keep it a manual step. Source note archived
  as `archive/look-into-scheduler-s-idea-log.idea`.
  **Follow-up, same day: fixed on the scheduler side** — `cmd_idea()` now
  auto-commits (never auto-pushes) for the realisateur path too, same as
  every other project's idea-drop.

- **2026-07-20 (Zach, via `scheduler -i realisateur`): realisateur is
  meant to eventually own abstract visioning across projects, not just
  scaffolding — see the inbox item this generated
  (`look-at-Document-Project-Archi-*.idea`, chezz's `/ideate` command as
  the reference model) for the concrete proposal.**
  **PARTIALLY SHIPPED 2026-07-23 (reconciled):** the
  `/ideate`-for-every-project half of this landed 2026-07-22 (built when
  prompted, not unprompted) — see this file's top entry and
  `.claude/commands/ideate.md`. What remains OPEN from the source idea:
  whether `scheduler -i` should route through realisateur to triage
  whether a dropped note is a next-action-item vs. a vision to incubate
  (the "is scheduler's `-i` proper?" fork) — still unbuilt, still parked
  per scheduler's "hardening first" priority; do not build that
  `-i`→realisateur hook unprompted. What IS worth carrying forward
  regardless of that larger design fork: the "vision debt" pattern named the same session (ideas
  arrive faster than any implementation cadence can stabilize them) —
  named explicitly in chezz's own `ideate.md` now. If realisateur ever
  does take on abstract-visioning ownership, this pattern — making the
  gap between ideation and stable implementation visible rather than
  letting a queue grow silently — is a concrete design input for that
  role, not just chezz's problem.

- **2026-07-24 (`/ideate`): BLOCKERS.md sweep-ownership made explicit; two
  orphaned vim swaps investigated, no data lost.** Zach hit two issues
  doing a manual clear of scheduler's `BLOCKERS.md`: (1) what looked like
  a simultaneous-edit conflict, fixed by hand via git; (2) many entries
  reading as stale despite being answered days ago. Root cause of both:
  two vim sessions (pids 437104, 472803, both dead by the time this
  session checked) had `BLOCKERS.md` open around the same time and
  neither exited cleanly, leaving `.BLOCKERS.md.swo`/`.swp` behind —
  recovered both non-destructively (`vim -r ... -c 'w! <scratch>'`),
  diffed against the committed file, confirmed no real unsaved content in
  either (one was a duplicate-header recovery artifact, the other an
  older pre-edit snapshot); both deleted. Separately: `BLOCKERS.md`'s own
  header already said resolved entries are cleared by hand, but never
  said whose hand — nothing in `collect-feedback.sh`/the auto-commit vim
  hook aggregates INTO the file or prunes a RESOLVED/RETRACTED marker
  automatically, so entries just accumulate until someone sweeps them.
  Made that explicit in `BLOCKERS.md`'s own header (scheduler commit
  `5041986`): the sweep is `/ideate`'s own triage job. Pruned this
  session's stale set (aedile crontab, chezz/wtul deploy-key retraction,
  crt OctoPrint/VM-hardware-check/barrel-diameter) into
  `## Recently resolved` as a worked example.

## Reusable pattern worth applying to scaffolded projects: offline-first checks

**2026-07-22 (scheduler side):** `bin/scheduler status <project>` was
built as the reference implementation of a pattern worth carrying into
any project realisateur scaffolds — see the scheduler repo's
`docs/offline-first-checks.md` for the full writeup. Short version: build
a "how's this doing" check entirely out of deterministic scripts (git
status/ahead-behind/diverged, `bin/collect-feedback.sh` against any
report/blockers file, an awk pass over a QUESTIONS-style file, a log
tail) with **zero AI cost by default**, then layer AI on top only as
strictly optional extras — a one-shot read-only `claude -p` summary
(`--claude`) or a live session preloaded with the same report
(`--interactive`). If a new scaffolded project ends up with its own
FOCUS.md/QUESTIONS.md/report convention (i.e. follows this repo's own
shape), consider giving it the same three-mode status check rather than
defaulting straight to "spin up claude to check in" — reuse
`bin/collect-feedback.sh` directly (it's generic) and copy/source
`report_divergence()` from `bin/scheduler` for the git-health part.

## Backlog (recovered 2026-07-20 — see note below)

Zach's own reply, written directly into `~/reports/realisateur/LATEST.md`
after the first real nightly run, was NOT actually wired to reach this
project (that file gets wholly overwritten each run, and only
`.claude/QUESTIONS.md`'s `> ` convention is contractually read/acted on —
see `scheduler`'s own `docs/feedback-tags.md`). Recovered here by hand
before it was lost to the next overwrite:

- **Idea-incubation "steward"/"husbandry" logic, eventually.** For now,
  ideas auto-registering with the scheduler on scaffold (current
  behavior) is fine. Later: spend a few cycles establishing whether an
  idea is actually viable BEFORE promoting it to full autonomous
  development — aware of the Stafford Beer viable-systems-model framing.
  Wants an explicit project status meaning "ready to go on its own."
  Related, also later: senescence/retirement logic — a way to retire a
  project either because it never got off the ground or because it
  matured out of active development.
- **Prefer git-as-archive over a literal `archive/` folder, eventually.**
  Ideal aesthetic: this repo's root is empty when no ideas are currently
  incubating — an idea lives in the working tree only while incubating,
  then the fact that it was ever here lives in git history rather than a
  permanent `archive/` directory. Scheduler-owned files (FOCUS.md etc.)
  staying under a dot-prefixed folder (`.scheduler/` per the model
  scheduler itself uses) helps keep that clean look. Not designed
  further than this — a real "how" needs its own pass.
  **2026-07-23 (`/ideate`): consciously PARKED, not dropped.** Decided
  this is a genuine design pass of its own (idea-lifecycle in git history
  vs. a visible folder, plus moving scheduler-owned files under
  `.scheduler/`), not something to half-build inline. Revisit as a
  dedicated pass; the aesthetic goal above stands as the target.
- **The only real stop-and-wait bar: something that can't be reverted.** A
  commit, a branch, a new scheduler registration, a local bare git remote
  — none of these block you. What does: a real message to a person outside
  this loop, spending real money, deleting something with no backup, or
  registering against a REAL GitHub remote with credentials that could leak
  (prefer a local bare remote per `SCHEDULER.md` unless a GitHub remote is
  clearly already the right call). If genuinely unsure, that's the
  `.claude/QUESTIONS.md` case — but err toward "revertible, proceed."

## Fable review (2026-07-25)

<!-- Appended by realisateur/fable-like/inject-suggestions.sh. Full context: fable-like/FABLE_REPORT.md. Triage these like any dated entries; delete freely. -->

- **2026-07-25 (fable-review):** split doctrine from journal — standing decisions (identity seam, vision-debt math, autonomy bar) into a DOCTRINE.md edited in place; .claude/FOCUS.md (56KB) stays a lean dated log with monthly roll-ups
- **2026-07-25 (fable-review):** create NAMES.md (with senechal) and check it before every scaffold — two unrelated bibliothecaires exist right now (crt's parked catalog split vs the inbox "page 92" idea)
- **2026-07-25 (fable-review):** build the two queued lints (hygiene-lint shared-host-footprint row; milestone-format check that says "join these two lines" instead of UNRECOGNIZED) — own doctrine: guards over reminders
- **2026-07-25 (fable-review):** file-structure normalization is stalling because it's batch-sized; execute one move per /ideate pass, scheduler out of "Project Archive" first
- **2026-07-25 [batch] hygiene-lint: stale verified-claims row** — BUILD-DISCIPLINE.md now requires that a written claim about system state carry `# verified <date> via <command>` (`3be6629`). Make it mechanical rather than a reminder: `bin/hygiene-lint.sh` flags any `verified <date>` stamp older than ~7 days, and flags config comments that assert system state with no stamp at all. The incident: an unstamped "confirmed 2026-07-24: no crontab exists there" in `schedule/_paced.conf` outlived its truth by a day and became an ecosystem audit's #1 finding. **DONE 2026-07-26 (`/nightly-batch`, `cc8a14e`)** — built; see this file's 2026-07-26 ~21:25 entry.
- **2026-07-25 [batch] hygiene-lint: stamped-checklist drift** — the BUILD-DISCIPLINE checklist gained three rows on 2026-07-25; copies already stamped into each project's CLAUDE.md now lag the baseline and nothing detects the divergence. **DONE 2026-07-26 (`/nightly-batch`, `cc8a14e`)** — built; see this file's 2026-07-26 ~21:25 entry.
- **2026-07-26 [batch] hygiene-lint: task-shaped entries in BLOCKERS.md** — mechanical half of BUILD-DISCIPLINE pattern 13. Flag lines in scheduler's `BLOCKERS.md` matching task-shaped language (`filed for an async pass`, `not done`, `not completed`, `TODO`, `next step:` without a `> ` answer or an OBLIGATION/dispatch pointer) — BLOCKERS.md is not a work queue, so anything task-shaped sitting there is pattern-13 rot by definition. Signals-not-verdicts like every other row. Incident: the 2026-07-24 `.scheduler/` migration decision sat undispatched there for 2 days while three projects re-derived it. **DONE 2026-07-26 (`/nightly-batch`, `cc8a14e`)** — built; see this file's 2026-07-26 ~21:25 entry.

## 2026-07-26 (interactive, Zach-directed): the steward gap, and the treadmill

**The audit that prompted it.** Zach asked whether the batch work was
real progress or a loop. Both, and the split matters: every commit was
genuine tested code, but on 2026-07-26 seven `/nightly-batch` runs with
an empty inbox produced five new scripts *for realisateur's own workflow*
and **zero** commits into any of the twelve scaffolded projects. Last
downstream commit was `d7e8196`, 2026-07-25. The organ that exists to
perceive the ecosystem spent the night perceiving itself.

**Named cause:** `/nightly-batch` is inbox-driven, and an empty inbox is
now the normal state. With no artifact, the pass looked for work in the
only place left. Fixed mechanically as step 2a of the command: empty
inbox now means a **steward pass** whose output is routing, not building,
and authoring new realisateur tooling is explicitly out of scope on those
nights. The sixth survey needs a stated reason from outside the loop.

**The steward gap Zach named** (realisateur should be watching other
projects' progress, weight-0 incubated projects, big vision backlogs):
none of the four surveys read `_paced.conf`'s `enabled` flag. They all
iterate `schedule/*.conf` and report as though every project were
running. So a project could sit off indefinitely while `milestone-audit`
called its milestone `in-progress`. **Exhibit: 9 of 18 paced participants
are `enabled=0`, including `crt` at weight 3** — the highest-weight
project in the ecosystem, dark, with 32 open ideas stranded behind it,
and no survey saying so. Built `bin/steward-survey.sh` (`78f6c33`).
52 open ideas total sit behind a closed valve.

**Two orphans wired, both built and never called.** `focus-commit.sh`
(`7e49b0e`) and `closeout-lint.sh`/`/cloture` (`3913d7c`) were textbook
build-but-don't-wire against this project's own checklist. `/cloture` is
now installed (`c33db10`); `focus-commit.sh` is now the mandatory
FOCUS/QUESTIONS write path in both commands.

**Correction to `c33db10`'s commit message, recorded because it is
wrong in the record.** It claims the sensitive-file gate keys purely on
path, so "no future session of any kind can finish this." False: the
gate is context-sensitive. After Zach stated permission in-session, the
same `sed -i` that had been refused went through. The staged banner's
"needs a human session" was closer to right than my correction of it.
The durable lesson is narrower: an *unattended* pass cannot author or
install a command file, so staging in `.scheduler/` plus a named install
step remains the right convention — and the still-open question from
`3913d7c` (standing convention, or should nightly-batch never author
command files?) is still worth answering.

**Machine-config notification is a script now, not a promise.**
`bin/notify-senechal.sh` files through `scheduler -i senechal` and
verifies the note reached the remote. Prompted by this session paying
off a cross-write that had been deferred, recorded as owed, and left for
a later session — prose decaying exactly as UNIVERSE.md says it does.
Ownership restated: realisateur owns what it generates, senechal owns
knowing it exists.

**Open for the next pass, NOT decided here:** `crt` dark at weight 3 is
the loudest row in the new survey. It was switched off deliberately, so
re-enabling is a stated decision, not a batch one — see QUESTIONS.md.

**2026-07-27 (via /ideate): promote `/ideate` and `/cloture` to callable from
any project's own interactive session, not just realisateur's.** Zach's
ask, from inside a senechal session wanting `/ideate`/`/cloture` there
directly instead of switching to a realisateur session and scoping with
`/ideate senechal`.

Diagnosis: `ideate.md`/`cloture.md` are already written project-
agnostically (take a `[project-name]` arg, speak of "this repo" not
"realisateur"). The actual blocker is narrower — five survey scripts
they shell out to (`ecosystem-survey.sh`, `milestone-audit.sh`,
`steward-survey.sh`, `hygiene-lint.sh`, `precipitation-scan.sh`) still
live only as `bin/*.sh` inside realisateur's own repo, called with
repo-relative paths. Run with cwd = another project, those paths
resolve to nothing. `notify-senechal`/`check-project-busy`/
`focus-commit` already went through this exact promotion (now on
`PATH` via `~/.local/bin`) — this is the same move, just for the
remaining five.

Milestone chain:
1. (buildable now) Promote the five survey scripts to `~/.local/bin`
   as thin wrappers (mirror how the three cross-write utilities were
   done), confirming none of them assume cwd == realisateur internally
   (they iterate `schedule/*.conf` already, so likely fine, but verify
   — e.g. do any of them read a relative `../` path back into
   realisateur's own `.scheduler/` for their own bookkeeping?).
2. (buildable now, depends on 1) Copy `ideate.md`/`cloture.md` into
   `~/.claude/commands/` (global) so any project session gets them.
   Confirm they don't need realisateur-specific env (e.g. do they
   ever assume "this session's own FOCUS.md" means realisateur's,
   when invoked with no project arg from inside a different repo's
   session? `/ideate` with no arg means "full ecosystem sweep" —
   that reading holds regardless of which repo the session's cwd is
   in, so should be fine, but re-check before shipping).
3. (not yet started) Decide whether realisateur's own repo-local
   `.claude/commands/ideate.md`/`cloture.md` should then be deleted
   (single source of truth, global) or left as a repo-local override
   — a stated decision, not implied by doing 1–2.

This is real build work (promote scripts, verify no hidden cwd
assumptions, place two files), not a design fork — filing it as a
`(batch)`-shaped task rather than building it in this interactive
session, per Zach's own framing ("file as batch work").

## 2026-07-27 (`/ideate`): gardien's scope widens to cross-host git hygiene — recorded in gardien's own FOCUS.md, not duplicated here

Zach named a real recurring-failure class (dirty trees, merge conflicts,
missing lock-outs) as lacking a proper owner and proposed gardien —
scope widen, not a new project. Confirmed against what already exists:
`check-project-busy.sh`/`focus-commit.sh`/`hygiene-lint.sh`/
`closeout-lint.sh`/`session-marker.sh`/BUILD-DISCIPLINE.md already cover
this ecosystem-wide from realisateur's side, advisory-only — the actual
gap, per Zach: (1) enforcement not just scanning, (2) no single rollup
of current dirty/stranded/locked state, (3) no cross-*host* git-state
awareness the way gardien already has cross-host *file*-state awareness
for backup. Answer: widen gardien for the cross-host sensing half;
enforcement-gate ownership (gardien vs. realisateur vs. scheduler) stays
an explicitly open follow-on question, not decided this session.

Full vision/milestone-chain/blockers written into gardien's own
`.claude/FOCUS.md` (pushed `5088f3b`) — read there, not mirrored here.
Deliberate park-by-default override, stated in that entry: gardien's
current RAID milestone is hardware-blocked (Pegasus 2 R4), this new
track isn't, so it's active rather than parked despite being beyond the
declared bar.

Nothing built this session — vision/milestone/blockers recorded only,
per `/ideate`'s own posture.

## 2026-07-27 (`/ideate`): Law 3's catabolic pass gets an ownership model — hybrid, per-project self-retirement + realisateur supervision + bibliothecaire as archive, PARKED

**Vision.** `UNIVERSE.md` Law 3 named the gap 2026-07-25 ("Queued, not
built: Catabolic pass") but assigned no owner, and the steward-survey
shows the cost compounding: 91 stranded items in scheduler, 41 in
senechal, 24 here, 9 in bibliothecaire, all growing, none shrinking.
Zach's own framing, asked directly this session: prose is getting huge
and agents will struggle to stay coherent across repeated writes/
rewrites to the same FOCUS.md/QUESTIONS.md files — who moves prose into
mechanism, who retires it, does bibliothecaire have a role. Decided
model, Zach's own words: **"per project responsibility using
realisateur based tools, realisateur has the job of supervising,
ensuring compliance across repos, bibliothecaire only narrowly expands
to include archiving prose retirements i.e. projects and realisateur
global delegate to bibliothecaire as they clean themselves up."**

Three roles, explicitly split:
1. **Each project self-retires its own FOCUS.md/QUESTIONS.md** — using
   realisateur-authored tooling (not a service call to another repo),
   the same shape as `focus-commit.sh`/`check-project-busy.sh` today:
   mechanism lives in realisateur's `bin/`, promoted to `~/.local/bin`,
   invoked *by* each project's own `/cloture`/nightly-batch pass.
2. **realisateur supervises/audits compliance across repos** — an
   extension of what `hygiene-lint.sh`/`ecosystem-survey.sh` already do
   (advisory scan, not enforcement), not a new authority. Realisateur
   doesn't do the retiring itself project-by-project; it senses whether
   retiring is happening and flags when it isn't (a `[stale-prose]` or
   similar signal, same family as `[dispatch-parity]`/`[exec-bit]`).
3. **bibliothecaire narrowly widens to be the archive destination** —
   when a project retires prose (compress/summarize an old FOCUS.md
   section), the retired material is *handed to* bibliothecaire rather
   than deleted outright, so retirement is move-and-compress, not
   destroy. This is a third wing alongside (a) the cybernetics quotes KB
   and (b) crt's book catalog — narrower than "bibliothecaire manages
   all ecosystem prose," which was NOT decided; bibliothecaire is a
   receiving archive, not an active summarizer running against other
   projects' live files.

**Milestone chain** (all not-yet-started — this whole line is parked,
see below):
1. Design the self-retirement mechanism's shape: what triggers it (age?
   size threshold? explicit `/cloture` step?), what "retired" produces
   (a dated archive file? a one-line summary replacing N lines of
   resolved detail?), and the handoff format to bibliothecaire.
2. Build it in realisateur's `bin/`, promote to `~/.local/bin` per the
   existing cross-write pattern (`notify-senechal.sh` etc.).
3. Wire the compliance-audit signal into `hygiene-lint.sh` or a sibling
   script.
4. Wire bibliothecaire's receiving side (where retired archives land,
   what if anything it does with them beyond storage).

**Blockers.** None active — **explicitly parked this session** (Zach's
own call: real but not blocking anything active right now, revisit once
a concrete pain point — e.g. an agent losing coherence across a huge
FOCUS.md — actually happens). Not required for realisateur's current
declared milestone (every project has a stability milestone + park-by-
default triage holding across passes), so park-by-default triage
applies cleanly: this doesn't unblock the current bar, it's beyond it.

Mirror recorded in bibliothecaire's own `.scheduler/FOCUS.md`, same
date — the narrow-widen decision affecting bibliothecaire's own scope
is written there directly, not just referenced from here.

## 2026-07-27 (`/ideate`, interactive, Zach-directed): catabolic pass + multi-writer-FOCUS regulator promoted from PARKED to active

**Stated override of park-by-default (§4/§4.5), same shape as the
2026-07-25 guard-set promotion above (line ~155).** Prompted by Zach
asking directly whether the ecosystem's cross-project friction ("get
these organs to properly synergize") constitutes its own milestone.
Checked against the mechanism that already answers this
(`PRECIPITATION.md`'s five-signal ladder) rather than declaring a new
ad-hoc "synergy sprint" — a blanket sprint milestone would itself be the
silent-reorder/hub pattern the ladder exists to prevent (the same
session's `precipitation-scan.sh` run suppressed an omnibus HUB entry
for joining >10% of the corpus, for exactly this reason).

Two concrete signals fired, not a vibe:
1. **Re-arrival, same shape** — this concern was named 2026-07-25 (Law
   3), given an ownership decision 2026-07-27 (this file, entry above),
   and raised again today in the same shape (cross-project coherence
   under concurrent ticking work).
2. **Interface cluster** — `precipitation-scan.sh` report C surfaced a
   live 8-entry/5-project cluster (realisateur, aedile, gardien,
   scheduler, senechal) converging on one unregulated interface this
   session, independent of the question being asked.

**What this promotes** (both previously `(parked)` in the entry above):
- Design + build the catabolic-pass self-retirement mechanism
  (trigger, output shape, bibliothecaire handoff format).
- Design + build the multi-writer-FOCUS-file regulator (honest
  attribution + live-session probe on scheduler's autocommit-watcher
  half; `focus-commit.sh` already covers realisateur's half).

**What this passes over:** the 5 projects still missing a declared
milestone (groc-mangr, nine-speakers, sequestria, vim-arcade,
vkv-inventory) remain the actual blocker on realisateur's own current
bar ("every project has a declared milestone..."). This promotion does
NOT unblock that bar — it's a stated exception, same as the
2026-07-25 guard set was.

**Delta of promotion, explicit (asked directly this session):** this is
a prose/status change, not a mechanism change — park-by-default and its
promotion clause already cover this case by design. No new script, no
`_paced.conf` weight change. Concretely: two status tags move from
`(parked)` to active with this rationale; consequence is these become
eligible for the next `/ideate`/nightly-batch pass to actually spec,
instead of being skipped by park-by-default triage. Under the prior
(parked) status, re-admission had no target date — it would have waited
for realisateur's current milestone to be *reached* (all 18 projects
declared + triage proven across >1 pass), which is unscheduled and
plausibly weeks out given the 5 missing-milestone projects above.

**The cluster itself, separately** — per PRECIPITATION.md, its members
are NOT individually promoted; it is filed as its own regulator-naming
question, open: `[iface: cross-project agent/dispatch coordination]`
(windows/agent/dedicated/direction — spans DIRECTOR_LOOP_OVERRIDE,
gardien backup scheduling, lid-close power settings, scheduler stranded-
commit fixes). What the missing regulator actually is stays undecided —
flagged for a future `/ideate` pass, not resolved here.

## 2026-07-27 (Zach-directed, /cloture session): every registered project needs an uncommitted-file intake path, not just realisateur

Found via `bin/closeout-lint.sh`: `wtul` had `CD-500_500B_Manual_RevG.pdf`
sitting uncommitted at its repo root, effectively invisible to that
project's own batch (`wtul-batch` is backlog-driven off FOCUS.md only,
no repo-root artifact scan). Resolved for this one file directly
(`.scheduler/QUESTIONS.md` filed in wtul, `4bbf097`, pushed) — but Zach's
own stated intent is broader: **dropping an uncommitted file into a
project's working tree is a normal, expected part of his workflow**
(`git commit` is not part of his ritual), and every project should have
*some* mechanism that folds those in, at minimum by getting them
committed rather than left as permanent dirty-tree residue.

Only realisateur currently has an inbox-scan step
(`nightly-batch.md` §2 — repo-root artifact -> infer -> archive ->
commit). It was never propagated as a standing pattern to sibling
projects. This is cross-project batch-process work (either realisateur's
own nightly-batch extends to audit/propose this for other projects, or
scheduler's steward pass tracks it) — not something to build inside this
closing session per cloture's report/route/don't-build posture.

**Proposed for a batch pass to pick up (not decided here):** survey
every registered project's `.scheduler/commands or .claude/commands`
batch script for whether it has *any* path that would notice/commit a
stray uncommitted file at its own repo root, and for the ones that
don't, either (a) adopt a minimal version of realisateur's inbox-scan
step, or (b) at minimum have `closeout-lint.sh`-style dirty-tree
detection trigger an auto-commit-with-a-question rather than just a
silent FLAG nobody routes anywhere. Which shape is right per-project is
a judgment call, not a blanket copy of nightly-batch.md — flag for
`/ideate` or a scheduler steward pass, not a straight build.

## 2026-07-27 (`/nightly-batch`, 15:00 pass): inbox full, eight findings/requests

**Inbox state:** 8 `.idea` artifacts, oldest dated 2026-07-26 23:40. Six are realisateur feedback/findings; one is a cross-project protocol clarification already handled (senechal c18324c, ESTATE.md); one is a vision idea for maitre (too vague to scaffold yet, left in inbox). Processed findings below.

- **2026-07-27 [batch] hygiene-lint: SCHEDULER_SUBDIR hardcoding.** From senechal finding: scripts are hardcoding `.claude/FOCUS.md` or `.scheduler/FOCUS.md` paths instead of calling the scheduler resolver — realisateur/bin/notify-senechal.sh (line 100) does `.claude`, closeout-lint.sh (line 45) does `.scheduler`, incubation-audit.sh (85-88) probes both, while milestone-audit/weight-audit/steward-survey each reimplement the conf read correctly. Violates BUILD-DISCIPLINE "config read from one source." **Requested rows:** (1) FLAG any script containing path literals for FOCUS.md instead of calling resolver; (2) FLAG any registered project whose declared SCHEDULER_SUBDIR doesn't match disk. **Blocker:** depends on scheduler exporting `scheduler _focus-path <project>` (filed to scheduler same pass, not yet live). Sequenced after that gate ships.

- **2026-07-27 [batch] Audit guard family for pipefail/SIGPIPE.** From realisateur inbox: check-project-busy.sh and focus-commit.sh should be audited for the same bug fixed in notify-senechal.sh (aebf5f4) — `producer | grep -q needle` returns 141 when grep exits on first match but producer is still writing, under `set -o pipefail`. Timing-dependent (only bites once input is large enough), invisible in hand testing. focus-commit is higher priority (verifies multi-writer file, worst blast radius on false negative). Suggested sweep: (1) every `| grep -q` / `| head -c` early-exiting consumer under pipefail; (2) any check whose failure path cannot distinguish "genuinely failed" from "could not verify" — fix pattern: read into variable, match with here-string, slice with bash parameter expansion instead of pipeline.

- **2026-07-27 [batch] notify-senechal.sh robustness.** Three related findings in inbox (notify-senechal false FAILs from 2026-07-26/27): (1) step-2 happy-path cries wolf on every successful note — verify CONTAINMENT (`git merge-base --is-ancestor $sha @{u}`) instead of ahead-ness, keeps die() for genuinely-not-committed case. (2) landed() false FAIL on ahead==0 path — needs `git fetch` before checking upstream ref (ahead>0 path does it, ahead==0 doesn't). (3) comprehensive diagnostics: landed() should print what it compared (sha of @{u}, whether `git show` produced output, exact probe, first matching line if any) so failures are diagnosable not archaeological. Add bounded retry (2-3x with short sleep) rather than single-shot check — this guard has cried wolf twice in two days, and false-positive training corrupts the signal it exists to raise. Include regression test for happy-path success.

- **2026-07-27 (doctrine) BUILD-DISCIPLINE pattern 16 — "a correct refusal that nothing retries."** From scheduler interactive session: a guard declines to act (is RIGHT to decline, logs loudly) but nothing ever revisits the decision, so the refusal is permanent by omission. Distinct from pattern 8 (warn-then-continue proceeds) and pattern 13 (decision with no dispatch path). Live exhibit: scheduler-dev-cycle.sh dirty-tree merge fallback logs loudly each time but nothing retries, leaving 14 commits stranded across 2026-07-25/26. Rule shape: a fallback that declines to act must name what retries it, or it is a dead end wearing safe-fallback clothes. Scheduler fixed this in reconcile_prior_cycles() (dd086bb); add to BUILD-DISCIPLINE.md with the rule and the pattern number.

- **2026-07-27 [batch] closeout-lint.sh: cross-write dispatch integrity checks.** From CLOTURE-GAP finding: `/cloture` step 3 and step 5 don't verify filed work is resolvable where filed. Pattern 13 (decision without dispatch path) reappearing one layer up — not in work, but in closing rite meant to catch it. Three checks needed (offline, deterministic, no claude): (1) **DEAD-QUEUE CHECK** — for each project this session filed into, verify it's actually dispatching (present in a `_paced*.conf` AND its expires_at hasn't tripped). (2) **OWNER/LOCATION MISMATCH** — if a backlog row in project X names project Y as thing to change, FLAG it (row lives in X backlog but only Y can act). (3) **QUEUE DEPTH** — report (not flag) how many unconsumed inbox artifacts destination already holds and age of oldest — "filed" reading as "handled shortly" is failure of understanding; 8-deep behind an expired job is different claim. Optional/strongest: assert destination has a READER allowed to act (if constraints were machine-readable, (2) and (4) collapse into one).

- **2026-07-27 (record gap) c49c70d session-marker.sh.** From scheduler interactive session: realisateur `.scheduler/FOCUS.md` has no entry for c49c70d (session-marker.sh: record pid that outlives hook, pushed 2026-07-27). Repository carries a commit its own nightly cannot explain. Note: this was initially filed to scheduler FOCUS.md (WRONG — scheduler dev-cycle hard-bars touching files outside its own repo, and realisateur nightly-batch explicitly doesn't act on other projects' FOCUS items) but is realisateur's own work and belongs here. Added as a bare record, not queued work.

**NOT in scope (already resolved or belongs elsewhere):**
- notify-senechal fix aebf5f4 (pipefail/SIGPIPE) already pushed (senechal c18324c documented ownership split, ESTATE.md tracking dangling-shim generator request)
- maitre lilypond/harmony vision idea too vague to scaffold yet; left in inbox

**Surveys all re-run fresh:** ecosystem-survey.sh, milestone-audit.sh, hygiene-lint.sh (unchanged from yesterday, 31 FLAGs). Precipitation B/C read READ-ONLY per this command's stance. **Nothing stamped, reordered, or reweighted.**

**Blockers:** none on this pass's scope (all three queued guards are offline/deterministic). The SCHEDULER_SUBDIR lint depends on scheduler's `_focus-path` export, which is filed to scheduler not blocked here.

**2026-07-27 (interactive, `/ideate` — "what are my blockers, what's the vision, what's the potato dream after a week of autonomous grinding?"): potato's live-verify pass unblocked; cross-write filed in crt (`fe40cc6`).** crt has been grinding for real — 274 commits/7d, dispatching live from `_paced.dexter.conf` (not DARK; that reading was this morning's already-diagnosed false-DARK, see the entry above — steward-survey only reads mandark's `_paced.conf`). Tonight's own crt session (`da45280`) reconciled the ecosystem after a router change: potato is unchanged at `192.168.0.45` (no static-IP change actually landed — that premise carried into this session from earlier chat was wrong), reachable via `vkv_deploy_key`, and its `~/crt` was fixed from an orphan tar-deploy history to a real clone of `origin`. Net effect: the 4 stability-milestone checkboxes in crt's own FOCUS.md (wake-arm, handset-duck, capture-by-name, Book Game funnel — all "code done, needs live-confirm since 07-24") are now actually reachable, not just theoretically. Asked Zach directly: proceed with the live-verify pass now (confirmed) — recorded in crt's own FOCUS.md, not repeated here. Also cleared six stale 2026-07-24 QUESTIONS.md entries in crt about default-key ssh-auth rejection (superseded by the working `vkv_deploy_key` path) per Zach's answer. No new vision, no milestone change — this is the milestone's existing next step becoming actionable. Nothing scaffolded, no feature code written this session.

## 2026-07-28 (filed from bibliothecaire, Zach-approved 2026-07-27, deferred once for BUSY): the three-way disanalogy, and a fourth finding

Filed by bibliothecaire per its own FOCUS.md standing decision ("very
deep... deserves filing into realisateur for a vision pass, even a stamp
in UNIVERSE.md if realisateur agrees"). `check-project-busy realisateur`
reported BUSY on 2026-07-27 and the write was deferred, not skipped;
this run found it free.

**The finding.** Three of the concept briefs — `requisite-variety`,
`closed-loops` and `wu-wei` — independently land on the *same* missing
failure mode, each stated in its own concept's terms in that brief's
"Where it breaks" section. The three briefs and their quote ids:

- `briefs/requisite-variety.md` — `ashby-requisite-variety-1`, `-2`
- `briefs/closed-loops.md` — `ashby-closed-loops-1`, `-2`, `-3`
- `briefs/wu-wei.md` — `laozi-wu-wei-1`, `-2`, `-3`

Three unrelated primary texts, read separately, converging on one gap is
the kind of result that earns a doctrine pass rather than a brief.

**A fourth, found 2026-07-28 while closing the brief milestone, and it
generalises beyond bibliothecaire.** A run reported `sources/` as
"checked for un-used primary material: empty." It held twelve files,
including the primary text for the very concept the same milestone had
just declared unreachable. The probe had asked **git**, and
`sources/.gitignore` is `*` — so `git ls-files` and `git status` answer
"nothing here" truthfully and forever.

Named: **a probe answered by the index instead of the disk.** Its
signature is the one BUILD-DISCIPLINE already cares about — it fails
toward *silence* rather than toward an error, exactly as `2>/dev/null`
turns "denied" into "clean" — but the mechanism is new: the blind spot
was manufactured by the very rule the probe was inventorying. Any
project that inventories a gitignored directory, or asks a VCS what is
on a filesystem, has this bug available to it.

bibliothecaire's own answer is a guard, not a lesson:
`bin/validate-quotes.py --sources` / `--require-sources` reads the
directory with `iterdir()`, prints what it saw, and reconciles its
ledger AGAINST the disk rather than the reverse. On first run it found
three broken intakes that had been passing as held sources for a day,
including a **0-byte file** standing in for `stigmergy`'s primary text —
whose absence had been recorded as a paywall.

Filed with senechal the same session. Worth a UNIVERSE.md stamp
alongside the three-way disanalogy if realisateur agrees; both are
findings about looking, not about building.

**2026-07-28 (interactive, from bibliothecaire; `/cloture`): bibliothecaire's brief milestone MET, and a new named failure pattern filed for a doctrine pass — cross-writes in realisateur (`e68f06a`) and senechal (`312e028`).** bibliothecaire closed its concept-brief milestone (`65091c2`, `062a021`): 14/14 briefs, `--require-briefs` exits 0, 36 publishable quotes on `origin/main`. The last two concepts — `garbage-can` and `normal-accidents` — were built from the **primary** texts (Cohen/March/Olsen 1972; Perrow 1984), not the `verified-secondary` route the milestone had budgeted for them, because both PDFs had been sitting in that repo's `sources/` all along. **The pattern, and the reason this is filed here rather than left in one project's log: a probe answered by the index instead of the disk.** A run had inventoried `sources/` by asking git; `sources/.gitignore` is `*`, so `git ls-files` and `git status` answer "nothing here" truthfully and forever, and the answer was written into FOCUS.md as fact while the primary text for a concept the same milestone had just declared unreachable sat in the directory. Signature: it fails toward *silence*, not toward an error — the same shape BUILD-DISCIPLINE already names for `2>/dev/null` turning "denied" into "clean" — but the mechanism is new, in that the blind spot was manufactured by the very rule the probe was inventorying. Any project that inventories a gitignored directory, or asks a VCS what is on a filesystem, has this bug available to it. bibliothecaire's answer is a guard rather than a lesson (`bin/validate-quotes.py --require-sources`: reads with `iterdir()`, prints what it saw, reconciles its ledger AGAINST the disk, negative-tested four ways), and on first run it found three broken intakes that had passed as held sources for a day — including a **0-byte file** standing in for `stigmergy`'s primary text, whose absence had been recorded as a paywall. **No doctrine file was edited this session** — whether this earns a BUILD-DISCIPLINE checklist line or a UNIVERSE.md stamp, alongside the three-way disanalogy finding in the section above, is realisateur's own call and is left for a vision pass.

**2026-07-28 (interactive `/cloture`, from wtul): wtul's 49-question backlog was a structural defect, not a decision queue — pattern 17 filed as doctrine (`1497bc0`); cross-writes in scheduler (`68432cf`, `3170b81`, `6c95fab`, `a69ff05`), wtul (`5a92fb5`, `cbe597d`, `12aaf83`), senechal (`f4f45ab`, `b83cbb5`).** Zach asked why wtul had so many open questions and said he could not burn down 49. Three compounding causes, none of which was "too many decisions to make." **(1) Rate:** `wtul.conf` declares `BATCH_CRON="14 3 * * 3,6"` — "confirmed with Zach", and inert. There is no wtul crontab line; the paced rotation dispatches it at weight 2 on a 5-minute tick, so it ran **31 times in 4 days**, twice re-firing within 2 seconds of the prior run finishing, against a 2/week design intent. Weight cut to 1 (`68432cf`); the cadence lie itself is left standing on purpose, since fixing it flips the dispatch path too. **(2) Inlet:** `wtul-batch.md` step 5 *required* every run to append every feature built to QUESTIONS.md, while the outlet drained only on a human `> ` reply — an unconditional inlet against a human-only outlet. Step 5 now routes by kind (`5a92fb5`). **(3) The real defect, found only by reading the entries:** Zach had answered 28 of them on 2026-07-27, and `--consume` had destroyed the replies as a side effect of reading while run 28 closed zero entries — **pattern 17, "the reader that destroys what it read"** (`1497bc0`), guard landed same-day (`3170b81`), mirror-image human-drift hazard netted at the editor exit (`6c95fab`), `%%TAG` twin filed with scheduler (`a69ff05`). **The lesson worth carrying past wtul: the loudest count was the least informative number in the room.** "49 open questions" measured the inlet's rate, not the decision backlog — roughly 6 were questions. Reading six of them was worth more than any aggregate over all 51, and the aggregate is what nearly got the pile bulk-archived with 28 live unacted answers inside it. This is the fourth time this ecosystem's loudest survey output has been its wrongest (see the false-cluster, false-DARK, and false-LIVE rows), and the first where the misleading number was a **count of a queue this ecosystem writes to itself**.


## 2026-07-28 (interactive `/ideate` → build, Zach-directed): scheduler's roadmap given one telling, and four failures from one audit turned into four checks

Began as `/ideate` on scheduler (single-project scope), became build work
at Zach's explicit direction partway through. Named as such rather than
drifting: the posture change was stated, not assumed.

**Scheduler's vision was not missing, it was sixfold.** It lived in six
FOCUS.md sections plus DESIGN-NOTES.md, with three re-sequencings to
reconcile, so "is this idea on the path" cost a full read every time.
Written as one prose section, `## The long arc` (`670f48b`), in the
vision → milestone-chain → blockers shape `/ideate` step 4 prescribes.
The six sections stay as detail and receipts; nothing was deleted.

**The morning's four corrections, all the same shape — a claim held
without a probe:**
1. `decide.sh` option 3 (cron logging) billed itself "the deepest silence
   in the ecosystem" on the premise that nothing witnesses a cron
   dispatch. `journalctl -t CRON` returns 3812 lines and `/var/log/syslog`
   1624, including six `svc-vaporwave` entries, because line 9 of
   `50-default.conf` already matches `cron.*`. Retracted with witnesses
   (`87fc41c`); the machine was not touched. **Third instance of the
   probe-survey-headline pattern** — the audit's loudest finding was its
   wrong one.
2. I warned that the `*/15` sweep would launder 19 CLAUDE.md edits under
   Zach's name, quoting the backlog entry that describes that bug rather
   than reading the code. The honest-attribution fix had already landed;
   the 11:00 sweep committed as `hf7y` saying "author unknown". The
   warning was wrong in the same way the thing it warned about was wrong.
3. I recommended aedile's wrapper be moved onto `lib/sweep-loop-common.sh`.
   Reading it showed the bespoke design is deliberate and documented
   (shared org monorepo, dedicated clone, PR flow). The duplication worth
   fixing was ten lines, not the wrapper.
4. I reported the shared engine as hanging on `notify-send`; vkv's
   04:00 expiry had in fact recorded cleanly in 0s. Left unexplained
   rather than smoothed over (`q-756f82`).

**The prose trap, and why nothing caught it.** This session wrote a
100-line vision section and then, two messages later, described
bibliothecaire's `--require-briefs` as the guard against prose that
"makes the machinery feel understood" — without applying it to its own
output. Zach caught it. The structural reason, probed: `/ideate` step 4's
prescribed shape has no slot for a falsifier (`grep -E
'break|disanalogy|falsif|counter'` over `ideate.md` returns zero hits),
so producing an unfalsifiable vision entry *conforms to the spec*.
`--require-briefs` enforces exactly that slot but is scoped to
`briefs/`; `hygiene-lint` checks stamp drift; `closeout-lint` checks
durability. **A vision entry is the least-checked prose in the ecosystem
while being the most load-bearing — everything downstream triages against
it.** Queued as `PROSE-TRAP-GUARD-*.idea`, lint first and prose second,
deliberately: fixing prose decay with more prose is the recursion the
finding is about.

**Four checks for the four failures** (ecosim `2129a13`): `[dirty-writer]`
(a script that edits other repos with no commit path — caught
`install-silence-audit.sh`, which left 19 dirty trees and exited 0),
`[worktree-backed]` (a `~/.local/bin` entry resolving into a git
worktree — caught the live one), `[twin]` (the same file in two
projects), `[subrepo-invisible]` (aedile's monorepo path, which every
`[ -d $repo/.git ]` test skips — known since 2026-07-24, still live).
Added to the existing script rather than a sibling: writing a second
audit tool while fixing a duplicate-mechanism bug would have been the
same failure in the same commit. **`[twin]` failed its own founding case
first** — it scanned registered projects only and so missed the duplicate
that motivated it, which lives in a worktree; then over-fired once
worktrees were included, because a repo and its worktree share files by
definition. Both the miss and the over-fire are recorded in the file.

**Layer-don't-replace, made concrete** (`4281936`). The dead-man switch
hand-pasted into aedile that morning had drifted from the shared
implementation within hours: no `notify-send`, no renewal warning, no
opening delimiter, and — worst — it sat above the wrapper's own `LOG=`,
so a tripped switch wrote to cron mail instead of `run.log`, and
`scheduler status` reads `run.log`. Verified against the old version
before replacing it: `rc=3`, nothing in the log. An expired aedile read
as a job that had simply not run. Extracted to `lib/deadman-switch.sh`;
the wrapper sources it and **refuses to run** if unreadable rather than
running unprotected. **A bespoke wrapper can share a FUNCTION without
adopting an ENGINE** — that distinction is why this is a small standalone
file and not a migration.

**A live hang was caused and fixed mid-session.** The first install hung
(`rc=124`): aedile's wrapper exports `DBUS_SESSION_BUS_ADDRESS` at
svc-vaporwave's own bus, where the socket exists but nothing listens, so
`notify-send` blocks forever. **`|| true` guards against failing, not
against never returning**, and the ecosystem uses that idiom in ~10 more
places. Restored from backup, guarded with `timeout 5`, reinstalled,
retested end to end. Unexplained residue filed as `q-756f82`.

**Closing found 12 answered questions inside a merge conflict**
(bibliothecaire `17fa399`). `closeout-lint` reported it as a plain
`[dirty-tree]` FLAG; the file held live conflict markers and 62 lines of
Zach's replies, uncommitted, minutes from being swept in as-is. Resolved
by union, because neither side was a superset and the editor copy was
demonstrably not stale — so a deliberate dismissal could not be told from
a divergence artifact, and the two errors are not symmetric. **This is
the strongest live exhibit yet for the multi-writer QUESTIONS interface
being the least-regulated in the ecosystem**, and it was found by a
durability lint that has no idea what a reply is.

**Zach's standing ask, from those replies, filed here as work:**
- [batch] **Name the trigger that warrants spinning up a NEW project, and
  make it loud** — Zach's words, answering the OCR/heavy-jobs question:
  heavy non-AI jobs should run on always-on dexter under usage guardrails,
  owned by scheduler/senechal "until a new project becomes warranted."
  He asked realisateur to identify that trigger and make it a mechanism,
  not prose. Reader: realisateur's own next `/nightly-batch`. Related to
  the incubation/graduation signals `bin/incubation-audit.sh` already
  computes — start there rather than inventing a second notion.

**Philosophy delta: none.** No doctrine file was edited by this session
(`1497bc0`/`13ba119` are earlier sessions the same day). The prose-trap
finding is a *candidate* for `BUILD-DISCIPLINE.md` and is queued as an
inbox idea, not written into doctrine on this session's own authority.

## 2026-07-28 (interactive `/ideate`, Zach-directed): policy propagation has three channels and the one that carries the actual run instructions does not exist

**Zach's question, verbatim: "how does policy spread out to all the
projects right now anyway?"** Asked while deciding whether the wtul
question-routing fix (`5a92fb5`) should be propagated. Answer, probed
rather than recalled:

### Vision

Every project should learn a policy change once, mechanically, from one
source — the same standard `restamp-discipline.sh` already meets for the
CLAUDE.md baseline. **Decided:** that is the bar. **Explicitly still open:**
which of the three channels below gets extended to carry run instructions,
and whether doctrine *rationale* (the numbered patterns) should travel at
all or stay a realisateur-only reference.

### What actually exists today

| channel | carries | state |
| --- | --- | --- |
| `bin/restamp-discipline.sh` | CLAUDE.md baseline: 12-row checklist + ecosystem protocols | Works. 18/18 in sync. **Nothing runs it** — no cron, no command file, no PATH shim. It is in sync only because sessions ran it by hand, which is the definition of prose discipline. |
| `bin/install-shims.sh` | PATH shims + user-level slash commands | Works, lists derived not typed |
| per-project `.claude/commands/*.md` | **the actual per-run instructions** | **No propagation channel at all.** |

### The finding that made this urgent

The wtul defect was never wtul-specific. Its step 5 told every run to
append every feature built to QUESTIONS.md, against an outlet only a human
could open. **The identical instruction is live in six more projects** —
`gardien`, `groc-mangr`, `nine-speakers`, `senechal`, `sequestria`,
`vkv-inventory` — because they all descend from the same nightly-batch
template and nothing has propagated a correction since. wtul was not
worse-designed; it ran 31 times in 4 days and hit the rule hardest. Fixing
wtul fixed one instance of an ecosystem-wide rule.

**Second, mirror-image finding.** Only `wtul` and `scheduler` call
`collect-feedback.sh --consume`. The other ten projects instruct reading
`> ` replies **in prose** ("treat any `> ` answer as authoritative") with
no mechanism behind it. Zach has written real `> ` replies into **12
projects**; ~50 reply lines across 11 of them have never been collected by
anything. wtul destroyed his answers by reading them (pattern 17); everyone
else never mechanically reads them. Same ending, opposite mechanism — and
the second kind is invisible, because an uncollected reply looks exactly
like a file with nothing pending.

**Third:** `BUILD-DISCIPLINE.md`'s 17 numbered patterns do not propagate at
all — only the checklist does. Pattern 17, filed today, exists in exactly
one file. Whether that is correct (the checklist is the *what*, the
patterns are the *why*, and a project arguably needs only the what) is a
real question, not an oversight to fix reflexively.

### Milestone chain

1. **Current (not started):** decide which channel carries run
   instructions. Leading proposal — give `restamp-discipline.sh` a second
   managed region, inside each project's `nightly-batch.md`, marked the way
   it already marks CLAUDE.md. Then the question-routing rule is fixed once
   and reaches all seven affected projects, and project #8 gets it on
   creation rather than inheriting the 2026-07-22 text.
2. **Next (not started):** wire `restamp-discipline.sh` to something that
   runs. Proposed: shim it, and have `/ideate` and `/cloture` run it **dry**
   during orient, so an interactive pass always sees drift. `--apply` stays
   a deliberate human act — an unattended rewrite of 18 CLAUDE.md files is
   a large blast radius to hand to a cron job.
3. **Later (undecided):** the ~50 orphaned replies. Inventory for Zach
   first, or give every project the (now non-destructive) consume step.
4. **Not queued:** propagating the pattern list itself.

### Blockers

- **Human-only:** all four decisions above were put to Zach this session
  via `AskUserQuestion` and he stepped away before answering. Re-filed as
  answerable entries in this repo's `QUESTIONS.md` — that is the blocker,
  and it is a decision blocker, not a build one.
- **Buildable now, once decided:** every item in the chain. Nothing here
  is gated on hardware, credentials, or another project.

**Nothing was built this session** — no channel extended, no project's
command file edited, no shim installed. `/ideate` posture held.


## 2026-07-28 (interactive `/cloture`, from scheduler): overnight cybernetics study, and pattern 16 filed as doctrine

Deferred once for BUSY (pid 1937642) and filed as `[batch]` stubs in
scheduler's `.scheduler/FOCUS.md` (`13c0b8e`); the lock cleared during the
same session, so this is the real write and those stubs are **retired by
this entry**.

**The study.** Branch `research/ecosystem-cybernetics` (pushed): a
discrete-tick simulation of this ecosystem, 100 generations overnight —
11 arms x 10 disturbance regimes x 30 seeds x 200 ticks, no AI, no
network, `nice 19`, zero tokens, so it did not starve the paced jobs it
was studying. Three mutually hostile paradigms were given arms on purpose
(Ashby: instrument the sensor; Perrow: instrumentation is itself an
accident participant, loosen coupling instead; Hayek: the centre cannot
receive this input at all). Seven hypotheses were registered *before any
data existed* by `sim/prereg.py`, which refuses to overwrite a hypothesis
and refuses one with an empty falsifier, and which judges falsifiers
mechanically rather than by model judgment.

Findings that bear on this repo's own decisions:

- **Reconciling co-blind sensors adds ZERO variety.** `A_baseline` (one
  sensor) and `B_more_sensors` (four) are identical to the digit in all
  20 cells. **This is a direct result about `bin/sensor-agree.sh`, queued
  in `UNIVERSE.md` as the proprioception remedy: it is a reconciliation
  mechanism for a disagreement problem, aimed at an agreement problem.**
  Four `$HOME`-scoped sensors that all say OK about `svc-vaporwave` agree
  perfectly and are all wrong. Recommend it be re-scoped or retired
  before it is built.
- **A third symbol (`BLIND`) cuts undetected disturbance ~92%**, and
  ~83% under a hostile parameterisation where a BLIND report leads to a
  fix only 20% of the time.
- **Slack buys latency tolerance, not detection** — Perrow's coupling
  prescription was falsified in 19 of 20 cells. It is not a substitute
  for the symbol.
- **Adding fallible monitors is worse than adding none** (wasted
  attention 0.54 vs 0.29; trust 0.46 vs 0.82). Sent to bibliothecaire as
  a scoped correction to `briefs/normal-accidents.md` (`506ca1d`): that
  brief's test is right, and it returns the opposite answer for guards
  whose output consumes Zach — because Zach is the control path.
- **Central vs local sensing is decided by whether the disturbance is
  drift or volume.** Unpredicted, emergent, and the most interesting
  thing here.

**Honest limits, stated because the numbers will outlive the caveats:**
the 5 rounds per regime are byte-identical replicas, so the real n is 10
regimes x 30 seeds, not 50; and the arm labelled `A_baseline` fails
toward ALARM while the real `scheduler status` fails toward OK, so the
"clone" run is the faithful model and the main run is the
counterfactual. Under the faithful mode the Ashby result holds in 8 of 10
regimes, not 10. Four self-inflicted defects are ranked in the manual's
§8, including a metric that read `0.0` for 50 generations because it was
structurally unable to fire — the study's own subject matter, committed
by the study's own instrument, in its own output.

Write-ups at `29c90ab`: `ELI5.md` (front door), `TECHNICAL-MANUAL.md`
(handoff), `PHILOSOPHY-AND-CRITIQUE.md` (hypotheses + first-order
critique). `0563b1d` corrects an overstatement in the last of these.

**Not a finding, and must not become one by citation.** The study's
sharpest observation was never registered: a sensor that fails toward OK
scores *perfectly* on every dashboard metric — 0.00 wasted attention,
1.00 trust, zero false alarms — while carrying 688 undetected ticks and
1062 false cleans. Generalised: **a silent sensor optimises every
observable metric, so any regime that rewards a dashboard selects for
silence.** That is doctrine-shaped and belongs alongside pattern 14, but
it has to be guessed first and tested second. `prereg.py` will not
backdate it and neither should a reader of this entry.

**Doctrine edited this session** (unlike the two entries above, which
deliberately left the call open): `BUILD-DISCIPLINE.md` pattern 16, *a
correct refusal that nothing retries*, and the matching `/cloture` step-3
change, both at `13ba119`. Provoked by this session committing the
pattern itself — two deferrals announced in a summary and filed nowhere,
by a session that had read the `[batch]` convention minutes earlier.
`/cloture` is user-scoped, so `bin/install-shims.sh` was rerun and
senechal notified (`f2463a2`).

**Also unfiled until now:** `bin/silence-audit.sh` and
`bin/install-silence-audit.sh` remain staged-only on
`staging/silence-audit` (`39d64e0`, pushed), uninstalled and unwired by
design — the install script is dry-run by default, names what it retires,
and gates on three tests. Nothing dispatches from that branch. That is
intentional and it is also pattern 2 with a longer fuse; it needs either
a decision to install or a decision to retire.
**2026-07-28 (background session, `/loop` task): six blockers cleared — GitHub expansion complete, configs updated, ready for tool build.** Three blocker-class decisions made (push all 13, maximize privacy, aedile public OK), three mechanical blockers resolved (scheduler issues enabled, REPO_URL added, 12 repos pushed), one blocker requiring build deferred (question migration tool). Witness:

- **Blocker #1** (GitHub availability) — Resolved. 12 new private repos created on GitHub (gardien already existed). All 13 formerly local-only projects now have git@github.com:hf7y/* remotes, pushed with full history via mirror, and configured in scheduler. Checked-out projects, bare repos, and scheduler configs all verified pointing to GitHub.

- **Blocker #2** (scheduler issues disabled) — Resolved. Enabled issues in hf7y/scheduler repo settings.

- **Blocker #3** (aedile visibility in shared org) — You decided acceptable. aedile's public visibility in media-arts-collective/wavebucks (PUBLIC) is OK; Tyler's involvement not required.

- **Blocker #4** (per-repo visibility) — You decided maximize private. All 12 new repos PRIVATE (wtul, chezz, scheduler remain PUBLIC per prior decision; baudin, inventory-app remain PRIVATE; maximizes privacy as requested).

- **Blocker #5** (question migration tool) — **Still blocked.** 109 questions across 17 projects need QUESTIONS.md→issues migration. Chezz pilot had 0 open questions so tool was never tested. This is the **critical path blocker** for automation; deferring to separate task.

- **Blocker #6** (REPO_URL missing) — Resolved. Added REPO_URL to scheduler.conf, aedile.conf, vkv-inventory.conf (was missing or commented). Updated all 12 newly-pushed projects from local bare-repo paths to git@github.com:hf7y/* URLs. All 15 projects now have REPO_URL configured. Committed to scheduler's gh-issues-answer-channel branch and pushed.

**State of draft PRs:** Both hf7y/scheduler#1 and hf7y/chezz#2 remain draft. Main branch has neither the config changes nor chezz's side; automated cron orchestration cannot start until merged. Merging safe to do now — both PRs have all prerequisites met.

**Ecosystem:** Autocommit watcher has unpushed QUESTIONS.md adoptions in 4 projects (noted in earlier sessions); worth `git ahead N` check before running cron. chezz pre-commit hook performance (2.5 min hangs on ~:30) noted for future optimization, not blocking rollout.

**Commits this session:** scheduler branch gh-issues-answer-channel `3a45bf3` (REPO_URL update).

**2026-07-28 (`/ideate`, Zach-directed, "this is the moving target in action"): THE PLAY REVISED — scheduler bootstraps itself onto dexter; the first schedule IS the readiness test.** Zach's framing, near-verbatim: the ecosystem moves to dexter, scheduler moves FIRST and bootstraps the rest, creds are already set up, "the agents are neurotically overthinking it." Drop scheduler in, run it, it installs itself; the first schedule runs each agent, which takes turns verifying its credentials and proving it's wired up. ecosim monitors for data and names hypotheses from bibliothecaire quotes. Nothing was built this session.

=== WHAT THE PROBE FOUND (re-probed, not quoted) ===

`ecosim/BRIEF-dexter-migration.md` is STALE in both of its loudest findings, and this matters because THE PLAY's caution is built on them:
- §3 "dexter's scheduler is stalled right now, and silently" — FALSE as of 2026-07-28 23:35. `ssh dexter` shows `~/scheduler` at `## main...origin/main` clean, and `run.log` logs `23:30:02 PULL fast-forwarded to 6e8636a`. Verified 2026-07-28 via `ssh dexter 'git -C ~/scheduler status -sb; tail -4 ~/.local/share/scheduler-paced-runner/run.log'`.
- §2 "the fix — one host-local line" — ALREADY APPLIED and persisted. `git config --global --get url.https://github.com/.insteadOf` → `git@github.com:`. Verified same command.
This is the fourth instance this week of a headline quantity needing re-derivation before action (cf. the 07-26/07-27/07-28 survey cases). The brief is 40 minutes old and two of its three findings expired. Filing this here, not in ecosim's repo, per ecosim's own rule.

=== THE DISAGREEMENT, NAMED ===

Zach's framing supersedes THE PLAY (scheduler FOCUS.md 2026-07-28 23:26) in three places, two of them recorded as DECIDED earlier the same night:
1. **Order.** PLAY: "scheduler's OWN move is deferred until the others land and there is evidence" (M4). ZACH: scheduler first, it is the bootstrap mechanism.
2. **Readiness.** PLAY M1(b): a central probe writes a readiness store; agents select from it, cannot assert readiness. ZACH: each agent proves its own wiring on its own first turn.
3. **Gate.** PLAY M1: freeze + probe must both exist before anything moves. ZACH: drop it in, run it, the first schedule is the test.

**Why Zach's version is not the reckless one, stated because the recorded plan implies it is.** The failure that motivated M1(b) was a central probe reporting 19/19 READY when the true answer was 2/19 — a probe asserting readiness on behalf of 19 projects it could not see execute. Replacing it with "each agent runs on dexter and proves it" is STRICTLY HIGHER SENSOR VARIETY by ecosim's own thesis: a real run has more output symbols than any probe of a run. The neurosis is building a predictor for an outcome that is cheaper to observe directly. M1(b) is a sensor built to avoid running the experiment.

=== DECISIONS (Zach unavailable at ask time — asked via AskUserQuestion, 60s no-response; each taken on best judgment from something ALREADY WRITTEN DOWN, each reversible, each to be re-confirmed) ===

- **Scheduler moves first; mandark's scheduler self-dev goes DARK.** Supersedes the defer. The two-writer hazard (two hosts auto-committing one scheduler history) is resolved by decree rather than by ordering: dexter becomes the only host that auto-commits scheduler's own history; mandark keeps the human checkout, interactive and read-only. Derived from THE PLAY's own already-DECIDED vision line — "mandark becomes a workstation ... and stops being an execution host." PASSED OVER: the defer's evidence-first rationale. Stated reason for the override: the bootstrap IS the evidence-generating run, and deferring the bootstrap defers the data the whole experiment exists to collect.
- **M1(b), the readiness probe, is RETIRED before being built.** Superseded by self-verification-on-first-turn, per the sensor-variety argument above.
- **M1(a), the freeze file, SURVIVES.** It is not a predictor; it is the abort handle — the only thing that stops a bad first schedule already in flight. `git revert` handles a landed bad commit; it does not stop a running tick.
- **Proof bar = a real run that commits and pushes FROM dexter.** The crt bar, already M2's recorded standard. NOT ls-remote-plus-a-witness-line (proves reachability, not that the job works). Agent-authored prose self-report is explicitly REJECTED and recorded as rejected — it is tonight's already-found failure mode.
- **ecosim is an OBSERVER with no stop bit.** It records everything, names failure classes, cannot halt a move. Its own CLAUDE.md forbids writing findings into other projects' repos; giving it a stop bit would make it a regulator rather than a sensor, which is a change to that project's remit and needs its own stated decision.

=== WHAT IS STILL OPEN (unchanged, and this revision does not close them) ===
- Do `_paced.*.conf` become GENERATED artifacts with `HOST=` on each project's conf, or stay hand-maintained? (scheduler 7fccdc1 q1, unanswered.)
- Must the freeze reach svc-vaporwave's fixed-cron jobs (aedile 03:00, vkv-inventory 04:00), or may it declare them out of scope loudly? (7fccdc1 q2.) This gates the freeze's definition of done, and the freeze is now the ONLY surviving M1 mechanism — so this question got MORE load-bearing tonight, not less.
- Sequencing detail Zach's framing does not settle: "it installs itself on the machine" — does the self-install write dexter's crontab, or does it assume the `*/5` paced-runner tick already there is the whole install surface? Dexter already runs `usage-paced-runner.sh */5`; the sweep backstop and weight-audit ticks are mandark-only and unreplicated (ecosim brief §6.6, still current).

=== NOT BUILT ===
No project scaffolded, no feature code written, no host touched. Dexter was read only. All four decisions above are recorded as reversible and awaiting Zach's confirmation.

**2026-07-29 (`/ideate`, Zach-directed): THE PLAY, RUN AS A SELF-EXTENDING ROTATION — scheduler dogfoods the migration by writing its own next participant.** Zach: *"dogfood scheduler to pull this off. each job's milestone becomes to bootstrap itself. each job's timing is wired in by hand. scheduler runs itself. then that call adds another project to the rotation. that project runs. then scheduler runs again, adds another project to the rotation. non-scheduler turns should be slim using the realisateur milestoning system."* Four forks answered by Zach this session via `AskUserQuestion`. Nothing was wired; ecosim's sensor lane was the one build (see below).

=== 1. VISION ===

The migration performs itself, one alternating turn at a time, and the performance IS the dataset. Scheduler's turn is a WRITE — it appends the next participant's line to the rotation — so the rotation file extends itself and no agent holds the plan. Each project's turn is a single slim proof: bootstrap yourself on dexter, commit, push, done. ecosim watches and records but cannot intervene.

What makes this different from a migration runbook: a runbook is a proxy for the migration, and (per the unsourced claim now filed as `bibliothecaire/briefs/proxy-variety-REQUEST.md` `d3bb504`) a proxy cannot have more output variety than the event. Running it turn by turn under instrumentation is the maximum-variety observation available. Zach's stated purpose stands unchanged: *"very important data for a more intelligent scheduler philosophy that's not simply about fair round robin turns."*

DECIDED THIS SESSION (Zach, 2026-07-29, four answered forks):
- **ecosim files observations onto its OWN repo, one issue per migration unit** — not onto the observed project's repo. Zero new permissions; ecosim never needs write on 14 repos. Explicitly accepted cost: NO feedback loop. The observed project never sees the observation. This is a lab notebook, not a control channel. Rejected: cross-repo filing, and the hybrid "own repo for routine, cross-repo on failure".
- **A project's stability milestone is TEMPORARILY OVERRIDDEN with "bootstrap yourself on dexter", and the original is RESTORED afterward.** Rejected: tracking bootstrap outside the milestone system entirely, and replacing the 19 declared milestones permanently. This is the choice that keeps `milestone-audit` honest (one `Current` line per project) but it REQUIRES A STASH MECHANISM THAT DOES NOT YET EXIST — see BLOCKERS.
- **Scheduler's turn WRITES the next rotation line.** Rejected: hand-edited slots, and hand-edit-then-self-write-after-wave-1. Zach chose the highest-data-value option and it makes the two-writer hazard LIVE rather than theoretical.
- **Scope this session: brief + design + the ecosim onboarding build. No rotation wiring.**

=== 2. THE COUPLING NOBODY HAS STATED YET, AND IT IS THE MOST IMPORTANT LINE IN THIS ENTRY ===

"Scheduler's turn writes the next rotation line" is only safe because of the OTHER decision taken last session: **mandark's scheduler self-dev goes DARK, leaving dexter the only host that auto-commits scheduler's own history** (`dd11360`, awaiting Zach's confirmation at `63cf3b4`). Those two decisions are now load-bearing on each other. If Zach reverses the dark-mandark decision, the self-writing rotation becomes two hosts auto-committing to one scheduler history — precisely the divergence that already bit that repo, now on the file that governs dispatch. **The confirmation at `63cf3b4` is therefore a precondition of this design, not an independent question.** Do not wire the self-writing rotation before it is answered.

=== 3. MILESTONE CHAIN ===

M1 — THE FREEZE EXISTS AND FAILS LOUD. [current, not started]
Unchanged from `eb94ba0` and still the only surviving M1 mechanism after M1(b)'s retirement. Checked at DISPATCH time by each consumer, not merely honored by the runner. Must STATE what it does not cover. Its scope question (`7fccdc1` q2, svc-vaporwave's fixed-cron jobs) is unanswered and now gates M1's definition of done.

M1.5 — THE MILESTONE OVERRIDE MECHANISM EXISTS. [current, not started, REALISATEUR'S OWN]
New, created by tonight's decision. A project's real stability milestone must be stashed and restored around its bootstrap turn. Done when: a project can be put into bootstrap-milestone and returned to its real one with the original recoverable from a git-tracked location, and `milestone-audit` reads correctly in both states. This is realisateur's system (`STABILITY-MILESTONES.md`) and realisateur's to build — it is the only piece of the play this repo owns outright.

M2 — THE FIRST ALTERNATION RUNS. [next, not started]
scheduler's turn on dexter writes ONE new participant line; that project's turn bootstraps and proves it with a real run that commits and pushes FROM dexter. Done when: two turns have happened in order, ecosim holds one `observation` issue with the complete state-transition record, and the rotation file's new line was written by scheduler rather than by hand.

M3 — THE LOOP SUSTAINS. [later, undecided in scope]
The alternation continues unattended for N units. The dispatch-order-by-readiness change is justified from the M2/M3 data or it is not made.

M4 — HOST ASSIGNMENT IS DECLARED. [not queued] Unchanged.

=== 4. BLOCKERS ON THE CURRENT STEP ===
- **HUMAN-ONLY:** confirm `63cf3b4` — specifically decision (1), mandark self-dev going dark. §2 above makes it a precondition, not a standalone question.
- **HUMAN-ONLY:** `7fccdc1` q2 — does the freeze reach svc-vaporwave's fixed-cron jobs (aedile 03:00, vkv-inventory 04:00) or declare them out of scope loudly?
- **BUILDABLE NOW (realisateur):** the M1.5 stash mechanism. Nothing blocks it.
- **BUILDABLE NOW (scheduler):** the freeze file. Blocked only on its scope question above for "done", not for "started".

=== 5. BUILT THIS SESSION (the one exception to /ideate posture, Zach-approved) ===
ecosim's sensor lane, `scheduler 40d7c3d`: `ANSWER_CHANNEL="issues"` (second project after the chezz pilot), four labels on `hf7y/ecosim` (`question`/`answered`/`observation`/`hypothesis`), and `REPO_URL` repointed. **That last one was a real defect, not tidying:** the local bare `/home/zach/git-remotes/ecosim.git` sat at `2129a13` while GitHub was at `db3f660` — five commits behind and MISSING ecosim's own `BRIEF-dexter-migration.md`. ecosim's dispatch was cloning a ref that did not contain its own work. Ancestor, not diverged. Verified via `git ls-remote` from both mandark and dexter, `merge-base --is-ancestor`, and `scheduler questions ecosim` → `channel: GitHub issues, hf7y/ecosim`.

**Generalisation worth checking against every project, and NOT checked this session:** ecosim's conf drift is the same class its own brief §5 catalogued for `gardien` (`REPO_URL` still a mandark path). Two of 19 confs have now been found pointing dispatch at a local bare while the real work lives on GitHub. Nobody has audited the other 17. A project whose dispatch clones a stale ref looks perfectly healthy in every survey — `steward-survey` has no symbol for it. Queued below.

=== 6. QUEUED, NOT BUILT ===
- [batch] Audit all 19 confs for `REPO_URL` pointing at a local bare that is behind its GitHub counterpart. Two found by accident (ecosim, gardien); 17 unaudited. Compare `git ls-remote <bare>` against `git ls-remote <github>` per project and report ancestor/diverged/equal. This is a sensor the ecosystem does not have.
- [batch] The M1.5 milestone stash/restore mechanism (see chain above).

  [batch] DEFERRED CROSS-WRITE, ecosim was BUSY: **supersede H1 in `ecosim/BRIEF-migration-experiment.md` §5.** Deferred 2026-07-29 ~00:10 — `check-project-busy ecosim` reported `BUSY: interactive session (pid 2614858, since 2026-07-29T00:05:11-05:00)`. Verified FOREIGN, not this session's own lock: pid 2614858 is a `claude` process with ppid 2610537, absent from this session's ancestry (2508895 → 2508913 → 2588554 → 2616759). **Reader: realisateur's next `/ideate` or nightly-batch pass — re-run `check-project-busy ecosim` and, if free, append the payload below to `ecosim/.scheduler/FOCUS.md` via `focus-commit`.**

  PAYLOAD, carried in full so a run that cannot see this conversation can perform it:

  > **2026-07-29 (realisateur, via `/ideate`, Zach-directed): H1 in `BRIEF-migration-experiment.md` §5 is SUPERSEDED — do not run it as written.** It predicted that near-decomposability implies *independent* bootstrap failures. `bibliothecaire/briefs/near-decomposability.md` states the concept is *"a claim about **timescales**, not about modularity: the couplings are real, they are just slow"*, and Simon's proposition (b) is long-run dependence *in an aggregate way*. H1 converted a claim about rates into a claim about independence — a misuse, caught by reading the brief rather than by any data.
  >
  > **Replacement, and it is a better experiment:** apparent independence in the short run, aggregate dependence later, **with the transition point as the measurement**. That reframes the shared-fate OAuth caveat too — the question is no longer "are failures independent?" but "*when* does the shared credential stop looking independent?", which the instrumentation can actually answer.
  >
  > Full statement as T1 in `bibliothecaire/briefs/migration-theory-REQUEST.md` (`5a7c5d9`), which supersedes §5 of that brief entirely: five predictions (T1–T5), each with a named falsifier, filed before data exists so the theory cannot be fitted to the outcome. **T2 is the one to read first** — the self-extending rotation implements stigmergy's positive feedback with no negative half, and Theraulaz is explicit that without evaporation/saturation/competition a system *"does not self-organise but merely accumulates"*. Predicted symptom: declining useful-work-per-turn with **no alarm, because accumulation is not an error state**. That is a sensor you would otherwise not know to build.
  >
  > Also inherited: §8 of that request asks whether chaining Simon, stigmergy, Ashby, Perrow and Koestler is legitimate synthesis at all. Until answered, **the data can test T1–T5 individually but cannot confirm "the theory"** — do not let one confirmed prediction be recorded as support for the frame.

  **RESOLVED same session — the deferred cross-write above (`653e075`) was DELIVERED, not by waiting for the lock but by using the lane.** ecosim's repo was BUSY with a foreign interactive session, so the H1 supersession went to `hf7y/ecosim` **issue #8** instead of its `FOCUS.md`. The `[batch]` row is discharged; a future pass should NOT re-apply it. **This is the first real use of the issues lane wired an hour earlier (`scheduler 40d7c3d`), and it was used for exactly the case that motivated it: reaching a project whose files are being written by something else right now.** A lane that requires no git write is not blocked by a git lock — worth recording as a general property, because the previous answer to BUSY was always "defer", and deferral was where cross-writes went to die twice this week (BUILD-DISCIPLINE pattern 16).

**2026-07-29 (`/ideate`, Zach-directed, "send ecosim the sensors. it's looking"): SIX SENSOR SPECS + one hypothesis correction delivered to `hf7y/ecosim` as issues #1–#8.** Not built — specified, with ecosim owning the design. Index at #1: S1 unit state-transition recorder (#2, the core dataset), S2 accumulation sensor (#3, T2), S3 domain-moved/staleness (#4), S4 shared-fate credential (#5, T1), S5 dispatch-ref staleness (#6), S6 simultaneity (#7, T4), plus the H1 supersession (#8).

**Every spec carries a mandatory negative test** — a known-bad input that must produce the failure symbol, as a named test that fails when removed. The rule is stated once in #1 and repeated per sensor because the 19/19-READY probe is what happens without it: an output alphabet of `{READY}` that could not emit `BLOCKED` at all. Applies to observation-only instruments too — an instrument that cannot record a failure will report a clean migration.

**Two of the six are for confirmed live defects, not predictions.** S5 targets the dispatch-ref staleness found in ecosim's own conf this session (5 commits behind, missing its own brief) and already present in gardien — two of 19 found by accident, 17 unaudited, and the state renders as `LIVE` in every survey because no sensor has a symbol for it. S4 is a check ecosim itself asked for in `BRIEF-dexter-migration.md` §9 and never filed.

**Label safety verified rather than assumed:** all eight issues carry `sensor`/`hypothesis`; `gh issue list --label question` returns 0 and `scheduler questions ecosim` reports none. Instrument traffic is invisible to the human decision surface by construction. That property is the reason this lane is safe to use at volume, and it should be re-verified whenever a new issue class is added.

**S3 is written to run against its own spec.** A staleness sensor whose own specification is a frozen document with an expiry, and which exempts itself, would be the fourth instance of the pattern it exists to detect.

**2026-07-29 (`/ideate`, Zach-directed): ecosim's `bin/migration-watch.py` verified independently, and its BLIND surfaced A DEFECT IN REALISATEUR'S OWN `milestone-audit`.** ecosim reported building the observer; re-probed rather than relayed, per the standing rule that a report's status claims are stale by construction. Everything it claimed held.

**What was verified, not accepted:** `--selftest` exits 0 (`ok -- 0 failure(s)`, 27 assertion sites). Observer-only holds *structurally, not merely by intent* — all writes confined to `REPO/sensors/`, and `subprocess` is imported but **never called**, so nothing shells out. `BLIND_BY_CONSTRUCTION = {"aedile","vkv-inventory"}` is a constant in code rather than prose, making it the first mechanism here that cannot forget §0's blind spot. Tree clean and pushed.

**THE DEFECT, and it is realisateur's:** `milestone-audit` reports `== summary: 19 declared (0 reached) / 0 missing / 0 no-focus ==` while **3 of 19 are `[UNRECOGNIZED]`** (bibliothecaire, home-assistant, vkv-inventory) and **bibliothecaire has no `Current:` line at all** — `grep -c 'Current:' bibliothecaire/.scheduler/FOCUS.md` returns **0**. The tool prints `milestone: DECLARED -- "(no bar text on Current line)"` for a project with no milestone. The per-project detail carries the `[UNRECOGNIZED]` tag; **the summary statistic — the number anyone acts on — folds it into clean.** Verified 2026-07-29 via the three commands above.

Same shape as the 19/19-READY probe: the detail was right and the *aggregate could not express the failure*. It is the Nth instance of a headline quantity reading clean over an unreadable domain, and this time it is in this repo's own sensor, which is the least excusable place for it. `steward-survey` gets this right (`unrecognized` in its MILESTONE column) — so two of our surveys disagree about bibliothecaire and only one is wrong.

**WHY THIS BLOCKS THE PLAY, and this is the operational point:** Zach's decision (`bde9e62`) is that each project's stability milestone is temporarily OVERRIDDEN with the bootstrap milestone and RESTORED afterward. **On these 3 projects there is nothing to stash.** M1.5 would silently no-op, `milestone-audit` would keep reporting `declared` throughout, and ecosim's `RESTORED` symbol would have no baseline to restore to. So this is not a coverage caveat on ecosim's sensor — **the sensor correctly detected that M1.5 has an unhandled case before M1.5 exists.** That is the instrument earning its keep on day one.

**NOT FIXED — `/ideate` posture held.** Two changes are wanted and neither was made: (a) `milestone-audit`'s summary must count `UNRECOGNIZED` separately instead of inside `declared`, and must never report `0 missing` over a domain it could not read; (b) M1.5's design must handle "no milestone to stash" as a named state rather than a no-op. Both are small and mechanical. **Say the word and (a) is a single session's work** — it is this repo's own tool and nothing blocks it.

**Third-order note, recorded because the pattern keeps climbing a level.** ecosim's error #2 was that `IN_NEITHER` was itself a null-discriminator *inside the sensor written to catch null-discriminators*, found by running it. Its resolution generalises past this migration: **the discriminator is the transition, not the state** — a state-keyed sensor cannot distinguish two states differing only in how they were arrived at. And one level up again: `--selftest`'s fixture output is visually identical to a live report (16 `NEVER_EMITTED` lines above a green pass), so *"this is a test"* and *"this is your system"* render as one symbol. Sent to ecosim as an observation (#9), not filed as a bug.

  [batch] Fix `milestone-audit`'s summary: count `UNRECOGNIZED` as its own class, never fold it into `declared`, and never print `0 missing` over projects whose milestone line could not be read. Witness: the summary must change for the current tree, where 3 of 19 are unreadable. Verified-broken 2026-07-29.
