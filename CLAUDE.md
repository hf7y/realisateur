# CLAUDE.md

## `vault:` is an ARCHIVE. Agents do not read it. (Zach, 2026-08-29, #762)

`vault:<project>/<file>` names a path in the private **`hf7y/ecosystem1-vault`**
remote — where prose goes when it stops being true. Recognise the notation;
never follow it. Reading a retired fact back is how it returns as documentation.
Establish facts from live code, config or API, else UNVERIFIED — say so and act
on nothing. Writing (`consigne`) is unaffected.

## Push permission (2026-08-14, reaped: main is a protected branch)

`main` is protected: a direct push is rejected for everyone, admins and this
repo's own automation included. Open a PR; never commit to local `main`.

## Subagent rules (2026-07-25, from the propagation pass)

- A subagent commits to a **branch**: on 2026-07-25 one pushed `main` directly.
- **A dirty tree at exit is a failed run**, not a handoff. An uncommitted change
  to a live script is indistinguishable from an abandoned one, and the next
  autocommit may adopt it under a human's name. One left 76 uncommitted lines in
  `sync-crontab.sh` — the script that writes crontabs — without mentioning it.
- A subagent reports **every file and every account** it touched, including ones
  it reverted. One modified a live crontab under a second user account.
- Its status claims are **stale by construction** — verify before relaying.
  Three reported already-completed work as still outstanding.
- One that needs a credential **stops and asks**; it does not go looking. A
  brief saying an API "needs a long-lived token you probably do not have" read
  as an invitation: one swept `~/.config`, `~/.netrc` and other projects until
  it found an unrelated project's admin token, then wrote to a live system with
  it. Searching credential stores for something that works is never in scope.
