# Joining the scheduler ecosystem

`realisateur` has been registered since 2026-07-19 — `schedule/realisateur.conf`
in the scheduler repo, Tier 2 only, paced (no fixed cron slot), local bare
remote at `~/git-remotes/realisateur.git`. This file is kept as the
walkthrough a *new* project scaffolded out of the inbox follows to register
itself the same way (`nightly-batch.md` step 3 points here) — read it as
"how registration works," not "realisateur's own status."

## What the scheduler is

`~/Documents/Projects/scheduler` is a shared engine + config registry
that runs unattended `claude -p` jobs on top of plain cron — it is **not a
daemon**. Two job tiers a project can opt into, independently:

- **Tier 1 — Bug Sweeper**: fast, frequent (e.g. every 15 min), narrow,
  fixed daytime window. Mechanical fixes only, against a live web tracker's
  open-report queue. Skip this tier if the project has no such tracker.
- **Tier 2 — Overnight Batch**: slow, thorough, broad. One long unattended
  run per night, scoped entirely by the project's own `.scheduler/FOCUS.md`.
  Builds features too, not just fixes — see the autonomy policy below.

Every registered project's Tier 2 batch currently runs through a shared
**usage-paced governor** rather than a fixed cron time (`schedule/_paced.conf`
+ `bin/usage-paced-runner.sh`): it round-robins enabled participants and only
fires a cycle when there's spare weekly usage quota, so nightly jobs don't
collectively blow the usage cap. New projects join this same rotation, not a
hand-picked cron slot.

## What registering actually requires

Read `~/Documents/Projects/scheduler/README.md` and `MIGRATION.md`
first — they're the source of truth; this file is a project-specific
pointer into them, not a replacement. In short, registering means:

1. **`realisateur` must be a git repo with a remote the scheduler can clone
   from unattended.** The engine works in a dedicated, disposable clone —
   `git clone`, `reset --hard`, invoke `claude`, push, repeat. The remote can
   be:
   - A real GitHub repo, cloned over SSH via a **passphrase-less per-repo
     deploy key** + a `~/.ssh/config` host alias (see the `github-*-deploy`
     aliases already set up for chezz/home-assistant/wtul/vkv), since cron
     has no ssh-agent. This is the standard path.
   - A **local bare repo** (`git init --bare` somewhere like
     `~/git-remotes/realisateur.git`, then `git remote add origin ...` and
     push) — no credentials or network needed at all. `crt` (a project with
     no GitHub presence) uses exactly this, and a GitHub mirror can be added
     later without disrupting anything by swapping `REPO_URL`.

2. **A `.scheduler/FOCUS.md`** — the single file that scopes every Tier 2
   run. (`.scheduler/`, NOT `.claude/`: the harness's sensitive-file gate
   blocks unattended writes to any `.claude/` path, so a FOCUS.md there is
   unwritable by the very nightly runs it scopes — the 2026-07-26
   migration decision. Set `SCHEDULER_SUBDIR=".scheduler"` in the
   project's `schedule/<name>.conf` so the audits and symlinks follow.)
   Copy the shape from `scheduler/examples/FOCUS.md.template`, or read a real
   one (`crt`'s or `chezz`'s) for a fuller example. Key convention worth
   knowing before writing it: the **"build maximally autonomously" policy**
   — an unattended nightly run is expected to actually build reasonable
   things, not just report on them, committing/branching as it goes; the
   only real stop-and-wait bar is an action that can't be reverted (a real
   message to a person, spending real money, deleting something with no
   backup — not an ordinary commit or branch).

3. **A `.scheduler/QUESTIONS.md`** — the two-way channel for anything needing a
   human decision. Either tier appends a question; you reply inline with a
   `> ` blockquote under it; the next nightly run reads and acts on answered
   questions, then removes them (git history + that run's report keep the
   record). Template: `scheduler/examples/QUESTIONS.md.template`.

4. **A `.claude/commands/nightly-batch.md`** (and `bug-sweep.md` if doing
   Tier 1) — the actual prompt/instructions the unattended run follows.
   Templates: `scheduler/examples/nightly-batch.md.template` and
   `bug-sweep.md.template`. Adapt the report path and tracker-specific
   sections to `realisateur`'s reality — e.g. if there's no web tracker (like
   `crt`), the command should say so explicitly and scope purely off
   `FOCUS.md` instead of `../INTAKE.md`.

5. **A root `CLAUDE.md`** (optional but recommended) — copy
   `scheduler/examples/CLAUDE.md.template`: the "suggest `/ideate
   <project>` instead of implementing" guardrail, so an ordinary
   interactive session on the new project recognizes an open-ended/
   vision-shaped ask and points at realisateur's `/ideate` rather than
   quietly building against it inline.

6. **One file dropped into the scheduler repo**:
   `schedule/realisateur.conf`, copied from
   `scheduler/examples/schedule-entry.conf.template`. This is the single
   source of truth for both *when* the job fires and *how* it runs —
   `REPO_URL`, `PROJECT_REPO_PATH` (this checkout, so `FOCUS.md`/
   `QUESTIONS.md` get symlinked into the scheduler's `focus/`/`questions/`
   aggregation folders), and per-tier `BATCH_PROMPT`/`BATCH_MAX_TURNS`/etc.
   Leave `BATCH_SCRIPT` unset — new projects go straight onto the generic
   `bin/scheduler-run` entrypoint, no bespoke wrapper script needed (older
   projects like chezz still have legacy `*_SCRIPT` wrappers for
   backwards-compat reasons; don't copy that pattern for a new project).

7. **Preview, then apply**: from the scheduler repo,
   `bin/sync-crontab.sh` (no `--apply`) to check the generated config, then
   `bin/sync-crontab.sh --apply` to actually install the symlinks/crontab
   changes.

## A gotcha worth knowing before the first run

The very first project to go through the pure `scheduler-run` + raw
`BATCH_PROMPT="/nightly-batch"` path (as opposed to a legacy `*_SCRIPT`
wrapper) was `crt`, registered 2026-07-19. Its first run failed because the
dedicated clone briefly caught a commit older than the one that added
`.claude/commands/nightly-batch.md` — a stale-clone timing issue, not a
scheduler bug — and self-healed on the next cycle once `origin/main` had the
command file. Moral: **push `.claude/commands/nightly-batch.md` (and
FOCUS.md/QUESTIONS.md) to the remote *before* registering**, and check the
first run's report/log rather than assuming it worked.

## Who to ask

Zach owns all policy/scope decisions here — the scheduler's own
`.scheduler/FOCUS.md` backlog and `QUESTIONS.md` are where open
questions about the ecosystem itself (not this project) get tracked.
