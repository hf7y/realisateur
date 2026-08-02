# The closure pass — 2026-08-02

**What this closes.** `bashify/DEPENDS.md` recorded a migration blocker on
2026-08-02: the purge guard scores files individually and is blind to `source`,
so `scheduler/bin/scheduler-run` — a script whose whole job is dispatching a
model — passed it. That is now closed mechanically, and building the fix turned
up a second, larger finding underneath it.

**Method.** Every number below was re-derived at the time of writing by running
the tool named beside it. Where a figure came from a subagent it says so and
says how it was independently verified. The recurring failure this ecosystem
records is a survey headline that was true once — so nothing here is quoted
forward from an earlier document without being re-run.

**Draft PR:** `hf7y/realisateur#15`, branch `bashify-closure-guard`.

---

## 1. The blocker, closed

`bashify/lib/closure.sh` resolves `source`/`.` transitively and scores the
*closure*, not the file.

```
scheduler  bin/scheduler-run  ESSENTIAL  self=0  closure=35  members=4
           via lib/sweep-loop-common.sh
```

Chain, verified by reading the files rather than trusting the count:
`bin/scheduler-run` → `lib/sweep-loop-common.sh` → {`lib/autonomy-merge.sh`,
`lib/registry-lock.sh`}.

### A third class the original note did not reach

`scheduler-run:44` is `source "$CONF"` — a path that is *runtime state*. No
static tool can score what is behind it. Silently treating an unresolvable
source as *no dependency* would rebuild this exact false negative one layer
down, where it is harder to see. Such a script is `UNRESOLVED` and is **never
CLEAN**. `scheduler-run` therefore fails for two independent reasons.

### The enumeration — it is exactly two

DEPENDS.md said *"nothing has enumerated them yet"*. Enumerated across all
seven repos:

| project | script | class | why |
|---|---|---|---|
| scheduler | `bin/scheduler-run` | ESSENTIAL | sources the model dispatcher |
| scheduler | `bin/morning-report.sh` | UNRESOLVED | `. "$conf"` at line 110 |

**Both are scheduler. No other repo has one.** `ESCAPES` is **0** — no wrapped
script in the estate sources a file outside its own repo, a question that had
been open and is now closed by measurement.

### Partition by closure

> **23 CLEAN / 25 COMMENT-ONLY / 45 ESSENTIAL / 1 UNRESOLVED / 0 ESCAPES**
> over **94** wrapped scripts

**Do not quote this against the 72 in DEPENDS.md.** The 72 was measured on
2026-07-30; the trees have grown, and this run covers every repo with a
`bashified` branch including realisateur itself. Two different questions, both
answers correct. Re-derive with `bashify/lib/closure.sh`.

---

## 2. The larger finding — the purge guard only ever runs once

Found while building the above, and it is the more consequential of the two.

`bashify.sh` checks the purge at **emit**, against the tree it is about to
commit, refusing at exit 5 if anything matches. **Nothing ever asks again.**

Since the doctrine changed on 2026-07-30 to *one noun, many verbs*, a branch
growing after emit is the expected state: `bashify coin` adds verbs, and `emit`
*refuses* to run against a branch carrying more than one because it would
delete them. So the guard runs at the exact moment the branch is smallest, and
never again across the whole period it is actually being added to.

