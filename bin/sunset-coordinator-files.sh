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

# A DRY RUN NEEDS NO BRANCH. Only --apply cuts one, so only --apply requires
# one. Demanding it up front made the script unusable against exactly the
# checkouts you most want to scan -- a CI checkout (this repo's own `suites`
# job runs detached, and test A failed there while passing locally), a pinned
# clone, a tag. The refusal is kept, moved down to the step that actually cuts
# the branch -- which is also AFTER the producer scan, so PRODUCERS FOUND stays
# the first thing --apply reports. It was reporting the wrong blocker.
branch="$(git symbolic-ref --quiet --short HEAD || true)"

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
  # invisible here, so the tool would have reported that repo READY and --apply
  # would have deleted files the next `scheduler ask` writes straight back.
  # That is the exact regeneration producers-first exists to prevent.
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
  # .claude/FOCUS.md end-goal", a dated note explaining why a threshold is what
  # it is. Those lines read nothing and write nothing, so deleting the files
  # cannot regenerate them and fixing them accomplishes nothing. Counting them
  # reported 123 blocking producers in scheduler, 117 in realisateur and 62 in
  # crt on 2026-08-15, which put the sunset out of reach in ten of sixteen
  # repos. Only a line of live code that names the path can bring a file back.
  #
  # The pass tracks BLOCK comments, not just line comments, because most of
  # those references sit in the BODY of a python module docstring or a /* */
  # block -- a line starting with an ordinary word, which no line-comment test
  # can see. It is deliberately approximate in the safe direction: a match on
  # a line that is partly code still counts as a producer.
  #
  # Markdown is NOT filtered: an instruction file has no code, and its prose
  # IS its mechanism.
  # PYTHON IS TOKENIZED, NOT PATTERN-MATCHED. The awk parity heuristic
  # (count the triple-quote delimiters on a line, toggle on an odd count)
  # desyncs on any line with a quote in prose, a single-line docstring, or a
  # file mixing both delimiters -- and once desynced, every line after it
  # flips. That produced the one failure mode a guard over a destructive
  # operation cannot have: NONDETERMINISM. On ecosim,
  # bin/migration-watch.py:196/:257/:1165 blocked, then silently stopped
  # blocking after unrelated edits elsewhere in the file, those lines
  # unchanged. On senechal.py, 506 and 525 were flagged inside an indented
  # docstring while the identical reference at 146 was correctly suppressed.
  # Two agents on the same commit could disagree and neither would be wrong.
  #
  # python's own tokenizer decides instead. Note what it does NOT strip:
  # ordinary string literals. open(".scheduler/FOCUS.md") is a producer and
  # the path lives in a STRING token. Only COMMENTs and DOCSTRINGs -- a string
  # standing alone as a statement -- are prose. A file that fails to tokenize
  # has nothing stripped, so it errs toward blocking.
  #
  # Which scanner a file gets follows the LANGUAGE, and for the extensionless
  # scripts above, the shebang is the only thing that says so.
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
  awk_matches=$(printf '%s\n' "$other_files" | grep -v '^$' | tr '\n' '\0' \
    | xargs -0 -r awk -v pat="$pat" '
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
  # FOCUS.md in prose is not. Scanning all *.md flags MONKEY.md, PLAYBOOK.md
  # and THE-FLOOR.md for narrating history, which blocks the sunset forever
  # on files that produce nothing.
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
  # for current priority". The scan saw nothing and the agent was still sent to
  # the dead path, because nightly-batch.md named no retired path itself. So
  # the hop starts from the instruction FILES, not from their matches, and
  # every .md they name is scanned too.
  #
  # It stops at one hop deliberately. Past one, "a file that mentions a file"
  # is the whole repo, and the guard goes back to being unsatisfiable -- the
  # failure this script has already had twice.
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
