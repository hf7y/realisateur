#!/usr/bin/env bash
# sunset-coordinator-files.sh <repo> [--apply] -- find and remove retired
# coordination directories (.scheduler/ and .claude/ coordinator files).
#
# TRAPS (the rest of this header is in the vault):
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
# WHY PRODUCERS FIRST: A file deleted with a live producer regenerates
# immediately, undoing the sunset. The script refuses to proceed until
# producers are fixed upstream.
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

# A DRY RUN NEEDS NO BRANCH. Only --apply cuts one, so only --apply requires
# one. Demanding it up front made the script unusable against exactly the
# checkouts you most want to scan -- a CI checkout (this repo's own `suites`
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
branch="$(git symbolic-ref --quiet --short HEAD || true)"

repo_name="$(basename "$(git rev-parse --show-toplevel)")"

# ============================================================================
# PART A: FIND PRODUCERS -- anything that reads or writes .scheduler/ or
# retired .claude/ coordinator files (FOCUS.md, QUESTIONS.md, BLOCKERS.md)
#   [rest: vault:realisateur/guard-archaeology-20260817.md]

# Filenames that were retired on 2026-08-07


find_producers() {
  # One scan, every language a producer can be written in. The earlier version
  # searched only *.sh/*.yml plus .claude/commands, which made chezz's real
  # producers invisible -- they are *.mjs (scripts/, test/) and CLAUDE.md.
  #   [rest: vault:realisateur/guard-archaeology-20260817.md]
  local pat='\.scheduler/|FOCUS\.md|QUESTIONS\.md|BLOCKERS\.md'
  local matches code_matches doc_matches code_files
  code_files=$(grep -rIlE "$pat" \
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

  # EXTENSIONLESS EXECUTABLES. Selecting code by extension misses the shebang
  # scripts that are usually a repo's front door: scheduler's `bin/scheduler`
  # is 3,659 lines with ~40 live read/write sites on the retired paths and was
  #   [rest: vault:realisateur/guard-archaeology-20260817.md]
  shebang_files=$(git ls-files 2>/dev/null | while IFS= read -r f; do
    case "$f" in *.*|'') continue ;; esac
    [ -f "$f" ] || continue
    [ "$(head -c2 "$f" 2>/dev/null)" = '#!' ] || continue
    grep -IlE "$pat" "$f" 2>/dev/null || true
  done)
  code_files=$(printf '%s\n%s' "$code_files" "$shebang_files" | grep -v '^$' | sort -u)

  # A COMMENT IS NOT A PRODUCER, and this is the difference between a usable
  # mechanism and one that can never report clean. Across the estate almost
  # every code hit is rationale prose -- "see FOCUS.md #8", "the 2026-07-21
  #   [rest: vault:realisateur/guard-archaeology-20260817.md]
  local py_files other_files py_matches awk_matches scanner
  py_files=$(printf '%s\n' "$code_files" | while IFS= read -r f; do
      [ -n "$f" ] || continue
      case "$f" in *.py) printf '%s\n' "$f"; continue ;; esac
      head -n 1 -- "$f" 2>/dev/null | grep -q python && printf '%s\n' "$f"
    done || true)
  if [ -n "$py_files" ]; then
    other_files=$(printf '%s\n' "$code_files" | grep -vxF "$py_files" || true)
  else
    other_files="$code_files"
  fi

  scanner=$(mktemp) || die "mktemp failed"
  cat > "$scanner" <<'PYSCANNER'
import io, os, re, sys, tokenize

pat = re.compile(os.environ["SUNSET_PAT"])
STARTERS = (tokenize.NEWLINE, tokenize.NL, tokenize.INDENT,
            tokenize.DEDENT, tokenize.ENCODING)

for path in sys.stdin.read().split("\n"):
    if not path:
        continue
    try:
        with open(path, "rb") as fh:
            src = fh.read().decode("utf-8", "replace")
    except OSError:
        continue
    lines = src.splitlines()
    scrubbed = [list(line) for line in lines]
    try:
        toks = list(tokenize.generate_tokens(io.StringIO(src).readline))
    except Exception:
        toks = []          # untokenizable: strip nothing, so it still blocks
    prev = tokenize.NEWLINE
    for n, tok in enumerate(toks):
        prose = tok.type == tokenize.COMMENT
        if not prose and tok.type == tokenize.STRING and prev in STARTERS:
            nxt = next((t for t in toks[n + 1:]
                        if t.type != tokenize.COMMENT), None)
            prose = nxt is not None and nxt.type in (tokenize.NEWLINE,
                                                     tokenize.NL)
        if prose:
            (srow, scol), (erow, ecol) = tok.start, tok.end
            for row in range(srow, erow + 1):
                if row - 1 >= len(scrubbed):
                    break
                line = scrubbed[row - 1]
                start = scol if row == srow else 0
                end = ecol if row == erow else len(line)
                for col in range(start, min(end, len(line))):
                    line[col] = " "
        prev = tok.type
    for num, chars in enumerate(scrubbed, 1):
        if pat.search("".join(chars)):
            print("%s:%d:%s" % (path, num, lines[num - 1]))
