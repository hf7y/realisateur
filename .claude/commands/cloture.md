<!-- Source: hf7y/realisateur:.claude/commands/cloture.md. It reaches this host
     through the verb build, not through a clone -- edit it here, never the
     installed copy, and never symlink to a checkout. -->

`/cloture` closes a session. The checks are in the `cloture` verb, not in this
file: prose let a close say "documented exception" forever, and on 2026-09-07
one did that to 29 branches, twenty of which needed no judgement at all
(hf7y/realisateur#1086). What used to be three pages of rules is now an exit
code.

## Run it until it is CLEAN

```
cloture
```

It reports what the session is about to leave behind — raised but not filed,
layered not replaced, built but not wired, branches, and who it lands on. It
writes nothing and files nothing; you act on the rows.

**Then run it again.** A close is finished when a pass comes back CLEAN, not
when you have explained why it is not. That loop is the whole routine: every
row you clear can reveal another, and the run that first exercised this caught
three layers of residue in three passes.

`cloture` exits 0 CLEAN, 1 with findings, 6 when a check could not look. **6 is
not a pass.** A check that could not look is a finding about the check.

## What the rows mean

- **CLONE-BACKED** — a name on PATH resolves into a project checkout. It stops
  working the day that clone goes, which is the acceptance test for anything
  installed on this host.
- **BUILT-NOT-INSTALLED / INSTALLED-NOT-BUILT** — the build and the home
  disagree about what exists.
- **OPEN-NO-MILESTONE** — an issue this session touched that nothing dispatches
  to. Filed is not dispatchable; attach it or say why it is human-only.
- **ADDED-NOTHING-RETIRED** — you added surfaces and retired none. Name what
  each replaces, or say why the thing it duplicates stays.
- **MERGED-NOT-REAPED / NO-PR / PRUNABLE-WORKTREES** — branch residue. Run
  `git worktree prune` first: a worktree whose directory is gone still pins its
  branch, and that is what makes a branch look like somebody else's work.
- **AWAITING-A-PERSON** — open, declares `DECISION:`, touched by this session.

## The three things the verb cannot do for you

1. **Philosophy delta.** Did this session change what the ecosystem believes —
   a rule in `PROSE-REAPING.md` or `CLAUDE.md`? Name it in one sentence and
   confirm it is in a commit or PR. If not, say **"philosophy delta: none"**;
   silence is indistinguishable from not looking.

2. **Cross-project writes.** Every repo, host and account this session touched,
   including ones it reverted, with sha. A run that cannot see this
   conversation still has to be able to act on it.

3. **Reading a row and deciding.** The verb finds; you judge. A row you dismiss
   is dismissed out loud, with the reason.

## Close

Report with **links, not descriptions**. Zach should never have to ask whether
something landed — the answer is a URL. Every clause naming a problem is
followed by an issue or PR URL, or it is not finished.
