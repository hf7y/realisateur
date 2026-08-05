# provision/verbs-meta — standing up the verb meta-repo

The design and the reasoning are in `realisateur/VERB-DISTRIBUTION.md`.
This file is only the sequence, and what is left of it.

`build-verbs.yml` belongs at `hf7y/verbs/.github/workflows/build-verbs.yml`.
It is kept here because realisateur owns the build logic it calls
(`bin/cut-verb-build.sh`), and a workflow living only in the repo it writes
to is a workflow nobody reviews next to the script it runs.

## Where the sequence has got to

Steps 1 and 2 ran on **2026-08-04**. `hf7y/verbs` exists, private, carrying
the workflow and a generated-do-not-edit README:

```
$ gh repo view hf7y/verbs --json url,isPrivate
https://github.com/hf7y/verbs  private=true
$ gh workflow list --repo hf7y/verbs
build-verbs   active   327473587
```

**Step 3 is the whole remaining gate, and only Zach can pass it.**

```sh
# 3. the credential. Fine-grained PAT, READ on the account's repositories.
#    NOT the default GITHUB_TOKEN: it is scoped to hf7y/verbs alone, so it
#    would see only the public projects and cut a SHORT build that looks
#    complete.
gh secret set VERBS_READ_TOKEN --repo hf7y/verbs

# 4. cut one by hand first and READ THE MANIFEST before any host installs it
gh workflow run build-verbs --repo hf7y/verbs
gh run watch --repo hf7y/verbs
```

Until step 3 happens the workflow **cannot run at all**, and it says so
rather than half-running. Verified 2026-08-04 by dispatching it with no
secret present (run 30968541374):

```
##[error]VERBS_READ_TOKEN is not set on this repository.
...
looks complete. Refusing to run rather than produce one.
```

That also means the nightly `30 1 * * *` schedule fails every night until
the PAT is minted. That is intended noise: a build pipeline not yet able to
build should say so once a day, not sit quiet.

## What the first real run should produce

A hand run of the same script on mandark, 2026-08-04:

```
$ bin/cut-verb-build.sh --assemble /tmp/vb --owner hf7y
derived 32 verb(s) from 13 project(s)
assembled 32 verb(s) under /tmp/vb        # 1.6M, all 32 passing --help
```

If CI's first run derives materially fewer than that, the credential is
narrower than intended — read the manifest, do not install the build. The
`cueille` collision that made the very first hand run refuse was resolved on
2026-08-04 (bibliothecaire keeps it; `quatre-vingt-douze` is archived), so a
refusal now is news, not the expected greeting.

## Validating the pipeline without the PAT

`.github/workflows/verb-build-smoke.yml`, in **this** repository, runs both
contract suites and a live `--dry-run` derivation using only the default
`GITHUB_TOKEN`. It exists because the meta-repo's own workflow cannot be
exercised without the secret — its first real step checks out private
`hf7y/realisateur` — so "dry run in the meta-repo" is not in fact a
credential-free path, and this job is.

A dry run's verb count is **not** a build's verb count: it sees only public
repositories. `cut-verb-build.sh` refuses `--dry-run` together with
`--assemble` or `--write`, so no short read can become an artifact.

## Then, on a consumer

```sh
install-verb-build.sh --check              # is a newer build out? exit 3 = BLIND
install-verb-build.sh --latest --apply     # install it and switch, atomically
install-verb-build.sh --list               # what is here, and what is current
install-verb-build.sh --rollback <id>      # back to a build already on disk (no network)
```

`--link` (writing `~/.local/bin`) is **off by default**: `installe` owns that
directory and its manifest, and this script leaves anything installe owns
alone rather than clobbering it. Reconciling the two is a deliberate sitting
— see `VERB-DISTRIBUTION.md` §7.

## Retiring this

Delete `hf7y/verbs`. Nothing else in the ecosystem depends on it until
`installe` is taught to read a build, which has not happened.
