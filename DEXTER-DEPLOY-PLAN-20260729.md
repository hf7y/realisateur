# dexter deploy — capability probe and proposed shape — 2026-07-29

Zach: *"we now deploy the dexter deploy branch of this ecosystem. the self-dev
agents render inanimate products, mechanism as the residue of their agency.
they become bash. here's the performance: basheur. we take a repo and bashify
it, load it into the bin of a userspace on dexter. the new agent metaphor on
dexter, deliberately stylized, is agents in an office, they have a portfolio.
this is the vaporwave office designing in another agent. the agents in this
performative model have usernames. in fact, we should run them inside a vm,
not zach@dexter at all. these agents will run the non-profit for real, and
realisateur and co become the dev team for this office's workflow, as a side
job."*

**Nothing here has been executed.** This is a probe result and a proposal. The
boundary decision and the root-access decision are both open and both belong
to Zach — see "Two open decisions" at the end.

## Naming, so the record is accurate

There is no `dexter` or `deploy` branch in any project in this ecosystem
(checked all of `Documents/Projects/*` plus `vkv/office`), and there is no
`basheur` project. "The dexter deploy branch" is a thing to be created, not an
existing artifact to be shipped. Recorded because the phrase reads like it
names something that exists.

## Capability probe (re-probed 2026-07-29 via `ssh dexter`)

| Fact | Value | Consequence |
|---|---|---|
| PID 1 | `systemd` | per-user services and `machinectl` are available |
| `/dev/kvm` | present, 16 `vmx\|svm` cores | **a real VM is possible**; nested virt works under WSL2 |
| Runtimes installed | **none** — no docker, podman, lxc, lxd, systemd-nspawn, machinectl, qemu, multipass | whichever option wins, something must be installed first |
| `sudo -n` | `interactive authentication is required` | **hard gate: no unattended root** |
| Non-system users | `zach` uid=1000 only | every agent username must be created |
| OS / kernel | Ubuntu 26.04 LTS / `6.18.33.2-microsoft-standard-WSL2` | |
| Disk / RAM | 953G free on `/`, 14Gi RAM | ample for a VM or many containers |

## Proposed shape: a VM whose interior is one unix user per agent

This satisfies both halves of the direction — *usernames* and *not zach@dexter
at all* — without choosing between them.

```
dexter (WSL2, user zach = the dev team's hand)
 └── VM "office"  [KVM, own kernel, own sshd]
      ├── user: secretaire   ~/.local/bin  Maildir  per-user systemd
      ├── user: auditor      ~/.local/bin  Maildir  per-user systemd
      ├── user: commissio    ~/.local/bin  Maildir  per-user systemd
      └── /srv/office-state  ledger, worm archive, spool, meter
```

Why this and not users-directly-on-dexter:

- **The username stops being decorative.** A unix account already has a home,
  a `~/.local/bin` for basheur to load into, a per-user systemd for its own
  jobs, and a Maildir. The office's mail bus stops being a metaphor
  implemented over a metaphor and becomes local delivery between real users.
- **The office becomes one destroyable artifact.** Today's teardown of
  `zach@dexter` required reasoning file-by-file about what was load-bearing,
  and a snapshot that had to exclude regenerable bulk by hand. A VM is one
  qcow2: snapshot before arming, roll back after a bad run, destroy without
  touching the host. Given how this afternoon went, that property is worth
  the install cost on its own.
- **`zach@dexter` becomes the dev team's hand, not the office's floor.** That
  is the split Zach named — realisateur and co. are the dev team as a side
  job; the office runs the non-profit. Putting them on opposite sides of a
  kernel boundary makes the split mechanical rather than remembered.

Cost, honestly: qemu/libvirt to install, a cloud image to fetch and seed, and
an extra ssh hop (`zach@dexter:2223` → VM). **Alternative worth considering:**
run the office VM on the *Windows* host under Hyper-V as a peer to the WSL2
instance rather than nested inside it — direct tailscale addressing, no hop,
at the cost of Windows-side setup and a second place to administer.

## basheur is the installer scheduler deleted

