# The ecosystem, 2026-07-17 → 2026-08-01

*A survey commissioned by Zach, 2026-08-01. Eight parallel readers over
architecture, sensor data, the prose vault, recorded failure modes, live
wiring, the bashify move, milestones, and git history — each adversarially
verified, then re-probed by hand for anything that would change what to do
next. Every number here was derived by a command, not quoted from prose.*

---

## 1. What was built

The idea is an estate with organs — a body that senses its own state, judges
it, dispatches work against it, and remembers. The naming carries it all the
way down: `senechal` (knows the house), `gardien` (keeps copies),
`bibliothecaire` (the librarian), and a vocabulary of French verbs for the
actions — `arpente`, `sonde`, `ausculte`, `juge`, `garde`, `fauche`,
`recense`. The genesis note is explicit about the biology
(`realisateur/the-cloture-ritual-should-reti-20260729-030821.idea`,
2026-07-29 03:08): *"projects should sunset their own AI usage through their
build. Organs should seek to decentralize their nervous system."*

The spine as it exists on disk:

| organ | job | state |
|---|---|---|
| **realisateur** | perception and judgment; owns the doctrine | alive, 409 commits |
| **scheduler** | metabolism — conf registry, `sync-crontab.sh`, paced runner | alive, 549 commits, dark |
| **senechal** | estate health; `estate-health.sh` | alive, the one working sensor |
| **gardien** | durability — backup, `fauche`, git hygiene | alive, **backups dead 8 days** |
| **basheur** | de-animation engine; MECHANIZED vs AGENT contracts | alive, **single-copy** |
| **ecosim** | instrumentation; the BLIND-vs-silence thesis | alive, sensor ticking |

Around that spine sits the newest layer: **25 bash verbs** across eight
`git worktree` checkouts on `bashified` branches, 24 symlinked onto `PATH`.

Does the code honor the metaphor? The naming, thoroughly. The claim
underneath it — decentralized sensing, organs that know their own state — no.
There is one organ that senses reliably, an aggregate sensor verdict that has
read `BLIND` on 14 of 14 recorded runs, and a 25-verb nervous system with
**zero machine consumers**: no cron line, no systemd unit, no git hook, no
scheduler conf invokes any verb. The body was given nerves and they were never
connected to muscle.

## 2. The arc

**Prehistory (~2026-07-05).** The oldest in-ecosystem content date is
`senechal/ESTATE.md:419` — a note about machine-wide config nobody had told
senechal about. The problem predates the solution by twelve days.

**Phase 1 — agents (07-17 → 07-22).** wtul 07-17, scheduler 07-18,
realisateur and crt 07-19, vim-arcade/groc-mangr/nine-speakers/sequestria
07-20, gardien and senechal 07-22. Seventeen projects eventually register.
Each gets a nightly batch loop, a FOCUS.md, a QUESTIONS.md.

**Phase 2 — doctrine (07-23 → 07-27).** The pivot's trigger is documented:
`crt/DEV-DISCIPLINE-RETROSPECTIVE-2026-07-23.md` becomes patterns 1–5 of
`BUILD-DISCIPLINE.md` (4,145 bytes on 07-23). On 07-25 a subagent pushes
`main` and leaves 76 uncommitted lines in `sync-crontab.sh`; the subagent
rules enter CLAUDE.md the same day. 07-26: `PLAYBOOK.md` Play 1 finds *"the
entire build discipline is prose, and zero Claude Code hooks exist anywhere."*

**Phase 3 — the burst (07-28 → 07-29).** The hottest two days: scheduler 94
commits on 07-28, 71 on 07-29; realisateur 54/52; senechal 59. ecosim is born
07-28 with a pre-registered study. Then two things inside 36 hours define
everything after. At **2026-07-29 14:26:01** the crontab is emptied for "THE
PLAY run 3" — deliberately removing the deus ex machina to see whether the
scheduler brings its own dispatch back up. And `bin/stamp-agent.sh`
bootstrap-stamps realisateur's and scheduler's FOCUS.md, **deleting their
`## Stability milestone` sections as collateral** (scheduler `d35f49f`: 28
insertions, 4,444 deletions; realisateur `7289527`).

