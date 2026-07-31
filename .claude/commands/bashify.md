---
scope: user
description: Bashify a project -- survey what it does, coin its verbs, write the man page that IS its contract, and wire the utility from the inside. Reaps agentic activity into documentation.
argument-hint: "[project-name] [verb]"
---

**bashify** is the verb of `basheur`. To bashify a thing is to state what
it does as a contract a shell can hold, so that the agent standing in for
it becomes unnecessary.

This is an **eschatological** command, and that is not decoration -- it
sets what "done" means. `/bashify` reaps agentic activity out of a project
and suspends it in documentation. The agent that used to run inside the
project does not survive the pass. What survives is the man page, and the
utility that page describes. The agency is not destroyed; it is **moved**:
reborn on a dexter VM, with a different purpose, no longer welded to this
repo.

Standing placement facts this command assumes (2026-07-30, Zach-directed):
- **mandark is no longer a dev box.** Personal agents only. Do not queue
  agentic dev work onto it, and do not build anything whose steady state
  requires it.
- **dexter VMs host agentic activity.** One of them is research.
- **Prose goes to `bibliothecaire`.** A bashified project keeps its man
  page, its contract, its test, and its `GAPS.md` -- nothing else. Every
  other document is research material and belongs in bibliothecaire, where
  Obsidian's linking is what integrates it. Prose left in a bashified repo
  is unreaped agency.

A verb, once coined with a definition, exists. Speaking it manifests it.
That is the whole mechanism: **the man page is written before the tool
works**, and the tool is then forced to become true to it.

---

## 0. Scope from `$ARGUMENTS`

- **`/bashify <project>`** -- run the full pass against that project.
- **`/bashify <project> <verb>`** -- work one existing verb: check it
  against its man page, close gaps, extend the page.
- **no argument** -- bashify the repo you are in, if it is a real project;
  otherwise say so and stop rather than guessing.

Read first, always offline:
- `/home/zach/Documents/Projects/basheur/DOCTRINE.md` -- the four laws.
- `/home/zach/Documents/Projects/realisateur/BASHIFY-REPORT-20260730.md`
  -- what the first worldwide pass actually found, including the
  headline finding it had to withdraw.
- `/home/zach/Documents/Projects/realisateur/RESEARCH-VERB-ECOSYSTEM-20260730.md`
  -- why one project gets **several small verbs**, not one large one.
- `basheur list` and `basheur status` -- existing contracts and the
  de-animation ratio.

Do not trust a prior session's count of anything. A headline quantity is
re-derived before it is acted on -- that rule has been earned four times
in this repo, most recently by the "ten of nineteen have no entry point"
finding, which was wrong and was caught by the instrument built to
consume it.

## 1. Survey -- what does this project actually do?

Read the repo and answer, in writing, one question: **what can a human ask
this project for?** Not what its code is organised into -- what a caller
would want out of it.

- Discover real entry points across **all** languages and **all**
  directories. Globbing `bin|scripts|tools` for `*.sh` is the known-bad
  pass: it found 3 of senechal's 23 scripts, and it miscounted Python and
  Node argv entry points as "no entry point at all". A project whose front
  door is `argparse` is already mechanized; what it lacks is a verb
  surface, which is a much smaller job -- say which of the two you found.
- Cluster the capabilities **by domain a caller would name**, not by
  directory. The seams are real: `crt` is a voice loop, a book-game
  funnel, and a deploy surface; those are three verbs, not 98
  subcommands under one.
- Name what the project does that is **not mechanizable yet** -- that is
  the residue of genuine agency, and it becomes exit 3 (`needs-summon`),
  not a silent omission.

## 2. Coin the verbs

The naming rule, ecosystem-wide: **French noun = animate** (a project, an
agent). **French imperative verb = inanimate** (a tool). The part of
speech alone tells a reader whether the thing they are invoking has
agency. Coining a verb is therefore a claim that the thing is *dead* --
which is the point of this command.

Hard constraints:
- **Pure ASCII.** `répartis` is unusable at a prompt. Rule out accents.
- **Unclaimed on `PATH`** -- check with `command -v` before assigning, on
  this host, now.
- **One domain per verb.** If you cannot write the NAME line of the man
  page in one clause without "and", it is two verbs.

## 3. Write the man page -- this is the deliverable

