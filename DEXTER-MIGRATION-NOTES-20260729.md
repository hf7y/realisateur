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

## Open question for the experimental record

Does gardien count as already-migrated (leave it running) or as a service to
re-migrate from scratch under the new bootstrap? It was kept on the
already-migrated reading. If the experiment wants a uniform starting line, the
teardown is `systemctl --user disable --now gardien.timer`, remove the two
units, `rm -rf ~/gardien ~/gardien-repo` — at the cost of the nightly backup
until it is re-landed.
