# Questions for the user

<!-- Copy this to .claude/QUESTIONS.md in a project's repo (or just let
     /bug-sweep or /nightly-batch create it on first use -- both commands
     already know to). Running log, appended to (never overwritten or
     trimmed) by either command whenever something bigger than a routine
     tracker note comes up -- an ambiguous policy question, a real
     tradeoff, a "which of these two directions" fork. This is the "can
     both tiers flag something for me, somewhere I can easily find it"
     answer -- deliberately a real file at the repo root, not buried in
     ~/reports/, so opening the project itself surfaces it (and it's
     symlinked into scheduler/questions/<project>.md + printed by
     bin/morning-report.sh). -->

## How to answer (this is the two-way interface)

Reply **inline, directly under the question**, on a new line starting
with `> ` (a Markdown blockquote). You don't delete anything yourself.
Example:

```
- **2026-07-18 (nightly): Stalemate — reset the floor or die?**
  > reset to the start of the current floor, keep the run alive
```

Contract the commands follow:
- **`/nightly-batch` owns answer-processing.** On its next run it reads
  this file first, treats any `> ` answer as authoritative (same standing
  as `FOCUS.md`), acts on it, folds a standing decision into `FOCUS.md`,
  then removes that question+answer block once acted on (git history and
  the run's report keep the record).
- **`/bug-sweep` only appends** genuine judgment calls; it must NOT act on
  or delete a `> ` answer (that's the nightly's job) — this keeps the fast
  15-minute loop from racing the nightly over the same file.
- Unanswered questions are left untouched and never re-asked/duplicated.
- To dismiss a question without any action, just delete its line by hand.

Question format either tier appends:
`- **YYYY-MM-DD (nightly|bug-sweep): <question>**` + short context, then a
`  > (answer inline here)` placeholder line so the reply slot is obvious.

*(No open questions right now — the four groc-mangr/nine-speakers/
sequestria/vim-arcade entries answered 2026-07-20 were folded into each
project's own `.claude/FOCUS.md` and removed here on 2026-07-22.)*

- **2026-07-24 (realisateur, via `/ideate crt`): "bibliothecaire" library-split idea — parked, see crt's own `.claude/FOCUS.md` for the full entry.** Zach's idea: split Book Game's library/catalog half into its own program with real book-contents/relationships/citations/further-reading knowledge. Decided: park until crt's current DECLARED milestone (voice loop + Book Game funnel reliable on potato) is reached — that milestone still needs the funnel itself, and a 2026-07-22 entry already declined to scaffold this same feature separately. No action needed here; full rationale and revisit-options live in crt's repo.

- **2026-07-24 (realisateur, via scheduler's `-i realisateur` drop): aedile + vkv-inventory silently orphaned 4 days — decision needed on which recovery path.** Both were disabled in `_paced.conf` 2026-07-20 assuming migration to `svc-vaporwave`'s own crontab; `crontab -l` there is empty, so it never happened. Decided **2026-07-24: finish the svc-vaporwave migration** (not pull back into zach's own rotation) — its credentials still look valid (touched 2026-07-21). Per scheduler's own ownership split (`DESIGN-NOTES.md` 2026-07-24 "silently-orphaned finding"), the actual crontab/credential/permission install on the svc-vaporwave account is a human (zach) action, not something an agent should attempt cross-account — zach already asked for broader access to that account's home directory for exactly this reason. Concrete next step: once that access exists, install crontab entries for `aedile-nightly-batch-loop.sh` and `vkv-inventory-nightly-batch-loop.sh` on svc-vaporwave (mirroring what `_paced.conf`'s disabled lines specify), then re-verify with `crontab -l` there. No further action from realisateur until that human step happens.
  > (answer inline here)
