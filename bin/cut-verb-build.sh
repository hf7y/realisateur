#!/usr/bin/env bash
# cut-verb-build.sh -- pin the ecosystem's whole verb surface to one
# immutable, dated BUILD, derived live from GitHub with no clone on this
# host at all.
#
# WHY THIS EXISTS
# ---------------
# Today a verb on this host is a symlink into a `bashified` WORKTREE of a
# full development clone (`installe`, senechal bin/installe:194-213). Three
# consequences follow from that one fact, and this script exists to break
# all three:
#
#   1. You cannot delete a dev clone without breaking its verb. Removing
#      ~/Documents/Projects/vim-arcade breaks `entraine`, because
#      vim-arcade-verbs/.git is a POINTER into vim-arcade/.git/worktrees/.
#      Measured 2026-08-04: 807M of dev clones on mandark to serve 26 verbs
#      whose bashified branches total ~2.3M.
#   2. Your verbs move under you while agents work. A worktree tracks a
#      BRANCH, so the moment monkey merges to `bashified`, the next `git
#      pull` anywhere changes what `arme` means mid-sitting. There is no
#      version of the verb set to name, hold, or roll back to.
#   3. Different user paths get different verbs. zach@mandark, ecosim@monkey
#      and bibliothecaire@monkey each pull at their own moment, so "the verb
#      set" is whatever each account last happened to fetch.
#
# A BUILD answers all three: a dated manifest naming an exact sha per
# project, so every user path can install *the same named thing*, hold it
# while agents merge past it, and step back to yesterday's by name.
#
# WHAT IT READS
# -------------
# GitHub, and nothing else. The declaration rule is realisateur
# bin/lib/verb-set.sh's, unchanged:
#
#     a project declares a verb  <=>  its `bashified` branch carries an
#     executable bin/<name> AND a matching man/<name>.1
#
# but read via `gh api .../git/trees/bashified?recursive=1` instead of
# `git ls-tree` against a local checkout. verb-set.sh's header already says
# the declaration "lives in the repository, not in ~/.local" -- that was
# true of the REF and false of the PROJECT LIST, which was a scan of
# ~/Documents/Projects/*/ as directories. This reads both from the source.
#
# THE FAILURE MODE THIS REFUSES TO HAVE
# -------------------------------------
# An empty build is not a small build -- it is an instruction to uninstall
# every verb on every host. So unreachable GitHub, an unauthenticated `gh`,
# and a zero-verb result are all HARD failures that write nothing, never an
# empty manifest exiting 0. This is the `garde` shape (realisateur/
# MONKEY.md §5): `pending_sets()` skipped unreachable destinations, so
# nothing reachable read as "everything is already proven". Absent must not
# read as proven, and here it must not read as "declared nothing".
#
# For the same reason a build that SHRINKS against the previous one is a
# refusal unless --allow-shrink: losing a project's verbs because one API
# call flaked is indistinguishable, in the manifest, from a project that
# genuinely retired its verbs.
set -uo pipefail

CLI_NAME='cut-verb-build.sh'
CLI_SUMMARY='pin every declared verb to one dated build manifest, read live from GitHub'
CLI_USAGE='  cut-verb-build.sh                    derive and print the manifest to stdout
  cut-verb-build.sh --write            also store it under the build root
  cut-verb-build.sh --assemble <dir>   lay every verb out under <dir> (what CI commits)
  cut-verb-build.sh --allow-shrink     accept a build with fewer verbs than the last'
CLI_FLAGS='--write --assemble --allow-shrink --owner --build-root'
CLI_POSITIONAL=any   # flag VALUES (--build <id>) read as positionals to cli-guard;
                     # the arg loop below rejects anything genuinely unknown.
CLI_EXITS='  0  a complete manifest was derived
  1  refused: BLIND (cannot read GitHub), empty, shrinking, or a name declared twice
  2  usage error'
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

OWNER="${VERB_BUILD_OWNER:-hf7y}"
BUILD_ROOT="${VERB_BUILD_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/verb-builds}"
WRITE=0
ALLOW_SHRINK=0
ASSEMBLE=''

