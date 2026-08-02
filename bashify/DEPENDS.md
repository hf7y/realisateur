# `DEPENDS.tsv` — the declared reach of a bashified branch

*Derived 2026-08-02 across the seven bashified branches. This file holds the
FORMAT, the DERIVATION RULE, and the judgements that cannot be derived. It
deliberately does not hold the data: the data is generated, and a hand-stored
copy of a derivable thing is how the 2026-07-27 shim gap happened.*

## Why a branch needs one

The self-containment gate proves a branch works from a bare clone by nulling
every declared dependency and asserting nothing else escapes. That only works
if "declared" is written down. Without it the gate cannot tell a legitimate
reach from a defect, and would have to either fail every verb or trust every
verb.

Escapes fall into two classes and **only one is a defect**:

- **IMPLEMENTATION escape** — the verb reaching its own repo's *other branch*
  to exec a script it wraps. This is what the migration removes.
- **DOMAIN escape** — the verb reaching its *subject*. `installe` writing to
  `~/.local/bin`, `fauche` scanning `~/Documents/Projects`, `glane` fetching
  from an archive. Legitimate; must be declared, never removed.

## Format — 10 columns

```
#verb  file  line  kind  name  value  class  scope  guard  null_to
```

| column | holds |
|---|---|
| `verb` | basename of the `bin/*` file; for a `lib/*` row, the verb that sources it |
| `file` `line` | branch-relative path and line where the dependency is *declared* |
| `kind` | `PATHVAR` \| `PATHLIT` \| `EXEC` \| `BIN` \| `NET` \| `DOC` (named in output, never run) |
| `name` | variable, binary, or subcommand; `-` for `PATHLIT` |
| `value` | default/literal/target, `$HOME`/`$SELF`/`$ROOT`/`$LEGACY_ROOT` left symbolic |
| `class` | `SELF` \| `IMPLEMENTATION` \| `DOMAIN` \| `DEAD` \| `RUNTIME` \| `UNCLASSIFIED` |
| `scope` | `SELF` \| `OWNREPO` \| `XPROJ:<name>` \| `HOME` \| `PATH` \| `NET` |
| `guard` | `x-test` \| `f-test` \| `r-test` \| `d-test` \| `commandv` \| `none` |
| `null_to` | what the gate substitutes; `UNOVERRIDABLE` where no variable exists |

## Derivation — no human in the loop

Run per branch from a worktree of `bashified`, over `bin/` and `lib/`.
Classification, **in this order**:

1. `DEAD` — the name occurs exactly once in the file (`grep -cw` == 1).
2. `RUNTIME` — the default contains no `/`.
3. `SELF` — resolves under `$SELF`/`$ROOT` **and** `git cat-file -e bashified:<rel>` succeeds.
4. `XPROJ:<n>` — matches `Projects/([^/]+)` where `$1` is not this repo.
5. `IMPLEMENTATION` — matches `Projects/<this repo>` (or is `$LEGACY_ROOT`-rooted)
   **and** `git cat-file -e bashified:<rel>` **fails**.
6. `DOMAIN` — everything else.

**Rule 5 is the load-bearing one and it is exact:** *"in my repo, not on my
branch"* is precisely the defect being removed.

## What CANNOT be derived — stated rather than papered over

Two judgements have no mechanical signal, and pretending otherwise would bake a
guess into a regex where nobody would find it:

1. **IMPLEMENTATION vs DOMAIN for a path naming DATA rather than a script.**
   `arme`'s `schedule/_monitor.conf` and `dose`'s `bin/morning-report.sh` are
   identical to every filesystem test: both in the repo, neither on the branch.
   The only source signal is the guard token — `[ -f ]` vs `[ -x ]` — which is
   a heuristic a future author can violate without noticing.
2. **Whether a DOMAIN path is the verb's genuine SUBJECT.** Nothing in `bin/*`
   distinguishes `~/.local/bin` being `installe`'s subject from it being merely
   a place `transplante` searches. That lives in `man/*.1` and `CONTRACT.md`.

**Resolution:** emit `UNCLASSIFIED` rather than guessing, and resolve from a
small committed `DEPENDS.overrides.tsv` keyed on `verb+file+line`. The drift
check compares generated-plus-overrides against the committed file; a *newly
appearing* `UNCLASSIFIED` row fails the gate until a human classifies it once.
The bulk stays never-hand-maintained; the genuine judgement becomes explicit,
small and reviewable.

## Verbs with ZERO implementation escapes — 7

These work from a bare clone today, with only domain dependencies satisfied:

`trie`, `glane`, `accroche` (bibliothecaire) · `fauche`, `transplante`
(gardien) · `installe`, `recense` (senechal)

