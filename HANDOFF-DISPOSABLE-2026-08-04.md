# HANDOFF (disposable) — 2026-08-04

**Delete this file once its contents are merged, filed, or superseded.** It is a
session handoff, not a record. The durable record is `.scheduler/FOCUS.md`,
issues #31–#34 / #37, and the commit messages named below.

Written at `/cloture` by the session that put `monkey` on the tailnet, taught
`ecosim` to see arbitrary hosts, and armed `vim-arcade`.

---

## 1. PRs: merge, or why not

> **STATUS 2026-08-04, after Zach's review — three of these are DONE.**
> `scheduler#17` merged (`ae16241`), `ecosim#28` merged (`91716d7`),
> `realisateur#35` merged (`b2d10df`). `/srv/scheduler` re-synced to `ae16241`
> afterwards, and `ecosim` re-verified from merged main: selftest 0 violations
> across 43 symbols, `test_hosts.py` green, 12 readings about monkey with zero
> BLIND.
>
> **What remains from this section: `scheduler#16` + `vim-arcade#7` only.**
> They are still a pair, and the reason to hold them is now stronger, not
> weaker — see the UPDATE below. Sections 2–4 are all still live.

Five open. **Three are ready. Two are paired and must not land alone.**

### `hf7y/scheduler#17` — MERGE (it rescues a stranded write)
*relay-vim-arcade-blockers · 1 commit*

`vim-arcade`'s batch produced `8ef2ecc` in its own scheduler checkout on monkey
and **could not push it**: that account's deploy key for `hf7y/scheduler` is
read-only by design. The checkout sat `[ahead 1]` with nowhere to go. The agent
correctly declined to push it under its own credentials — and that is also
exactly how a write gets silently lost, so this relays it via `git am` from
`format-patch` (original author, date and message preserved).

`BLOCKERS.md` only, +78/−1, and the single deletion is an **answer slot being
consumed**, not a prune — checked specifically, because that file is
machine-appendable but never machine-prunable. Contains a correction (the
"unauthorized commit `5b5783e` was never pushed" premise was stale) and a new
blocker (the sensitive-file gate refused two edits mid-run with no human
present, and the run reported it instead of routing around it).

### `hf7y/ecosim#28` — MERGE
*rotation-sees-monkey · 4 commits*

The session's main body of work. Derives the host set from
`schedule/_paced.*.conf` instead of a hardcoded tuple, splits "who dispatches"
from "how to reach them", and adds `lib/hosts.py` + `test/test_hosts.py`.

Merge because it is verified beyond exit codes: `sonde selftest` passes 0
contract violations across 43 symbols, and `test_hosts.py` is
**mutation-checked** — restoring the old tailnet-first transport order fails
`alias_beats_tailnet` with rc=1, so the test is capable of firing rather than
merely green. It also kills three false-finding classes that were live in
production (below, §3).

Only caveat: it carries `d2831f9`, an unrelated FOCUS.md autocommit that was
stranded unpushed in the shared checkout. Flagged in the PR body. Split it out
if you'd rather, but dropping it strands it again.

### `hf7y/realisateur#35` — MERGE (it is a document)
*nomac-vaporwave-brief-20260804 · 1 commit*

A draft brief proposing svc-vaporwave move onto `nomac` as a second dispatching
host on an institutional credential with its own quota. It changes no
configuration and touches nothing outside one new markdown file, so merging
costs nothing and losing the branch costs the analysis.

Read it before acting on it — it argues against `MONKEY.md` §2's own reasoning
for *not* using nomac, which is the interesting part, and it needs Tyler's
buy-in question answered before any of it is built.

### `hf7y/scheduler#16` + `hf7y/vim-arcade#7` — HOLD, and merge together
*vim-arcade-issues-channel · issues-answer-channel*

These are two halves of one change and **either alone is a silent-divergence
bug**:

- `#16` sets `ANSWER_CHANNEL="issues"` in `schedule/vim-arcade.conf`. The
  scheduler machinery (`answer_channel`, `cmd_ask`, `project_questions_counts`)
  then routes vim-arcade's questions to GitHub issues. `REPO_URL` is present,
  so this half is correct.
- `#7` is the matching change to `hf7y/vim-arcade`'s
  `.claude/commands/nightly-batch.md`, which currently tells the batch to
  read/write `.claude/QUESTIONS.md` — six references, zero mentions of issues.

Land `#16` alone and `scheduler status` counts issues while the batch writes a
file. Land `#7` alone and the reverse. **Neither side errors.**

