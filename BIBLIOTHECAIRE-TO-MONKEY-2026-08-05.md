# bibliothecaire → monkey: what moved, what cannot, and a dead pipeline found on the way

*2026-08-05/06, mandark. Zach: "move bibliothecaire and all of those services
entirely over to monkey. calling into them should be by github issues, or
through scp inboxes and outboxes, or something else clever. but that should be
on always-on monkey, not mandark."*

**Every claim below is a command run on the host it names.**

## 0. First: the pipeline was already dead, and not because of this work

`bibliothecaire-intake.service` had been failing **every 15 minutes since
17:16**, hours before this session touched anything:

```
$ journalctl -u bibliothecaire-intake.service | grep -m1 203/EXEC
  Aug 05 17:16:32 mandark ... status=203/EXEC
$ ls /home/zach/Documents/Projects/bibliothecaire/bin/intake.py
  No such file or directory
$ git -C .../bibliothecaire branch --show-current
  ask-basheur-before-demanding-summon
```

**The live checkout had been left on a feature branch whose `bin/` does not
contain `intake.py`.** `origin/main` has it; that branch carries the bashified
verb set instead. So the three units pointed at a path that no longer existed,
and `203/EXEC` is systemd saying "I could not execute that."

This is exactly the coupling being removed: a live service whose executable is
whatever branch someone last checked out in a dev clone.

Fixed by putting the checkout back on `main`. The witness is systemd's own,
not mine — the next scheduled run finished clean:

```
Aug 05 21:16:17 mandark systemd[1]: Finished bibliothecaire-intake.service
Aug 05 21:16:17 mandark systemd[1]: Consumed 1min 9.274s CPU time.
```

**Nothing was lost:** `incoming/` was empty at the time (checked before
touching anything), so no scan sat unprocessed during the outage. The branch
was fully pushed and had 0 unpushed commits, so the switch discarded nothing.

## 1. The constraint that decides the whole design

`monkey` is a **VirtualBox VM hosted on dexter**, on NAT:

```
$ ssh monkey 'systemd-detect-virt; ip -4 addr'
  oracle  (VirtualBox / innotek GmbH)
  inet 10.0.2.15/24   enp0s3        <- VirtualBox NAT, not a LAN address
  inet 100.121.83.23  tailscale0
$ tailscale status | grep monkey
  monkey  ... active; direct 192.168.0.22:54179     <- .22 is dexter
$ nmblookup -A 192.168.0.22
  DEXTER <20> ACTIVE                                <- dexter already serves SMB on 445
```

The scanner is a LAN appliance that writes over SMB to a share restricted to
`192.168.0.0/24` (`intake.json: hosts_allow`). **monkey has no LAN address, no
`smbd`, and dexter's own Windows SMB already owns port 445.**

### On "sshfs? sockets? webapp?"

The protocol is not the constraint — **inbound reachability** is. sshfs,
sockets and a webapp all fail identically: the scanner can only push to
something with a LAN address, and it speaks SMB, not HTTP.

