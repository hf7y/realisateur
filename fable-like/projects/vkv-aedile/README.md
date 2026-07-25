# aedile — email operations for the Virtual Krewe of Vaporwave

AI email-ops role co-directed with Tyler, inside the shared
`media-arts-collective/wavebucks` monorepo. Roman-named, correctly (collective
work). Review-gated, worktree-based nightly wrapper, low autonomy tier — all
appropriate for a real nonprofit's real email.

## ⚠️ The placement caveat

This directory is aspirational only. The real aedile lives at
`~/Documents/vkv/wavebucks/aedile` in a repo **co-owned with Tyler** — you
cannot move it unilaterally, and per your own memory note, no buy-in is needed
for your subtree *changes* but a *relocation* of the monorepo is a conversation.
Until then, a symlink from `projects/vkv-aedile` to the real path gives you the
single-root view without moving anything.

## Fable notes — this is the ecosystem's loudest failure

- **Silently orphaned since 2026-07-20.** Disabled for a svc-vaporwave crontab
  migration that never completed; zero dispatch for days, discovered only
  2026-07-24. The liveness guard (see scheduler/bin/liveness-audit.sh) exists
  because of this row.
- Two known one-line fixes flagged but NOT applied: `SCHEDULER_SUBDIR=".scheduler"`
  missing from `schedule/aedile.conf` (milestone-audit misreports "no focus"
  every pass against a real 21 KB FOCUS.md), and scheduler's `questions/aedile.md`
  symlink pointing at the wrong file. A flagged-not-applied one-liner is the
  cheapest debt you own — apply on sight.
- The svc-vaporwave crontab install is human-only by policy (correct), but it's
  been a 15-minute task pending for 5 days — which is why desk/BLOCKERS.md puts
  it at the top of `blocking` with its age in bold.
