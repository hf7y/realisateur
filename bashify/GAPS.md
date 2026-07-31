# GAPS — what `bashify` cannot yet do

Recorded 2026-07-30 when `man/bashify.1` was written; revised the same day
when `check` was built at its own exit-4 call site. The page describes four
subcommands; two are backed by tooling. Every gap below exits 4 at the call
site and names itself on stderr. `bashify list` is the live scoreboard; this
file is the reason.

## `page` — writing a man page standalone

**Reclassified 2026-07-30 from GAP to SUMMON.** GAP means no tooling *and* no
escalation. Since `bashify` now spends, `page` has an escalation: it refuses
with exit 3, names its purpose and cost, and reaches the contract store under
`--summon`. It is a metered promise, not a missing one.

It is still not *kept*: the store carries no `verb-page` contract, so an
authorised `page` exits 4 naming exactly that. The page-first defect also
stands — the documented signature is `page <verb> <command>`, which requires a
live command, while the method it serves exists precisely to write a page
before any command does. Fixing that signature is its own amendment.

`bashify.sh` writes a man page *inline*, as part of `emit`, from a fixed
template. There is no way to write or rewrite a page for one verb against a
live command, which is what the page-first method needs: the page comes
first, the tool moves toward it, the page is extended as the tool learns.
Today extending a page means editing troff by hand — which is how this page
was amended, and the labour is the evidence for building this.

## `amend` — built 2026-07-30

Built at its own exit-4 call site, and used the same session to gate the cost-
boundary reversal of `man/bashify.1`. It rules on an edit; it never writes one,
because a gate that also writes can be satisfied by its own output.

It refused that amendment **three times** before allowing it — an undocumented
`--summon` and two stale doctests, then prose naming the very thing the page
forbids naming, then a modal sentence. Every one was the tooling catching its
own author, which is the whole argument for a script over a habit.

**What it still cannot do.** The caller search classifies a hit as an
invocation by matching the verb in command position; a verb invoked through a
variable, an alias, or `xargs` reads as prose. It searches `origin/bashified`
only, so a caller on a default branch is invisible. And a project whose
repository is unreadable is counted and reported, not silently skipped — one
was on this run — but the gate still passes, so "18 searched" is a floor and
not a total.

## `check` — what it does not cover

`check` is built and scores nine rows, five of which were previously
by-eye. It is not complete coverage, and it says so at runtime under
"declared limits of this run" rather than leaving the shortfall silent.

**Forms it does not execute.** A SYNOPSIS form carrying placeholder
arguments must declare `.\" bashify: norun`, and `check` counts and prints
those instead of running them. Four of this page's nine forms are norun.
The escape hatch is bounded — row 3 still requires every such form's
subcommand to exist in the tool's own `list` — but a page could hide a
broken form behind the annotation, and only the printed count would show it.

**Exit codes it does not provoke — and the converse, which is worse.** Row 4
compares only against codes the run happened to provoke, so an *undocumented
but reachable* code passes. On 2026-07-30 the tool gained exit 3 and the page
did not list it; row 4 passed, and a human reading the EXAMPLES caught it. The
row is therefore weaker than it reads: it catches a documented ghost, not a
silent surface. Row 4 verifies that every code the tool
*returns during the run* is documented, and that no documented code
redefines the shared vocabulary. It does **not** prove a documented code is
reachable; codes no invocation provoked are printed as UNCHECKED. On this
page that is currently 2, 4, 5, 6 and 7 — all of which `test/verify-check.sh`
provokes deliberately, but from outside the page test rather than within it.

**Row 3 is only half bidirectional for subcommands.** Flags are compared
both ways against `--help`. Subcommands are compared both ways only when the
tool can enumerate its own (`list`); against a tool that cannot, the row
reports subcommands UNCHECKED and passes on flags alone.

**Row 9 is a heuristic.** It flags modals and future-tense markers in the
contract sections and prints the offending line for a human to judge. It
cannot tell an aspirational promise from a counterfactual aside — it flagged
a legitimate one on the first run, and the page was reworded rather than the
check loosened.

**`--json` is not wired for `check`.** The row scores are human-readable
only, so a caller cannot gate a commit on a specific row without parsing
prose. Requesting `--json` here exits 4 rather than being ignored.

## `emit` has no doctest, deliberately

Every other subcommand appears in the page's EXAMPLES and is executed when
the page is scored. `emit` does not, because running it mutates another
project's repository — it deletes and recreates that project's `bashified`
branch. Its error paths **are** provoked (arity, unregistered project,
claimed verb, malformed verb, and exit 5 via an empty scratch repository),
but the success path is not exercised by the page test. A `--dry-run` for
`emit` would close this; it does not exist.

## `emit` still wraps rather than reimplements

`emit`'s subcommands `exec` the legacy scripts they were discovered from.
That is an honest front door over what exists, not a rewrite, and the
bashified verbs inherit whatever contract those scripts already kept —
including the ones that keep none.

## `BASHIFY_WORK` defaults to a dead scratch path

`bashify.sh` defaults its worktree directory to a scratch path belonging to
a session that has since ended. It works, because the directory is created
on demand, but the default names a session rather than a purpose and will
accumulate. The default should be derived.

## Standing gap: the cost baseline

