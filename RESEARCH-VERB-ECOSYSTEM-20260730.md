# Research — the verb ecosystem, and whether a project deserves many verbs

*Offline survey, 2026-07-30, of all 19 `bashified` branches. Zach asked for
a research step before the multiple-verbs suggestion; this is it. No agent
cost — all findings read straight from the branches.*

## The one-line answer

**A project should have several small verbs, not one large one — and the
naming rule already says so.** The current one-verb-per-project mapping was
the bashify pass's shortcut, not a decision. The evidence below is that the
shortcut breaks exactly where a project does more than one thing.

## The grammar makes the case before the data does

The ecosystem's own rule: **French noun = animate (a project/agent); French
imperative verb = inanimate (a tool).** A project is a *noun*. A noun does
many things. `crt` — the noun — rings a handset, catalogs a book, trains an
STT model, deploys to potato. Those are not one verb; they are what the noun
can *do*. Forcing each noun to expose exactly one verb fights the grammar
the ecosystem chose. **One noun, many verbs** is the natural shape, and it is
also the unix shape: small tools that each do one thing.

## The data agrees, loudly

Subcommands wired under each project's single verb:

| project | verb | subs | reading |
|---|---|---:|---|
| crt | sonne | **98** | not a verb, a suite |
| scheduler | dose | **52** | dispatch + reporting + linting + crontab + usage, welded |
| realisateur | juge | **44** | survey + audit + lint + commit-plumbing |
| senechal | veille | **40** | watch/journal + remedies |
| gardien | garde | 26 | (Zach's live work — left alone) |
| ecosim | sonde | 12 | borderline |
| wtul | grave | 10 | borderline |
| vkv-inventory | compte | 8 | borderline |
| bibliothecaire | range | 6 | coherent, single verb is fine |
| everything else | — | ~2 | one real capability or none yet |

`dose`'s 52 subcommands include `collect-feedback`, `sync-crontab`,
`token-usage`, `morning-report`, and `nightly-batch-loop`. Those are four
different *domains* a user would invoke for four different reasons and pipe
into four different things. Calling them subcommands of one verb is a
category error that a `man` page cannot rescue.

**The natural break is by domain, and the big four each have obvious seams:**
- **crt** → the voice loop, the book-game funnel, the deploy/ops surface.
- **scheduler** → dispatch (`dose`, keep it), reporting, linting, usage-gating.
- **realisateur** → sensing/survey, audit, lint, commit-plumbing.
- **senechal** → keeping watch, and applying remedies.

These are *candidates*, not a decree — naming the seams is exactly the
judgment to put in front of Zach rather than take unattended. What the
research settles is only that the seams are real and the 1:1 mapping hides
them.

## Pipeability is promised and not delivered

The shared runtime (`lib/verb.sh`) parses `--json` and `--quiet` and sets
`VERB_JSON` / `VERB_QUIET`. **Nothing consumes them.** Every subcommand
`exec`s its legacy script unchanged, and the legacy scripts never heard of
those flags. So a verb *advertises* machine-readable, quiet-able output in
its own `--help`, and silently ignores the request. That is the exit-0-no-op
pattern wearing a flag: the caller asks for JSON, gets prose, and nothing
says the flag did nothing.

For "unix-like, pipe-able, aesthetic" to be true rather than aspirational,
the verbs need three things they do not yet have:
1. **Line-oriented, quiet-by-default output** a downstream tool can read
   without a parser. Commentary goes to stderr; results go to stdout.
2. **`--json` actually honored** where structured output makes sense —
   which means the verb owns its output format instead of passing through a
   legacy script's human prose.
3. **Composability by design**: the output of one verb is a reasonable
   input to another. `sonde` (probe) → `juge` (judge) → `dose` (apportion)
   should be a pipeline, not three unrelated CLIs.

This is the strongest argument that a bashified verb must eventually
*reimplement* rather than *wrap* (the M3 "self-contained" milestone): a
pass-through wrapper can never honor `--json`, because the format is decided
downstream of it.

## What "cleanup" turned out to mean

The branches are structurally clean — 7 files each (`bin/<verb>`,
`lib/verb.sh`, `CONTRACT.md`, `GAPS.md`, `README.md`, `man/<verb>.1`,
`test/contract-test.sh`), `main` plus one purge commit, no debris. The only
incoherence is the **contract**: most branches still carry the one-eyed stub
("no shell tooling existed in this project") that measured `*.sh` and missed
Python/Node entry points — the same error that withdrew BASHIFY-REPORT
finding 1. Cleaning up a branch therefore *is* deriving its real contract,
which is the contract workstream, not a separate one.

Two systemic issues worth a line each, neither mass-fixed here:
- **`LEGACY_ROOT` is a hardcoded mandark path** in every verb (overridable
  by env, but wrong by default anywhere else — e.g. nomac). A portability
  bug that the self-containment milestone dissolves rather than patches.
- **The stub contracts are wrong, not just thin**, and should be re-derived
  through `basheur run project-contract`, not hand-edited.

## Recommendation

1. **Adopt "one noun, many verbs."** Split the big four along the domain
   seams named above; keep single verbs for the coherent small projects.
   The split is Zach's to approve (see QUESTIONS).
2. **Make pipeability real, not advertised.** Quiet-by-default, commentary
   to stderr, `--json` honored — which pulls M3 (reimplement, don't wrap)
   forward for any verb that claims structured output.
3. **Re-derive the stub contracts** through basheur, in the garde shape,
   rather than hand-editing — the derivation is what catches the seams.
