# CLAUDE.md

## Push permission (2026-07-22, human-directed)

Claude may push committed changes directly to `origin/main` without
asking each time, for ordinary work in this repo. Flag every such push in
the next report/summary (what was pushed, why, and how to revert it —
`git revert <sha>`). This does not license skipping review of what goes
into a commit in the first place, only the push step itself.



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

## Build discipline (realisateur baseline — see realisateur/BUILD-DISCIPLINE.md)
Before marking anything done:
- [ ] Fails **loud**? (no exit-0 no-ops; pipefail+SIGPIPE guarded)
- [ ] **Wired to a real path** (boot/timer/enabled-flag), not just built?
- [ ] "Working" backed by a **test name or human-sense witness**, not exit code alone?
- [ ] New mechanism **names what it retires**?
- [ ] Config read from **one source**, not retyped per file?
- [ ] Deploy verified against a **git ref**; drift fails loud?
- [ ] **No secret** in a tracked file; tree clean of build debris?
- [ ] Claims about system state **re-probed, not quoted** — and if written
      down, stamped `# verified <date> via <command>`?
- [ ] Verified **where the consumer reads it** (pushed to the ref the job
      clones — not just committed locally)?
- [ ] No privileged probe **silencing stderr** (`2>/dev/null` turns
      "denied" into "clean")?
