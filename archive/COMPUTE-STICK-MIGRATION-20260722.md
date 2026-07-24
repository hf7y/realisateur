# Compute stick migration (Intel Compute Stick STK1AW32SC) — ABANDONED

Copied in from the `crt` project as reference context for future
deployment decisions — not this project's own work, just lessons learned
from a hardware migration attempt that ended up steering toward a
Raspberry Pi instead. Original: `crt/COMPUTE-STICK-MIGRATION.md`.

**Outcome: abandoned after ~1hr+ blind hangs that didn't resolve even with
a trivial single-line preseed test. Migration target switched to a
Raspberry Pi instead** (see "Why we gave up" and "What's next" at the
bottom). Internal Windows install was never touched — every attempt hung
before reaching partitioning, so the stick's eMMC should be untouched;
unplug the USB and it should boot straight back into Windows.

Kept below for reference (the 32-bit-UEFI-boot and isohybrid-partitioning
techniques are reusable if anyone ever revisits Compute Stick hardware),
but **do not resume this path** without reading the "Why we gave up"
section first.

---

Side task, unrelated to the crt voice console's STT mission — flashing a USB
stick to install Debian on an Intel Compute Stick ahead of migrating project
files to a single system. Documented here for reference and so a future
agent picking this up mid-stream has the full story.

## Hardware

- **Device**: Intel Compute Stick **STK1AW32SC** — Atom Z3735F (Bay Trail),
  1GB RAM, 32GB eMMC, 2 USB ports, microSD slot (not bootable — secondary
  storage bus only).
- **Critical quirk**: ships with **32-bit UEFI firmware** despite a 64-bit
  CPU. A standard 64-bit ISO's `bootx64.efi` cannot be executed by this
  firmware — confirmed live via the internal UEFI Shell, which itself only
  runs `ia32` images (proof the firmware is genuinely 32-bit, not just a
  BIOS setting).
- **Also broken**: no usable video output for the Debian installer on this
  hardware. GRUB reports "no suitable video mode, booting blind" and the
  installer kernel never produces a picture, with or without `nomodeset`.
  Likely cause: PowerVR SGX544 graphics unsupported by stock kernel +
  flaky EFI framebuffer handoff across the 32-bit-firmware/64-bit-kernel
  boundary. Confirmed alive via Caps Lock toggling (keyboard/kernel
  responsive) with zero video regardless of cmdline flags tried
  (`nomodeset`, explicit `console=`, `fb=false`). **Working assumption:
  this install has to happen fully blind, via preseed.**
- USB stick used for all of this: `/dev/sda` on `mandark` (7.5GB, labeled
  WESDATA originally — user confirmed already backed up and safe to wipe).

## Distro choice: Debian, not Ubuntu

Ubuntu Server ISOs (24.04.x) dropped 32-bit EFI support — only ship
`bootx64.efi`. **Debian's netinst ISO turned out to also be 64-bit-only**
in the same way (confirmed by inspecting `EFI/boot/` inside the ISO — only
`bootx64.efi` + `grubx64.efi`, no `bootia32.efi`). The "Debian ships both"
assumption made early in this session was wrong and cost a round-trip.
Debian was still the right call for the OS itself (glibc/apt compatibility,
lighter base than Ubuntu Server) — the 32-bit boot problem had to be solved
separately (see below), and would have needed solving for any modern distro
on this firmware.

Also note: Debian dropped official **i386** netinst ISOs too (404 on
`cdimage.debian.org/debian-cd/current/i386/` for current release) — so
"just grab bootia32.efi from the i386 ISO" doesn't work anymore either.
Solution was to build one locally instead (see below).

## Getting a 32-bit UEFI bootloader

Package `grub-efi-ia32-bin` (from Ubuntu/Debian archives, available via
`apt` even on the amd64 `mandark` host) provides the modules needed to
build a standalone ia32 EFI binary with `grub-mkstandalone`.

