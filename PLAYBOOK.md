# PLAYBOOK.md — where code effort goes

*(2026-07-26, human-directed strategy audit. Sibling doctrine to
`UNIVERSE.md` (the organism's laws), `STABILITY-MILESTONES.md` (one
project's bar), and `BUILD-DISCIPLINE.md` (one build's hygiene). This
file governs **allocation**: what to build, what to import, what to
retire, and where the highest-leverage code lives. Grounded in a
three-agent read-only audit of all 17 registered projects — duplication
vs. native/off-the-shelf tooling, meta-vs-making ratio, and per-project
milestone state. The numbers are that day's snapshot and will decay;
the plays are meant to outlive them.)*

## The stance (inherited from UNIVERSE.md)

Zach is the rate-limiting enzyme — the scarcest organ. Every play below
is judged by one question: **does it return human attention to
making?** Law 3 (retirement pressure) is the audit's through-line —
surfaces only ratchet up unless catabolism is a first-class pathway.
And this file's own doctrine applies to itself: prose decays,
enforcement doesn't, so every play names its mechanism.

## Play 1 — Guards, not reminders: mechanize BUILD-DISCIPLINE as hooks

The audit's largest single finding: **the entire build discipline is
prose, and zero Claude Code hooks exist anywhere in the ecosystem**
(no `hooks` key in any settings file; the only real hook is chezz's git
pre-commit). At least six BUILD-DISCIPLINE rules are literally
hook-shaped, and every incident the document records — backticks in
`git commit -m` executed (2026-07-25), a subagent pushing `main`, a
subagent exiting with a dirty tree — is a case of an agent reading the
prose and not following it. Hooks are deterministic local shell: zero
API cost, offline, fails loud. They ARE the offline-first doctrine.

- `git commit -m` with evaluating metacharacters → PreToolUse deny
  (already queued 2026-07-25, narrow form — build it first).
- Subagent may-not-push-main → `permissions.deny` in a real agent
  definition, not a CLAUDE.md section titled "Subagent rules."
- Dirty tree at exit → Stop/SubagentStop hook running
  `git status --porcelain`.
- Secrets in staged files → gitleaks via PreToolUse.
- `2>/dev/null` on privileged probes → PreToolUse warn.

**Mechanism:** user-level `settings.json` hooks; the queued commit-
message guard is the proving case. BUILD-DISCIPLINE.md stays as the
rationale record for the rules that are genuinely prose (re-probe
claims, name-what-you-retire).

## Play 2 — Import the commodity layer; never churn the original three

Stop maintaining what a maintained tool already does:

- `scheduler pacing deploy` + `deployable_scripts()` + DRIFT reporting
  → **symlinks**. `~/.local/bin/scheduler` is already a symlink; its
  siblings are copies, and `usage-paced-runner.sh` — the file cron runs
  every 5 minutes — was found drifted live. ~80 lines and one CLI verb
  retire; the drift class disappears.
- `bin/token-usage.sh` (262 lines of JSONL parsing) → **ccusage**.
  Keep only the ~35-line conf→session-dir mapping, which is genuinely
  custom; pipe it into `ccusage --json`.
- `hygiene-lint.sh` secret/binary/shebang checks → **gitleaks** +
  standard pre-commit-hook engines, kept INSIDE the existing
  cross-repo, exit-0, signals-not-verdicts harness (that harness is
  right for unattended agents; blocking pre-commit is not).
- `gardien.py` storage layer (self-described "rsnapshot-style") →
  **restic or rsnapshot** when it unparks. Keep the mount-guard, the
  config, the systemd timer. Whatever happens: its milestone gains a
  restore drill — an untested self-built backup is failure pattern #1
  waiting to happen.

Never churn (audited as genuinely original and correct):

1. **`usage-gate.sh` / `usage-paced-runner.sh`** — nothing native or
   OSS returns a headless RUN/HOLD verdict against the live
   account-wide rate-limit windows. Native scheduled agents would
   *consume* the quota this gate protects.
2. **The `%%TAG` / `> ` reply convention + `collect-feedback.sh`** —
   Claude Code has no async human-reply channel into headless runs.
   Original and load-bearing.
