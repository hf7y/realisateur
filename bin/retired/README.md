# Retired scripts

Unwired, not deleted. Nothing on `PATH` reaches these and no command file
invokes them. They stay in the tree so their ideas can be mined rather than
rediscovered, and each has an issue naming what is worth bringing back.

Being in this directory is what makes a script inert: `install-shims.sh`
derives shims from `bin/<name>.sh`, so a file under `bin/retired/` cannot
become a shim, and cannot be silently resurrected by a docs edit.

| script | retired | why | what to mine |
|---|---|---|---|
| `hygiene-lint.sh` | 2026-08-14 | Discovered projects through `$SCHED_ROOT/schedule/*.conf`, so an estate-wide hygiene check could only see repos one unrelated project had registered — and saw **none at all** on mandark, which has no scheduler checkout. Zach: *"hygiene lint looking into scheduler for every other repo never made sense."* | hf7y/realisateur#265 — the `7c` unwired-deploy-key check, the `[ssh-remote]` passphrase-identity check, and above all its BLIND discipline (distinguishing "I could not look" from "nothing to report"). |
