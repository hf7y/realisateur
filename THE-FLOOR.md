# THE FLOOR — a stability milestone for the ecosystem itself

*Proposed 2026-08-01, from the survey in `ECOSYSTEM-SURVEY-2026-08-01.md`.
Ecosystem-scoped, machine-facing. Every exit criterion is a command that exits
0/nonzero or an observable checkable in under 60 seconds — because this
ecosystem's recorded pathology is prose accumulating faster than mechanism,
and a milestone made of prose would be self-defeating.*

---

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
| 1.1 | No enabled unit, installed shim, or crontab line names a path that does not exist | `ausculte dead-config` exits 0 (today: exit 6, BLIND, 3 WARN) **and** `for f in ~/.local/bin/*; do [ -L "$f" ] && [ ! -e "$f" ] && echo "$f"; done` prints nothing (today: `silence-audit`) | **NOT MET** |
| 1.2 | Total executable cron surface is 2 lines, both on `zach@mandark` | `crontab -l \| grep -cvE '^\s*(#\|$)'` = 2; same for `svc-vaporwave` = 0; `ssh dexter crontab -l \| grep -cvE '^\s*(#\|PATH=\|$)'` = 0 | **NOT MET** (1 / **2** / 0) |
| 1.3 | Every guard the propagated checklist names resolves and fails loud | `install-shims.sh --check` exits 0 (today: 1); `command -v silence-audit` resolves (today: dangling); `reach-lint.sh --strict-reach` exits nonzero when it prints FLAGs (today: **exit 0 with 5 FLAGs**) | **NOT MET** |

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
| 2.1 | Every repo under `Projects/` has a reachable non-local origin and is 0-ahead of it | `for d in ~/Documents/Projects/*/; do u=$(git -C "$d" remote get-url origin 2>/dev/null) \|\| continue; case $u in /*) echo "LOCAL-ONLY $d";; esac; done` prints nothing (today: `basheur`) **and** `git -C basheur rev-list --count origin/main..main` = 0 (today: **2**) | **NOT MET** |
| 2.2 | gardien's nightly backup completes, and a named file restores out of the newest snapshot | `systemctl --user start gardien.service && systemctl --user is-failed gardien.service` → `inactive`; then restore one known path and `diff` it against source, exit 0 | **NOT MET** — and note there is **no snapshot anywhere**: no `.gardien-snapshot-complete` marker exists on the filesystem, and the Pegasus destination is `online: false` |
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
| 3.2 | The harness refuses a dirty exit and a `main` push, mechanically | `jq '.hooks.SubagentStop' ~/.claude/settings.json` names a script running `closeout-lint --strict`; `jq '.permissions.deny'` contains a `git push`-to-`main` rule. Verify by attempting each and observing refusal | **NOT MET** |
| 3.3 | One overnight run left a clean tree, a commit on a branch, and no BLIND | Next morning: `closeout-lint` reports 0 BLIND (today: 6 BLIND, **exit 0** — itself a silent pass) and `git -C gardien log --oneline -1 main` is unchanged while a dated branch carries the night's commit | **NOT MET** |

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

1. **A `SubagentStop` hook running `closeout-lint --strict`.** Does not exist.
   `PLAYBOOK.md` Play 1 named it on 2026-07-26; six days later `settings.json`
   still has only `SessionStart`/`SessionEnd`. A dirty tree at exit must
   *terminate* the run, not be reported by it.
2. **`permissions.deny` blocking `git push` to `main`.** Does not exist.
   CLAUDE.md's "commits to a branch, does not push main" is prose, and prose
   has already failed twice.
3. **`--strict` exit discipline on `reach-lint`, `closeout-lint`,
   `hygiene-lint`.** All three print FLAGs and exit 0.
4. **A machine-footprint check in `fauche`.** `BINDIR` is assigned at
   `bin/fauche:27` and never used — ten lines in a file that already knows
   where to look.

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
