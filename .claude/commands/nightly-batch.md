---
description: Nightly pass -- infer ideas from dropped inbox artifacts and wire them into scaffolded, scheduler-registered projects
---

Read `.scheduler/FOCUS.md` first -- including its "build maximally
autonomously" policy. Build first, don't just analyze: pick the most
reasonable interpretation of an inbox artifact and scaffold a real project
for it, flagged in `.scheduler/QUESTIONS.md` and the report. Only actually
stop and wait for the user when the action itself can't be reverted -- an
ordinary commit, branch, or new local scheduler registration never
qualifies.

This command is designed to run unattended overnight, with no human
review step until the morning.

## 1. Orient

`git log --oneline -10`, `README.md`, and `.scheduler/FOCUS.md`. If a
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

`ecosystem-survey.sh` also runs **`bin/precipitation-scan.sh`** at its end
(promotion signals: re-arrival candidates and interface clusters --
doctrine in `PRECIPITATION.md`). Oldest-first, above, is the WEAKEST of
the five ranked signals. **In an unattended pass, treat reports B and C
as READ-ONLY.** They are inference over prose, and their most convincing
output is the most likely to be wrong -- a 5-project "cluster" on
2026-07-26 turned out to be a shared boilerplate footer (worked example
in `PRECIPITATION.md`). Confirming a candidate means opening its members
and judging shape stability, which is a `/ideate` job with a human
present, not a batch one. What this pass MAY do: note a striking
candidate in `.scheduler/FOCUS.md` or `QUESTIONS.md` for the next
interactive pass to judge. What it must NOT do: stamp
`(re-arrival: …)`/`[iface: …]`, reorder anything, or change a weight on
the strength of the scan alone. A promotion nobody stated is the silent
reorder `/ideate` 4.5 forbids.

**Then run `bin/hygiene-lint.sh`** (offline, no AI cost). It's the third
mechanical survey alongside `ecosystem-survey.sh`: it scans every
registered project for the recurring build/deploy failure signatures in
`BUILD-DISCIPLINE.md` -- secrets in tracked files, build debris, finished-
but-uncommitted scripts, missing exec bits, silent-pipeline smells, config
duplication. Same stance as the others: its FLAGs are *signals*, not
verdicts -- a human/AI confirms each before acting, and most belong to
other projects' own nightly runs, not this one. Note any FLAG against a
project *this* run touches and fix it before committing; don't go fix the
whole ecosystem unprompted.

**Then run `bin/milestone-audit.sh`** (offline, no AI cost). The third
survey: per registered project it reports whether a `## Stability
milestone` is declared, its current bar + status
(`not-started`/`in-progress`/`reached`), and a rough parked/waiting
reservoir signal. Convention: `STABILITY-MILESTONES.md`. This is what makes
the park-by-default triage in step 3 decidable — you need each project's
current milestone in front of you before judging whether an idea is
`active` (required to reach it) or `parked` (beyond it). A project whose
status is `reached` is a signal to set a new milestone or graduate it
(drop its `_paced.conf` weight) — same signals-not-verdicts stance as the
other two surveys.

**Then run `bin/steward-survey.sh`** (offline, no AI cost). The fifth
survey, and the only one that reads `_paced.conf`'s `enabled` flag — the
other four report on every registered project as though it were running.
It answers the steward question none of them can: **which organs are dark,
and how much undrained vision is stranded behind each one.** Columns:
paced weight, days since the repo's last commit, count of open dated ideas
in its FOCUS.md, milestone status.

Read it in the order its own summary states. The loudest signal is a
**DARK row with a high weight** — weight is stated intent, `enabled=0` is
actual dispatch, and the two disagreeing means an intention stopped being
acted on without anyone deciding to stop. Second is a DARK row with a
large stranded count: a reservoir filling behind a shut valve. Same
signals-not-verdicts stance as its four siblings — **a dark project is
very often deliberate** (`gardien` is blocked on hardware, `crt` was
switched off on purpose), so this pass NEVER re-enables a project or
changes a weight on the strength of the scan. Note a striking row in
`.scheduler/FOCUS.md` for the next interactive pass to judge.

**Read `.scheduler/QUESTIONS.md` and process any answers.** The user replies
inline, on a line starting with `> ` directly under a question --
QUESTIONS.md's own header documents the convention. Treat any `> `
answer as authoritative (same standing as FOCUS.md): act on it, fold a
standing decision into FOCUS.md if it should persist, then remove that
question+answer block once acted on. Leave unanswered questions
untouched.

