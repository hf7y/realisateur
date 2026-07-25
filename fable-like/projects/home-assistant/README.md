# home-assistant — automation of a real house

Config/docs repo backed by a live HA instance controlling physical devices.
Correctly low autonomy tier, WebFetch allowed only because it's the sole way to
genuinely test the port-forward from outside the LAN. Renamed on disk from
`home_assistant` to match its registered name — one name, one spelling.

## Fable notes

- Carries the **oldest open vision-debt items in the ecosystem** (three from
  2026-07-18). Under oldest-first-is-a-signal: drain one, or explicitly park it
  with a note saying so. A week-old active item that nobody drains and nobody
  parks is the exact ambiguity the three-state vocabulary exists to kill.
- Structurally excluded from burst/concurrency experiments (physical side
  effects) — in the fable version that exclusion is a conf flag
  (`BURST_EXCLUDE=1 # touches physical devices`), not a remembered list.
