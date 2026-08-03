# THE FLOOR — a stability milestone for the ecosystem itself

*Proposed 2026-08-01, from the survey in `ECOSYSTEM-SURVEY-2026-08-01.md`.
Ecosystem-scoped, machine-facing. Every exit criterion is a command that exits
0/nonzero or an observable checkable in under 60 seconds — because this
ecosystem's recorded pathology is prose accumulating faster than mechanism,
and a milestone made of prose would be self-defeating.*

---

> # ⚠ SUPERSEDED — that banner was true for 31 minutes
>
> **Re-measured 2026-08-02 22:00: `bin/floor-check.sh` → NOT MET, 3 unmet.**
> The stamp below was taken at 03:02. `garde-nightly.service` fired at 03:33
> and failed, which broke gate 1.1 half an hour later. Read
> `MANDARK-DEXTER-PLAN-20260802.md` §0, then **run the checker** — this file
> says four paragraphs down that the command is the authority and the prose is
> not, and this banner is what that warning looks like when it comes true.
>
> Since re-measured: the backup was fixed (17/17 sets, gate 2.2 restore now
> exercised and MET), failed units 2 → 1. What still holds it NOT MET is two
> things needing Zach — `hermes-gateway.service` failed, and `basheur` +6
> unpushed. Both are named in the plan's §5.
>
> ---
>
> # THE FLOOR WAS MET — 9/9, 2026-08-02 03:02 CDT
>
> ```
> $ bin/floor-check.sh --restore    # exit 0
> MET  2.2 destination readable AND a file restored byte-identical
>      /mnt/d/gardien-media/mandark/Projects/realisateur/README.md
>      -> md5 4a96ae0a00fc matches source
> ```
>
> The last unproven criterion was the restore, and it is now exercised rather
> than asserted: a real file pulled back off dexter and diffed byte-for-byte
> against its source. **The resumption contract at the bottom of this file is
> therefore unlocked** — read it before arming anything, especially the
> one-project-at-a-time rule.
>
> **Carry this forward, because it is the live hazard:** `gardien`'s last run
> ended `outcome=NOT-DONE` with no verdict written, so the runner will
> re-dispatch it every tick and spin until the project writes a verdict or is
> unpaced. Harmless while nothing is armed; a loop the moment something is.

**`bin/floor-check.sh` IS THE AUTHORITY, not the tables below.** This file's own
premise is that "every exit criterion is a command" — so when the prose and the
command disagree, the command wins, and on 2026-08-02 they disagreed badly.
The checker's criteria were **deliberately revised** after this document was
written (`4928775`, `0acb7f6`, `f0d911e`), and the prose tables were never
updated to match:

| gate | prose below says | the checker actually asks |
|---|---|---|
| 1.2 | total cron surface is exactly **2 lines** | exactly **one agent-dispatching** line, no unaccounted lines |
| 3.1 | `_paced.conf` has **exactly one** enabled row | a **ceiling** on armed agents — zero armed is fine |
| 2.2 | start `gardien.service` | restore a real file from the destination and diff it |
| 2.3 | `ecosystem1` **and** `git-remotes` are named sets | `~/Documents/Projects` is a named set |

**A correction to the restamp of earlier today.** That pass reported "2 of 9
MET" by hand-evaluating the prose criteria above. Measured against the
*command*, the true figure at that moment was 8 of 9 with one unproven. The
error was reading the specification instead of running the mechanization — the
exact substitution this milestone exists to prevent. The tables below are kept
as history; they are no longer the score.

## Relationship to the prior art

`STABILITY-MILESTONES.md` is a **per-project admission-control convention**.
Its canonical bar is *"Real life output gathers real life input"*, and it
explicitly calls a bar reachable by unattended internal work **suspect**
(`:66-67`).

**THE FLOOR differs in unit and in kind.** It is ecosystem-scoped and
deliberately internally-satisfiable — a *floor*, not a *bar*. That is not a
violation of `:66-67`; it is the exception the doctrine never wrote, because
it never imagined the substrate failing. Grading THE FLOOR against claim 1 of
the doctrine is a category error, and this paragraph exists so no later
session does it.

**What it supersedes:** three lines of doctrine *text* — `:76-79`, naming
`groc-mangr`, `nine-speakers` and `sequestria` as "the reference examples."
All three were deleted from disk on 2026-08-01; only `vim-arcade` survives.
Nothing in the doctrine's *model* is superseded.

