---
scope: user
description: Session-closing rite -- reconcile every branch against the remote, deal with residue rather than narrating it, FIX the rows one edit away and file only what it cannot reach, surface what is blocked on Zach.
---

<!-- Source: hf7y/realisateur:.claude/commands/cloture.md, installed at USER
     level: "this repo" below means realisateur, not your cwd. Edit it there.
     Self-contained on purpose -- git and gh, nothing else. -->

`/cloture` closes a session the way `/ideate` opens one. Not "is the content
safe" but "can the next reader find it without asking" — and repo prose is
never the answer, because issues are searchable and do not make this repo grow.

**FIX the rows you can reach; file only what you cannot** (Zach, 2026-09-07). A
row one edit away — an unwired hook, a matcher that does not deliver — closes
here, with a PR. **Run it again after you act**: clearing one row reveals the
next, and a close ends when a pass finds nothing, not when you explain why not.

## 1. Branch reconciliation

**Prune first** -- a worktree whose directory is gone still pins its branch, and
git calls that *used by worktree*, which reads as somebody else's live work:

```
git worktree list          # look for `prunable`
git worktree prune -v      # removes ONLY records whose directory is missing
```

**Then ask the right question.** `git cherry` compares patch-ids, so a
squash-merge reports as unlanded. It finds candidates; it does not decide.

```
git diff --stat origin/main..<branch>    # empty, or overwhelmingly deletions => BEHIND
gh pr list --head <branch> --state open  # an open PR already covers it
git status --porcelain -uall             # uncommitted AND untracked
```

Every branch and every path resolves, **checked against the remote, not
asserted**:

- **Reflects `main`** — merging changes nothing. Record branch and sha, reap
  it; no judgement is required and none should be performed.
- **Has an open PR** — draft if unfinished, ready if not. The remote is then
  the source of truth for what is outstanding.
- **Genuinely unlanded** — push and open a PR, or say why it stays, **with a
  URL**. Re-read an existing body: `gh` refuses a bad one at the write, and
  nothing re-reads it after.
- **Uncommitted** — commit (message via file) or discard deliberately. Paths
  predating this session are neither, and are not an exception either: they get
  an issue in the OWNING repo naming the files, or they are not dealt with.
- **Untracked, not ignored** — commit, ignore, or move it out. It will sit in
  `git status` forever belonging to nobody, and reporting it is not dealing
  with it.

**An unresolved branch is not an exception you may narrate.** It needs a URL
like anything else; "documented exception" written only into the reply is how
a checkout reaches thirty branches with no record any of it happened.

## 2. Name the philosophy delta, or say "none"

Did this session change what the ecosystem *believes* — a rule in
`PROSE-REAPING.md` or `CLAUDE.md`? Those two are the doctrine still in this
repo; the rest were consigned to the vault in #366.

If yes: name the delta in one sentence and confirm the file is in a commit or
PR from step 1, not merely described in chat. If no, **say "philosophy delta:
none" explicitly** — silence is indistinguishable from forgetting to look.

## 3. Three things that leave a session, and where each goes

### Raised but not filed

Every FLAG, gap or defect this session named and did not fix needs an issue or
PR URL. The rule is **structural, not lexical** — a keyword sweep will not
catch it. realisateur#165: a close named a real defect with *"Not something I
fixed — flagging it"*, which contains none of the obvious trigger words, and
Zach had to ask who had been told.

**Filed is not dispatchable.** Since 2026-09-04 a project runs only while a
milestone holds an open issue, so every issue this session files OR TOUCHES gets
one -- and "no milestone fits" is a finding to file, never a line in the reply.

### Layered not replaced

Did this session add a surface while the ones it duplicates stayed? Name what
each new file replaces, or say why the thing it duplicates remains. A check
that already exists is owned by whatever owns it — a second implementation is
the defect, not the coverage.

### Built but not wired

A thing that exists and nothing reaches. Nothing should need a checkout to run
on mandark, and the verb build should match the home:

```
installe list | grep Documents/Projects   # a PATH name resolving into a CLONE
```

Compare the build's `commands/` and `hooks/` against `~/.claude/`, and check
`settings.json` names each hook at an event. **An installed hook wired to
nothing enforces nothing** — the most expensive shape here, because a hook is
the only surface that makes a rule arrive as a consequence rather than as a
paragraph.

### Where each goes

The **owning** repo — `check-project-busy <target>` first if it isn't this one.
Never `.scheduler/FOCUS.md`, `BLOCKERS.md` or `QUESTIONS.md`: retired by
hf7y/scheduler#66, and finding one is itself a finding (hf7y/realisateur#230).

- **A cross-project write**, reverted ones and any second account or host
  included — one issue or PR comment each, with repo and sha.
- **A decision blocked on Zach** — an issue titled as the question. He comments
  and leaves it open; `etiquette` derives the label.
- **An insight** — a *rule* goes in a doctrine file (step 2), a finding is an
  issue, and merely interesting needs no home.

## 4. What is blocked on Zach, from this session

Only this session's own; the estate-wide pile is its own question.

An issue whose body opens `DECISION:` and is still open is waiting on a person;
`NO-DECISION:` is not. **Residue this session CAUSED is never one of these** --
repair it or file it; handing it back as "yours to reconcile" is the failure.

## 5. Close

Re-read it before you write it: **every clause naming a problem is immediately
followed by an issue or PR URL**, or it is not finished.

**Links, not descriptions** — which branches got which PR, which issues were
filed, what was pushed and where, what was reaped and its sha. Zach should
never have to ask whether something landed.
