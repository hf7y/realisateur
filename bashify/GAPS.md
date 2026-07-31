# GAPS — what `bashify` cannot yet do

Recorded 2026-07-30, when `man/bashify.1` was written. The page describes
four subcommands; one is backed by tooling. These gaps are written down so
the utility never pretends — every one of them exits 4 at the call site and
names itself on stderr. `bashify list` is the live scoreboard; this file is
the reason.

## `page` — writing a man page standalone

`bashify.sh` writes a man page *inline*, as part of `emit`, from a fixed
template. There is no way to write or rewrite a page for one verb against a
live command, which is what the page-first method actually needs: the page
comes first, the tool moves toward it, and the page is then extended as the
tool learns. Today extending a page means editing troff by hand.

## `check` — the nine-row page test

**This is the load-bearing gap.** The nine rows are stated in
`man/bashify.1` and in `/bashify`, and scored by hand. Rows 3, 4 and 6
(surface, exit status, cost boundary) are already mechanised by
`skel/test/contract-test.sh`, which takes any command. Rows 1, 2, 5, 7, 8, 9
are not:

| row | mechanised by |
|---|---|
| 1 NAME is one clause | nothing — read by eye |
| 2 SYNOPSIS forms run | nothing — each form run by hand |
| 3 surface bidirectional | `contract-test.sh` (partial: flags, not subcommands) |
| 4 exit codes reachable | `contract-test.sh` (partial: 0 and 2) |
| 5 EXAMPLES are doctests | nothing — run by hand, output compared by eye |
| 6 cost answerable | `contract-test.sh` |
| 7 lineage named | nothing |
| 8 purge | a `grep`, run by hand |
| 9 present tense | nothing |

A row verified by reading is a row that will drift, so every hand-checked
row above is a standing liability, not a completed check. Rows 2 and 5 are
the ones worth mechanising first: they are pure execution — parse the
`.nf` blocks out of the page, run them, diff the output — and they are the
rows that catch a page going stale silently.

Row 3 is only *partially* mechanised even where it is covered:
`contract-test.sh` asserts flag behaviour, not that every subcommand on the
page exists and every subcommand that exists is on the page. Closing that
means the checker parsing the page's SYNOPSIS, which is the same parser row
2 needs.

## `amend` — the contract-change gate

The four steps (stated reason, previous page preserved, full re-run of the
rows, callers searched) are run by hand and can therefore be skipped by
hand. The step that most needs a machine is the caller search: a changed
promise breaks a downstream pipeline silently, and nothing currently looks.

## `emit` has no doctest, deliberately

Every other subcommand appears in the page's EXAMPLES and is executed when
the page is scored. `emit` does not, because running it mutates another
project's repository — it deletes and recreates that project's `bashified`
branch. Its exit paths **are** provoked (arity, unregistered project,
claimed verb, malformed verb, and exit 5 via an empty scratch repository),
but the success path is not exercised by the page test. This is a declared
limit rather than a silence: a `--dry-run` for `emit` would close it, and
does not exist.

## `emit` still wraps rather than reimplements

`emit`'s subcommands `exec` the legacy scripts they were discovered from.
That is an honest front door over what exists, not a rewrite, and the
bashified verbs inherit whatever contract those scripts already kept —
including the ones that keep none.

## `BASHIFY_WORK` defaults to a dead scratch path

`bashify.sh` defaults its worktree directory to a scratch path belonging to
a session that has since ended. It still works, because the directory is
created on demand, but the default names a session rather than a purpose and
will accumulate. The default should be derived, not a literal.

## Standing gap: the cost baseline

No before-measurement exists for what these passes replaced, so the saving
is **unmeasured — not zero, and not assumed**. `bashify` itself spends
nothing, so it produces no after-number either. Closing this needs a real
measurement of a real summon, not an estimate.
