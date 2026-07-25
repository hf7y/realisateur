# scheduler — FOCUS

## Stability milestone
**Current:** every enabled project dispatches from exactly one host, fails loud when silent, and runs through the generic entrypoint — status: in-progress
Done when:
- [ ] liveness-audit cron-wired; a dark enabled project appears in the morning glance within 24h
- [ ] zero `*_SCRIPT` legacy wrappers referenced by any `_paced*.conf`
- [ ] `services/` view deleted; glance named as its replacement
- [ ] rotation log free of the `[legacy absolute path]` defect
Ideas beyond this bar are PARKED by default (see realisateur/STABILITY-MILESTONES.md).

## Current focus

- Fix the one `rc=1` dispatch (2026-07-25 00:19, scheduler batch) — read its run log; an uninvestigated nonzero exit is a silent failure wearing a timestamp
- Finish MIGRATION.md: port chezz, home-assistant, wtul off legacy wrappers
- Structural exclusion list for burst mode (home-assistant: physical side effects) — from the 2026-07-25 mega-burn writeup

## Parked

- **2026-07-23 (parked):** BLOCKERS.md blocking/waiting/fyi taxonomy — unify with active/parked/waiting, one vocabulary (routed from realisateur)
- **2026-07-25 (parked):** quota-aware automated mega-burn near deadline
