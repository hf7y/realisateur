# Questions for the user

<!-- Copy this to .scheduler/QUESTIONS.md in a project's repo (or just let
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
  - **2026-07-26 (realisateur, via `/ideate`): SUPERSEDED — the park is resolved by merge, not by crt reaching its milestone.** Zach decided the catalog split merges into the new **bibliothecaire** project (own scheduler-registered repo; cybernetics/philosophy KB wing + this catalog wing), taking the "split scope-only, greenfield, shares at most `books.db` data" option crt's entry preserved. Full vision/milestone chain: this repo's `.scheduler/FOCUS.md` 2026-07-26 entry; crt's own FOCUS.md carries the matching `(realisateur)` update same date. Nothing scaffolded yet — queued for nightly-batch at low weight via the rewritten `bibliothecaire.idea` drop.

- **2026-07-24 (realisateur, via scheduler's `-i realisateur` drop): aedile + vkv-inventory silently orphaned 4 days — decision needed on which recovery path.** Both were disabled in `_paced.conf` 2026-07-20 assuming migration to `svc-vaporwave`'s own crontab; `crontab -l` there is empty, so it never happened. Decided **2026-07-24: finish the svc-vaporwave migration** (not pull back into zach's own rotation) — its credentials still look valid (touched 2026-07-21). Per scheduler's own ownership split (`DESIGN-NOTES.md` 2026-07-24 "silently-orphaned finding"), the actual crontab/credential/permission install on the svc-vaporwave account is a human (zach) action, not something an agent should attempt cross-account — zach already asked for broader access to that account's home directory for exactly this reason. Concrete next step: once that access exists, install crontab entries for `aedile-nightly-batch-loop.sh` and `vkv-inventory-nightly-batch-loop.sh` on svc-vaporwave (mirroring what `_paced.conf`'s disabled lines specify), then re-verify with `crontab -l` there. No further action from realisateur until that human step happens.
  > (answer inline here)

- **2026-07-24 (nightly-batch): build a `UserPromptSubmit` hook to enforce ideate-mode across a whole conversation, or stay prose-only?** Zach's own complaint (`revise-the-ideate-workflow-*.idea`, full writeup in `IDEATE-WORKFLOW-REVISION.md`): `/ideate` drifts into build-mode over a long session because it's a one-shot slash command with no harness-enforced "mode." This pass strengthened the prose (`ideate.md` now says the posture holds for the rest of the conversation), but a harder guarantee would mean a project-local `.claude/settings.json` `UserPromptSubmit` hook that re-injects an ideate-mode reminder on every subsequent turn. That's an infra change to how every prompt in a realisateur session behaves, not a markdown edit -- flagging rather than building unprompted.
  > (answer inline here)

- **2026-07-26 (nightly-batch, ~15:30 pass): the librarian drop is EXECUTED — rename + scaffold, both live.** Step 0: the page-92 project is now **quatre-vingt-douze** (dir, bare remote, `schedule/quatre-vingt-douze.conf`, `_paced.conf` line + loop script, every in-repo self-reference; weight unchanged at 1; its own commit `cd70522`, scheduler `9c8f335`; collision question folded in its QUESTIONS.md). Then **bibliothecaire** scaffolded fresh under the freed name (`~/Documents/Projects/bibliothecaire`, own repo `332637b` pushed to a new bare remote, registered enabled at LOW weight 1 per the drop, scheduler `60bc63c`): consumer contract + honesty policy in README, 6-quote seed set all marked `seed-unverified`, `bin/validate-quotes.py` fails-loud validator (negative-tested), SOURCES.md primary-literature map, milestone = every wing-(a) theme ≥2 primary-source-verified quotes + published export. Two judgment flags live in ITS `.scheduler/QUESTIONS.md` (quotes-file contract shape for crt; Beer/Koestler texts not freely online). Drop archived as `archive/bibliothecaire-librarian.idea` — `archive/bibliothecaire.idea` stays page-92's record, per the drop's own instruction. The prior pass's three-projects informational flag (abletim/bibliothecaire/secretaire) is hereby closed as read; its bibliothecaire half is superseded by this entry.

- **2026-07-26 (nightly-batch): secretaire is registered but parked (`enabled=0`) — flip it on when you've answered its lane question.** Its remaining milestone items are human steps: fill `ACCOUNTS.md`'s inventory, and decide the access lane (grant-access vs utilities vs thunderbird — the fork is laid out in `secretaire/.scheduler/QUESTIONS.md`). Once a `> ` answer lands there, set `secretaire|1|...` in scheduler's `schedule/_paced.conf`.
  > (answer inline here)

- **2026-07-26 (nightly-batch, ~21:25 pass): three queued `[batch]` hygiene-lint rows BUILT — one judgment call in the new BLOCKERS.md row, and one large finding worth your eye.**
  Built (`cc8a14e`, pushed): `[checklist-drift]`, `[stale-claim]`/`[unstamped-claim]`, `[blockers-task]`. Full writeup in `.scheduler/FOCUS.md`'s entry of the same date. Two things for you rather than for the next batch:
  **(a) The `[blockers-task]` rule's exemption scope.** It flags `BLOCKERS.md:129` — the 2026-07-24 wtul `.scheduler/` migration, the entry pattern 13 is named after. That entry *did* get a status note (`ba1757a`), but its OBLIGATION line was filed under `## realisateur`, a different section, so the entry itself carries no dispatch pointer. Under the rule as written that's a true positive. If you meant "a dispatch pointer anywhere in the file exempts the entry," say so and the check widens to file scope.
  > (answer inline here)
  **(b) 13 of 18 projects' stamped build-discipline checklists lag the baseline** — most at 7 rows vs. 12, realisateur's own at 11. That's now mechanically visible every run. Restamping 13 CLAUDE.md files is a real cross-project sweep (each is a separate repo + commit), not something this pass did unprompted. Worth one dedicated pass, or one project per nightly?
  > (answer inline here)

- **2026-07-26 (nightly-batch, ~22:1x pass): the write-race guard `bin/focus-commit.sh` is BUILT and tested — but nothing uses it yet. Should adoption be mandatory?**
  Built this pass (`7e49b0e`) as realisateur's half of the four-times-recorded FOCUS-file write race: stages exactly the named files, commits `-F`, pushes, and on rejection does fetch → print-incoming → rebase → **verify the rebase didn't change what the commit means** (same file set, same blob hashes, before and after) → retry. Witness is `bin/tests/focus-commit.test.sh` — 9 assertions over a real throwaway remote and two clones, offline, including a direct reproduction of the 2026-07-26 incident (upstream renames the file we edited; the rebase lands our edit on a path we never named; the check catches it and pushes nothing). Negative-tested against a stub so the suite can actually fail.
  **The question is adoption, not the build.** Switching this repo's own `nightly-batch.md`/`ideate.md` to *require* it for every FOCUS/QUESTIONS write is a real behavior change to how every session commits — and its refusals are strict by design (an unrelated staged file is a hard abort, a same-file conflict is a hard abort). That strictness is the point, but it will stop sessions that today muddle through, so it's your call rather than something to impose unprompted. This pass dogfooded it exactly once (the commit of its own FOCUS entry) and changed no command file. Options: (a) mandate it in both command files, (b) leave it available and let it prove itself on a few more live races first, (c) go further and make it the only sanctioned path, with a hook.
  > (answer inline here)
