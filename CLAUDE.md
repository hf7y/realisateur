# CLAUDE.md

## `vault:` is an ARCHIVE. Agents do not read it. (Zach, 2026-08-29)

`vault:<project>/<file>` names a path in the private **`hf7y/ecosystem1-vault`**
remote. Recognise the notation; do not follow it. **The vault is where prose goes
when it stops being true** — `consigne` deposits superseded text there
(`basheur`, `retired-verbs-20260818`, `retired-claude-memory-20260829`, 26% of
whose assessed files were FALSE). Reading it back is how a retired fact returns
as documentation: on 2026-08-29 vault prose reached a subagent brief as "the
registry says dexter is a laptop that sleeps" — it says `kind: windows-mini-pc`,
`expect: always-on`. Establish facts from live code, config, or API; if you
cannot, it is UNVERIFIED — say so and act on nothing. Writing (`consigne`) is
unaffected. Deeper vault design: realisateur#762.

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
