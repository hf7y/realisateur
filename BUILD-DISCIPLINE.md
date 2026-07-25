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
7. **A claim outlives its verification.** Someone checks a thing once,
   writes the result as prose, and the prose is then believed long after
   it stopped being true — by people *and* by later audits that quote it.
   Found live 2026-07-25: one unverified sentence ("confirmed 2026-07-24:
   no crontab exists there") propagated into two `_paced.conf` lines,
   DESIGN-NOTES, and became a whole ecosystem audit's #1 ranked finding
   ("silently orphaned, zero dispatch for four days"). Both projects had
   been dispatching nightly the entire time; one `crontab -l` — which
   nobody was ever blocked from running — would have overturned it. The
   tell: *"I looked and saw nothing"* was never distinguished from *"I
   did not look."*
8. **Warn-then-continue.** A check detects the bad condition, prints it,
   and proceeds anyway — so the signal exists but only in a log nobody
   reads at 3am. Distinct from silent failure: the code *knew*. Live
   examples the same day: a freshness check that says "N commits behind —
   committing anyway" and then fails its push; `checkout`/`reset --hard`
   failing unchecked while the run continues on an unknown base; a failed
   push reported as prose while the job exits 0.
9. **The actor grades its own homework.** A run's summary claims success
   ("everything committed, pushed, and in sync") while the machine-checkable
   truth says otherwise. Whoever performs the work must not be the source
   of truth for whether it worked.
10. **A rename breaks a silent consumer.** Moving a file updates the thing
    that moved it, not the unrelated tool that hardcoded the old path.
    Both consumers of chezz's `.claude/`→`.scheduler/` move broke this way
    (a pre-commit fast path, an injection script), each degrading quietly
    rather than erroring.
11. **Writer and reader disagree about location.** Work is saved somewhere
    the consumer never looks: committed but unpushed when the consumer
    clones from origin; on `main` when the job reads `master`; on a
    feature branch when dispatch reads `main`. Everything "succeeds" and
    nothing arrives.

12. **Prose that gets evaluated instead of stored.** Text meant as a
    *record* is handed to something that interprets it, and part of it
    runs. Found live 2026-07-25: a commit message written inline as
    `git commit -m "... \`set -uo pipefail\` ..."` — backticks inside
    double quotes are command substitution, so the shell executed the
    snippet the message was quoting. The near misses hid it: quoting shell
    fragments in `-m` messages had been habitual all session and stayed
    harmless only because no earlier fragment happened to be a runnable
    command. The general shape: the safety of a text-through-an-evaluator
    path depends on the *content* of the text, so it tests clean until the
    day the content changes.

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

- **Probe, don't quote.** Before repeating a written claim about system
  state (what's installed, enabled, running, reachable), re-derive it from
  the system. Where the claim must be written down, it carries the date
  and the command that produced it — `# verified 2026-07-25 via
  sudo -u svc-vaporwave crontab -l` — so the next reader can re-run it
  instead of trusting it. Better still, don't store it: a command that
  *derives* current state (`scheduler dispatchers`) can't rot the way a
  comment describing it can.
- **Never `2>/dev/null` a privileged probe.** Discarding stderr turns
  "permission denied" into "clean result" — the check reports all-clear
  precisely when it failed to look. Found this way 2026-07-25: a
  `sudo -n find` that needed a password printed a confident "0
  world-writable" for a tree that had 2,637. If a probe can fail for
  access reasons, its failure must be distinguishable from its negative.
- **Verify at the consumer's location, not the producer's.** "Done" means
  the thing that reads it can see it. For anything a scheduled job
  consumes, the closing check runs against the exact ref that job reads:
  `git show origin/<branch>:<path>`. A commit in a working copy the
  consumer never clones is not delivered work.
- **The runner writes the verdict, not the actor.** The harness that
  invoked the work decides whether it succeeded, from machine-checkable
  state (remote sha, exit status, file present) — never from the actor's
  own summary. A run claiming "pushed" while the remote disagrees is a
  failed run, and must exit non-zero so the layer above records it.
- **Commit messages go through a file, never through the shell.** Any
  message beyond a single plain line — anything multi-paragraph, and
  anything quoting shell, code, backticks, `$`, `!`, or newlines — is
  written to a file and committed with `git commit -F <file>` (or
  `-F -` from a heredoc). `-F` takes the bytes literally; there is no
  shell in the path at all. Reserve `-m` for short messages containing
  no shell metacharacters. Same rule for any other command being handed
  prose to *store* (`gh pr create --body-file`, `gh issue create -F`):
  if the text is a record, pass it as a file, because a quoting path
  that is safe today is only safe until the text changes.
- **Subagents work on branches.** An agent doing unattended work commits
  to a branch, never pushes to `main`, and reports every file it touched.
  A dirty tree at exit is a failed run, not a handoff — an uncommitted
  change to a live script is indistinguishable from an abandoned one, and
  the next autocommit may adopt it under someone else's name.

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
- [ ] Claims about system state **re-probed, not quoted** — and if written
      down, stamped `# verified <date> via <command>`?
- [ ] Verified **where the consumer reads it** (pushed to the ref the job
      clones — not just committed locally)?
- [ ] No privileged probe **silencing stderr** (`2>/dev/null` turns
      "denied" into "clean")?
- [ ] Multi-line or shell-quoting commit message written with
      **`git commit -F <file>`**, not `-m` (backticks inside double
      quotes execute)?
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
