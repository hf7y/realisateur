# scheduler — the engine

Coordinates autonomous `claude -p` jobs across every registered project on plain
cron. Not a daemon. Shared engine + config registry + report aggregator.
**Moved out of "Project Archive"** — the ecosystem's most active repo now lives
where active things live.

## What's different in the fable version

1. **`bin/liveness-audit.sh` exists and is cron-wired** — the guard whose absence
   let aedile/vkv-inventory go dark for 4 days. See the script; it's real bash.
2. **The wrapper zoo is retired, not layered.** Today ~20 per-project
   `~/.local/bin/<name>-nightly-batch-loop.sh` scripts coexist with the generic
   `bin/scheduler-run <project> <tier>`. Here, every `_paced.conf` line uses
   `scheduler-run`; MIGRATION.md's job is finished and the file names what it
   retired. (Your own layer-not-replace rule, applied at home.)
3. **`services/` view is gone.** It was last regenerated 2026-07-18 and described
   a pre-pacing world — healthy-looking stale output is the exact "silent
   failure" smell. The morning glance supersedes it; deleting it names what the
   glance retires.
4. **Journals compact.** DIGEST.md (256 KB) and DESIGN-NOTES.md (88 KB) roll up
   monthly into `docs/history/YYYY-MM.md` with a one-page index. Append-only
   honesty is kept; unbounded single files are not. A journal nobody can reread
   is write-only memory.
5. **`SCHEDULER_SUBDIR` is retired** — every project uses `.scheduler/`, so the
   override (and the aedile misconfiguration it enabled) can't exist.

## Unchanged, because it's right

Usage-paced governor · `_paced.<hostname>.conf` host scoping · crontab managed
block with timestamped backups · runtime mutex vs schedule registry separation ·
weight enforced here, judged in realisateur.
