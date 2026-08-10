---
scope: user
description: Session-closing rite -- reconcile every branch against the remote, run the closeout lint, file residue as issues/PRs (never repo prose), surface decisions. Does not build.
---

`/cloture` is the closing counterpart to `/ideate`'s opening posture: a
general rhythm to run after a big job, so a session ends "clear to clear"
instead of trailing off. Designed 2026-07-26 (name Zach's own call);
revised 2026-08-10 on two counts: a session can end with local branches
that reconcile cleanly on lint yet still have no PR/draft PR at all (the
lint checks "is the content safe", not "can the next reader find it
without asking"), and repo prose (FOCUS.md/BLOCKERS.md/QUESTIONS.md rows)
had become the default residue channel when GitHub issues and PR bodies
already are one, are searchable, and don't need this repo (or a sibling
repo) to keep growing to hold them.

**Posture: report, route, and surface — do NOT build.** If closing
reveals unfinished work, file it where something dispatches from (a
GitHub issue in the owning repo) or land it as a PR/draft PR — never
start building it at the end of a session, and never park it only in
this conversation. The one exception is finishing what the lint flags as
*undurable*: committing and pushing work this session already did isn't
new work, it's the session not having landed yet.

## 1. Branch reconciliation — no dangling branches for later discovery

**Every local branch this session touched or leaves behind must resolve
to one of three states, checked directly against the remote, not
asserted:**

- **Reflects `main`** — merged (`git cherry` against `origin/main` shows
  nothing new) or its tip is reachable from a remote ref already. Nothing
  to do.
- **Has an open PR** — pushed, and `gh pr view` finds it. Draft is fine
  if the work or the decision isn't finished; ready (with or without
  `DECISION:`, per `claim-drift.sh --convention`) if it is. This is what
  makes the remote the source of truth for "what's outstanding" instead
  of this checkout.
- **Documented as an intentional exception** — a repo whose registration
  is itself missing/stale (`bin/closeout-lint.sh`'s `[missing-repo]`
  row), a branch deliberately parked mid-experiment, etc. Say so in the
  session close (step 4) with the branch name and why — not as a new
  repo file, just in what you tell Zach.

Run:

```
bin/closeout-lint.sh
```

first (offline, zero AI) — it already does the hard part: distinguishing
a genuinely unpushed branch from one that's squash-merged, stale-pointer,
or checked out in someone else's worktree (`note`/`skip`, not `FLAG`).
Then, for anything it does NOT already clear:

- **Uncommitted changes** → commit (per `CLAUDE.md`'s commit-message-via-
  file rule) or discard deliberately, never leave sitting.
- **Committed but unpushed, no PR** → push and open one. Even a one-line
  draft PR beats a branch only this host knows exists.
- **Pushed with an open PR already** → re-read the PR body against
  `claim-drift.sh --convention` before closing: does it still say what's
  actually true right now (draft vs. ready, `DECISION:` vs. no-decision)?
  A PR that drifted out of sync with its own claim during this session is
  exactly what `claim-drift.sh <n>` checks — run it on anything you
  touched.

`bin/hygiene-lint.sh <project>` too, for any project this session
touched — it overlaps deliberately little with the above.

## 2. Name the philosophy delta, or say "none"

Did this session change what this ecosystem *believes* — a rule, a
doctrine file (`UNIVERSE.md`, `BUILD-DISCIPLINE.md`, `PRECIPITATION.md`,
`STABILITY-MILESTONES.md`, `PLAYBOOK.md`, `FOCUS-FORMAT.md`, `CLAUDE.md`
itself)? If yes, name the delta in one sentence and confirm the file was
actually edited and is part of a commit/PR from step 1 — not just
described in chat. If no, **say "philosophy delta: none" explicitly.**
Silence here is indistinguishable from forgetting to look.

## 3. Every cross-project write, and every piece of residue, is a GitHub issue or a PR — not repo prose

**Nothing from this session gets appended to `.scheduler/FOCUS.md`,
`BLOCKERS.md`, or `QUESTIONS.md` as a session-log row.** Those files stay
for genuinely stable, load-bearing state (per `PROSE-REAPING.md`'s own
criterion: "does this describe a premise that still holds"), not as
where a session dumps what it did. That is what made them grow
unboundedly in the first place. Prose lives in issues and PRs now,
per Zach's own reply establishing this paradigm — searchable, closeable,
and not something every project's clone has to carry forever.

For each of the following, file a GitHub issue in the **owning** repo
(the repo the write/finding/decision is actually about — run
`check-project-busy.sh <target>` first if you're about to write into a
repo that isn't this one) rather than a row in a file:

- **A cross-project write** (including reverted ones, and any second
  account/host touched) — the CLAUDE.md subagent rule, applied to
  yourself. One issue (or a comment on the relevant PR) per write, with
  repo + sha, so a run that can't see this conversation can still act on
  it.
- **A deferred write** because `check-project-busy` said BUSY — same
  destination. Re-check before filing: locks are short, and if it now
  reports `free`, do the write for real instead of filing about it.
  Carry the actual payload in the issue body, not a pointer back to this
  chat — an issue nobody but you can decode is a second dropped write
  wearing a filed one's clothes.
- **A decision blocked on Zach** — an issue, titled as the question,
  in the repo it's about. He answers by commenting and closing (per
  standing convention) — not by editing a file back.
- **An insight true beyond this session** — if it's a *rule*, it goes in
  a doctrine file for real (step 2). If it's a fact or a finding rather
  than a rule, it's an issue. If it's neither — just interesting — it
  does not need a durable home at all.

**Retire check, run it every time:** grep the session for "deferred",
"BUSY", "left undone", "next session should". Every hit needs either an
issue URL or a PR URL from this step. A hit with neither exists only in
the chat, and the chat is about to end.

## 4. Close

State plainly, with **links, not descriptions**: which branches got a PR
and which URL, which issues got filed and which URL, what was pushed and
where (with revert shas per `CLAUDE.md`'s push-permission clause), and
what was deliberately left as a documented exception from step 1 and
why. Zach should never have to ask whether something landed — the answer
is a URL in the close, not a sentence promising one exists. If
`closeout-lint.sh` is still reporting anything you chose not to resolve,
name it and say why; an unmentioned FLAG at close reads as an unseen one.
