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

*(No open questions right now — the four groc-mangr/nine-speakers/
sequestria/vim-arcade entries answered 2026-07-20 were folded into each
project's own `.claude/FOCUS.md` and removed here on 2026-07-22.)*

- **2026-07-22 (nightly-batch): bare-remote permission mismatch hit on TWO scheduler-registered projects (nine-speakers, crt). RESOLVED same day.** Root cause: both were the only two bare remotes with group `vaporwave-reports`+setgid instead of plain `zach:zach` (every other repo, including six scaffolded this same session, is plain). Zach ran `sudo chown -R zach:zach` on both; pushes confirmed working immediately after (nine-speakers' 3 stranded local commits and crt's 1 pushed clean).
  > resolved — chowned both repos back to zach:zach

- **2026-07-22 (nightly-batch, via ideate-style ad-hoc pass): first incubation audit — weight applied, flagging for review.** Ran `bin/incubation-audit.sh` (new, offline/no-AI) across all 6 realisateur-scaffolded projects. Honest finding: the whole ecosystem is only 0-2 days old, so no project has real history to judge a genuine "graduated" call on yet — nothing here is a true migration-back case. What the signals DO support: **gardien, senechal, sequestria, vim-arcade** each have an identified, unresolved design fork or explicit non-standard status already flagged in their own FOCUS.md/QUESTIONS.md (git-history-on-RAID, keeper-of-names/places, the sequestria business-experiment framing, tmux/git-etiquette arcs) — set to `weight=1` (stay under closer incubator-style watch). **groc-mangr, nine-speakers** show clean build momentum with no identified blocking fork — set to `weight=2` (graduation CANDIDATES, not declared graduated). Applied via `incubation-decisions-2026-07-22.conf` — revert by editing `schedule/_paced.conf` directly if any single call looks wrong; the audit is fully reproducible (`bin/incubation-audit.sh`, dry-run by default) so re-running it later costs nothing.
  > **Resolved 2026-07-23 (`/ideate` reform pass).** Reframed weighting around "near a stable core" (higher) vs. "bigger still-forming dream" (lower) instead of the incubating/graduation-candidate axis. Only change: **nine-speakers 2→1** (physical rig is a forming dream, not near-stable). **groc-mangr stays 2** (conventional app, no forming-dream flag; re-confirm next audit). The four incubating projects (gardien/senechal/sequestria/vim-arcade) stay at 1 — consistent under the new framing (each has an open fork or forming dream). Standing decision folded into FOCUS.md's 2026-07-23 entry; nightly-batch may remove this block.

- **2026-07-24 (realisateur): crt has a dirty working tree + likely build debris — blocked from safe realisateur engagement until cleaned.** crt's tree carries uncommitted self-repair scripts + systemd units and a `potato_large.txt` that looks like tracked build debris (BUILD-DISCIPLINE #5). Because of the dirty tree it was skipped for the 2026-07-23 build-discipline checklist backfill and can't be safely cross-written (per `STABILITY-MILESTONES.md`'s concurrency rule: a dirty tree is a *stop*, not a thing to edit around). Action: crt's own nightly-batch or a human should commit-or-clean the tree (and gitignore `potato_large.txt` if it's debris); after that, the checklist + a `## Stability milestone` can land there. Flagging, not acting, to respect the stop.
  > (answer inline here)
