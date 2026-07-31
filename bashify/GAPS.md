# GAPS — what `bashify` cannot yet do

Recorded 2026-07-30 when `man/bashify.1` was written; revised the same day
when `check` was built at its own exit-4 call site. The page describes four
subcommands; two are backed by tooling. Every gap below exits 4 at the call
site and names itself on stderr. `bashify list` is the live scoreboard; this
file is the reason.

## `page` — writing a man page standalone

`bashify.sh` writes a man page *inline*, as part of `emit`, from a fixed
template. There is no way to write or rewrite a page for one verb against a
live command, which is what the page-first method needs: the page comes
first, the tool moves toward it, the page is extended as the tool learns.
Today extending a page means editing troff by hand — which is how this page
was amended, and the labour is the evidence for building this.

## `amend` — the contract-change gate

The four steps (stated reason, previous page preserved, full re-run of the
rows, callers searched) are run by hand and can therefore be skipped by
hand. The first real amendment of `man/bashify.1` ran all four manually:
the caller search was `git grep -w bashify` across every `bashified` branch
in the ecosystem (six hits, all prose, no invocations), and the re-run was
`bashify check`. Both halves are scriptable; neither is scripted. The step
that most needs a machine is the caller search, because a changed promise
breaks a downstream pipeline silently and nothing currently looks.

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

**Exit codes it does not provoke.** Row 4 verifies that every code the tool
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
