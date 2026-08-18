---
scope: project
description: Nightly pass -- infer ideas from dropped inbox artifacts and wire them into scaffolded, scheduler-registered projects
---

Build first, don't just analyze: pick the most reasonable interpretation of
an inbox artifact and scaffold a real project for it, and say so in the
report. Only actually stop and wait for the user when the action itself
can't be reverted -- an ordinary commit, branch, or new local scheduler
registration never qualifies.

**Findings go in the issue tracker, never in a markdown surface.**
`BLOCKERS.md`, `.scheduler/FOCUS.md` and `.scheduler/QUESTIONS.md` were
retired by hf7y/scheduler#66 and do not exist in this repo. One
destination, and it is a command: `gh issue create -R hf7y/realisateur`.

This command is designed to run unattended overnight, with no human
review step until the morning.

## 1. Orient

`git log --oneline -10`, `README.md`, and the open issues
(`gh issue list -R hf7y/realisateur`). If a
previous nightly run left work in progress (check the last report under
`~/reports/realisateur/`), pick up from there rather than starting over.

**Promotion signals are inference over prose, and the most convincing output
is the most likely to be wrong** -- a 5-project "cluster" on 2026-07-26 turned
out to be a shared boilerplate footer (worked example in
`vault:realisateur/PRECIPITATION.md`). Judging one means opening its members
and reading them, which is an `/ideate` job with a human present, not a batch
one. This pass MAY file a striking candidate as an issue for the next
interactive pass. It must NOT stamp `(re-arrival: …)`/`[iface: …]`, reorder
anything, or change a weight. A promotion nobody stated is the silent reorder
`/ideate` 4.5 forbids.

RETIRED 2026-08-07: `ecosystem-survey.sh`, `milestone-audit.sh` and
`steward-survey.sh`. Four scripts each re-implemented the same
`schedule/*.conf` enumeration, nothing ran any of them, and two computed the
same FOCUS.md fact with a character-identical expression and printed it under
two different names. For per-project git health and open questions use
`scheduler status <project>` directly, which is what `ecosystem-survey.sh`
was calling. See `bin/tests/guard-estate.test.sh` for the standard the
survivors are now held to, and for what is knowingly given up.

(The third survey was `bin/hygiene-lint.sh`, retired: hf7y/realisateur#265.)

**Read the answers on your own issues and process them.** Zach answers by
commenting and LEAVING THE ISSUE OPEN -- state and labels say nothing about
whether he answered, so an open question issue is *not* evidence that it is
unanswered. Sweep across **all** states. Rule, predicate and history:
`SCHEDULER.md`, "What is true now". Treat
any such comment as authoritative: act on it, and if the decision should
persist, put it where the mechanism it governs lives. Then remove that
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
seven batch runs in one day): with no artifact to work on, the pass goes
looking for work in the only place left -- realisateur itself -- and builds
another lint, guard or record *about its own batch process*. Each one is real,
tested, committed code, which is what makes it hard to see. That day produced
five new scripts for realisateur's own workflow and **zero** commits into any
of the twelve scaffolded projects.

So when there is no artifact to process, the job is **stewardship of the
other projects**, and the output is *routing*, not building:

- Pick the **one** most striking row — a dark high-weight project, a
  reservoir stranded behind a closed valve, a live weight-1 project whose
  oldest open idea is weeks old.
- **File it as an issue.** If it needs a human decision (re-enable?
  reweight? park the stranded ideas?), the issue IS the question.
  **Re-enabling a project or changing a weight is not this pass's call** — those are
  stated decisions, and a batch run making them silently is the reorder
  `/ideate` §4.5 forbids.
- Then **stop**. A steward pass that surfaces one thing clearly and
  builds nothing is a complete, successful run. Say so in the report.

**Explicitly out of scope on an empty-inbox night:** authoring a new lint,
survey, guard, or command for realisateur itself. If the pass believes one
is needed, that belief is the output — file it as an issue for a pass with
a human present, and do not build it tonight. Realisateur already has five surveys; the sixth needs a stated
reason from outside this loop.

## 3. Infer and wire up, one artifact at a time

**Before writing into ANY repo other than realisateur's own, run
`bin/check-project-busy.sh <project>`** (offline, ~instant -- flock-probes
that project's own scheduler job locks). If it reports `BUSY: <job-name>`,
that project's automation is mid-run against the same files RIGHT NOW:
**defer the write**, note it in the report and in the issue it belongs to,
and carry on with the rest of this run. This is the
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
  don't scaffold a project -- research the answer, record the decision
  where the mechanism it governs lives (or `README.md` if it changes the
  documented process), then archive the source artifact same as any other
  processed idea.
- Check whether a project for this idea already exists under
  `~/Documents/Projects/` before creating a new one -- an artifact might
  be an addition to something already scaffolded, not a brand-new project.
- **If it's an addition to an existing project, apply park-by-default
  triage** (see `vault:realisateur/STABILITY-MILESTONES.md`): is this idea required to reach
  that project's *current* stability milestone (its open `milestone`-
  labelled issue)? If **yes**, it's `active` -- build/queue it normally. If
  **no**, **park it**: `bin/defere.sh '<one line>' --project <name>` to
  file it as a `deferred` issue, and do NOT build it tonight. Parking is
  the default for anything beyond the current bar --
  building past the milestone unprompted is the failure mode this convention
  exists to prevent. A brand-new project is exempt: the inbox idea *is* its
  v1, so scaffold it and set its first `## Stability milestone` as part of
  the scaffold (below).
