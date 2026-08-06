# PROSE-REAPING.md — where a paragraph lives

**Established 2026-08-06**, from Zach's reply of that date:

> Reaping of prose and logs is good. […] My hunch is that projects are
> prose-bloated which leads to inefficiency and confusion among agents. The new
> paradigm is github issues for mundane text, mostly stable FOCUS.md and claude
> materials, with only occasional paradigm updates propagated top down as the
> result of ecosystem analysis, research, and insights.

> Prose should not be going to github, especially to avoid issues with licensing
> while we implement proper ethics guards around IP.

First pass: `scheduler/schedule/_paced.conf`, **284 lines → 66**, four live rows
untouched. Narrative consigned to `ecosystem1/scheduler/paced-conf-history.md`.

---

## 1. The criterion

Applied paragraph by paragraph. It is one question:

> **Does this paragraph describe a premise that STILL HOLDS?**

| Answer | Destination |
|---|---|
| Holds, and breaking it breaks something | **Stays in the repo**, beside the thing it protects |
| Held *at the time* — explains why a past decision was right | **Obsidian vault** (`/home/zach/ecosystem1/ecosystem1/<project>/`) |
| **Expired**, and the paragraph exists to *defend a mechanism* | **Flag the mechanism for deletion.** Do not relocate the paragraph |

The third row is the one that makes this more than tidying. A long, careful
justification for a knob is *evidence about the knob*. If its premise has
expired, moving that justification to the vault launders dead config into a
cleaner-looking file and the knob survives. Prose defending an expired premise
is a **deletion signal**, and it gets reported as a finding in its own right.

Worked example, 2026-08-06: `_paced.conf` carried ~60 lines defending the
`weight` field — the doctrine block, four dated bump-and-exit-condition
rationales, four trailing `weight-audit.sh` annotations, four "no weights
remove" blocks. `realisateur#74` had just established that weight is **inert**
(it works by repeating a row in the rotation pool; on monkey an account can
execute only its own row, and `PACED_MAX_PER_TICK=1` stops after the first
dispatch). None of that prose went to the vault as narrative. It went into a
table of *mechanisms recommended for deletion*, and the conf now carries a
`FLAGGED FOR DELETION` block instead.

### Reaping never deletes the mechanism itself

