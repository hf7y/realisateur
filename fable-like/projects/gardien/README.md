# gardien — backups

rsync+hardlink nightly backups of mandark + dexter onto Thunderbolt-2 RAID-5
(4×3TB). Unattended-safe by construction: everything tested against temp dirs;
never touches a real RAID mount until Zach verifies by hand. A model citizen —
the autonomy bar applied exactly right.

## Fable notes

- The TB2 cable is `waiting`, correctly tagged — it should cost zero glance
  anxiety. (This is why the blocking/waiting/fyi split matters.)
- Git-history-on-RAID fork decided (git remote + partial clone): record what the
  rejected option was and why, one line, so the decision survives its context.
