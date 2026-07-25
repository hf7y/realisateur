# fable-like/ — a parallel, tidied copy of your ecosystem

**What this is.** A read-only *exhibit*, not a mechanism. Nothing in here is wired
to cron, the scheduler, or any boot path — per BUILD-DISCIPLINE.md, that means it
retires nothing and claims nothing. It is a scale model of your ecosystem as it
could look after the file-structure normalization you already decided on
(2026-07-24, queued not built), plus a handful of structural improvements argued
for in `FABLE_REPORT.md`.

Explore it like a show home. Every project directory contains a distilled
`README.md` and a `.scheduler/FOCUS.md` in the canonical milestone format —
including **proposed** milestones for the six projects that have none today.

## The map

```
fable-like/
├── README.md              ← you are here
├── FABLE_REPORT.md        ← the honest accounting (ecosystem + per-project)
├── inject-suggestions.sh  ← propagates the suggestions into your REAL projects (dry-run by default)
├── desk/                  ← the only surface you look at daily
│   ├── MORNING.md         ← example generated glance (with the liveness column that would
│   │                        have caught the aedile/vkv-inventory silent orphaning)
│   └── BLOCKERS.md        ← the human-only queue, with the blocking/waiting/fyi taxonomy
├── projects/              ← ONE root. No "Project Archive" holding your most active repo.
│   ├── scheduler/         ← the engine (moved out of Project Archive)
│   ├── realisateur/       ← the vision organ
│   ├── crt/  chezz/  gardien/  groc-mangr/  home-assistant/
│   ├── nine-speakers/  senechal/  sequestria/  vim-arcade/  wtul/
│   ├── bibliothecaire/    ← your live inbox idea, shown scaffolded ("page 92")
│   ├── secretaire/        ← your live inbox idea, shown scaffolded (email triage)
│   ├── vkv-aedile/        ← NOTE: can't actually move — co-owned with Tyler; see its README
│   └── vkv-inventory/
└── archive/               ← where "Project Archive" contents that are ACTUALLY archived go
    └── README.md
```

## What changed, and why

1. **One root.** Today: `~/Documents/Projects/`, `~/Documents/Project Archive/`,
   `~/Documents/wtul`, `~/Documents/vkv/`. Here: `projects/` + `archive/`. This is
   your own decided plan — the model just shows what it looks like finished. Each
   real move pairs with its `schedule/<name>.conf` `PROJECT_REPO_PATH` update in
   the same commit, per your sequencing note.

2. **`.scheduler/` everywhere, `.claude/` nowhere.** chezz's unattended runs
   can't write `.claude/QUESTIONS.md` (sensitive-file gate); aedile already had to
   use `.scheduler/` because `.claude/` is gitignored in the monorepo; wtul's
   migration is already in BLOCKERS.md. The ecosystem is drifting toward
   `.scheduler/` one pain at a time — this model just finishes the drift and
   retires `SCHEDULER_SUBDIR` as a per-project override entirely (one config
   source, not retyped per conf).

3. **The desk realized.** Your loose `Projects/FOCUS.md` says: *"When I open
   Projects/, I see only .md documents for my attention… Otherwise, my desk is
   empty."* That vision file is currently stranded and unregistered. Here it
   becomes `desk/` — the morning glance and the human-only blockers queue in one
   place, with the projects tucked one level down.

4. **A liveness guard exists.** `projects/scheduler/bin/liveness-audit.sh` is a
   working example of the one mechanical check whose absence cost you the most:
   *every enabled participant must have produced a report within N days, or the
   morning glance shouts.* aedile and vkv-inventory went dark on 2026-07-20 and
   nobody — human or agent — noticed for four days.

5. **Every project has a milestone.** Six of your fourteen have none; the parked
   set and the unmilestoned set are nearly identical, which means "parked" is
   currently doing double duty for "never triaged." Parking is supposed to be a
   choice. The proposed milestones (marked `PROPOSED (fable)`) make re-admission
   defined even for parked projects.

## What this exhibit deliberately does NOT do

- It does not copy code, git history, secrets, or reports — docs only.
- It does not claim the vkv subtree can move (Tyler co-owns wavebucks; see
  `projects/vkv-aedile/README.md`).
- It does not touch your real projects. That's what `inject-suggestions.sh` is
  for, and it dry-runs by default.
