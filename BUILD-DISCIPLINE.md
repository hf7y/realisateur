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
   did not look."* Same pattern, different surface, named 2026-07-27:
   doctrine files describing their own open work in status words
   ("queued", "shape open", "not yet started") decay exactly like a
   system-state comment does — see `UNIVERSE.md` Law 3's own "Queued,
   not built" section, which had gone stale about itself. The existing
   `verified <date>` stamp + `hygiene-lint.sh` check 8 already cover
   this for free (it scans the whole repo, not just `.conf` comments) —
   the gap was never mechanical, only that nobody had stamped a status
   claim before.
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

13. **A decision without a dispatch path.** A real decision gets recorded
    somewhere no executor ever reads, so it's never implemented — and later
    sessions re-derive it from scratch, blind to the original. Found live
    2026-07-26: the 2026-07-24 call to migrate FOCUS/QUESTIONS off the
    gated `.claude/` paths ("same design as every other project,
    long-term") was filed in scheduler's BLOCKERS.md under `## wtul` —
    a file that is by standing rule *not a work queue*, in a section no
    other project's runs read. The wtul migration never executed; the
    "every project" clause reached no template and no backlog; chezz and
    realisateur each rediscovered the wall independently over the next two
    days and realisateur re-queued the already-made decision as an open
    question. This is pattern 2 (build-but-don't-wire) for decisions:
    *recorded* is not *wired*. A decision is wired only when it sits in a
    file some run actually dispatches from (a project FOCUS backlog, a
    template, a queued job) — and if it changes a convention, the
    template/doc that teaches the convention changes in the same commit.

    **13b — the partial-wiring case: wired on the path you were looking
    at.** More dangerous than 13 proper, because it looks done. The
    decision *is* in a file some run dispatches from — just not all of
    them. Found live 2026-07-26, one day after 13 was written, by the
    same session that wrote it: `precipitation-scan.sh` was wired into
    `ecosystem-survey.sh` and documented in `.claude/commands/ideate.md`,
    but not in `nightly-batch.md`. So every *unattended* pass printed
    promotion-signal reports with no doctrine attached — the run with no
    human present to catch a false positive, which the same scan produced
    within the hour. The tell is that the author edits the path they are
    reading and never enumerates the others: a mechanism usually has more
    consumers than the one in hand (interactive vs. unattended, template
    vs. instance, doc vs. dispatcher).

    **Rule:** when wiring a mechanism or recording a convention,
    enumerate *every* executor that reads it and name them in the same
    commit — or state which are deliberately excluded. "I updated the
    docs" is not a list.

    **Mechanical guard:** `hygiene-lint.sh` check 9, `[dispatch-parity]`
    — flags a `bin/*.sh` named by some of a project's `.claude/commands/`
    files but not all. Advisory, since asymmetry is sometimes deliberate.
    (Distinct from the queued BLOCKERS.md task-shaped-language row, which
    is 13 proper: a decision in a file nothing dispatches from at all.)

    **13c — the unasked-scope case: the executor cannot reach what the
    instruction names.** 13b assumes you know the set of executors and
    forgot one. 13c is worse: the set was never enumerated, because the
    thing works perfectly in the one place anyone looked. Found live
    2026-07-27 — `/ideate` and `/cloture` existed only in
    `realisateur/.claude/commands/`, so they were invocable in exactly
    one repo, and six of the nine scripts they instruct a session to run
    had no PATH shim. Both facts were invisible for the same reason: a
    project-scoped command that resolves everything from its own repo
    emits no failure signal at all. `[dispatch-parity]` could not see it,
    because it compares command files *to each other* and every command
    file had the same blind spot. The tell is an instruction file with no
    stated audience: nobody decided these should be repo-local, the
    question was never posed.

    **Rule:** every command/instruction file states its **scope** —
    `scope: project` or `scope: user` in frontmatter — and every command
    a `scope: user` file names must resolve from a neutral cwd, since it
    will be read inside repos with no realisateur checkout and no
    relative `bin/`. Silence is not an answer; a file with no declared
    scope is the defect.

    **Mechanical guard:** `reach-lint.sh` (check A `[scope-undeclared]`,
    check B `[unreachable]`), surfaced as `hygiene-lint.sh` check 11 and
    gated in `install-shims.sh`, which derives BOTH its install list and
    its shim list from `scope:` rather than a typed list — the typed list
    is what produced the gap. Adding `scope: user` to a command file is
    the entire opt-in; nothing else needs editing.

14. **A sensor reports a negative it never checked for.** A probe reads one
    of the places a thing can live and reports "not present" as if it had
    read all of them — so the tool is confidently wrong, and wrong in the
    direction of alarm. This is pattern 7's tell (*"I looked and saw
    nothing" was never distinguished from "I did not look"*) moved from
    prose into a script, where it is worse: prose is quoted by people who
    might doubt it, a script's output is read as measurement.

    Found live 2026-07-27, in realisateur's own surveys, twice:
    `steward-survey.sh` equated *enabled in `schedule/_paced.conf`* with
    *dispatches at all* and so reported 9 of 18 projects DARK — but the
    ecosystem has **three** dispatch surfaces (mandark's `_paced.conf`,
    dexter's `_paced.dexter.conf`, `svc-vaporwave`'s crontab). crt, the
    single most active project in the ecosystem (289 commits/7d, dispatching
    from dexter), was its loudest "dark, high-weight, 32 ideas stranded"
    row. 42 of the 52 reported stranded ideas were artifact. Separately,
    `ecosystem-survey.sh` reported a *subdirectory* of a shared monorepo as
    a clean repo, because `git -C <subdir>` silently walks up to the parent
    — so a co-owned monorepo's health had been printing as one project's.

    Two properties make this the most expensive sensor bug shape:
    - **It fails toward alarm, and alarm is routed to the human.** The
      false row was the tool's self-declared "loudest signal," which
      `/ideate` §1 instructs be raised as an `AskUserQuestion`. It was,
      and it consumed a real decision on a premise that did not exist.
      A survey that spends the scarcest organ's attention on an artifact
      is worse than one that stays quiet.
    - **The most confident output is the likeliest to be wrong.**
      Second instance in two days (`PRECIPITATION.md`'s false cluster was
      the first): plausible, well-framed, agreeing with something already
      in the doctrine. Confirmation-shaped output is the expected failure
      mode of every inference-over-partial-reads tool here.

    **Rule:** a probe may only report a negative over the domain it
    actually read, and must name that domain. "Not enabled in
    `_paced.conf`" is a fact; "DARK" is a claim about every dispatch
    surface and requires reading every one. Where a probe *cannot* read a
    surface (no access, host unreachable), that is a third result —
    `UNKNOWN` — never folded into the negative. Corollary for consumers:
    before a survey row becomes a question to a human or an edit to real
    config, **re-derive it from the system**, and cite the probe rather
    than the survey.

    **Mechanical guard:** none today — `bin/sensor-agree.sh` is queued
    (realisateur `.scheduler/FOCUS.md` 2026-07-27) to cross-check every
    sensor that answers the same question and FLAG disagreement. Until it
    lands, this row is prose, and prose decays; that is stated here rather
    than left implied.

15. **A file's prose about its own structure gets parsed as its structure.**
    A document that explains its own format has to *write the format down*,
    and a parser that matches on a prefix cannot tell the explanation from
    an instance. The document becomes an example of itself, in the one place
    it was trying to be a description of itself.

    Found live 2026-07-27, in `scheduler/BLOCKERS.md`, having stood for two
    days. That file's header explains where resolved entries go, in prose,
    by naming the heading: *"…until a human (or an `/ideate` pass) actually
    moves it down into `` `## Recently resolved` `` or deletes it."* Two
    independent mechanisms then matched that sentence as structure, 24 hours
    apart and without knowing about each other:

    - **The writer.** `ec89b84`, chezz's nightly machine-append, inserted
      its `## chezz` section at the *first* `## ` it found — which was
      inside that sentence. The header was cut mid-clause, and its tail was
      left wearing a heading it never had: a second `## Recently resolved`,
      standing 372 lines ahead of the real one.
    - **The reader.** `blockers-freshness-check.sh` scopes itself to "the
      active section" as *everything before the first `## Recently
      resolved`*. From `ec89b84` onward that was **line 91**. Every
      project's real blockers sat below it, in what the script now
      understood to be already-resolved history.

    **Measured, not inferred** (both runs, same script, only the file
    differs): against the corrupt file it printed
    `== summary: 0/0 active project section(s) flagged ==`; against the
    repaired file, `4/9`. Zero out of zero. Not an error, not an empty
    result — a clean bill of health, in the standard format, from a check
    that had been blinded. **The corruption's first casualty was the only
    script watching for it.**

    That is the property that makes this shape worth its own row rather
    than folding into 14: this is not a probe that read too few surfaces,
    it is a probe whose *surface was redefined underneath it* by a
    conforming edit to the file it watches. Pattern 14 asks a probe to name
    its domain. Here the probe named its domain correctly and the domain
    moved.

    **Rule, three parts:**
    - **A structural marker must be matched by a rule its own
      documentation cannot satisfy.** Anchor both ends (`^## Recently
      resolved$`), not a prefix; never match inside a fenced block or a
      backticked span. If the parser would accept the sentence explaining
      the format, the parser is wrong.
    - **A document must be able to name its own format without becoming an
      instance of it.** If it cannot, the format is wrong — not the prose.
      Fix the matcher, do not ask writers to avoid mentioning the file's
      own headings.
    - **A section-scoped reader that finds zero sections reports `UNKNOWN`,
      never zero findings.** A file known to have sections and suddenly
      having none is a parse failure wearing a passing summary. `0/0` must
      be as loud as a FLAG. (This is 14's rule applied to a reader's *own*
      scoping, which is where 14 did not reach.)

    **Mechanical guard:** filed with `scheduler` 2026-07-27 through the
    front door (`scheduler -i scheduler`) — exact-match headings for
    machine-append, and a watcher that refuses to autocommit a file
    carrying conflict markers or duplicate `## ` headings. The `0/0`
    half is filed separately against `blockers-freshness-check.sh`. Until
    all three land this row is prose, and prose decays; stated here rather
    than left implied.

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

## The baseline (restamped into every project's CLAUDE.md)

**This fenced block is the ONE SOURCE.** `bin/restamp-discipline.sh` reads
it from here and rewrites the delimited region in every registered
project's `CLAUDE.md`. Edit it here and nowhere else — a hand-edit inside
a project's copy is overwritten on the next pass, by design.

Why a copy at all, rather than a symlink or an import (decided
2026-07-26, Zach's question)? Because the nightly jobs run in a
**dedicated clone**, and shared hosts (`dexter`/`mandark`) may not have
realisateur checked out at all. A symlink to an absolute path outside the
repo dangles there — and a dangling symlink doesn't error, it just makes
the discipline silently absent, which is the first failure pattern this
very file names. Plain text travels to any host and shows up in a diff.
The "config read from one source" row is satisfied in substance because
the copy is written mechanically, never by hand.

It carries two things: the **checklist** (how to build inside your own
repo) and the **protocols** (what to do when you touch anything outside
it). The protocols were added 2026-07-26 after Zach asked how other
projects were supposed to learn rules like the senechal cross-write —
the honest answer was that they weren't: those rules lived only in
realisateur's own two command files.

```
<!-- >>> realisateur-baseline: generated by realisateur/bin/restamp-discipline.sh -->
<!-- Edit realisateur/BUILD-DISCIPLINE.md, not this copy -- it is overwritten. -->
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

## Ecosystem protocols (realisateur baseline)
The checklist above governs work inside this repo. These govern anything
that reaches OUTSIDE it. Each is a command on `PATH`, installed by
realisateur — not a rule to remember, because prose decays and guards
don't. If a command is missing, say so loudly rather than doing the step
by hand: a missing guard is a finding, not an inconvenience.

- **Changing machine-wide config** — anything outside this repo that the
  machine as a whole sees: crontab entries, `~/.claude` settings hooks,
  systemd units, autostart, WM config, marker files under
  `~/.local/share`, scripts in `~/.local/bin`. Run:
  `notify-senechal '<what changed, where, who owns it>'`
  Standing rule: the project that generates a piece of machine config
  **owns** it; `senechal` owns **knowing it exists**. The command files
  through senechal's own front door and confirms the note reached its
  remote. Do this without being asked, and without waiting for a
  convenient moment.

- **Committing this project's `FOCUS.md` / `QUESTIONS.md`** — use
  `focus-commit <repo> <msgfile> <file>...`, never a bare
  `git add`/`commit`/`push`. These files have multiple writers (you, the
  human, and a scheduler autocommit watcher on a ~:30 tick), and the bare
  sequence has silently lost and rewritten content four times. It stages
  exactly the named files, resolves a rejected push itself, and verifies
  the rebase did not change what your commit means.

- **Writing into another project's repo** — run
  `check-project-busy <project>` first. If it reports `BUSY`, that
  project's own automation is mid-run against the same files right now:
  **defer the write**, note what was deferred and why, and carry on. Do
  not edit a FOCUS.md out from under a live run.
<!-- <<< realisateur-baseline -->
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
