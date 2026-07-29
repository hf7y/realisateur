# dexter service migration — working notes — 2026-07-29

Hand-migrating services to dexter one at a time. This file accumulates notes
per service, to be integrated later with the run-3 experimental data in
[`SESSION-RECORD-the-play-run-3-20260729.md`](SESSION-RECORD-the-play-run-3-20260729.md).

Step 0 (this entry): snapshot `zach@dexter:~`, then clear it so a scheduler
bootstrap starts from a known slate.

---

## Snapshot

`~/dexter-snapshots/dexter-home-2026-07-29T1645.tar.gz` on **mandark**
— 50M, 5553 entries, mode `600`, dir mode `700`.

Deliberately **outside** any git repo: it contains eight private keys
(`id_dexter_gardien`, `dexter_{gardien,mandark,scheduler,chezz,wtul}_deploy`,
`dexter-potato`) plus `.claude.json`. Never commit it.

Verified rather than assumed — `gzip -t` clean, and the manifest was grepped
for each load-bearing path: `.ssh/` (18), `gardien/gardien.json`,
`.config/systemd/user/gardien.service`, `.claude.json`, `.bashrc`,
`crt-brain/` (435), `pw-probe/` (234), `reports/` (30), `scheduler/` (1540),
`.local/share/scheduler-registry`, `.local/bin/crt-brain-shell`.

Excluded as regenerable: `.cache`, `.npm`, `.nvm`,
`.local/share/claude/versions` (1.4G → 50M).

Restore: `tar xzf <snap> -C /home` (unpacks as `zach/`).

## Finding: dexter held no unpushed work

Every git repo on the host was clean **and** fully pushed — `scheduler`,
`crt-repo`, `gardien-repo`: zero dirty files, zero commits ahead of upstream.

This is worth recording because it inverts the usual assumption behind the
"dirty tree at exit is a failed run" rule. The risk on dexter was never
uncommitted git work; it was the **non-git** material, which no discipline
covers and no remote holds: `crt-brain` (12M, not a repo), `pw-probe` (19M,
not a repo), `reports`, `.crt`, and the scheduler state markers under
`.local/share`. A "is everything committed?" check would have returned a
clean bill of health and still lost all of it.

## Finding: "clear it out" and "so a bootstrap can run" are in tension

A literal `rm -rf ~/*` destroys the bootstrap's own preconditions. Recorded
because it is the same shape as the run-3 finding that stripping FOCUS.md
broke the filing channels the play depended on — clearing the stage also
clears the things the next scene needs to stand on.

| Deleting | Breaks |
|---|---|
| `.ssh/authorized_keys` + keys | all access to dexter (WSL2 sshd, port 2223) |
| `.claude/`, `.claude.json` | bootstrap's `claude` cannot authenticate |
| `.nvm`, `.local/bin/{node,npm,claude}` | no node/claude on PATH — the hand-run PATH trap again |
| `.bashrc` | PATH for scheduled jobs (`.bashrc` returns early for non-interactive shells *before* its nvm block) |
| `.config/systemd/user/gardien.*`, `~/gardien/gardien.json`, `gardien-repo` | kills the live nightly backup — and un-migrates an already-landed service |

## What was cleared

Removed (~36M): `crt-repo`, `.crt`, `pw-probe`, `reports`,
`.local/share/crt-nightly-batch`, and the loose files at `~`:
`gardien.py`, `gardien.json`, `gardien-dryrun.log`, `gardien-run.log`,
`gardien-media-audit.json`, `gardien.service.backup-2026-07-28`,
`media-audit-2026-07-25.json`, `media-audit-run.log`,
`handrun-run3{,b,c,d,e}.log`, `crt-secretary-stranded-2026-07-29.patch`,
`crontab-backup-2026-07-28.txt`.

The loose `~/gardien.py` and `~/gardien.json` were the **superseded**
pre-migration copies — the live unit reads `$HOME/gardien-repo/gardien.py`
with `--config $HOME/gardien/gardien.json`, and the two json files differ by
md5 (`3320d05…` loose vs `b6b2c0a…` live). Confirmed before deleting, not
after.

Kept: `.ssh`, `.bashrc`, `.profile`, `.gitconfig`, `.claude`, `.claude.json`,
`.nvm`, `.npm`, `.cache`, `.local/bin`, `gardien/`, `gardien-repo/`,
`.config/systemd/user/gardien.*`.

Post-clear verification (re-probed, not quoted): `node -v` → `v24.18.0` via
`.local/bin`; `claude` resolves; no dangling symlinks in `.local/bin`;
`gardien.timer` still armed for Thu 2026-07-30 03:04 CDT; `gardien.json`
parses; crontab `PATH=` line intact.

## DEFERRED — the two directories the bootstrap actually needs cleared

`~/scheduler` and `~/crt-brain` were **not** touched. Both are the cwd of a
live interactive `claude` session that is Zach's, not automation:

