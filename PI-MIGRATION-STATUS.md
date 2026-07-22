# crt Pi migration — status note (2026-07-22)

Dropped in from the `crt` project as reference context — the file
migration target switched from an Intel Compute Stick to a Raspberry Pi
3B after the Compute Stick attempt was abandoned (see
`COMPUTE-STICK-MIGRATION.md`, already in this inbox — 32-bit UEFI +
no-video + blind-preseed hangs that never resolved even on a trivial
test). The Pi has no equivalent firmware/GPU gap, so this migration is
going much more smoothly.

## Account split decision

Flashed Raspberry Pi OS Lite (64-bit) to a USB drive (Pi 3B boots off USB
directly, no SD card). Decided on a two-account split rather than a
single shared login:

- **`admin`** — sudo, unique hardened password, created at flash/init
  time. This is what got provisioned first so setup could proceed
  cleanly.
- **A low-privilege shared account** (the club's meme/shared-password
  account, `vkv` was the working name floated) — no sudo, created after
  first boot via `admin`. Not yet done as of this note.

Explicit reasoning: losing the `admin` password isn't a real
recovery risk on a Pi — pull the USB drive, mount its root partition on
another machine, and reset `/etc/shadow` directly (same mechanism used
below for the keyboard fix), no full reinstall needed.

## Keyboard-layout snag (still open-ish)

The Pi's console came up with a non-US keyboard layout, and the
mismatch was bad enough that even the *fix* commands
(`loadkeys us`, `setxkbmap`) couldn't be typed reliably — the Lite image
also turned out not to ship the `kbd` package's keymap files at all
(`loadkeys us` failed with "No such file us").

Working around it by never typing on the Pi console at all: pull the USB
drive, mount its partitions on another Linux box, and sideload config
directly onto the filesystem — same technique used for wifi credentials
(writing a `NetworkManager` `.nmconnection` file directly into
`etc/NetworkManager/system-connections/` on the root partition, since
Bookworm-based Pi OS doesn't read `wpa_supplicant.conf` from `/boot`
anymore) and for the keyboard fix itself (patching `XKBLAYOUT`/`XKBMODEL`
in `/etc/default/keyboard` on the mounted root partition). SSH access
is the intended real fix once the drive-sideload keyboard patch takes —
console interaction shouldn't be needed again after that.
