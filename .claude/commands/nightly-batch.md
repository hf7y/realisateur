---
description: Nightly pass -- infer ideas from dropped inbox artifacts and wire them into scaffolded, scheduler-registered projects
---

Read `.claude/FOCUS.md` first -- including its "build maximally
autonomously" policy. Build first, don't just analyze: pick the most
reasonable interpretation of an inbox artifact and scaffold a real project
for it, flagged in `.claude/QUESTIONS.md` and the report. Only actually
stop and wait for the user when the action itself can't be reverted -- an
ordinary commit, branch, or new local scheduler registration never
qualifies.

This command is designed to run unattended overnight, with no human
review step until the morning.

## 1. Orient

`git log --oneline -10`, `README.md`, and `.claude/FOCUS.md`. If a
previous nightly run left work in progress (check the last report under
`~/reports/realisateur/`), pick up from there rather than starting over.

**Run `bin/ecosystem-survey.sh`** (offline, no AI cost, ~2s) before
reasoning about anything else. It's realisateur's own equivalent of
`scheduler status <project>` but across every registered project at
once: per-project git health/open-questions/last-run-outcome (via
`scheduler status`), plus an ecosystem-wide ranking of the oldest still-
open dated ideas across every project's `FOCUS.md` -- the concrete signal
behind "vision debt" (see `chezz/.claude/commands/ideate.md` 4.5 for
where that pattern was named). Treat its output as a starting map of
real current state, not something to act on item-by-item unprompted --
most of what it surfaces belongs to other projects' own nightly-batch
runs, not this one. It exists so this session (and `/ideate`) starts
from ground truth instead of a stale mental model of the ecosystem.

**Read `.claude/QUESTIONS.md` and process any answers.** The user replies
inline, on a line starting with `> ` directly under a question --
QUESTIONS.md's own header documents the convention. Treat any `> `
answer as authoritative (same standing as FOCUS.md): act on it, fold a
standing decision into FOCUS.md if it should persist, then remove that
question+answer block once acted on. Leave unanswered questions
untouched.

## 2. Find the inbox

The inbox is whatever's sitting at the repo root (or under an `inbox/`
subdirectory if one exists by now) that isn't part of realisateur's own
scaffolding (`README.md`, `SCHEDULER.md`, `.claude/`, `.git/`, an
`archive/` directory). It could be a text file, a PNG, anything -- there
is no fixed naming convention, per `README.md`. Read every text artifact;
view every image artifact.

## 3. Infer and wire up, one artifact at a time

For each unarchived artifact:

- Infer the idea it's pointing at. If it's too vague to act on (a single
  ambiguous word, an image with no clear direction), leave it in the
  inbox rather than guessing wildly -- but a genuine partial idea should
  still get a best-effort scaffold, not be skipped for being imperfect.
- **First check whether the artifact is actually about realisateur's own
  process/workflow, not a new sibling project** -- e.g. "look into how
  the scheduler's idea logic could unite with my habit of dropping notes
  here" is feedback about this repo, not raw material for a new
  `~/Documents/Projects/<name>/`. Telltale: it names realisateur, the
  scheduler, or "this folder/workflow" itself as the subject. For these,
  don't scaffold a project -- research the answer, fold the finding/
  decision into `.claude/FOCUS.md` (a dated bullet is enough) and/or
  `README.md` if it changes the documented process, then archive the
  source artifact same as any other processed idea.
- Check whether a project for this idea already exists under
  `~/Documents/Projects/` before creating a new one -- an artifact might
  be an addition to something already scaffolded, not a brand-new project.
- For a genuinely new idea: create `~/Documents/Projects/<name>/`, `git
  init` it, write a minimal README describing the inferred idea and
  initial scaffolding (actual code/structure appropriate to what was
  inferred -- don't leave it as just a README).
- If the new project is the kind of thing that benefits from unattended
  nightly iteration (most agent/codebase projects are), wire it into the
  scheduler exactly as `SCHEDULER.md` documents for realisateur itself:
  a local bare remote under `~/git-remotes/<name>.git` (no GitHub
  credentials needed unless one already clearly exists for this idea), a
  `.claude/FOCUS.md` + `.claude/QUESTIONS.md` +
  `.claude/commands/nightly-batch.md` for the new project (adapt the
  templates in `~/Documents/Project Archive/scheduler/examples/` to what
  the new project actually is), push to the bare remote, then drop
  `schedule/<name>.conf` into the scheduler repo (copy
  `schedule-entry.conf.template`, `BATCH_CRON="auto"`, no `BATCH_SCRIPT`)
  and add it to `schedule/_paced.conf` as a new participant with a thin
  `~/.local/bin/<name>-nightly-batch-loop.sh` wrapper (mirror
  `crt-nightly-batch-loop.sh` exactly -- it's the current canonical
  no-legacy-wrapper example). Preview with `bin/sync-crontab.sh`, then
  `--apply`.
- Move the source artifact into `archive/` (create it if missing) once
  acted on, or once a real decision was made not to (note why in the
  report either way).

## 4. Commit as you go

Commit realisateur's own repo (inbox archival, any scaffolding that lives
here) as each artifact is processed, not all in one giant commit at the
end. Each new project gets its own first commit(s) in its own repo.

## 5. Flag what you built, and anything needing the user's own judgment

Append-only, format `- **YYYY-MM-DD (nightly-batch):** <text>`, in
`.claude/QUESTIONS.md`:

- **Every new project scaffolded tonight** -- what artifact it came from,
  what was inferred, where it lives, whether it got a scheduler
  registration.
- **A genuine judgment call needing the user's own decision** -- not
  "should I build this" (default: yes), but something actually
  ambiguous: two very different readings of the same artifact, or a case
  where a GitHub remote (real credentials) seemed like it might genuinely
  be warranted instead of a local bare one.

## 6. Write the report

`~/reports/realisateur/$(date +%Y-%m-%d).md`, and update
`~/reports/realisateur/LATEST.md` to match. Cover: which inbox artifacts
were processed and what was inferred from each, which new projects were
scaffolded (and whether scheduler-registered), what was archived, what
was deliberately left unprocessed and why, and whether anything got
appended to `.claude/QUESTIONS.md`.

## 7. Before finishing

Confirm every meaningful change -- in realisateur's own repo AND in any
new project's repo -- has a real commit, pushed to its remote. An
overnight run that is not saved anywhere didn't happen.