sshfs is worse than the others, not better: if the mount drops, samba keeps
accepting scans onto mandark's local disk and monkey never sees them. Files
land, the share looks healthy, and the loss is discovered whenever someone
wonders where a scan went. `intake.json` was written specifically to refuse
that class of failure ("a no-op run that reports success is the failure mode
this project cares most about avoiding").

**The clever option is dexter, not a protocol.** dexter is always-on, already
serves SMB on the LAN, and already hosts monkey. A Windows shared folder on
dexter, handed to the guest as a VirtualBox shared folder, puts scans on
monkey's filesystem with no network hop, no tunnel, no relay process, and no
new failure mode. Second-best: bridge monkey's NIC so it gets a real
`192.168.0.x` and serves the share itself.

Both need hands on dexter's hypervisor and a scanner repoint. **So no path to
"mandark keeps nothing" is reachable unattended**, and this record does not
pretend one was taken.

## 2. What now exists on monkey, proven

| step | witness |
|---|---|
| OCR toolchain installed | `ocrmypdf`, `tesseract`, `pdftotext`, `pdfinfo`, `pdftoppm`, `smbclient` all resolve on PATH |
| repo cloned | `/home/zach/Documents/Projects/bibliothecaire` @ `92bedb7`, branch `main` |
| 1.4G of scans copied | **byte-identical**: `1417659222` bytes / `565` files on *both* hosts |
| `bibscan` group created | gid 3010 (the units declare `SupplementaryGroups=bibscan`; systemd refuses to start without it) |
| units installed | by the repo's own `systemd/install.sh`, **unmodified** |
| units verified | `install.sh --verify`: all 6 units match the repo, 3 timers enabled + active |
| the pipeline runs | `./bin/intake.py --run` → **exit 0**, 294 lines of stage output |
| a real document goes through | see below |

### Why the layout mirrors mandark exactly

The repo's units hardcode `/home/zach/Documents/Projects/bibliothecaire`,
`User=zach`, `SupplementaryGroups=bibscan` — and `install.sh --verify` fails
loud on **any** drift between the installed copy and the repo copy. Hand-editing
monkey-specific units would have created precisely the drift that verifier
exists to catch. Mirroring the paths instead means the project's own installer
runs unmodified on monkey and its verifier passes. The cost is a
`Documents/Projects` path on a server; the benefit is one source of truth.

Making the units host-agnostic is the right follow-up, and it is a repo change
with a PR, not a thing to improvise into a live pipeline at 02:00.

### The witness: a real document, not an exit code

`--help` and exit codes were not accepted as proof. A valid single-page PDF
with a real text layer was generated, dropped into monkey's `incoming/`, and
drained:

```
[ok] accepted migration-witness-20260806.pdf -> 1cda27ad6d98-migration-witness-20260806.pdf
[ok] accept: 1 accepted, 0 still arriving, 0 unreadable, 0 errored
[ok] ingested migration-witness-20260806: 1 pages, 340 chars/page
[ok] ingest: 1 ingested, 0 parked as needs-ocr

ledger entry: {'slug': 'migration-witness-20260806', 'state': 'ingested',
  'pages': 1, 'sha256': '1cda27ad6d98a0e5...',
  'accepted_path': '/home/zach/bibliothecaire-intake/accepted/1cda27ad6d98-...pdf'}
```

340 chars/page cleared the 120 threshold, so text extraction genuinely worked
rather than parking the item for OCR.

Trying to remove the synthetic item afterwards was **refused by the tool**, and
correctly: `--abandon is for scans OCR could not read, not a general escape
hatch`. It is removed instead by the cutover's mirror step (§4), where
mandark's ledger is authoritative.

## 3. monkey's own healthcheck, unedited

```
[FAIL   ] smb-share      /etc/samba/conf.d/bibliothecaire-intake.conf absent
[UNKNOWN] smb-account    pdbedit not installed -- cannot confirm
[OK     ] dropbox-perms  incoming is 730 zach:bibscan (no listing from the network)
[OK     ] drain-timer    both timers enabled + active, all 6 units match the repo
[OK     ] pdf-tools      pdftotext, pdfinfo, ocrmypdf, tesseract (lang eng) all present
[FAIL   ] backup-proof   garde has no ledger for set 'bibliothecaire-intake'
                         -- --reap will delete nothing, so scans accumulate forever
[FAIL   ] published-share samba does not define a 'bibquotes' share
[OK     ] pipeline-flow  nothing stalled (210 item(s) tracked, 0 awaiting drain)
```

Three of those are real and expected, and each is named in §5:

- **smb-share** — the drop box stays on mandark by design (§1).
- **backup-proof** — `garde media list` shows `bibliothecaire-intake 354/356
  1/1 ok x1`: **one copy**, sourced from mandark. Until gardien is repointed,
  scans on monkey have no backup. The pipeline refuses to `--reap` without
  proof, so the failure mode is "disk fills", not "scans deleted".
- **published-share** — `bibquotes` is the **outbox**. Consumers read published
  quotes over SMB; on monkey that share does not exist yet.

## 4. Cutting over

`bin/cutover-bibliothecaire-to-monkey.sh` (this repo). It exists because
**mandark has no passwordless sudo** — `sudo -n true` answers "a password is
required" — so stopping mandark's three *system* units is the one step an
unattended run cannot take. Everything upstream of it is already done.

```sh
sudo bash bin/cutover-bibliothecaire-to-monkey.sh --verify   # changes nothing
sudo bash bin/cutover-bibliothecaire-to-monkey.sh --apply
```

It refuses to run unless monkey is genuinely ready (ssh works, `intake.py` is
present and executable, the drain timer is enabled) — all three verified
passing today. Then it disables mandark's timers, **mirrors the whole intake
tree** to monkey and proves the mirror byte-for-byte, installs a 5-minute cron
line that ships `incoming/` to monkey, and proves that shipper command runs
before leaving it behind.

The mirror is the whole tree, not just `incoming/`: mandark stays live until
the moment of cutover, so its `ledger.json` and `accepted/` move on past the
seed copy taken tonight. Syncing only `incoming/` would leave those scans on
monkey as files with no ledger entry — which `--status` would report as a
healthy pipeline with 0 awaiting drain. Quiet loss, wearing a green light.

Mandark's unit *files* are deliberately left on disk after the cutover, so
re-enabling is one command if monkey turns out to be wrong.

## 5. What is left, in the order it must happen

1. **Run the cutover script** (above). One command, reversible.
2. **Watch one real scan land on monkey** before trusting it.
3. **Repoint gardien** at monkey for the `bibliothecaire-intake` set. It is at
   **1 copy**. This is the step that loses data if forgotten.
4. **Serve the `bibquotes` outbox from monkey**, or accept that published
   quotes are unreachable over SMB until the drop box moves.
5. **Then** remove mandark's leftovers: `systemd/install.sh --uninstall`, the
   1.4G local copy, and finally the clone (`fauche check` → `fauche script`).
6. **The real fix**, with hands on dexter: dexter shared folder into the guest,
   or bridge monkey's NIC. Then the scanner talks to monkey and mandark keeps
   nothing — not even samba.

Also noted: **`notify-senechal` does not exist for `zach` on monkey**
(`~/.local/bin` holds only `scheduler`). The installer flagged it itself —
"a missing guard is a finding, not an inconvenience" — so senechal was told
about the monkey config from mandark instead.

## 6. Footprint

**monkey:** apt-installed `ocrmypdf tesseract-ocr poppler-utils smbclient`;
created group `bibscan` (3010); cloned the repo to
`/home/zach/Documents/Projects/bibliothecaire`; created
`/home/zach/bibliothecaire-intake` (1.4G, zach:zach, `incoming` 0730
zach:bibscan); installed 6 systemd units + enabled 3 timers via the repo's
installer. A `/srv/bibliothecaire{,-intake}` staging path was created first and
**removed** in favour of the mirrored layout.

**mandark:** switched the bibliothecaire checkout from
`ask-basheur-before-demanding-summon` back to `main` (repairing the outage in
§0). Ran `bin/intake.py --run` once by hand. **No unit was changed, nothing was
deleted, and the live pipeline is still mandark's** until the cutover script is
run.
