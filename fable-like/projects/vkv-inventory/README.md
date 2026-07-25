# vkv-inventory — Krewe inventory app

Apps Script / clasp-deployed inventory app, its own dedicated repo. Same
placement caveat as aedile (vkv subtree; symlink into the single root until a
real move is agreed).

## Fable notes

- **Silently orphaned since 2026-07-20**, same never-completed svc-vaporwave
  migration as aedile. Same fix, same liveness guard.
- Known gap carried from before the orphaning: its nightly-batch never runs
  `collect-feedback.sh --consume` against its own QUESTIONS.md — meaning your
  `> ` answers there go unread by the very run they're meant to steer. That's
  the contract channel broken at one endpoint; a one-line addition to its batch
  prompt/wrapper.
