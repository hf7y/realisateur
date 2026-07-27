#!/usr/bin/env bash
# notify-senechal.sh <text> -- file a machine-config change through senechal's
# own front door, and make sure it actually LANDED where senechal reads it.
#
# THE STANDING RULE THIS MECHANIZES (Zach-directed, reaffirmed 2026-07-26):
# realisateur GENERATES machine-wide config (crontab entries, ~/.claude
# settings hooks, systemd units, autostart, WM config, marker files under
# ~/.local/share); senechal OWNS KNOWING IT EXISTS. Ownership of the thing
# itself stays with realisateur -- precedent is the `# >>> realisateur-owned`
# block inside Zach's crontab: one project owning its own entry inside a
# shared machine-config surface.
#
# WHAT IT RETIRES: the prose promise. Until now this rule lived only as a
# remembered policy ("cross-write a dated note to senechal's FOCUS.md"), and
# prose decays -- UNIVERSE.md's own doctrine. On 2026-07-26 the cross-write
# for the SessionStart/SessionEnd hook was deferred (senechal was mid-run),
# recorded as owed in QUESTIONS.md, and only paid a session later by hand.
# That is exactly the failure mode a script removes.
#
# WHY THE FRONT DOOR AND NOT A DIRECT FOCUS.md EDIT:
# `scheduler -i senechal` routes through cmd_commit_file -- the same
# staleness-checked single-file commit path the vim auto-commit hook uses.
# That IS the multi-writer regulator for this interface, so it is safe
# against a live senechal run in a way a hand edit is not. The 2026-07-26
# check-project-busy.sh deferral was belt-and-braces on top of it.
#
# WHY IT DOES NOT STOP AT `scheduler -i`:
# `scheduler -i` deliberately SKIPS the push when the target repo is behind
# origin, printing "run git push by hand". An unpushed note is invisible to
# senechal's own nightly run, which clones from the remote -- the
# "verified where the consumer reads it" row of BUILD-DISCIPLINE. So this
# script resolves the divergence itself and verifies the rebase did not
# change what the commit means, the same check focus-commit.sh makes.
#
# Usage:
#   bin/notify-senechal.sh 'realisateur added <what> at <where>; ownership: ...'
#
# Exit 0 ONLY if the note is on senechal's remote. Every other path exits
# non-zero with a stated reason -- no exit-0 no-op.
set -uo pipefail

SCHED_ROOT="/home/zach/Documents/Project Archive/scheduler"
SENECHAL="/home/zach/Documents/Projects/senechal"

die() { printf 'notify-senechal: FAIL: %s\n' "$*" >&2; exit 1; }

text="${1:-}"
[ -n "$text" ] || die "no text given. Usage: notify-senechal.sh '<what changed, where, who owns it>'"

[ -x "$SCHED_ROOT/bin/scheduler" ] || die "scheduler front door not found/executable at $SCHED_ROOT/bin/scheduler"
[ -d "$SENECHAL/.git" ]           || die "senechal repo not found at $SENECHAL"

# --- 1. file it through the front door -------------------------------------
echo "notify-senechal: filing via 'scheduler -i senechal'..."
"$SCHED_ROOT/bin/scheduler" -i senechal "$text" || die "scheduler -i senechal rejected the note"

# --- 2. make sure it landed on the remote ----------------------------------
cd "$SENECHAL" || die "cannot cd to $SENECHAL"

branch="$(git rev-parse --abbrev-ref HEAD)" || die "cannot read current branch"
upstream="$(git rev-parse --abbrev-ref '@{u}' 2>&1)" \
  || die "branch '$branch' tracks nothing -- cannot verify the note reached senechal's remote ($upstream)"

git fetch -q origin || die "git fetch failed -- cannot verify the note landed"

ahead="$(git rev-list --count '@{u}'..HEAD)"
[ "$ahead" -gt 0 ] || die "nothing to push after 'scheduler -i' -- the note was not committed, and this script will not report success for a write that did not happen"

behind="$(git rev-list --count HEAD..'@{u}')"
if [ "$behind" -gt 0 ]; then
  echo "notify-senechal: $behind commit(s) behind upstream -- rebasing with content verification"

  # Snapshot what OUR commits mean before the rebase: the fileset they touch
  # relative to upstream, plus the content of each. A rename-following rebase
  # silently rewrote an archived file's content on 2026-07-26 and was caught
  # only because a human diffed it by hand -- this is that check, mechanized.
  files_before="$(git diff --name-only '@{u}'...HEAD | sort)"
  [ -n "$files_before" ] || die "our commits touch no files relative to upstream -- refusing to rebase blind"
  hash_before="$(git diff '@{u}'...HEAD | sha256sum)"

  git rebase -q origin/"$branch" || {
    git rebase --abort 2>&1 || true
    die "rebase failed (aborted, work left intact and unpushed) -- resolve by hand in $SENECHAL"
  }

  files_after="$(git diff --name-only '@{u}'...HEAD | sort)"
  hash_after="$(git diff '@{u}'...HEAD | sha256sum)"

  if [ "$files_before" != "$files_after" ] || [ "$hash_before" != "$hash_after" ]; then
    printf 'fileset before:\n%s\nfileset after:\n%s\n' "$files_before" "$files_after" >&2
    die "REBASE CHANGED WHAT OUR COMMIT MEANS. Work is intact and un-pushed in $SENECHAL -- read it by hand before pushing."
  fi
  echo "notify-senechal: rebase verified (fileset + content identical)"
fi

git push -q origin "$branch" || die "push rejected -- note is committed locally in $SENECHAL but senechal's nightly run will not see it"

echo "notify-senechal: OK -- on senechal's remote as $(git rev-parse --short HEAD)"