PYSCANNER
  py_matches=$(printf '%s\n' "$py_files" | grep -v '^$' \
    | SUNSET_PAT="$pat" python3 "$scanner" || true)
  rm -f "$scanner"

  # awk still handles shell/js/yaml, where a comment really is "the line starts
  # with a marker" or a /* */ block -- no ambiguity to desync on.
  #
  #   [rest: vault:realisateur/guard-archaeology-20260817.md]
  awk_matches=$(printf '%s\n' "$other_files" | grep -v '^$' | tr '\n' '\0' \
    | SUNSET_PAT="$pat" xargs -0 -r awk 'BEGIN { pat = ENVIRON["SUNSET_PAT"] }
      FNR==1 { inblk=0; inpy=0 }
      {
        s=$0; sub(/^[ \t]*/,"",s); c=$0; iscomment=0
        if (inblk)      { iscomment=1; if ($0 ~ /\*\//) inblk=0 }
        else if (inpy)  { iscomment=1; if (gsub(/"""|'"'''"'/,"&",c) % 2 == 1) inpy=0 }
        else if (s ~ /^(#|\/\/|\*)/)      { iscomment=1 }
        else if (s ~ /^\/\*/)             { iscomment=1; if ($0 !~ /\*\//) inblk=1 }
        else if (s ~ /^("""|'"'''"')/)    { iscomment=1; if (gsub(/"""|'"'''"'/,"&",c) % 2 == 1) inpy=1 }
        if (!iscomment && $0 ~ pat) printf "%s:%d:%s\n", FILENAME, FNR, $0
      }' || true)


  code_matches=$(printf '%s\n%s' "$py_matches" "$awk_matches" | grep -v '^$' || true)

  # Markdown is scanned NARROWLY, and the distinction is the whole point:
  # a slash-command file or CLAUDE.md INSTRUCTS an agent to read or write
  # these paths, so it is a producer. A retrospective that merely mentions
  #   [rest: vault:realisateur/guard-archaeology-20260817.md]
  local doc_targets='./.claude/commands ./.scheduler/commands ./CLAUDE.md ./AGENTS.md'
  # shellcheck disable=SC2086  # deliberate word-splitting: a list of paths
  doc_matches=$(grep -rInE "$pat" \
    --include='*.md' --include='*.template' \
    --exclude-dir='.git' \
    --exclude-dir='archive' --exclude-dir='retired' \
    --exclude-dir='.scheduler' \
    $doc_targets \
    2>/dev/null || true)

  # ONE HOP, and only one. An instruction file that says "read README.md in
  # full and trust it over your own assumptions" has made README.md part of
  # the instruction -- and baudin's README.md then said "see `.claude/FOCUS.md`
  #   [rest: vault:realisateur/guard-archaeology-20260817.md]
  local hop_files hop_matches=""
  # shellcheck disable=SC2086  # deliberate word-splitting: a list of paths
  hop_files=$(grep -rhoE '[A-Za-z0-9_./-]+\.md' \
      --include='*.md' --include='*.template' \
      --exclude-dir='.git' --exclude-dir='archive' --exclude-dir='retired' \
      $doc_targets 2>/dev/null \
    | grep -vE '(^|/)(FOCUS|QUESTIONS|BLOCKERS|PARKING-LOT)\.md$' \
    | sort -u)
  for hop in $hop_files; do
    [ -f "$hop" ] || continue
    case "$hop" in                    # already scanned as an instruction file
      CLAUDE.md|./CLAUDE.md|AGENTS.md|./AGENTS.md) continue ;;
      .claude/commands/*|./.claude/commands/*) continue ;;
      .scheduler/*|./.scheduler/*) continue ;;
    esac
    hop_matches="$hop_matches$(grep -nE "$pat" "$hop" 2>/dev/null | sed "s|^|$hop:|" || true)
"
  done

  matches=$(printf '%s\n%s\n%s' "$code_matches" "$doc_matches" "$hop_matches" \
    | grep -v '^$' || true)

  [ -z "$matches" ] && return 0
  printf '%s\n' "$matches"
  return 1
}

# ============================================================================
# PART B: CHECK FOR FILES -- what would be removed
#
#   [rest: vault:realisateur/guard-archaeology-20260817.md]

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
      # -L as well as -f: chezz's .claude/FOCUS.md is a SYMLINK into
      # .scheduler/. -f follows the link, so once .scheduler is removed the
      # link dangles and every later test reads false.
      if [ -f "$dir/$f" ] || [ -L "$dir/$f" ]; then
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
  # PRINT THEM ALL. The list IS the work order, and truncating at 20 made it
  # unusable in exactly the repos that need it most -- scheduler has 44. A
  # producer you cannot see is one you will not fix.
  printf '%s\n' "$producers" | sed 's/^/  /'
  printf 'sunset-coordinator-files: %d producer line(s).\n' \
    "$(printf '%s\n' "$producers" | wc -l)"
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
if [ -z "$branch" ]; then
  die "detached HEAD -- refusing to cut a branch from no branch"
fi

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
  # A dangling symlink is still a file to remove. Without -L the loop
  # skipped chezz's two .claude links after .scheduler went first, and
  # reported "removal complete" with both still on disk.
  if [ -e "$target" ] || [ -L "$target" ]; then
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
note "removed paths: $(printf '%s\n' "$targets" | grep -cv '^$') ($(printf '%s\n' "$staged" | grep -cv '^$') files staged)"
note "next: git push -u origin $sunset_branch && gh pr create --base $branch"
exit 2