**Two further reasons to hold `#7` specifically:**

1. It is titled as a one-file change and carries **9 files, +612/−23** —
   including new modules (`vim_arcade/gh_game.py`, `gh_triage.py`,
   `session.py`), `joue`, `tests/test_gh_triage.py`, a `CLAUDE.md` restamp and
   a stability-milestone rewrite of `.claude/FOCUS.md`. Its history reaches
   back to July and diverges from `main` (branch has `d7c0e90b`; main is at
   `7002618`). Merging on the strength of its title pulls in work the title
   does not mention.
2. A vim-arcade nightly dispatch **was still running against that repo** when
   this was written, so the branch may not have settled.

**Order:** review `#7` against its title (split the `nightly-batch.md` change
out, or retitle it honestly) → merge both together.

Both PRs carry comments explaining this, so the reasoning survives without this
file.

#### UPDATE at close — the dispatch finished, and the divergence is now LIVE

The first manual vim-arcade dispatch **succeeded**: `160 passed in 0.12s`,
1297s, real deliverable (`vim_arcade/paste_lesson.py` — the actual
stability-milestone bar — plus 19 new tests).

**Where it landed, corrected.** An earlier close-out of this session said the
work reached `origin/main` at `b0fd41c`. That was wrong, and the way it was
wrong is worth more than the fact:

    refs/heads/main               1e88818   <- the batch's own commit
    refs/heads/tmux-pane-mechanic b0fd41c   <- the autonomy-merge forward

`hf7y/vim-arcade`'s **GitHub default branch is `tmux-pane-mechanic`, not
`main`.** A plain `git clone` therefore checks out `tmux-pane-mechanic`, and
reading its log as "origin/main" is how `b0fd41c` got reported as main's tip.
That is the wrong-ref witness error — the same class this session spent the day
removing from `ecosim`, committed by the session itself. Verified with
`gh api repos/hf7y/vim-arcade -q .default_branch` and `git ls-remote`, which is
what should have been used the first time.

**This is also a live decision for Zach:** the default branch is what
`scheduler-run` resolves to when `BATCH_BRANCH` is unset, so an unattended batch
targets `tmux-pane-mechanic` unless told otherwise. Pre-existing, not caused by
this session, and probably not intended.

