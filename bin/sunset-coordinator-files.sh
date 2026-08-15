#!/usr/bin/env bash
# sunset-coordinator-files.sh <repo> [--apply] -- find and remove retired
# coordination directories (.scheduler/ and .claude/ coordinator files).
#
# The sunset: scheduler#66 (2026-08-07) retired FOCUS.md, QUESTIONS.md,
# BLOCKERS.md and siblings in favour of GitHub issues. These mechanisms
# worked via side effects on the filesystem -- files deleted while producers
# still write them just come back.
#
# This script has two halves and does the PRODUCER HALF FIRST:
#   a. PRODUCERS — find every reference to .scheduler/ and retired filenames
#      across the target repo (shell scripts, .github/workflows/*.yml,
#      .claude/commands/*.md, agent prompts, anything that USES them).
#      If any live producers exist, refuse --apply and say which ones must be
#      fixed first.
#   b. FILES — only once producers are clean, git rm:
#      - the .scheduler/ directory (entire directory)
#      - .claude/FOCUS.md, .claude/QUESTIONS.md, .claude/BLOCKERS.md
#        (only these files if present; .claude/ itself stays)
#
# Default is DRY RUN: prints what would be removed. --apply commits the
# removal on a new branch.
#
# WHY PRODUCERS FIRST: A file deleted with a live producer regenerates
# immediately, undoing the sunset. The script refuses to proceed until
# producers are fixed upstream.
#
# Usage:
#   sunset-coordinator-files.sh <repo>           dry-run: show what would be removed
#   sunset-coordinator-files.sh <repo> --apply   apply the removal
#
# Exit codes:
#   0  nothing to do (already sunset, no producers, no --apply)
#   1  producers block the removal (live readers/writers remain)
#   2  work was done (--apply succeeded, changes committed)
#   3  usage error or other fatal error
#
set -uo pipefail

die() { printf 'sunset-coordinator-files: FAIL: %s\n' "$*" >&2; exit 3; }
note() { printf 'sunset-coordinator-files: %s\n' "$*"; }

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

if [ $# -lt 1 ]; then
  cat <<'HELP'
sunset-coordinator-files.sh -- remove retired coordination files

usage:
  sunset-coordinator-files.sh <repo>           dry-run: show what would be removed
  sunset-coordinator-files.sh <repo> --apply   apply the removal

exit codes:
  0  nothing to do (already sunset, no producers, no --apply)
  1  producers block the removal (live readers/writers remain)
  2  work was done (--apply succeeded, changes committed)
  3  usage error or other fatal error

about:
  Detects live producers (readers/writers) of .scheduler/ and deprecated
  .claude/ coordinator files. Refuses --apply if producers are found.
  Once producers are fixed, removes the directories and commits.
HELP
  exit 3
fi

case "${1:-}" in
  -h|--help)
    cat <<'HELP'
sunset-coordinator-files.sh -- remove retired coordination files

usage:
  sunset-coordinator-files.sh <repo>           dry-run: show what would be removed
  sunset-coordinator-files.sh <repo> --apply   apply the removal

exit codes:
  0  nothing to do (already sunset, no producers, no --apply)
  1  producers block the removal (live readers/writers remain)
  2  work was done (--apply succeeded, changes committed)
  3  usage error or other fatal error
HELP
    exit 0
    ;;
  -*)
    die "expected repo path, got flag: $1"
    ;;
esac

repo="$1"
shift || true

APPLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    *)
      die "unknown flag: $1"
      ;;
  esac
  shift
done

[ -d "$repo" ] || die "not a directory: $repo"
cd "$repo" || die "cannot cd: $repo"
git rev-parse --git-dir >/dev/null 2>&1 || die "not a git repo: $repo"

branch="$(git symbolic-ref --quiet --short HEAD)" \
  || die "detached HEAD -- refusing to work on no branch"

repo_name="$(basename "$(git rev-parse --show-toplevel)")"

