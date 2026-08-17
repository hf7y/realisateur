---
scope: user
description: Halve a repo's prose by deleting the mechanisms that manufacture it, halve its foreign-owned mechanism, and close 75% of its issues by working them. Derived from the realisateur pass, 2026-08-17.
argument-hint: "<repo-name>"
---

Reap `$ARGUMENTS`. Three targets, measured before and after:

1. **Prose in half.**
2. **Foreign-owned mechanism in half** — deleted, or moved to its owner.
3. **75% of open issues closed** — by working them.

realisateur was the test case: **19,458 → 9,670 prose lines (50.3%)**, foreign
surface 23,954 → 19,944 with three moves routed, **50 of 66 issues closed**.
Everything below is what that pass actually needed, including the parts that
went wrong.

---

## 0. Measure first, and never quote a number you did not just produce

```sh
bash bin/markdown-cost.sh --census          # or the repo's copy; seed with --accept if absent
gh issue list -R hf7y/<repo> --state open --limit 500 --json number | jq length
bash bin/ownership-audit.sh                 # if the repo has an ownership ledger
```

Write the three numbers down. Every claim you make at the end is against them.

**If a guard is missing, that is a finding, not a reason to skip the step.**
Port it: `bash bin/port-markdown-cost.sh <repo> --dest <dir>`. It carries the
harness now; before 2026-08-17 it shipped a suite that died on
`summary: command not found`, so re-run the suite after porting rather than
assuming.

---

## 1. Cut the generators, not the output

**This is the step that makes the rest stick.** Prose in these repos is
manufactured, not chosen — `realisateur#321` measured **84 mandatory prose
lines per 180 lines of mechanism**, none of them lines anyone decided to write.
Reap without cutting what mandates the prose and it regrows by the next PR.

Zach, 2026-08-17: *"Do not establish new policies that will go stale. Delete
the old policy they would contradict instead."* **Add no guard, no convention
and no document.** Enforcement is whatever ratchet already exists.

Hunt these, in this order — they are ranked by what they yielded:

| look for | how to find it |
|---|---|
| a doctrine file's essay half | any `.md` over ~200 lines whose mechanism lives in a script |
| a checklist row that argues with itself | grep the checklist for parentheses over 3 lines |
| a spec for a check that no longer exists | grep the header's check names against the code that emits them |
| a guard demanding a *reason* per declaration | `grep -n "without a reason"` in the estate test |
| a ledger column nothing parses | read the consumer: `while read -r k v` means field 3+ is dead |
| prose that is load-bearing for code | grep for a script that `grep`s a `.md` |
| a nag aimed at repos you do not own | any per-item finding printed every run with no local fix |
| an instruction to write a retired surface | grep command files for the retired filenames |
| a mandate contradicted by a guard | run the guards, then read the doctrine that tells you to do the opposite |

**Two findings from realisateur that generalize, and both were invisible until
something broke:**

- `install-shims.sh` derived shim names by grepping backticked tokens out of
  `BUILD-DISCIPLINE.md`. `closeout-lint` was reachable only through **one
  sentence in an essay**, so reaping the essay would have silently uninstalled
  a working guard.
- `ownership-audit`'s READ-BY relation attached a foreign file if a recorded
  file *mentioned it in prose*. Trimming a header **detached** a suite and the
  audit reported it as newly parked — a regression caused by editing a comment.

> **Prose must never be load-bearing.** When you find prose holding up
> mechanism, fix it structurally — an explicit list, a name-shape rule — before
> you reap anything near it. Otherwise your reap silently deletes function.

---

## 2. Reap what is left

Destination rule, per paragraph: **premise still holds → stays beside the
mechanism, with a runnable witness. Held at the time → the vault. Expired and
defending a mechanism → a deletion flag, not a relocation.**

Header shape that survives:

```sh
#!/usr/bin/env bash
# name.sh -- the one-line claim.
#
# RUNNER: ...        <- machine-read; never cut
# GUARD-TEST: ...
# GATE: ...
# TRAP: the condition that would trip someone editing this, with the
#   command that reproduces it.
```

For interior comments, relocate rather than delete: keep the first 4–5 lines
with a pointer to the vault page. **Never touch a block containing `TRAP`,
`NEVER`, `MUST NOT` or `DO NOT`.**

Consign narrative to `hf7y/ecosystem1-vault` under `<project>/`, and **push** —
an unpushed deposit is not deposited. Then repoint every citation at
`vault:<project>/<doc>.md` rather than leaving it dangling, and re-grep.

**Before deleting a doc, check whether anything READS it** — as opposed to
citing it. In realisateur, 32 of `MONKEY.md`'s 40 referrers were prose; exactly
one file opened a doc for content.

---

## 3. Close 75% of the issues by working them

Zach, 2026-08-17: *"Closing wrong-repo issues or other valid issues without
working them yourself and either merging them or routing them to an owner who
can merge them is a fail."*

Five dispositions. Only three close an issue without doing its work, and those
three are legitimate:

- **Worked** — the fix merges. Close citing the commit and a witness.
- **Routed** — the fix belongs to another repo: clone it, write the diff, open
  a **draft** PR there, and open a **stamped** issue asking that repo's
  self-dev to validate, ready and merge. Leave it draft; you do not own it.
- **Verified done** — re-probe and close with the probe output, not the body's
  claim.
- **Superseded / stale** — name the commit or issue that overtook it.
- **Aggregated** — fold into an umbrella. **Write the umbrella's index first**,
  restating the measurements so it stands alone, then close into it.

**Re-probe before believing any issue, including your own plan.** In
realisateur, three planned closures were wrong: `#285` was going to be closed
as superseded and CI turned out to exist in 5 of 12 repos, not 12; `#280`'s
plan said `rm` a symlink that turned out to be the only thing putting a working
command on Zach's PATH; `#125` was going to have its check deleted when the
issue itself said the check was worth keeping.

**If you cannot make the change, do not close the issue.** Post the
measurement and say what blocked you.

---

## 4. Halve the foreign surface

For each foreign block, in order of size:

1. Does the owner repo **exist**? If not, that is the finding — file it as a
   decision (create the repo, or retire the mechanism) and stop.
2. `check-project-busy <project>`; defer on `BUSY`.
3. Draft PR carrying the files, their suites and their workflows, with a body
   saying what moved, why the owner's mission covers it, and what the receiving
   repo must wire.
4. Stamped issue asking their self-dev to validate, ready, merge.
5. **Delete on your side only after the receiving PR merges.** A draft is not a
   delivery. Do not `--accept` the ownership ratchet on a promise.

---

## 5. Land it

`main` is protected everywhere: branch, PR, green checks. `git commit -F
<dated-file>` for anything multi-line. Never `git add -A`. A dirty tree at exit
is a failed run.

Expect the reap's own PR to fail the prose guard — a diff that deletes 6,728
comment lines and adds 541 scores 74% comments. If the comment check has no
reap exemption, that guard is taxing the behaviour it exists to produce: give
it one (count deletions **only** for the reap comparison, never in the ratio)
rather than working around it.

Then `--accept` every ratchet that improved. It refuses to raise, so it is a
one-way lock at what you actually achieved.

---

## 6. Report

Three before/after numbers, the list of generators deleted, and — separately —
**what you could not do and why**. A reap that reports only what it cut is
hiding the half a reader needs.
