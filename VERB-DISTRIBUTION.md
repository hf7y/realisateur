# VERB-DISTRIBUTION.md — how a verb reaches a user path

*Opened 2026-08-04, Zach-directed, while asking what it would take to remove
vim-arcade's clone from mandark. Sibling to `MONKEY.md` (where development
went) and `THE-UNWIRING.md` (what was parked). This one says how the thing
agents build on monkey gets **back** to the hands that use it.*

**Status: built and standing, waiting on one credential. `cut-verb-build.sh`
and `install-verb-build.sh` exist and are tested (17/17 `bin/tests/
verb-build-test.sh`, 31/31 `bin/tests/cut-verb-build-test.sh`). The
meta-repo `hf7y/verbs` exists as of 2026-08-04 with its workflow installed
and registered. It has cut **no build**: the workflow refuses to start
without `VERBS_READ_TOKEN`, a PAT only Zach can mint. Nothing on this host
has been switched over; `installe` is untouched and still owns
`~/.local/bin`.**

Every figure below was produced by a command on 2026-08-04. Where something
has not run, this file says so.

---

## 1. The question, and why the obvious answer was wrong

*"vim-arcade can go away and self-dev on monkey via my issue reports. What's
a way of removing the general project while keeping the verb and its
actions?"*

vim-arcade **had already moved**: account #4 on monkey, uid 3000, a `0 */6`
runner line in its own crontab, `ANSWER_CHANNEL="issues"`, and no vim-arcade
cron line left on mandark. So the question was only ever about the mandark
side. `fauche` said `KEEP`, and its reason was the whole problem:

```
KEEP          vim-arcade
  - a worktree outside this repo depends on it: .../vim-arcade-verbs
KEEP          vim-arcade-verbs
  - a worktree outside this repo depends on it: .../vim-arcade
```

```
$ cat ~/Documents/Projects/vim-arcade-verbs/.git
gitdir: /home/zach/Documents/Projects/vim-arcade/.git/worktrees/vim-arcade-verbs
```

`vim-arcade-verbs` is not a repository. It is a **worktree of the dev
clone**, so deleting the project directory breaks `entraine`. That is not an
accident of this project — it is what `installe` does, for every project:

```sh
# senechal bin/installe:194-213
local repo="$PROJECTS/$project"
tree="$PROJECTS/$project-verbs"
git -C "$repo" worktree add "$tree" bashified
```

**The first design in this document was a per-project runtime clone.** It
was replaced twice by Zach, and both corrections are the reason the answer
is any good, so they are recorded rather than smoothed over.

## 2. The two corrections

**(a) "This should be done generalizably — all repos on mandark have a
similar shape."** Right, and it killed a plan that would have edited
vim-arcade's own `joue` to teach it about updates. Nothing project-specific
survives: no project's code changes at all.

**(b) "With no repos on mandark other than senechal, senechal should be able
to produce the entire functioning verb set."** This is the real design, and
probing it found **three** couplings to the dev clone, not one:

| # | where | what it does | consequence |
|---|---|---|---|
| 1 | `realisateur bin/lib/verb-set.sh:84` | `verb_set_declared()` iterates `~/Documents/Projects/*/` **as directories** | no dev clone ⇒ the verb is not declared at all |
| 2 | `senechal bin/installe:194-213` | `git worktree add` off the dev clone | the verb tree *is* part of the dev clone |
| 3 | `install-verbs.sh` registry | reads `scheduler/schedule/*.conf` | needs the scheduler clone too |

`verb-set.sh`'s own header says declarations are read with `git ls-tree` so
that "a project needs no checkout of `bashified` for its verbs to count".
That is true of the **ref** and false of the **project list**, which was a
filesystem scan. Nobody had noticed, because on mandark every project
happened to be cloned.

**(c) "All user paths should have the same verbs; they should stay stable
while agents work on their next versions; we can work off nightly builds."**
This is what makes it a *distribution* problem rather than a *layout*
problem — see §4.

**(d) "Could GitHub Actions unite every repo's verb set into one clone-able
meta-repo?"** Yes, and it is strictly better than the N-fetch design it
replaced. See §5.

## 3. What is actually being carried

Measured on mandark, 2026-08-04:

```
807M    ~/Documents/Projects            (all dev clones)
  6.1M  vim-arcade/  = 4.1M .git + 1.2M tests + 548K engine
968K    three bashified branches, cloned standalone, shallow
~2.3M   projected for all seven
```

A standalone shallow clone of a `bashified` branch works with **no dev clone
present** — verified by running `entraine --help` (rc=0) from one. The
`bashified` branch was designed for exactly this and nothing was using it
that way.