The reaper's output is a *flag*. Removing a field, a script, or a config file is
a separate change with its own review — and on 2026-08-06 it was also
explicitly out of scope (Zach's Decision 1: *"No need to change anything now. I
just want to understand the current system properly."*). Conflating the two is
how a documentation pass silently becomes a behaviour change.

### Verify before you preserve

A trap paragraph earns its place in the repo only if the trap is **still live in
the code**. Re-probe it; do not carry it forward on the old header's authority.
On 2026-08-06 both of `_paced.conf`'s traps were re-derived — read out of
`lib/paced-conf.sh`, then *reproduced* with a real `sync-crontab.sh` preview —
and the reproduction was sharper than the prose it replaced (the trap's blast
radius is two of the four rows, not all four). Stale prose surviving a reaping
pass is the exact failure the pass exists to prevent, so the witness command
goes **into the file**, phrased as an instruction to re-run it.

---

## 2. The three destinations

### In the repo — mechanical traps and live invariants

Keep only what a reader must know **not to break it**. A test:

- Would an agent editing this file cause damage without this paragraph?
- Is the damage *mechanical* — a cron line armed, a second writer created, a
  suppression key dropped — rather than aesthetic?
- Can the claim be re-derived from the code **today**?

If yes to all three, it stays, and it stays *beside the thing it protects*, not
in a doc. Prefer a **runnable witness** over an assertion: three lines the
reader can paste, with the observed output, beats a paragraph asserting the
same. Prose decays; a command re-derives.

### The Obsidian vault — narrative, post-mortems, superseded decisions

`/home/zach/ecosystem1/ecosystem1/<project>/`. Everything that answers *"why did
this end up this way?"* rather than *"what will break if I touch it?"*: run
narratives, migration post-mortems, weight and tuning archaeology, unregistration
records, reversed decisions and the reason they reversed.

**Prose does not go to GitHub** — Zach's licensing/IP note, standing until
ethics guards around IP exist.

**The vault has a GitHub remote and is deliberately left unpushed.** Commit
locally; do not push. As of 2026-08-06 it is 6 commits ahead of `origin/main`.

### GitHub issues — the work

Mundane per-item text: one actionable item, one issue, in that project's repo.

---

## 3. The nuance that makes or breaks this: reap *into issues*, not only into the vault

Zach, same reply:

> Agree that pace needs to be proportional to backlog. That's the mechanism
> we're missing.

**Backlog that lives as prose in a `FOCUS.md` cannot be counted.** A scheduler
cannot pace against it, a report cannot size it, and a human cannot see whether
it is growing or shrinking. That is the same defect as the boiler-without-a-
thermostat, one level up: the missing input is not the run's outcome, it is the
*size of what remains*.

So a reaping pass that moves everything to the vault **makes the problem worse
while looking like progress.** The repo gets clean, the vault gets fat, and the
backlog is exactly as uncountable as before — now in a second location.

> **Vault gets narrative. Issues get work.**
> If a paragraph names something that should *happen*, it becomes a GitHub
> issue in that project's repo — not a vault page, and not a bullet that stays
> in `FOCUS.md`.

The split, applied to one paragraph at a time:

| The paragraph… | Becomes |
|---|---|
| explains why a past decision was made | a vault section |
| describes something that should be done | **a GitHub issue** |
| does both | an issue, *plus* a vault section it links to |
| defends a mechanism whose premise expired | a **deletion flag** in the report |
| protects a live mechanical trap | stays in the repo, with a runnable witness |

Corollaries worth stating because they have already gone wrong:

- **An issue title is a countable unit; a `FOCUS.md` bullet is not.** The point
  of the conversion is arithmetic, not tidiness.
- **`BLOCKERS.md` is never a work queue** (standing rule). Doable-unattended
  work goes to the project's own backlog or to an issue. Nothing dispatches from
  `BLOCKERS.md`, so a task parked there is invisible to every run.
- **Zach answers question-issues by commenting and closing.** A sweep that
  gates on labels loses his answers. Read closed issues.
- **Before reaping into another project's repo, run `check-project-busy
  <project>`.** A front-door write (`scheduler -i`, `notify-senechal`) carries
  its own regulator and does not need the guard; a direct file write does.

### Where the backlog count should end up

Not specified here, deliberately — `realisateur#74` proposes replacing the
`weight` field with a figure each project derives from its own state per run,
which is the same idea arrived at from the pacing side. This document only
commits to the precondition: **the backlog has to be countable before anything
can be paced against it**, and prose is not countable.

---

## 4. Branch doctrine (Zach's Decision 3, 2026-08-06)

> vim-arcade moves to main. Rather, all self-dev should be on a consistently
> named branch. "main" is fine for now. […] Git branch discipline is severely
> lacking on Zach's side, so the solution must anticipate that.

**The convention:** all self-dev commits land on **one branch name across the
whole ecosystem, `main` today.** A development branch is Zach's stated second
preference and would be a single-value change, not a per-project migration.

**Anticipating uneven discipline means not writing it as a rule.** A convention
that exists only as prose is exactly the thing this document is about reaping.
It is therefore installed as `bin/hygiene-lint.sh` **check 8c**, which runs
offline across every scheduler-registered project:

| Condition | Flag |
|---|---|
| detached HEAD | `FLAG [branch]` — commits reach no branch at all |
| on a branch that is not `$SELFDEV_BRANCH` | `FLAG [branch]` |
| no upstream configured | `FLAG [branch-noremote]` |
| ahead of upstream | `FLAG [branch-unpushed]` |

`SELFDEV_BRANCH` is read from one place and retargets the convention
ecosystem-wide. **Do not special-case a project by editing the script** — that
is the "config read from one source" row of `BUILD-DISCIPLINE.md`.

**Why the second half exists — the vim-arcade finding.** vim-arcade was
*already on `main`*, so Decision 3's stated action was a no-op. It still could
not converge: `scheduler#38`, a **read-only deploy key**, turns every local
commit into a permanent PULL WARNING. The branch *name* was never the problem.
So the check asks both questions — is it on the agreed branch, and can that
branch actually reach its remote — because an ahead-count that never falls to
zero is the observable form of "this checkout is diverging from where the batch
reads." Zach's own reply names the wider version: projects *"often with no git
remotes,"* which he calls malformed. `FLAG [branch-noremote]` is that, made
countable.

The check does **not** fetch. `hygiene-lint.sh` is offline-first, so the
ahead-count is against last-known remote state and the flag text says so.

---

## 5. Doing a pass

1. `check-project-busy <project>` if the repo is not your own. Defer on `BUSY`.
2. Work in a **git worktree**, not the shared checkout — other writers and a
   human's open editor are in it. Never `git add -A`; stage only named files.
3. Read the file whole. Classify **each paragraph** by §1's question.
4. **Re-derive every trap you intend to preserve** against the code. Reproduce
   it. Put the witness command in the file.
5. Convert every actionable paragraph to a **GitHub issue** in that project's
   repo (§3). Count them; the count is part of the report.
6. Write the narrative to the vault under `<project>/`. Commit locally, **do not
   push.**
7. Verify **behaviour is unchanged** — for a config file, a byte-identical
   preview from whatever consumes it, plus its witness tests.
8. Report the before/after line count, and **the list of expired-premise
   paragraphs with the mechanism each was defending.** That list is a
   deliverable, not a footnote.

`git commit -F <file>` for anything multi-line; a dirty tree at exit is a failed
run.

---

## 6. Standing observation

This repo has **34 top-level `.md` files**, most of them dated session and
sprint records. By §1 they are vault material almost in their entirety. That is
noted here rather than acted on: reaping realisateur is its own pass, and doing
it inside the pass that *writes the convention* would leave nobody able to check
the convention against a before-state.
