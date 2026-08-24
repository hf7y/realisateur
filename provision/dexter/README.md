# dexter — where work lives on it, and what it runs

*Sibling to `vault:realisateur/MONKEY.md`, which says where self-dev runs; it lives here, beside
the compose files it governs, rather than as another root document.*

* This one says where
anything else on dexter runs, and it exists because the answer was previously
"wherever whoever built it happened to put it." Every claim below carries the
command that produced it and the date. Re-probe before relying on one.*

**Status: proposed 2026-08-14, on empty ground.** Written the night zaxon was
found dead for ten days in an undocumented WSL distro. Nothing has been
migrated yet; §6 says what would move and what that costs.

---

## 1. The failure this document is for

zaxon — the only relay that carries a question to a human — ran in a WSL distro
called `hermes` that no ecosystem document mentioned. When dexter rebooted, the
`Ubuntu` distro came back and `hermes` did not. Nothing noticed for ten days.

```
# 2026-08-14, from dexter's Ubuntu distro
uptime                       up 10 days,  6:19
wslx -l -v                   Ubuntu Running / hermes Stopped / docker-desktop Stopped
ss -ltn | grep 8643          (nothing)
```

The service was never broken: `hermes-gateway.service` is `enabled` and carries
`Restart=always`. **A WSL distro has no supervisor above it** — `Restart=always`
protects the process, nothing protects the distro. That is a missing layer, and
no amount of care inside `hermes` would have caught it. The alarm now exists as
`bin/dexter-liveness.sh`; its header carries the rest of this argument.

## 2. The canonical userland: the `Ubuntu` distro, and no other

