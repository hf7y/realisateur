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

As of 2026-08-14 there is **no Docker in the Ubuntu distro at all** —
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

## 6. What this would move, and what it costs

**zaxon, out of `hermes` and into a container under `/srv/zaxon/`.** It is a
plain Python venv service — `hermes-agent/.venv/bin/python -m hermes_cli.main
gateway run`, `User=zaxon`, working dir `~/.hermes` — with no Windows
dependency beyond an inherited `PATH` full of `/mnt/c` entries. Two real costs,
neither of which should be discovered mid-migration:

1. **WhatsApp re-auth.** `~/.hermes/auth.json` + `auth.lock` is a linked-device
   session. It may not survive the host change; if it does not, re-linking
   needs Zach's phone and a QR scan. This is the step that can strand the
   channel, so it is the step to rehearse first.
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