**Phase 4 — de-animation (07-30 → 08-01).** `THE-UNWIRING.md` theorizes the
move on 07-30: self-dev parks, work does not. Commit rate falls off a cliff —
scheduler 71 → 4. The vault is created 2026-07-31 19:51. On 08-01, 253 notes
are consigned, `fauche` clears five repos off disk (~1.1 GB), `WAITING-ROOM.md`
becomes the parking ledger, and at 10:55:01 one cron line is reinstalled.

Fifteen days, ~1,882 commits across surviving repos. About 98% authored by the
agent identity `hf7y`; realisateur is the sole inversion (380 "Zach" vs 36
"hf7y") — which is exactly the repo where judgment lives.

## 3. What worked

**`git worktree` for the bashify branches.** The best structural decision in
the ecosystem. Each project's verb layer lives on a `bashified` branch in a
sibling worktree, so no working tree was disturbed, the "total purge" of agent
references is safe *because* everything removed is one `git log main` away in
the same object store, and there is no second repo to sync. All eight branches
clean and 0/0 against `origin/bashified`.

**The man page as contract, with a runnable gate.** `bashify check` scores
nine concrete rows and exits 7 on failure; `bashify amend` refuses its own
author. Own suites pass (5/5, 8/8). Twelve of 25 verbs score 9/9. Doctrine
with a real gate behind it rather than a paragraph.

**senechal's `estate-health.sh`.** The one working sensor, finding real
damage: gardien's backups failing (distinguished from merely stale), root at
91%, three "agreed retiring, STILL INSTALLED" items. It distinguishes SKIP
(could not check) from OK — the exact BLIND-vs-silence distinction ecosim's
whole thesis argues for, implemented by hand in a different project.

**The consign mechanism.** `consign-prose` writes provenance frontmatter, then
**re-reads the bytes off disk and re-hashes** rather than self-reporting, and
refuses any overwrite by whole-file comparison. All notes have intact markers.
And `fauche` refuses to clear a repo whose prose has no vault note — so
ordering was *forced by the tool*, not remembered by the operator.

**Instruments that falsified their own authors.** ecosim's `prereg.py` denied
"finding" status to the study's sharpest result because no hypothesis was
registered for it. `THESIS.md` carries a CORRECTION block on top of the wrong
text rather than an edit, because "the wrong version is the evidence." The
BASHIFY-REPORT headline was withdrawn by two independent contract runs. This
habit is real and it is rare.

**Git hygiene.** 12/12 repos clean, 12/12 at the live GitHub tip verified by
network `ls-remote`, 0 ahead / 0 behind — with exactly one exception (below).
The 07-25 dirty-tree incident produced a rule that held.

## 4. What did not

**(a) Bugs.** Four installed verbs — `arpente`, `epluche`, `lance`,
`ausculte` — exit **0 on every flag including `--nonsense`**. This is a
regression introduced 2026-08-01 by `4a9dc85` and `1b54a0e`, whose own commit
messages say the defect was *"found by running each flag rather than by reading
the code"* — and which then shipped four verbs where running the flag returns
0. Before those commits they exited 4.

`reach-lint.sh --strict-reach` prints `== 5 FLAG(s) ==` and **exits 0**.
`closeout-lint` and `hygiene-lint` do the same with 1 and 61 FLAGs. Anything
gating on them sees green — BUILD-DISCIPLINE's own first row failing inside
realisateur's guards.

The installed `/ideate` at `~/.claude/commands/ideate.md:75` hardcodes
`/home/zach/Documents/Project Archive/scheduler/bin/scheduler`, a path that
does not exist. Source fixed 2026-08-01 10:25; installed copy is from 07-27.
Nobody reran the installer.

