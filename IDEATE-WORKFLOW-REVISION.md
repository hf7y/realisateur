# /ideate workflow: what's wrong, what changed, what's still open

Written 2026-07-24 in response to a dropped inbox note (`revise-the-
ideate-workflow-or-20260724-221900.idea`) asking for exactly this: a
visible `.md` summary of the issue, plus questions/blockers raised where
real. Source note archived unchanged in `archive/` once this was folded
in.

## The complaint, verbatim

> revise the ideate workflow, or help me out. I keep stating in prompts
> that I want to move from big vision, to milestones, to blockers, but
> that should just be part of ideate boilerplate. Also, ideate seems to
> only run once, like a command on a prompt. It doesn't load up an
> interactive session that adheres to ideate principles. we seem to
> drift from ideate over time rather than do the ideate goal of stay
> focused on roadmapping not building. hard to enforce with prose I
> guess. give me a .md summary of this issue somewhere I can see it, and
> raise questions/blockers as appropriate

Three distinct problems bundled together. Taking each in turn.

## 1. Vision → milestones → blockers should be boilerplate, not restated per-prompt

**Real and fixable with prose.** Looking back at actual `/ideate`
entries in `.claude/FOCUS.md`, the shape Zach keeps asking for by hand
already exists as an ad hoc pattern — the 2026-07-24 dexter pass
(vision → milestone chain → blockers-clearable-now, three clean
subsections) is the best example, but it happened because Zach's own
prompt that session spelled out the structure, not because `ideate.md`
asked for it as a matter of course.

**Fixed this pass:** `ideate.md` §4 now has a named "Standard entry
shape" subsection making Vision → Milestone chain → Blockers the default
template for any `/ideate` FOCUS.md entry recording a real direction (not
just a one-line decision) — modeled directly on the dexter entry so the
next session has a concrete example to follow, not just a rule.

## 2. "/ideate only runs once" — it's a single-shot slash command, and that's mostly real

This is a genuine limitation, not a documentation gap. A Claude Code
slash command is a one-shot prompt injection at invocation time — it has
no persistent "mode" the harness enforces across the rest of a
conversation. Once `/ideate` finishes its turn, nothing stops a
follow-up prompt in the same conversation from drifting into build-mode,
because there's no standing state saying "we're still in an ideate
session."

**Partially fixed this pass (prose-level):** added an explicit
instruction at the top of `ideate.md` — the posture (surface/ask/record/
queue, not build) holds for the rest of *that conversation*, not just
the first response, until the user clearly redirects. This is the same
class of fix as problem 1: it makes the existing prose do more work, but
it's still prose — a sufficiently long or distracted conversation can
still drift past it, which is exactly problem 3.

**Genuinely open, not built this pass:** a harder guarantee would mean
either (a) a `UserPromptSubmit` hook that re-injects an "you're still in
ideate mode" reminder on every turn after `/ideate` fires, or (b) some
other session-state mechanism the harness itself provides. (a) is
buildable (project-local `.claude/settings.json`, scoped to this repo)
but it's an infrastructure change to how *every* prompt in a realisateur
session behaves, not a markdown edit — worth Zach's own sign-off before
building rather than shipping unprompted. Raised as a real question in
`.claude/QUESTIONS.md`.

## 3. Drift over long sessions — "hard to enforce with prose I guess"

Same root cause as problem 2, and Zach's own instinct in the complaint
is correct: prose alone caps out. The boilerplate template (problem 1)
and the "stays in effect for the whole conversation" instruction
(problem 2) both raise the ceiling — a clearer, more repeatable
structure is easier for a model to stay anchored to over a long session
than loose prose was. But neither is a hard guarantee. The hook-based
mechanism from problem 2 is the actual candidate fix for problem 3 too
(same mechanism, same open question) — there isn't a second, separate
solution to build here beyond what's already queued.

## What's done vs. queued

- **Done, this pass:** `ideate.md` §4 standard entry shape (vision →
  milestones → blockers boilerplate); `ideate.md` top-of-file "stays in
  effect for the whole conversation" instruction; this summary doc;
  source artifact archived.
- **Queued, needs Zach's own call:** whether to build a
  `UserPromptSubmit` hook (or equivalent) that actively re-enforces
  ideate-mode across a long conversation, rather than relying on prose
  holding. See the dated question in `.claude/QUESTIONS.md`.