`man/<verb>.1`, written **before** the tool is complete. The page is not
documentation of the tool; the tool is an attempt to satisfy the page.

Required sections: NAME, SYNOPSIS, DESCRIPTION, OPTIONS, EXIT STATUS,
EXAMPLES, FILES (if it touches any), SEE ALSO.

**Exit codes are standardized ecosystem-wide** and live in exactly one
place, `bashify/skel/lib/verb.sh`. Do not invent a dialect:

| code | meaning |
|---|---|
| 0 | kept -- the contract was satisfied |
| 2 | usage error -- the caller is wrong |
| 3 | needs-summon -- only an agent can do this yet |
| 4 | gap -- the tooling does not exist yet |
| 5 | broken -- the tool exists and failed |
| 6 | blind -- it could not see what it needed to judge |

A project-specific code is allowed **above 6**, documented in EXIT STATUS,
never a redefinition of one of these.

**Default to unix synonyms.** A caller should be able to guess this tool.
Where a standard behavior exists, adopt its name and its shape rather than
a novel one: `-h/--help`, `--version`, `-n/--dry-run`, `-q/--quiet`,
`-v/--verbose`, `-f/--force`, `--json`, `-` for stdin, `--` to end flags.
Results to stdout, commentary to stderr, quiet by default, line-oriented
so the next tool in the pipe needs no parser. If you document `--json` or
`--quiet`, they must be **honored** -- the shared runtime currently parses
both and nothing consumes them, which is the exit-0 no-op wearing a flag.
Either wire it or leave it off the page.

**The cost boundary is `--summon`, long form only.** `-s` collides and
`-S` is one shift key away from it, which is unacceptable for the only
flag that spends real money. A utility that cannot spend does not carry
the flag at all -- so `--help` alone answers "can this cost me anything?"

## 4. The man page test -- what makes a man page *successful*

A man page is a **contract**, so it is testable, and a page that cannot be
tested has not been written yet. A page passes when a competent stranger
with no access to the repo can predict the tool's behavior from the page
alone, **and every prediction is machine-checkable**. These nine rows are
that test. Score them explicitly; a page is not done until every row
passes or its failure is written into `GAPS.md`.

1. **NAME is one clause.** `<verb> - <imperative, one domain>`. An "and"
   in the NAME line fails the row and means step 2 was done wrong.
2. **SYNOPSIS is copy-pasteable.** Every form shown runs as written. Not
   "would run" -- run each one.
3. **Surface is bidirectional.** Every flag and subcommand on the page
   exists; every flag and subcommand that exists is on the page. An
   undocumented surface fails this row as hard as a documented ghost.
4. **EXIT STATUS is complete and reachable.** Every code the page lists
   can be provoked by some invocation; every code the tool can return is
   listed. Provoke them.
5. **EXAMPLES are doctests.** Each example is executed and its stated
   output matches. An example that is illustrative rather than real is a
   lie with a shell prompt in front of it.
6. **Cost is answerable from the page alone.** Either `--summon` is
   documented with what it spends on, or the page states the tool cannot
   spend. Silence fails.
7. **Lineage is named.** SEE ALSO names the standard tool(s) this one
   behaves like, so a reader can transfer expectations instead of
   learning a dialect.
8. **No vendor, no agent names, anywhere.** Not in the page, not in
   examples, not in paths. This is mechanized as a `grep` over the whole
   tree that must come back empty -- and it has already caught real
   leaks, including generated prose *explaining* that there is no agent
   here, which is itself a trace.
9. **Present tense only.** The page documents what IS. Anything aspirational
   is not a sentence in the man page; it is a line in `GAPS.md` and an
   exit 4 at the call site.

The universal assertions in
`realisateur/bashify/skel/test/contract-test.sh` already mechanize part of
this (rows 3, 4, 6). It takes any command, so the *same* assertions run
against the legacy implementation and the new verb -- that is what makes
"the contract was kept" a measurement rather than a claim. Where a row
above is not yet mechanized, **say which**, and prefer building the check
over asserting the row by eye. A row verified by reading is a row that
will drift.

## 5. Wire it from the inside

The utility ships incomplete on purpose. Completion happens **through
use**: a caller invokes it, hits a path that is not built, and that call
site is where the agent is summoned.