"Take a repo, bashify it, load it into the bin of a userspace" is exactly
*check the declared set, install from the repo, on every run* — the rule this
afternoon's teardown produced (see `DEXTER-MIGRATION-NOTES-20260729.md`,
"Correction to step 1"), generalized into a product instead of bolted onto one
project.

This matters for basheur's design, not just its motivation. scheduler's
installer was deleted because, from inside a development checkout, installing
looks like a no-op — the repo already *is* what runs. basheur is only safe
from that same deletion if **re-deriving is its normal operation rather than a
separate step**: every run recomputes the bin from the repo, so there is never
a moment where skipping it looks harmless. `office/bootstrap.sh` already has
this shape; basheur should inherit it rather than reinvent it.

Corollary guard, from the same finding: **check the declared set, never the
intersection.** `deploy-drift-check.sh` compared repo `bin/` against what was
already installed, so an absent utility was never examined and it exited 0
saying "nothing to check." basheur's verify must iterate what the repo
*declares*, so absence reports as a defect rather than as health.

## What per-agent users do to `office.conf`

`office.conf` is currently single-home:

```
OFFICE_ROOT="$HOME/office-state"
BIN_DIR="$HOME/.local/bin"      # bootstrap symlinks office commands here
MAILDIR_ROOT="$OFFICE_ROOT/mail"
```

Under one-user-per-agent those become two different classes and must be split:

- **Shared, one per office** — `LEDGER`, `MAIL_ARCHIVE` (WORM), `METER_LOG`,
  the spool. These want a group-owned path like `/srv/office-state` with a
  shared `office` group, not any one employee's home. The WORM archive in
  particular must not be writable by the employees whose mail it retains.
- **Per-employee** — `BIN_DIR` (`~<user>/.local/bin`, basheur's target) and
  the employee's Maildir.

So `bootstrap.sh` grows a notion of *whose* office it is installing: run once
as root to create the shared state and the accounts, then once per employee to
populate that employee's bin and mailbox. That is a real change to the script's
contract and should be made deliberately, not patched in. **Not attempted here
— `office` is Zach's active working tree (last commit `f9198dc`, 17:58), and
editing it mid-session is the collision the busy-guard exists to prevent.**

## Provisioning sequence (proposal — not run, needs root)

Written out so it can be read before it is armed. Every step needs a password
prompt today.

1. `sudo apt-get install -y qemu-kvm libvirt-daemon-system virtinst`
   — then `sudo adduser zach libvirt` and re-login for group membership.
2. Fetch the Ubuntu 26.04 cloud image; `virt-install` a VM named `office`,
   2 vCPU / 4G / 40G, with a cloud-init seed that creates the employee
   accounts and installs the office ssh keys. **The account list must come
   from `office/ROSTER.md` or `office.conf`, generated — not retyped into the
   cloud-init file**, or we have reproduced the two-sources defect in the
   provisioning layer itself.
3. Create `/srv/office-state`, group `office`, `2770` so new files inherit the
   group; WORM archive owned by root and append-only to employees.
4. Snapshot the VM *before* anything is armed, so run 1 has a rollback point.
5. Deploy `office` into the VM and run `bootstrap.sh` **preflight-only**.
   Arming is a separate, later, deliberate step.
6. `notify-senechal` — a VM, a libvirt daemon, and N unix accounts on dexter
   are machine-wide config, and senechal owns knowing they exist.

## Two open decisions

1. **The boundary** — VM with users inside (proposed above), unix users
   directly on dexter (fastest, no kernel boundary), or one container per
   agent (per-employee destroy, but the mail bus needs real networking).
2. **Root access** — Zach runs an auditable provisioning script by hand
   (no standing privilege), a scoped `NOPASSWD` sudoers rule for named
   commands, or blanket `NOPASSWD`. Recommendation: one of the first two.
   Blanket root on the account that agent processes run as is hard to scope
   back, and a session on this host deleted a directory today for reasons that
   took a human witness to explain.

Both were put to Zach; neither is answered yet. Nothing proceeds past this
document without them.
