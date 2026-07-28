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

- **2026-07-24 (realisateur, via scheduler's `-i realisateur` drop): aedile + vkv-inventory silently orphaned 4 days — decision needed on which recovery path.** Both were disabled in `_paced.conf` 2026-07-20 assuming migration to `svc-vaporwave`'s own crontab; `crontab -l` there is empty, so it never happened. Decided **2026-07-24: finish the svc-vaporwave migration** (not pull back into zach's own rotation) — its credentials still look valid (touched 2026-07-21). Per scheduler's own ownership split (`DESIGN-NOTES.md` 2026-07-24 "silently-orphaned finding"), the actual crontab/credential/permission install on the svc-vaporwave account is a human (zach) action, not something an agent should attempt cross-account — zach already asked for broader access to that account's home directory for exactly this reason. Concrete next step: once that access exists, install crontab entries for `aedile-nightly-batch-loop.sh` and `vkv-inventory-nightly-batch-loop.sh` on svc-vaporwave (mirroring what `_paced.conf`'s disabled lines specify), then re-verify with `crontab -l` there. No further action from realisateur until that human step happens.
> This is a failure of a blocker. Does nto explicitly say what I need to do to unblock. I don't
> immediately know how to install permission on the cron tab. 

- **2026-07-24 (nightly-batch): build a `UserPromptSubmit` hook to enforce ideate-mode across a whole conversation, or stay prose-only?** Zach's own complaint (`revise-the-ideate-workflow-*.idea`, full writeup in `IDEATE-WORKFLOW-REVISION.md`): `/ideate` drifts into build-mode over a long session because it's a one-shot slash command with no harness-enforced "mode." This pass strengthened the prose (`ideate.md` now says the posture holds for the rest of the conversation), but a harder guarantee would mean a project-local `.claude/settings.json` `UserPromptSubmit` hook that re-injects an ideate-mode reminder on every subsequent turn. That's an infra change to how every prompt in a realisateur session behaves, not a markdown edit -- flagging rather than building unprompted.
> The re-injection sounds cool but clunky. Let's park it and decide on a trigger: say, Zach needs
> to invoke /ideate multiple times on the same idea to prevent drift into build. Include that in
> /ideate itself so that agents know to name the trigger when it happens.

- **2026-07-27 (interactive): should there be ONE user-level `/ideate`, or does each project keep its own?** `reach-lint.sh` check A (new, `7c3d45c`) now requires every command file to declare `scope:`. For the 16 currently-undeclared files across 13 repos, almost all are unambiguously `scope: project` — a `nightly-batch.md` is a per-project unattended pass and nothing else. But **chezz** and **scheduler** each carry their own `ideate.md`, and realisateur's is now installed at user level, so it is already reachable from inside those repos. Two of them cannot both be `scope: user` without colliding on `~/.claude/commands/ideate.md`. Genuine fork, and not mine to settle: (a) realisateur's is THE `/ideate` and the other two get `scope: project` and are eventually retired as duplicates; (b) they stay project-scoped indefinitely because a chezz-specific triage pass is a different job from an ecosystem sweep; (c) the ecosystem-wide one gets renamed so all three can coexist. Until answered, all three keep working exactly as they do now — realisateur's globally, the other two only in their own repos.
> (a) is a fine shape. I can see both commands and choose which I like. Better idea, 
> project-specific ideate commands have the global one nested in it by default. That way,
> realisateur's changes propagate globally automatically while still allowing bespoke designs.
> If that's possible, that's my preferred path.

- **2026-07-27 (`/ideate bibliothecaire`): informational, closable once read — two scheduler-engine guards filed through the front door, and the concept set for bibliothecaire's new milestone is a PROPOSAL awaiting your amendment.** Filed via `scheduler -i scheduler` (its `.scheduler/FOCUS.md` backlog, committed + pushed by the front door itself): (1) the ~:30 autocommit watcher should refuse to commit a file containing conflict markers or a duplicate `## ` heading — live exhibit `0e9b6a6`, which adopted a mid-`vimdiff` BLOCKERS.md under your name, 106 insertions / 0 deletions; (2) machine-append must not anchor on a `## ` that lives inside prose — live exhibit `ec89b84`, which split BLOCKERS.md's header sentence on the literal `` `## Recently resolved` `` inside it and left a fake duplicate heading standing for two days. Both repaired by hand in `1a6bc0a`; the proposals are so they cannot recur. **The part that wants your eye:** bibliothecaire's new milestone (`550af93`) runs against a 14-concept starting set that *realisateur* assembled from this ecosystem's own failure record — Ashby, Simon 1962, Conway 1968, Hayek 1945, Ostrom, Coase, Laozi reachable now; Grassé, Beer, Koestler, Cohen/March/Olsen, Perrow, March 1991 behind the Tulane access you're wiring. It is explicitly labelled a proposal, not your list. Amend it with a `> ` answer in bibliothecaire's own `.scheduler/QUESTIONS.md` or here; the nightly will work the reachable half in the meantime either way.
> Yes. We need to do something about the autocommit watcher; it's half baked. I already addressed the bibliothecaire question inside that project's questions. In short, no problem. Note, this is note a question. Failure mode that needs to be filed and addressed later. I'm seeing this in many projec'ts filed.

- **2026-07-26 (nightly-batch, ~15:30 pass): the librarian drop is EXECUTED — rename + scaffold, both live.** Step 0: the page-92 project is now **quatre-vingt-douze** (dir, bare remote, `schedule/quatre-vingt-douze.conf`, `_paced.conf` line + loop script, every in-repo self-reference; weight unchanged at 1; its own commit `cd70522`, scheduler `9c8f335`; collision question folded in its QUESTIONS.md). Then **bibliothecaire** scaffolded fresh under the freed name (`~/Documents/Projects/bibliothecaire`, own repo `332637b` pushed to a new bare remote, registered enabled at LOW weight 1 per the drop, scheduler `60bc63c`): consumer contract + honesty policy in README, 6-quote seed set all marked `seed-unverified`, `bin/validate-quotes.py` fails-loud validator (negative-tested), SOURCES.md primary-literature map, milestone = every wing-(a) theme ≥2 primary-source-verified quotes + published export. Two judgment flags live in ITS `.scheduler/QUESTIONS.md` (quotes-file contract shape for crt; Beer/Koestler texts not freely online). Drop archived as `archive/bibliothecaire-librarian.idea` — `archive/bibliothecaire.idea` stays page-92's record, per the drop's own instruction. The prior pass's three-projects informational flag (abletim/bibliothecaire/secretaire) is hereby closed as read; its bibliothecaire half is superseded by this entry.
> I'm not sure what happened here but there seem to be compounding failures. I dropped two ideas under the same name in realisateur; my bad. But they should not have spawned two new projects like this with the whole rename dance. This is the same project. Just different aspects. So two things, we need to more elegantly handle a name collision like this (just build one combo project with an easy seam when in doubt). 2) Bibliothecaire is moving towards a system where it is the head librarian of a multiagent institution. Page92 lives inside bibliothecaire even if it has agent shape. Bibliographe, when bootstrapped, will do the same. Best to keep these contained under the bibliothecaire abstraction but acknowledge the emerging monorepo feel. My preference is to only interface with bibliothecaire. An interesting experiment would be to have the subagents report to bibliothecaire in the same way other agents report to me. Then bibliothecaire answers questions, clears blockers, and kicks things up to me that it cannot handle.

- **2026-07-26 (nightly-batch): secretaire is registered but parked (`enabled=0`) — flip it on when you've answered its lane question.** Its remaining milestone items are human steps: fill `ACCOUNTS.md`'s inventory, and decide the access lane (grant-access vs utilities vs thunderbird — the fork is laid out in `secretaire/.scheduler/QUESTIONS.md`). Once a `> ` answer lands there, set `secretaire|1|...` in scheduler's `schedule/_paced.conf`.
> Thanks for the flag. This is not really a question though. Eventually I will prefer not to see these in this view.

- **2026-07-26 (nightly-batch, ~21:25 pass): three queued `[batch]` hygiene-lint rows BUILT — one judgment call in the new BLOCKERS.md row, and one large finding worth your eye.**
  Built (`cc8a14e`, pushed): `[checklist-drift]`, `[stale-claim]`/`[unstamped-claim]`, `[blockers-task]`. Full writeup in `.scheduler/FOCUS.md`'s entry of the same date. Two things for you rather than for the next batch:
  **(a) The `[blockers-task]` rule's exemption scope.** It flags `BLOCKERS.md:129` — the 2026-07-24 wtul `.scheduler/` migration, the entry pattern 13 is named after. That entry *did* get a status note (`ba1757a`), but its OBLIGATION line was filed under `## realisateur`, a different section, so the entry itself carries no dispatch pointer. Under the rule as written that's a true positive. If you meant "a dispatch pointer anywhere in the file exempts the entry," say so and the check widens to file scope.
> This is pretty opaque to me. So I'm just going to say things are fine now. Not really able to parse this jargon. Sounds like a filing error that needed a mechanical check.
  **(b) 13 of 18 projects' stamped build-discipline checklists lag the baseline** — most at 7 rows vs. 12, realisateur's own at 11. That's now mechanically visible every run. Restamping 13 CLAUDE.md files is a real cross-project sweep (each is a separate repo + commit), not something this pass did unprompted. Worth one dedicated pass, or one project per nightly?
> Nightly is fine. But this raises the question, why isn't this a symlink? Why is there this labor at all? Should there be a stamper script, if we insist on maintaining separate checklists per repo? It should be trivial to maintain the common build-discipline while allowing for per-project variation. This is a solved problem from 1980.

- **2026-07-26 (nightly-batch, ~22:1x pass): the write-race guard `bin/focus-commit.sh` is BUILT and tested — but nothing uses it yet. Should adoption be mandatory?**
  Built this pass (`7e49b0e`) as realisateur's half of the four-times-recorded FOCUS-file write race: stages exactly the named files, commits `-F`, pushes, and on rejection does fetch → print-incoming → rebase → **verify the rebase didn't change what the commit means** (same file set, same blob hashes, before and after) → retry. Witness is `bin/tests/focus-commit.test.sh` — 9 assertions over a real throwaway remote and two clones, offline, including a direct reproduction of the 2026-07-26 incident (upstream renames the file we edited; the rebase lands our edit on a path we never named; the check catches it and pushes nothing). Negative-tested against a stub so the suite can actually fail.
  **The question is adoption, not the build.** Switching this repo's own `nightly-batch.md`/`ideate.md` to *require* it for every FOCUS/QUESTIONS write is a real behavior change to how every session commits — and its refusals are strict by design (an unrelated staged file is a hard abort, a same-file conflict is a hard abort). That strictness is the point, but it will stop sessions that today muddle through, so it's your call rather than something to impose unprompted. This pass dogfooded it exactly once (the commit of its own FOCUS entry) and changed no command file. Options: (a) mandate it in both command files, (b) leave it available and let it prove itself on a few more live races first, (c) go further and make it the only sanctioned path, with a hook.
> a, then c. this was the built but not wired failure mode. name what you retire and then actually confirm you retire it after this. the trigger for full sunset is all projects running on the new behavior. we can roll this out one at a time but we should at least stamp stale commands to announce their own outdated behavior loudly.

- **2026-07-26 (nightly-batch, ~23:0x pass): `/cloture` is built — layer 1 is live, layer 2 needs one `git mv` from you.**
  Built this pass (`3913d7c`, pushed): **layer 1** `bin/closeout-lint.sh` (offline, zero AI, writes nothing, exit 0) + `bin/tests/closeout-lint.test.sh` (16 assertions, both directions, negative-tested against a stub). It flags recently-touched repos that are dirty / ahead of upstream / tracking nothing, checks that today's FOCUS entry cites a real sha, and reports — never flags — whether BLOCKERS.md has anything dated today. Full writeup in `.scheduler/FOCUS.md`'s entry of the same date.
  **The one thing needing you:** **layer 2 could not be installed.** The harness's sensitive-file gate hard-refuses Edit/Write under `.claude/**` in an unattended run — the same gate that forced the `.scheduler/` FOCUS migration. The command file is written in full and committed at `.scheduler/cloture.command.md`; installing it is one line in a human session:
  `git mv .scheduler/cloture.command.md .claude/commands/cloture.md` (then strip its leading HTML comment).
  Worth deciding at the same time: is a staged-in-`.scheduler/`-then-`git mv` path the standing convention for *any* command file an unattended pass writes, or should nightly-batch simply never author command files and queue them for `/ideate` instead? Layer 3 (the Stop hook) is deliberately not built — its own design says "only after both exist," and layer 2 isn't a command until the `mv` runs.
> Is this stale by the time I've gotten to it? I can't find the commands to git mv. What failed such that I'm seeing this?

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

- **2026-07-27 (nightly-batch): home-assistant is DIVERGED from origin/master — 1 local-only, 5 remote-only commit(s) — and its last scheduled run FAILED (2026-07-27 17:48:44, 212s, nothing pushed).** `ecosystem-survey.sh`'s own git-health check refuses to auto-resolve this ("Needs a real merge decision -- NOT auto-resolved, ever"), and this pass agrees — it's home-assistant's repo/automation, not realisateur's to touch. Genuine judgment call for Zach: which side is correct (the 1 local-only commit, or the 5 remote-only ones), and should the merge happen by hand or should home-assistant's own next run be trusted to reconcile it? Until resolved, home-assistant's nightly automation is likely to keep failing or skipping pushes.
  > (answer inline here)

- **2026-07-28 (`/ideate`, Zach-directed): four decisions on policy propagation.**
  Asked live this session; Zach stepped away before answering, so they are
  filed here rather than lost with the conversation. Full findings and the
  milestone chain are in `.scheduler/FOCUS.md` same date (`a301147`); the
  watcher proposal is filed with scheduler (`afcfba9`). Nothing was built.

  **(1) The sweep watcher.** Its human-presence guard is keyed to the
  project the *editor* opened, so every cross-project write is unguarded —
  and `cmd_commit_file` pushes, so a half-finished file reaches the ref the
  nightlies clone. 7 adoptions in 36h; one swallowed your own reply-writing
  burst (wtul `4b02419`), one took this session's 116-line in-progress
  restoration and committed it as "author unknown". Options: **(a)
  quiescence** — adopt only a file unchanged two ticks running; needs no
  marker so it covers cross-writes, GUI editors and agents for free, costs
  15min→30min backstop latency (**realisateur's recommendation**); (b)
  defer if ANY session marker is live; (c) both; (d) sweep stops pushing.
  > (answer inline here)

  **(2) Propagating the question-routing fix.** The bad instruction is live
  in `gardien`, `groc-mangr`, `nine-speakers`, `senechal`, `sequestria`,
  `vkv-inventory`. Options: **(a)** give `restamp-discipline.sh` a second
  managed region inside each project's `nightly-batch.md`, so the rule is
  fixed once and project #8 gets it on creation (**recommended**); (b)
  hand-fix the six now — faster, but it is the hand-copy this ecosystem
  keeps naming as failure pattern 4; (c) fix only the high-cadence ones.
  > (answer inline here)

  **(3) The ~50 orphaned `> ` replies across 11 projects.** Options: **(a)**
  inventory them for you first — project, question, your reply, git-blame
  date — and you decide what is still live (**recommended**); (b) give every
  project the now-non-destructive consume step and let their next runs pick
  them up; (c) leave them, deliberately, as archaeology.
  > (answer inline here)

  **(4) `restamp-discipline.sh` runs on nothing.** Options: **(a)** shim it
  and have `/ideate` + `/cloture` run it **dry** during orient, keeping
  `--apply` a deliberate human act (**recommended** — an unattended rewrite
  of 18 CLAUDE.md files is a large blast radius for a cron job); (b) cron it
  with `--apply`; (c) shim only.
  > (answer inline here)
