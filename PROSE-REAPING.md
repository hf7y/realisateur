# PROSE-REAPING.md — where a paragraph lives

Established 2026-08-06 (Zach): *"projects are prose-bloated which leads to
inefficiency and confusion among agents. The new paradigm is github issues for
mundane text."* `/reap` is the pass; this is the criterion it applies.

## 1. The criterion

Paragraph by paragraph: **does this describe a premise that STILL HOLDS?**

| Answer | Destination |
|---|---|
| Holds, and breaking it breaks something | **Stays in the repo**, beside the thing it protects |
| Held *at the time* — explains why a past decision was right | **The vault** |
| **Expired**, and the paragraph exists to *defend a mechanism* | **Flag the mechanism for deletion.** Do not relocate the paragraph |

Row three is what makes this more than tidying: a long justification for a knob
is *evidence about the knob*, and vaulting it launders dead config into a
cleaner-looking file while the knob survives. Reaping **flags** a mechanism; it
does not delete it. Prefer a **runnable witness** over a paragraph asserting the
same. And when the ratchet flags +N, **the answer is always reap** (Zach,
2026-09-07): a large baseline is itself the evidence that N lines of junk exist.

## 2. The three destinations

**The repo** — mechanical traps and live invariants only: would an agent
editing this file cause *mechanical* damage without this paragraph, and can the
claim be re-derived from the code **today**?

**A document may name a VERB, never a script path, flag, or guard's job** (Zach,
2026-08-23; #579). A verb's `--help` is its own source; the others go stale the
moment the mechanism moves, and 24 had. **Deleting the sentence is the fix** —
do not repoint it, and do not build a detector, itself a mechanism to describe.

**The vault** — narrative, post-mortems, superseded decisions. The private
`hf7y/ecosystem1-vault` remote **is** the vault (#212). Commit **and push**; an
unpushed deposit is not deposited. `man consigne` owns the resolution order,
and CLAUDE.md owns the read ban that `hooks/pretooluse-path-guard.sh` enforces.
A reaping pass deposits and then deletes the claim with its pointer (#741); it
never repoints and never writes a new citation.

**GitHub issues** — the work. One actionable item, one issue, in its own repo.

## 3. Reap *into issues*, not only into the vault

Backlog that lives as prose cannot be counted — a scheduler cannot pace against
it and a human cannot see it growing, so a pass that vaults everything **makes
the problem worse while looking like progress**.

> **Vault gets narrative. Issues get work.**

- **An issue title is a countable unit; a bullet in a file is not.** The point
  is arithmetic, not tidiness.
- **Zach answers question-issues by commenting and leaving them open.** State
  carries no signal. `etiquette` prints the grammar and derives the label.
- **Before reaping into another project's repo, run `check-project-busy
  <project>`** — a direct file write needs the guard; a front-door write
  (`scheduler -i`, `notify-senechal`) carries its own regulator.

## 4. Branch doctrine

Self-dev commits land on one branch name ecosystem-wide, `main` today.
`SELFDEV_BRANCH` retargets it from one place — **do not special-case a project
by editing a script**. The name is rarely the real problem: `vim-arcade` was
already on `main` and still could not converge, because a read-only deploy key
(`scheduler#38`) turns every local commit into a permanent unpushed warning.
Ask both questions — is it on the agreed branch, and can that branch reach its
remote?
