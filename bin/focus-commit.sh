#!/usr/bin/env bash
# focus-commit.sh <repo> <msgfile> <file>... -- atomic FOCUS/QUESTIONS write.
#
# TRAPS (the rest of this header is in the vault):
# Realisateur's own half of the multi-writer FOCUS-file write race (see
# .scheduler/FOCUS.md's 2026-07-26 write-race entry; scheduler owns the
# other half -- honest watcher attribution + a live-session probe). FOUR
# recorded occurrences as of 2026-07-26, one of which silently rewrote an
# archived artifact's content during a rename-following rebase and was
# caught only because a human happened to diff it by hand.
#
# Usage:
# exit-0 no-op.

set -uo pipefail

die() { printf 'focus-commit: FAIL: %s\n' "$*" >&2; exit 1; }
note() { printf 'focus-commit: %s\n' "$*"; }

case "${1:-}" in
  -h|--help|'') sed -n '2,/^set -uo/p' "$0" | sed 's/^# \{0,1\}//;$d'; exit 0 ;;
  # The first argument is a REPO PATH, so a flag reaching here is a misparse.
  # It used to surface as "not a directory: -s" (exit 1) -- loud, but it named
  # the wrong problem, and exit 1 is this script's real-failure code.
  --summon) printf 'focus-commit: --summon rejected: this tool makes no AI calls and cannot spend.\n' >&2; exit 2 ;;
  -*)       printf 'focus-commit: expected a repo path, got a flag: %s\n' "$1" >&2
            printf 'try `focus-commit.sh --help`\n' >&2; exit 2 ;;
esac

repo="$1"; msgfile="$2"; shift 2
[ "$#" -ge 1 ] || die "no files named -- usage: focus-commit.sh <repo> <msgfile> <file>..."

[ -d "$repo" ] || die "not a directory: $repo"
cd "$repo" || die "cannot cd into $repo"
git rev-parse --git-dir >/dev/null 2>&1 || die "not a git repo: $repo"

# msgfile is resolved before the cd-sensitive work below, but the caller may
# have given it relative to their own cwd -- accept either.
[ -f "$msgfile" ] || msgfile="$OLDPWD/$msgfile"
[ -f "$msgfile" ] || die "commit message file not found: $2"
[ -s "$msgfile" ] || die "commit message file is empty: $msgfile"

files=("$@")
for f in "${files[@]}"; do
  [ -e "$f" ] || die "named file does not exist in $repo: $f"
done

branch="$(git symbolic-ref --quiet --short HEAD)" \
  || die "detached HEAD -- refusing to commit a FOCUS write onto no branch"

upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)" \
  || die "branch '$branch' has no upstream -- set one before writing FOCUS files"
remote="${FOCUS_COMMIT_REMOTE:-${upstream%%/*}}"
tries="${FOCUS_COMMIT_TRIES:-3}"

# --- 1. stage EXACTLY the named files --------------------------------------
# Anything already staged that we did not name would ride along invisibly
# inside a FOCUS commit. That is how an uncommitted edit to a live script
# gets adopted under someone else's name (CLAUDE.md subagent rules, and the
# 2026-07-25 sync-crontab.sh incident). Loud abort, not a quiet `git add -A`.
preexisting="$(git diff --cached --name-only)"
if [ -n "$preexisting" ]; then
  printf '%s\n' "$preexisting" >&2
  die "index is not clean -- the above are staged but were not named. Unstage them (git restore --staged) and re-run."
fi

git add -- "${files[@]}" || die "git add failed"

staged="$(git diff --cached --name-only)"
[ -n "$staged" ] || die "nothing to commit -- the named files are identical to HEAD (refusing an empty commit)"

# Every staged path must be one we named (a directory argument can expand to
# several real paths, so compare against what `git add` of our args produced,
# not against the argument strings themselves).
expected="$(git diff --cached --name-only -- "${files[@]}" | sort -u)"
if [ "$(printf '%s\n' "$staged" | sort -u)" != "$expected" ]; then
  die "staged set does not match the named files -- refusing. staged: $(printf '%s' "$staged" | tr '\n' ' ')"
fi

# --- 1b. stamp the commit with the verb build that produced it -------------
# "What was ecosim running when it wrote that?" has to be answerable from the
# artifact alone, months later, by someone who was not there. A git trailer
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
_lib="$(dirname "${BASH_SOURCE[0]}")/lib/propagation-set.sh"
if [ -r "$_lib" ]; then
  # shellcheck source=lib/propagation-set.sh
  . "$_lib"
  if ! grep -qi '^Verb-Build:' "$msgfile" 2>/dev/null; then
    _stamped="$(mktemp)"
    cat "$msgfile" > "$_stamped"
    # A trailer block needs one blank line before it, or git folds it into
    # the body and `--format=%(trailers)` cannot see it.
    [ -n "$(tail -c1 "$_stamped")" ] && printf '\n' >> "$_stamped"
    tail -1 "$_stamped" | grep -q '^[A-Za-z-]\+:' || printf '\n' >> "$_stamped"
    prop_build_trailer >> "$_stamped"
    msgfile="$_stamped"
  fi