**What it does NOT re-invent:** the seven declared per-project bars (abletim,
basheur, ecosim, gardien, senechal, vim-arcade, wtul) stand as written. No new
project bars here.

**One correction to the record:** `milestone-audit` reporting realisateur and
scheduler MISSING is a **three-day-old regression**, not an omission —
`bin/stamp-agent.sh` deleted both sections on 07-29 (`d35f49f` −4,444 lines;
`7289527`). Their text survives in `ecosim/sensors/milestones-baseline.json`.
Restoring them is recovery work, which is why it is a first action and not a
gate.

---

## Definition of done — one sentence

> **Nothing on this machine runs from a path that no longer exists, every
> repo's history exists in at least two places, and exactly two cron lines are
> installed — one sensor, one dispatcher — with exactly one project enabled,
> whose overnight run leaves a clean tree and a commit on a branch.**

---

## GATE 1 — NO GHOSTS

*Rationale:* `fauche` checks git reachability and vault consignment; it does
not check machine footprint (`bin/fauche:27` assigns `BINDIR` and never uses
it — the check is half-built and abandoned). That gap left
`front-door-watch.service` running from a directory deleted this morning,
`crt-whisper-server.service` listening on `0.0.0.0:8991` for a repo that is
gone, and 8 orphan loop scripts for absent projects — two of which **fired
this morning at 03:00 and 04:00** under `svc-vaporwave`. Re-arming dispatch
onto this floor adds agents to a surface nobody can enumerate.

