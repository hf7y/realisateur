# PROSE-REAPING.md — where a paragraph lives

**Established 2026-08-06**, from Zach's reply of that date:

> Reaping of prose and logs is good. […] My hunch is that projects are
> prose-bloated which leads to inefficiency and confusion among agents. The new
> paradigm is github issues for mundane text, mostly stable FOCUS.md and claude
> materials, with only occasional paradigm updates propagated top down.

## 1. The criterion

Applied paragraph by paragraph. One question:

> **Does this paragraph describe a premise that STILL HOLDS?**

| Answer | Destination |
|---|---|
| Holds, and breaking it breaks something | **Stays in the repo**, beside the thing it protects |
| Held *at the time* — explains why a past decision was right | **The vault** |
| **Expired**, and the paragraph exists to *defend a mechanism* | **Flag the mechanism for deletion.** Do not relocate the paragraph |

The third row is what makes this more than tidying. A long justification for a
knob is *evidence about the knob*. If its premise has expired, moving that
justification to the vault launders dead config into a cleaner-looking file and
the knob survives.

**Reaping flags a mechanism; it does not delete it.** Removing a field, script
or config is a separate change with its own review. Conflating the two is how a
documentation pass silently becomes a behaviour change.

**Verify before you preserve.** A trap paragraph earns its place only if the
trap is still live in the code. Re-probe it; do not carry it forward on the old
header's authority. Prefer a **runnable witness** — three lines the reader can
paste, with the observed output — over a paragraph asserting the same. Prose
decays; a command re-derives.

## 2. The three destinations

**In the repo** — mechanical traps and live invariants. Keep only what a reader
must know *not to break it*. The test: would an agent editing this file cause
*mechanical* damage without this paragraph, and can the claim be re-derived
from the code **today**? If yes, it stays beside the thing it protects.

**The vault** — narrative, post-mortems, superseded decisions. Everything that
answers *"why did this end up this way?"* rather than *"what will break if I
touch it?"*

The private `hf7y/ecosystem1-vault` remote **is** the vault (Zach-directed,
2026-08-12, reversing "do not push"; #212). Commit **and push** — an unpushed
deposit is not deposited. A local clone is only a cache, resolved in this order
by `consigne`, `fonde` and `fauche`, which share one variable deliberately so a
caller pointing one door somewhere cannot leave another pointing elsewhere:

    --vault <path>          highest precedence, per invocation
    $BIBLIOTHECAIRE_VAULT   one variable, shared across all three
    /srv/ecosystem1-vault   the default

**The `vault:` notation.** `vault:<project>/<file>` names a path inside the
**remote**, never one on disk — mandark holds no clone and
`/srv/ecosystem1-vault` exists only on monkey, so a citation assuming either is
dangling for most readers. Resolve with
`gh api repos/hf7y/ecosystem1-vault/contents/<path>`. **This is the only
definition**; hf7y/ecosim#73 read these as pointing at a file that "does not
exist anywhere on disk", which was true of the disk and of the notation being
undefined, not of the deposit.

**GitHub issues** — the work. One actionable item, one issue, in that
project's repo.

## 3. Reap *into issues*, not only into the vault

**Backlog that lives as prose cannot be counted.** A scheduler cannot pace
against it, a report cannot size it, and a human cannot see whether it is
growing. So a pass that moves everything to the vault **makes the problem worse
while looking like progress**: the repo gets clean, the vault gets fat, and the
backlog is exactly as uncountable as before.

> **Vault gets narrative. Issues get work.**

| The paragraph… | Becomes |
|---|---|
| explains why a past decision was made | a vault section |
| describes something that should be done | **a GitHub issue** |
| does both | an issue, plus a vault section it links to |
| defends a mechanism whose premise expired | a **deletion flag** in the report |
| protects a live mechanical trap | stays in the repo, with a runnable witness |

- **An issue title is a countable unit; a bullet in a file is not.** The point
  of the conversion is arithmetic, not tidiness.
- **Zach answers question-issues by commenting and leaving them open.** State
  and labels carry no signal. Stated once in `SCHEDULER.md`; do not retype it.
- **Before reaping into another project's repo, run `check-project-busy
  <project>`.** A front-door write (`scheduler -i`, `notify-senechal`) carries
  its own regulator and does not need the guard; a direct file write does.

## 4. Branch doctrine

All self-dev commits land on **one branch name across the whole ecosystem,
`main` today**. `SELFDEV_BRANCH` is read from one place and retargets the
convention ecosystem-wide — **do not special-case a project by editing a
script**, which is BUILD-DISCIPLINE.md's "config read from one source" row.

The branch *name* is rarely the real problem. `vim-arcade` was already on
`main` and still could not converge, because a **read-only deploy key**
(`scheduler#38`) turns every local commit into a permanent unpushed warning. So
ask both questions: is it on the agreed branch, and can that branch actually
reach its remote?

## 5. Doing a pass

1. `check-project-busy <project>` if the repo is not your own. Defer on `BUSY`.
2. Work on a **branch off `main`**. Never `git add -A`; stage only named files.
   **Not a worktree** — `bin/no-worktree-lint.sh` mechanizes Zach's 2026-08-06
   instruction that no more worktrees be created, and this file told you to
   make one until 2026-08-17. A doctrine that cannot be followed without
   failing a guard is itself the thing this document is about.
3. Read the file whole. Classify **each paragraph** by §1's question.
4. **Re-derive every trap you intend to preserve** against the code. Put the
   witness command in the file.
5. Convert every actionable paragraph to a **GitHub issue** (§3). Count them;
   the count is part of the report.
6. Deposit the narrative in the vault under `<project>/`, then **commit and
   push**, under `consigne lock` when a local clone is shared — the vault is
   one checkout with thirteen writers and nothing else serializes them
   (`#213`).
7. Verify **behaviour is unchanged**: for a config file, a byte-identical
   preview from whatever consumes it, plus its witness tests.
8. Report the before/after count from `bin/markdown-cost.sh --census`, and
   **the list of expired-premise paragraphs with the mechanism each was
   defending**. That list is a deliverable, not a footnote.

**The generators matter more than the output.** Cutting prose without cutting
what mandates it means the ratchet gets paid rather than obeyed — `#321`
measured 84 mandatory prose lines per 180 lines of mechanism. Before trimming a
header, ask what *required* it: a guard demanding a reason, a ledger demanding
a rationale column, a derivation that reads prose and so makes prose
load-bearing. Delete that first.

`git commit -F <file>` for anything multi-line; a dirty tree at exit is a
failed run.