## 2. Find the inbox

The inbox is whatever's sitting at the repo root (or under an `inbox/`
subdirectory if one exists by now) that isn't part of realisateur's own
scaffolding (`README.md`, `SCHEDULER.md`, `.claude/` (commands only), `.scheduler/`, `.git/`, an
`archive/` directory). It could be a text file, a PNG, anything -- there
is no fixed naming convention, per `README.md`. Read every text artifact;
view every image artifact.

### 2a. If the inbox is empty — do a STEWARD pass, not meta-work

An empty inbox is now the **normal** state, not an exception. Intake is
bursty; most nights there is nothing dropped.

**The failure mode this section exists to prevent** (observed 2026-07-26,
seven batch runs in one day): with no inbox artifact to work on, the pass
goes looking for work in the only place left — realisateur itself — and
builds another lint, guard, or record *about its own batch process*. Each
one is real, tested, committed code, which is what makes it hard to see.
But that day produced five new scripts for realisateur's own workflow and
**zero** commits into any of the twelve scaffolded projects. That is a
productive treadmill: the organ that exists to perceive the ecosystem
spent the night perceiving itself.

So when there is no artifact to process, the job is **stewardship of the
other projects**, and the output is *routing*, not building:

- Re-read `bin/steward-survey.sh`'s section A and B from step 1.
- Pick the **one** most striking row — a dark high-weight project, a
  reservoir stranded behind a closed valve, a live weight-1 project whose
  oldest open idea is weeks old.
- Write it up as a dated entry in `.scheduler/FOCUS.md`, and if it needs a
  human decision (re-enable? reweight? park the stranded ideas?), put a
  `> `-answerable question in `.scheduler/QUESTIONS.md`. **Re-enabling a
  project or changing a weight is not this pass's call** — those are
  stated decisions, and a batch run making them silently is the reorder
  `/ideate` §4.5 forbids.
- Then **stop**. A steward pass that surfaces one thing clearly and
  builds nothing is a complete, successful run. Say so in the report.

**Explicitly out of scope on an empty-inbox night:** authoring a new lint,
survey, guard, or command for realisateur itself. If the pass believes one
is needed, that belief is the output — file it as a `[batch]` row in
`.scheduler/FOCUS.md` for a pass with a human present, and do not build it
tonight. Realisateur already has five surveys; the sixth needs a stated
reason from outside this loop.

## 3. Infer and wire up, one artifact at a time

**Before writing into ANY repo other than realisateur's own, run
`bin/check-project-busy.sh <project>`** (offline, ~instant -- flock-probes
that project's own scheduler job locks). If it reports `BUSY: <job-name>`,
that project's automation is mid-run against the same files RIGHT NOW:
**defer the write**, note it in the report and `.scheduler/QUESTIONS.md`
for the next pass, and carry on with the rest of this run. This is the
same guard `/ideate` has used since the 2026-07-24 concurrency finding,
and it belongs here at least as much: an unattended pass has no human
watching to notice it just edited a file out from under a live job.

Applies to the **scheduler repo too** (`check-project-busy.sh scheduler`)
-- registering a new project edits `schedule/*.conf` and `_paced.conf`
while scheduler is itself a paced participant with runs of its own.
Scaffolding a genuinely new project is the one exempt case: nothing is
dispatching against a repo that did not exist a minute ago.

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
  decision into `.scheduler/FOCUS.md` (a dated bullet is enough) and/or
  `README.md` if it changes the documented process, then archive the
  source artifact same as any other processed idea.
- Check whether a project for this idea already exists under
  `~/Documents/Projects/` before creating a new one -- an artifact might
  be an addition to something already scaffolded, not a brand-new project.
- **If it's an addition to an existing project, apply park-by-default
  triage** (see `STABILITY-MILESTONES.md`): is this idea required to reach
  that project's *current* stability milestone (from `milestone-audit.sh` /
  its FOCUS.md)? If **yes**, it's `active` -- build/queue it normally. If
  **no**, **park it**: append it to that project's FOCUS.md tagged
  `(parked)` with one line of why it's past the milestone, and do NOT build
  it tonight. Parking is the default for anything beyond the current bar --
  building past the milestone unprompted is the failure mode this convention
  exists to prevent. A brand-new project is exempt: the inbox idea *is* its
  v1, so scaffold it and set its first `## Stability milestone` as part of
  the scaffold (below).