- **Not 8:** `entraine` (vim-arcade) has zero escapes only because its
  `LEGACY_ROOT` is dead and `verb_subcommands` prints an empty list. It cannot
  regress and cannot demonstrate anything; counting it inflates the figure with
  a verb that does no work.
- **Not 6:** `accroche`'s `basheur` is a PATH *name*, not a filesystem path into
  another repo, and its arm exits cleanly through `verb_gap` when absent — the
  same shape as `installe`'s `notify-senechal`. Excluding it while keeping
  `installe` would be inconsistent.

## Genuinely debatable — for a human, not a regex

| site | the tension |
|---|---|
| `arme:44-45` | reaches main for the monitor *register* — data the verb arguably owns |
| `garde:31` | `basheur` is delegation infrastructure (domain in intent) reached by absolute cross-repo path (implementation in mechanism) |
| `ausculte:22` | its own source argues declared-domain pending a file move; by the resolves-into-a-repo test it is an implementation escape into ecosim |
| `fonde:50` | briefs are corpus (domain) but the fallback path is inside the implementation tree; which applies depends on runtime state, not source |
| `manifest.sh:12` | `$SELF/garde.json` is branch-relative but **not committed** — a bare clone has a SELF path that does not exist, which is neither escape class |
| `arpente:65`, `juge:93` | `fable-like/…` is same-repo by path, vendored-other-project by content |
| `page92.py:56` | outbound network is domain for a harvester, but it is the estate's only network reach and may deserve its own class |

## A defect found in the purge guard while deriving this

`bashify.sh`'s vendor alternation was **unanchored**, so the three-letter tokens
`llm` and `gpt` matched inside ordinary words. Measured hits across the estate:
`re.fu`**`llm`**`atch` (twice) and `nKi`**`llM`**`ode`. None names a vendor.

Each would have blocked a commit, or — worse — classified a perfectly movable
script as unmovable during the migration, on the strength of the letters in
`fullmatch`. The `\bagent\b` half was word-bounded from the start; the vendor
half was not. Fixed to a **leading** `\b`, which still catches `LLMs`,
`claudes`, `assistants` (a trailing anchor would let a plural evade).

**A guard that cries wolf is a guard someone eventually switches off.**

### Corrected partition after that fix

The movable/essential split was computed with the unanchored pattern.
`plasma-panel-visible.sh` matched only on `re.fu`**`llm`**`atch` and flips to
CLEAN, so `veille` goes 10 → **9** subcommands, not 10 → 8, and the partition
of the 72 wrapped scripts becomes:

> **23 CLEAN / 18 COMMENT-ONLY / 31 ESSENTIAL**

The two other instances found by a whole-tree sweep — `ecosim
bin/migration-watch.py` and `senechal journal/2026-07-31.json` — were never in
the 72: `.py` is excluded from script discovery at `bashify.sh:62`, and a
journal is not a script. Both counts are consistent; they have different scopes.

## THE BLOCKER FOR THE MIGRATION — a false negative, and it is worse

Anchoring fixed the false-*positive* class. The false-*negative* class is
untouched and it is the one that can put the model dispatcher onto a branch
that guarantees it contains no such thing.

**`scheduler/bin/scheduler-run` scores ZERO on the purge guard.** Measured:

```
grep -ciE '\b(claude|…)|\bagent\b' bin/scheduler-run          -> 0   (passes)
bin/scheduler-run:93   source "$SCHED_ROOT/lib/sweep-loop-common.sh"
grep -ciE '…' lib/sweep-loop-common.sh                        -> 35  (fails hard)
```

That library is the engine: `claude -p`, `PROMPT`, `MODEL`. So a script whose
whole job is dispatching a model **passes the guard**, because the naming is one
`source` away.

Under the migration rule — *"a wrapped script moves iff it passes the purge
guard"* — `scheduler-run` would be classified CLEAN and **moved onto the
bashified branch**. The branch's stated guarantee would then be false, and false
in exactly the way the guard exists to prevent.

**The guard checks files individually and is blind to `source`.** Two possible
fixes, both real work, neither done here:

1. **Transitive closure** — resolve `source`/`.` within the moved set and score
   the closure, not the file. Correct, and it is what the rule actually meant.
2. **An explicit recorded judgement** per script, in `DEPENDS.overrides.tsv`.
   Cheaper, but it is prose in a table and will decay.

Until one exists, **`scheduler-run` must not be moved**, and the partition's
CLEAN column cannot be trusted as a move-list — only as a first pass. Any other
script that `source`s a library outside the moved set is the same class; nothing
has enumerated them yet.