Measured across all seven branches as they stand — **25 files break the promise
their own README makes** (*"a total purge: it keeps the tool and nothing
else"*):

| repo | files |
|---|---|
| bibliothecaire | 12 |
| gardien | 5 |
| scheduler | 3 |
| senechal | 2 |
| ecosim | 1 |
| vim-arcade | 1 |
| realisateur | 0 |

`bashify/lib/branch-purge.sh` re-asks. Its gardien row includes `lib/verb.sh`,
caught **independently** as drifted from the skeleton — the same Law 3
violation `runtime-check.sh` reports, reached from a different direction. That
cross-check is the reassuring part: two guards asking different questions agree
on the same repo.

Exemptions are derived where possible (`lib/verb.sh`, and **only** while
byte-identical to the skeleton — the same byte-identity `bashify.sh` already
makes load-bearing) and recorded where not, in `bashify/PURGE-EXEMPT.tsv`.
Exemptions are themselves checked: an entry whose file no longer matches is
reported `STALE` and fails.

`PURGE-EXEMPT.tsv` was written **empty** and stayed empty until the audit
landed — classifying first would have recorded a guess as a judgement. It now
carries 16 rows, all verified by reading the matching lines rather than by
trusting the audit's table, taking the guard from **25 findings to 9**. The 9
that remain are 4 genuine defects and 5 judgement calls (§7-D); none is
exempted, and the guard stays red on them deliberately.

---

## 2b. The third finding — `bashify emit` was broken for every project

Found by the branch audit, verified by reproduction. **This is the most
consequential item in the pass.**

`bashify.sh`'s own header records this happening once before:

> the guard was UNSATISFIABLE and `emit` exited 5 for every project, on every
> run, **for two days** — while `bashify list` went on reporting emit
> MECHANIZED, because `_state` only asks whether the file is executable.

**It happened again, the same way.** The de-fork commit (`8f83801`, the same
day) added this line to the skeleton, for good reason:

```
# gardien's `verb_gap_or_summon` is NOT here. It calls `claude -p` directly.
```

`claude` is a vendor name. The exemption was bounded to *"the generic English
word `agent`, never to a vendor name"*, and the vendor grep had **no exemption
at all, for any path, ever**. So every `emit` matched the skeleton it had just
copied in and exited 5.

**Reproduced rather than reasoned about.** A throwaway registry, a clean
one-script repo, run against both the current generator and the pre-change one
at `7225a19`. Both exit 5 on `./lib/verb.sh` — so this predates this pass and
the widened `agent` pattern did not cause it.

*(A first attempt also flagged `bin/<verb>`. That was the fixture living under
a path containing `.claude`, which the generated verb bakes into `LEGACY_ROOT`.
A false attribution caught before it was recorded; test E0 now asserts the
fixture path is clean.)*

**The fix** bounds the exemption by **byte-identity alone**, which is the
property that actually makes it safe: a reviewed, version-controlled skeleton
cannot smuggle anything whatever words it uses. The word-level bound only ever
added a way for the guard to become unsatisfiable when the skeleton's prose
changed. This also makes `bashify.sh` agree with `branch-purge.sh`, which
already exempted the byte-identical runtime from the whole pattern.

`test/verify-emit.sh` is the end-to-end run this generator **never had** — 11
assertions, of which E1 is simply *"emit exits 0 on a clean project."* Nothing
has ever asserted that. That is why it broke twice.

**The pattern worth naming:** both times, emit's health was inferred from a
file mode (`_state` asks `[ -x ]`) rather than from running it. A subcommand
that reports MECHANIZED because its implementation file is executable is
reporting on the filesystem, not on the promise.

---

## 3. Underneath both: one definition instead of three

`bashify/lib/surface.sh` now holds the vendor list and the discovery rule
*once*. They had been typed out separately — which is exactly how the
2026-08-02 anchoring fix reached the content guard and **not** the path guard
eleven lines above it. `fullmatch.sh` and `killmode.sh` were still being purged
from the subcommand surface, silently, recorded in GAPS.md as "deliberately not
exposed" where it reads like a judgement rather than a bug.

Applying the anchor to the path guard changes the classification of **zero**
real files estate-wide: it removes the false-positive class and regresses
nothing. Discovery verified byte-identical to the pipeline it replaces across
five repos (scheduler 25, senechal 19, bibliothecaire 7, gardien 5,
realisateur 31 scripts).

### `agent` is deliberately unanchored — and this is measured both ways

The two halves of the pattern fail in **opposite directions**:

- `llm`/`gpt` are three-letter substrings of ordinary English, so they need a
  **leading anchor** or they match `re.fu`**`llm`**`atch`.
- `agent` is a whole English word whose compounds — `subagent`, `agents`,
  `agentic`, `agentish` — are all *genuinely agent-naming*, so an anchor on
  either side is an **evasion**, not precision.

Measured:

- widening `\bagent\b` → `agent` changed the verdict on **zero** files
  estate-wide (every file containing a compound already contained a bare
  `agent`), so nothing newly fails and no false positive is introduced;
- anchoring it flips `realisateur/hooks/subagent-closeout.sh` from purged to
  **exposed** — a subcommand named after an agent on a branch promising none.
  That one file is the whole reason it is not anchored.

---

## 4. gardien's Law 3 — the design, and a stale figure corrected

Researched by subagent, **independently verified here before recording.**

### It is 3 call sites, not 4

`bin/garde` has four textual hits of `verb_gap_or_summon`, but line 241 is a
comment. The three real calls are at **218, 223, 276** (`media dedup`,
`media remote`, `backup`).

The `media triage` and `coverage` arms were **already refactored** to call
`basheur run [--summon] <contract>` directly and no longer touch the function.
The "four" figure predates that refactor.

**The stale figure is in realisateur's own skeleton**, at
`bashify/skel/lib/verb.sh` lines 97 and 101 — verified by grep, both say four.

### Why the conversion is not mechanical

`basheur run --summon <contract>` takes a **contract name** and assembles the
whole prompt from a committed `.contract` file. `verb_gap_or_summon` takes
**free text**. There is no channel for injecting per-call instructions.

None of the 14 contracts in the store expresses any of the three call sites.
All three need a new contract authored first — judgement work.

Worse, two of them may not fit the model at all: `media remote` and `backup`
are **one-shot design-proposal** requests ("propose what a `kind: s3` entry
would need"; "read `gardien.py` and propose an argv contract"). basheur's model
assumes a contract is invoked repeatedly with a `verify:` checking output shape
each time. A "propose a design" ask has no repeat semantics — once answered,
the gap should be *built*, not re-asked.

**That is a Zach decision**, recorded in §7.

---

## 5. Decisions I made — each flagged, each revertible

Zach was AFK with standing instruction to pick a good path and keep it
revertible.

| # | decision | why | revert |
|---|---|---|---|
| D1 | Made `agent` **unanchored** in the shared pattern | Measured: zero verdict changes estate-wide; anchoring would expose `subagent-closeout.sh` | one line in `bashify/lib/surface.sh` (`SURFACE_RE_AGENT`) |
| D2 | Record 16 exemptions once the audit landed; leave 9 red | The 16 are summon-docs, test artifacts and `User-Agent` substrings, each re-verified by reading the lines. The 9 are defects and judgements — exempting those would be switching the guard off | delete rows from `bashify/PURGE-EXEMPT.tsv`; the guard returns to 25 |
| D7 | Fixed `emit` by bounding its exemption on **byte-identity** rather than on the word `agent` | The word-level bound is what made the guard unsatisfiable twice; byte-identity to a reviewed skeleton is what actually makes it safe | revert the `LEAK=` block in `bashify/bashify.sh` — but `emit` breaks again for every project |
| D3 | Put the work on a **new branch** `bashify-closure-guard`, not `propagate-runtime` | `propagate-runtime` was already merged as #14 | branch is independent; nothing else moved |
| D4 | Reset local `propagate-runtime` to `origin/propagate-runtime` | It sat 3 ahead with commits already pushed elsewhere; the divergence was bookkeeping noise | `git branch -f propagate-runtime b151c84` |
| D5 | **Did not** fix the stale "4 call sites" in `skel/lib/verb.sh` | The skeleton is byte-identity-checked; editing a comment marks all 6 adopted repos DRIFTED until a mass re-sync — wrong trade unattended at 98% gate | n/a — nothing changed; see §6 |
| D6 | Overrode `installe`'s refusal for `garde` after checking its assumption | `installe audit` calls it `repo-link`, target exists and is executable, and sibling verbs `fauche`/`transplante` are already in the manifest pointing at the *same directory* | **not applied** — blocked, see §7 |

---

## 6. Remaining roadmap

**Ordered by what unblocks what.**

1. **Resolve the 9 remaining branch-purge failures.** The other 16 are now
   classified and recorded in `PURGE-EXEMPT.tsv`, taking the guard from 25 to
   9. What is left is 4 genuine defects and 5 judgement calls (§7-D). The
   defects are removable without asking anyone; the judgements are not.
   *Blocks: using the guard in CI or a closeout hook.*

2. **Fix the stale "4 call sites" in `skel/lib/verb.sh` and re-sync.** One
   comment edit, then `bashify/lib/sync-runtime.sh <project> --apply` across the
   6 adopted repos, each needing a commit and push. Deferred as D5.
   *Do this in one deliberate pass, not incidentally.*

3. **gardien Law 3.** Author the `media-dedup` contract first — it is the only
   one of the three that is structurally close to an existing contract
   (`media-triage`: positional paths → classified report). Then decide §7-B for
   the other two.
   *Blocks: gardien adopting the union runtime; blocks 6-of-7 becoming 7-of-7.*

4. **The libexec migration itself.** The CLEAN column is now a real move-list
   for 23 of 94 scripts — the two false negatives are named and excluded.
   *No longer blocked.*

5. **`verify-amend.sh` hangs** on a timeout. Pre-existing and unrelated to this
   pass (it references none of the changed files; `amend.sh` sources nothing).
   A test that hangs is a test nobody runs.

6. **`consign-prose` has no implementation.** `fonde consign` is contracted on
   the page and gated behind `--summon`, so every deposit into the vault
   currently costs an agent turn to do by hand what the contract fully
   specifies: derive frontmatter, copy the body byte-for-byte, and generate the
   `Referenced` wikilinks from the scheduler registry rather than a typed list.
   The contract is precise enough to implement directly — including its exit
   codes and its refusal to overwrite a note whose body differs. Writing
   `bibliothecaire/test/verify-consign-prose.sh` and the mechanism behind it
   would retire a recurring cost, which is what `--summon` exists to make
   temporary. *This note was deposited by executing that specification
   mechanically rather than by paying the summon.*

---

## 7. Blockers that need Zach

**A. `installe --force verb gardien garde` is blocked by the permission
classifier.** Second session running. This is the last `UNOWNED` row in
`install-verbs.sh` — everything else on the host is `OK`.

I checked the refusal's assumption rather than just overriding it: `installe
audit` classifies `garde` as `repo-link`; its target
`/home/zach/Documents/Projects/gardien-garde/bin/garde` exists and is
executable; and its two sibling verbs `fauche` and `transplante` are already in
the manifest pointing into the **same directory**. The dry run with `--force`
confirms it would replace the link with an **identical** link:

```
installe: would adopt garde: replace the unowned link at
  /home/zach/.local/bin/garde -> .../gardien-garde/bin/garde
```

Zero behavioural change; pure bookkeeping. It needs either a hands-on run by
Zach or a Bash permission rule. **This also changes machine-wide config, so
whoever runs it should follow with `notify-senechal`.**

**B. Do `media remote` and `backup` belong in basheur at all?** Both are
one-shot design asks, not recurring classifications. Authoring contracts for
them would freeze a one-off request into a recurring-service shape it does not
fit. The alternative is to do the design work directly and delete the summon
path. *This is a judgement about what basheur is for, which is why it is here
and not in a diff.*

**D. Nine branch-purge findings remain, and five of them are yours to decide.**

Four are **defects** and can simply be removed:

- `bibliothecaire CONTRACT.md` — *"two an assistant processes"*: broken grammar
  left by a find/replace of a vendor name. A laundering artifact, not
  documentation.
- `gardien CONTRACT.md`, `gardien bin/garde`, `gardien lib/verb.sh` — all three
  are the Law 3 violation in §4, stated, commented, and **executable**
  respectively.

Five are **judgements**, where the guard-as-written conflicts with a legitimate
tool, and no mechanical signal decides it:

| file | the tension |
|---|---|
| `bibliothecaire REAPED.tsv` | a cryptographic proof-of-**deletion** that must name what it deleted |
| `ecosim GAPS.md` | names a governance file by filename |
| `gardien bin/fauche` | real code that must name the file to classify it — in *other*, unpurged repos |
| `scheduler bin/arme` | live spend-detection code whose **job** is grepping for vendor names |
| `vim-arcade CONTRACT.md` | the game's own pedagogical premise (pasting to/from a chat) |

`scheduler bin/arme` is the sharpest: the guard's text says the exemption
"applies only to `lib/verb.sh`, never to a vendor name", and `arme` cannot do
its job without naming vendors. One of the two has to give.

**C. The 7-day usage window is at 98% util against a 93.3% burn-line**
(slack −4.7pts, `status=allowed_warning`, resets in ~11h). This pass was
deliberately scoped down because of it — one subagent pair instead of a fan-out,
and the mass re-sync in roadmap item 2 deferred rather than attempted.

---

## 8. How to re-derive everything here

```sh
bashify/lib/closure.sh                 # partition + false negatives, exit 1 if any
bashify/lib/closure.sh --false-neg     # just the migration blockers
bashify/lib/branch-purge.sh            # the 25, per repo
bashify/test/verify-closure.sh         # 27 assertions
bashify/test/verify-branch-purge.sh    # 12 assertions
bashify/test/verify-emit.sh            # 11 assertions -- emit actually runs
bin/install-verbs.sh                   # the UNOWNED garde row
```

Nothing above is stored; it is all generated. A hand-stored copy of a derivable
thing is how the 2026-07-27 shim gap happened.