fi

# --- 2. record what we are about to push, so the rebase can be verified ----
base_before="$(git rev-parse '@{u}')"
git commit -q -F "$msgfile" || die "git commit failed"
head_before="$(git rev-parse HEAD)"

# The range diff: which files OUR unpushed commits touch, relative to the
# upstream they were written against, and the exact content of each.
range_manifest() { # <base> <head>
  local f
  git diff --name-only "$1" "$2" | sort -u | while IFS= read -r f; do
    printf '%s %s\n' "$(git rev-parse --quiet --verify "$2:$f" 2>/dev/null || echo ABSENT)" "$f"
  done
}
manifest_before="$(range_manifest "$base_before" "$head_before")"

note "committed $(git rev-parse --short HEAD) on $branch ($(printf '%s\n' "$staged" | wc -l) file(s))"

# --- 3. push, with fetch -> rebase -> VERIFY -> retry on rejection ---------
attempt=0
while :; do
  attempt=$((attempt + 1))
  # stderr is CAPTURED, never discarded -- a swallowed push error turns
  # "permission denied" into an indistinguishable "someone raced me", which
  # is the exact `2>/dev/null` failure BUILD-DISCIPLINE names. It is printed
  # on every path that gives up.
  push_err="$(git push -q "$remote" "$branch" 2>&1)" && {
    note "pushed to $remote/$branch: $(git rev-parse --short HEAD)"
    exit 0
  }

  if [ "$attempt" -gt "$tries" ]; then
    printf '%s\n' "$push_err" >&2
    die "push still rejected after $tries rebase round(s) (last error above) -- work is committed locally at $(git rev-parse --short HEAD), nothing pushed. Resolve by hand."
  fi

  note "push rejected (round $attempt/$tries) -- upstream moved. Fetching."
  git fetch -q "$remote" "$branch" || die "fetch failed -- cannot safely rebase"

  base_new="$(git rev-parse FETCH_HEAD)"
  if [ "$base_new" = "$base_before" ]; then
    printf '%s\n' "$push_err" >&2
    die "push rejected but upstream is unchanged at ${base_before:0:8} -- this is NOT a race (see the push error above). Check remote permissions/hooks."
  fi

  # Inspect the incoming work before touching our own -- this is the step the
  # standing rule says never to skip, printed so it lands in the run's log.
  note "--- incoming from $remote/$branch (${base_before:0:8}..${base_new:0:8}) ---"
  git log --oneline --no-decorate "$base_before..$base_new" | sed 's/^/    /'
  git diff --stat "$base_before" "$base_new" | sed 's/^/    /'
  note "--- end incoming ---"

  pre_rebase="$(git rev-parse HEAD)"
  if ! git rebase -q "$base_new" >/dev/null 2>&1; then
    git rebase --abort 2>/dev/null
    die "rebase onto ${base_new:0:8} CONFLICTED -- aborted, nothing lost, nothing pushed. Your commit is $pre_rebase. Resolve by hand."
  fi

  # --- the verification the bare sequence does not do ---------------------
  # Same set of files, same content. A rename-following auto-resolution that
  # quietly rewrote a file we never touched shows up here as an extra path;
  # an upstream edit silently merged into one of our files shows up as a
  # changed blob. Either way: stop, keep the work, tell the human.
  manifest_after="$(range_manifest "$base_new" "$(git rev-parse HEAD)")"
  if [ "$manifest_before" != "$manifest_after" ]; then
    printf '%s\n' "--- before rebase ---" >&2
    printf '%s\n' "$manifest_before" >&2
    printf '%s\n' "--- after rebase ---" >&2
    printf '%s\n' "$manifest_after" >&2
    git reset -q --hard "$pre_rebase"
    die "REBASE CHANGED WHAT OUR COMMIT MEANS (see manifests above) -- rebase undone, tree restored to $pre_rebase, NOTHING PUSHED. Either the rebase dragged in a file we never named, or upstream also edited one of ours. Inspect and resolve by hand."
  fi

  note "rebase onto ${base_new:0:8} verified clean -- same files, same content. Retrying push."
  base_before="$base_new"
  manifest_before="$manifest_after"
done
