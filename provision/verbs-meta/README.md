# provision/verbs-meta — standing up the verb meta-repo

The design and the reasoning are in `realisateur/VERB-DISTRIBUTION.md`.
This file is only the sequence.

`build-verbs.yml` belongs at `hf7y/verbs/.github/workflows/build-verbs.yml`.
It is kept here because realisateur owns the build logic it calls
(`bin/cut-verb-build.sh`), and a workflow living only in the repo it writes
to is a workflow nobody reviews next to the script it runs.

## The sequence

```sh
# 1. the repository. An outward-facing act, so it is yours, not a script's.
gh repo create hf7y/verbs --private \
   --description 'assembled verb builds -- generated, do not hand-edit'

# 2. the workflow
git clone git@github.com:hf7y/verbs.git && cd verbs
mkdir -p .github/workflows
cp ~/Documents/Projects/realisateur/provision/verbs-meta/build-verbs.yml \
   .github/workflows/
git add -A && git commit -m 'the nightly verb build' && git push

# 3. the credential. Fine-grained PAT, READ on the org's repositories.
#    NOT the default GITHUB_TOKEN: it is scoped to this repo alone, so it
#    would see only the public projects and cut a SHORT build that looks
#    complete.
gh secret set VERBS_READ_TOKEN --repo hf7y/verbs

# 4. cut one by hand first and READ THE MANIFEST before any host installs it
gh workflow run build-verbs --repo hf7y/verbs
gh run watch --repo hf7y/verbs
```

## Expect the first run to refuse

As of 2026-08-04 `cueille` is declared by both `bibliothecaire` and
`quatre-vingt-douze`, and a name claimed twice is a build that cannot be
installed unambiguously. That refusal is the mechanism working. Resolve the
ownership, do not add a flag to skip it.

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
