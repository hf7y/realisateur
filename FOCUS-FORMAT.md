# FOCUS.md formatting spec

Canonical shape for `.scheduler/FOCUS.md` (the standard location since
the 2026-07-26 migration decision; legacy `.claude/FOCUS.md` only for
projects not yet migrated) so `scheduler status
<project>`'s `extract_next_items()` (`bin/scheduler` in the scheduler
repo) can actually parse a "next up" list out of it, and so
`bin/milestone-audit.sh`/`bin/ecosystem-survey.sh` here can too. Written
2026-07-24 (nightly-batch) after `FOCUS-md-formatting-compliance-*.idea`
flagged chezz and wtul as unparseable — this is the spec both existing
scaffolds should be reconciled against and new scaffolds should already
satisfy by construction.

## What the parser actually requires

`extract_next_items()` is a heuristic awk pass, not a real parser:

1. It skips anything inside an HTML comment (`<!-- ... -->`) entirely —
   design notes, standing rules, and rationale are fine to keep in
   comments, but nothing inside one will ever surface as a "next up"
   item.
2. It looks for a markdown heading (`#`+) whose text contains (case-
   insensitive) one of: `current focus`, `priority queue`, `priority`,
   `backlog`.
3. Once inside that heading's scope, it collects **top-level** lines
   starting with `- ` or `N. ` (no more than one leading space of
   indent — nested sub-bullets are deliberately skipped so this stays a
   short list, not a dump).
4. It stops at 12 collected items and displays at most 8.

## The spec

- Have at least one real (non-commented) heading matching `## Current
  focus`, `## Priority queue`, `## Priority`, or `## Backlog`.
- Under it, a flat top-level bullet or numbered list — one line per
  item, present tense, short enough to read in a glance (the display
  path truncates at 110 characters and shows at most 8).
- Prose/HTML-comment design notes, rationale, and standing rules are
  fine and encouraged *around* that list — they just can't be the ONLY
  content, and the list itself can't live inside a comment block.
- A project whose real backlog lives in a different file (e.g. wtul's
  `ROADMAP.md`) should still carry a thin `FOCUS.md` with a `## Current
  focus` or `## Priority queue` heading and a real top-level list —
  either the actual current items copied in, or (if the other file is
  kept as the single source of truth to avoid drift) a short curated
  subset with a note that the full detail lives elsewhere.
- Newly scaffolded projects (groc-mangr, gardien, senechal, etc.)
  already comply by construction — this spec formalizes what they
  already do, it doesn't change their shape.

## Non-goals

This does not mandate a bug/feature/priority *tag* schema per item —
that's the separate, still-open "real priority/bug-feature tagging
needs a schema decision" note in `bin/scheduler`'s own comment (FOCUS.md
2026-07-22 backlog note). This spec only fixes parseability of a flat
next-up list; per-item tagging is a later, still-undesigned pass.