`ssh dexter` (port **2223** — 22 is the Windows sshd and holds none of our
keys, see `~/.ssh/config`'s own note).

It earns "canonical" empirically, not by preference: it survived the reboot
that killed `hermes`, and has held sshd continuously for ten days. It is also
**empty** — as of 2026-08-14 `~zach` has no files, `/srv` and `/opt` do not
exist, and `/` is 1007G with 3.7G used. There is no legacy to migrate around.

**No new WSL distros.** A distro is a userland with no autostart, no
supervisor, and no place in any inventory. `hermes` is the proof. If something
needs isolation, it gets a container (§3), which has all three.

## 3. The canonical runtime: containers under the Ubuntu distro's own dockerd

**NOT Docker Desktop.** The `docker-desktop` distro exists on this host and is
`Stopped`; Docker Desktop requires a **Windows login session**, which is the
same failure mode as `hermes` one layer down. A service that needs someone
logged in is not a service.

**A container is what a dev agent SHIPS.** Zach, 2026-08-14: *"docker containers
are the consumables produced by dev agents."* That is the distribution channel
for services, sitting beside the one that already exists for commands — a
project declares a verb on its `bashified` branch and the verb build carries it
to every account (`vault:realisateur/VERB-DISTRIBUTION.md`); a project that runs a *service*
produces an image and a `compose.yaml` under `/srv/<project>/`, and this host
runs it. Same shape, different artifact: the repo is the source, the built
thing is the deliverable, and no service is hand-installed into a userland
where only its author knows it exists. That is what `hermes` was.

The roster this implies, Zach-directed the same day: `zaxon` and the whisper/STT
services (both **crt's** — crt owns the human channel, see `SECRETARY.md` in
that repo), `bibliothecaire` intake, `gardien` auto-backup. Each is produced by
its own project; this repo holds none of them. `potato`
(the Pi) is out of scope — it is a separate appliance `crt` produces, not a
container on this host.

INSTALLED 2026-08-14: `docker.io` 29.1.3, `systemctl is-enabled docker` →
`enabled`, `is-active` → `active`. Since dockerd is enabled inside a distro
that comes up with the host, `restart: always` on a container is a real
promise — which is the layer §1 says was missing.

Before that install there was no Docker in this distro at all — no binary, no
socket, no packages, no units — so this is a green field, not a migration.

## 4. The canonical paths

```
/srv/<project>/          one directory per service. compose.yaml + data/.
                         The unit of ownership: one project, one dir, one
                         compose file, no state anywhere else.
~/Documents/Projects/<r>  git clones, matching mandark and monkey exactly.
                         Code, never data.
/mnt/d/<...>             BULK ONLY, and Windows owns it. gardien's 261G of
                         backups live here. Not a place to install anything:
                         it is NTFS through a translation layer, with Windows
                         file locking and no unix permissions worth the name.
/usr/local/bin/          host-wide commands, same convention as monkey.
                         Currently: wslx (§5).
```

Anything that does not fit one of those four is a finding, not a fifth option.

## 5. The Windows edge, and the one wrapper that crosses it

Work that genuinely needs Windows — starting a distro, driving VirtualBox,
touching `D:` — crosses at **`/usr/local/bin/wslx`** and nowhere else. Calling
`wsl.exe` directly is unreliable: under `systemd=true` the `WSLInterop` binfmt
registration does not hold, and stdin must be closed or `wsl.exe` eats the rest
of a piped script. `wslx`'s own header records the probe log.

It depends on `/etc/sudoers.d/zach-nopasswd`, installed 2026-08-14 at Zach's
direction. **Stated plainly rather than left to be discovered**: every agent
holding a mandark key can now reach root here and drive Windows through it.
That was the deliberate trade for fixing things unattended — senechal#253.

## 5b. Nothing here starts at boot — it starts at LOGIN

The probe that matters most, and the one `bin/dexter-liveness.sh` runs last:

```
Windows LastBootUpTime          2026-08-03 16:25
Ubuntu distro uptime            10 days          (i.e. it came up with that boot)
hermes distro                   never started
C:\Users\Zach\...\Startup\      monkey-vm.bat, senechal-wsl-autostart.vbs
```

Both live things on this host are started by **per-user Startup folder** items,
which run at **login**. A reboot with nobody logging in leaves `monkey` down —
that is *all* of self-dev — and looks, from outside, exactly like a quiet
night. `hermes` was simply never given such an item, which is the entire
ten-day outage.

`senechal-wsl-autostart.vbs` is the shape that works, and it already uses the
`sleep infinity` anchor, because *"WSL tears the VM down when its last process
exits."* It is owned by senechal (`remedies/dexter-wsl-autostart.sh`) and has a
matching scheduled task. **The fix is not a third such script — it is to make
these boot-scoped rather than login-scoped**, so the host recovers from a power
cut without a human. That needs a Windows credential and is Zach's to authorise.

## 6. Moving zaxon, and the one rule that governs it

**crt owns zaxon** (Zach, 2026-08-14), so its container form lives in
`hf7y/crt` at `provision/dexter/zaxon/` — this repo ships the road, not the
freight. The deploy path resolved a service from the owning
project's checkout; `DEXTER_SERVICE_PATH` overrides the search for a worktree
or an owner that is not cloned locally.

**The WhatsApp bridge is Baileys, a LINKED DEVICE** (probed 2026-08-14:
`@whiskeysockets/baileys` 7.0.0-rc13, Node + express on :3000, session as plain
files in `~/.hermes/whatsapp/session`). This retires the belief that a phone
must stay powered on — a linked device keeps working while the phone is off,
and is needed only to pair and, roughly every two weeks, to refresh.

**Exactly one process may own that session.** Two — a container and the old
distro — and WhatsApp logs the link out, costing a QR scan to recover. The
deploy script enforces this by refusing while `hermes` runs; the cutover order
is stop, move, start, never overlap. (`auth.json` is unrelated: it holds the
model-provider credential.)

`whisper-server` is the CPU-heavy half and moves second. STT degrades
gracefully; the relay does not.

**Not settled here**: whether dexter is a build host that happens to hold
zaxon, or the estate's always-on service host — `monkey` is also always-on and
is where zaxon's callers live. The layout is right either way; the roster is not.

**Still missing**: nothing has been migrated yet, and dexter's autostart is
still login-scoped (§5b).
