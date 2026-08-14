# DEXTER.md — where work lives on dexter

*Sibling to `MONKEY.md`, which says where self-dev runs. This one says where
anything else on dexter runs, and it exists because the answer was previously
"wherever whoever built it happened to put it." Every claim below carries the
command that produced it and the date. Re-probe before relying on one.*

**Status: proposed 2026-08-14, on empty ground.** Written the night zaxon was
found dead for ten days in an undocumented WSL distro. Nothing has been
migrated yet; §6 says what would move and what that costs.

---

## 1. The failure this document is for

`zaxon` — the only relay that carries a question to a human — ran in a WSL
distro called `hermes` that **no ecosystem document mentioned**. `ZAXON.md`
recorded its reachability and not its lifetime. When dexter rebooted, the
`Ubuntu` distro came back and `hermes` did not. Nothing noticed for ten days.

```
# 2026-08-14, from dexter's Ubuntu distro
uptime                       up 10 days,  6:19
wslx -l -v                   Ubuntu Running / hermes Stopped / docker-desktop Stopped
ss -ltn | grep 8643          (nothing)
```

The service was never broken. `hermes-gateway.service` is `enabled`, runs as
`User=zaxon`, and carries `Restart=always` — it is correctly written. **A WSL
distro has no supervisor above it.** `Restart=always` protects the process and
nothing protects the distro; WSL terminates one when its last session exits.
That is a missing layer, not a tuning problem, and no amount of care inside
`hermes` would have caught it.

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
to every account (`VERB-DISTRIBUTION.md`); a project that runs a *service*
produces an image and a `compose.yaml` under `/srv/<project>/`, and this host
runs it. Same shape, different artifact: the repo is the source, the built
thing is the deliverable, and no service is hand-installed into a userland
where only its author knows it exists. That is what `hermes` was.

The roster this implies, Zach-directed the same day:
`zaxon` (from the `hermes` distro), `crt`'s whisper/STT services (from
`crt-vm`, retired), `bibliothecaire` intake, `gardien` auto-backup. `potato`
(the Pi) is out of scope — it is a separate appliance `crt` produces, not a
container on this host.

INSTALLED 2026-08-14: `docker.io` 29.1.3, `systemctl is-enabled docker` →
`enabled`, `is-active` → `active`. Since dockerd is enabled inside a distro
that comes up with the host, `restart: always` on a container is a real
promise — which is the layer §1 says was missing.

As of 2026-08-14, before that install, there was **no Docker in the Ubuntu distro at all** —
`command -v docker` is empty, `/var/run/docker.sock` absent, zero
docker/containerd packages, no units. Installing the native engine
(`docker.io` + `docker-compose-v2`, systemd-supervised) is therefore a green
field, and it buys the layer §1 says is missing: `restart: always` on the
container, `dockerd` supervised by the Ubuntu distro's systemd, and the distro
itself proven durable across reboots.

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

Some work genuinely needs Windows — starting a distro, driving VirtualBox,
touching `D:`. That crossing goes through **`/usr/local/bin/wslx`** and
nowhere else.

`wsl.exe` cannot be called directly and reliably: with `systemd=true` in
`/etc/wsl.conf` the `WSLInterop` binfmt registration is absent at boot, and
**re-registering it does not hold** — on 2026-08-14 it worked, vanished within
seconds, and worked again, three times in one session. `wslx` re-registers
before every call (milliseconds) and closes stdin, because `wsl.exe` is a
Windows process that inherits stdin and will silently eat the rest of a piped
script — the same class of bug `MONKEY.md` §7 records for `VBoxManage.exe`.

This depends on `/etc/sudoers.d/zach-nopasswd` (passwordless sudo for `zach`,
installed 2026-08-14 at Zach's direction). **State that plainly rather than
letting it be discovered**: every agent holding a mandark key can now reach
root on dexter's Ubuntu distro and drive Windows through it. That was the
deliberate trade for being able to fix things unattended. Declared to senechal
as hf7y/senechal#253.

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

## 6. What this would move, and what it costs

**zaxon, out of `hermes` and into a container under `/srv/zaxon/`.** It is a
plain Python venv service — `hermes-agent/.venv/bin/python -m hermes_cli.main
gateway run`, `User=zaxon`, working dir `~/.hermes` — with no Windows
dependency beyond an inherited `PATH` full of `/mnt/c` entries. Two real costs,
neither of which should be discovered mid-migration:

1. **The WhatsApp session, and the ONE-OWNER rule.** Probed 2026-08-14 rather
   than assumed: the bridge is **Baileys** (`@whiskeysockets/baileys`
   7.0.0-rc13, Node + express on :3000, `scripts/whatsapp-bridge/`), storing a
   linked-device session as plain files in `~/.hermes/whatsapp/session`.

   **This retires the belief that a Samsung Galaxy must stay powered on.** A
   linked device keeps working while the phone is off; WhatsApp expires an idle
   link at roughly two weeks, so the phone is needed to pair (QR) and
   occasionally to refresh — not continuously. What must be always-on is
   whatever holds the session directory.

   The real hazard is different and sharper: **exactly one process may own that
   session.** Two — a container and the old distro, say — and WhatsApp logs the
   link out, which costs a QR scan to recover. So the cutover order is: stop
   the distro's bridge, move the session, start the container. Never overlap.
   `auth.json` is unrelated to WhatsApp; it holds the *model provider*
   credential (Nous Portal — see `~/.hermes/AUTH_NOTES.md`).
2. **`whisper-server` is the CPU-heavy half.** Move the gateway alone first —
   it is the part that must never be down. STT degrades gracefully; the relay
   does not.

**Open question this document does NOT settle**: whether dexter is a
build-and-compute host that happens to hold zaxon, or the estate's always-on
service host. `monkey` is also always-on Linux and is where the agents that
*call* zaxon live. The layout above is right either way; the roster is not
decided.

## 7. What is still missing, named rather than implied

- **A liveness probe.** This outage was found by accident, by a `groc-mangr`
  dispatch run that happened to try the relay (hf7y/groc-mangr#9). Every hour
  of those ten days, something could have curled 8643 and filed a finding.
  Until that exists, this document has improved the map and not the alarm.
- **hermes is still the live location.** Nothing here has been migrated. A
  `hermes-keepalive.service` was written as a stopgap and its install is
  pending — see hf7y/senechal#253.