- A path that is not built exits **4** with the reason on stderr. It never
  exits 0 quietly, and it never silently substitutes something else.
- `--summon` at that site calls an agent to produce the result *and* to
  leave **residue**: a durable shell script in `basheur/residue/` recording
  how the result was actually obtained.
- The dev stream's job is wiring residue into `impl/`, which moves the
  contract from `AGENT` to `MECHANIZED` and drops that call's token cost
  to zero. `basheur status` is the scoreboard, and it goes UP as the
  ecosystem gets *less* animated.

Never wrap a legacy script and call the verb done without saying so. A
subcommand that `exec`s the script it was discovered from is an honest
front door but not a rewrite -- report which subcommands are wrappers and
which are real, per project. The end state is self-contained.

## 6. Fulfilling the contract vs. modifying the contract

These are different acts with different gates, and conflating them is how
a contract stops meaning anything. State which one you are doing, every
time, in the commit message.

**Fulfilling** -- the page stays byte-identical; the implementation moves
toward it. No permission needed. This is the default and most work is
this. Success is measured by the step-4 rows going from fail to pass with
the page untouched.

**Modifying** -- the page changes, so the promise changes. This is not a
free action. It requires, mechanically:
1. **A stated reason** in the commit: what the tool learned that the page
   did not know.
2. **The old page preserved**, not overwritten in place -- `git` holds it,
   and the commit must name the change, so a reader can see the promise
   move.
3. **A re-run of the full step-4 test** against the new page. Changing the
   contract to match a broken implementation is the failure mode this gate
   exists to catch; if the only thing that changed is that the tool could
   not do it, that is exit 4 and a `GAPS.md` line, **not** a page edit.
4. **Callers checked.** If another verb pipes into this one, a changed
   promise breaks it silently. Grep for the verb name across bashified
   branches before committing.

That four-step gate is itself mechanical, which means **it can be
bashified** -- and should be. `bashify` modifying contracts is the same
operation as `bashify` modifying anything else, and it is the strongest
proof the verb is real: the tool that de-animates other projects submits
to its own contract. Until that check is a script, run the four steps by
hand and say in the report that you did, so the gap is visible.

## 7. Prose out, insight to bibliothecaire

Everything the survey turned up that is *not* the man page, the contract,
the test, or `GAPS.md` is research material. Move it to `bibliothecaire`
(`check-project-busy bibliothecaire` first; defer if BUSY) rather than
deleting it, and rather than leaving it in the bashified tree. Obsidian's
linking is what turns those notes into something integrable -- so write
them as linkable notes, not as a dump.

`vim-arcade` is becoming the universe this vocabulary lives in: a verb
coined here is a verb spoken there. Note new verbs in a form vim-arcade can
pick up rather than assuming it will re-derive them.

## 8. Branch, never main; and never extract

The pass emits a **`bashified` branch**, off the project's own default
branch, built in a `git worktree` so no human's working tree is ever
touched -- two projects were bashified while Zach had live sessions open
in both.

The purge is total *because* it is a branch: every removed thing is one
`git log <default-branch>` away in the same repository. **Extracting a
`bashified` branch into a standalone repo destroys the archive that makes
the purge safe**, and leaves defensive code standing with no visible
reason, which is how hard-won guards get deleted by the next reader. Every
README and man page says so; keep saying it.

## 9. Report

End with, explicitly:
- Verbs coined (with the `command -v` check that showed each unclaimed).
- The step-4 man page test **scored row by row**, per verb -- and which
  rows were checked by machine vs. by eye.
- Which subcommands are wrappers and which are real.
- Contracts moved `AGENT` → `MECHANIZED`, and the `basheur status` ratio
  before and after.
- Whether this pass **fulfilled** or **modified** any contract, naming
  each.
- What was moved to bibliothecaire, and what was deferred because it was
  BUSY.
- What is deliberately not done -- especially anything not wired to
  `PATH`, since wiring a verb into the machine is a **human decision** and
  a machine-wide config change: if you do wire one, run
  `notify-senechal '<what, where, who owns it>'`.

Never report a verb as working on the strength of an exit code alone. The
witness is a named test row or a human-sensible output -- that is
`BUILD-DISCIPLINE.md`, and this command is the one most able to violate it
quietly, because a tool that does nothing passes almost everything.