- PID `55298` — tmux `potato-claude`, 18h55m, cwd `~/crt-brain`, running
  `--permission-mode bypassPermissions`. Pane shows it awaiting/working on
  `fix the bridge first`. Its own transcript reports the crt bridge broken
  and a second session writing the same repo — worth reading before killing.
- PID `242127` — 7h15m, cwd `~/scheduler`, parent an interactive bash on
  `pts/0`.

`~/scheduler` is precisely what a bootstrap re-clones, so this must be
resolved before step 1. **Deleting it under a live session is the collision
the busy-guard exists to prevent**, and killing a human's 19-hour interactive
session is not an unattended call. Both directories are in the snapshot.

Next action: Zach decides — kill the sessions, or let them close out first.

---

# Step 1 — full teardown, then bootstrap (Zach: "kill it all. this is bootstrap.sh and go")

## Teardown completed

Killed both live sessions (tmux `potato-claude`/PID `55298`, and PID `242127`);
`pgrep claude` now returns nothing. Pane history captured first to
`~/dexter-snapshots/session-captures-2026-07-29/`.

Gardien torn down for a uniform starting line: `gardien.timer` disabled and
stopped, both unit files removed, `daemon-reload` run. **The nightly backup no
longer runs** — `~/.config/systemd/user/` is now empty.

Removed `scheduler` (20M), `crt-brain` (12M), `gardien` (96K),
`gardien-repo` (996K); then the orphans they left in machine config:
`.local/bin/{usage-gate.sh,usage-paced-runner.sh}` (both dangling symlinks
into the deleted `~/scheduler`), `.local/bin/crt-brain-shell`, and all six
`.local/share/scheduler-*` state dirs.

Home is now: dotfiles, `.ssh`, `.claude`+`.claude.json`, `.cache`, `.npm`,
`.nvm`, `.local/{bin,share}` holding only node/npm/npx/claude. Verified after:
`node v24.18.0`, `claude 2.1.220`, crontab `PATH=` line intact, deploy key
authenticates (`Hi hf7y/scheduler!`).

## FINDING (the headline): scheduler cannot bootstrap itself onto a bare host

Re-cloned scheduler from `git@github-scheduler-deploy:hf7y/scheduler.git` at
`5f72845`. Ran `bin/sync-crontab.sh` **without** `--apply`. It refused to
install the runner tick:

```
ERROR [runner]: RUNNER_CMD -- /home/zach/.local/bin/usage-paced-runner.sh
  does not exist or isn't executable -- runner tick omitted
-- 1 error(s) above; the affected tier(s) were left OUT of the generated
   crontab, everything else proceeded --
```

The mechanism, confirmed by reading rather than inferred:

- `schedule/_runner.conf:25` hardcodes
  `RUNNER_CMD="/home/zach/.local/bin/usage-paced-runner.sh"` — a path
  **outside the repo**.