**The seam is not bash-versus-Python.** Zach: *"the seam is between end
products and dev environment utilities. the latter should be bashify
shaped."* By that test `joue` — which triages your live GitHub issue queue —
is a dev utility and belongs in the verb set, notwithstanding that it is a
548K stdlib-only Python engine. It is **not** in the declared set today
(26 verbs; `joue` is not among them) because the rule wants `bin/<name>` +
`man/<name>.1` on `bashified`. So `~/.local/bin/joue` is a hand-installed
symlink into a dev clone, owned by nothing and invisible to
`install-verbs.sh` — the same unowned-symlink shape as scheduler's
2026-07-29 dispatch outage. **Bringing `joue` under the contract is open
work, named in §7.**

## 4. Why a *build*, and not a branch you track

A worktree tracks a branch. So the moment monkey merges to `bashified`, the
next fetch anywhere changes what `arme` means mid-sitting, and there is no
version of the verb set to name, hold, or return to. Three separate things
follow, and one construct fixes all three:

> A **build** is a dated manifest naming an exact sha per project. Every
> user path installs *the same named thing*, holds it while agents merge
> past it, and steps back to yesterday's by name.

The consumer layout, and the one indirection that carries the whole idea:

```
~/.local/share/verb-builds/
  repo/                  one clone of the meta-repo
  2026-08-05T0130Z/      a build, extracted from tag build/<id>
  2026-08-04T0130Z/      yesterday's, kept for rollback
  current -> 2026-08-05T0130Z

~/.local/bin/entraine -> ~/.local/share/verb-builds/current/vim-arcade/bin/entraine
```

**The `~/.local/bin` links are written once and never again.** Adopting a
build, or rolling back, repoints **one** symlink, so the verb set changes
all at once or not at all. N independent `git pull`s cannot express that:
they half-succeed and leave you running a verb set that never existed as a
whole and cannot be named in a bug report.

## 5. Why a meta-repo, and what it retires

CI assembles every project's `bin/` + `man/` into one repository, tagged
`build/<id>`. Three things collapse at once:

- **One clone, not 26 fetches.** ~2.3M, one network dependency.
- **The deploy-key sprawl ends.** `MONKEY.md` §8.1 records four hand-made
  per-repo deploy keys *per self-dev account*, and Zach's verdict on it:
  *"we can't do this for every install."* A consumer now needs read on
  **one** repo. The Actions runner holds the org-wide credential instead.
- **The build is a git tag.** "Stable while agents work" needs no machinery
  — you are on `build/2026-08-05` until you choose otherwise, and rollback
  is a checkout.

**The build logic is not in the YAML.** The workflow runs realisateur's
`bin/cut-verb-build.sh`. Retyping the declaration rule into a workflow file
would create a second source of truth for the one question the ecosystem
already has a single answer to (`bin/lib/verb-set.sh`), and
BUILD-DISCIPLINE's *"config read from one source, not retyped per file"*
applies to a derivation as much as to a hostname. CI and a human at a
terminal run the same script.

### What the build refuses to be

Each refusal is a failure this estate has already had once:

| refusal | the precedent |
|---|---|
| **BLIND** — GitHub unreachable, or `gh` unauthenticated | `garde` reported "nothing pending — every set is already copied and proven" with nothing reachable (`MONKEY.md` §5). An empty build is not a small build; it is an instruction to uninstall every verb on every host. |
| **shrinking** without `--allow-shrink` | a verb lost to a flaked API call is indistinguishable, in a manifest, from one genuinely retired |
| **a name declared twice** | `range` was assigned to both bibliothecaire and secretaire on 2026-07-30 |
| **switching to an unverified build** | scheduler's 2026-07-29 total dispatch outage was ONE missing symlink no check could say should exist |
| **claiming currency when it could not look** | `--check` exits **3 BLIND**, never 0 |

**The unauthenticated case deserves its own line.** A `gh` that is not
logged in still lists *public* repositories, so it would cut a build that is
short by exactly the private projects and looks perfectly complete. That is
why authentication is asserted rather than hoped for.

## 6. What has run, and what has not

**Run.** `bin/tests/verb-build-test.sh` — 17/17, against a local fixture
meta-repo over `file://`, so the suite is not itself subject to the
blindness it tests for. It asserts, among others, that a build missing a
promised verb is *discarded* rather than switched to; that rollback works
with the remote unreachable; that `--link` leaves another installer's link
untouched; and that after a rollback the *same* `~/.local/bin` link resolves
to the older build.

**Run, and it found three things.**

**(1) A verb name declared twice.** The first live `cut-verb-build.sh`
refused:

```
reading hf7y's repositories ...
  COLLISION  cueille declared by: bibliothecaire quatre-vingt-douze
cut-verb-build.sh: a verb name is declared by more than one project. Refusing.
```

**mandark could not see this.** `quatre-vingt-douze` has no clone here, so
`verb_set_declared()`'s directory scan never considered it, and
`install-verbs.sh` reports `OK -- all 26 declared verb(s) present` — a clean
bill of health it was structurally incapable of withholding. This is the
`range` collision recurring, caught on the new mechanism's first run.

**Resolved 2026-08-04, Zach: bibliothecaire keeps `cueille`; 92 was already
decided to fold into bibliothecaire and stop existing separately.** The
mechanical record of that decision was missing, which is why a retired
project was still declaring a verb. `quatre-vingt-douze` is now **archived**
(reversible: `gh repo unarchive hf7y/quatre-vingt-douze`), and
`cut-verb-build.sh` passes `--no-archived`. Archiving is therefore the
**retirement mechanism**, not tidiness: deriving live from the account means
a dormant repository would otherwise declare its verbs forever, which a
host-local scan never had to think about because a dormant project simply
was not cloned. 92's entire bashified surface was one verb; bibliothecaire
already carries both `bin/cueille` and `bin/page92.py`.

**(2) mandark was missing six projects and six verbs.** With the collision
resolved the build cuts clean — and it is bigger than what this host knew
about:

```
derived 32 verb(s) from 13 project(s)      <- from GitHub
      26 verb(s) from  7 project(s)        <- install-verbs.sh, same day
```

The six never visible from mandark, because they have no clone here:
`baudin/loge`, `chezz/joue`, `crt/sonne`, `groc-mangr/mange`,
`nine-speakers/chante`, `sequestria/capte`. The whole assembled surface is
**1.6M**.

**And it exposes a live conflict.** `chezz` **declares** `joue`; this host's
`~/.local/bin/joue` is the hand-installed symlink into vim-arcade's dev
clone. An undeclared link is shadowing a declared verb, and neither
`installe` nor `install-verbs.sh` can see it, because the shadowing link is
owned by nothing. This sharpens the `joue` question in §7 from "should it be
a verb" to "**two things are already called `joue`**".

**(3) The executable bit is not a witness.** The assemble step first copied
only `bin/` and `man/`, and its verification — `-f && -x` — passed on a
build in which every verb was broken:

```
./sequestria/bin/capte: line 19: .../sequestria/lib/verb.sh: No such file or directory
./sequestria/bin/capte: line 31: verb_parse: command not found
```

Verbs source `lib/verb.sh` from their project root and each project carries
its own (already-forked) copy. Two fixes, and the second matters more: the
assemble now copies the whole bashified tree, and the check now **runs each
verb's `--help` and requires it to introduce itself** rather than merely
exist. Caught only because the assembled verbs were run by hand — which is
precisely BUILD-DISCIPLINE's "*'working' backed by a test name or
human-sense witness, not exit code alone*", failing inside the builder that
is supposed to enforce it.

**Run, later on 2026-08-04: the meta-repo now exists.** `hf7y/verbs`,
private, carrying `.github/workflows/build-verbs.yml` and a
generated-do-not-edit README; `gh workflow list` shows `build-verbs active
327473587`. Steps 1 and 2 of the stand-up are done.

**Still not run: any build at all.** Step 3 is the gate and it is a human's:

3. Add secret `VERBS_READ_TOKEN`: a fine-grained PAT with **read** on the
   account's repos. The default `GITHUB_TOKEN` is scoped to the meta-repo
   alone and would silently produce the short-build failure above.
4. `gh workflow run build-verbs` and read the manifest before any host
   installs it. As of 2026-08-04 a hand run of the same script produces 32
   verbs from 13 projects, 1.6M, all 32 passing the `--help` witness.

The workflow now refuses to start at all without that secret rather than
failing later at a checkout 404 — dispatched with no secret, run
30968541374 ends at its first step: *"VERBS_READ_TOKEN is not set on this
repository ... Refusing to run rather than produce one."* Which also means
the nightly cron fails every night until the PAT exists, deliberately.

### What hardening the workflow found

Three defects, none of which a hand run on mandark could have shown,
because all three only appear on a machine with no previous build on it.

**(1) The shrink refusal was a no-op in CI.** It compared against
`$BUILD_ROOT/current` — `~/.local/share/verb-builds` — which on a fresh
Actions runner does not exist, so `prev_count` stayed 0 and no build could
ever be smaller than it. The one check whose stated purpose is to catch a
*nightly* build that lost a project to a flaked API call was disabled in
the only place a nightly build runs. In CI the previous build is not
missing, it is merely elsewhere: the meta-repo checkout being assembled
into carries the last build's `manifest.tsv`. That is now also consulted,
larger record wins.