3. **The offline-first survey pattern** (`docs/offline-first-checks.md`
   and the deterministic auditors) — measured justification: before the
   sweep precheck, ~99% of one day's chezz model-time was spent
   discovering "nothing to do."

## Play 3 — Catabolize the already-labeled dead weight (Law 3's first cheap win)

Roughly 1,000 lines of live surface are already labeled superseded *in
their own headers* and cost attention every time they're read around:
`morning-report.sh` + `morning-report.md`, `build-services-view.sh` +
`services/`, `incubation-audit.sh` (this repo's own), both
`overnight-dev.sh` copies, the two 162-line loop-script forks
(`scheduler-`/`aedile-nightly-batch-loop.sh` — migrate to the 5-line
shim shape), and `sync-crontab.sh`'s auto-stagger subsystem (dead since
pacing suppressed fixed batch lines). **Mechanism:** this list is the
queued catabolic pass's first worklist — one retirement per pass,
each commit naming what retires it.

## Play 4 — Point the engine at making (the forward ratio is the real one)

Backward-looking, the split is defensible: last 14 days ran ~43% meta /
57% making by commits (~37% meta after discounting journaling). But the
**forward** allocation — `_paced.conf` turns — ran 64% meta while six
making projects sat at `enabled=0`, four of them parked for the literal
reason "no stability milestone declared." The milestone-declaration
jobs queued 2026-07-26 (groc-mangr, nine-speakers, sequestria,
vim-arcade) are those projects' re-admission gates: as each declares,
re-enable it at weight 1–2. scheduler and realisateur weights fall per
the exit conditions already written into `_paced.conf`. **Mechanism:**
`milestone-audit.sh` flipping MISSING→DECLARED is the re-admission
signal; `weight-audit.sh` handles magnitude from there. No new code.

## Play 5 — Spend code on the human bottleneck, not on more engine

The highest-leverage builds available, in order (from the audit's
evidence, not vibes):

1. **A live-verification path to potato (crt).** The ecosystem's
   largest compute spend (307 commits/14d, top weight) produces code
   that structurally cannot close its milestone — all four open
   checkboxes are "code done, needs live confirm on unreachable
   hardware." Anything that lets a run assert against the real device
   converts that spend from unverifiable to closing.
2. **One ranked answer-session surface across all `questions/*.md`,**
   ordered by how much queued work each answer releases, plus a
   standing-policy vocabulary so a yes is durable rather than
   per-question. Multiple projects are 100% blocked on single answers;
   chezz's four forks gate ~10 tracker items; BLOCKERS.md's own header
   admits nothing prunes resolved entries. This is the only play that
   acts directly on the rate-limiting enzyme.
3. **aedile's auto-merge gate** — explicitly a bottleneck-removal
   milestone (nightly auto-merge on a clean scenario run instead of
   always waiting on a human), 2/5 criteria already done, remainder
   unattended-buildable, sequencing already decided in-file.
4. **A shared Apps Script library** for chezz / aedile / vkv-inventory
   (sweep-status endpoint, triage policy, local scenario harness) —
   three confirmed consumers currently told to hand-copy each other's
   code, a sync step already known to lag.
5. **A `SessionStart` hook wrapping `collect-feedback.sh`** so
   interactive sessions see the same pending feedback nightly runs do —
   same script, zero new mechanism, closes a documented near-miss.

## Play 6 — The admission test for new meta-tooling

Before building any new tool-to-make-tools (the incubation-audit
precedent, now standing policy): **(a)** does it reuse an existing
validated pattern; **(b)** is its scope bounded and its output
reviewable/reversible; **(c)** does it stop once that's true rather
than elaborating open-endedly; **(d)** does it name what it retires
(Law 3); **(e)** does an import exist that covers it (Play 2)? A
meta-build that fails the test is parked, not built. The reservoir is
not debt; unbuilt meta-tooling is not either.

## Where to dig in

If only three things get real attention next: **crt's verification
path, the answer-session surface, and aedile's auto-merge gate.**
Each one either unblocks the largest making project, widens the
narrowest channel (Zach's attention), or deletes a recurring human
chore — the three shapes of leverage this audit found. Everything else
above is either a config edit, an import, or a retirement — cheap by
construction, and cheaper the sooner it happens.
