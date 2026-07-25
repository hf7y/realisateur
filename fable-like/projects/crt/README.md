# crt — voice console + Book Game

Voice-driven Claude Code console: landline handset + CRT display + Debian VM,
hardware-pinned to **dexter**. The build-discipline source case — its 186-commit
first-four-days retrospective produced BUILD-DISCIPLINE.md itself.

## Fable notes

- **Single-dispatcher asserted mechanically.** crt is dexter's alone
  (`_paced.dexter.conf` enabled, mandark's `_paced.conf` disabled) — yet
  mandark's paced-runner log shows crt dispatches at 2026-07-24 23:58/23:59.
  Either the log predates the flip or you have double-dispatch. In the fable
  version the runner refuses to dispatch a project enabled in another host's
  rotation file, and says so. A rule two config files merely imply is a
  reminder; a runner that checks is a guard.
- The dexter cruft this project shed (unattributable scripts/autostarts) is what
  created the senechal footprint rule — its footprint is now declared in both
  FOCUS files.