# ============================================================================
# PART A: FIND PRODUCERS -- anything that reads or writes .scheduler/ or
# retired .claude/ coordinator files (FOCUS.md, QUESTIONS.md, BLOCKERS.md)
#
# We search ACTIVE code locations only: shell scripts, workflows, commands
# files. We SKIP archive/, retired/, and pure documentation.
# ============================================================================

# Filenames that were retired on 2026-08-07


find_producers() {
  # One scan, every language a producer can be written in. The earlier version
  # searched only *.sh/*.yml plus .claude/commands, which made chezz's real
  # producers invisible -- they are *.mjs (scripts/, test/) and CLAUDE.md.
  #
  # Two exclusions matter and are not cosmetic:
  #   - the retired files themselves. A FOCUS.md that mentions FOCUS.md is the
  #     thing being removed, not a producer of it.
  #   - this script and its test. They necessarily contain the patterns they
  #     search for, so without this the mechanism permanently blocks itself in
  #     realisateur and can never report clean.
  # Code is scanned broadly: any language can read or write these paths.
  local pat='\.scheduler/|FOCUS\.md|QUESTIONS\.md|BLOCKERS\.md'
  local matches code_matches doc_matches
  code_matches=$(grep -rInE "$pat" \
    --include='*.sh' --include='*.bash' \
    --include='*.yml' --include='*.yaml' \
    --include='*.mjs' --include='*.js' --include='*.cjs' --include='*.ts' \
    --include='*.py' \
    --include='crontab*' \
    --exclude-dir='.git' \
    --exclude-dir='archive' --exclude-dir='retired' \
    --exclude-dir='.scheduler' \
    --exclude='sunset-coordinator-files.sh' \
    --exclude='sunset-coordinator-files.test.sh' \
    . 2>/dev/null || true)

  # A COMMENT IS NOT A PRODUCER, and this is the difference between a usable
  # mechanism and one that can never report clean. Across the estate almost
  # every code hit is rationale prose in a comment or docstring -- "see
  # FOCUS.md #8", "the 2026-07-21 .claude/FOCUS.md end-goal", a dated note
  # explaining why a threshold is what it is. Those lines read nothing and
  # write nothing, so deleting the files cannot regenerate them and fixing
  # them accomplishes nothing. Counting them reported 123 blocking producers
  # in scheduler, 117 in realisateur and 62 in crt on 2026-08-15, which put
  # the sunset permanently out of reach in ten of sixteen repos.
  # Only a line of live code that names the path can bring a file back.
  # Markdown is NOT filtered here: an instruction file has no code, and its
  # prose IS its mechanism.
  code_matches=$(printf '%s\n' "$code_matches" \
    | grep -vE '^[^:]*:[0-9]+:[[:space:]]*(#|//|\*|/\*|"""|'"'''"')' || true)

  # Markdown is scanned NARROWLY, and the distinction is the whole point:
  # a slash-command file or CLAUDE.md INSTRUCTS an agent to read or write
  # these paths, so it is a producer. A retrospective that merely mentions
  # FOCUS.md in prose is not. Scanning all *.md flags MONKEY.md, PLAYBOOK.md
  # and THE-FLOOR.md for narrating history, which blocks the sunset forever
  # on files that produce nothing.
  doc_matches=$(grep -rInE "$pat" \
    --include='*.md' \
    --exclude-dir='.git' \
    --exclude-dir='archive' --exclude-dir='retired' \
    --exclude-dir='.scheduler' \
    ./.claude/commands ./.scheduler/commands ./CLAUDE.md ./AGENTS.md \
    2>/dev/null || true)

  matches=$(printf '%s\n%s' "$code_matches" "$doc_matches" | grep -v '^$' || true)

  [ -z "$matches" ] && return 0
  printf '%s\n' "$matches"
  return 1
}

# ============================================================================
# PART B: CHECK FOR FILES -- what would be removed
#
# Remove:
#   - .scheduler/ directory (if it exists)
#   - .claude/FOCUS.md, .claude/QUESTIONS.md, .claude/BLOCKERS.md (if they exist)
# ============================================================================