**First attempt failed for a subtle reason worth remembering**: a
standalone GRUB that just `chainloader`s `BOOTX64.EFI` hits the *exact
same* "image type x64 not supported" error, because chainloading still
asks the firmware to execute an x64 PE binary directly. The fix that
actually works: have the **32-bit GRUB load the Linux kernel itself**
(`linux` / `initrd` commands), since GRUB's own kernel loader does the
long-mode switch internally and never asks the firmware to execute a
64-bit PE image. This is the real mechanism behind "32-bit UEFI can boot a
64-bit OS" — it's GRUB doing a mode switch, not firmware mixed-mode
support (which this firmware doesn't have).

Build command:

```
grub-mkstandalone -O i386-efi --compress=xz \
  -o BOOTIA32.EFI \
  --modules="part_gpt part_msdos fat iso9660 linux normal search" \
  "boot/grub/grub.cfg=/dev/stdin" <<'GRUBCFG'
insmod part_gpt
insmod part_msdos
insmod fat
insmod iso9660
insmod linux
search --no-floppy --set=root --file /install.amd/vmlinuz
linux /install.amd/vmlinuz ---
initrd /install.amd/initrd.gz
boot
GRUBCFG
```

Gotchas hit along the way:
- Building to `/tmp` failed with `Permission denied` even as root on this
  host — build to a project path instead.
- The stick's ESP (`sda2`) is only **3.6MB** — barely fits one GRUB image.
  Had to drop `all_video` module and add `--compress=xz`, and delete the
  now-unneeded `grubx64.efi` to make room.
- `mount` can fail with "already mounted" if a previous manual check left
  `/mnt/stick` mounted — scripts should `umount ... || true` defensively
  first.

## Disk layout on the stick after `dd`

The Debian netinst ISO is a hybrid isohybrid image. `dd`-ing it to `/dev/sda`
produces an odd-looking but *normal* layout:

```
/dev/sda1   755M  iso9660         (whole-image placeholder, "Empty" type in fdisk)
/dev/sda2   3.6M  vfat, type ef   (the real ESP — EFI/BOOT/*.efi lives here)
```

`sda1` and `sda2` **intentionally overlap** in sector ranges — this is
normal isohybrid structure, not corruption. `gdisk` gets confused and
prompts "MBR or GPT?" because of leftover GPT structures — **just answer
`q` to quit without writing, never pick 1/2/3** unless you mean to
convert the table. Use `sfdisk`/`fdisk` (which correctly report
`Disklabel type: dos`) instead of `parted` (reported "Partition Table:
unknown" on this image) or `gdisk`.

A third partition, `sda3`, was added afterward in the unused space after
`sda1` ends to hold installer kernels/initrds without needing to remaster
the whole ISO:

```
sudo sfdisk --append --no-reread /dev/sda   # start=1546240, type=c (W95 FAT32 LBA)
sudo mkfs.vfat -F 32 -n INSTALLDATA /dev/sda3
```

(`partprobe` after `sfdisk` appeared unreliable/silent-failure-prone on
this host — the partition device node still showed up fine via
udev/kernel even when the script seemed to die after `sfdisk`. If a script
exits silently right after `sfdisk` with no `mkfs`/`DONE` output, just run
the format-and-copy steps as a separate follow-up script — don't assume
`sfdisk` itself failed.)

## Booting from the ia32 UEFI Shell (manual recovery path)

BIOS boot menu (F10) did **not** list the USB stick as a boot option on
this firmware even with USB Boot enabled — a known quirk, not a config
error. Recovery path when this happens: boot into the **Internal UEFI
Shell** (a BIOS boot-menu option) and drive it manually:

```
map -r                      # list filesystem mappings, look for the small FAT one
fs3:                        # (or whichever fsN: matches — varies by boot)
cd EFI\BOOT
BOOTIA32.EFI                # runs our standalone grub, which searches+boots the kernel
```

Device naming inside GRUB itself does **not** match the shell's `fsN:`
numbering — GRUB uses `(hd0)`, `(hd1)`, etc. On this board `hd0` mapped
to the **USB stick** while `hd1` turned out to be the **internal Windows
disk** (identified by finding `bcd`/`System Volume Information` when
listing `(hd1,gpt1)/`). The ISO9660 data partition on the stick shows up as
the raw whole-disk `(hd0)` itself, **not** as a numbered `(hd0,msdosN)`
partition — El Torito hybrid images often expose the ISO filesystem this
way. The writable `sda3` partition added later showed up as `(hd0,msdos3)`.

## Preseeding the install (fully unattended, since there's no video)

Since the installer could never be seen, the plan was to make it fully
unattended via Debian preseed, embedded directly into a modified initrd
(the standard "initrd preseeding" technique — append a tiny uncompressed
cpio archive containing `preseed.cfg` to the end of the existing
compressed `initrd.gz`; the kernel's initramfs unpacker handles
concatenated archives, and a later archive's files win over earlier ones
with the same path):

```
(cat original-initrd.gz; echo preseed.cfg | cpio -H newc -o) > initrd-preseeded.gz
```

Kernel cmdline to actually load and use it:

```
auto=true priority=critical preseed/file=/preseed.cfg
```

A diagnostic-only preseed variant was built first (safe, no disk writes)
to nail down the actual internal eMMC device name via a
`preseed/early_command` that dumps `/proc/partitions`, `disk/by-id`, and
`lsblk` output to a file on the stick's own ESP, then powers off before
partitioning ever starts. Two destructive candidate preseeds were also
built (targeting `/dev/mmcblk0` and `/dev/mmcblk1`, the two likely names
on this Bay Trail chipset) — full-disk wipe, offline install (no network
config baked in, since WiFi firmware isn't in the installer and there's no
wired ethernet), sudo user account, `openssh-server` included.

**Important, if this pattern gets reused**: fully-unattended blind installs
are inherently risky — no screen means no confirmation before a
destructive partitioning step runs, so getting the target disk name
right *before* committing to a real (non-diagnostic) install matters far
more than in a normal sighted install.

## Why we gave up

Ran the diagnostic boot (safe, no-disk-writes version) twice — both hung
indefinitely in blind mode (kernel/keyboard alive via Caps Lock toggling,
fan hot, but no poweroff, no diagnostic file ever written). Rebuilt with a
mount-retry loop and progress checkpoints — same hang. Verified via direct
inspection (not guesswork) that the preseed-embedding technique itself was
structurally correct: the appended cpio archive's magic bytes (`070701`)
landed exactly where the base `initrd.gz`'s gzip stream ended, and
extracting it back out showed the exact intended `early_command` content.
So the embedding mechanism wasn't the bug.

To isolate further, built the simplest possible test — a single-line
`d-i preseed/early_command string poweroff -f`, no loops, no multi-line
shell, nothing that could be mangled by preseed's line-continuation
parsing. **This hung identically for over an hour.** A trivial
"power off immediately" command failing to execute at all, combined with
every more-complex variant failing the exact same way regardless of
content, points away from a preseed/shell-syntax bug and toward something
lower-level — most likely this stick's flaky 32-bit-UEFI/USB stack failing
to load the ~24MB `initrd-*.gz` correctly (a truncated or corrupted
initramfs would explain a wedged early-userspace that behaves identically
no matter what's inside it — the kernel itself boots fine since that comes
from a separate, much smaller read via GRUB's own FAT driver). This wasn't
independently confirmed (no way to verify blind), but it's the most
consistent explanation across all the evidence gathered.

**Conclusion**: further blind iteration on this class of hardware has
diminishing returns once even a trivial no-op preseed fails to execute.
That's the signal to stop and pivot rather than keep guessing at preseed
content.

## Takeaways for future deployment decisions

- **Bay Trail-era Intel Compute Sticks (STK1-series) are a poor target**
  for anything beyond their original stock OS: 32-bit UEFI firmware, no
  supported GPU driver in mainline kernels, and (on this unit) an
  apparently flaky USB read path that broke even a trivial unattended
  install. Don't default to reusing one of these for a "just needs to run
  headless Linux" project — the setup cost is very high for very low
  compute payoff (1GB RAM, single-core Atom).
- **Raspberry Pi is the better default** for small headless Linux
  deployments needing "maximum platform compatibility" — normal
  boot chain, well-supported hardware, no equivalent firmware fights.
- If a fully-blind/unattended install is ever necessary again on
  suspect hardware, **test the absolute minimum viable automation first**
  (a single no-op command) before investing in a full preseed — it would
  have surfaced this hardware's fundamental problem in one iteration
  instead of several.