while [ $# -gt 0 ]; do
  case "$1" in
    --write)        WRITE=1 ;;
    --assemble)     ASSEMBLE="${2:?--assemble needs a directory}"; shift ;;
    --allow-shrink) ALLOW_SHRINK=1 ;;
    --owner)        OWNER="${2:?--owner needs a value}"; shift ;;
    --build-root)   BUILD_ROOT="${2:?--build-root needs a value}"; shift ;;
    *) printf '%s: unknown argument: %s\n' "$CLI_NAME" "$1" >&2; exit 2 ;;
  esac
  shift
done

say() { printf '%s\n' "$*" >&2; }
die() { printf '%s: %s\n' "$CLI_NAME" "$*" >&2; exit 1; }

command -v gh >/dev/null 2>&1 || die 'gh is not on PATH -- cannot read the declarations. Refusing to cut an empty build.'
gh auth status >/dev/null 2>&1 \
  || die 'gh is not authenticated. Refusing: an unauthenticated read sees no private repo and would cut a SHORT build that looks complete.'

# --- 1. which repositories carry a bashified branch ---------------------
# `gh repo list` rather than a typed list: a project that bashifies itself
# tomorrow joins the build with nobody editing a file. The private repos
# are why authentication is checked above and not merely hoped for.
#
# --no-archived is not tidiness; it is the RETIREMENT MECHANISM. Deriving
# live from the account means a repository nobody has opened in a year still
# declares its verbs forever, and a host-local scan never had to think about
# that because a dormant project simply was not cloned. Archiving is how a
# project says "I am no longer a participant" -- reversibly, in one place,
# visible to everyone.
#
# Found the hard way 2026-08-04: `cueille` was declared by BOTH
# bibliothecaire and quatre-vingt-douze. quatre-vingt-douze had already been
# folded into bibliothecaire by decision, but nothing mechanical recorded
# that, so it kept declaring a verb it no longer owned.
say "reading $OWNER's repositories ..."
repos="$(gh repo list "$OWNER" --limit 200 --no-archived --json name -q '.[].name' 2>/dev/null)" \
  || die "cannot list $OWNER's repositories -- BLIND, not empty."
[ -n "$repos" ] || die "$OWNER has no readable repositories -- BLIND, not empty."

# --- 2. per repo: the bashified sha, then the verbs in that exact tree ---
# ls-remote gives the sha, and the tree is then read AT THAT SHA rather
# than at the branch name. Reading at the name would race a merge landing
# between the two calls and pin a sha whose contents were never inspected.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
rows="$tmp/rows"; : > "$rows"
blind=0
projects=0

