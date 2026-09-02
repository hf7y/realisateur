# provision/verbs-meta — the verb channel

`build-verbs.yml` belongs at `hf7y/verbs/.github/workflows/build-verbs.yml`
and is deployed there **by hand**; it is kept here because realisateur owns the
build logic it calls. `tests.yml`'s `deploy-drift` job is the only thing that
notices the two disagreeing, and it is advisory, never required.

## The channel, hop by hop

THE LEVER. A merged fix reaches a running account this way and no other:

```
<project>/main                the source
  -> <project>/bashified      a project DECLARES a verb by carrying an
                              executable bin/<n> there; a man/<n>.1 beside it
                              is carried when present, never required (#891,
                              bin/lib/verb-set.sh). realisateur's own carry is
                              bin/carry.sh, from bin/lib/carries.tsv
  -> bin/cut-verb-build.sh    reads every hf7y bashified branch, applies that
                              rule, and REFUSES an orphaned man page --
                              bin/lib/not-a-verb.tsv is the written opt-out
  -> build-verbs.yml          on hf7y/verbs, nightly `30 1 * * *`: assembles
                              every night, cuts every CUT_INTERVAL_DAYS (30)
  -> selfdev-release-tick.sh  from a crontab. PULL: no ssh, no push, no
                              hands-account reaching into a 0700 home
  -> install-verb-build.sh    verifies every verb the manifest promises and
                              discards the WHOLE build if any is missing,
                              then moves ONE symlink: <root>/current
```

`hf7y/verbs` is **public**, so the tick needs no credential to pull. The cut
still needs `VERBS_READ_TOKEN`, a PAT with READ on the account's repositories:
the default `GITHUB_TOKEN` sees only the public ones and would cut a SHORT
build that looks complete. **The count is in `manifest.tsv`, never in prose.**

## Two tiers, and only one has a clock everywhere

| tier | installed at | refreshed by |
|---|---|---|
| verbs | `/usr/local/bin` → `/usr/local/share/verb-builds/current` | the tick |
| host tools | `/usr/local/libexec/selfdev/**` | the tick, **host-wide only** |

`TICK_HOST_LIBEXEC` is empty unless `wire-release-channel.sh --host` set it
(#517), so the probes ride the clock on a host-wide install and **not** on a
per-account one: on mandark 2026-08-29 the verb pin was that morning's build
while `~/.local/libexec/selfdev` was 18 days old. The provision-class half is
a human's act on purpose (`bin/lib/carries.tsv` says why).

## Host-wide, not per-account

`wire-release-channel.sh --host` is the shape, and the reason is not tidiness:
`ssh <host> <verb>` is not a login shell, so its PATH holds nothing under
`$HOME` and a per-account install is **invisible from outside the account**.
mandark is per-account deliberately -- `~/.local/bin` PRECEDES `/usr/local/bin`
there and is full of `installe`-owned links, so a host-wide install would be
shadowed rather than adopted (VERB-DISTRIBUTION §7 reconciles the two).

## Retiring a verb is three acts

1. delete the source on `main`, and remove its `bin/lib/carries.tsv` row
2. delete the file from the project's `bashified` branch
3. declare the loss in `bin/lib/retired-verbs.tsv`

**Step 1 alone ships a zombie.** `carry.sh` is copy-only, so `carries.tsv` is
an allow-list of what to COPY and never a manifest of what should EXIST, and
the cut reads `bashified`. **Step 2 without step 3 refuses every nightly**:
since #749 the cut diffs verb NAMES and dies on a disappearance no
`retired-verbs.tsv` row explains, because a verb lost to a flaked API call
looks exactly like a retired one.

## On a consumer

```sh
install-verb-build.sh --check              # 1 = a newer build exists; 6 = BLIND
install-verb-build.sh --latest --apply     # install it and switch, atomically
install-verb-build.sh --rollback <id>      # back to a build already on disk
```

**BLIND is 6, not 3** (#334, #394): "could not reach the channel" is never
"up to date". `--link` is **off by default**; `installe` owns `~/.local/bin`.
