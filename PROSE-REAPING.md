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

The third row is what makes this more than tidying. A long justification for a
knob is *evidence about the knob*; moving it to the vault launders dead config
into a cleaner-looking file and the knob survives.

**Reaping flags a mechanism; it does not delete it** — that is a separate
change with its own review. **Verify before you preserve:** a trap paragraph
earns its place only if the trap is still live. Prefer a **runnable witness**
— three lines the reader can paste — over a paragraph asserting the same.

## 2. The three destinations

**The repo** — mechanical traps and live invariants only: would an agent
editing this file cause *mechanical* damage without this paragraph, and can the
claim be re-derived from the code **today**?

**The vault** — narrative, post-mortems, superseded decisions. The private
`hf7y/ecosystem1-vault` remote **is** the vault (#212). Commit **and push**; an
unpushed deposit is not deposited. `man consigne` owns the resolution order.

**Never resolve a `vault:` pointer** (Zach, 2026-08-29; #742, #762). CLAUDE.md
defines the notation. Everything in the vault is there because §1 ruled it
non-current, so following a pointer re-imports a premise that was retired — and
the how-to that stood here was the invitation. Establish the fact from live
code, config or API, else say UNVERIFIED and act on nothing.
`hooks/pretooluse-path-guard.sh` refuses both routes. Depositing is unaffected,
and a **new** citation is never written: a reaping pass deposits and then
deletes the claim with its pointer (#741), it does not repoint.

**GitHub issues** — the work. One actionable item, one issue, in its own repo.

## 3. Reap *into issues*, not only into the vault

**Backlog that lives as prose cannot be counted** — a scheduler cannot pace
against it and a human cannot see it growing. A pass that moves everything to
the vault **makes the problem worse while looking like progress**.

> **Vault gets narrative. Issues get work.**

The destination table is §1's and is not restated here. Note only what the read
ban changes: a paragraph that both explains a past decision and names work
becomes an issue **and** a deposit, never an issue that cites the deposit.

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
by editing a script**. The branch *name* is rarely the real problem:
`vim-arcade` was already on `main` and still could not converge, because a
read-only deploy key (`scheduler#38`) turns every local commit into a permanent
unpushed warning. Ask both questions — is it on the agreed branch, and can that
branch reach its remote?
