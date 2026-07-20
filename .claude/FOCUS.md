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
- **The only real stop-and-wait bar: something that can't be reverted.** A
  commit, a branch, a new scheduler registration, a local bare git remote
  — none of these block you. What does: a real message to a person outside
  this loop, spending real money, deleting something with no backup, or
  registering against a REAL GitHub remote with credentials that could leak
  (prefer a local bare remote per `SCHEDULER.md` unless a GitHub remote is
  clearly already the right call). If genuinely unsure, that's the
  `.claude/QUESTIONS.md` case — but err toward "revertible, proceed."
