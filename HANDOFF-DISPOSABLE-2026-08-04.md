# HANDOFF (disposable) — 2026-08-04

**Delete this file once its contents are merged, filed, or superseded.** It is a
session handoff, not a record. The durable record is `.scheduler/FOCUS.md`,
issues #31–#34 / #37, and the commit messages named below.

Written at `/cloture` by the session that put `monkey` on the tailnet, taught
`ecosim` to see arbitrary hosts, and armed `vim-arcade`.

---

## 1. PRs: merge, or why not

Four open. **Two are ready. Two are paired and must not land alone.**

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

**Order:** let the dispatch finish → review `#7` against its title (split the
`nightly-batch.md` change out, or retitle it honestly) → merge both together.

Both PRs carry comments explaining this, so the reasoning survives without this
file.

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
at close.

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