**The half-wiring is no longer hypothetical.** During arming, `scheduler ask`
filed a genuine design question as **`hf7y/vim-arcade` issue #6** ("tmux design
fork: grid-world metaphor or a real tmux session…"), correctly stamped by
`cmd_ask` (`q-94e71f · filed 2026-08-04`, "Answer by commenting on this
issue"). So the issues machinery **demonstrably works**.

But on `main`, `ANSWER_CHANNEL` is unset and `nightly-batch.md` still reads the
file — so **the batch that just ran could not have seen issue #6, and will not
see an answer posted there.** Mitigating detail worth knowing: the agent wrote
`**SUPERSEDED 2026-08-04**` into `scheduler/questions/vim-arcade.md`, so a
*human* reading the file is redirected to issues. A human is redirected; the
batch is not.

This makes merging `#16` + `#7` **more** urgent, not less: there is now a real
open question sitting in a channel the running mechanism does not read.

---

## 2. Next sprint: make the GitHub-issues channel the ecosystem default

**The thesis.** Two answer channels exist —
`.claude/QUESTIONS.md` (file) and GitHub issues — and today which one a project
uses is set per-project by `ANSWER_CHANNEL`, while the *batch prompt* that
actually reads and writes answers is a per-project file that may disagree with
it. `vim-arcade` is the live proof: config on one channel, prompt on the other,
in two separate PRs that can be merged independently. **The channel is
configured in one place and obeyed in another, and nothing checks that they
agree.**

That is the sprint: not "switch everyone to issues", but *make it impossible for
the two halves to disagree.*

**Why issues rather than the file.** Zach answers from a phone; issues notify,
thread, and close. `ecosim` and `bibliothecaire` already run this way and it
demonstrably works — `ecosim` filed #26/#27 from monkey unattended, Zach
answered on GitHub, and the run consumed and closed them.

### Phase 1 — make the disagreement detectable
The `ANSWER_CHANNEL` in `schedule/<p>.conf` and the channel the project's
`.claude/commands/nightly-batch.md` actually uses must be checkable by machine.
Add the check to `hygiene-lint` (it already reports per-project rows) so a
project whose config says `issues` while its prompt says `QUESTIONS.md` is a
FLAG, not a surprise. **Do this first** — without it, every later phase can
half-land exactly the way vim-arcade's did.

### Phase 2 — stop shipping a per-project copy of the prompt
The real defect is that `nightly-batch.md` is duplicated per project and drifts.
`vim-arcade`'s local copy *shadows* the global command. Either the global
command becomes channel-aware (reading `ANSWER_CHANNEL` and behaving
accordingly, so no project needs its own copy), or per-project copies are
generated from one source the way `install-shims.sh` already generates commands
with a `GENERATED by ... do not edit here` header. Prefer the first: one
mechanism beats a generator over N copies.

### Phase 3 — migrate the remaining projects
Once phases 1–2 hold, flipping a project is one conf line plus a lint that
proves both halves agree. Migrate the file-channel projects, then delete the
dead `questions/<proj>.md` paths that nothing reads. Do **not** start here.

### Phase 4 — close the loop the batch depends on
Verify that an answered issue actually reaches a running batch (label
transition, `ensure_gh_labels`, and the consume-and-close step), with a witness
run per migrated project rather than one run generalised to all of them.

**Sequencing rule for whoever picks this up:** phase 1 is the cheap one and the
one that protects the rest. A sprint that starts at phase 3 will migrate
projects into the same half-wired state vim-arcade is in right now, and it will
be invisible because neither half errors.

---

## 3. Three false-finding classes killed today — do not reintroduce them

All three are the same defect: **an unreadable thing reported as a known-good or
known-bad state.** They recurred three times in one day, in three different
files, which is the argument for the shared helper in `lib/hosts.py`.

1. **Swallowed error → CRIT.** `cat FREEZE 2>/dev/null || true` exits 0 and
   prints nothing when the path is absent, so "could not read the freeze"
   became "there is no freeze" became `CRIT FREEZE_NOT_PROPAGATED` about a
   freeze that was present and correct.
2. **Unexpanded `$HOME` → "absent".** Registrations declare
   `PROJECT_REPO_PATH="$HOME/..."`; the shell that reads them is not the shell
   that runs the job. Left literal, `[ -d ]` is false for everything —
   **seven CRITs about repositories that all existed.**
3. **"Cannot see" → "is not there".** Project homes are `0700` by design, so a
   plain `[ -d ]` by the login account returns false for anything inside them.
   Present / absent / cannot-see are three states; absence must be
   *established*, never inferred from a failed look.

**`closeout-lint` still has bug #2 and it is live.** Run today it emitted 8
`FLAG [missing-repo] <proj>: $HOME/Documents/Projects/<proj> does not exist`
and then concluded *"no registered repo has a commit younger than 12h"* — on a
day with commits to four repos. That is a **false all-clear in the tool that
exists to catch things at closing time.** It is the same one-line class of fix
as `ecosim`'s `relocation` sensor got today (resolve `$HOME` from the passwd
entry, or refuse and go BLIND). Highest-value small fix available right now.

---

## 4. State left behind

**Live and verified:** `monkey` is on the tailnet (`100.121.83.23`), reachable
directly from mandark as `ssh monkey`, with a system-wide root-owned scheduler
at `/srv/scheduler` that every account reads and none owns. All three hosts read
`sync LEVEL behind=0`. `ecosim` produces 12 readings about monkey with zero
BLIND. `vim-arcade` is armed (`vim-arcade|1|1|` on main, `EXEMPT:
vim-arcade@monkey`, crontab installed) and a first manual dispatch was running
at close (see the UPDATE in section 1 -- it succeeded).

**Open decisions added at close:** `hf7y/vim-arcade`'s default branch is
`tmux-pane-mechanic`, which is what `scheduler-run` targets when `BATCH_BRANCH`
is unset — decide whether that is intended. And `hf7y/vim-arcade` issue **#6**
(the tmux design fork) is a real question waiting on Zach, currently in a
channel the batch cannot read until `#16`+`#7` land.

**Open decisions (issues, not this file):** #31 tailnet join at install time and
key policy · #32 NOPASSWD scope for hands accounts · #33 how secrets reach an
unattended run (*the one that actually blocked this session*) · #34 superseded,
resolved by the key route · #37 dexter has a checkout, no dispatcher and no way
to stay current.

**Watch for:** `/srv/scheduler` needs `provision/monkey-scheduler-system.sh
--sync` after anything merges to `scheduler` main, or monitors read stale
config. `_paced.monkey.conf`'s command column still points into project homes
rather than `/srv` — the obvious next consolidation, deliberately not done while
`#16` was in flight against that file.
