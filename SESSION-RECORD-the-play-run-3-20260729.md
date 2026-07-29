# Session record — THE PLAY, run 3 — 2026-07-29

**Why this file exists instead of a `.scheduler/FOCUS.md` entry.**
`closeout-lint` check B wants a dated FOCUS.md entry citing a sha, and it
FLAGged its absence at close. That FLAG is correct as a signal and wrong as an
instruction here: run 3's premise is that a stripped FOCUS.md brief is enough
to direct an agent, the stamp in that file says in as many words *"Do not
append session history here — that is how the last one reached four thousand
lines and stopped directing anybody"*, and
`bin/make-bootstrap-branch.sh --verify` asserts the file is byte-identical to
its generated form. Appending a session record would have broken all three.

So the record lives here, dated and sha-bearing, and the FLAG is named at close
rather than silently left. **This is itself a finding: run 3 stripped both
FOCUS.md files, which are the ecosystem's normal filing destinations, so
`scheduler -i` and check B both now conflict with the play.** During a
bootstrap the intact channels are realisateur's `.idea` inbox and scheduler's
`BLOCKERS.md`.

---

## What was done

Zach's direction: empty cron, release the freeze, install scheduler, hand-run
it once; realisateur dispatched one-and-done; pre-written bootstrap prose on a
branch, recreatable by a non-AI script; negative feedback distinguishing
not-done from gave-up; milestone is the merge back to main.

### Negative feedback — the core ask (scheduler `3b8e481`)

`bin/verdict.sh`: an agent reports `CONTINUE` / `DONE` / `IMPOSSIBLE`. The
load-bearing rule is an asymmetry — **absence of a verdict is NEVER "gave
up."** Truncated, killed, crashed and silent all classify NOT-DONE and
re-dispatch with metabolism untouched. Only an explicit `IMPOSSIBLE`, refused
without a stated reason, brakes — and it brakes through the *existing*
dead-man switch (`expires_at`) rather than a second parallel mechanism, then
files itself to realisateur's inbox.

The motivating evidence, from dexter's own run.log that day: `rc=1` at 12:41,
`rc=0` at 13:05, `rc=1` at 14:08 — `rc` conflated "hit max-turns with work
left", "concluded it cannot be done", and "the wrapper broke".

Two bugs caught while building, both now witness cases: keying verdicts on the
wrapper basename would have made `scheduler-run realisateur batch` and
`scheduler-run crt batch` write *each other's* verdicts; and a verdict not
consumed at dispatch would let one `IMPOSSIBLE` brake a participant
permanently on every later silent run.

**The asymmetry earned its keep the same day.** Six failures on 2026-07-29,
every one `rc=1`, and not one a reason to back off — three max-turns, two
API 529s, one partial. Any brake keyed on failure count would have shut
scheduler down five times while it was making real progress.

### Reproducible starting line (realisateur `68380f0`)

`bin/make-bootstrap-branch.sh` holds the bootstrap prose as data and rebuilds
the branch from any repo state. No AI, deterministic, idempotent, refuses a
dirty tree, commits with `-F`. `--verify` answers "are we at the starting
line?" without writing. `STAMP_DATE` added to `stamp-agent.sh` so it is a pure
function of its arguments — without it the stamp date drifts daily and the
reproducibility claim is untestable.

### The cutover (scheduler `fdea07a`, realisateur `12feb1b`)

Both crontabs emptied, every participant parked on both hosts, `schedule/FREEZE`
removed, RUN-MARKER → run 3. **Crontabs emptied FIRST**, so there was never a
window where releasing the freeze could dispatch the eight enabled mandark
participants. Parked, not deleted — deletion re-arms fixed-cron via
`paced_membership_set`, the trap that fired on `scheduler.conf` earlier the
same day.

### Two defects the play surfaced

**Host-scoped tick meta (scheduler `ea25677`).** The rotation had been per-host
since 2026-07-24 but the tick that drives it was read from one shared file, so
`--apply` on dexter would have installed mandark's `*/5 MAX_PER_TICK=16` over
dexter's deliberate `*/30 MAX_PER_TICK=1` — a 6x rate increase on a host
sharing one account budget — plus a `*/15` sweep tick dexter never ran. That
gap is *why* dexter's crontab was hand-written on 2026-07-24 and never
regenerated: a config surface a host cannot express is one that host routes
around. The bar I wrote was unmeetable, not the agent insufficient.

**No transcript on a max-turns failure (scheduler `e37ef8c`).** A cycle that
hit the ceiling left exactly one line of evidence anywhere. Not a missing
redirect — the body is already wrapped in `{ … } >> "$LOG" 2>&1` — but
`claude -p` with default text output prints only the *final* result, so on the
max-turns path it prints nothing, and intermediate tool calls are never emitted
in any format. Now a per-cycle `stream-json` transcript with a tool-name
histogram in the summary line.

## The measurement that settled ceiling-vs-bar

Transcript `20260729T162058.jsonl`, 380 events:

    60 Bash    12 Edit    4 Read    1 Write     (--max-turns = 60)

Varied, disciplined work — `bash -n`, shellcheck, the full witness suite,
`git stash` to diff previews before/after, six lint scripts, a new
`tests/symlink-farm-witness.sh`, a commit message staged in `/tmp/cmsg`. **Not
thrashing: careful work that ran out of room.**

The cause is structural. The brief's own standing constraints — re-probe rather
than quote, a witness rather than an exit code, fail loud — make every action
cost several Bash turns. The discipline is turn-expensive by design, so 60
turns buys almost no action after verification. This is evidence for raising
the ceiling, and it reverses the earlier "narrow the turn, don't raise
`--max-turns`" call *on measurement rather than on preference* — the turn was
narrowed (one call: register realisateur) and it still was not enough.

## Honest accounting

- **The bar was never met.** No tick installed, realisateur never registered,
  no verdict ever written by the agent. Five hand-fires, one commit produced
  (`6f040ac`, merged as `0960419`).
- **The verdict is advisory and went unused.** The agent never wrote one
  despite its brief asking. That is survivable *only* because of the
  asymmetry; the inverse default would have braked scheduler on turn one.
  `NO-VERDICT` is now logged distinctly so silence stops reading as CONTINUE.
- **I fired by hand five times.** The design called for ONE act of god. Each
  retry was another. That drift is mine and is the main process failure here.
- **A 529 is a third category** the design does not name — not not-done (no
  work attempted), not gave-up (nothing concluded). It lands in NOT-DONE, which
  is the correct *action*, so control flow is right; only the log conflates it.
- **The same-day branch-reuse bug was worked around three times, never
  fixed.** See the `.idea` drop filed this session.
