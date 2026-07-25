# senechal — steward of the environment

Observes and records the Linux environment (bin scripts, dotfiles, keybindings,
WM) so a from-scratch rebuild is painless. "Somewhat intimate — must guard
secrets even from other agents"; real `$HOME` scans forbidden unattended.

## Fable notes — scope creep watch

Senechal has quietly become three projects: (1) environment journal,
(2) keeper of names and places, (3) ecosystem registry for shared-host
script/autostart footprints. Each addition was reasonable; the sum is a weight-1
project carrying three missions. The fable version makes the footprint ledger a
**file format, not prose** (`FOOTPRINTS.tsv`: host · path · owner · installed ·
retired) so hygiene-lint can diff it against reality mechanically — and the
names half lives in a shared registry (realisateur/NAMES.md) rather than
prose-only. Missions that stay prose stay unfinishable.
