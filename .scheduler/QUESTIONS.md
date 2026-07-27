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

- **2026-07-26 (nightly-batch, ~23:0x pass): `/cloture` is built — layer 1 is live, layer 2 needs one `git mv` from you.**
  Built this pass (`3913d7c`, pushed): **layer 1** `bin/closeout-lint.sh` (offline, zero AI, writes nothing, exit 0) + `bin/tests/closeout-lint.test.sh` (16 assertions, both directions, negative-tested against a stub). It flags recently-touched repos that are dirty / ahead of upstream / tracking nothing, checks that today's FOCUS entry cites a real sha, and reports — never flags — whether BLOCKERS.md has anything dated today. Full writeup in `.scheduler/FOCUS.md`'s entry of the same date.
  **The one thing needing you:** **layer 2 could not be installed.** The harness's sensitive-file gate hard-refuses Edit/Write under `.claude/**` in an unattended run — the same gate that forced the `.scheduler/` FOCUS migration. The command file is written in full and committed at `.scheduler/cloture.command.md`; installing it is one line in a human session:
  `git mv .scheduler/cloture.command.md .claude/commands/cloture.md` (then strip its leading HTML comment).
  Worth deciding at the same time: is a staged-in-`.scheduler/`-then-`git mv` path the standing convention for *any* command file an unattended pass writes, or should nightly-batch simply never author command files and queue them for `/ideate` instead? Layer 3 (the Stop hook) is deliberately not built — its own design says "only after both exist," and layer 2 isn't a command until the `mv` runs.
  > (answer inline here)

## DEFERRED CROSS-WRITE -> senechal (2026-07-26, interactive session)

**Owed:** a dated note in senechal's own FOCUS.md recording that
realisateur added a **global** `~/.claude/settings.json` hook entry
(`SessionStart`/`SessionEnd` -> `realisateur/bin/session-marker.sh`)
— machine-wide config, so it falls under the standing notify-senechal
policy AND under senechal's own 2026-07-24 mission widening
("shared-host script/autostart ownership": no unattributable leftovers).

**Ownership decided this session (Zach asked directly):** realisateur
owns the hook entry and its behavior; senechal owns *knowing it exists*.
Precedent is the existing `# >>> realisateur-owned ... # <<< ` block in
Zach's crontab — realisateur owns its own entry inside a shared
machine-config surface. JSON has no comments, so attribution rides on
the command path itself being unmistakably realisateur's.

**Why not done inline:** `bin/check-project-busy.sh senechal` reported
BUSY (`senechal-nightly-batch`, pid 96695, started 21:55:03) at the
moment of writing, so the cross-write was deferred per `/ideate` step 4
rather than edit FOCUS.md out from under a live run. Re-checked at the
end of the session, still busy.

**Next pass: re-probe and write it.** Also worth telling senechal: the
marker file it may observe at
`~/.local/share/scheduler-registry/<project>.interactive` is
realisateur's, is expected, and is self-healing (a stale one means a
session died, not that anything is wrong).

- **2026-07-26 (interactive): `crt` is dark at weight 3, with 32 open ideas stranded behind it. Intended?**
  The new `bin/steward-survey.sh` surfaced this on its first run and it is
  the loudest row in the ecosystem: weight 3 is the highest stated intent
  anywhere, `enabled=0` is the actual dispatch, and the two have disagreed
  long enough for 32 dated ideas to pile up with nothing draining them.
  Not touched — re-enabling a project is a stated decision, not a batch
  one. Three honest options, and any of them is fine:
  (a) **re-enable** — the intent was real and the valve was shut by
  accident or for a reason that has passed;
  (b) **drop the weight to 1 and leave it dark** — so the stated intent
  stops contradicting the dispatch, and re-enabling later is a small step;
  (c) **leave it exactly as is and park the 32 ideas honestly** — crt is
  deliberately off, and the reservoir behind it should say so rather than
  reading as live backlog.
  Same question applies more quietly to `groc-mangr` (weight 2, dark) and
  to `aedile`, whose registered repo path
  (`/home/zach/Documents/vkv/wavebucks/aedile`) no longer exists at all —
  that one is probably a stale registration rather than a decision.
  > (answer inline here)
  >
  > **WITHDRAWN 2026-07-27 (`/ideate`) — THE QUESTION WAS BUILT ON A
  > SENSOR ARTIFACT. Do not answer it; nothing here needs deciding.**
  > Zach *did* answer it in the 2026-07-27 session (option b, "drop the
  > weight to 1 and leave it dark") and the change was deliberately NOT
  > applied — `schedule/_paced.conf` is untouched and crt keeps weight 3,
  > which is correct. Re-probed, not quoted:
  > - **crt is not dark.** `schedule/_paced.dexter.conf:105` is
  >   `crt|1|3|...`, enabled, and crt has **289 commits in the last 7
  >   days** (most recent nightly authored `Dexter Pine`, 2026-07-25). It
  >   is the single most active project in the ecosystem. The 32 "stranded"
  >   ideas are draining nightly, from dexter.
  > - **aedile is not a stale registration.** Its path is a *subdirectory*
  >   of the shared `wavebucks` monorepo, which is why `git -C` reported
  >   both "no repo" (to some sensors) and "clean, up to date" (to
  >   `ecosystem-survey.sh`, which was reading the monorepo). It dispatches
  >   from `svc-vaporwave`'s crontab at 03:00 — verified with
  >   `sudo -n -u svc-vaporwave crontab -l`, stderr not silenced.
  > - **vkv-inventory** likewise, 04:00, 26 commits/7d including one
  >   authored by `svc-vaporwave` itself.
  > `groc-mangr` (weight 2, dark) is the one part of the original question
  > that survives, and it is quiet enough not to need a decision tonight.
  > Root cause: `bin/steward-survey.sh` reads one of **three** dispatch
  > surfaces. 42 of the 52 reported "stranded" ideas were artifact. Fix
  > queued as `bin/sensor-agree.sh`; new BUILD-DISCIPLINE.md pattern 14.

- **2026-07-27 (`/ideate`): realisateur's own stability milestone is gated
  on five projects that nothing dispatches against. Restate the bar, or
  clear the five by hand?**
  The current bar is *"every scheduler-registered project with a real git
  repo has a declared `## Stability milestone` of its own, AND
  park-by-default triage has held across more than one live pass."*
  `milestone-audit.sh` reports 5 still missing: `groc-mangr`,
  `nine-speakers`, `sequestria`, `vim-arcade`, `vkv-inventory`. Four of
  those five are `enabled=0` in every rotation file, so no nightly run
  will ever declare them — and the fifth (`vkv-inventory`) dispatches
  under `svc-vaporwave`, whose runs have not taken up milestone-setting.
  **The bar as written is not reachable by waiting**, which makes it a
  milestone that cannot be reached rather than one that has not been. Not
  touched — restating a milestone is a stated decision, not a batch one.
  (a) **declare the five by hand** from an interactive pass (realisateur
  has direct cross-write privilege; ~5 short entries, one session);
  (b) **restate the bar** to cover only projects with a live dispatch
  path, and say so — the honest version if the five are deliberately
  dormant;
  (c) **re-enable some of the five** so their own runs can do it — the
  most expensive option, and only right if you actually want them moving.
  > (answer inline here)