**(b) Designs that did not survive contact.** The single-shared-runtime claim:
`lib/verb.sh` has forked into **four** versions in three days; only 2 of 8
worktrees match the skel. The "no agent names anywhere" purge guarantee is
**false on 7 of 8 branches** that publish it — the guard runs only inside
`bashify emit`, and every branch has taken hand-commits since. And 14 of 25
verbs reach into the parent's un-bashified tree at hardcoded absolute paths:
`arme`, held up as the exemplar, reads its entire input from
`$LEGACY_ROOT/schedule/_monitor.conf`. **The bashified branches are a front
door on the old layer, not a replacement.**

The one-milestone-per-project model was abandoned without being retired:
realisateur's FOCUS.md runs seven hand-written milestone chains, two reusing
M0–M3 numbering for unrelated subjects. Zero milestones anywhere are
`reached`; 3 of 30 Done-when boxes are checked; and realisateur and scheduler
have **no milestone at all**, because their own stamping tool deleted the
sections on 07-29.

**(c) The meta-pathology.** `BUILD-DISCIPLINE.md` grew from 4,145 bytes and 5
patterns on 07-23 to **45,182 bytes and 20 patterns on 08-01** — 11× in nine
days, while `bin/` went 3 → 23 scripts. Roughly half the patterns have a guard
that runs. Four rows print the sentence *"until it lands, this row is prose,
and prose decays"* about themselves; two have carried it for four and five
days with nothing built. All 42 `.idea` files were filed inside a 44-hour
window on 07-28/29 and the inbox has not moved since.

The sharpest single artifact: `BUILD-DISCIPLINE.md:676` argues against
symlinking doctrine because *"a dangling symlink doesn't error, it just makes
the discipline silently absent, which is the first failure pattern this very
file names."* `~/.local/bin/silence-audit` is today a dangling symlink into a
deleted worktree, while nine CLAUDE.md files require `silence-audit --strict`
clean.

## 5. What we have now

**Alive and wired.** One cron line (`ecosim-sensor-tick`, `*/30`, reinstalled
08-01 10:55 — four fires ever). `senechal-health.timer`, hourly, working.
Three gardien timers firing nightly *into failure*. Three bibliothecaire
**system** timers (intake every 15 min) that no parking document mentions.
`hermes-gateway.service`, running permanently out of `~/.hermes`, declared in
no project's footprint. `crt-whisper-server.service` — a **system** unit,
active, listening on `0.0.0.0:8991` for a repo deleted this morning. And
`front-door-watch.service`, active since 07-29, executing
`Projects/front-door/bin/watch` — **a path `fauche` deleted on 08-01** —
looping every 120 seconds.

**Alive and unwired.** The entire 25-verb layer, ~3,600 lines of shell, 24
PATH symlinks, no machine consumer. The vault: 253 notes, ~360k words, pushed
clean to `github.com/hf7y/ecosystem1-vault`, but in **no** gardien backup set.

**Dark.** All six paced participants are `enabled=0`. The paced runner last
ticked 2026-07-29T14:25:24. 220 open ideas sit behind the closed valve.

**Still dispatching, unnoticed.** `svc-vaporwave`'s crontab was never emptied.
Verified in syslog: `aedile` fired at **2026-08-01T03:00:01** and
`vkv-inventory` at **04:00:01** — today, and every night through the freeze —
from lines tagged `# scheduler:<project>:BATCH` whose generating confs no
longer exist. THE PLAY's premise ("nothing dispatches") was false on the one
account it could not read, and its own log admits the gap was *"declared in
scope, NOT enforced."*

**Regenerating garbage.** 15 `*-nightly-batch-loop.sh` files in `~/.local/bin`
— regular files, not symlinks, **all rewritten 2026-08-01 10:21** — of which
**8** name projects with no directory on disk (aedile, chezz, crt, groc-mangr,
home-assistant, nine-speakers, sequestria, vkv-inventory). Something ran after
the reap, from the pre-reap project list.

**The single most important thing broken: durability.** `gardien.service` has
failed every night since 2026-07-24 — `[FAIL] config not found at
~/.local/share/gardien-nightly-batch/repo/gardien.json` — the one failure
`THE-UNWIRING.md` §5 names as unrecoverable. `gardien-git-hygiene.service`,
the job built to find unpushed repos, is failed on the same cause. And because
it is dark, nothing found this:

