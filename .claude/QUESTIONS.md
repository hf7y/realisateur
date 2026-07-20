# Questions for the user

<!-- Copy this to .claude/QUESTIONS.md in a project's repo (or just let
     /bug-sweep or /nightly-batch create it on first use -- both commands
     already know to). Running log, appended to (never overwritten or
     trimmed) by either command whenever something bigger than a routine
     tracker note comes up -- an ambiguous policy question, a real
     tradeoff, a "which of these two directions" fork. This is the "can
     both tiers flag something for me, somewhere I can easily find it"
     answer -- deliberately a real file at the repo root, not buried in
     ~/reports/, so opening the project itself surfaces it (and it's
     symlinked into scheduler/questions/<project>.md + printed by
     bin/morning-report.sh). -->

## How to answer (this is the two-way interface)

Reply **inline, directly under the question**, on a new line starting
with `> ` (a Markdown blockquote). You don't delete anything yourself.
Example:

```
- **2026-07-18 (nightly): Stalemate — reset the floor or die?**
  > reset to the start of the current floor, keep the run alive
```

Contract the commands follow:
- **`/nightly-batch` owns answer-processing.** On its next run it reads
  this file first, treats any `> ` answer as authoritative (same standing
  as `FOCUS.md`), acts on it, folds a standing decision into `FOCUS.md`,
  then removes that question+answer block once acted on (git history and
  the run's report keep the record).
- **`/bug-sweep` only appends** genuine judgment calls; it must NOT act on
  or delete a `> ` answer (that's the nightly's job) — this keeps the fast
  15-minute loop from racing the nightly over the same file.
- Unanswered questions are left untouched and never re-asked/duplicated.
- To dismiss a question without any action, just delete its line by hand.

Question format either tier appends:
`- **YYYY-MM-DD (nightly|bug-sweep): <question>**` + short context, then a
`  > (answer inline here)` placeholder line so the reply slot is obvious.

- **2026-07-20 (nightly-batch): Scaffolded groc-mangr.** From
  `groc-mangr.idea` — "grocery manager, buy groceries, manage my fridge...
  invisible, like smart google keep lists" (with a nod to
  `~/Documents/vkv/inv/scanscript` for the quick-capture instinct, though
  that's part of the unrelated `vkv-inventory` warehouse-inventory
  project, not this one). Built a dependency-free Node HTTP server +
  flat-JSON store + single-page fridge/shopping-list UI at
  `~/Documents/Projects/groc-mangr`. Marking a fridge item low/out
  auto-adds it to shopping; marking shopping bought moves it back to
  fridge. Registered as a Tier 2 scheduler paced participant (local bare
  remote, no fixed cron).
  > (answer inline here)

- **2026-07-20 (nightly-batch): Scaffolded nine-speakers.** From
  `nine-speakers.md` — a 9-node autonomous speaker/Pi/PIR art
  installation where nodes try to build a sense of their own space/
  neighbors/self from audio+motion sensing alone. The note left the
  actual model technically wide open (real audio-timing localization? a
  simpler cellular-automata neighbor-reaction model?). Built a Python
  simulation (`~/Documents/Projects/nine-speakers`) implementing the
  timing-correlation approach as a first concrete guess, with an
  in-process `Bus` that models real inter-node signal delay explicitly.
  FOCUS.md asks a future run to prototype the CA alternative alongside it
  for comparison. Registered as a Tier 2 scheduler paced participant.
  > (answer inline here)

- **2026-07-20 (nightly-batch): Scaffolded sequestria — judgment call on
  whether it should be autonomously iterated at all.** From
  `sequestria.idea` — a seltzer brand whose whole story is that its
  carbonation comes from direct-air-captured CO2. Built a static brand/
  landing-page site (~/Documents/Projects/sequestria) — name, tagline,
  how-it-works, mission, client-side-only waitlist. Registered as a Tier
  2 paced participant like the others, but this is a genuinely different
  kind of project: its real work (naming, positioning, eventually a real
  DAC supplier claim, company formation) is brand/business judgment, not
  code. I fenced its FOCUS.md hard against anything irreversible (no real
  supplier/certification claims, no domain/trademark/company formation,
  no spending money, no contacting waitlist emails) so nightly runs stay
  strictly in safe copy/design/code territory — but you may want this one
  developed by hand instead of autonomously at all. If so, just disable
  it: delete `schedule/sequestria.conf` from the scheduler repo and
  re-run `bin/sync-crontab.sh --apply`.
  > [2026-07-20T14:59 zach, recovered from LATEST.md — see FOCUS.md
  > Backlog note] Keep it registered and autonomous for now. Treat this as
  > a deliberate experiment in how a real-world business idea can evolve
  > out of this software-dev workflow — part of sequestria's own scope
  > should be documenting that process itself: the tensions, and any
  > reusable workflow patterns worth carrying to other business-shaped
  > ideas later.

- **2026-07-20 (nightly-batch): Scaffolded vim_arcade.** From
  `vim_arcade.idea` — a terminal platformer teaching vim keybindings (and
  tmux) by making them the movement mechanic. Built a Python game
  (`~/Documents/Projects/vim-arcade`): curses-free, unit-tested game
  logic (motion parsing, grid, level-gated unlocking) plus a thin curses
  UI, 5 levels (hjkl → 0/$ → gg/G → w/b → counts). tmux interactions named
  in the note aren't built — that's a genuinely separate design fork
  (real tmux session vs. another grid-world metaphor) flagged in the
  project's own FOCUS.md rather than guessed at deep. Registered as a
  Tier 2 scheduler paced participant.
  > (answer inline here)
