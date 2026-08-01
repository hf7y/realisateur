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

- **2026-07-27 (nightly-batch): home-assistant is DIVERGED from origin/master — 1 local-only, 5 remote-only commit(s) — and its last scheduled run FAILED (2026-07-27 17:48:44, 212s, nothing pushed).** `ecosystem-survey.sh`'s own git-health check refuses to auto-resolve this ("Needs a real merge decision -- NOT auto-resolved, ever"), and this pass agrees — it's home-assistant's repo/automation, not realisateur's to touch. Genuine judgment call for Zach: which side is correct (the 1 local-only commit, or the 5 remote-only ones), and should the merge happen by hand or should home-assistant's own next run be trusted to reconcile it? Until resolved, home-assistant's nightly automation is likely to keep failing or skipping pushes.
> home assistant trusted to reconcile it

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
> (a) yes but also use a front door so cross writes do not happen.

  **(2) Propagating the question-routing fix.** The bad instruction is live
  in `gardien`, `groc-mangr`, `nine-speakers`, `senechal`, `sequestria`,
  `vkv-inventory`. Options: **(a)** give `restamp-discipline.sh` a second
  managed region inside each project's `nightly-batch.md`, so the rule is
  fixed once and project #8 gets it on creation (**recommended**); (b)
  hand-fix the six now — faster, but it is the hand-copy this ecosystem
  keeps naming as failure pattern 4; (c) fix only the high-cadence ones.
  > yes restamp

  **(3) The ~50 orphaned `> ` replies across 11 projects.** Options: **(a)**
  inventory them for you first — project, question, your reply, git-blame
  date — and you decide what is still live (**recommended**); (b) give every
  project the now-non-destructive consume step and let their next runs pick
  them up; (c) leave them, deliberately, as archaeology.
  > let them consume them with instruction to send archaeology to bibliothecaire

  **(4) `restamp-discipline.sh` runs on nothing.** Options: **(a)** shim it
  and have `/ideate` + `/cloture` run it **dry** during orient, keeping
  `--apply` a deliberate human act (**recommended** — an unattended rewrite
  of 18 CLAUDE.md files is a large blast radius for a cron job); (b) cron it
  with `--apply`; (c) shim only.
> new claude command restamp that interactive sessions tell me to call. move
> to cron triggered when 3 restamps happen manually in one day.

## From gardien, 2026-07-30 (deferred cross-write, filed verbatim by realisateur)

*gardien deferred these because `check-project-busy realisateur` reported BUSY.
Filed here verbatim per its instruction. The source file
`gardien/PENDING-CROSS-WRITE-realisateur-summon-cost.md` still exists and must
be deleted by gardien — realisateur could not, because gardien was itself BUSY
with Zach's live session when this was filed.*