- The repo *does* ship `bin/usage-paced-runner.sh`, executable.
- **Nothing in the repo creates that symlink.** No `install.sh`, no
  `bin/install*`; `grep -rn "local/bin" bin/*.sh` turns up only *consumers*
  (`deploy-drift-check.sh` treats `~/.local/bin` as a pre-existing
  `DEPLOY_DIR`) and prohibitions (`overnight-dev.sh:100`, "NEVER edit the
  installed wrapper scripts under `~/.local/bin`").

So the link was hand-installed once, on 2026-07-24, and every later run
inherited it. Deleting it — which the clear-out did as routine orphan cleanup,
not as a probe — removed the last copy, and the host lost the ability to
dispatch anything at all.

**This is run 3's own thesis reproduced one layer down.** Run 3 emptied the
crontab because the `*/30` tick "had been HAND-INSTALLED and never generated
by `bin/sync-crontab.sh`". The generator turns out to have the same defect it
was being tested for: it can generate the *cron line*, but the *thing the line
executes* is still hand-installed and ungenerated. `sync-crontab.sh:420`
already documents this exact gap class for `~/.local/bin/scheduler` — so the
pattern was known and filed, just not swept for.

**The loud failure is the good news, and worth crediting.** `meta_cmd_unrunnable`
checked the target, named it, and **omitted the tier** rather than emitting a
cron line that would fail silently every 30 minutes. That is the
BUILD-DISCIPLINE "fails loud / no exit-0 no-op" row doing real work on a real
regression.

### Second-order: the generated crontab would be empty anyway

With the runner tick omitted, `_sweep.dexter.conf` blanking `SWEEP_TICK_CRON`
(host opts out), and every project's fixed BATCH line suppressed as a paced
participant, the managed block generates as:

```
# >>> scheduler-managed >>>
# <<< scheduler-managed <<<
```

Empty. Nothing on dexter dispatches. The runner tick is not *a* job here — it
is the *only* job, so that single missing symlink is a total-dispatch outage,
not a degraded tier.

### Third: the clone assumes mandark's directory layout

`focus/` and `questions/` symlinks are generated pointing at
`/home/zach/Documents/Projects/<proj>/.scheduler/…`, which is mandark's tree.
On dexter every one reports `target does not exist yet`. Not fatal (they skip),
but a dexter-resident scheduler has no FOCUS/QUESTIONS to read — a second
unstated host assumption in the same bootstrap.

---

# Step 2 — dexter goes bare, and the office replaces scheduler on it

Zach: *"dexter's working directory should be bare, not even scheduler."*

## Teardown completed

Removed the re-cloned `~/scheduler` (3.4M, at `5f72845`). Checked before
deleting, not after: no `claude` process running, tree clean, `0` commits ahead
of upstream — nothing on the host that the remote didn't already hold.

dexter's home is now exactly: `.bashrc`, `.bash_history`, `.bash_logout`,
`.profile`, `.gitconfig`, `.viminfo`, `.motd_shown`, `.landscape`, `.ssh`,
`.claude` + `.claude.json`, `.cache`, `.npm`, `.nvm`, `.config`, `.local`.
No project directory of any kind.

Re-probed after (2026-07-29, via `ssh -p 2223 dexter`): `~/.local/bin` holds
only `claude`, `node`, `npm`, `npx`; `claude --version` → `2.1.220`;
`~/.config/systemd/user/` is empty; crontab is the `PATH=` line plus the
comment block. **Nothing on dexter dispatches, and nothing on dexter is
scheduled to.**

Note the PATH trap reappearing as expected: bare `node -v` over
non-interactive ssh fails (`command not found`) while `~/.local/bin/node`
exists — `.bashrc` returns early before its nvm block. Absence of `node` on
that shell's PATH is not absence of node.

## What replaces scheduler there

A new repo — **`media-arts-collective/office`**, local clone
`~/Documents/vkv/office`, first commit `f63ce49`, pushed. It is the "office
parallel to the front door" from the 2026-07-29 `/ideate` capture, built for
nomac (nomac is the performance; the office is the company behind it). Directors
Zach and Tyler; Roman-named agents as employees; Claude capacity in the
vaporwave account denominated as **wavebucks**, so an agent is paid for
completed work orders and charged for its own thinking.

Filed to senechal via `notify-senechal` (senechal `719dd0f`): dexter is bare,
and the office — not scheduler — is the declared owner of its machine config
going forward.

**The office has installed nothing on dexter yet.** `bootstrap.sh` was run
preflight-only, from mandark. Arming it is a separate, deliberate step.

## Finding: the bootstrap defect from step 1 became a design rule

Step 1's headline was that `scheduler` could not bootstrap onto a bare host: its
generator emitted a cron line pointing at `~/.local/bin/usage-paced-runner.sh`,
a path **nothing in its repo ever created**, hand-installed once on 2026-07-24
and silently depended on forever.

`office` is built so that failure is structurally unavailable:

- every out-of-tree path is declared in **`office.conf`** (one source) and
  created by **`bootstrap.sh`**, which re-derives its symlinks from the repo on
  *every* run rather than trusting a link a human made once;
- `bootstrap.sh` **refuses to clobber a non-symlink** at a target path — if a
  human put a real file there, that is a finding, not something to overwrite;
- it **preflights by default** and arms nothing without `--apply`;
- it prints six **declared-but-unbuilt** items out loud (mail transport,
  Workspace accounts, `commissio`, the token meter, `office-worm`, an empty
  archive) so the presence of well-written protocol documents cannot be mistaken
  for a working office.

## Finding: an economy is a mechanism, so it can be tested — and the first test found a real bug

The reverse-bid market is the load-bearing idea (an agent is paid its own bid and
keeps the margin, so the only way to get rich is to stop thinking about a
repeated job and build the utility instead). That is an incentive claim, but the
bookkeeping under it is ordinary software and was exercised as such.

`bin/office-ledger` — hash-chained, append-only — was tested for: chain tamper
detection, seq-gap detection, pipe/newline injection, and refusal to pay beyond
what was appropriated. **The first run exposed a real defect:** `APPROP` and
`HIRE` credited the *appending* director, giving `zach@nomac.org` a balance of
550 wavebucks. A director holding a balance in a closed economy would have made
every solvency check meaningless.

Fixed by separating **authority from subject**: `--as <director>` authorizes and
is recorded in the note, the subject is the employee (or the literal `TREASURY`
for an appropriation), and any row whose subject is a director is now refused
outright. Recorded here because the bug was only visible because a balance was
*printed and read* — the human-sense witness, not the exit code. `office-ledger
verify` exited 0 on the ledger that contained it.

## Open question for the experimental record

Does gardien count as already-migrated (leave it running) or as a service to
re-migrate from scratch under the new bootstrap? It was kept on the
already-migrated reading. If the experiment wants a uniform starting line, the
teardown is `systemctl --user disable --now gardien.timer`, remove the two
units, `rm -rf ~/gardien ~/gardien-repo` — at the cost of the nightly backup
until it is re-landed.
