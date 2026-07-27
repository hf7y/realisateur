**2026-07-26 (`/nightly-batch`, ~19:40 pass): inbox empty, nothing to build.**

Repo root held only realisateur's own scaffolding (`fable-like/` + doctrine
files) -- no dropped artifact to infer or wire up. All three offline
surveys re-run fresh, no findings changing this pass's scope:
`hygiene-lint.sh` still 30 total FLAGs across 18 projects, same senechal
`base64` test-fixture false positive as the last recorded composition;
`milestone-audit.sh` unchanged at 13 declared/5 missing/0 no-focus
(sequestria, vim-arcade, vkv-inventory, + 2 others still missing --
milestone-setting candidates, not this run's project);
`ecosystem-survey.sh`'s vision-debt ranking unchanged, still topped by
the four 2026-07-18 home-assistant entries. `.scheduler/QUESTIONS.md`'s
open blocks (aedile/vkv-inventory svc-vaporwave recovery, ideate-mode
`UserPromptSubmit` hook, secretaire lane) all still carry only the
placeholder `> (answer inline here)` slot -- no real `> ` reply landed,
left untouched, genuinely waiting on the human.

---

**2026-07-26 (`/nightly-batch`, ~15:30 pass): the librarian drop executed end-to-end — quatre-vingt-douze rename (step 0) + bibliothecaire scaffolded/registered; plus a real feedback-pipeline bug found at dispatch and fixed in scheduler.**

**The dispatch-time bug first (acted on before the batch, per the wrapper's own act-on-feedback-FIRST rule):** this run was handed five "REPLY" blocks from BLOCKERS.md `## realisateur` — all EMPTY. Root cause verified in scheduler's working diff: `collect-feedback.sh --consume` treated the five bare `>` answer slots under the strategy-audit questions as replies (its guard only knew the `> (answer inline here)` placeholder form), emitted five empty REPLY blocks, and deleted the slots from the file. **Nothing was treated as approved — all five strategy-audit calls still await Zach.** Fixed: bare `>` not continuing a reply is now kept as an un-answered slot (scheduler `bb5c762`, regression-tested both directions: restored realisateur section → exit 1/file unchanged; synthetic real reply with interior blank `>` → collected as one block, sibling slot preserved); slots restored from HEAD; dated machine-append note under the entry (`5731804`). Both pushed to scheduler `main` (revert: `git revert 5731804 bb5c762`).

**The batch itself — one inbox artifact, the rewritten `bibliothecaire.idea`, executed exactly per its own sequencing:**
- **Step 0, rename:** page-92 project → **quatre-vingt-douze**: project dir + bare remote moved, clone origin repointed, every in-repo self-reference updated (README keeps Zach's verbatim drop quote as origin record), collision question in its QUESTIONS.md folded as answered (its commit `cd70522`, pushed); scheduler side: conf renamed with all fields, `_paced.conf` line disabled during → renamed → re-enabled (weight unchanged 1), loop wrapper now `quatre-vingt-douze-nightly-batch-loop.sh` (`9c8f335`, pushed). Verified: `milestone-audit.sh` resolves quatre-vingt-douze with its declared milestone; no crontab line ever named the old job; no state dir existed to migrate; `~/reports/` had nothing under the old name.
- **Scaffold, under the freed name:** `~/Documents/Projects/bibliothecaire` (own repo `332637b` → new bare remote `~/git-remotes/bibliothecaire.git`, HEAD=main). Contents per the drop: consumer contract (crt reads `quotes/quotes.txt`/`quotes.json`, never imports code), **honesty policy as a hard rule** (a quote is data; `verified` only after checking the primary text — the 6-quote seed set covering all named themes ships honestly ALL `seed-unverified`, so the crt-facing export is empty until the first real verification pass), `bin/validate-quotes.py` fails-loud validator (negative-tested live), `SOURCES.md` mapping each theme to its primary literature, `.scheduler/` files from day one, CLAUDE.md with the build-discipline baseline. Registered: `schedule/bibliothecaire.conf` (SCHEDULER_SUBDIR, BATCH_TEST_CMD=validator, AUTONOMY_TIER high), `_paced.conf` enabled at LOW weight 1 per the drop's stated pacing call, sync-crontab applied, `hygiene-lint.sh bibliothecaire` clean, `scheduler status bibliothecaire` reads everything through the regenerated symlinks (`60bc63c`, pushed). Its first milestone: every wing-(a) theme ≥2 primary-source-verified quotes, export published. Wing (b) (crt catalog) and doctrine integration parked in its own FOCUS.md.
- **Housekeeping:** drop archived as `archive/bibliothecaire-librarian.idea` (page-92's `archive/bibliothecaire.idea` untouched, per the drop); the prior pass's three-projects informational flag closed in QUESTIONS.md (explicitly closable-once-read); surveys re-run fresh (milestone-audit 12 declared → 13 with bibliothecaire / 5 missing; hygiene-lint 30 FLAGs ecosystem-wide, none in tonight's touched projects; vision-debt ranking unchanged, still topped by the 2026-07-18 home-assistant entries). No other artifacts in the inbox. QUESTIONS.md's remaining blocks (svc-vaporwave recovery, UserPromptSubmit hook, secretaire lane) all still unanswered — left untouched.

---

**2026-07-26 (interactive, Zach-directed, `/ideate` follow-up to the unattended-execution report): the `.claude/`→`.scheduler/` FOCUS-file question — traced to a FAILED DECISION PROPAGATION, realisateur MIGRATED this session (named inline exception, Zach's explicit call), ecosystem pass QUEUED, lesson mechanized.**

**The trace (what Zach asked: "we established using .scheduler — what failed?"):** the decision DID exist. 2026-07-24 ~21:22, scheduler BLOCKERS.md `## wtul` (`ffab7d9`, revising `de62b82` from 20 minutes earlier): migrate off the gated `.claude/` paths onto `.scheduler/`, "same design as every other project long-term, per Zach's explicit preference" — scope fully scouted, then *"filed for an async pass, not completed live."* It was filed into BLOCKERS.md — by standing rule NOT a work queue — under a section no other project's runs read. Consequences, all verified live this session: the wtul migration never executed (no `~/Documents/wtul/.scheduler/`, no `SCHEDULER_SUBDIR` in `wtul.conf`); the "every project" clause reached no template (scheduler `examples/*` and this repo's `SCHEDULER.md` still taught `.claude/`); chezz hit the wall independently and self-migrated (its own mv 2026-07-24, conf caught up in `c00f079`); realisateur's three 2026-07-26 nightlies hit it again, adapted well locally (new projects scaffolded on `.scheduler/` from day one, no gate retries, no self-authorized contract change) but dead-ended their own vision/triage records in `~/reports/` and re-queued the already-made decision as an open question. Not a harness change and not agent disobedience — **a decision recorded where nothing dispatches from is indistinguishable from no decision.** Now BUILD-DISCIPLINE **failure pattern 13** ("a decision without a dispatch path" — pattern 2 for decisions). Deliberately NOT added as a stamped-checklist row (that would re-trigger the stamped-drift debt, see the 2026-07-25 note below); the guards are pattern 13 + SCHEDULER.md/templates teaching the right layout + the queued lint row.

**Zach's three calls this session (asked directly): scope = ALL remaining projects; realisateur's own migration = inline NOW (it structurally cannot run unattended — the gate blocks the very `.claude/` command-file edits the migration consists of); lesson = discipline row + BLOCKERS sweep + a queued mechanical lint.**

**Done this session (realisateur = the pass's template, all consumers verified where they read):**
- `git mv .claude/{FOCUS,QUESTIONS}.md → .scheduler/` + every own-path reference in `nightly-batch.md`/`ideate.md`/`SCHEDULER.md`/`README.md`/`UNIVERSE.md`/`STABILITY-MILESTONES.md`/`FOCUS-FORMAT.md`/`IDEATE-WORKFLOW-REVISION.md` (`fa222cb`); records+consumer-fix commit (this entry's own commit).
- scheduler side: `realisateur.conf` `SCHEDULER_SUBDIR=".scheduler"` + `sync-crontab.sh --apply` (`1284b58`); `focus/realisateur.md` + `questions/realisateur.md` symlinks verified re-pointed; zach crontab verified byte-identical; `milestone-audit.sh` and `scheduler status` both re-probed reading the new location.
- Consumer sweep (the chezz-wrapper lesson from senechal's 2026-07-25 ledger, checked not assumed): `~/.local/bin/realisateur-nightly-batch-loop.sh` is a thin generic exec, needed nothing; two REAL stale consumers found and fixed here — `bin/incubation-audit.sh` (now tries `.scheduler/` then legacy `.claude/`) and `fable-like/inject-suggestions.sh`'s realisateur map line.
- The 2026-07-26 nightlies' PENDING flags folded into `.scheduler/QUESTIONS.md` (three-projects flag closable; secretaire enable question carries the reply slot; the bibliothecaire-collision half was already resolved by this morning's merge/rename decision).
- BLOCKERS.md sweep (append-only, nothing pruned): exactly one task-shaped entry found (the wtul migration itself); status note appended under `## wtul` + a human-present OBLIGATION line under `## realisateur`, both in `ba1757a`.
- Templates routed via the front door per §5 (`scheduler -i scheduler`, commit `c1f9e7b`): examples/* + scheduler README teach `.scheduler/` + `SCHEDULER_SUBDIR`.
- senechal footprint note cross-written per standing policy (senechal `c34dfaa`; push raced its nightly, rebased with content-diff verification per the 2026-07-26 race entry below).

**Milestone chain (the migration pass):**
1. *(done, this session)* realisateur migrated end-to-end — the recipe other projects copy: mv + own-doc paths + conf `SCHEDULER_SUBDIR` + sync-crontab regen + consumer sweep (`~/.local/bin` wrapper, `bin/` scripts, anything mapping project→FOCUS-path).
2. *(next — HUMAN-PRESENT BY CONSTRUCTION, queued, dispatch line in scheduler BLOCKERS.md `## realisateur`)* the remaining 10, one or a few per interactive session, wtul FIRST (its scouted scope in BLOCKERS `## wtul` is still accurate, incl. ~8 hardcoded paths in `wtul-batch.md` and its FOCUS/QUESTIONS self-references): crt, gardien, senechal, home-assistant, groc-mangr, nine-speakers, sequestria, vim-arcade, vkv-inventory after it. Each migration must run the consumer sweep — the chezz precedent shows the untracked `~/.local/bin` wrappers are where this silently breaks.
3. *(queued via front door, scheduler's own sequencing)* templates fix (`c1f9e7b`) so no future scaffold teaches the gated layout.
4. *(queued, `[batch]` row at the bottom of this file)* hygiene-lint: task-shaped-language-in-BLOCKERS.md row — the mechanical half of pattern 13.

**Park-by-default / §4.5 override, stated:** this jumps ahead of every older parked item because it unblocks the recording half of the loop the CURRENT milestone measures — nightlies literally could not write triage records to the file this repo's whole contract runs on — and because three projects hit the same wall independently inside 48 hours (the convergence signal, same as the front-door promotion below). No weight change: realisateur is already at 3 with a stated exit.

**Blockers:** none for steps 3–4 (queued in their owners' own dispatch paths). Step 2 is blocked only on a human being present — that's its nature, not a missing decision; the dispatch line exists so it can't rot silently the way the 2026-07-24 original did. wtul's FOCUS-note cross-write was DEFERRED this session per ideate.md §4 (its batch was live-dispatched 13:05 mid-session, `check-project-busy.sh` said BUSY) — carry it into the wtul migration itself.

**Postscript, same session — THIRD live occurrence of the watcher misattribution:** the ~13:15 sweep tick adopted this very session's in-progress `QUESTIONS.md` and `BUILD-DISCIPLINE.md` edits as `Human edit via scheduler` under Zach's name (`47892d0`, `62507d2` — content verified intact and exactly as authored, attribution published and unrecoverable, same as `93ad456`). Adds a same-day second data point to the write-race entry below; the scheduler-half fix (honest attribution + live-session probe) is already routed via `scheduler -i` there — this recurrence is evidence for its priority, not a new decision.

---

**2026-07-26 (interactive, Zach-directed, same session as the strategy audit below): `/cloture` — the session-closing rite — DESIGNED AND QUEUED, not built. Name chosen by Zach (asked directly, with options); build scope "record and queue only" also his explicit call.** Stated park-by-default override: not required for realisateur's current milestone, promoted by the decider himself.

**What it is:** the closing counterpart to `/ideate`'s opening posture — a general rhythm after big jobs: philosophy delta named, cross-project writes reported, insights made durable, decisions surfaced "clear to clear." Three layers, offline-first split (deterministic half before any AI, per `docs/offline-first-checks.md`):
1. **`bin/closeout-lint.sh`** (zero AI, exit 0, signals-not-verdicts): REUSE `hygiene-lint.sh`'s dirty-tree/stranded-commit checks, adding only: (a) any registered repo touched in the last N hours with unpushed commits; (b) today's dated FOCUS entry exists here and contains commit shas (mechanizes the confirm-durable-records rule); (c) if the session filed decisions, scheduler's `BLOCKERS.md` carries a block dated today.
2. **`.claude/commands/cloture.md`** (the judgment half, interactive like `/ideate`): run the lint, then — doctrine file updated or explicitly "none"; every cross-write listed with repo+sha; insights routed to doctrine or memory, never left in chat; decision-shaped residue posted to `BLOCKERS.md` under the filing project's `##` section as `> `-answerable one-liners (worked example: the 2026-07-26 five-item block, scheduler `86a49a7`).
3. **Stop hook** (the off-API enforcer, Play 1 applied to this rite): warn-only, realisateur project settings first, NOT user-level until proven; runs layer 1 at session end so the check survives prose decay.

**Admission test (Play 6), passed:** reuses hygiene-lint/BLOCKERS-append/slash-command patterns; bounded (three small files); names what it retires — the ad-hoc prose session summary as the SOLE reporting channel. **Blockers:** none — unattended-buildable here; layers 1+2 first, layer 3 only after both exist.

---

**2026-07-26 (interactive, Zach-directed): ecosystem STRATEGY audit — duplication/import/meta-ratio — PLAYBOOK.md written, milestone-declaration jobs QUEUED in five projects, gardien milestone line repaired. Audit by three read-only agents; all writes by this session, committed per-repo.**

**The deliverable:** **`PLAYBOOK.md`** (new, repo root — sibling to UNIVERSE.md/STABILITY-MILESTONES.md/BUILD-DISCIPLINE.md; governs *allocation* of code effort). Six plays, each with its mechanism: (1) mechanize BUILD-DISCIPLINE's six hook-shaped rules as real Claude Code hooks — the audit found ZERO hooks configured anywhere while every recorded discipline incident was an agent not following prose; (2) import the commodity layer (symlinks over `pacing deploy` copy-drift — `usage-paced-runner.sh`, the file cron runs every 5 minutes, was found drifted LIVE; ccusage over `token-usage.sh`; gitleaks inside hygiene-lint's harness; restic/rsnapshot under `gardien.py` when it unparks) while never churning the three audited-as-original pieces (`usage-gate.sh`, the `%%TAG`/`> ` convention, the offline-first surveys); (3) catabolize ~1,000 lines already self-labeled superseded (morning-report, build-services-view, incubation-audit.sh here, overnight-dev ×2, the two 162-line loop forks, sync-crontab's dead auto-stagger) — the queued catabolic pass's first worklist; (4) forward `_paced.conf` allocation ran 64% meta while backward commits ran ~43% — the queued milestone jobs are the parked making-projects' re-admission gates, no new code needed; (5) the top leverage builds: crt potato live-verification, a ranked cross-project answer-session surface (the only play acting directly on the rate-limiting enzyme), aedile's auto-merge gate, a shared Apps Script library (chezz/aedile/vkv-inventory hand-copy today), a SessionStart hook for `collect-feedback.sh`; (6) a standing admission test for new meta-tooling.

**Cross-writes, all committed+pushed in their own repos (tagged in each commit):** milestone-declaration jobs queued as dated `(realisateur)` FOCUS entries in **groc-mangr** (`c6a9d6d`), **nine-speakers** (`e9f6712`), **sequestria** (`4bc1b2f`), **vim-arcade** (`ec35b37`), **vkv-inventory** (`a1c8249`, on `drilldown-browse-redesign` where its FOCUS lives; entry itself warns its `enabled=0` is deliberate anti-double-dispatch, not a flag to flip). Each entry carries grounded candidate bars from a per-project read plus per-project traps (nine-speakers' stale near-term list, sequestria's self-documentation loop, vim-arcade's already-shipped 14 levels + the `d7c0e90` tmux prototype, vkv's `--consume` dead-letter gap). **gardien**: not a milestone job — its milestone was fine; the audit's UNRECOGNIZED verdict was one token (`**Current (on hold…):**` hid the literal `**Current:**` from the grep). Repaired in place, `9bc6da7`, after a fetch-rebase whose content was diff-verified per the race entry below.

**chezz: NO job queued — milestone-audit's MISSING verdict was a stale clone, not a gap.** The working checkout sat at 2026-07-25; a fetch showed chezz's own nightly declared a real `## Stability milestone` ("Autopilot loop stable", in-progress) in `.scheduler/FOCUS.md` since. Same lesson as the standing stale-clone memory: diff content before reacting to an audit verdict rendered from an unfetched checkout. Consequence for this repo's own milestone checklist: of the "remaining 7," chezz is now DECLARED by its own hand; the five queued above + aedile (declared 2026-07-24) leave the checkbox closeable once the queued jobs land.

**Blockers:** none human-only for the queued jobs (each is unattended-buildable in its own project's next pass). PLAYBOOK Play 5's items are queued where their owners already track them, not re-routed here.

---

**2026-07-26 (interactive, Zach-directed, same `/ideate` session as the bibliothecaire entry below): the FOCUS-file write race — incident recorded, clean-handling job QUEUED, not built.**

**The incident (mechanics also in the bibliothecaire entry's status-correction paragraph):** during this live interactive session, (1) `origin/main` moved twice underneath the session — first the nightly's archive push, then the watcher's own push — rejecting two pushes mid-flight; (2) a scheduler-side sweep (~10:30 tick) found the session's *uncommitted* `.claude/FOCUS.md` edits and committed them as `Human edit via scheduler` — under **Zach's name** in realisateur (`93ad456`, published, cannot be reattributed) and as `hf7y` on crt's stale mandark checkout (reset and recommitted cleanly as `81fc98f`); (3) the rebase across the nightly's archive-rename silently rewrote `archive/bibliothecaire.idea` with unrelated new content via rename-following auto-resolution — caught only by a content diff, restored in `2120677`. This is the **second live exhibit** of the interface `UNIVERSE.md` already names as unregulated (multi-writer FOCUS/QUESTIONS files); the first was the 2026-07-25 mega-burn merge conflict. Per the Ashby reading: the regulator is missing, nobody slipped.

**Queued (Zach's explicit direction this session; stated park-by-default override — not required for realisateur's current milestone, promoted by the decider himself):** clean handling for the next occurrence, split by ownership:
- **scheduler's half — routed via `scheduler -i scheduler` this session per ideate.md §5, not hand-edited:** the watcher should (a) attribute honestly — an adopted working-tree edit is `autocommit-watcher`, never `Human edit`/a human's name, or alternatively refuse to adopt `.claude/`-gated files at all; (b) probe for a live interactive session before committing/pushing from a working tree it doesn't own (flock probe, the same shape as realisateur's `bin/check-project-busy.sh`, pointed the other direction).
- **realisateur's half — buildable unattended here:** make the session discipline mechanical instead of prose (prose decays; this file's own doctrine): a small `bin/focus-commit.sh <repo> <msgfile> <files...>` that stages, commits, and pushes a FOCUS/QUESTIONS edit as ONE atomic step, and on a rejected push does the fetch→content-diff→rebase itself, then **verifies post-rebase that no renamed/archived file's content changed relative to both parents** (the check that would have caught the `archive/bibliothecaire.idea` rewrite mechanically). Session memory already carries the edit→commit→push-atomically rule, but memory is per-assistant prose — the helper is the enforcement, and it names what it retires: the bare `git commit -F` + `git push` sequence for FOCUS-file writes in this repo's own sessions.

**Blockers:** none — both halves are buildable now; scheduler sequences its own half against its current milestone.

---

**2026-07-26 (interactive, Zach-directed, `/ideate` bibliothecaire session): the librarian's vision recorded, three-way name collision resolved by MERGE, scaffold queued for nightly-batch at low weight. RECORDED AND QUEUED, no feature code.**

**Vision (decided by Zach this session, four explicit calls via AskUserQuestion):** **bibliothecaire** is the ecosystem's librarian — its own scheduler-registered project (new repo, not a realisateur subdirectory, not inside crt), with two wings: **(a)** an operations/cybernetics knowledge base seeded from `UNIVERSE.md` — closed loops, stigmergy, theories of the firm, holons; sourced quotes with real attribution from the primary literature (Ashby *An Introduction to Cybernetics*, Beer/VSM, Grassé on stigmergy, Coase, Koestler on holons — UNIVERSE.md already cites Ashby/VSM/Laozi; the other three themes are new research directions), intended to become a core philosophical resource for realisateur; **(b)** crt's book-catalog knowledge (contents/relationships/citations/further-reading) — the catalog-split idea parked in crt's `.claude/FOCUS.md` 2026-07-24, now MERGED into this project rather than staying a crt-internal fork. Consumers (crt first, realisateur later) read a published quotes/data file; they never import bibliothecaire code. **Explicitly NOT decided:** repo location/remote name, the quotes-file format and its contract with crt, how the catalog wing relates to crt's `books.db`, and whether/when realisateur's doctrine files cite back into the KB.

**Name collision, resolved (this was three-way as of this session):** (1) the "page 92" inbox drop, (2) crt's parked catalog split, (3) this new KB vision all claimed "bibliothecaire." Zach's call: the merged librarian project (2+3) owns the name; the page-92 idea becomes **quatre-vingt-douze** (the rename candidate `fable-like/projects/bibliothecaire/README.md` already proposed). This is exactly the incident the queued NAMES.md item (fable-review, 2026-07-25, bottom of this file) exists to prevent — third arrival of the same noun makes that item's case for it.

**Status correction, same session (the survey's own point — don't trust a stale mental model):** while this session deliberated, the 2026-07-26 nightly (first pass, ~00:xx) had already consumed the old page-92 `bibliothecaire.idea` and **scaffolded it as a live registered project under the contested name** (repo at `~/Documents/Projects/bibliothecaire`, `schedule/bibliothecaire.conf`, enabled at weight 1, bare remote, loop script) — flagging the collision itself in its conf and its own `.scheduler/QUESTIONS.md` ("a rename pass is cheap now, expensive later") rather than resolving it. So the rename is no longer a `git mv` of a drop; it's a rename of a live registration. **Asked directly (queue it or do it now); Zach chose: queue it in the librarian drop.** The rewritten `bibliothecaire.idea` now carries STEP 0: the next realisateur nightly renames the page-92 registration to quatre-vingt-douze (dir, bare remote, conf, `_paced.conf` line, loop script — disable during, re-enable after, weight unchanged; no crontab lines exist for it, only the generic paced runner) and folds the collision question in that project's own QUESTIONS.md, then — only after that verifies clean — scaffolds the librarian under the freed name. The first push of this entry was also rejected (`fetch first`) by that same nightly's push; rebased, and the rebase's rename-following auto-resolution (it rewrote `archive/bibliothecaire.idea` with librarian content and left a root `quatre-vingt-douze.idea` the next nightly would have re-scaffolded as a duplicate) was caught and reverted by hand before this push — the archived drop stays page-92's consumed record, untouched.

**Milestone chain, working backward from the vision:**
1. *(current — queued for nightly-batch via the new `bibliothecaire.idea` drop, register at LOW `_paced.conf` weight)* scaffold the project + first research pass: sourced quotes on the four themes from the primary literature, published as a consumable quotes file. Low weight is Zach's stated pacing call per §4.6 AND `UNIVERSE.md`'s own convergence test — three arrivals in three different shapes means the vision is still dissolving; the first case is concrete, the whole is not.
2. *(next)* crt consumes the quotes file through its **existing** idle-bait quote rotation (`pick_idle_quote`/`FALLBACK_QUOTES` in `crt/bin/crt-book-game.py`) — cross-written into crt's FOCUS.md this session as an offline-safe `[batch]` item tagged `(waiting: bibliothecaire quotes file)`. Chosen over a dedicated splash app deliberately: no new tmux window/surface (Law 3 clean), and it feeds the offline-safe lane crt's own QUESTIONS.md said was exhausted.
3. *(later, undecided)* fold in the catalog wing — the "split scope-only, greenfield, shares at most `books.db` data, never forks crt's scan/grade/STT code" variant crt's parked entry preserved as an option.
4. *(explicitly not queued)* deeper doctrine integration (UNIVERSE.md citing into the KB, quotes surfacing anywhere beyond crt's book channel).

**Blockers:** none human-only for step 1 — the scaffold + research pass is unattended-buildable once the drop reaches the nightly clone (pushed this session). Step 2 waits on step 1's quotes file, nothing else.

---

**2026-07-25 (interactive, Zach-directed, `/ideate` scheduler front-door session): three-view front door promoted to scheduler's NEXT milestone, ecosystem doctrine written (`UNIVERSE.md`), weights raised with a stated exit. RECORDED AND QUEUED, no feature code.**

**Vision:** `bin/scheduler`'s entire human surface becomes three stable, printable views mapped to the organism's three timescales — `scheduler` noargs (operations: now/next + a one-line gate/dials footer), `scheduler blockers` (obligation: the one blocked-on-you place), `scheduler <project>` (identity: detail, inline reply, reorder/reweight from there) — each view's footer printing its own mutation one-liners. Decided by Zach this session (four explicit calls): **hard fold + retire** (the ~20-verb surface collapses; superseded views become one-line redirect stubs; `usage()` ≤ ~20 lines), **static + verbs, no TUI** (printable doctrine from 2026-07-20 holds; tweaks are pasteable one-liners, not arrow keys), **dials = one-line noargs footer** (full pacing/drift/deploy detail stays under `pacing`). NOT decided: the redesign's internal implementation order, and whether `scheduler <project>` also absorbs the item-0 merged report+questions file in the same milestone or a later one — scheduler's own design call.

**Parking override, stated per §4.5:** this promotes scheduler FOCUS.md item 0 (parked 2026-07-20 under the hardening-first SEQUENCING decision) ahead of nothing older — it IS the oldest parked scheduler design — but it does jump the queue relative to the standing "only after 1-2 are genuinely solid" gate, before the current milestone's last checkbox closes. Justification: **re-derivation convergence** — Zach independently re-derived the 2026-07-20 target UX near line-for-line on 2026-07-25, the strongest crystallization signal this ecosystem produces. The principle itself (plus the anatomy, three laws, three-timescale channel rule, and the Daoist/cybernetic reading of the moving target) is now durable doctrine in **`UNIVERSE.md`** at this repo's root — written this session per Zach's "plan this from a universe perspective."

**Milestone chain:**
1. *(current, scheduler's, in-progress — unchanged)* scheduler's zero-silent-failure bar, 4/5 checked; last box (vkv-inventory `--consume` gap) is routed to realisateur and is now weight-supported work.
2. *(next, filed this session via `scheduler -i scheduler`, adopt when 1 closes)* the three-view front-door consolidation above, with an **accretion freeze effective immediately**: no view gains a legend line or new verb before the redesign; new needs go into the spec.
3. *(later, undecided)* whether the merged report+questions file (item 0's other half) and the printable-document refinement ride the same milestone.
4. *(explicitly not queued)* any TUI.

**Weights (realisateur's knob, edited directly in scheduler's `schedule/_paced.conf` this session):** scheduler 3→4 (it builds the redesign), realisateur 1→3 (owns the doctrine, the convergence-test triage change, and milestone-1's last checkbox). **Exit condition, stated in the file so it can't become permanent skim: both drop back (4→3, 3→1) when the front-door milestone is reached.**

**Queued, not built (two new mechanisms, shapes open — `UNIVERSE.md` names both as its own gaps):**
- **Re-arrival sensor** — on intake/triage, check the reservoir for a prior same-shape entry; a convergence hit is a stated promotion trigger stronger than oldest-first. Candidate: an offline `bin/` sense like the existing surveys.
- **Catabolic pass** — recurring retirement discipline (e.g. every Nth `/ideate` names one surface to shrink), generalizing BUILD-DISCIPLINE's "names what it retires" from mechanisms to text/verbs.

**Blockers:** none human-only for the recording itself. The redesign build is scheduler's paced work under the new weights; nothing here needs Zach before scheduler's next cycles pick it up.

---

**2026-07-25 (interactive, Zach-directed, `/ideate` abletim session): mandark→dexter SSH channel — verified live, licensed NARROWLY, provisioning QUEUED not built.** Context: developing the `abletim.idea` drop (Ableton + its media live on dexter; the project is a clean `_paced.dexter.conf` hardware-evidenced pin, second after crt). Zach asked whether realisateur's nightly can write into dexter. Probed rather than assumed:

- Batch-mode SSH from mandark works unattended TODAY: mandark's `~/.ssh/config` already carries a `Host dexter` block (dexter.local, user zach), key auth succeeds with no prompt, and the session lands in **Windows PowerShell** (Windows OpenSSH server), not WSL. `# verified 2026-07-25 via ssh -o BatchMode=yes dexter 'echo OK: $(hostname)'`
- From that shell, `wsl -d Ubuntu -u zach` reaches dexter's real scheduler environment (`/home/zach/scheduler/bin` listed) and the Windows media filesystem (`/mnt/c/Users/Zach/` visible). Note: the WSL **default** distro is `docker-desktop`, so a bare `wsl -e` lands in the wrong distro as root — the `-d Ubuntu -u zach` flags are load-bearing. `# verified 2026-07-25 via ssh dexter "wsl -d Ubuntu -u zach -e sh -c 'ls /home/zach/scheduler/bin; ls -d /mnt/c/Users/*/'"`
- Probe side effects, disclosed per the subagent/footprint rules: this was the first recorded mandark→dexter connection, so dexter's host key was added to mandark's `known_hosts` (`accept-new`); the first probe briefly started the stopped `docker-desktop` utility distro. No dexter files were written.

**Decision (Zach, asked directly with three options): license the channel NARROWLY.** Not git-only-plus-human-session, and not the existing full zach shell — a dedicated restricted credential, the reverse-direction analog of `dexter_mandark_deploy`. Design sketch (shape open, not decided in detail): dedicated passphrase-less keypair on mandark; forced `command=` entry in dexter's **Windows-side** `authorized_keys` wrapping a gateway (e.g. `wsl -d Ubuntu -u zach -e <gateway>`) that exposes a small verb set (register a project on dexter, run declared read-only probes against declared media paths) rather than a shell; a mandark `~/.ssh/config` alias with `IdentitiesOnly`. The `_paced.dexter.conf` concurrency rule survives intact: the gateway executes ON dexter, so dexter-host files are still written by dexter.

**Verification bar (crt/wtul precedent, both directions):** before any nightly uses it, live-verify the restricted channel BOTH does what it should AND refuses what it shouldn't — a forced command that quietly still grants a shell is the failure mode that matters.

**Queued, not built (this is `/ideate`):** provisioning is a human-present interactive task — generating key material and editing another host's `authorized_keys` is exactly what the footprint rules say never happens unattended. Until it's provisioned + verified, abletim's dexter-side registration falls back to a human dexter-side session (crt/wtul style). If the gateway generalizes beyond abletim's bootstrap into a real cross-host dispatch mechanism, that's scheduler-engine territory — route via `scheduler -i scheduler` per ideate.md §5, don't grow it ad hoc here.

**Flagged, not fixed (small, low-ambiguity):** `bibliothecaire.idea` and `secretaire.idea` sit **untracked** at the repo root — but nightly runs execute in the dedicated clone of `~/git-remotes/realisateur.git`, so untracked drops are invisible to the very consumer they're waiting for (the exact gap the 2026-07-20 `cmd_idea()` auto-commit fix closed for `scheduler -i` drops; these two were manual drops that bypassed it). `abletim.idea` is committed+pushed this session so it actually reaches the clone; the other two await Zach's say-so (commit as-is, or re-drop via `scheduler -i realisateur`). **Resolved same session:** Zach said commit as-is — both committed+pushed. Root-cause check: `scheduler -i`'s pipeline needs no fix (`cmd_commit_file` auto-commits AND auto-pushes since 2026-07-22); only hand-echoed files bypass it. Going forward: drop via `scheduler -i realisateur "<text>"`, or after a manual echo run `scheduler _commit-file <file>` — the same commit+push path, already exposed as a CLI subcommand for exactly this.

---

**2026-07-25 (`/nightly-batch`, ~11:50 pass): one inbox artifact, investigated and routed to scheduler's own backlog, not scaffolded.**

Only artifact at the repo root was `Investigate-adding-a-door-a-re-20260725-095956.idea` — a remote idea-intake ("door") request for `scheduler -i`, so drops don't have to originate on mandark. Per step 3's own telltale, this names `scheduler -i` directly: it's an addition to the `scheduler` project's own mechanism, not raw material for a new sibling project. Read `~/.local/bin/scheduler`'s `cmd_idea()` to confirm the premise (today's intake is 100% local-filesystem — no network path exists) and scoped three intake options (SSH-only via a dedicated bare repo reusing dexter's existing git-shell-key pattern; a small authenticated HTTP endpoint; email/SMS relay) with a recommendation and the senechal-relevant threat-model note (an internet-reachable file-editing endpoint is the one to harden hardest, if chosen).

Applied park-by-default triage against scheduler's current DECLARED milestone (zero-silent-failure unattended dispatch) — a new intake surface isn't required to reach that bar, so this is `(parked)`, not built. The scoping itself (not code) matches the artifact's own explicit ask ("investigated, not built blind") and the already-recorded-but-unbuilt cross-project-research-agent vision (2026-07-25 entry above) — one concrete instance of that shape run by hand. Routed via the front door (`scheduler -i scheduler "..."`, per the established convention for scheduler-owned design questions — see the 2026-07-24 BLOCKERS.md-taxonomy entry using the same route) rather than a direct cross-write, since this is scheduler's file to design. Committed + pushed by that command in scheduler's own repo. Source artifact archived here as `archive/Investigate-adding-a-door-a-re-20260725-095956.idea`.

Three offline surveys re-run fresh, no new findings changing this pass's scope: `ecosystem-survey.sh` unchanged vision-debt ranking (still topped by the four 2026-07-18 home-assistant entries); `hygiene-lint.sh` 24 total FLAGs (23 crt exec-bit/silent-pipe pre-existing + 1 senechal `base64` test-fixture false positive, same composition as prior passes); `milestone-audit.sh` 8 declared/6 missing/0 no-focus, unchanged from the last recorded count. QUESTIONS.md's two open blocks (svc-vaporwave aedile/vkv-inventory recovery, ideate-mode `UserPromptSubmit` hook) both still carry no `> ` reply — left untouched, genuinely waiting on the human.

---

**2026-07-25 (interactive, Zach-directed): mechanical guard for the commit-message policy — DECIDED, QUEUED NOT BUILT, narrow form only.** Today's policy addition (BUILD-DISCIPLINE failure pattern 12 + the `git commit -F` discipline + a new stamped checklist row, commit `fd04011`) is a *reminder*, which this file's own doctrine says decays. Zach's call, verbatim: **"Worth building, in the narrow form — deny-with-message PreToolUse hook, not a lint row, not a wrapper script. The cost is roughly one small session and a few milliseconds per Bash call; the benefit is coverage of unattended runs that the prose policy structurally cannot reach."**

**Scope (what "narrow form" rules in and out):**
- **In:** a Claude Code `PreToolUse` hook on `Bash` that inspects the command string and *denies with an explanatory message* when it sees a `git commit -m` (or `--message=`) whose message contains shell metacharacters that a double-quoted context would evaluate — backtick, `$(`, `${` — or embedded newlines. The denial message names the fix (`write the message to a file, use git commit -F <file>`), so the deny is instructive rather than just obstructive.
- **Explicitly out, per the same call:** a `hygiene-lint.sh` row (it can't see how a message was constructed — it only ever sees committed text, after the damage), and a `git` wrapper script (it changes a system-wide tool for every human invocation to catch an agent-shaped mistake).
- **Why a hook and not prose:** the failure mode belongs to unattended runs, where no one reads the policy doc. A `PreToolUse` deny is the only layer that sits in the actual path a nightly run takes.

**Design notes to settle when built (not decided now):**
- Where it lives — user-level `~/.claude/settings.json` (covers every project, matching that the mistake is agent-shaped and not repo-specific) vs. per-project. Leaning user-level; confirm before installing, since it's a cross-project behavior change.
- False-positive shape: a message legitimately containing a `$` (e.g. a dollar amount) must not be blocked forever with no escape. Prefer matching only the genuinely-evaluating forms (backtick, `$(`, `${`) over any `$`.
- Same guard arguably belongs on `gh pr create --body`/`gh issue create --body`, per the discipline's own wording. Second, not first.

**Cost/benefit as accepted:** one small session to build; a few ms per Bash call thereafter. **Blockers:** none — this is unattended-buildable in this repo, no human-only step.

**Note for whoever builds it:** this is also a live instance of the `[batch] hygiene-lint: stamped-checklist drift` row at the bottom of this file — today's commit added an 11th checklist row to the BUILD-DISCIPLINE template and to realisateur's own CLAUDE.md, so every other project's stamped copy is now one row behind again.

---

**2026-07-25 (interactive, Zach-directed): manual concurrent burst test ("mega burn near quota deadline") — run, results + groundwork documented, mechanism itself RECORDED NOT BUILT.** Full test writeup, per-project results, and groundwork conclusions live in scheduler's own `DESIGN-NOTES.md` 2026-07-25 entry (same date) — not duplicated here, this is the pointer. Short version: Zach asked to bypass `usage-paced-runner.sh`'s flock and fire `chezz`/`gardien`/`senechal`/`scheduler` concurrently by hand, excluding `home-assistant` (physical side effects) per his instruction and `realisateur` (self-conflict with this live session) on my own call. Cross-repo concurrency ran clean; the one real collision was a `.scheduler/FOCUS.md` merge conflict between `scheduler`'s own dev cycle and a concurrent dexter-side interactive session touching the same file — handled safely (merge aborted, nothing lost, one commit stranded on `paced/2026-07-25` pending a by-hand resolve). Vision for a real automated mega-burn mode, milestone chain toward it, and the concrete gaps found (no quota-aware gating in this manual test, `chezz`'s staleness check silently no-op'd, exclusion list needs to be structural not ad hoc) are all in the scheduler entry — this is a genuinely new mechanism, recorded and queued per `/ideate`'s own contract, not built this pass.

**2026-07-25 (interactive, Zach-directed): cross-project research agent — proposed, RECORDED NOT BUILT, per `/ideate`'s own record-and-queue contract for a genuinely new mechanism.** Same session as the dexter blockers correction below and the `wtul`-on-dexter controlled test (see scheduler `_paced.dexter.conf` commit `0366936`). Zach asked for "a research tool during batch" and confirmed the intent directly: a **cross-project research agent** — something that investigates a specific open question and writes findings back into a project's own FOCUS/QUESTIONS, not a general web-search grant to every nightly-batch run.

**Vision:** an on-demand, realisateur-owned research pass — given one specific open question (tagged in a project's `QUESTIONS.md`, e.g. a `RESEARCH:` prefix), spin up a **read/web-only** one-shot agent (Read/Grep/WebSearch/WebFetch — explicitly no Bash/Write/Edit outside its own scratch dir) that investigates only that question and appends its findings as a `>` reply, reusing the existing `collect-feedback.sh`/`>` convention rather than inventing a new one. It never decides — same posture as everything else here (realisateur perceives → judges → records; the human still decides). This is a natural extension of the already-proven offline-first-checks pattern (`docs/offline-first-checks.md`: build the deterministic version first, layer `claude` on top only for the part that needs judgment) — here the "judgment" is synthesizing external info a local codebase read can't supply.

**Milestone chain, working backward:**
1. *(next, not started)* Prove the shape by hand on ONE real open question that genuinely needs outside info (not something answerable by reading this repo) — a natural candidate once one exists is whichever dexter/wtul quota-race observation ends up needing an external comparison point.
2. *(after that)* If useful, wire it as a real invocation (`scheduler -i <project> --research "<question>"` or a dedicated command) with the tool-scope restriction enforced structurally, not just by prompt — same rigor as `home-assistant.conf`'s existing `BATCH_ALLOWED_TOOLS` restriction pattern.
3. *(explicitly not queued yet)* Any automatic wiring into nightly-batch's own Orient step for every `RESEARCH:`-tagged question — only after step 2 is proven on real cases, not designed ahead of it.

**Blockers:** none technical — this is a "do we want this, and what's the tool-scope guardrail" design decision, not a build blocker. Revisit as a dedicated pass, same as the git-as-archive and file-structure-normalization items already parked this way in this file.

---

## Stability milestone

**REACHED 2026-07-24** — see below. Original bar:
**realisateur reliably turns inbox drops into scaffolded, scheduler-registered projects AND triages every idea active/parked/waiting against each project's milestone (park-by-default), with all three offline surveys wired into every pass** — status: reached
Done when:
- [x] inbox → infer → scaffold → scheduler-register loop runs unattended (proven: 6 projects scaffolded)
- [x] `bin/milestone-audit.sh` exists and the convention is documented (`STABILITY-MILESTONES.md`)
- [x] the offline surveys are wired into both command files (`milestone-audit` added to `/ideate` + `/nightly-batch`; nightly-batch already ran ecosystem-survey + hygiene-lint)
- [x] park-by-default triage APPLIED to real ideas for at least one full pass (2026-07-24: gardien/senechal/wtul each got a real milestone + explicit active/parked tagging against it — git-history-on-RAID and keybinding-parsing parked, naming-registry an explicit named exception, wtul's five deeper-integration items parked)
- [x] build-discipline baseline stamped into every registered project (2026-07-24: crt's dirty tree cleared, then stamped. **Correction, same night:** aedile was WRONGLY marked an edge case here — "no git repo, migrated/defunct" was never actually checked before being written down (same lesson as tonight's credential-gap mistake). It's real and active: tracked as a subdirectory of the `wavebucks` monorepo (`.git` lives at the parent, not `aedile/` itself — a real bug in `bin/scheduler`'s own repo-detection, routed to scheduler via the front door). Stamped its build-discipline checklist same night once corrected; its own milestone content is a separate per-project judgment call, queued below like crt's, not done in this pass)

**New milestone, per STABILITY-MILESTONES.md's Lifecycle (a reached bar means set the next one, not stop):**
**Current:** every scheduler-registered project with a real git repo has a declared `## Stability milestone` of its own, AND park-by-default triage has held across more than one live pass (not just its first exercise) — status: in-progress
Done when:
- [x] gardien, senechal, wtul, scheduler each have a declared milestone (2026-07-24)
- [x] crt got its own dedicated `/ideate crt` pass (2026-07-24) — milestone set (core voice loop + Book Game funnel reliable on potato), park-by-default triage applied against it (dual-tier/Vosk STT eval, bare-metal migration, refactor/docs/polish, wake-judge autonomy, Gemini fallthrough, dexter NPU parked; see crt's own `.claude/FOCUS.md`). This is also the pass that satisfies the next line's "different project than gardien/senechal/wtul" requirement.
- [x] home-assistant got its own dedicated `/ideate home-assistant` pass (2026-07-24) — milestone set (core automations reliable + remote HTTPS access), park-by-default triage applied against it (new device integrations, phased sun-matched circadian rework, kitchen task-lighting design, half-bulbs-off question, wall-switch alternatives, cosmetic entity re-id parked; see home-assistant's own `.claude/FOCUS.md`).
- [ ] the remaining 7 (chezz, nine-speakers, sequestria, vim-arcade, vkv-inventory, groc-mangr, **aedile**) get theirs — incrementally, one per-project judgment call at a time (NOT a bulk-invent — aedile is a real nonprofit Apps Script project — DM-tier bump/triage tuning, scenario library, institutional-memory design — with enough of its own domain nuance to deserve a real pass, not a guessed bar)
- [x] at least one more live `/ideate` pass exercises park-by-default triage on a DIFFERENT project than gardien/senechal/wtul, confirming the mechanism generalizes rather than being a one-off (crt, 2026-07-24, see above)
- [ ] scheduler's own milestone (2026-07-24, see its `.scheduler/FOCUS.md`) reaches `in-progress` → visibly progressing, not stalled — a live signal the engine side of tonight's split is actually working, not just designed

Ideas beyond this bar are PARKED by default (see realisateur/STABILITY-MILESTONES.md):
git-as-archive (Backlog), the `scheduler -i`→realisateur triage-routing hook, and the BLOCKERS.md taxonomy unification (routed to scheduler 2026-07-23) are all `(parked)` — real, past this milestone, revisit when it's reached.

---

**2026-07-24 (`/nightly-batch`, ~23:10 pass): `/ideate` workflow revised — inbox note was about realisateur's own process, not a new project.**

Inbox held one artifact, `revise-the-ideate-workflow-or-20260724-221900.idea`,
naming `ideate` itself as the subject (per step 3's own telltale) — routed
as process feedback, not scaffolded as a sibling project. Full research
and reasoning written to a new root doc, `IDEATE-WORKFLOW-REVISION.md`,
per Zach's own explicit ask ("give me a .md summary... somewhere I can
see it"). Three complaints, three outcomes:
1. **"Vision → milestones → blockers should be ideate boilerplate"** —
   fixed. `ideate.md` §4 now has a named "Standard entry shape" section
   making that structure the default template for any real-direction
   FOCUS.md entry, modeled on this file's own 2026-07-24 dexter entry
   (the example that prompted the ask in the first place).
2. **"ideate seems to only run once"** — partially fixed at the prose
   level (`ideate.md`'s intro now says the surface/ask/record/queue
   posture holds for the rest of that conversation, not just the first
   response), but this is a real Claude-Code-slash-command limitation, not
   fully solvable with markdown — a harder fix would need a
   `UserPromptSubmit` hook re-asserting ideate-mode each turn. Not built
   this pass — infra-scoped, Zach's call, see the new QUESTIONS.md entry.
3. **"drift from ideate over long sessions, hard to enforce with prose"**
   — same root cause and same partial fix as #2; no separate mechanism
   exists to build here beyond what's already queued in the question
   below.

Source artifact archived as `archive/revise-the-ideate-workflow-or-20260724-221900.idea`.

---

**2026-07-24 (`/ideate`, interactive, Zach-directed): dexter parallelism vision/milestone/blockers pass — triggered by Zach running a scheduler self-build session ON dexter itself, live, during this pass.**

**Vision (partial promotion, asked directly — see scheduler's own `.scheduler/FOCUS.md` "vision promoted... partial" entry same date for full text, mirrored short here):** "dexter becomes the primary host where unattended jobs run" is now a real active direction, not just gardien's 2026-07-24 parked dream — that QUESTIONS.md item is answered, see gardien's own `.claude/QUESTIONS.md`. Explicitly NOT decided yet: cloud VMs, remote GitHub-agent triggers, or a hard mandark-sunset date — those stay open, separate, later. Explicitly declined: naming "many parallel jobs on dexter via VMs/WSL" as the next-next milestone — too far ahead per Zach, revisit once the current single-peer MVP is proven.

**Milestone chain, working backward from that vision:**
1. *(current, in-progress, DESIGN-NOTES.md 2026-07-24)* — dexter self-build: register as a second host, own `_paced.conf` subset (crt pinned, the one hardware-evidenced case), own crontab tick, drop crt from mandark's `_paced.conf` so nothing double-dispatches. This is the session Zach is running right now.
2. *(next, not yet started)* — observe `run.log` on both boxes for the accepted quota-race risk (two independent `usage-gate.sh` probers can both see slack and both dispatch, overshooting between probes) actually behaving safely in practice, not just in theory.
3. *(after that, undecided)* — whether more projects pin to dexter (gardien/senechal's permission-scope gate, not network-locality, is still an open question per scheduler QUESTIONS.md) and whether dexter becomes the RAID's physical host (blocked on a TB2 cable/adapter per gardien's own FOCUS.md).
4. *(explicitly not queued yet)* — multi-VM/parallel-job architecture on dexter, cloud VMs, GitHub remote-agent triggers, mandark retirement. Real ideas, deliberately left fully open past step 3.

**Blockers clearable now/tonight (from scheduler's own QUESTIONS.md, human-only steps — nothing here is unattended-buildable until these are confirmed):**
1. Confirm dexter's Claude Code login is on the SAME primary Max account as mandark — the whole shared-quota premise silently breaks otherwise. (Human/interactive OAuth step — likely already done if the self-build session is running.)
2. Confirm dexter has working git push access to crt's local bare remote (`/home/zach/git-remotes/crt.git` from mandark's filesystem — confirm the equivalent path/reachability from dexter).
3. Re-confirm crt's OctoPrint (`192.168.0.43`) is reachable from dexter's NEW WSL2 environment specifically — the 2026-07-20 confirmation was against a different (full-VM) networking setup, not guaranteed to carry over to WSL2's NAT.
4. Zach's call, still open: does gardien/senechal need dexter locality, or does their existing permission-scope gate mean they're irrelevant to the machine question? Left unpinned in scheduler's FOCUS.md, not guessed.

**Status correction, 2026-07-25 (realisateur, interactive, re-surveyed against scheduler's own FOCUS.md/QUESTIONS.md/DESIGN-NOTES.md rather than left stale) — all four blockers above are CLEARED, not open:**
1. **Cleared** — `usage-gate.sh` runs on dexter and reads the shared account's live 5h/7d windows; confirmed same-account login (scheduler QUESTIONS.md, "RESOLVED BY THE 2026-07-24 dexter self-build," item 1).
2. **Cleared, but the resolution differs from what this entry assumed.** dexter does not reach mandark's bare-repo path directly — mandark's `/home/zach/git-remotes/crt.git` is now exposed over SSH (`openssh-server` on mandark, a git-shell-only `dexter_mandark_deploy` key, `crt.conf`'s `REPO_URL` repointed at `ssh://mandark-lan/...`), and dexter clones through that. Live-verified from dexter itself (`git ls-remote`, host-key fingerprint cross-checked against mandark's real key) — commit `845d1e5`, full writeup DESIGN-NOTES.md 2026-07-24 "crt live-verified from dexter, enabled." `crt` is now `enabled=1` in `schedule/_paced.dexter.conf` and was dropped from mandark's `_paced.conf` in the same change (`2e0602a`) — dexter runs it, mandark does not, no double-dispatch.
3. **Cleared** — 0% ICMP loss, TCP 80 open, OctoPrint-identifying HTTP 302 (`x-clacks-overhead` header) confirmed from dexter's actual WSL2 environment, not just assumed to carry over (scheduler FOCUS.md 2026-07-24 dexter self-build entry).
4. **Answered 2026-07-25** (scheduler QUESTIONS.md) — no pinning. gardien/senechal stay parallel stewards of their own systems; revisit only if real hardware/network evidence for either shows up, per `_paced.dexter.conf`'s own stated pinning bar.

Net effect: the milestone-chain step-1 self-build above is DONE, not in-progress — dexter and mandark are two independently-dispatching, independently-pulling schedulers running in parallel tonight (mandark's normal ~8-participant rotation; dexter running `crt` alone). Step 2 (watch `run.log` on both boxes for the accepted quota-race risk) is the live open item now, not these four.

**File structure: DECIDED — normalize now, ecosystem-wide (not deferred, not opportunistic-only).** Asked directly; Zach chose a dedicated pass now, since a clean known layout makes each project's dexter clone path predictable rather than adding a new inconsistency to migrate around later. **Queued, not built this pass** (this is a real blast-radius action — moving directories that scheduler's `schedule/*.conf` `PROJECT_REPO_PATH` fields point at, for live registered projects, needs sequencing with config updates so dispatch doesn't silently break):
- Real inconsistency, surveyed this pass: `~/Documents/Projects/` holds most active projects (crt, gardien, groc-mangr, nine-speakers, realisateur, senechal, sequestria, vim-arcade) plus a stray loose `FOCUS.md`; `~/Documents/Project Archive/` — despite its name — holds several currently-active scheduler-registered projects (chezz, home_assistant, scheduler itself) alongside genuinely archived non-project files (PDFs, scores, old application docs); `~/Documents/wtul` sits directly under `Documents/` on its own; `~/Documents/vkv/{wavebucks/aedile, inv/inventory-app}` is a third pattern again.
- Proposed target shape (not yet approved in detail — flag before executing): all scheduler-registered *active* projects under one root (`~/Documents/Projects/`), non-project archive material (the PDFs/scores/docs currently sharing `Project Archive`) moved somewhere clearly not named "Project" (e.g. `~/Documents/Archive/`), each move paired with the matching `schedule/<project>.conf` `PROJECT_REPO_PATH` update in the same pass so scheduler dispatch never points at a stale path even transiently.
- The stray `~/Documents/Projects/FOCUS.md` loose file at the root (not inside any project directory) is worth a direct look before the cleanup pass — likely leftover/misplaced, not a real per-project file.
- Not done this session (interactive-only ideate scope) — queued as the next concrete realisateur-led build once the dexter MVP blockers above are clear, since this doesn't need to happen before dexter's self-build finishes, and touching every registered project's config is exactly the kind of action worth a dedicated, careful pass rather than a rushed one alongside tonight's dexter work.

---

**2026-07-24 (`/ideate`, interactive, Zach-directed): aedile/vkv-inventory carved out of realisateur's direct cross-write privilege — front-door only, going forward.** Zach asked directly how realisateur's ideation reaches these two vaporwave projects, given zach@mandark's existing local copies (`schedule/aedile.conf`/`vkv-inventory.conf`'s `PROJECT_REPO_PATH`, `/home/zach/Documents/vkv/{wavebucks/aedile,inv/inventory-app}`) are scheduled to be sunset/closed. Both projects' actual unattended dispatch already migrated off mandark to `svc-vaporwave`'s own fresh-clone-and-push checkout (2026-07-20) — the mandark copy has been a read/write target for realisateur's own ideation only, not load-bearing for the automation itself. Presented three options (fresh-clone-and-push like svc-vaporwave, a dedicated persistent vision-mirror clone, or route through scheduler's `-i` front door like an external project) — **Zach chose the front door.** Decided: once mandark's copies close, realisateur stops direct `FOCUS.md`/`QUESTIONS.md` cross-writes into aedile/vkv-inventory and queues ideation for them via `scheduler -i <project> "<text>"` instead, same as chezz's own `/ideate` must for anything outside itself. Every other registered project keeps the direct-cross-write privilege — this carve-out is scoped to just these two, because of their specific account/remote topology (svc-vaporwave-owned, not zach's own working copy). Recorded as an explicit exception in `.claude/commands/ideate.md`'s step 4 (not silently applied) so future `/ideate` passes read it as a standing rule, not something to re-derive. No code changed; `PROJECT_REPO_PATH` in `schedule/*.conf` is unchanged for now (still points at mandark, since those copies haven't actually closed yet) — this is a heads-up decision for when they do, not an immediate migration.

**2026-07-24 (`/ideate aedile`, interactive, Zach-directed): the entry above is SUPERSEDED same day — front-door carve-out reverted to a documented fallback, not the default.** Zach followed up asking to scope the "scrub `.claude/` files off GitHub" idea into a real `/ideate aedile` pass. Investigation found the premise already moot: `wavebucks`' root `.gitignore` already ignores `.claude/` ("Claude Code local state, per-developer, not shared"), and `git log --all --diff-filter=A` across the entire repo confirms no `.claude/*` file was EVER committed there — nothing to scrub. aedile's real vision docs were deliberately renamed to `aedile/.scheduler/FOCUS.md`/`QUESTIONS.md`, which ARE git-tracked and already flow through svc-vaporwave's normal clone with zero extra sync mechanism. This directly undercuts the prior entry's premise: the mandark-copy-closing concern doesn't block a direct cross-write at all, since the real docs live in git, reachable via a fresh clone with zach's own existing GitHub access regardless of whether mandark's copy exists. **Reverted:** direct cross-write is again the default for aedile/vkv-inventory (vkv-inventory was never actually in the same boat anyway — `inventory-app.git` is its own dedicated repo, not shared with Tyler, and already tracks plain `.claude/` normally, so "same shape as aedile" doesn't apply to it). The `scheduler -i` front door stays documented as an available fallback in `ideate.md`, not deleted, per Zach's explicit "keep as option." `.claude/commands/ideate.md` step 4 updated to reflect this correction directly (not left as two contradictory entries to reconcile later).

**Real bug found in the same pass, queued not fixed:** `bin/milestone-audit.sh` already supports a `SCHEDULER_SUBDIR` override (used by `scheduler` itself, whose own FOCUS.md also lives outside `.claude/`) but `schedule/aedile.conf` never sets it, so the audit defaults to `.claude/FOCUS.md`, finds nothing, and has been misreporting aedille as "FOCUS: none / no milestone" every pass — it actually has a real 21KB `.scheduler/FOCUS.md`. Separately, `scheduler`'s own `questions/aedile.md` symlink points at the wrong file (`aedile/.claude/QUESTIONS.md`, empty/untracked) instead of the real, tracked `aedile/.scheduler/QUESTIONS.md` — `focus/aedile.md`'s symlink is correct, `questions/aedile.md`'s isn't. Proposed fix (one line, `SCHEDULER_SUBDIR=".scheduler"` in `aedile.conf`, then regenerate symlinks): flagged to Zach as small/low-ambiguity per `/ideate` step 2, not applied without confirmation.

---

**2026-07-24 (`/nightly-batch`, ~21:10 pass): inbox empty, nothing to build.**

Repo root held only realisateur's own scaffolding again -- no dropped
artifact to infer or wire up. All three offline surveys re-run fresh:
`bin/hygiene-lint.sh` still 21 total FLAGs, same composition as the last
recorded pass (20 pre-existing crt exec-bit/silent-pipe issues + the one
senechal `base64` test-fixture false positive) -- not this run's project
to fix. `bin/milestone-audit.sh` now shows **8 declared/6 missing/0
no-focus**, up from the last-recorded 7/6/1 -- aedile now carries a real
DECLARED milestone (scenario-library-as-PR-gate replacement) and
scheduler's own no-focus edge case has resolved too, both from other
sessions' work since the last nightly pass, not this one -- observed,
not acted on. `bin/ecosystem-survey.sh`'s vision-debt ranking unchanged,
still topped by the four 2026-07-18 home-assistant entries.
QUESTIONS.md's one open block (aedile/vkv-inventory svc-vaporwave
recovery) still carries no `> ` reply -- left untouched, genuinely
waiting on the human cross-account access step. Park-by-default triage
not exercised this pass (no live new-project/new-addition candidate in
tonight's empty inbox).

**2026-07-24 (`/nightly-batch`, ~20:00 pass): inbox empty, nothing to build.**

Repo root held only realisateur's own scaffolding again -- no dropped
artifact to infer or wire up. All three offline surveys re-run fresh:
`bin/hygiene-lint.sh` now shows 21 total FLAGs (up from 20) -- 20 still
crt's own pre-existing exec-bit/silent-pipe issues (already flagged, not
touched), plus one new FLAG in senechal (`test_senechal.py:296`, a
`base64`-encoded test fixture literal tripping the secret-value
heuristic) -- not this run's project to fix, noted here per the
signals-not-verdicts stance so it doesn't go unrecorded.
`bin/milestone-audit.sh` unchanged at 7 declared/6 missing/1 no-focus, no
reached triggers. `bin/ecosystem-survey.sh`'s vision-debt ranking
unchanged, still topped by the four 2026-07-18 home-assistant entries.
QUESTIONS.md's one open block (aedile/vkv-inventory svc-vaporwave
recovery) still carries no `> ` reply -- left untouched, genuinely
waiting on the human cross-account access step. Park-by-default triage
not exercised this pass (no live new-project/new-addition candidate in
tonight's empty inbox).

**2026-07-24 (`/nightly-batch`, ~16:12 pass): inbox empty, nothing to build.**

Repo root held only realisateur's own scaffolding again -- no dropped
artifact to infer or wire up. All three offline surveys came back
unchanged from the last recorded pass: hygiene-lint's 20 FLAGs are still
crt's own pre-existing exec-bit/silent-pipe issues (already flagged,
not touched); milestone-audit still 7 declared/6 missing/1 no-focus, no
reached triggers; vision-debt ranking still topped by the four
2026-07-18 home-assistant entries and the 2026-07-19/20 scheduler
entries, nothing new or older surfaced. QUESTIONS.md's one open block
(aedile/vkv-inventory svc-vaporwave recovery) is still genuinely
waiting on the human cross-account access step -- no `> ` reply, left
untouched. Park-by-default triage not exercised this pass (no live
new-project/new-addition candidate in tonight's empty inbox).

**2026-07-24 (`/nightly-batch`, ~14:45 pass): inbox empty, nothing to build.**

Repo root held only realisateur's own scaffolding again -- no dropped
artifact to infer or wire up. All three offline surveys came back
unchanged from the last recorded pass: hygiene-lint's 20 FLAGs are still
crt's own pre-existing exec-bit/silent-pipe issues (already flagged,
not touched); milestone-audit still 7 declared/6 missing/1 no-focus, no
reached triggers; vision-debt ranking still topped by the four
2026-07-18 home-assistant entries and the 2026-07-19/20 scheduler
entries, nothing new or older surfaced. QUESTIONS.md's one open block
(aedile/vkv-inventory svc-vaporwave recovery) is still genuinely
waiting on the human cross-account access step -- no `> ` reply, left
untouched. Park-by-default triage not exercised this pass (no live
new-project/new-addition candidate in tonight's empty inbox).

**2026-07-24 (`/nightly-batch`, ~13:12 pass): inbox empty, nothing to build.**

Repo root held only realisateur's own scaffolding (`README.md`,
`SCHEDULER.md`, `STABILITY-MILESTONES.md`, `BUILD-DISCIPLINE.md`,
`FOCUS-FORMAT.md`, `CLAUDE.md`, `.gitignore`, `.claude/`, `archive/`,
`bin/`, `schedule/`, `.git/`) -- no dropped artifact to infer or wire up.
All three offline surveys came back unchanged from the last recorded
pass: hygiene-lint's 20 FLAGs are still crt's own pre-existing exec-bit/
silent-pipe issues (already flagged there, not touched); milestone-audit
still 7 declared/6 missing/1 no-focus, no reached triggers; vision-debt
ranking still topped by the four 2026-07-18 home-assistant entries and
the 2026-07-19/20 scheduler entries, nothing new or older surfaced.
QUESTIONS.md's one open block (aedile/vkv-inventory svc-vaporwave
recovery) is still genuinely waiting on the human cross-account access
step -- no `> ` reply, left untouched per the answer-only-acts-on-a-reply
contract. Park-by-default triage not exercised this pass (no live
new-project/new-addition candidate in tonight's empty inbox).

**2026-07-24 (`/nightly-batch`, ~10:08 pass): inbox cleared (two artifacts, both stale reference snapshots), no new project scaffolded.**

Two artifacts at the repo root: `COMPUTE-STICK-MIGRATION.md` and
`PI-MIGRATION-STATUS.md`, both explicitly self-described as "copied in
from the `crt` project as reference context," not new ideas. Checked
against crt's own current state before archiving, per park-by-default
triage (an addition to an existing project, judged against its current
milestone): crt already carries a near-identical
`COMPUTE-STICK-MIGRATION.md` in its own repo (this inbox copy differs
only in copyedits/a header line -- same content, same conclusion:
abandoned, migrated to a Pi), and the compute-stick/bare-metal migration
is already explicitly PARKED in crt's own `.claude/FOCUS.md` ("explicitly
excluded from this bar by Zach 2026-07-24 -- a separate, later goal, not
required for the core loop or Book Game to be reliable"). The Pi-status
note (flashed Pi 3B, account split in progress, keyboard-layout snag) is
an early-stage snapshot from 2026-07-22 that's since been superseded by
crt's own `POTATO.md`, which documents potato (Pi 3B+) as the fully live,
working console hardware today. Nothing left to build or decide -- both
archived as `archive/COMPUTE-STICK-MIGRATION-20260722.md` and
`archive/PI-MIGRATION-STATUS-20260722.md`. All three offline surveys came
back unchanged from the last recorded pass (crt's 20 hygiene FLAGs are
its own pre-existing exec-bit/silent-pipe issues, already flagged, not
touched this pass; milestone-audit still 7 declared/6 missing/1 no-focus;
vision-debt ranking still topped by the four 2026-07-18 home-assistant
entries). **QUESTIONS.md housekeeping:** verified crt's own working tree
directly (`git status` on `~/Documents/Projects/crt`) -- it's clean now,
crt's own nightly runs already committed the WIP + stamped build-
discipline (`d8fbe7b`, `a22ac77`, same night) since that question was
flagged. Removed the stale crt-dirty-tree question from QUESTIONS.md as
resolved (not acting on a `> ` answer -- there wasn't one -- just retiring a
flag whose underlying condition no longer holds, verified against real
state rather than assumed). The aedile/vkv-inventory recovery question
remains open, untouched, genuinely waiting on the human svc-vaporwave
access step. Park-by-default triage was exercised this pass (both
artifacts judged against crt's current milestone/parked-status), even
though the outcome was "nothing to build."

---

**2026-07-24 (`/ideate`, interactive, Zach-directed): new BUILD-DISCIPLINE.md rule — "declare your host footprint" — plus senechal's mission widened to own it.** Zach asked directly ("senechal should take some ownership... nobody owns this right?") about `dexter` accumulating unattributable dev cruft (scripts/autostart entries) from `crt`'s work, with no ecosystem mechanism naming or tracking it. Two decisions, asserted together per Zach's own framing ("both... give the build discipline rule... but have senechal own knowledge of the script world of all of Zach's shared hosts"):
- **BUILD-DISCIPLINE.md**: added failure pattern #6 (cruft on shared hosts) and a new mechanical discipline — any project installing onto a shared host (`dexter`, `mandark`, future hosts) must declare it in its own FOCUS.md, remove it when retired — plus a new checklist row. A real `hygiene-lint.sh` check (cross-referencing declared footprints against senechal's actual host journals) is queued, not built, this pass.
- **senechal's mission widened** (recorded in senechal's own FOCUS.md/QUESTIONS.md, cross-committed there): from mandark-only journaling to owning knowledge of the script/autostart world across *all* of Zach's shared hosts, with cleanup itself as "a mix" — direct action where senechal owns it, delegation to project-specific batch jobs via scheduler where a project (like crt) should clean up its own mess. This is explicitly a **named exception** past senechal's current stability milestone (mandark watch-list breadth + redaction coverage), same shape as the naming-registry exception — approved directly by Zach, not milestone-widening by drift. Implementation (how senechal reaches a Windows host like dexter, the actual cleanup-vs-delegate split per case) is genuinely open design, not decided or built this pass — record and queue, not build, per `/ideate`'s own contract.

---

**2026-07-24 (`/nightly-batch`, ~04:00 pass): inbox cleared (one artifact, already resolved), no new project scaffolded.**

Only inbox artifact was `Correction-to-the-chezz-wtul-c-20260724-032158.idea` -- its full content (chezz/wtul deploy keys verified working, no credential gap, real cause is the spend-limit-cutoff pattern) was already folded into this file's own credential-gap-correction entry below (commit `a09c5b1`, same night, ahead of this pass). Nothing left to do but archive it -- no new decision, no new build. All three offline surveys came back substantively unchanged from the last recorded pass (crt's 24 hygiene FLAGs still pre-existing/already-flagged there; milestone-audit still 5 declared/8 missing/1 no-focus, no reached triggers; vision-debt ranking still topped by the three 2026-07-18 home-assistant entries). QUESTIONS.md: both open blocks (crt dirty-tree, aedile/vkv-inventory recovery) still unanswered, left untouched. Park-by-default triage not exercised this pass -- no live new-project/new-addition candidate in tonight's inbox.

**2026-07-24 (`/nightly-batch`): inbox cleared, no new project scaffolded, chezz/wtul FOCUS.md formatting fixed.**

Ran the three offline surveys first (clean: crt's 27 FLAGs are its own
pre-existing dirty-tree/exec-bit/silent-pipe issues, already flagged,
not touched). QUESTIONS.md: two already-answered/already-folded blocks
(bare-remote chown, incubation-audit reweight) removed as processed; the
crt-dirty-tree block is still unanswered, left in place. Five inbox
artifacts at the repo root, all already-decided or realisateur's-own-
process notes rather than new ideas needing a fresh project:
`Build-the-stability-milestone-*.idea` (already built, see the section
above), `look-at-Document-Project-Archi-*.idea` (already reconciled,
`/ideate` shipped 2026-07-22, remainder stays parked), `Spec-out-a-more-
principled-eco-*.idea` (already routed to scheduler 2026-07-23),
`incubation-decisions-2026-07-22.conf` (applied then superseded
2026-07-23) — all archived. `FOCUS-md-formatting-compliance-*.idea`
(flagged by scheduler 2026-07-22: chezz's FOCUS.md was prose/HTML-
comment-only, wtul had no real FOCUS.md) was genuinely actionable:
wrote `FOCUS-FORMAT.md` (canonical spec, matches what
`extract_next_items()` in `bin/scheduler` actually parses), added a
real `## Priority queue` section to chezz's FOCUS.md (existing comment
content untouched), fleshed out wtul's FOCUS.md into a thin pointer
into `ROADMAP.md` (kept as the real detail doc, to avoid drift).
Committed in both projects' own repos, tagged `(realisateur)`; **could
not push either** — both use real GitHub remotes (`git@github.com:hf7y/
{chezz,wtul}.git`) this environment has no publickey credentials for
(same "prefer local bare remote, GitHub needs real credentials" bar
`SCHEDULER.md`/this file's Backlog section already names) — commits sit
local, will push on each project's own next scheduled dispatch, or push
by hand if that's wanted sooner. **Milestone checklist note:** this pass
did NOT exercise park-by-default triage against a live idea (nothing in
tonight's inbox was a genuine new-project or new-addition candidate) —
that checklist item stays unchecked, not falsely marked done.

**2026-07-24 (this sprint — vision + concurrency fix + first live triage pass, sequenced per plan):**

- **Concurrency fix shipped (realisateur's half).** `bin/check-project-busy.sh`
  (flock-probes a project's own scheduler job locks, zero AI cost) wired
  into `/ideate` step 4's cross-write bullet — don't edit another
  project's FOCUS.md/QUESTIONS.md while its own automation holds the
  lock. Scheduler's half (dispatch/push robustness) is routed, not
  hand-fixed — see below.
- **Root cause: CORRECTED 2026-07-24, was wrong the first time.** Original
  claim (this same night, earlier): chezz/wtul's stranded commits were a
  credential gap (dispatch environment lacking GitHub SSH access). That
  was never actually tested against the real keys before being routed to
  scheduler — a later pass caught it (zach: "don't they have deploy?"),
  verified directly (`ssh -T`, a real test push), and found chezz/wtul
  already have working, write-verified deploy keys. **No credential gap
  exists.** The real explanation for the original stranded commits is the
  already-documented account-wide spend-limit-cutoff pattern (2026-07-20):
  a run's commit lands, the push doesn't happen because the run got cut
  off by quota exhaustion mid-cycle, not because credentials were
  missing. Real fix (already queued in scheduler's own FOCUS.md): make a
  stale/incomplete push loud in `scheduler status`/`sweep.log`, not new
  credentials. **Lesson for next time:** verify a diagnosis against real
  state (an actual `ssh -T`/test push here) before routing it to another
  project as fact or writing it into memory — a plausible-sounding
  explanation that fits the symptom isn't the same as a tested one.
  `bin/check-project-busy.sh` (below) is unaffected by this correction —
  it solves a different, real problem (cross-writing into a live run's
  files) regardless of what was actually wrong with the pushes.
- **First real park-by-default triage pass.** gardien, senechal, and
  wtul (the three projects this sprint's design-fork decisions touched)
  each got their first `## Stability milestone` — the prerequisite the
  checklist above was waiting on. Hit and fixed a real parser trap along
  the way: the `**Current:**` bar+status must be one physical line, not
  wrapped Markdown — documented in `STABILITY-MILESTONES.md` now so the
  next 8 missing-milestone projects don't repeat it.
- **Remaining sprint work, split per tonight's "both, sequenced" call:**
  - *Triage-hardening:* **DONE, same session.** Both bootstrap exit
    conditions were met (convention exists + a live pass proved park-by-
    default out), so `schedule/_paced.conf`'s `scheduler`/`realisateur`
    weight dropped 3→1 — stated explicitly in that file's own comment
    and in the commit, not a silent reweight.
  - *Scaffold-hardening:* 8 more projects still show `missing` in
    `milestone-audit.sh` (chezz, crt, home-assistant, nine-speakers,
    sequestria, vim-arcade, vkv-inventory, groc-mangr). Per the standing
    "not a bulk-invent" rule, populate incrementally during each
    project's own `/ideate <name>` pass — crt specifically blocked until
    its dirty-tree flag (still open in QUESTIONS.md) is cleared.
- **Blockers only the user can clear:** crt's dirty tree (needs a human
  or crt's own batch to commit-or-clean it — realisateur can't touch it
  meanwhile); whether the dispatch environment actually gets GitHub
  credentials is scheduler's design call but the credential material
  itself (deploy key generation, `known_hosts`) needs a human step no
  agent should do unattended.

**2026-07-24 (`/ideate` ecosystem pass — decisions recorded, nothing built):**

- **scheduler-milestone open question: RESOLVED — engine participates.**
  Decided the engine should get a stability milestone too, not be treated
  as exempt mechanism. Routed via `scheduler -i scheduler` (front door,
  per step 5) rather than hand-edited — scheduler itself now owns whether
  that lands as a `.scheduler/FOCUS.md` `## Stability milestone` section
  or a `milestone-audit.sh` fix to also read `.scheduler/`.
- **gardien's git-history-on-RAID fork: DECIDED — git remote + partial
  clone.** Folded into gardien's own FOCUS.md/QUESTIONS.md
  (`(realisateur)`-tagged). Real synchronicity worth naming here too:
  this is the same underlying shape as this repo's own parked
  "git-as-archive" idea below (empty working root, full history lives in
  git) — if gardien builds the remote/partial-clone mechanism first,
  revisit git-as-archive against it rather than designing from scratch.
- **senechal's "keeper of names and places" fork: SCOPED, not just
  decided.** Naming-convention registry only (new file in senechal's own
  repo, senechal's to name); canonical-shared-location half (lilypond
  library, GitHub tidy-up) explicitly split out as a separate later idea.
  Folded into senechal's own FOCUS.md/QUESTIONS.md.
- **wtul's metadata-API either/or: DECIDED — Discogs, token already in
  hand.** Only part (a) of that 2026-07-18 bundle; (b)/(c)/(d) (catalog
  spreadsheet, printer model, web-photo/OCR) remain genuinely open.
- **Flagging, not fixing:** chezz and crt both show stranded local
  commits from FAILED nightly runs (not pushed to origin, per `scheduler
  status`) — separate from crt's already-flagged dirty-tree stop.
  home-assistant's last run divergence check also printed an empty
  remote-hash field, possibly a reporting glitch rather than a real
  issue. None acted on this pass.
- **Vision-debt state, unchanged:** oldest open dated items are still the
  three 2026-07-18 home-assistant entries — same as last check, not
  drained, not obviously grown either (no new dated items older than
  those surfaced this pass).

**2026-07-24: stability-milestone convention BUILT + wired — active follow-ups (queued, not done):**

- **Milestone population is standing per-project triage work, NOT a
  bulk-invent.** `milestone-audit.sh` shows **11 projects `missing`** a
  `## Stability milestone` section. Populate each incrementally during that
  project's own `/ideate <name>` or nightly triage pass — the bar is a
  per-project judgment call, not something to invent in one sweep. Do the
  projects realisateur is about to build against first, and the
  stable-vs-dream-flagged ones (nine-speakers/sequestria/senechal) early,
  since their `_paced.conf` weight already depends on that judgment.
- **The 2 `no-focus` cases are edge cases, not population targets:**
  `aedile` (no git repo — migrated/defunct) and `scheduler` (keeps its
  FOCUS under `.scheduler/`, not `.claude/`, because it's the *engine*, not
  a scaffolded project). `milestone-audit.sh` assumes `.claude/FOCUS.md`, so
  it reads scheduler as no-focus — a known limitation. **Open question:**
  does the engine participate in the milestone convention at all, or is it
  exempt? Decide before treating scheduler's no-focus as a gap to fix.
- **Reweight decision (the one open pacing call):** scheduler + realisateur
  stay at weight 3 until park-by-default triage runs on **≥1 live pass and
  proves out**, then drop toward 1 per `_paced.conf`'s exit note. Waiting on
  evidence, not on a decision.

**2026-07-23 (`/ideate` — vision-debt strategy, standing doctrine):**
The honest number (scheduler DESIGN-NOTES 2026-07-23): intake is zero-cost
and unbounded (`scheduler -i`), clearing is quota-gated and shared 12 ways,
so the backlog diverges at **−6 to −10 items/week regardless of build
speed**. Conclusion, decided this session:

- **This is a queue-stability problem, not a throughput one.** You cannot
  out-build a free, unbounded idea faucet. Weight bumps slow divergence;
  they never reverse its sign. **Pruning (admission control) is the only
  lever that changes the sign** — it moves arrivals *out of the active set*
  at near-zero cost instead of building them down.
- **Backlog count is the WRONG health metric.** A reservoir fed for free
  *should* grow (already settled: chezz 2026-07-20, a growing backlog is
  the expected shape). Vision debt is only debt when parked ideas
  masquerade as active commitments. Track instead: **(1) active/build-now
  set size per project (cap it), (2) is the oldest *build-now* item
  draining.** Parked-reservoir size is not tracked as debt.
- **Primary discipline = milestone-gated parking.** Each project gets **one
  current stability milestone** (its "stable v1 core" bar — this is the
  recovered "ready to go on its own"/VSM status). Realisateur's triage
  default becomes: *is this idea within the current milestone? If not →
  PARK it* (visible, zero dev cost). Parking is the load-bearing act, not
  building. QUEUED next build (nightly-batch, not this pass): a per-project
  stability-milestone convention + the park-by-default triage step.
- **The weight-3 bump is a BOOTSTRAP, not steady-state.** scheduler +
  realisateur at weight 3 only buys time to stand the pruner up. **EXIT:
  drop both toward 1 once the milestone convention exists AND triage parks
  by default** (mirrored in `_paced.conf`'s comment so it can't silently
  become permanent skim on operational slack).
- **Synchronicity to unify, not build twice:** this "active vs. parked vs.
  waiting" status need is the *same* as the parked `Spec-out-a-more-
  principled-eco` idea (BLOCKERS.md blocking/waiting/fyi taxonomy). One
  status vocabulary should serve vision items and blockers alike — routed
  to scheduler via `scheduler -i scheduler` this session (it's a
  scheduler-convention proposal, front-door per ideate.md §5).

**2026-07-23 (`/ideate` reform pass — three standing decisions):**

- **Identity: realisateur is a steward with sensory organs, not a second
  engine.** The doctrine is "scheduler runs things; realisateur
  perceives → judges → records." Its three offline deterministic auditors
  (`bin/hygiene-lint.sh`, `bin/ecosystem-survey.sh`, `bin/incubation-
  audit.sh`) stay in this repo *deliberately*: they are realisateur's
  senses, not scheduler mechanism misfiled here. The test for what belongs
  in realisateur vs. what goes through scheduler's `-i` front door: does it
  feed a *judgment* (perception/triage/prioritization → realisateur) or is
  it *engine mechanism* the ecosystem runs regardless of judgment
  (timing/dispatch/templates → scheduler)? The auditors inform judgment;
  they don't act on their own. This resolves the "pure mechanism living in
  the vision repo" tension by naming the seam rather than moving code.

- **Weighting reframes around "near a stable core" vs. "bigger still-forming
  dream" (supersedes the incubation-audit graduation framing).** `_paced.conf`
  weight is higher for ideas close to a defined, near-term shape (safe to
  iterate fast unattended) and lower for ideas likely to morph before
  anything built survives (slower pace, NOT "don't build"). Applied
  2026-07-23: **nine-speakers 2→1** — its physical-rig half is a forming
  dream, so the 2026-07-22 "graduation candidate = clean build momentum"
  call conflated momentum with nearness-to-stable. **groc-mangr stays 2**
  (conventional app, no forming-dream flag; re-confirm at next audit). The
  broader incubating/graduation weights the audit applied remain a separate
  open question — see QUESTIONS.md.

- **git-as-archive: consciously parked (see Backlog bullet below).** The
  empty-root-when-idle aesthetic is a real "needs its own design pass," not
  a near-term build. Recorded as deliberately deferred so it stops reading
  as forgotten.

**2026-07-22: `/ideate` added — realisateur's interactive vision/triage
counterpart to `/nightly-batch`, cross-project by design.** Refines the
scheduler/realisateur relationship being worked out this session:
scheduler stays a pure mechanism (timing, pacing via `_paced.conf`'s new
`weight` field — see `docs/priority-weight.md` in the scheduler repo);
realisateur owns interpreting vision — feature requests, cross-project
synchronicities, and "stable build vs. bigger dream" pacing judgments
(vision debt, named 2026-07-20 in `chezz/.claude/commands/ideate.md`
4.5, from the user's own words: *"my ideas outpace implementation of
stable versions so the target is always moving"*). `/ideate` is
interactive-only (surface/ask/record/queue, never build/scaffold — that
stays `/nightly-batch`'s job), works ecosystem-wide by default or scoped
to one project via `$ARGUMENTS`, and is the vehicle for the cross-write
relationship: realisateur writes tagged `(realisateur)` entries directly
into another project's own FOCUS.md/QUESTIONS.md, distinct from that
project's own `(nightly-batch)`/`(bug-sweep)` entries. `bin/ecosystem-
survey.sh` (new, offline-first, no AI — reuses `scheduler status
<project>` per registered project plus a "oldest open dated idea"
ecosystem ranking) backs both this command's step 1 and
`/nightly-batch`'s own orient step now. See `.claude/commands/ideate.md`
for the full shape, including the explicit oldest-first-override
principle (a newer idea CAN jump an older parked one when justified —
state why, don't reorder silently).

Current focus: process whatever's sitting in the inbox (repo root artifacts
not yet archived — see `.claude/commands/nightly-batch.md` step 1 for how
to tell) and turn each viable idea into a real, scaffolded project wired
into the scheduler ecosystem the same way realisateur itself is.

realisateur has no web tracker (like `crt`), so there is no
`NIGHTLY:`-flagged-report convention here — scope is purely this file plus
whatever's physically sitting in the inbox.

**Policy: build maximally autonomously.**

- Pick the most reasonable interpretation of a dropped artifact and act on
  it — scaffold the project, don't just write up what it might be.
- A new project gets its own directory under `~/Documents/Projects/`, its
  own git repo, and (if it's an agent/codebase project that would benefit
  from unattended iteration) its own scheduler registration, following
  exactly the process `SCHEDULER.md` documents for realisateur itself.
- Archive the source artifact once acted on (or once a real decision was
  made not to act on it) so it's not re-processed next time.
- Flag what got built and why in `.claude/QUESTIONS.md` and in the report
  — the flag IS the review point, not a request to build.

- **2026-07-22 (from wtul questions-pane diagnosis):** `vkv-inventory`'s
  `command-nightly-batch.md` never runs `collect-feedback.sh --consume`
  against its own `.claude/QUESTIONS.md`, the same append-only-reply gap
  just fixed in wtul's and the scheduler's own nightly-batch commands (see
  scheduler's `.scheduler/FOCUS.md` backlog for the full writeup). Add the
  same Orient-step fix to vkv-inventory's command file, or confirm it's
  already covered elsewhere before skipping it.

## Realisateur's own process (not inbox ideas — see nightly-batch.md step 3)

- **2026-07-20: "Look into scheduler's idea logic, unite with the habit of
  echoing ideas into text files here" — already solved, no project
  needed.** `scheduler -i realisateur "idea text"` (`~/.local/bin/scheduler`,
  `cmd_idea()`) already special-cases realisateur: instead of writing into
  a FOCUS.md backlog section like every other registered project, it drops
  a real `<slug>-<timestamp>.idea` file at this repo's root — the exact
  same artifact shape as manually echoing a note here. The CLI is the
  unification; nothing new to build. One real gap the CLI's own output
  names: it does NOT `git add`/`commit`/`push` for you, so a dropped idea
  sits invisible to the scheduler's dedicated clone until someone commits
  it by hand (this bit the first three ideas — see `f8f244d`/`7886409`).
  Worth raising with Zach directly: either fold the commit+push into
  `cmd_idea()` itself (small, safe, lives in `~/.local/bin/scheduler` —
  outside this repo), or just keep it a manual step. Source note archived
  as `archive/look-into-scheduler-s-idea-log.idea`.
  **Follow-up, same day: fixed on the scheduler side** — `cmd_idea()` now
  auto-commits (never auto-pushes) for the realisateur path too, same as
  every other project's idea-drop.

- **2026-07-20 (Zach, via `scheduler -i realisateur`): realisateur is
  meant to eventually own abstract visioning across projects, not just
  scaffolding — see the inbox item this generated
  (`look-at-Document-Project-Archi-*.idea`, chezz's `/ideate` command as
  the reference model) for the concrete proposal.**
  **PARTIALLY SHIPPED 2026-07-23 (reconciled):** the
  `/ideate`-for-every-project half of this landed 2026-07-22 (built when
  prompted, not unprompted) — see this file's top entry and
  `.claude/commands/ideate.md`. What remains OPEN from the source idea:
  whether `scheduler -i` should route through realisateur to triage
  whether a dropped note is a next-action-item vs. a vision to incubate
  (the "is scheduler's `-i` proper?" fork) — still unbuilt, still parked
  per scheduler's "hardening first" priority; do not build that
  `-i`→realisateur hook unprompted. What IS worth carrying forward
  regardless of that larger design fork: the "vision debt" pattern named the same session (ideas
  arrive faster than any implementation cadence can stabilize them) —
  named explicitly in chezz's own `ideate.md` now. If realisateur ever
  does take on abstract-visioning ownership, this pattern — making the
  gap between ideation and stable implementation visible rather than
  letting a queue grow silently — is a concrete design input for that
  role, not just chezz's problem.

- **2026-07-24 (`/ideate`): BLOCKERS.md sweep-ownership made explicit; two
  orphaned vim swaps investigated, no data lost.** Zach hit two issues
  doing a manual clear of scheduler's `BLOCKERS.md`: (1) what looked like
  a simultaneous-edit conflict, fixed by hand via git; (2) many entries
  reading as stale despite being answered days ago. Root cause of both:
  two vim sessions (pids 437104, 472803, both dead by the time this
  session checked) had `BLOCKERS.md` open around the same time and
  neither exited cleanly, leaving `.BLOCKERS.md.swo`/`.swp` behind —
  recovered both non-destructively (`vim -r ... -c 'w! <scratch>'`),
  diffed against the committed file, confirmed no real unsaved content in
  either (one was a duplicate-header recovery artifact, the other an
  older pre-edit snapshot); both deleted. Separately: `BLOCKERS.md`'s own
  header already said resolved entries are cleared by hand, but never
  said whose hand — nothing in `collect-feedback.sh`/the auto-commit vim
  hook aggregates INTO the file or prunes a RESOLVED/RETRACTED marker
  automatically, so entries just accumulate until someone sweeps them.
  Made that explicit in `BLOCKERS.md`'s own header (scheduler commit
  `5041986`): the sweep is `/ideate`'s own triage job. Pruned this
  session's stale set (aedile crontab, chezz/wtul deploy-key retraction,
  crt OctoPrint/VM-hardware-check/barrel-diameter) into
  `## Recently resolved` as a worked example.

## Reusable pattern worth applying to scaffolded projects: offline-first checks

**2026-07-22 (scheduler side):** `bin/scheduler status <project>` was
built as the reference implementation of a pattern worth carrying into
any project realisateur scaffolds — see the scheduler repo's
`docs/offline-first-checks.md` for the full writeup. Short version: build
a "how's this doing" check entirely out of deterministic scripts (git
status/ahead-behind/diverged, `bin/collect-feedback.sh` against any
report/blockers file, an awk pass over a QUESTIONS-style file, a log
tail) with **zero AI cost by default**, then layer AI on top only as
strictly optional extras — a one-shot read-only `claude -p` summary
(`--claude`) or a live session preloaded with the same report
(`--interactive`). If a new scaffolded project ends up with its own
FOCUS.md/QUESTIONS.md/report convention (i.e. follows this repo's own
shape), consider giving it the same three-mode status check rather than
defaulting straight to "spin up claude to check in" — reuse
`bin/collect-feedback.sh` directly (it's generic) and copy/source
`report_divergence()` from `bin/scheduler` for the git-health part.

## Backlog (recovered 2026-07-20 — see note below)

Zach's own reply, written directly into `~/reports/realisateur/LATEST.md`
after the first real nightly run, was NOT actually wired to reach this
project (that file gets wholly overwritten each run, and only
`.claude/QUESTIONS.md`'s `> ` convention is contractually read/acted on —
see `scheduler`'s own `docs/feedback-tags.md`). Recovered here by hand
before it was lost to the next overwrite:

- **Idea-incubation "steward"/"husbandry" logic, eventually.** For now,
  ideas auto-registering with the scheduler on scaffold (current
  behavior) is fine. Later: spend a few cycles establishing whether an
  idea is actually viable BEFORE promoting it to full autonomous
  development — aware of the Stafford Beer viable-systems-model framing.
  Wants an explicit project status meaning "ready to go on its own."
  Related, also later: senescence/retirement logic — a way to retire a
  project either because it never got off the ground or because it
  matured out of active development.
- **Prefer git-as-archive over a literal `archive/` folder, eventually.**
  Ideal aesthetic: this repo's root is empty when no ideas are currently
  incubating — an idea lives in the working tree only while incubating,
  then the fact that it was ever here lives in git history rather than a
  permanent `archive/` directory. Scheduler-owned files (FOCUS.md etc.)
  staying under a dot-prefixed folder (`.scheduler/` per the model
  scheduler itself uses) helps keep that clean look. Not designed
  further than this — a real "how" needs its own pass.
  **2026-07-23 (`/ideate`): consciously PARKED, not dropped.** Decided
  this is a genuine design pass of its own (idea-lifecycle in git history
  vs. a visible folder, plus moving scheduler-owned files under
  `.scheduler/`), not something to half-build inline. Revisit as a
  dedicated pass; the aesthetic goal above stands as the target.
- **The only real stop-and-wait bar: something that can't be reverted.** A
  commit, a branch, a new scheduler registration, a local bare git remote
  — none of these block you. What does: a real message to a person outside
  this loop, spending real money, deleting something with no backup, or
  registering against a REAL GitHub remote with credentials that could leak
  (prefer a local bare remote per `SCHEDULER.md` unless a GitHub remote is
  clearly already the right call). If genuinely unsure, that's the
  `.claude/QUESTIONS.md` case — but err toward "revertible, proceed."

## Fable review (2026-07-25)

<!-- Appended by realisateur/fable-like/inject-suggestions.sh. Full context: fable-like/FABLE_REPORT.md. Triage these like any dated entries; delete freely. -->

- **2026-07-25 (fable-review):** split doctrine from journal — standing decisions (identity seam, vision-debt math, autonomy bar) into a DOCTRINE.md edited in place; .claude/FOCUS.md (56KB) stays a lean dated log with monthly roll-ups
- **2026-07-25 (fable-review):** create NAMES.md (with senechal) and check it before every scaffold — two unrelated bibliothecaires exist right now (crt's parked catalog split vs the inbox "page 92" idea)
- **2026-07-25 (fable-review):** build the two queued lints (hygiene-lint shared-host-footprint row; milestone-format check that says "join these two lines" instead of UNRECOGNIZED) — own doctrine: guards over reminders
- **2026-07-25 (fable-review):** file-structure normalization is stalling because it's batch-sized; execute one move per /ideate pass, scheduler out of "Project Archive" first
- **2026-07-25 [batch] hygiene-lint: stale verified-claims row** — BUILD-DISCIPLINE.md now requires that a written claim about system state carry `# verified <date> via <command>` (`3be6629`). Make it mechanical rather than a reminder: `bin/hygiene-lint.sh` flags any `verified <date>` stamp older than ~7 days, and flags config comments that assert system state with no stamp at all. The incident: an unstamped "confirmed 2026-07-24: no crontab exists there" in `schedule/_paced.conf` outlived its truth by a day and became an ecosystem audit's #1 finding.
- **2026-07-25 [batch] hygiene-lint: stamped-checklist drift** — the BUILD-DISCIPLINE checklist gained three rows on 2026-07-25; copies already stamped into each project's CLAUDE.md now lag the baseline and nothing detects the divergence.
- **2026-07-26 [batch] hygiene-lint: task-shaped entries in BLOCKERS.md** — mechanical half of BUILD-DISCIPLINE pattern 13. Flag lines in scheduler's `BLOCKERS.md` matching task-shaped language (`filed for an async pass`, `not done`, `not completed`, `TODO`, `next step:` without a `> ` answer or an OBLIGATION/dispatch pointer) — BLOCKERS.md is not a work queue, so anything task-shaped sitting there is pattern-13 rot by definition. Signals-not-verdicts like every other row. Incident: the 2026-07-24 `.scheduler/` migration decision sat undispatched there for 2 days while three projects re-derived it.
