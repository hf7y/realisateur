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

### Deferred cross-writes — file them HERE, not by pointer

If a cross-write was **deferred** because `bin/check-project-busy.sh`
said BUSY, it is BUILD-DISCIPLINE pattern 16 (*a correct refusal that
nothing retries*) until it is written down. The refusal was right. The
refusal is not the end of your obligation.

This step used to say "file it, per step 5." That routing is what
failed — twice, on 2026-07-27 and again on 2026-07-28, the second time
by a session that had read the convention minutes earlier and still lost
the writes until Zach asked. Step 5 is for **decisions**; a deferred
write is **work**, so step 5 correctly declined it and named no
destination. So the destination is named here instead, and it is not
optional:

```
focus-commit <THIS repo> <msgfile> .scheduler/FOCUS.md
```

appending a row that begins literally:

```
  [batch] DEFERRED CROSS-WRITE, <target> was BUSY: <payload>
```

Three requirements, because a stub that omits any of them is a second
dropped write wearing a filed one's clothes:

- **Carry the payload, not a pointer to it.** The row must be usable by
  a run that cannot see this conversation. Findings, shas, and what the
  target repo is supposed to do — not "see the summary above."
- **Re-check before you assume it's still blocked.** Locks are short.
  Re-run `check-project-busy <target>` at close; if it now reports
  `free`, do the real write and skip the stub. Verify *whose* lock it is
  — an interactive session's own pid looks identical to a foreign one in
  the output, so compare against your own before deferring to yourself.
- **A deferral with no named reader is not filed.** Say which run picks
  it up. If nothing does, that is the finding, and it goes to step 5 as
  a decision.

**Retire check, run it every time:** grep the session for the words
"deferred", "BUSY", "left undone", and "next session should" — every hit
must correspond to a sha from this step or a sha from step 5. Any hit
that corresponds to neither exists only in the chat, and the chat is
about to end.

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
work rather than a decision, file it where its owner dispatches from —
and if it is work deferred by a BUSY lock, step 3 names the exact
destination; do not leave it here.

This is why lint check C never FLAGs: only this session knows whether it
had any decision-shaped residue at all. Answer that question deliberately
here rather than letting the empty check read as "nothing to file."

## 6. Close

State plainly: what was pushed and where (with revert shas, per
`CLAUDE.md`'s push permission), what was deliberately left undone and
why, and what the next session should pick up.

**Every item in the "left undone" and "next session" lists carries a
sha** — the commit that filed it, from step 3 or step 5. An item with no
sha is not left undone, it is dropped, and saying it here is what a
dropped write looks like from the inside. If you cannot produce a sha,
go back and file it before writing the close. Zach should never have to
ask whether a deferral landed; the answer is in the sentence. If `closeout-lint.sh` is
still reporting FLAGs you chose not to resolve, name them and say why —
an unmentioned FLAG at close reads as an unseen one.
