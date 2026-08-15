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
RETIRED_NAMES='(FOCUS\.md|QUESTIONS\.md|BLOCKERS\.md)'

find_producers() {
  local found=0
  local temp_matches
  local match_count=0

  # Pattern: .scheduler/ referenced in shell/yaml (active code)
  # Exclude documentation files
  temp_matches=$(grep -r '\.scheduler/' \
    --include='*.sh' \
    --include='*.yml' --include='*.yaml' \
    --exclude-dir='archive' --exclude-dir='retired' \
    --exclude-dir='.git' \
    . 2>/dev/null || true)

  if [ -n "$temp_matches" ]; then
    printf '%s\n' "$temp_matches"
    match_count=$((match_count + $(printf '%s\n' "$temp_matches" | wc -l)))
    found=1
  fi

  # Pattern: .claude/ with coordinator filenames in active code
  temp_matches=$(grep -rE "\.claude/(FOCUS|QUESTIONS|BLOCKERS)" \
    --include='*.sh' \
    --include='*.yml' --include='*.yaml' \
    --exclude-dir='archive' --exclude-dir='retired' \
    --exclude-dir='.git' \
    . 2>/dev/null || true)

  if [ -n "$temp_matches" ]; then
    printf '%s\n' "$temp_matches"
    match_count=$((match_count + $(printf '%s\n' "$temp_matches" | wc -l)))
    found=1
  fi

  # Pattern: FOCUS/QUESTIONS/BLOCKERS referenced in shell scripts (actual reads/writes)
  temp_matches=$(grep -rE "FOCUS\.md|QUESTIONS\.md|BLOCKERS\.md" \
    --include='*.sh' \
    --exclude-dir='archive' --exclude-dir='retired' \
    --exclude-dir='.git' \
    . 2>/dev/null || true)

  if [ -n "$temp_matches" ]; then
    printf '%s\n' "$temp_matches"
    match_count=$((match_count + $(printf '%s\n' "$temp_matches" | wc -l)))
    found=1
  fi

  # Special case: .claude/commands/* are active commands even though they're .md
  if [ -d '.claude/commands' ]; then
    temp_matches=$(grep -rE "\.scheduler/|FOCUS\.md|QUESTIONS\.md|BLOCKERS\.md" \
      '.claude/commands' \
      2>/dev/null || true)
    if [ -n "$temp_matches" ]; then
      printf '%s\n' "$temp_matches"
      match_count=$((match_count + $(printf '%s\n' "$temp_matches" | wc -l)))
      found=1
    fi
  fi

  return $([ $found -eq 0 ] && echo 0 || echo 1)
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

  for f in FOCUS.md QUESTIONS.md BLOCKERS.md; do
    if [ -f ".claude/$f" ]; then
      echo ".claude/$f"
      found=1
    fi
  done

  return $([ $found -eq 0 ] && echo 0 || echo 1)
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
note "applying removal on branch $branch..."

# Verify clean working tree before making changes
if ! git diff-index --quiet HEAD 2>/dev/null; then
  die "working tree not clean. Commit or stash changes before applying sunset."
fi

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
trap "rm -f '$msg_file'" EXIT
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
note "branch: $branch"
note "removed files/dirs: $(printf '%s\n' "$staged" | wc -l)"
exit 2