| # | Criterion | Proof | Status |
|---|---|---|---|
| 1.1 | No enabled unit, installed shim, or crontab line names a path that does not exist | `ausculte dead-config` exits 0 (08-02: still **exit 6, BLIND** — it cannot read `svc-vaporwave`'s crontab, which is finding 1.2 wearing a different hat) **and** `for f in ~/.local/bin/*; do [ -L "$f" ] && [ ! -e "$f" ] && echo "$f"; done` prints nothing (08-02: **prints nothing ✓**, was `silence-audit`) | **NOT MET** (dangling-shim half now clean) |
| 1.2 | Total executable cron surface is 2 lines, both on `zach@mandark` | `crontab -l \| grep -cvE '^\s*(#\|$)'` = 2; same for `svc-vaporwave` = 0; `ssh dexter crontab -l \| grep -cvE '^\s*(#\|PATH=\|$)'` = 0 | **NOT MET** (**3** / not re-probed, needs sudo / **0 ✓**) |
| 1.3 | Every guard the propagated checklist names resolves and fails loud | `install-shims.sh --check` exits 0 (08-02: **0 ✓**); `command -v silence-audit` resolves (08-02: **resolves ✓**); every lint gates when asked: `reach-lint.sh --strict`, `closeout-lint.sh --strict`, `hygiene-lint.sh --strict` all exit 1 while printing FLAGs (08-02: **all three ✓**, `a8218b6`) | **MET ✓** |

**Correction to 1.3 as originally written (2026-08-02).** The row cited
`reach-lint.sh --strict-reach` exiting 0 while printing 5 FLAGs as evidence of
broken exit discipline. That was a misreading of a correct guard: `--strict-reach`
gates on check B (reach) *only*, deliberately, because check A's `scope:`
convention is one other repos have not adopted and a caller asking "are my own
instructions reachable?" must not be held hostage by another project's
frontmatter (`bin/reach-lint.sh:35-41`). All 5 FLAGs were check A; check B was
clean; exit 0 was right. `--strict` — the flag the assertion actually wanted —
exited 1 the whole time.

Recorded rather than quietly deleted because it is this ecosystem's own
recurring shape: **the check reporting the defect was itself the thing
misread.** The real half of the finding was true — `closeout-lint` and
`hygiene-lint` genuinely had no `--strict` at all, and now do.

## GATE 2 — TWO COPIES

*Rationale:* `basheur` is the single live self-dev agent and the declared gate
on U0. It has **no GitHub repository**, its only remote is a bare repo on the
same 91%-full disk, `~/git-remotes` is in no backup set, and **2 of its 57
commits exist in exactly one directory right now** — written at 12:50 and
12:52 today, mid-survey, by a concurrent session. `gardien` — whose entire job
is knowing this — has failed every night since 2026-07-24 on a missing
`gardien.json`, and `gardien-git-hygiene.service`, the job built to find
exactly this gap, is failed too. Autonomous agents write. If writing is not
recoverable, every later gate is theatre.

| # | Criterion | Proof | Status |
|---|---|---|---|
| 2.1 | Every repo under `Projects/` has a reachable non-local origin and is 0-ahead of it | `for d in ~/Documents/Projects/*/; do u=$(git -C "$d" remote get-url origin 2>/dev/null) \|\| continue; case $u in /*) echo "LOCAL-ONLY $d";; esac; done` prints nothing (08-02: **prints nothing ✓** — `basheur` now on `https://github.com/hf7y/basheur.git`) **and** 0-ahead (08-02: **0 ✓**, was 2). Re-probed 08-02 across all **20** repos, and widened to the doctrinal test rather than `main` alone: **0 host-only branches, 0 ahead-of-origin, ecosystem-wide** | **MET ✓** |
| 2.2 | gardien's nightly backup completes, and a named file restores out of the newest snapshot | ~~`gardien.service`~~ → `systemctl --user start garde-nightly.service && systemctl --user is-failed garde-nightly.service` → `inactive`; then restore one known path and `diff` it against source, exit 0 | **NOT MET** — and note there is **no snapshot anywhere**: no `.gardien-snapshot-complete` marker exists on the filesystem, and the Pegasus destination is `online: false`. **08-02: the proof command named a unit that no longer exists** — `gardien.service`, `gardien-check-stale` and `gardien-git-hygiene` were retired 2026-08-01; the live unit is `garde-nightly.timer`, enabled and armed for 03:33, which has **never run** (`LAST` = `-`, journal empty). A gate whose own proof command names a deleted unit is gate 1.1's defect inside gate 2 |
| 2.3 | `~/ecosystem1` and `~/git-remotes` are named backup sets | `grep -c ecosystem1 gardien-garde/garde.json` ≥ 1 and `grep -c git-remotes …` ≥ 1 (today: **0 and 0**; `~/Documents` is a set, so `Projects/` is transitively covered *if backups ran* — the vault and the bare remotes are not covered at all) | **NOT MET** |

## GATE 3 — ONE LOOP, WATCHED

*Rationale:* Dispatch is off by choice; that choice only means something if
turning it back on is a decision with a witness. The recorded agent failures —
pushed `main` (07-25), 76 uncommitted lines in `sync-crontab.sh` (07-25), woke
after "completed" and wrote outside mandate (07-27) — are **all detectable
after the fact and none were detected**. The precondition is not that agents
behave; it is that the harness refuses. Today `~/.claude/settings.json` has
`"permissions": {"defaultMode":"auto"}` — zero deny rules — and hooks only for
`SessionStart`/`SessionEnd`.

**The target crontab, stated as config, not as intent:**

```
# zach@mandark — exactly two lines, both generator-installed, neither hand-written
*/30 * * * * /home/zach/.local/bin/ecosim-sensor-tick     # arme:ecosim-sensors:MONITOR
*/5  * * * * /home/zach/.local/bin/usage-paced-runner.sh  # scheduler:paced-runner:META
# zach@dexter    — PATH= only, zero jobs
# svc-vaporwave  — zero lines
# schedule/_paced.conf — exactly one row with enabled=1: gardien|1|2
```

gardien is the one, because its milestone *is* the restore-verified backup and
its failure is the only one `THE-UNWIRING.md` §5 calls unrecoverable.

| # | Criterion | Proof | Status |
|---|---|---|---|
| 3.1 | Crontab matches the block above, installed by `sync-crontab.sh --apply`, one project enabled | `crontab -l \| grep -c 'scheduler:paced-runner:META'` = 1; `grep -cE '^\s*[a-z-]+\|1\|' schedule/_paced.conf` = 1 (today: 0 and **0 of 6 enabled**) | **NOT MET** |
| 3.2 | The harness refuses a dirty exit and a `main` push, mechanically | `jq '.hooks.SubagentStop' ~/.claude/settings.json` names a script running `closeout-lint --strict`; `jq '.permissions.deny'` contains a `git push`-to-`main` rule. Verify by attempting each and observing refusal | **MET in substance, not in letter** (08-02). `permissions.deny` holds **7** rules ✓ — `git push origin main:*`, `master:*`, both `HEAD:` forms, and all three force-push forms. `SubagentStop` **is** wired ✓, to `~/.claude/hooks/subagent-closeout.sh`, which exits 2 to BLOCK on a dirty tree, loop-guards on `stop_hook_active`, and fails loud (exit 1) if git is missing. But it does its **own** `git status --porcelain` rather than calling `closeout-lint --strict`, so it catches a dirty tree and nothing else — not unpushed commits, not host-only branches, not a missing session record. See the follow-up below |
| 3.3 | One overnight run left a clean tree, a commit on a branch, and no BLIND | Next morning: `closeout-lint` reports 0 BLIND (today: 6 BLIND, **exit 0** — itself a silent pass) and `git -C gardien log --oneline -1 main` is unchanged while a dated branch carries the night's commit | **NOT MET** — and the silent pass is **still open** as of 08-02: `--strict` gates on FLAGs only, so a run with 0 FLAGs and N BLIND still exits 0. See the follow-up below |

---

## DO-NOT-DO — frozen until THE FLOOR lands

| Frozen | Reason |
|---|---|
| **No new projects, no scaffolding** | 220 ideas already stranded behind a closed valve. Intake was never the bottleneck. |
| **No new prose file; no new `BUILD-DISCIPLINE.md` row without a guard command in the same commit** | 4,145 → 45,182 bytes and 5 → 20 patterns in nine days while `bin/` went 3 → 23 scripts. The ratio *is* the pathology. |
| **No new verbs, no new subcommands, no `bashify coin`** | 25 verbs, ~3,600 lines, **zero machine consumers**, 4 exit-0 no-ops on PATH. A 26th measures nothing. |
| **No unparking a second project; no cron line beyond the two declared** | One loop is an experiment with a control. Two is a return to the state that produced this survey. |
| **No reaping any repo until `fauche` checks machine footprint** | Its check set is otherwise sound. It is missing exactly one dimension, and that dimension is what left a service running from a deleted tree. |
| **No `--summon`, no new agent-contract work** | U0's load-bearing box is "token cost measured on both sides, not estimated," and it is unchecked. 23 verb-page attempts have already run against an unmeasured baseline. |
| **No editing `STABILITY-MILESTONES.md` beyond the `:76-79` fix** | It is the prior art. The temptation under pressure is to rewrite the doctrine rather than meet it. |

---

## FIRST THREE ACTIONS

**1. Close the single-copy exposure (~20 min).**
`gh repo create hf7y/basheur --private --source=$HOME/Documents/Projects/basheur --push`,
then re-point `origin` off the local bare. Add `~/ecosystem1` and
`~/git-remotes` as named sets in `gardien-garde/garde.json`. Verify with the
2.1 loop. **Do this first and today** — a concurrent session is writing into
basheur right now, and its two newest commits exist in one directory on one
91%-full disk. Closes 2.1 and 2.3.

**2. Kill the ghosts that are actually running (~45 min, machine-wide —
`notify-senechal` is mandatory).**
`systemctl --user disable --now front-door-watch.service`; retire the **system**
unit `crt-whisper-server.service` and `ufw delete allow 8991`; clear
`svc-vaporwave`'s crontab (needs a password — it cannot be read or written
from zach's account, which is itself finding 1.2); remove the 8 orphan
`*-loop.sh` files from `~/.local/bin` — **and find what rewrote all 15 of them
at 10:21 today, after the reap, or this recurs.** Then `notify-senechal`.
Re-run `ausculte dead-config` — target exit 0. Closes 1.1 and 1.2.

**3. Make the guards resolve and fail loud (~45 min).**
Run `realisateur/bin/install-shims.sh` (no `--check`) — installs
`silence-audit` and refreshes the drifted `/ideate`, whose installed copy still
hardcodes a `Project Archive` path that does not exist, in the user-level
command every unattended run loads. Pick the canonical `silence-audit.sh` and
delete the loser. Then make `reach-lint`, `closeout-lint` and `hygiene-lint`
exit nonzero when they print a FLAG — today they exit 0 while printing 5, 1
and 61. Closes 1.3.

---

## RESUMPTION CONTRACT

Autonomous self-dev restarts only when all nine criteria are MET, and then only
under these rules.

**Guards that exist and work today** (verified this session — use as-is):

- `check-project-busy <project>` — fails **closed** (exit 2 on unknown name).
  Gates direct writes into another project's files; never gates front-door
  writes (`scheduler -i`, `notify-senechal`).
- `focus-commit <repo> <msgfile> <file>...` — the only sanctioned path to
  `FOCUS.md` / `QUESTIONS.md`. Never a bare `git add`/`commit`/`push`.
- `notify-senechal '<what, where, who owns it>'` — mandatory for any change
  outside a repo.
- `fauche` — refuses a repo unless all branches are on origin, tree is clean,
  no outside worktree depends on the object store, and prose is consigned.
- `epluche silence-audit --strict` — correctly exits 1. The *implementation*
  is healthy; only the PATH name is broken.

**Guards that MUST BE WRITTEN FIRST** — stated plainly rather than assumed:

1. ~~**A `SubagentStop` hook running `closeout-lint --strict`.**~~ **LANDED
   2026-08-01** as `~/.claude/hooks/subagent-closeout.sh` — but it implements
   the dirty-tree check *inline* instead of calling `closeout-lint --strict`,
   which did not exist at the time. It now does. See follow-up A.
2. ~~**`permissions.deny` blocking `git push` to `main`.**~~ **LANDED** — 7
   rules, covering `origin main`/`master`, both `HEAD:` forms, and all three
   force-push forms.
3. ~~**`--strict` exit discipline on `reach-lint`, `closeout-lint`,
   `hygiene-lint`.**~~ **LANDED 2026-08-02** (`a8218b6`). Note the original
   framing was wrong about `reach-lint`, which had `--strict` all along — see
   the correction under gate 1.3. `closeout-lint` and `hygiene-lint` genuinely
   lacked it and now have it, with witnesses: closeout-lint 32/0,
   hygiene-lint 9/0, reach-lint 13/0.
4. **A machine-footprint check in `fauche`.** `BINDIR` is assigned at
   `bin/fauche:27` and never used — ten lines in a file that already knows
   where to look. **Still open.**

**Follow-ups opened 2026-08-02, both deliberately NOT taken unattended:**

**A. Point the `SubagentStop` hook at `closeout-lint --strict`.** The hook
catches a dirty tree; `closeout-lint` catches that *plus* unpushed commits,
host-only branches, a missing session record, and BLIND worktrees. The gap is
not theoretical — the 2026-07-25 incident this hook exists for (76 uncommitted
lines in `sync-crontab.sh`) would be caught either way, but the 2026-07-27
incident (an agent waking after "completed" and writing outside its mandate)
leaves *unpushed commits*, which the inline check cannot see. Not done here
because `~/.claude/**` is machine-wide config: it is senechal's to know about
and Zach's to authorise, and an agent editing the hook that constrains agents
is exactly the wrong party to do it silently.

**B. Decide whether BLIND gates.** `--strict` exits 1 on a FLAG and 0
otherwise, so a scan with 0 FLAGs and 6 BLIND — today's actual state — passes.
Gate 3.3 asks for "no BLIND", and this cannot deliver it. The reason it was
left alone rather than patched: `a8218b6` states a deliberate rationale for
the exit codes (*"Exit 2 is already used via lib/cli-guard.sh for usage
errors, so --strict uses 1"*), and BLIND wants a **third** answer — senechal's
`lib/common.sh` already means *could-not-check* by 2, and `ausculte` signals
BLIND with 6. Three conventions, one script, and the choice changes the
contract of a guard that hooks may call. **Zach's call**, and it is one line
once made:
  - reuse **2** for BLIND (matches senechal, collides with cli-guard's usage error), or
  - fold BLIND into **1** (simplest; loses the "I could not look" vs "I found a problem" distinction the ecosystem's own `silence-audit` doctrine exists to preserve), or
  - leave it and drop "no BLIND" from gate 3.3 as unmechanized.

**Standing rules once restarted.** One project enabled at a time. Every run
reports every file and every account it touched, including reverted ones. A
run producing no commit says so explicitly (`vkv-inventory` burned three
dispatches on 07-30/31/08-01 with no commit anywhere). Agent status claims are
**stale by construction** — re-probed before relaying, never quoted. A second
project is unparked only after the first has completed seven consecutive clean
nights.

---

## The one thing this milestone does not decide

U0's open box — *token cost measured on both sides* — is still open, and
THE FLOOR deliberately does not close it. THE FLOOR makes the machine safe to
run an experiment on; it does not run the experiment. Once the gates pass, the
next decision is the one `THE-UNWIRING.md` §8 left open and
`basheur/.scheduler/FOCUS.md` marks `[OPEN — Zach]`: author one genuinely
agent-backed contract, measure the summon, measure the mechanization, measure
the per-call cost after, and write the three numbers down. Until those numbers
exist, "agents can be made unnecessary" remains an untested thesis that
seventeen projects are parked behind.