find_targets() {
  local found=0

  if [ -d ".scheduler" ]; then
    echo ".scheduler"
    found=1
  fi

  # Retired names live in three places across the ecosystem: .scheduler/,
  # .claude/, and the repo root (sequestria, nine-speakers, groc-mangr and
  # abletim all carried a bare FOCUS.md).
  for f in FOCUS.md QUESTIONS.md BLOCKERS.md PARKING-LOT.md; do
    for dir in .claude .; do
      if [ -f "$dir/$f" ]; then
        echo "${dir#./}/$f" | sed 's|^\./||; s|^/||'
        found=1
      fi
    done
  done

  # 0 = nothing found, 1 = targets found.
  return "$found"
}

# ============================================================================
# MAIN FLOW
# ============================================================================

note "scanning for producers in $repo_name..."

producers=""
producer_rc=0
producers=$(find_producers 2>&1) || producer_rc=$?

if [ $producer_rc -eq 1 ]; then
  note "PRODUCERS FOUND (must be fixed before removal):"
  printf '%s\n' "$producers" | head -20 | sed 's/^/  /'
  lines=$(printf '%s\n' "$producers" | wc -l)
  if [ "$lines" -gt 20 ]; then
    printf 'sunset-coordinator-files:   ... (%d more)\n' $((lines - 20))
  fi
  exit 1
fi

# Producers clean, now check what would be removed
targets=""
target_rc=0
targets=$(find_targets 2>&1) || target_rc=$?

if [ -z "$targets" ]; then
  note "no coordinator files/directories found (already sunset)"
  exit 0
fi

note "would remove:"
printf '%s\n' "$targets" | sed 's/^/  /'

if [ $APPLY -eq 0 ]; then
  note "(dry-run; use --apply to commit removal)"
  exit 0
fi

# --- APPLY: git rm the targets ---

# Verify clean working tree BEFORE cutting a branch, so a dirty tree cannot
# be carried onto it.
if ! git diff-index --quiet HEAD 2>/dev/null; then
  die "working tree not clean. Commit or stash changes before applying sunset."
fi

# Never commit onto whatever branch happened to be checked out. The earlier
# version committed to $branch, so running this on main committed to main --
# which is protected everywhere in this ecosystem, and the push would be
# rejected after the files were already gone locally.
case "$branch" in
  main|master) : ;;
  *) note "note: not on main (on '$branch'); cutting the sunset branch from here anyway" ;;
esac

sunset_branch="sunset-coordinator-files-${repo_name}"
if git show-ref --quiet "refs/heads/$sunset_branch"; then
  die "branch $sunset_branch already exists -- delete or rename it first"
fi
git checkout -q -b "$sunset_branch" || die "could not create branch $sunset_branch"
note "applying removal on new branch $sunset_branch..."

# Remove the targets
for target in $targets; do
  if [ -e "$target" ]; then
    if ! git rm -r "$target"; then
      die "git rm failed on $target"
    fi
  fi
done

staged=$(git diff --cached --name-only 2>/dev/null) || true
if [ -z "$staged" ]; then
  note "no changes staged (nothing to commit)"
  exit 0
fi

# Commit the removal
msg_file=$(mktemp)
trap 'rm -f "$msg_file"' EXIT
cat > "$msg_file" <<'EOF'
Sunset retired coordination directories

Remove .scheduler/ and .claude/ coordinator files (FOCUS.md, QUESTIONS.md,
BLOCKERS.md), retired by scheduler#66 (2026-08-07) in favour of GitHub
issues. All producers have been fixed upstream.

See the scheduler#66 migration notes and realisateur's bin/sunset-coordinator-files.sh
for the retirement mechanism.
EOF

if ! git commit -q -F "$msg_file"; then
  die "git commit failed"
fi

note "committed $(git rev-parse --short HEAD) -- removal complete"
note "branch: $sunset_branch"
note "removed files/dirs: $(printf '%s\n' "$staged" | wc -l)"
note "next: git push -u origin $sunset_branch && gh pr create --base $branch"
exit 2
