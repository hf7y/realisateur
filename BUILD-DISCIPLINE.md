# Build discipline — lessons every scaffolded project inherits

Realisateur's job doesn't end at scaffolding a project; it's to seed
projects that stay *stable* as they iterate themselves unattended. This
file is the distilled, project-agnostic set of build/deploy disciplines
that every new project should carry from day one, and that
`bin/hygiene-lint.sh` checks for mechanically across the whole ecosystem.

It's a generalization of one concrete audit — `crt`'s first 4 days, 186
commits (see `crt/DEV-DISCIPLINE-RETROSPECTIVE-2026-07-23.md`) — but the
patterns are the ones any fast-moving, self-iterating project regenerates.

## The recurring failure patterns (what to design against)

1. **Silent failure.** Code that fails with exit 0 / no output / a
   healthy-looking status — a dead device, a truncated sync, a
   `pipefail`+SIGPIPE pipeline, a POST to a host that no longer exists.
   Found by archaeology (a surviving log, an import crash), not by alarm.
   *The #1 cost multiplier — it turns a 5-minute bug into a multi-day one.*
2. **Build-but-don't-wire.** A component finished and tested, then left
   disconnected from the path that runs it (boot script, timer, enabled
   flag). A reboot or fresh session runs the *old* path as if the work
   never happened. Its earliest form: finished work left **uncommitted**.
3. **Layer-not-replace.** A new mechanism stacked on an old one it was
   meant to supersede, retiring nothing — complexity and config sprawl
   grow while nothing gets simpler.
4. **Hand-copy deploy loses work.** Deploy targets that aren't git clones
   drift silently; work exists on one machine and nowhere else until an
   accident reveals it.
5. **Secrets in the open.** Passwords/keys committed to tracked files
   (permanent, in history) or left loose one `git add -A` away from it;
   build debris (disk images, firmware) tracked as if it were source.
6. **Cruft on shared hosts.** A project drops a script, autostart entry,
   or systemd unit onto a host it doesn't exclusively own (`dexter`,
   `mandark`) during fast dev iteration, then the project moves on or its
   architecture shifts — the leftover is now unattributable: nobody
   scanning that host later can tell which project it came from or
   whether it's still needed (found live, 2026-07-24: `dexter`
   accumulated exactly this from `crt`'s dev work, see its own FOCUS.md's
   parked `dexter-npu-tools` entry and the 2026-07-23 bridge-cleanup
   flags — prose notes, not a mechanism).

## The disciplines (stated as mechanical rules)

The rule of this file: prefer a **mechanical guard** (a test, a lint, a
boot-path line) over a reminder. Reminders decay; guards fail loud.

- **Fail loud by default.** No silent no-op path. Any device open, HTTP
  call, or subprocess whose failure currently means "nothing happens"
  logs a WARN and, where safe, exits non-zero. `pipefail` with a pipeline
  that can legitimately SIGPIPE needs an explicit guard.
- **"Working" needs a witness.** A done/working claim requires a test
  name or a human-sense verification in the same commit — never exit code
  alone.
- **Wire-on-commit.** Nothing is "done" until something runs it on the
  real path. Don't leave finished scripts untracked.
- **Name what you retire.** A new mechanism that overlaps an old one must
  say what it replaces; if it replaces nothing, stop and consolidate.
- **One source of truth for config.** Ports, device indices, hostnames
  defined once and read everywhere; never retyped per file.
- **Deploy is a git operation.** Deploy targets are clones; drift against
  the intended ref should be checkable and fail loud.
- **No secret in a tracked file.** Real secrets live in an untracked
  `.env`/`secrets/`; the `.gitignore` blocks creds and build debris from
  day one.
- **Declare your host footprint — and report it, don't just log it.** Any
  project that installs a script, autostart entry, or systemd unit onto a
  *shared* host (one this project doesn't exclusively own — `dexter`,
  `mandark`, any future shared box) must (1) name it in that project's own
  `FOCUS.md` (what, where, why) so it's attributable later, remove/say-so
  when retired rather than leaving it live and unowned, **and** (2) at the
  same time it lands, cross-write a dated note into senechal's own
  `.claude/FOCUS.md` saying so (tagged `(<project> cross-write, ...)`,
  same discipline realisateur itself already follows per its own
  `feedback_notify_senechal` policy) — check `senechal`'s tree isn't
  mid-run first (`bin/check-project-busy.sh` pattern), keep the write
  small, commit immediately. `senechal` is the ecosystem's registry for
  this (2026-07-24 decision, widened again 2026-07-25 from passive
  reconciliation to active reporting — see its own FOCUS.md/QUESTIONS.md,
  mission widened past mandark-only to own the script/autostart world
  across all of Zach's shared hosts). A project's own `FOCUS.md`
  declaration is still the source of truth senechal reconciles against —
  the cross-write is what makes sure senechal actually *sees* it at
  install time, instead of only catching it later during its own scan (or
  never, on a host it doesn't yet watch).

## The checklist (stamped into every new project's CLAUDE.md)

```
## Build discipline (realisateur baseline — see realisateur/BUILD-DISCIPLINE.md)
Before marking anything done:
- [ ] Fails **loud**? (no exit-0 no-ops; pipefail+SIGPIPE guarded)
- [ ] **Wired to a real path** (boot/timer/enabled-flag), not just built?
- [ ] "Working" backed by a **test name or human-sense witness**, not exit code alone?
- [ ] New mechanism **names what it retires**?
- [ ] Config read from **one source**, not retyped per file?
- [ ] Deploy verified against a **git ref**; drift fails loud?
- [ ] **No secret** in a tracked file; tree clean of build debris?
- [ ] **Shared-host footprint declared** (script/autostart/systemd unit on
      `dexter`/`mandark`/etc named in this project's own FOCUS.md), and
      retired entries actually removed, not left live?
```

`bin/hygiene-lint.sh` mechanically checks the last two rows (secrets,
debris, uncommitted work, missing exec bits, silent-pipeline smells,
config duplication) across every registered project — offline, no AI. Run
it at the top of every nightly-batch pass, same as `ecosystem-survey.sh`.
A mechanical check for the new shared-host-footprint row (cross-
referencing each project's declared footprint against senechal's actual
host journals) is a real follow-on `hygiene-lint.sh` addition, not yet
built — queued, not done, as of this entry. The reconciliation itself
(declared vs. actually-present, on both `mandark` and `dexter`) is
senechal's own build to do proactively, not just react to reports — see
its FOCUS.md 2026-07-25 entry.