**(2) Retirement did not propagate to the tree.** Each project directory is
removed and re-copied, so a project that *changed* was handled; a project
that *left* was not. Nothing deleted its directory, so `git add -A` would
re-commit a retired project's verbs every night and every consumer would
keep installing a verb the manifest no longer names. This silently voids
the archiving mechanism §5 rests on — archiving `quatre-vingt-douze` to
settle the `cueille` collision would have dropped the row and left the
executable in place. Verified before the fix by assembling three times into
one directory with a planted `quatre-vingt-douze/bin/cueille`: it survived
every run. The prune is driven by the previous build's own manifest, never
by a directory listing, because `$ASSEMBLE` also holds the meta-repo's
`README.md`, `.github/` and `.git`.

**(3) The workflow's own no-change branch was unreachable.** `BUILD_ID` is a
fresh timestamp every run, so `git diff --cached --quiet` was never true and
the nightly job would have cut a distinct tag every night over a
byte-identical tree — a stream of names for one artifact, which is the
opposite of a build you can name and hold. The comparison is now on the
payload (manifest body plus assembled files); a night in which no project
moved cuts no tag.

Also hardened: `GIT_TERMINAL_PROMPT=0`, so a repository the credential
cannot read fails instead of waiting on a password prompt no runner will
ever answer, and an `ls-remote` that *fails* is now counted BLIND rather
than read as "this project has no bashified branch" — the two were
indistinguishable in an empty sha and mean opposite things. Manifest rows
are shape-checked (four fields, 40-hex sha, a `repo_url` naming its own
project) before emission, so a malformed row is refused here rather than
discovered by a consumer required to throw the whole build away.

`bin/tests/cut-verb-build-test.sh` (31 tests) covers all of the above,
hermetically: a fake `gh` and fixture repositories reached over `file://`,
so the suite cannot pass merely because GitHub happened to be up.

### Validating the pipeline with no credential

`.github/workflows/verb-build-smoke.yml` — realisateur's first CI workflow —
runs both contract suites and a live `cut-verb-build.sh --dry-run` using
only the default `GITHUB_TOKEN`. It lives in realisateur rather than the
meta-repo because a "dry run" dispatched in `hf7y/verbs` is *not* a
credential-free path: its first real step checks out private
`hf7y/realisateur` to obtain the script it would dry-run.

`--dry-run` derives and shape-checks a manifest, writes nothing, and cannot
be combined with `--assemble` or `--write`. That exclusion is the point: a
credential-limited read is short **by construction** — it sees the public
repositories and misses every private project — and a short build that
looks complete is the precise failure §5 is built around. So the smoke path
is structurally incapable of producing an artifact, and it says so in its
own output rather than leaving a reader to infer it from a small number.

## 7. Open, each with its real question stated

- **`joue`, twice over.** Two things are called `joue`: chezz **declares**
  one, and vim-arcade has an undeclared hand-installed symlink currently
  shadowing it on this host. So there are two questions, and the naming one
  comes first. Then the shape one: `joue` should feel like every other verb,
  but the declaration rule wants `bin/<n>` + `man/<n>.1` on `bashified` and
  vim-arcade's is a stdlib-only Python engine on `main` — *does `bashified`
  carry an engine, or does the rule grow a second shape?* Until both are
  answered, `~/Documents/Projects/vim-arcade` cannot be deleted, because
  `~/.local/bin/joue` points into it. **This is the original question that
  opened this document, and it is the one thing still genuinely open.**
- **`installe` must learn to install from a build.** This is the chokepoint
  change and it is deliberately not made here. `installe` owns `~/.local/bin`
  and its manifest; `install-verb-build.sh --link` therefore refuses to
  clobber anything installe owns and reports it instead. Reconciling the two
  is one sitting, and it is a contract change to the ecosystem's single
  verb-installing command — `MONKEY.md` §9 already flags that class.
- **Registration versus live derivation.** See the `cueille` note in §6.
- **`notify-senechal` from a self-dev account still exits 8.** Unchanged
  from `MONKEY.md` §8.1(2), and a build cut by CI rather than by a host does
  not fix it — but it does remove one of the three reasons an account needed
  write access anywhere.

---

*The removal of any dev clone from mandark remains a human's act. `fauche`
writes the script and never runs it, and that is the right shape for this
too: nothing in §6 deletes anything.*
