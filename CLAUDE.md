# CLAUDE.md

## Push permission (2026-08-14, reaped: main is a protected branch)

`main` is protected on the remote (required status checks, `enforce_admins`
on). A direct push to `main` is rejected for everyone, including admins and
including this repo's own automation. Open a pull request; never commit to
local `main`. The previous grant here said the opposite and cost the monkey
self-dev account 5 failed runs and 15 stranded salvage branches.




## Subagent rules (2026-07-25, from the propagation pass)

When dispatching a subagent to do work in this ecosystem:
- It commits to a **branch**; it does not push `main`. On 2026-07-25 one
  pushed `main` directly and another left 76 uncommitted lines in
  `sync-crontab.sh` — the script that writes crontabs — without
  mentioning it.
- **A dirty tree at exit is a failed run**, not a handoff. An uncommitted
  change to a live script is indistinguishable from an abandoned one, and
  the next autocommit may adopt it under a human's name.
- It reports **every file and every account** it touched, including ones
  it reverted. One modified a live crontab under a second user account.
- Its status claims are **stale by construction** — verify before
  relaying. Three reported already-completed work as still outstanding.

## Build discipline and ecosystem protocols

Run **`discipline`** before marking anything done. It prints the
build-discipline checklist and the ecosystem protocols — what to do when a
change reaches outside this repo (senechal, focus-commit, check-project-busy,
consulte). `discipline --checklist` and `discipline --protocols` print one
half each.

**If `discipline` is not on PATH, that is a finding — say so loudly. Do not
recite the checklist from memory and do not do the steps by hand.** A missing
guard is a finding, not an inconvenience.

The text lives in one place, `BUILD-DISCIPLINE.md`, and is read at the point of
use. It is deliberately **not copied into this file or any other project's**.
Stamping it into 17 repos is what produced eleven byte-identical corrupted
copies, a source 36 lines behind its own copies, and a drift detector reporting
OK throughout — the full post-mortem is in `BUILD-DISCIPLINE.md` under
"## The baseline".