> **basheur has no GitHub repository.** `git ls-remote
> https://github.com/hf7y/basheur.git` → *Repository not found*. Its only
> remote is a bare repo at `~/git-remotes/basheur.git` on the same 91%-full
> disk. `~/git-remotes` is in **no** backup set. basheur is the one live
> self-dev agent and the declared gate (U0) on the entire 17-project park.

This is not theoretical and it is not static. basheur was at `05d7666` when
this survey began and is at `9e17804` now: **two commits — `residue: verb-page
attempt 022/023` at 12:50 and 12:52 today — exist in exactly one directory on
one disk.** A concurrent session is actively generating work into the only
repo with no second copy.

## 6. The central tension

Every failure above is the same failure at a different altitude: **this
ecosystem's detection is excellent and its actuation is absent.**

senechal has printed the exact `systemctl --user disable --now gardien.timer`
remediation, hourly, into a file, for eight days. The ecosim sensor reports
BLIND every thirty minutes. `hygiene-lint` fires 61 FLAGs on every run and
nothing changes. `milestone-audit` reports its own author MISSING. The
instruments are right, loud, and unread — because the actuator they escalate
through (`scheduler -i <project>`) writes into a FOCUS.md that no dispatch will
read, since every participant is `enabled=0`. Detection without a consumer is
Ashby-equivalent to no detection, and this ecosystem *knows* that: it is
pattern 14, it is the closed-loops brief, it is the thesis of the project that
wrote the sensors.

The generator of that gap is the ecosystem's own preferred move. Confronted
with a failure, the reflex is to *write it down as a pattern* and *build the
surface that would catch it* — and to stop before wiring the surface to
something that acts. That reflex produced 45 KB of doctrine against 23
scripts, 25 verbs with no caller, and an archiving code path built explicitly
"for the unattended run" and never symlinked.

**The unwiring is the same move at full scale.** It removed cron — the one
thing that closed loops — while leaving systemd, `svc-vaporwave`, and three
bibliothecaire timers running, and replaced dispatch with a verb layer nothing
dispatches. The metaphor asked for organs that decentralize their nervous
system. What exists is a nervous system that decentralized itself away from
every muscle it had.

### The specific form of it: the gate was bypassed

`realisateur/.scheduler/FOCUS.md:171` defines the chain U0 → U1 → U2 → U3 and
says in as many words:

> *"Parking 17 projects in favour of an unproven instrument is the failure
> mode."*

U0 is *basheur is developed enough*, and its decisive criterion is **token
cost measured on both sides, not estimated**. That box is unchecked.
basheur's own FOCUS.md has carried it as `[OPEN — Zach]` since 2026-07-30 and
states plainly that a purge cannot fill it, because a subtraction has no
before-cost. U1's acceptance bar was *restorable, not "rsync exited 0"* — and
there is no backup at all: one 477 GB NVMe at 91%, no external storage
mounted, no `.gardien-snapshot-complete` marker anywhere on the filesystem,
the Pegasus enclosure dead since 07-25.

U2 was executed anyway. The crontab was emptied, ten projects parked, five
reaped off disk. Meanwhile the machinery has been *exercised* heavily — 15
contracts, 6 residue scripts, 6 wired impls, 23 verb-page summon attempts —
and *tested* zero times.

The document predicted the failure mode by name, and the ecosystem walked into
it anyway. That is the finding. Not that the design was wrong — the design was
right and written down in advance — but that **nothing in the system was
capable of stopping an act the system had already forbidden in prose.** Which
is, exactly, the meta-pathology: a guard that is a paragraph is not a guard.

---

*Method note: this survey's own headline quantities were re-derived by command
before publication. Three figures from the first pass were wrong and are
corrected here — orphan loop files are 8, not 9 or 10; the vault is 253 notes
and ~360k words, not 366/394k; and the vault is **not** single-copy (it is
pushed to GitHub), though it is in no backup set. The single-copy exposure is
basheur alone.*
