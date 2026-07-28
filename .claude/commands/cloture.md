---
scope: user
description: Session-closing rite -- run the closeout lint, name the philosophy delta, report cross-project writes, make insights durable, surface decisions. Does not build.
---

`/cloture` is the closing counterpart to `/ideate`'s opening posture: a
general rhythm to run after a big job, so a session ends "clear to clear"
instead of trailing off. Designed 2026-07-26 (name Zach's own call);
layer 1 is `bin/closeout-lint.sh`, this file is layer 2.

**Posture: report, route, and surface — do NOT build.** If closing
reveals unfinished work, the answer is to file it where something
dispatches from (a `[batch]` row in `.scheduler/FOCUS.md`, a
`> `-answerable line in scheduler's `BLOCKERS.md`), not to start
building it at the end of a session. The one exception is finishing what
the lint flags as *undurable* — committing and pushing work this session
already did. That isn't new work; it's the session not having landed yet.

**What it retires:** the ad-hoc prose session summary as the SOLE
reporting channel. A summary is still fine — this is what it must cover
before it counts as one.

## 1. Run the lint first (offline, zero AI)

```
bin/closeout-lint.sh
```

Deterministic half before any judgment, per
`scheduler/docs/offline-first-checks.md`. It reports:

- **A** every registered repo with a commit younger than 12h that has a
  dirty tree, unpushed commits, or no upstream at all;
- **B** whether this repo's `.scheduler/FOCUS.md` has an entry dated
  today citing at least one commit sha;
- **C** whether scheduler's `BLOCKERS.md` carries anything dated today
  (a NOTE, never a FLAG — see step 5).

Its FLAGs are **signals, not verdicts**, same as the other surveys —
except the durability ones, which are close to verdicts by construction:
an unpushed commit genuinely has not reached the ref the nightly clones.
Resolve those before closing, and say in the summary what you pushed.

Run `bin/hygiene-lint.sh <project>` too for any project this session
touched — the two overlap deliberately little.

## 2. Name the philosophy delta, or say "none"

Did this session change what this ecosystem *believes* — a rule, a
doctrine file (`UNIVERSE.md`, `BUILD-DISCIPLINE.md`, `PRECIPITATION.md`,
`STABILITY-MILESTONES.md`, `PLAYBOOK.md`, `FOCUS-FORMAT.md`)? If yes,
name the delta in one sentence and confirm the file itself was edited,
not just the chat. If no, **say "philosophy delta: none" explicitly.**
Silence here is indistinguishable from forgetting to look.

## 3. List every cross-project write, with repo + sha

One line each: `<repo> <sha> <what>`. Includes writes that were
**reverted** and any second account or host touched — the CLAUDE.md
subagent rule, applied to yourself. A cross-write nobody listed is how a
project acquires an entry its own nightly can't explain.

If a cross-write was **deferred** because `bin/check-project-busy.sh`
said BUSY, list it as deferred and file it, per step 5 — a deferral that
isn't written down is a dropped write.

## 4. Route the insights out of the chat

Anything learned this session that is true beyond it goes to a durable
home *now*: a doctrine file (a rule), `.scheduler/FOCUS.md` (a dated
record of what happened and why), or memory (a standing preference).
Prose decays and chat evaporates — this repo's own doctrine. An insight
still sitting only in the conversation at closing time is lost.

## 5. Surface decision-shaped residue

Anything that needs Zach's own judgment goes to one of two places, and
saying it in the summary is not one of them:

- **a question about a project** → that project's
  `.scheduler/QUESTIONS.md`, with a `  > (answer inline here)` slot;
- **a decision blocked on him** → scheduler's `BLOCKERS.md`, under the
  filing project's `##` section, as a `> `-answerable one-liner.

`BLOCKERS.md` is **not a work queue** — a task-shaped entry filed there
with no dispatch pointer is BUILD-DISCIPLINE failure pattern 13, and
`hygiene-lint.sh`'s `[blockers-task]` row will find it. If the residue is
work rather than a decision, file it where its owner dispatches from.

This is why lint check C never FLAGs: only this session knows whether it
had any decision-shaped residue at all. Answer that question deliberately
here rather than letting the empty check read as "nothing to file."

## 6. Close

State plainly: what was pushed and where (with revert shas, per
`CLAUDE.md`'s push permission), what was deliberately left undone and
why, and what the next session should pick up. If `closeout-lint.sh` is
still reporting FLAGs you chose not to resolve, name them and say why —
an unmentioned FLAG at close reads as an unseen one.