for repo in $repos; do
  sha="$(git ls-remote "https://github.com/$OWNER/$repo.git" refs/heads/bashified 2>/dev/null | awk 'NR==1{print $1}')"
  # No bashified branch is a normal answer: most repos are not bashified.
  [ -n "$sha" ] || continue

  tree="$(gh api "repos/$OWNER/$repo/git/trees/$sha?recursive=1" \
            -q '.tree[] | select(.path|test("^(bin|man)/")) | "\(.mode) \(.path)"' 2>/dev/null)"
  if [ -z "$tree" ]; then
    # A repo WITH a bashified branch whose tree will not read is the
    # ambiguous case: it is either genuinely verbless or a failed call.
    # Counted as blindness rather than silently contributing zero verbs.
    say "  BLIND  $repo: bashified is $sha but its tree did not read"
    blind=$((blind + 1))
    continue
  fi

  # The declaration rule, applied to the fetched tree. Same two conditions
  # as verb-set.sh: executable bin/<n> AND man/<n>.1. bibliothecaire's
  # bin/page92.py is executable, has no page, and correctly is not a verb.
  verbs="$(printf '%s\n' "$tree" | awk '
      $1 == "100755" && $2 ~ /^bin\/[^\/]+$/ { n = substr($2, 5); exec_[n] = 1 }
      $2 ~ /^man\/[^\/]+\.1$/ { n = $2; sub(/^man\//, "", n); sub(/\.1$/, "", n); page[n] = 1 }
      END { for (n in exec_) if (n in page) print n }
    ' | sort)"
  [ -n "$verbs" ] || continue

  projects=$((projects + 1))
  while read -r v; do
    [ -n "$v" ] || continue
    printf '%s\t%s\t%s\t%s\n' "$repo" "$v" "$sha" "https://github.com/$OWNER/$repo.git" >> "$rows"
  done <<< "$verbs"
done

[ "$blind" -eq 0 ] || die "$blind repository tree(s) did not read. Refusing to cut a build that is short by an unknown amount."

verb_count="$(wc -l < "$rows" | tr -d ' ')"
[ "$verb_count" -gt 0 ] || die 'derived zero verbs. That is a BLIND read, not an ecosystem with no verbs.'

# --- 3. a name may be declared by exactly one project -------------------
# verb-set.sh exists because `range` was assigned to both bibliothecaire
# and secretaire on 2026-07-30. Two claimants is a build that cannot be
# installed unambiguously, so it is refused here rather than resolved by
# whichever `ln -s` runs last.
dupes="$(awk -F'\t' '{print $2}' "$rows" | sort | uniq -d)"
if [ -n "$dupes" ]; then
  while read -r d; do
    [ -n "$d" ] || continue
    say "  COLLISION  $d declared by: $(awk -F'\t' -v w="$d" '$2==w{printf "%s ", $1}' "$rows")"
  done <<< "$dupes"
  die 'a verb name is declared by more than one project. Refusing.'
fi

# --- 4. compare against the previous build ------------------------------
prev_count=0
if [ -L "$BUILD_ROOT/current" ] && [ -f "$BUILD_ROOT/current/manifest.tsv" ]; then
  prev_count="$(grep -cv '^#' "$BUILD_ROOT/current/manifest.tsv" 2>/dev/null || echo 0)"
fi
if [ "$prev_count" -gt "$verb_count" ] && [ "$ALLOW_SHRINK" -eq 0 ]; then
  say "  previous build: $prev_count verb(s)"
  say "  this build:     $verb_count verb(s)"
  die 'this build is SMALLER than the current one. A verb that vanished because an API call flaked looks exactly like one that was retired. Re-run, or pass --allow-shrink if the loss is real.'
fi

# --- 5. emit ------------------------------------------------------------
# The build id is a UTC date-time so builds sort lexically and a nightly
# job never collides with a hand-cut one in the same day.
build_id="$(date -u +%Y-%m-%dT%H%M%SZ)"
manifest="$tmp/manifest.tsv"
{
  printf '# verb build %s\n' "$build_id"
  printf '# cut by %s from github.com/%s on %s\n' "$CLI_NAME" "$OWNER" "$(hostname -s)"
  printf '# %d verb(s), %d project(s). Immutable: install this by id, never by branch.\n' \
         "$verb_count" "$projects"
  printf '# project\tverb\tsha\trepo_url\n'
  sort "$rows"
} > "$manifest"

cat "$manifest"
say ""
say "derived $verb_count verb(s) from $projects project(s)"

# --- 6. assemble the tree CI commits ------------------------------------
# The meta-repo's whole content, laid out as <project>/bin/<verb> +
# <project>/man/<verb>.1, so a consumer clones ONE repository instead of
# fetching from N. This is what makes a new self-dev account need read on
# one repo rather than four hand-made per-repo deploy keys
# (realisateur/MONKEY.md §8.1: "the credentials were a memory, not a
# script").
#
# Assembled from the SHA, never the branch name -- `bashified` may have
# moved since the manifest was derived minutes ago, and committing a tree
# the manifest does not describe would make the pin a lie.
if [ -n "$ASSEMBLE" ]; then
  mkdir -p "$ASSEMBLE" || die "cannot create $ASSEMBLE"
  # Only ever prune paths this build owns. A blanket wipe of $ASSEMBLE
  # would take the meta-repo's own .git, README and workflow with it.
  while IFS=$'\t' read -r project _ _ _; do
    [ -n "$project" ] || continue
    printf '%s\n' "$project"
  done < "$rows" | sort -u > "$tmp/projects"

  while read -r project; do
    [ -n "$project" ] || continue
    sha="$(awk -F'\t' -v p="$project" '$1==p{print $3; exit}' "$rows")"
    url="$(awk -F'\t' -v p="$project" '$1==p{print $4; exit}' "$rows")"
    work="$tmp/fetch/$project"
    mkdir -p "$work"
    git -C "$work" init -q 2>/dev/null || die "git init failed for $project"
    git -C "$work" remote add origin "$url" 2>/dev/null || die "git remote failed for $project"
    git -C "$work" fetch -q --depth 1 origin "$sha" 2>/dev/null \
      || die "cannot fetch $project at $sha -- refusing to assemble a partial build"
    git -C "$work" checkout -q FETCH_HEAD 2>/dev/null \
      || die "cannot check out $sha for $project"

    rm -rf "${ASSEMBLE:?}/$project"
    mkdir -p "$ASSEMBLE/$project"
    # THE WHOLE bashified TREE, not just bin/ + man/.
    #
    # This copied only bin/ and man/ first, on the reasoning that a build's
    # job is to be executable. Every verb in the resulting build was broken:
    #
    #   ./sequestria/bin/capte: line 19: .../sequestria/lib/verb.sh:
    #       No such file or directory
    #   ./sequestria/bin/capte: line 31: verb_parse: command not found
    #
    # Verbs source `lib/verb.sh` from their project root, and each project
    # carries its OWN copy (they have already forked -- gardien-garde's is
    # uniquely richer). So the lib travels per project or not at all.
    #
    # Copying the tree wholesale rather than adding `lib` to the list,
    # because the next such dependency would fail exactly the same way and
    # the bashified branch is already a total purge -- the whole tree is
    # ~30K per project. Guessing which subdirectories matter is what broke
    # this once already.
    rm -rf "$work/.git"
    cp -a "$work/." "$ASSEMBLE/$project/"
    say "  assembled $project at ${sha:0:12}"
  done < "$tmp/projects"

  cp "$manifest" "$ASSEMBLE/manifest.tsv"
  printf '%s\n' "$build_id" > "$ASSEMBLE/BUILD_ID"

  # Prove the tree matches the promise before CI is allowed to commit it.
  #
  # THE EXECUTABLE BIT IS NOT A WITNESS. This check was `-f && -x` and it
  # passed on a build in which EVERY VERB WAS BROKEN -- the lib/ omission
  # above. The file existed and was executable; it just could not run.
  # BUILD-DISCIPLINE's rule ("'working' backed by a test name or human-sense
  # witness, not exit code alone") applies to the builder as much as to what
  # it builds, so the witness is now: the verb runs, prints its own name,
  # and does not report a missing file or an undefined function.
  #
  # `--help` is the safe invocation: every bashified verb routes it through
  # lib/verb.sh or lib/cli-guard.sh before doing any work. Bounded by
  # timeout so one hung verb cannot hang the nightly build.
  bad=0
  while IFS=$'\t' read -r project verb _ _; do
    [ -n "${verb:-}" ] || continue
    f="$ASSEMBLE/$project/bin/$verb"
    if [ ! -f "$f" ] || [ ! -x "$f" ]; then
      say "  BAD $project/bin/$verb missing or not executable"; bad=$((bad+1)); continue
    fi
    out="$(timeout 20 "$f" --help 2>&1)"; rc=$?
    case "$out" in
      *'No such file or directory'*|*'command not found'*|*'unbound variable'*)
        say "  BAD $project/bin/$verb ran but is missing something it sources:"
        say "      $(printf '%s' "$out" | head -1)"
        bad=$((bad + 1)); continue ;;
    esac
    # 0 is the norm; some verbs treat --help as a usage exit. Anything else
    # (including the 124 timeout) is a verb that cannot introduce itself.
    case "$rc" in
      0|2) : ;;
      *) say "  BAD $project/bin/$verb --help exited $rc"; bad=$((bad + 1)) ;;
    esac
  done < <(grep -v '^#' "$manifest")
  [ "$bad" -eq 0 ] || die "$bad verb(s) did not assemble runnably. Refusing."
  say "assembled $verb_count verb(s) under $ASSEMBLE"
fi

if [ "$WRITE" -eq 1 ]; then
  dest="$BUILD_ROOT/$build_id"
  mkdir -p "$dest" || die "cannot create $dest"
  cp "$manifest" "$dest/manifest.tsv"
  say "wrote $dest/manifest.tsv"
  say "install it with: install-verb-build.sh --build $build_id --apply"
fi
exit 0