No before-measurement exists for what these passes replaced, so the saving
is **unmeasured — not zero, and not assumed**. `bashify` spends nothing, so
it produces no after-number either. Closing this needs a real measurement of
a real summon, not an estimate.

## Discovery finds programs only under `bin/`, `scripts/` or `tools/`

**Half-closed 2026-07-31, and the remaining half is stated rather than fixed.**

Discovery excluded programs by file extension — `py|js|mjs|cjs|ts` were
stripped alongside data files — so a verb's subcommand count tracked *shell
scripts* rather than *tooling*. Measured across all 19 registered projects:

| project | subcommands | tooling |
|---|---|---|
| nine-speakers | 0 | 20 Python programs, 0 shell |
| vim-arcade | 0 | 15 Python, 0 shell |
| quatre-vingt-douze | 0 | 2 Python, 0 shell |
| secretaire | 0 | 2 Python, 0 shell |
| abletim | 0 | 2 Python, 0 shell |
| home-assistant | 0 | 1 Python, 0 shell |
| bibliothecaire | 2 | 6 Python, **2 shell** |
| crt | 48 | 79 shell |
| scheduler | 25 | 41 shell |

The count equals the shell-script count in every row. Six verbs were blind to
their own project's language, and an empty subcommand list read as "this
project has nothing" rather than "this discovery cannot see it".

**The language filter is deleted** — the extension blacklist now strips data
files and `.pyc` only. That closed **one** project of six (`bibliothecaire`
2 → 7), because bibliothecaire keeps its Python in `bin/`.

**The other five are still invisible, deliberately unfixed.** Discovery's
first branch globs `*.sh` alone, so a program outside `bin|scripts|tools` is
found only if it is a shell script. `quatre-vingt-douze`'s `page92.py` sits at
the repository root and remains undiscoverable; so does `nine-speakers`'
twenty. Closing it means widening that glob, which is a change to how `emit`
works and is therefore an amendment's job, not a patch's: `man/bashify.1` now
promises language-independent discovery, and the next `--summon` at this call
site is obliged to satisfy the page rather than the code it finds.

## `emit` writes summaries that fail row 1

**12 of 18** emitted `VERB_SUMMARY` strings join clauses with "and" —
`guard the estate's data: nightly backups and their proof`,
`survey the ecosystem and read its state`,
`sort the mail and decide what deserves an answer`. Row 1 of the page test
rejects exactly this, so the generator produces pages that fail its own
contract before any implementation exists. `garde`, the only verb on `PATH`,
scores 3 of 9 and fails row 1 for this reason. The page now states the
one-clause obligation; the generator does not yet keep it.

## `check` reports written sections as missing when the heading is quoted

Found 2026-07-31 by `verb-page` RUN 4, at a cost of two rows on a page that had
actually written them. `lib/check.sh` matches sections with a literal
`.SH <name>` scan, so a page using the ordinary troff form `.SH "EXIT STATUS"`
— quoted, as any multi-word heading may be — is read as having no EXIT STATUS
section at all. **The failure direction is the dangerous one:** it reports a
fully-written section as absent, so an author "fixes" a page that was correct.

## `check` row 6 can pass for the wrong reason

Found the same day by RUN 3. Row 6 greps `^\.B \-\-summon` across the whole
page, so a page that names `--summon` **in order to deny it** ("this verb cannot
spend, it has no `--summon`") lands on the summon branch and passes as though it
had declared one. The row's PASS text said "page documents --summon" while the
page said the opposite. Only reading the PASS *text* rather than the count
caught it — which is the same failure mode as an exit-0 no-op, one level up.

## A contract's `output:` field is not enforced by anything

`basheur` lints that the field EXISTS; nothing checks that a summon obeyed it.
Measured across five summons in one session, all violating the same clause
("nothing else on stdout") in **three different ways**: `idea-to-contract`
returned its contract wrapped in prose and a code fence; `verb-page` RUN 1
returned the page inside a fence; RUNs 2–4 wrote the page to `/tmp/<verb>.1`
and printed a *report* on stdout instead. Every caller therefore has to parse
prose to find the artifact, which is precisely what a stated output field exists
to prevent. The contracts are not wrong — they are unenforced.

## The page test cannot score a page whose verb does not exist

**The finding of the 2026-07-31 pass, and it is a tension in the doctrine, not a
bug in the tool.** `man/bashify.1` says a page "is written before its utility is
complete, and the utility is judged against the page rather than the reverse."
But three of the nine rows can only be scored against a live verb:

- **NAME** compares the page's name to the command under test's basename, so a
  page for `fonde` scored against `bin/validate-quotes.py` fails by construction.
- **SURFACE** compares the page's flags against the command's `--help`, which is
  the legacy program's help, not the verb's.
- **EXAMPLES** executes doctests that invoke a binary not on PATH.

Measured on four pages written the same day: `fonde` 5/9, `verse` 6/9,
`cueille` 6/9, `range` 5/9. **6 of 9 is the ceiling at page-writing time.**
Either `verb-page` scores those three rows against `<verb>`, or the contract
states the ceiling in its own output field. Unresolved deliberately — picking
one silently would make a real doctrinal question look like a formatting choice.
Four runs of evidence in `basheur/residue/verb-page.sh`.
