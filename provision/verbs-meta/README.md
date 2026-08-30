# provision/verbs-meta — the verb channel

`build-verbs.yml` belongs at `hf7y/verbs/.github/workflows/build-verbs.yml`
and is deployed there **by hand**. It is kept here because realisateur owns
the build logic it calls (`bin/cut-verb-build.sh`), and a workflow living only
in the repo it writes to is one nobody reviews next to the script it runs. The
`deploy-drift` job in `.github/workflows/tests.yml` is the only thing that
notices the two disagreeing; it is advisory, never required. Design and
reasoning: `vault:realisateur/VERB-DISTRIBUTION.md`.

## The channel, hop by hop

This is THE LEVER. A merged fix does not reach a running account because
someone walked its clones; it rides this, and nothing else:

```
<project>/main                the source
  -> <project>/bashified      a project DECLARES a verb by carrying an
                              executable bin/<n> AND a matching man/<n>.1
                              there (bin/lib/verb-set.sh). realisateur's own
                              carry is bin/carry.sh, from bin/lib/carries.tsv
  -> bin/cut-verb-build.sh    reads every hf7y bashified branch, applies that
                              rule, and REFUSES a half-declaration --
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
the default `GITHUB_TOKEN` is scoped to `hf7y/verbs` alone, so it would see
only the public projects and cut a SHORT build that looks complete.

**The count lives in the manifest, not here.** `head -3
<root>/current/manifest.tsv` says how many verbs from how many projects, plus
every recorded NOT-A-VERB judgement. A number written here rots between cuts.

## Two tiers, and only one has a clock everywhere

| tier | installed at | refreshed by |
|---|---|---|
| verbs | `/usr/local/bin` → `/usr/local/share/verb-builds/current` | the tick |
| host tools | `/usr/local/libexec/selfdev/**` | the tick, **host-wide only** |

`TICK_HOST_LIBEXEC` is empty unless `wire-release-channel.sh --host` set it
(#517), so the payload-class probes ride the clock on a host-wide install and
**not** on a per-account one. Measured on mandark 2026-08-29: the verb pin was
that morning's build while `~/.local/libexec/selfdev` was 18 days old. The
provision-class half (`dresse.sh` and what it runs) stays a human's act on
purpose — `bin/lib/carries.tsv` says why.

## Host-wide, not per-account

`wire-release-channel.sh --host` is the shape, and the reason is not tidiness:
`ssh <host> <verb>` is not a login shell, so its PATH holds nothing under
`$HOME` and a per-account install is **invisible from outside the account**.

mandark is per-account deliberately: `~/.local/bin` PRECEDES `/usr/local/bin`
there and is full of `installe`-owned links, so a host-wide install would be
shadowed rather than adopted — appearing to succeed while changing nothing a
shell resolves. Reconciling them is that vault file's §7.

## Retiring a verb is three acts

An agent can do only the first.

1. delete the source on `main`, and remove its `bin/lib/carries.tsv` row
2. delete the file from the project's `bashified` branch
3. dispatch `build-verbs.yml` (its `allow_shrink` input exists only on
   `workflow_dispatch`; the guard's own critique is #699)

**Step 1 alone ships a zombie.** `carry.sh` is copy-only, so `carries.tsv` is
an allow-list of what to COPY and never a manifest of what should EXIST: a
removed row means the file stops being updated, not that it stops shipping,
and the cut reads `bashified`. **Step 3 is gated on Zach** —
`workflow_dispatch` runs in the `release` environment, whose protection rule
is `required_reviewers: hf7y`. Step 2 without step 3 leaves the channel
refusing every night, so never do step 2 unattended.

## On a consumer

```sh
install-verb-build.sh --check              # 1 = a newer build exists; 6 = BLIND
install-verb-build.sh --latest --apply     # install it and switch, atomically
install-verb-build.sh --rollback <id>      # back to a build already on disk
```

**BLIND is 6, not 3** (realisateur#334, #394): "I could not reach the channel"
must never render as "you are up to date". `--link` (writing `~/.local/bin`)
is **off by default** — `installe` owns that directory and its manifest, and
this script leaves anything installe owns alone rather than clobbering it.