- For a genuinely new idea: create `~/Documents/Projects/<name>/`, `git
  init` it, write a minimal README describing the inferred idea and
  initial scaffolding (actual code/structure appropriate to what was
  inferred -- don't leave it as just a README). When you write its
  `.scheduler/FOCUS.md` (below), open it with a `## Stability milestone`
  section (canonical shape in `STABILITY-MILESTONES.md`) whose bar is the
  inferred **v1 core** of the idea, `status: not-started`. That milestone
  is what every later idea against the project gets park-by-default-triaged
  against.
- **Stamp the build-discipline baseline into every new project** so the
  lessons in `BUILD-DISCIPLINE.md` are inherited from day one, not
  rediscovered per project the hard way (see that file for why -- it
  generalizes `crt`'s retrospective):
  - Append the "Build discipline" checklist block from
    `BUILD-DISCIPLINE.md` to the new project's root `CLAUDE.md`.
  - Write a baseline `.gitignore` that blocks secrets and build debris
    before the first `git add`: at minimum
    `*.env`, `.env`, `secrets/`, `*secret*`, `*cred*`, `*.pem`, `*.key`,
    `id_rsa*`, plus build/debris `*.img`, `*.img.xz`, `*.iso`, `*.efi`,
    `*.dmg`, `*.log`, `__pycache__/`, `*.pyc`, `.DS_Store`. Real secrets
    go in an untracked `.env`/`secrets/`, never a tracked file.
  - `bin/hygiene-lint.sh <name>` should come back clean (or only advisory
    NOTEs) before you consider the scaffold done -- that's the mechanical
    proof the baseline actually took.
- If the new project is the kind of thing that benefits from unattended
  nightly iteration (most agent/codebase projects are), wire it into the
  scheduler exactly as `SCHEDULER.md` documents for realisateur itself:
  a local bare remote under `~/git-remotes/<name>.git` (no GitHub
  credentials needed unless one already clearly exists for this idea), a
  `.scheduler/FOCUS.md` + `.scheduler/QUESTIONS.md` (NOT `.claude/` -- the
  sensitive-file gate blocks unattended writes there; set `SCHEDULER_SUBDIR=".scheduler"` in the conf) + `.claude/commands/nightly-batch.md` + a root `CLAUDE.md` (adapt the
  templates in `~/Documents/Project Archive/scheduler/examples/` to what
  the new project actually is -- `CLAUDE.md.template` is the "suggest
  `/ideate <project>` instead of implementing" guardrail, worth every new
  project having from day one), push to the bare remote, then drop
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

### 3a. Two mandatory write paths

**Every `.scheduler/FOCUS.md` / `.scheduler/QUESTIONS.md` commit goes
through `bin/focus-commit.sh <repo> <msgfile> <file>...`** — never a bare
`git add` + `git commit` + `git push`. It commits exactly the named files
(anything else already staged is a loud abort, so an unrelated
working-tree edit can never ride along inside a FOCUS commit), does the
fetch/rebase/retry itself on a rejected push, and verifies the rebase did
not change what the commit means. That last check is the one that would
have caught the 2026-07-26 rename-following rebase that silently rewrote
an archived artifact's content. The bare sequence is prose discipline
carried in session memory; this is the guard.

**Every machine-wide config change goes through
`bin/notify-senechal.sh '<what, where, who owns it>'`** — crontab entries,
`~/.claude` settings hooks, systemd units, autostart, WM config, marker
files under `~/.local/share`. Standing rule: realisateur *owns* the thing
it generates; senechal *owns knowing it exists*. The script files through
`scheduler -i senechal` (the front door — a staleness-checked commit path
that is safe against a live senechal run, unlike a hand edit of its
FOCUS.md) and then confirms the note actually reached senechal's remote,
because `scheduler -i` skips the push when the repo is behind origin and
an unpushed note is invisible to senechal's own nightly clone.

## 4. Commit as you go

Commit realisateur's own repo (inbox archival, any scaffolding that lives
here) as each artifact is processed, not all in one giant commit at the
end. Each new project gets its own first commit(s) in its own repo.

## 5. Flag what you built, and anything needing the user's own judgment

Append-only, format `- **YYYY-MM-DD (nightly-batch):** <text>`, in
`.scheduler/QUESTIONS.md`:

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
appended to `.scheduler/QUESTIONS.md`.

## 7. Before finishing

Confirm every meaningful change -- in realisateur's own repo AND in any
new project's repo -- has a real commit, pushed to its remote. An
overnight run that is not saved anywhere didn't happen.
