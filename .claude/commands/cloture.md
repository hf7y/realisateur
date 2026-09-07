---
scope: user
description: Session-closing rite -- reconcile every branch against the remote, deal with residue rather than narrating it, file findings as issues/PRs (never repo prose), surface what is blocked on Zach. Does not build.
---

<!-- Source: hf7y/realisateur:.claude/commands/cloture.md -- installed at USER
     level, so "this repo" below means realisateur, not your cwd. Edit it
     there, never the installed copy.

     SELF-CONTAINED ON PURPOSE. Everything here runs from a shell with git and
     gh and nothing else installed. An earlier version delegated the checks to
     a binary that was never put on PATH, which turned the whole routine into
     a pointer at a command not found. -->

`/cloture` is the closing counterpart to `/ideate`'s opening posture: a rhythm
to run after a big job, so a session ends "clear to clear" instead of trailing
off. A session can end with local branches that reconcile cleanly yet have no
PR at all -- the question is not "is the content safe" but "can the next reader
find it without asking". Repo prose is never the residue channel: GitHub issues
and PR bodies already are one, are searchable, and do not need this repo to
keep growing to hold them.

**Posture: report, route, and surface — do NOT build.** If closing reveals
unfinished work, file it where something dispatches from (a GitHub issue in the
owning repo) or land it as a PR/draft PR — never start building it at the end
of a session, and never park it only in this conversation. The one exception is
finishing what this session already did: committing and pushing that isn't new
work, it's the session not having landed yet.

**Run the whole thing again after you act.** Clearing one row reveals the next.
A close is finished when a pass finds nothing, not when you have explained why
the findings are acceptable.

## 1. Branch reconciliation

**Prune first.** A worktree whose directory is gone still pins its branch, and
git reports it as *used by worktree* — which reads as somebody else's live
work and is not:

```
git worktree list          # look for `prunable`
git worktree prune -v      # removes ONLY records whose directory is missing
```

**Then ask the right question.** `git cherry` compares patch-ids, so
squash-merges and reworks make it report unique commits for branches whose
content already landed. It finds candidates; it does not decide.

```
git diff --stat origin/main..<branch>    # empty, or overwhelmingly deletions => BEHIND
gh pr list --head <branch> --state open  # an open PR already covers it
git status --porcelain -uall             # uncommitted AND untracked
```

Every local branch resolves to one of three states, **checked against the
remote, not asserted**:

- **Reflects `main`** — merging it would change nothing. Reap it; no judgement
  is required and none should be performed. Record branch and sha first.
- **Has an open PR** — draft if the work or decision isn't finished, ready if
  it is. This makes the remote the source of truth for what's outstanding.
- **Genuinely unlanded** — commits that would still change main. Push and open
  a PR, or say what it is and why it stays, **with a URL**.

Handle what's left:

- **Uncommitted tracked changes** -> commit (via a message file) or discard
  deliberately. Paths that predate this session are NOT that: leave them alone,
  since committing or reverting them adopts or destroys a concurrent run's work.
- **Untracked and not ignored** -> commit it, ignore it, or move it out of the
  repo. It will sit in `git status` forever and belong to nobody. Reporting it
  is not dealing with it.
- **Committed but unpushed, no PR** -> push and open one. A one-line draft PR
  beats a branch only this host knows exists.
- **Pushed with an open PR** -> re-read the body against the grammar `gh`
  refuses at write time. A body edited after the write is not re-read by
  anything, so read it yourself.

**A branch you cannot resolve is not an exception you may narrate.** It needs
an issue URL like anything else. "Documented exception" written only into the
reply is how a checkout reaches thirty branches with no record that any of it
happened.

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
milestone holds an open issue, so attach it at creation:

```
gh issue create --milestone "<title>" ...
gh issue list -R <slug> --milestone "<title>"   # confirm it is actually there
```

### Layered not replaced

Did this session add a surface while the ones it duplicates stayed? Name what
each new file replaces, or say why the thing it duplicates remains. A check
that already exists is owned by whatever owns it — a second implementation is
the defect, not the coverage.

### Built but not wired

A thing that exists and nothing reaches. Three shapes, all worth a look:

```
installe list | grep Documents/Projects   # a name on PATH resolving into a CLONE
```

Nothing should need a checkout to run on mandark. Also compare what the verb
build carries against what the home actually has — commands in
`~/.claude/commands/`, hooks in `~/.claude/hooks/`, and whether
`settings.json` names each hook at an event. **A hook that is installed and
wired to nothing enforces nothing**, and it is the most expensive shape of
this, because a hook is the only surface that makes a rule arrive as a
consequence rather than as a paragraph.

### Where each goes

File in the **owning** repo — run `check-project-busy <target>` first if you're
writing into files of a repo that isn't this one. Nothing gets appended to
`.scheduler/FOCUS.md`, `BLOCKERS.md` or `QUESTIONS.md`: retired by
hf7y/scheduler#66 on 2026-08-07. Finding one is a finding
(hf7y/realisateur#230), not a destination.

- **A cross-project write**, including reverted ones and any second account or
  host touched — one issue or PR comment per write, with repo and sha.
- **A decision blocked on Zach** — an issue titled as the question, in the repo
  it's about. He answers by commenting and leaving it open; `etiquette` prints
  the grammar and derives the label.
- **An insight true beyond this session** — a *rule* goes in a doctrine file
  (step 2). A fact or finding is an issue. Neither, and just interesting, needs
  no durable home.

## 4. What is blocked on Zach, from this session

Only this session's own. What is piled up estate-wide is a different question
with its own surface, and answering it here would be a fourth one.

An issue whose body opens `DECISION:` and is still open is waiting on a person.
`NO-DECISION:` is not.

## 5. Close

Re-read what you are about to say before you write it. **Every clause naming a
problem, gap, defect or FLAG must be immediately followed by an issue or PR
URL.** Never a bare statement of fact. If a clause fails that test, go file it
before finishing.

State plainly, with **links, not descriptions**: which branches got a PR and
which URL, which issues were filed and which URL, what was pushed and where
(with revert shas), what was reaped and its recorded sha. Zach should never
have to ask whether something landed — the answer is a URL, not a sentence
promising one exists.