- For a genuinely new idea: create `~/Documents/Projects/<name>/`, `git
  init` it, write a minimal README describing the inferred idea and
  initial scaffolding (actual code/structure appropriate to what was
  inferred -- don't leave it as just a README). Its **stability
  milestone** (canonical shape in `vault:realisateur/STABILITY-MILESTONES.md`) is the
  inferred **v1 core** of the idea, filed as a `milestone` issue,
  `status: not-started`. That milestone is what every later idea against
  the project gets park-by-default-triaged against.
- **Point every new project at `discipline`; do NOT copy the checklist in.**
  Its root `CLAUDE.md` gets a one-line pointer to the command. Copying the
  block is what realisateur#263 retired.
  - Write a baseline `.gitignore` that blocks secrets and build debris
    before the first `git add`: at minimum
    `*.env`, `.env`, `secrets/`, `*secret*`, `*cred*`, `*.pem`, `*.key`,
    `id_rsa*`, plus build/debris `*.img`, `*.img.xz`, `*.iso`, `*.efi`,
    `*.dmg`, `*.log`, `__pycache__/`, `*.pyc`, `.DS_Store`. Real secrets
    go in an untracked `.env`/`secrets/`, never a tracked file.
  - Prove it took by RUNNING `discipline` from the new project and seeing the
    full checklist, not by trusting that a file was written.
- If the new project is the kind of thing that benefits from unattended
  nightly iteration (most agent/codebase projects are), wire it into the
  scheduler exactly as `SCHEDULER.md` documents for realisateur itself:
  a GitHub repo under `hf7y` (its issue tracker is where the project's
  prose lives -- do NOT create `.scheduler/FOCUS.md`, `QUESTIONS.md` or
  `BLOCKERS.md`; scaffolding them is how the retired surfaces kept being
  reborn after hf7y/scheduler#66), a `.claude/commands/nightly-batch.md`
  and a root `CLAUDE.md` (adapt the templates in scheduler's `examples/`
  to what the new project actually is -- `CLAUDE.md.template` is the
  "suggest `/ideate <project>` instead of implementing" guardrail, worth
  every new project having from day one), then register it with the
  scheduler as `SCHEDULER.md` documents.

  **Dispatch registration is in flux** -- hf7y/realisateur#228 is retiring
  per-account cron and `usage-paced-runner`. Check that issue before
  copying a crontab shape out of an older project; do not add a new
  per-account cron line on monkey without reading it.
- Move the source artifact into `archive/` (create it if missing) once
  acted on, or once a real decision was made not to (note why in the
  report either way).

### 3a. The mandatory write path

**Every machine-wide config change goes through
`notify-senechal '<what, where, who owns it>'`** — crontab entries,
`~/.claude` settings hooks, systemd units, autostart, WM config, marker
files under `~/.local/share`. Standing rule: realisateur *owns* the thing
it generates; senechal *owns knowing it exists*. It files a labelled issue
on `hf7y/senechal` with `gh` directly and reads it back to confirm it
landed, so it needs no clone of that repo and no push access to it.

Do not create `FOCUS.md`/`QUESTIONS.md` here in order to have something to
commit. They are retired (hf7y/scheduler#66).

## 4. Commit as you go

Commit realisateur's own repo (inbox archival, any scaffolding that lives
here) as each artifact is processed, not all in one giant commit at the
end. Each new project gets its own first commit(s) in its own repo.

## 5. Flag what you built, and anything needing the user's own judgment

One issue per item, on `hf7y/realisateur`:

- **Every new project scaffolded tonight** -- what artifact it came from,
  what was inferred, where it lives, whether it got a scheduler
  registration.
- **A genuine judgment call needing the user's own decision** -- not
  "should I build this" (default: yes), but something actually
  ambiguous: two very different readings of the same artifact, or a case
  where a GitHub remote (real credentials) seemed like it might genuinely
  be warranted instead of a local bare one.

## 6. Report in the run, not in a file

Do NOT write a dated report file. scheduler's standing rule 5 bans it --
*"NO NEW MARKDOWN FILES. Do not write a handoff, session record, design note,
sprint summary, or retrospective. Prose is not a deliverable."* This command
told you to write one until 2026-08-17.

End the run by saying, in the run's own output: which artifacts were
processed and what was inferred, which projects were scaffolded and whether
registered, what was archived, what was left and why, and which issues were
filed. Anything that must survive the run is an ISSUE, not a paragraph.

## 7. Before finishing

Confirm every meaningful change -- in realisateur's own repo AND in any
new project's repo -- has a real commit, pushed to its remote. An
overnight run that is not saved anywhere didn't happen.
