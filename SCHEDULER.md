# Joining the scheduler ecosystem

`realisateur` has been registered since 2026-07-19. This file is the
walkthrough a *new* project scaffolded out of the inbox follows to register
itself (`nightly-batch.md` step 3 points here) — read it as "how
registration works," not "realisateur's own status."

**Reaped 2026-08-13, 119 lines → this.** What was here described the
mandark-era model in step-by-step detail: local bare remotes under
`~/git-remotes/`, a `.scheduler/FOCUS.md` that scoped every Tier 2 run, a
`.scheduler/QUESTIONS.md` answered with `> ` blockquotes, symlinks into the
scheduler's `focus/`/`questions/` aggregation folders, and
`bin/sync-crontab.sh --apply` to install per-account cron. Every one of
those premises has expired, and a walkthrough that instructs a new project
to build retired surfaces is how they kept being reborn — see
`PROSE-REAPING.md` §1, third row: prose defending an expired mechanism is a
deletion signal, not something to relocate. The narrative is in git history
if it is ever wanted.

## What is true now

- **Prose lives in the issue tracker.** `BLOCKERS.md`, `.scheduler/FOCUS.md`
  and `.scheduler/QUESTIONS.md` were retired by hf7y/scheduler#66 on
  2026-08-07. A new project gets a GitHub repo under `hf7y` and files its
  findings, questions and milestones as issues. Do not scaffold those files.
- **Questions are issues, and Zach answers by commenting and CLOSING.** A
  closed issue carrying a comment is an answer, not a dropped thread.
- **Verbs come from the host-wide build**, not from a clone: on monkey,
  `/usr/local/bin` fed by one nightly tick. A new project needs no
  `*-verbs` worktree and no per-account pin (hf7y/realisateur#180).
- **A project holds a clone of its own repo, and nothing else.**

## What registering still requires

1. A git repo with a remote the scheduler can clone from unattended — the
   engine works in a disposable clone (`git clone`, `reset --hard`, invoke
   `claude`, push, repeat).
2. A `.claude/commands/nightly-batch.md` — the prompt the unattended run
   follows. Adapt a real one; the templates in scheduler's `examples/`
   still carry retired-surface instructions, so read before copying.
3. A root `CLAUDE.md` — the "suggest `/ideate <project>` instead of
   implementing" guardrail, so an interactive session recognises an
   open-ended ask and points at `/ideate` rather than building inline.
4. Registration with the scheduler, per its own `README.md`, which is the
   source of truth.

**Dispatch registration is in flux.** hf7y/realisateur#228 is retiring
per-account cron and `usage-paced-runner` in favour of host-level dispatch
on monkey. Read that issue before copying any crontab shape out of an older
project, and do not add a new per-account cron line without it.

## One gotcha that still holds

Push `.claude/commands/nightly-batch.md` to the remote **before**
registering, and read the first run's report rather than assuming it
worked. `crt`'s first run in 2026-07-19 failed because the disposable clone
briefly caught a commit older than the one that added its command file. It
self-healed, and the moral is the general one: a scheduled job reads the
ref, not your working tree.

## Who to ask

Zach owns all policy and scope decisions. Open questions about the
ecosystem itself go in the relevant repo's issue tracker.
