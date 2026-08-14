# Retired scripts

Unwired, not deleted. Nothing on `PATH` reaches these and no command file
invokes them. They stay so their ideas can be mined rather than rediscovered.

Being here is what makes a script inert: `install-shims.sh` derives shims from
`bin/<name>.sh`, so nothing under `bin/retired/` can become a shim or be
resurrected by a docs edit.

| script | retired | why | mine it for |
|---|---|---|---|
| `hygiene-lint.sh` | 2026-08-14 | Discovered projects through the scheduler's schedule directory, so an estate-wide hygiene check saw only what one unrelated project had registered — and none at all on a host with no scheduler checkout. | hf7y/realisateur#265 |
