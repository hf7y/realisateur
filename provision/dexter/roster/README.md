# roster — the estate's arming authority

`live`/`parked` for every project, served on dexter at `:8646`. `dose <project>
--arm/--park` writes it in one call and returns only once committed; nothing is
gated on a green build. `hf7y/scheduler:schedule/ROSTER` keeps the DECLARATION —
`project | account@host | rate`, reviewed and diffed — and says nothing about
liveness, so the two halves cannot disagree.

Deploys are automatic: `roster-autoupdate.timer` pulls hourly. By hand:
`sudo docker compose pull && sudo docker compose up -d`.

`data/` is service state, never overwritten from a repo; the source ships in the
image. `data/.env` holds `ROSTER_WRITE_TOKEN`; without it every write is refused.

Why it exists: hf7y/scheduler#429.
