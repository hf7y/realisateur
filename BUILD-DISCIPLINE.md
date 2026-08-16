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
    sensor that answers the same question and FLAG disagreement.

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
    half is filed separately against `blockers-freshness-check.sh`.

16. **A correct refusal that nothing retries.** A guard detects a real
    hazard and correctly declines to act. The decline is right, logged,
    and loud. And then nothing ever picks the work back up, so a *safety
    mechanism working exactly as designed* is where the work dies.

    Distinct from its neighbours, which is why it is its own row:
    pattern 8 (warn-then-continue) *proceeds* after warning — here the
    stopping is correct and the stopping is the loss; pattern 13 is a
    **decision** with no dispatch path — here it is finished **work**
    with none; pattern 2 is built-and-unwired — here the work is not
    even parked, it is announced and dropped.

    **The reason it deserves doctrine rather than a lint:** every
    instance so far failed *loud*. It logged, it printed, it was said out
    loud in a summary — and was lost anyway. "It failed loud" is the
    usual remedy in this file and here it is not sufficient, because
    loudness reaches a human at the moment of refusal and the retry is
    needed later, when nobody is looking.

    **Found live, three times, escalating:**

    - 2026-07-27: a dirty-tree merge fallback and a failed-push path both
      declined correctly, logged, and were lost.
    - 2026-07-27: two cross-writes deferred because `check-project-busy`
      said BUSY; filed as `[batch]` rows in scheduler's own
      `.scheduler/FOCUS.md` — the correct move, and the row itself noted
      that realisateur's `.scheduler/FOCUS.md` still had no record of
      `c49c70d`.
    - **2026-07-28, and this is the one that settles it:** a `/cloture`
      pass deferred two writes to realisateur (BUSY, pid 1937642 —
      verified against the session's own pid, not assumed), announced
      both in a closing summary, and filed neither. The session had read
      the `[batch]` convention *in the same file* minutes earlier. The
      loss was corrected only because Zach asked whether deferrals were
      filed anywhere pickup-able. **The prediction was already written
      down, one screen above where the work was lost, and it did not
      prevent the loss.** A pattern that can be read and then immediately
      re-committed by its reader is not adequately guarded by prose.

    **Rule:** *a fallback that declines to act must name what retries it,
    or it is a dead end wearing a safe fallback's clothes.* Concretely, a
    refusal is complete only when it has (a) written the deferred payload
    somewhere a run dispatches from — not a chat summary, not a log line
    — and (b) named the reader that will pick it up. A refusal that
    cannot name its retrier is an unfinished refusal, and should say so
    at the moment it declines.

    **Mechanical guard (the part that makes this row not-prose):**
    `check-project-busy` currently reports BUSY and its job ends there —
    it is a sensor with no effector. Proposed: on BUSY it emits the
    `[batch]` deferral stub itself, into the calling project's FOCUS
    backlog, pre-filled with the target repo and the caller's identity,
    so declining to write *is* the act of filing. Filed with `scheduler`
    2026-07-28 (`13c0b8e`), and the `/cloture` half filed here the same
    day.

17. **The reader that destroys what it read.** A mechanism consumes human
    input as a *side effect of reading it*, before anything has decided
    whether to act. The read succeeds, the caller declines to act, and
    the input is gone — not lost to a crash, but deleted by the component
    whose only job was to report it. Every step exits 0. Nothing fails
    loud, because nothing fails.

    Distinct from its neighbours: pattern 1 (silent failure) is a step
    that *didn't work* and said nothing — here every step worked exactly
    as written; pattern 16 is a refusal with no retrier — here there is
    no refusal at all, just a read; pattern 8 warns then continues — here
    there is nothing to warn about at the moment of loss, because the
    loss looks identical to success.

    **Found live, 2026-07-28 (wtul):** `collect-feedback.sh --consume`
    stripped the `> ` marker off a reply as part of collecting it. wtul
    run 28 (`0baabb6`) collected 28 of Zach's replies, judged them
    "mostly not actionable", and deleted zero question entries. The
    answers survived only as unattributed prose wedged inside still-open
    questions: invisible to every later `--consume` (nothing left to
    collect) and indistinguishable from the question's own body text.
    **A question had been answered and by every mechanical measure never
    had been.** The verdict did not survive re-reading: among the "not
    actionable" replies were a stream URL answering an entry that called
    itself undesigned, three Apps Script URLs followed by "build it", and
    a hardware question already resolved by purchase. Recovered
    (wtul `cbe597d`) *only because the markers survived in git* — the
    `%%TAG` half of the same script has no such luck, since there the
    keyword IS the marker, and a destroyed one leaves a bare sentence
    with nothing identifying it as feedback at all (filed with scheduler
    2026-07-28, `a69ff05`).

    **Why it hides:** the damage is invisible at both ends. The producer
    (a human) sees their reply accepted. The consumer (the next run) sees
    a file with no pending feedback, which is indistinguishable from a
    file whose feedback was handled. Only a git archaeologist comparing
    two revisions can tell the difference — and there is no alarm that
    would send anyone looking.

    **Rule:** *a mechanism may not destroy evidence on behalf of a
    decision it does not make.* Reading and consuming are separate acts
    and must be separately triggered. Where they cannot be — where the
    reader must mark what it read to stay idempotent — it **marks rather
    than deletes**, in a form that stays legible to the human who wrote
    it and inert to the next reader.

    **Mechanical guard (the part that makes this row not-prose):**
    landed the same day, not proposed. `--consume` now rewrites a matched
    reply as `>> reply` under a dated `>> _[consumed ...]_` header
    (scheduler `3170b81`) — still visible, still attributed, still in
    position, simply not collectable twice; `>>` lines are skipped
    outright, so the operation is idempotent. Deleting the entry is the
    caller's job and always was. Negative-tested: pass 2 over a consumed
    file returns nothing, exits 1, and leaves the file byte-identical.
    The complementary hazard — a human's own formatting drift silently
    truncating what the reader can see — is netted by `bin/lint-replies.sh`,
    run automatically when a human quits the editor from the scheduler
    front door (scheduler `6c95fab`).

18. **A safeguard named for its mechanism gets removed by someone
    reasoning about its function.** A control is named after *what it
    reads* rather than *what it protects*. Later, someone reasons about
    the thing being protected, does not recognise the control as
    relevant, and removes or bypasses it — correctly, by the name. The
    name had fewer distinctions than the job, so a true statement about
    the name ("this limits usage, and we have usage headroom") licensed
    a false conclusion about the system ("so this can go").

    Distinct from its neighbours: pattern 3 (layer-not-replace) leaves
    the old mechanism running underneath — here it is deliberately
    removed; pattern 10 (a rename breaks a silent consumer) is about a
    name *changing* — here the name never changed and was wrong from the
    start; pattern 14 is a sensor that cannot report a state — here the
    sensor works perfectly and the *label on it* is what lacks variety.

    **Found live, 2026-07-29 (scheduler, the dexter migration).**
    `usage-gate.sh` was read as a quota guard, because it is called a
    usage gate. Both hosts had stalled — mandark's last dispatch 17h
    earlier, dexter's log showing zero dispatches ever — and the gate was
    holding on `29% used vs burn-line 27% (on-pace)`. With credits
    available, removing the 7-day even-burn hold was a correct reading of
    a quota guard, and it worked: both hosts dispatched within five
    minutes.

    It was not only a quota guard. It was the ecosystem's **metabolic
    rate limiter** — the one thing bounding how fast the whole system
    could consume itself — and it was doing that job well. Zach named the
    defect exactly: *"the usage gate was actually helpful and we missed
    it because it's called usage gate, not slow down metabolism."*

    The cost was ordering. **The throttle came off before the abort
    handle went on**, and the causal chain is short and entirely
    mechanical: gate removed → dexter dispatched immediately and looped
    on `crt` → a busy host skips `PULL` → the freeze, which propagates by
    git pull, **could not reach the host it most needed to reach** →
    dexter had to be stopped by hand-editing its crontab. The abort
    handle existed, was correct, was tested in both directions, and was
    irrelevant, because the window in which it could have been installed
    quietly had already been spent.

    **The rule:** install and *verify arrival of* the replacement control
    before removing the existing one — arrival on every host, not merely
    a commit. A control you have not yet seen refuse something is not
    installed; and one that reaches a host only when that host is idle is
    not a control over a busy host, which is the only case that matters.

    **The tell, generalised:** when a component's name describes its
    *input* (usage, disk, tokens, rate) rather than what breaks in its
    absence, assume the name understates it, and ask what it is the last
    line of defence for before touching it. A control whose real function
    has no name is one nobody can argue for at the moment it is removed.


19. **The operator reaches around the system instead of through it, and
    the bypass is invisible to the system.** A system owns some domain —
    dispatch, deploys, releases. Something needs stopping or changing in
    that domain *right now*. The system has no verb for it, or its verb
    is too slow, so a human reaches past it: edits the crontab the system
    generates, kills the process the system started, moves the file the
    system manages. It works. Nothing fails loud, because the bypass
    genuinely did the job.

    Three costs, none of which appear at the time:
    - **The system's own state is now a lie.** It still believes it is
      dispatching, or that a job is running, because nothing told it
      otherwise. Every consumer of that state inherits the lie.
    - **The missing verb stays missing.** The hand-fix removes the
      pressure that would have built it, so the same emergency finds the
      same gap next time — and the fix is now folklore in one person's
      shell history rather than a mechanism.
    - **If the run was an experiment, the data is contaminated and does
      not say so.** An out-of-band intervention is invisible to
      instrumentation that watches the system's own channels. The
      observer records an uninterrupted run.

    Distinct from its neighbours: pattern 3 (layer-not-replace) adds a
    mechanism alongside an old one — here no mechanism is added at all;
    pattern 6 (cruft on shared hosts) is about what a bypass *leaves
    behind* — this is about what it *fails to record*; pattern 18 is a
    control removed because its name misled — here the control was never
    consulted.

    **Found live, 2026-07-29 (the dexter migration).** The stated purpose
    was Zach's: *"we need to run the play, via scheduler, for science."*
    Stopping dexter was then done entirely outside scheduler — its
    crontab hand-edited, mandark's sweep backstop hand-commented, and
    finally the paced runner and a running job killed by pid. Each step
    worked. None went through scheduler, so:
    - scheduler's `run.log` shows `DISPATCH [0/4] crt` and no
      termination — from its own records the job simply stops existing.
    - The freeze, which IS scheduler's native stop, was engaged and
      **never reached dexter at all**; the actual stop was three hand
      operations it knows nothing about.
    - ecosim is instrumenting this migration. Every control action taken
      tonight is invisible to its sensors, which read rotation files and
      FOCUS entries. Its record of the night will show a migration nobody
      interrupted.
    Zach named it: *"the failure here is that we should have used
    scheduler itself to stop the work."*

    The tell that it had already gone wrong: the in-flight runner
    survived the crontab edit by 52 minutes, because removing a schedule
    never stops what the schedule already started. Reaching around the
    system got a *partial* stop that looked complete — the strongest
    argument for the verb, discovered by not having it.

    **The rule:** when you are operating a system deliberately (and
    always when dogfooding it), control actions go THROUGH it. If it has
    no verb for what you need, **building the verb is the work** — a
    hand-fix is a decision to leave the gap. If you must bypass in an
    emergency, the bypass is not finished until it is recorded where the
    system and its observers will see it.


20. **A census is blind to a class it cannot enumerate, and its number
    does not get quieter.** A check counts its subject by one method —
    `grep` for a string, a glob over a directory, a read of one config.
    Some part of the domain is not representable that way. The count
    still prints, the exit code is still zero, and nothing distinguishes
    *"the domain is empty"* from *"the domain was not enumerable"*.

    This is Ashby's transducer failure applied to instruments rather than
    messages: two different worlds reach the same output, and the decoder
    that would tell them apart does not exist. See the
    `census-blindness` brief in the vault for the sourced argument.

    Four instances on 2026-08-01, none found by review and all found by
    running the tool against a real case:
    - **A symlink names its path in its target, which is not file
      content.** `transplante` and `ecosim.relocation` both counted
      references with `grep` and missed the four symlinks that put
      `scheduler` itself on PATH — the most load-bearing references in
      the set.
    - **Static reading cannot establish a negative capability.**
      `arme check` passed two jobs that spend, because the wrapper
      `exec`s a script that resolves its engine at run time and names
      nothing a reader can follow.
    - **A self-exclusion compared across two representations excludes
      nothing.** `fauche` filtered its own worktree by string match,
      comparing git's absolute output against a relative argument, so
      every repository reported its own worktree as foreign.
    - **A count of the wrong set.** `arme apply` reported five armed
      monitors over one, counting subcommands after two lists were split.

    Distinct from pattern 14 (a sensor reporting a negative it never
    checked for): there the check was never run. Here it ran correctly,
    over a domain smaller than the one it claims. Distinct from pattern 6
    for the same reason — this is not a silent failure, it is a confident
    success about less than you think.

    **The rule:** a census never reports a bare number. It names the
    method it used and the domain it read, so a reader can see what was
    not looked at. This is a discipline that makes the failure *legible
    after the fact* — it does not prevent it, and the brief says so.
    Prevention comes from the second half: **the negative test for a
    census is an instance of the class it cannot see.** Write one.


21. **A guard that fails safe but never clears.** An outage with better
    manners than an outage. Scheduler `fb485e0`: the paced runner's PULL gate
    was a bare `git status --porcelain`, so one *untracked* scratch file
    pinned a dispatcher's deployed code at whatever commit it sat on,
    indefinitely, announced by a `*/5` log line nobody reads. It scored
    perfectly on the only thing it measured — it never once pulled over a
    dirty tree — while the failure it caused was invisible to it. At estate
    scale in hf7y/scheduler#61/#29/#82: a dirty `BLOCKERS.md` blocked
    vim-arcade's clone for seven commits.

    Row 14 is a sensor failing toward OK. This is a guard succeeding toward
    stuck. Row 16 is adjacent and not the same: there a correct refusal is
    unretried; here the condition **cannot clear on its own**, because the
    guard's own inaction preserves it.

    **The test:** can the condition this guard waits on clear without a
    human? If not, it needs a deadline or a voice, not just a refusal.


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
- **Probe, don't quote.** Before repeating a written claim about system
  state (what's installed, enabled, running, reachable), re-derive it from
  the system. Don't store it: a command that
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

### Settled definition: "pushed" (2026-08-01, Zach)

**A host-only branch is a blocker.** A repository is not recoverable
elsewhere while any branch of it exists only on this host — commit-level
recoverability is not sufficient, because a branch is a name someone
chose to keep, and losing the name loses the reason those commits were
separated.

The test is the remote **ref**, never the tracking config:

```sh
git for-each-ref --format='%(refname:short)' refs/heads/ | while read -r b; do
  git rev-parse --verify -q "origin/$b" >/dev/null || echo "$b exists only here"
  [ "$(git rev-list --count "origin/$b..$b")" = 0 ] || echo "$b is ahead"
done
```

`@{u}` is the wrong question: a branch pushed by explicit refspec
(`git push origin b:b`) has no upstream configured and is still safely on
origin. The first attempt at propagating this doctrine used `@{u}` and
over-reported by two — failing in exactly the way pattern 20 describes,
while implementing pattern 20's own remedy.

Enforced in three places, deliberately not one, because each answers it
for a different act: `fauche` (may this repository be removed),
`transplante` (may it be moved), `closeout-lint` (did this session
leave anything stranded). Any new instrument that asks "is this pushed"
uses the block above.

## The baseline (ONE file, read through the `discipline` command)

**The fenced block below is the ONE SOURCE, and it is now the ONLY copy.**
`discipline` prints it. Every project's `CLAUDE.md` carries a single line
pointing at that command, and nothing else.

```
## Build discipline (realisateur baseline — see realisateur/BUILD-DISCIPLINE.md)
Before marking anything done:
- [ ] Fails **loud**? (no exit-0 no-ops; pipefail+SIGPIPE guarded)
- [ ] "Working" backed by a **test name or human-sense witness**, not exit code alone?
- [ ] Config read from **one source**, not retyped per file?
- [ ] Deploy verified against a **git ref**; drift fails loud?
- [ ] **No secret** in a tracked file; tree clean of build debris?
- [ ] **Shared-host footprint declared** (script/autostart/systemd unit on
      `dexter`/`mandark`/etc named in this project's own FOCUS.md), and
      retired entries actually removed, not left live?
- [ ] Claims about system state **re-probed, not quoted**? (Do not write the
      probe down in the file. The `# VERIFIED:` stamp was retired 2026-08-15,
      #321: 30 hand-maintained dates asserting freshness that nothing re-ran,
      which is a staleness generator wearing the costume of a guarantee.)
- [ ] Verified **where the consumer reads it** (pushed to the ref the job
      clones — not just committed locally)?
- [ ] Multi-line or shell-quoting commit message written with
      **`git commit -F <file>`**, not `-m` (backticks inside double
      quotes execute)?
- [ ] `silence-audit --strict` clean, ON THE PROJECTS THIS CHANGE TOUCHES?
      (mechanizes the retired stderr-silencing / wired-to-a-real-path rows.
      Scoped 2026-08-07: it had demanded a clean estate-wide run since the day
      it was written and that has never once been passable -- 74 FLAGs on the
      morning it was scoped, 52 of them one retired check's false alarms. A
      mandatory row nobody can satisfy is how a checklist stops being read.)
- [ ] Pull request opened per the convention — **`claim-drift --convention`**
      is the canonical text. Reference it; do NOT paraphrase it into a brief.
      In short: a **draft** claims nothing; marking it **ready** is the
      completion claim. A ready PR with **no decision** goes on
      `gh pr merge --auto --squash` and lands unattended; a ready PR that needs
      a call carries `DECISION: <the call>` as its **first non-empty line** and
      auto-merge stays off. (Added 2026-08-08. This convention was previously
      retyped from memory into eight agent briefs in one evening, and a second
      conflicting meaning was invented an hour later — retyping was the
      distribution mechanism, and that is the defect. `claim-drift` now
      enforces the same text it prints.)
- [ ] **Before writing `DECISION:`, ask the cheaper question first: did the
      human already explicitly ask for this exact change earlier in THIS
      conversation, and is there verified evidence (tests, a live dogfooded
      run) that it does what was asked?** If yes, there is no decision —
      write nothing, or `NO-DECISION:` if auto-merge is unavailable. This is
      not mechanically checkable: `claim-drift`'s `OVERCAUTIOUS` check
      only catches ONE narrow shape (a diff touching no existing file's
      behavior) and cannot see the conversation at all — proven live on
      2026-08-10 when realisateur#124, implementing that very check, carried
      an unwarranted `DECISION:` line that the check itself could not flag
      (its diff genuinely touches an existing file) and STILL got a second,
      identical `DECISION:` on the very next commit fixing the first one.
      There is no diff-shape or wording heuristic that reliably tells a
      legitimate `DECISION:` from an illegitimate one — a real, correctly-
      approved decision in this repo's own test suite
      (`"DECISION: adopt the ratchet as a build-blocking floor?"`) is worded
      in the identical closed-yes/no shape as the illegitimate #124 case.
      The check is real and worth keeping for what it does catch; it is not
      a substitute for this.

## Ecosystem protocols (realisateur baseline)
The checklist above governs work inside this repo. These govern anything
that reaches OUTSIDE it. Each is a command on `PATH` — installed by
realisateur, or, where the command is another project's own front door,
by senechal's `installe` from the ecosystem verb build — not a rule to
remember, because prose decays and guards don't. If a command is missing,
say so loudly rather than doing the step by hand: a missing guard is a
finding, not an inconvenience.

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

- **Asking for research** — `bibliothecaire` answers research requests,
  and its front door is a command, not a cross-write. Run:
  `consulte --claim '<the claim to substantiate>' --falsifier '<what would falsify it>' --from <this project>`
  It files a GitHub issue on `hf7y/bibliothecaire` labelled `request` —
  the queue bibliothecaire's own run already works — so it needs **no
  clone of that repo and no push access to any branch of it**, and works
  from any account on any host with `gh`, including the read-only
  deploy-key ones. `--falsifier` is required: a request that names
  nothing that would settle it against you is asking for agreement, not
  research. Then `consulte list --from <this project>` for what you have
  asked, `consulte show <n>` for the answer when it lands.
  **Filing is free; answering is metered** — bibliothecaire spends the
  model call and the literature search, not you — so ask once and read
  the queue before asking again.
  This retires the hand-carry, which had already failed once: on
  2026-08-04 ecosim's request for a literature read on two hypotheses sat
  staged and uncommitted on a clone for two days, because the account
  that wanted to ask held no credential for bibliothecaire and there was
  no door that did not need one.
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