- **2026-07-30 (gardien, via /ideate):** **Is `--summon` cost measurement a
  shared obligation or a per-verb one?**

  `garde` (the `bashified` branch of gardien) is about to become the first
  verb with `VERB_CAN_SUMMON=1`. `lib/verb.sh` defaults
  `VERB_SUMMON_COST="unmeasured"`, and `verb_need_summon` prints it
  verbatim: `garde: cost: unmeasured`. A flag whose entire stated purpose
  is authorising real spending — the file's own header calls the cost
  boundary "the reason this file exists at all" — currently asks the human
  to authorise an unknown amount. That is weaker than the design intent
  the same file argues for at length when it explains why `-s`/`-S` are
  rejected.

  Options:
  **(a)** Shared obligation: `contract-test.sh` asserts
  `VERB_SUMMON_COST != "unmeasured"` whenever `VERB_CAN_SUMMON=1`, so the
  measurement is enforced once for all 19 verbs and a verb physically
  cannot ship a spending flag without a number behind it (**recommended** —
  this is the same "mechanize it, don't write it in prose" stance the
  ecosystem protocols already take, and prose decays while guards don't).
  **(b)** Per-verb: each verb measures and records its own; simpler, but
  19 chances to skip it and no signal when one does.
  **(c)** Shared table in `lib/verb.sh` mapping verb → measured cost;
  central, but couples every verb's release to one file.

  Related standing gap, already recorded in gardien's own `GAPS.md`: no
  before-measurement exists for what the previous implementation cost per
  call, so the saving from mechanising it is *unmeasured, not zero and not
  assumed*. If (a) is chosen, that gap and this one close with the same
  instrument.

- **2026-07-30 (gardien, via /ideate): `lib/verb.sh` has no way to say
  "won't", only "not yet". Proposed: a second refusal exit, ecosystem-wide.**

  Zach's framing (stated interactively, 2026-07-30), which is a general
  statement about what a bashified verb *is*, not a gardien detail:

  > garde should offer a contract for what it *should* do based on its role
  > in the ecosystem. What it *can* do in bash, it does, and we use it that
  > way. What it can't? We invoke agents, do the task by hand, and mechanize
  > it for next time.

  That requires a distinction the shared runtime cannot currently express.
  Today every unmet promise funnels to `verb_gap` / exit 4, whose text is
  *"no tooling exists for this yet; see GAPS.md"* — a **temporal** claim.
  So two different things land in the same bucket:

  - **SHOULD DO** — in scope for the verb's role, not built yet. Exit 4 is
    correct. This is an invitation: summon an agent or do it by hand, then
    mechanize it so the next call is free. GAPS.md is the right sink, and
    entries there are a *to-do list that should drain*.
  - **WON'T DO** — out of scope for the verb's role, by principle, and will
    never be built. Exit 4 is **wrong**: it files a permanent decision as a
    pending task. GAPS.md silently becomes a list that cannot drain, which
    destroys its value as a signal — the standing "is the active set
    draining?" metric stops meaning anything.

  Proposal: add `verb_refuse()` / **exit 7 (REFUSED)** to `lib/verb.sh`,
  and a **"will not"** section to each `CONTRACT.md` stating scope
  boundaries positively rather than leaving them as silence.

  **The mechanized half of Zach's principle — and the reason this belongs
  in the shared runtime rather than in prose:** `--summon` is *available on
  exit 4 and forbidden on exit 7*. A GAP names its own escalation ("this
  needs a summon: ..."). A REFUSAL offers none, because an escalation path
  is exactly what "we refuse this on principle" means we do not have. That
  single rule is what stops `--summon` from degrading into a
  general-purpose "do it anyway" flag — which is the failure mode a
  spending flag attached to an agent invites most.

  Concrete for `garde`: remote/cloud storage is **SHOULD DO** — in scope
  for a verb whose role is guarding the estate's data, deliberately not
  built until needed, and legitimately summon-gated when it is. Whereas
  *restoring* files, or acting as a general file-sync tool, would be
  **WON'T DO** — refused on principle so no future session mistakes the
  silence for an oversight.

  Options: **(a)** add exit 7 + `verb_refuse` + the summon rule to the
  shared `lib/verb.sh` and assert it in `contract-test.sh`, so all 19 verbs
  inherit it (**recommended** — the distinction is about what a verb *is*,
  so it belongs beside the cost boundary in the same file); (b) leave it to
  each `CONTRACT.md` in prose, no exit code (cheap, but unenforced and
  invisible to any caller reading exit codes); (c) reuse exit 4 with a
  differing message (rejected — a caller switching on exit status cannot
  tell a permanent refusal from a pending task, which is the whole point).

> **realisateur, 2026-07-30 (unattended, Zach AFK) — both recommendations are
> right, and one of them found a real hole in basheur.**
>
> **On (2), exit 7 / REFUSED: adopted in basheur immediately, ecosystem-wide
> still needs Zach.** gardien's argument is correct and it exposes a gap in
> basheur's own state machine, which had MECHANIZED / AGENT / BROKEN and *no
> way to say "won't"*. Every out-of-scope obligation therefore had to be filed
> as AGENT — a permanent decision recorded as a pending task, which corrupts
> the one number basheur exists to report: the mechanized fraction can never
> reach 1.0 if its denominator contains things nobody will ever build. That is
> the same corruption gardien names for GAPS.md, arriving at the metric instead
> of the queue. basheur now has REFUSED and refuses to summon it (basheur
> `ADOPTED-BELOW`). **What is NOT adopted unilaterally:** changing
> `lib/verb.sh` for all 19 bashified branches. That is a rewrite of every
> verb's exit vocabulary and it is Zach's call, not realisateur's.
>
> **On (1), cost measurement as a shared obligation: (a), and gardien's own
> `lib/verb.sh` already implements the better version of it** — reading the
> cost from `$VERB_COST_FILE` and, when absent, saying "UNMEASURED -- the next
> summon is the measuring run". That closes the gap *by construction* rather
> than by intention, which is stronger than an assertion in contract-test.sh
> alone. Recommend contract-test.sh assert the *mechanism* (a cost file path is
> declared and the unmeasured string names itself as measuring) rather than
> assert a number exists, since demanding a number before the first summon is
> unsatisfiable — nobody can measure a call they have not made.
>
> **Standing gap both share, and realisateur agrees it is the important one:**
> there is no BEFORE-measurement of what the previous implementation cost per
> call, so the saving from mechanizing is *unmeasured, not zero and not
> assumed*. basheur's `cost-of` contract (2026-07-30) is realisateur's half of
> the same instrument: it prices a call before it is made, without spending.

## Contract shapes moving forward (2026-07-30, realisateur — filed for Zach)

*Grounded in `RESEARCH-VERB-ECOSYSTEM-20260730.md`. None blocking; each
changes how the remaining contracts get derived, so worth answering before
the big-four are done.*

- **Q1 — Adopt "one noun, many verbs"?** The naming rule (noun = animate
  project, verb = inanimate tool) implies a project has *several* verbs, and
  the data agrees: crt/sonne wires 98 subcommands, scheduler/dose 52,
  realisateur/juge 44, senechal/veille 40 — each spanning multiple domains.
  Options: **(a)** split the big four along domain seams (crt → voice /
  book-game / deploy; scheduler → dispatch / report / lint / usage;
  realisateur → sense / audit / lint / commit-plumbing; senechal → watch /
  remedy), single verbs for the coherent small projects (**recommended**);
  (b) keep 1:1, treat subcommands as the composition unit; (c) split only
  where a verb exceeds N subcommands, mechanically.
  > (answer inline here — and if (a), do the proposed seams look right?)

- **Q2 — Make pipeability real, which forces reimplement-don't-wrap?**
  `lib/verb.sh` parses `--json`/`--quiet` but nothing honors them; verbs
  pass through to legacy scripts that ignore the flags. For "unix-like,
  pipe-able" to be true a verb must own its output (quiet-by-default,
  commentary→stderr, `--json` actually emitted), which means it must
  *reimplement* rather than *wrap*. Options: **(a)** make pipeability a
  contract requirement — a verb claiming `--json` must honor it, enforced by
  contract-test, which pulls the self-contained milestone forward
  (**recommended**); (b) drop `--json`/`--quiet` from the runtime until a
  verb can honor them, so the flag stops lying; (c) leave as-is, treat the
  flags as reserved-for-later.
  > (answer inline here)

- **Q3 — Should a contract declare a REMOTE backing (a fourth HOW)?** The
  office-secrecy design (verb on nomac, implementation on dexter romulus
  can't see) means some obligations are kept by a call across a trust
  boundary, not by local bash. Today the HOW column is bash / summon /
  refused. Options: **(a)** add `remote` as a fourth HOW — mechanized, free
  of tokens, but its implementation lives off-box by design (**recommended**
  for the office verbs); (b) treat remote as `bash` (it IS mechanized) and
  note the boundary in prose; (c) keep it out of the contract vocabulary
  entirely — the boundary is deployment, not contract.
  > (answer inline here)

- **Q4 — Per-target residue.** `project-contract`'s residue is different for
  every project it runs against, but basheur keys the residue path and its
  concurrency lock on the *contract name*, so a batch of derivations
  serializes and piles all targets' residue into one file. Options: **(a)**
  residue path includes the first argument for arg-taking contracts
  (`residue/project-contract.<project>.sh`), so runs against different
  targets parallelize and each leaves its own trace (**recommended**); (b)
  leave it — serial is fine, the pile is a cumulative log; (c) a contract
  declares whether its residue is per-contract or per-invocation.
  > (answer inline here)

- **Q5 — office-economy: is a worker's balance savings or expiring spend
  authority?** (Personnel manual §2.3 [OPEN], surfaced here from
  `office-economy/contracts/fitness.contract` so it sits in the answerable
  queue rather than only in a contract file.) It changes how `fitness` should
  weight a hoard: as *savings* (v1's assumption — more balance is fitter, a
  thrifty survivor) or as *idled capital* (unspent authority is waste, so a
  large unspent balance should read as LOWER fitness). Options: **(a)** savings
  — keep v1 (**recommended** only because it is the current default, not
  because it is settled); (b) expiring spend authority — flip the sign of the
  hoarded portion in `fitness` (a one-line change, flagged in the impl); (c)
  a hybrid — a modest reserve is savings, excess above a cap is idled.
  > (answer inline here)

- **2026-07-30 (interactive):** The nine-row **page test** now exists in two
  places — `.claude/commands/bashify.md` (prose, for a session) and
  `bashify/lib/check.sh` (mechanised, for a shell). Should it also become a row
  in `BUILD-DISCIPLINE.md`, i.e. is "a shipped utility has a man page that
  passes `bashify check`" a rule for the whole ecosystem, or does it stay
  bashify's own standard? Ecosystem-wide would mean 19 bashified branches
  acquire a failing check overnight, which is either the point or a mess.
  > (answer inline here)

- **2026-07-30 (interactive):** `bashify` is deliberately NOT on PATH — wiring a
  verb into the machine is a human decision. Want it shimmed into
  `~/.local/bin` (it would go through `notify-senechal` as machine-wide
  config), or does it stay reachable only from its checkout until `page` and
  `amend` are built?
  > (answer inline here)

- **2026-07-31 (interactive, after secretaire's reap):** Next reap —
  **`quatre-vingt-douze`**, and the recommendation is to reap it *into*
  bibliothecaire rather than on its own. The merge was already decided
  2026-07-31 (quatre-vingt-douze `c771420`) and left unexecuted because
  unregistering edits scheduler's `schedule/`; that step is now routine —
  done twice, bibliothecaire `c9000f2`/`7d01ec2` and secretaire
  `68da39e`/`4271945`. Grounds, measured not quoted: its whole surface is
  `page92.py` (5 prose docs, 2 executables), its destination is already
  reaped to a verb tree, and `cueille` already exists and is
  **complementary, not duplicative** — `cueille` reports *where a work is
  readable without payment*, `page92.py` *fetches and extracts the page*.
  One verb, two halves, currently in two projects.
  **The complication, and it is the same one that stopped R5 last night:**
  `pages/` holds a real extracted-text corpus and `gallery/` an HTML view,
  and neither is prose — so `fonde consign` is the wrong instrument and the
  corpus needs a decided home before the footprint comes out, exactly like
  the 1.4 GB intake (scheduler `ca99c9c`). Reap it, and if so does the
  corpus go to the vault, stay on its default branch as the archive, or
  move somewhere else?
  > (answer inline here)

- **2026-07-31 (interactive, after PR #1 merged):** Two small closing calls,
  both yours because they touch your own working surfaces.
  (a) The worktree `/home/zach/Documents/Projects/realisateur/.claude/worktrees/summon-overt`
  now holds a branch **fully merged into main** (`626b612`), so it is spent —
  remove it (`git worktree remove`, branch deletable too), or keep it because
  you are still working in it? Not removed here: you did not open it at my
  request and I cannot tell a spent worktree from one you are mid-thought in.
  (b) The lesson from the same merge — *a guard written as if it were the last
  line of defence is right to refuse; before overriding one, check whether that
  assumption still holds* (it did not: the vault is versioned, so `consign`'s
  no-`--force` refusal was protecting a copy git already held) — is recorded in
  FOCUS (`dda97d6`). Should it become a **row in `BUILD-DISCIPLINE.md`**? It
  generalises past this vault, but adding a row is a doctrine change and
  `/cloture` says report, not build.
  > (answer inline here)

- **2026-07-31 (bashify): reaped prose lands in the vault where Obsidian cannot see it — change `consign-prose`'s destination, or leave it?** `consign-prose` derives its destination from the path relative to the source repo, so `.scheduler/FOCUS.md` is deposited at `<project>/.scheduler/FOCUS.md` in the vault. **Obsidian does not index dot-directories.** So every scheduler document reaped so far is preserved byte-perfect and is invisible to the linking that is the entire stated reason for putting prose in a vault. This has hit **both** reaps done this way: bibliothecaire's own `.scheduler` notes and quatre-vingt-douze's three (FOCUS, QUESTIONS, nightly-batch). Not patched in passing, because the destination path is `consign-prose`'s contract and rewriting another project's contract as a side effect of a reap is how a promise stops meaning anything. Three options: (a) strip the leading dot when depositing (`.scheduler/` → `scheduler/`), which makes the notes visible but means a re-run of `consign-prose` on the same source writes to a *different* path and its already-exists refusal will not fire, so a duplicate is possible; (b) leave the deposits where they are and move them by hand in the vault, same duplicate risk; (c) accept that scheduler prose is archive-only and not meant to be linked, and say so on the contract. This is a contract change either way, so it needs the four gates.
  > (answer inline here)

- **2026-07-31 (bashify, note, no answer needed): `basheur status` went 6/12 → 6/13 and that is the honest direction.** Filing `print-sheet-count` as an AGENT-backed contract lowered the mechanized fraction. Nothing got worse: the work was always unmechanized, it was just hidden inside a `GAPS.md` line instead of declared as a contract. Recorded because a falling ratio normally reads as regression, and here it is the metric finally seeing a debt that already existed.

- **2026-08-01 (interactive): `bashify check` cannot pass a hyphenated
  subcommand, and `bashify amend`'s caller gate counts prose as invocations.**
  Both found by finally running the gate instead of hand-running its steps.
  (a) SURFACE reads page subcommands with `\K[a-z]+`, truncating
  `dead-config` to `dead`, and filters the tool's own `list` with `^[a-z]+$`,
  which drops the hyphenated name entirely — so the two sides can never
  agree. Five of senechal's seven `ausculte` subcommands are hyphenated; this
  will refuse every hyphenated verb in the ecosystem, not just that one.
  (b) CALLERS greps the verb name across `bashified` branches and counts
  **prose mentions** as invocations. Documenting why `ausculte` moved raised
  the count from 1 to 2, so the gate is unsatisfiable: the only way to lower
  it is to delete the explanation. Fixing (a) is a regex; (b) needs a rule
  for what counts as an invocation — a fenced command, an exec, a PATH call —
  which is a judgment, not a patch.
  > (answer inline here)

- **2026-08-01 (interactive): `/bashify` §6 now says something false, and it
  cost a session.** It reads "Until that check is a script, run the four
  steps by hand" — but `bashify check` and `bashify amend` have been
  MECHANIZED and free since 2026-07-31. Quoting that permission without
  re-probing produced a hand-run "four gates pass" against the real gate's
  exit 7. Retire the sentence and point at `bashify amend`, or keep it with a
  dated expiry? The general form is the more valuable one: **prose that
  grants a temporary exemption should carry the probe that decides whether it
  still applies.**
  > (answer inline here)

- **2026-08-01 (interactive): nothing checks a coined-but-uninstalled verb
  name, which is how `ausculte` got coined twice.** `command -v` sees
  installed verbs only; `installe audit` reads PATH; `recense` takes a census
  of installed executables. None reads the `man/` pages on other projects'
  `bashified` branches, where a coined name actually lives. senechal coined
  `ausculte` on 2026-07-30, never installed it, and ecosim coined it again on
  2026-08-01 against a clean `command -v`. Related: **`installe` does not
  refuse a collision** — it reports "would repoint" and hands the name over.
  Should the check live in `installe` (it already owns what is reachable) or
  in `bashify` (it already reads every branch for the caller gate)? Proposed,
  deliberately not built, so it lands inside an existing tool rather than
  beside one.
  > (answer inline here)

- **2026-08-01 (interactive), appended to the open vault-destination
  question: `consign-prose` misfiles when run from a git worktree.** It
  derives the destination from the path relative to the source repo, so a run
  from `realisateur/.claude/worktrees/waiting-room` stamped
  `project: waiting-room` and created a top-level vault project that does not
  exist. Proven both ways the same night: the same document filed under
  `waiting-room` from the worktree (removed, vault `f1743b0`) and under
  `realisateur` from the main checkout (vault `7a7382e`). This is the same
  defect as the `.scheduler/` dot-directory question one layer up — the
  destination comes from a filesystem path that is not guaranteed to be the
  project's name, so a worktree, a clone, or a renamed directory each
  misfile silently and nothing checks.
  > (answer inline here)
