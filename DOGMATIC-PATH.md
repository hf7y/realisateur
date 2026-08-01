# THE DOGMATIC PATH

*A prompt prefix that pushes an agent through the front door instead of
around it. Written 2026-08-01, from a session that went around it.*

## The template

```
DOGMATIC PATH. Before you do the task, do this, and report it:

1. INVENTORY THE FRONT DOOR FIRST. List the tools that already claim
   this job — for this ecosystem: `bashify list`, `basheur list`,
   `basheur status`, `command -v <verb>`, and the repo's own bin/ and
   lib/. Name which subcommand or script owns each step of what I asked
   for. Do this BEFORE writing anything, including tests.

2. A MECHANIZED GATE IS NOT OPTIONAL. If a check, gate, or generator
   already exists and is free, you RUN IT. You may not hand-run its
   steps, re-implement it, or write "a quick check" beside it. If you
   catch yourself writing a verifier, stop: first prove no existing one
   covers it, by running the existing one and showing its output.

3. DOCUMENTED ESCAPE HATCHES EXPIRE. Prose that says "until X is a
   script, do it by hand" is a claim about the past. Re-probe whether
   X is a script NOW. Do not quote a doc's permission without checking
   it still holds.

4. "NOT MECHANIZABLE" IS A MEASUREMENT, NOT AN OPINION. Before
   declaring any check unautomatable or UNCHECKED, grep the existing
   tooling for it. Something already decides more than you think.

5. VERIFY WITH THEIR INSTRUMENT, NOT YOURS. A pass from a harness you
   wrote this session is not evidence. Report the exit code of the
   ecosystem's own gate. If it refuses, that is the answer — do not
   route around it, and do not edit the artifact to satisfy your own
   checker instead.

6. IF THE FRONT DOOR REFUSES, STOP AND SAY SO. A refusal is a finding
   to report, not an obstacle to work around. State what refused, its
   exit code, and what it objected to. Ask before overriding.

Report at the end: which front-door commands you ran, their exit codes,
and anything you built that duplicates something that already existed.
```

## Why each clause exists

Every clause is a specific failure from the `/bashify vim-arcade` pass on
2026-08-01, not a general virtue. Recorded with the evidence so the
template is falsifiable rather than exhortation.

| clause | what actually happened |
|---|---|
| 1 | `bashify list` was never run. It reports `amend` as **MECHANIZED** in about a second, which would have ended the whole error. |
| 2 | `test/page-test.sh` was written beside the existing `check` / `amend`, and committed to two branches (ecosim `a74dc68`, vim-arcade `653400a`) doing the same job worse. |
| 3 | `/bashify` §6 says "Until that check is a script, run the four steps by hand and say in the report that you did." That was quoted as permission. `bashify/lib/amend.sh` had existed since 2026-07-31 19:20. |
| 4 | Row 9 (present tense) was reported `UNCHECKED` with the claim it was "not decidable by this script". `amend.sh` has a `TENSE` gate that decides it. |
| 5 | The hand-run gate reported **all four passing**. `bashify amend` on the same page exits **7 — amendment REFUSED**. |

## What the mechanized gate caught that the hand-rolled one did not

Run retroactively against the page that had already been committed:

- `--help` offers `--quiet` and `--version`, neither documented on the
  page. The hand-rolled check compared **subcommands only, never flags**.
- The tool lists a subcommand the SYNOPSIS does not name. The hand-rolled
  parser read `case` arms and could not see it.
- Aspirational sentences in a contract — the tense row that had been
  declared unmechanizable.

## The honest limit of this document

**This is prose, and prose decays — which is the thing this ecosystem
keeps concluding.** A prompt prefix is a suggestion an agent may forget by
turn forty; the same session that wrote this template had read the rule it
violated, in the very command it was executing.

The mechanical form of clause 2 is a commit hook that refuses a commit
touching `man/*.1` unless `bashify amend` passed. Until that exists, this
file is a stopgap, and should be described as one.

The deeper finding underneath all six clauses: **the front door is
optional, and an optional front door is a suggestion.** `bashify amend`
documents its own restraint — "It does NOT perform the edit" — which is
correct for a gate, but means something else must invoke it, and nothing
does. Four of `bashify`'s five subcommands exist and three are free; what
does not exist is anything that makes the sequence unavoidable.
