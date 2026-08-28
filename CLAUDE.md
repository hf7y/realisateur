# CLAUDE.md

## `vault:` in a citation is a remote, not a path

`vault:<project>/<file>` names a path inside the private
**`hf7y/ecosystem1-vault`** remote. It is not on disk here — mandark holds no
clone. Read one with `gh api repos/hf7y/ecosystem1-vault/contents/<path>`.
Defined once in `PROSE-REAPING.md` §2; do not retype the resolution rule.

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
