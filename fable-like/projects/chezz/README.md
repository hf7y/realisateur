# chezz — chess project

The elder: origin of `/ideate`, the vision-debt phrase, and the bug-sweep tier.
Live web tracker; real GitHub remote via deploy key.

## Fable notes

- Migrated `.claude/` → `.scheduler/` — this is what unblocks unattended
  QUESTIONS.md writes (the sensitive-file gate was the whole problem).
- Off the legacy `chezz-nightly-batch-loop.sh` wrapper, onto `scheduler-run`.
- Its staleness check silently no-op'd during the 2026-07-25 mega-burn — here it
  exits nonzero with a reason. No exit-0 no-ops, per the checklist it helped create.
- **It has a milestone now.** The oldest project having none means its nightly
  runs have no bar to build toward — weight 1 with no direction is drift, not pace.
