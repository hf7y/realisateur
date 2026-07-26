# realisateur

Zach drops ideas into this folder in a chaotic, unstructured way — a quick
echoed note, a screenshot, a half-formed thought in a text file. No fixed
format, no naming convention.

realisateur's job is to notice what's been dropped, infer the idea behind
it, and turn it into a real, scaffolded project wired into the rest of the
development ecosystem — most importantly, registered with
`~/Documents/Project Archive/scheduler` (see `SCHEDULER.md`) so it can keep
developing itself unattended, the same way realisateur itself now does.

## How it works

1. **Inbox**: raw dropped artifacts land at the repo root (or wherever
   Zach puts them) — text files, PNGs, whatever. Nothing about their name
   or shape is guaranteed.
2. **Inference**: read/view each artifact and figure out what idea it's
   pointing at. When it's ambiguous, pick the most reasonable
   interpretation and act — see `.scheduler/FOCUS.md`'s autonomy policy.
3. **Wiring**: turn a viable idea into its own project — a real directory
   (usually a sibling under `~/Documents/Projects/`), a git repo, and a
   scheduler registration of its own if it's the kind of thing that
   benefits from an unattended nightly loop (most agent/codebase projects
   are).
4. **Archive**: once an artifact has been acted on (a project scaffolded,
   or a decision made not to), move it out of the inbox so the next run
   doesn't re-process it — see `.claude/commands/nightly-batch.md` for the
   exact convention.

## This project's own scheduler registration

realisateur is itself registered as a Tier 2 (nightly batch) participant
— see `schedule/realisateur.conf` in the scheduler repo. Its nightly run
is what actually processes the inbox and wires up new projects; there is
no separate daemon or watcher.
