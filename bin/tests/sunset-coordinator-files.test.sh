#!/usr/bin/env bash
# sunset-coordinator-files.test.sh -- test the sunset-coordinator-files.sh mechanism
#
# Tests:
#   A. Producer detection works (finds references)
#   B. File detection works (finds directories/files)
#   C. Refuses --apply when producers are present
#   D. --apply works when producers are clean (in a test repo)
#   E. Dry-run mode doesn't change anything
#   F. Usage and exit codes are correct
#   G. Regressions (a .mjs producer; --apply never commits to the checked-out branch)
#   H. A comment is not a producer -- and the real producers under comments still are
#
# HERMETICITY: every fixture is a throwaway git repo under mktemp -d, removed
# on EXIT. No network, no gh, no writes outside $T. Section A and C point the
# script at THIS repo, which is read-only there -- both are dry-run/refusal
# paths that never reach --apply's branch cut.
#
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CMD="$REPO/bin/sunset-coordinator-files.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { printf '  ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  FAIL %s\n    %s\n' "$1" "${2:-}" >&2; fail=$((fail+1)); }
eq()  { [ "$2" = "$3" ] && ok "$1" || bad "$1" "expected '$3', got '$2'"; }

printf 'sunset-coordinator-files.sh\n'

# --- A: Producer detection (real repo) ---
note() { printf '%s\n' "$@" | sed 's/^/  /'; }

note "A. Producer detection against realisateur (has producers)"
rc=0
out="$("$CMD" "$REPO" 2>&1)" || rc=$?
eq "A1  exits 1 when producers found" "$rc" "1"
printf '%s' "$out" | grep -q "PRODUCERS FOUND" && \
  ok "A2  reports PRODUCERS FOUND" || \
  bad "A2  reports PRODUCERS FOUND" "$out"
printf '%s' "$out" | grep -q "\.sh:" && \
  ok "A3  names a producer (shell script found)" || \
  bad "A3  names a producer (shell script found)"

# --- B: File detection ---
note "B. File detection in test repo"
mkdir -p "$T/test-repo/.scheduler/commands" "$T/test-repo/.claude/commands"
touch "$T/test-repo/.scheduler/FOCUS.md"
touch "$T/test-repo/.claude/FOCUS.md" "$T/test-repo/.claude/QUESTIONS.md"
touch "$T/test-repo/.claude/commands/test.md"
touch "$T/test-repo/.scheduler/commands/test.md"
touch "$T/test-repo/README.md"

cd "$T/test-repo" && git init && git config user.email test@test && git config user.name Test
git add -A && git commit -q -m "init"

rc=0
out="$("$CMD" "$T/test-repo" 2>&1)" || rc=$?
eq "B1  exits 0 when no producers and dry-run" "$rc" "0"
printf '%s' "$out" | grep -q "would remove" && \
  ok "B2  reports would remove" || \
  bad "B2  reports would remove" "$out"
printf '%s' "$out" | grep -q ".scheduler" && \
  ok "B3  identifies .scheduler directory" || \
  bad "B3  identifies .scheduler directory" "$out"
printf '%s' "$out" | grep -q ".claude/FOCUS.md\|.claude/QUESTIONS.md" && \
  ok "B4  identifies coordinator files in .claude" || \
  bad "B4  identifies coordinator files in .claude" "$out"

# --- C: Refuse --apply when producers exist ---
note "C. --apply blocked by producers in real repo"
rc=0
"$CMD" "$REPO" --apply >/dev/null 2>&1 || rc=$?
eq "C1  --apply exits 1 when producers block" "$rc" "1"

# --- D: --apply works when producers are clean ---
note "D. --apply succeeds in clean test repo"
rc=0
out="$("$CMD" "$T/test-repo" --apply 2>&1)" || rc=$?
eq "D1  --apply exits 2 when work done" "$rc" "2"
printf '%s' "$out" | grep -q "committed" && \
  ok "D2  reports commit" || \
  bad "D2  reports commit" "$out"

# Verify directories were actually removed
[ ! -d "$T/test-repo/.scheduler" ] && \
  ok "D3  .scheduler directory removed" || \
  bad "D3  .scheduler directory removed"
[ ! -f "$T/test-repo/.claude/FOCUS.md" ] && \
  ok "D4  .claude/FOCUS.md removed" || \
  bad "D4  .claude/FOCUS.md removed"

# --- E: Dry-run doesn't change tree ---
note "E. Dry-run preserves tree"
mkdir -p "$T/test-repo2/.scheduler" "$T/test-repo2/.claude/commands"
touch "$T/test-repo2/.claude/QUESTIONS.md" "$T/test-repo2/README.md"
cd "$T/test-repo2" && git init && git config user.email test@test && git config user.name Test
git add -A && git commit -q -m "init"
hash_before=$(git rev-parse HEAD)

"$CMD" "$T/test-repo2" >/dev/null 2>&1 || true

hash_after=$(git rev-parse HEAD)
eq "E1  dry-run doesn't commit" "$hash_before" "$hash_after"
[ -d "$T/test-repo2/.scheduler" ] && \
  ok "E2  dry-run preserves .scheduler" || \
  bad "E2  dry-run preserves .scheduler"

# --- F: Usage and help ---
note "F. Usage and help"
out="$("$CMD" --help 2>&1)"; rc=$?
eq "F1  --help exits 0" "$rc" "0"
printf '%s' "$out" | grep -q "usage:" && \
  ok "F2  --help prints usage" || \
  bad "F2  --help prints usage"

rc=0
"$CMD" >/dev/null 2>&1 || rc=$?
eq "F3  no args exits 3" "$rc" "3"

rc=0
"$CMD" /nonexistent >/dev/null 2>&1 || rc=$?
eq "F4  nonexistent repo exits 3" "$rc" "3"

# --- G: the two defects that would have caused real damage ---
# G1: chezz's live producer is test/answer-channel.spec.mjs, which resolves
# .scheduler/QUESTIONS.md at runtime. A scan limited to *.sh/*.yml reports
# chezz clean and deletes the files the suite reads.
# G2: --apply used to commit onto whatever branch was checked out, so running
# it on main committed the removal to a protected branch.
note "G. Regressions"
mkdir -p "$T/repo-mjs" && cd "$T/repo-mjs" || exit 1
git init -q . && git config user.email t@t && git config user.name t
mkdir -p .scheduler scripts
echo "# retired" > .scheduler/FOCUS.md
printf 'const F = path.join(ROOT, ".scheduler", "FOCUS.md");\n' > scripts/reader.mjs
git add -A && git commit -qm init
rc=0; out="$("$CMD" "$T/repo-mjs" 2>&1)" || rc=$?
eq "G1  a .mjs producer blocks the sunset" "$rc" "1"
printf '%s' "$out" | grep -q "reader.mjs" && \
  ok "G1b names the .mjs producer" || bad "G1b names the .mjs producer"

rm scripts/reader.mjs && git add -A && git commit -qm "fix producer"
start_branch=$(git symbolic-ref --short HEAD)
rc=0; "$CMD" "$T/repo-mjs" --apply >/dev/null 2>&1 || rc=$?
eq "G2  --apply exits 2" "$rc" "2"
cd "$T/repo-mjs" || exit 1
[ "$(git symbolic-ref --short HEAD)" != "$start_branch" ] && \
  ok "G2b --apply commits on a new branch, not $start_branch" || \
  bad "G2b --apply commits on a new branch, not $start_branch"
[ -z "$(git show "$start_branch" --stat --format= 2>/dev/null | grep -c '^$' )" ] || true
git ls-tree -r --name-only "$start_branch" | grep -q '.scheduler/FOCUS.md' && \
  ok "G2c starting branch still has the files (untouched)" || \
  bad "G2c starting branch still has the files (untouched)"

# --- H: a comment is not a producer ---
# The scan used to count every rationale comment mentioning FOCUS.md as a live
# producer: 123 in scheduler, 117 in realisateur, 62 in crt. Those lines read
# and write nothing, so no amount of fixing them ever unblocks the sunset.
note "H. Comments are not producers"
mkdir -p "$T/repo-comments" && cd "$T/repo-comments" || exit 1
git init -q . && git config user.email t@t && git config user.name t
mkdir -p .scheduler lib tests
echo "# retired" > .scheduler/FOCUS.md
printf '# the 0.82 threshold comes from .scheduler/FOCUS.md 2026-07-24\nTHRESHOLD=0.82\n' > lib/tuned.sh
printf '"""Covers the end-goal stated in .claude/FOCUS.md."""\nX = 1\n' > tests/test_x.py
printf '// see FOCUS.md item 9\nconst n = 9;\n' > lib/n.mjs
git add -A && git commit -qm init
rc=0; out="$("$CMD" "$T/repo-comments" 2>&1)" || rc=$?
eq "H1  comment-only references do not block" "$rc" "0"
printf '%s' "$out" | grep -q "would remove" && \
  ok "H2  reaches the removal step" || bad "H2  reaches the removal step" "$out"

# ...but a real code reference in the same repo still blocks.
printf 'FOCUS=".scheduler/FOCUS.md"\ncat "$FOCUS"\n' > lib/reader.sh
git add -A && git commit -qm "add a real producer"
rc=0; out="$("$CMD" "$T/repo-comments" 2>&1)" || rc=$?
eq "H3  a live code reference still blocks" "$rc" "1"
printf '%s' "$out" | grep -q "reader.sh" && \
  ok "H4  names the real producer" || bad "H4  names the real producer" "$out"
printf '%s' "$out" | grep -q "tuned.sh" && \
  bad "H5  does not name the comment-only file" "$out" || \
  ok "H5  does not name the comment-only file"

# The failure mode of stripping comments is dropping a REAL producer that
# happens to sit under one. bin/stamp-agent.sh is the live shape (#278): a
# comment block explaining the bootstrap FOCUS.md, then the line that WRITES
# it. The write must still be caught.
rm lib/reader.sh
printf '# writes the bootstrap .scheduler/FOCUS.md, then gates on it\nwrite_stamp() {\n  echo hi > "$repo/.scheduler/FOCUS.md"\n}\n' > lib/stamp.sh
git add -A && git commit -qm "comment above a writer"
rc=0; out="$("$CMD" "$T/repo-comments" 2>&1)" || rc=$?
eq "H6  a writer under a comment still blocks" "$rc" "1"
printf '%s' "$out" | grep -qE 'stamp\.sh:3' && \
  ok "H7  names the code line, not the comment line" || \
  bad "H7  names the code line, not the comment line" "$out"

# A .claude/commands/*.md instruction is a producer BY NATURE -- an
# instruction is what creates the reader -- and markdown is never filtered.
rm lib/stamp.sh
mkdir -p .claude/commands
printf 'Read `.scheduler/FOCUS.md` first; everything below is scoped by it.\n' \
  > .claude/commands/nightly-batch.md
git add -A && git commit -qm "instruction file"
rc=0; out="$("$CMD" "$T/repo-comments" 2>&1)" || rc=$?
eq "H8  a command-file instruction still blocks" "$rc" "1"
printf '%s' "$out" | grep -q "nightly-batch.md" && \
  ok "H9  names the instruction file" || bad "H9  names the instruction file" "$out"

# The reference usually sits in the BODY of a docstring, on a line beginning
# with an ordinary word -- wtul/lib/catalog_outbox.py:2, nine-speakers/world.py:8.
# A line-comment test cannot see those; a block tracker can.
mkdir -p "$T/repo-block" && cd "$T/repo-block" || exit 1
git init -q . && git config user.email t@t && git config user.name t
mkdir -p .scheduler lib
echo "# retired" > .scheduler/FOCUS.md
printf '"""Outbox.\n\nBuilt for the item at .scheduler/FOCUS.md #8.\n"""\nQ = 1\n' > lib/outbox.py
printf '/*\n * heading\n   see .claude/QUESTIONS.md 2026-07-24\n */\nconst q = 1;\n' > lib/q.mjs
git add -A && git commit -qm init
rc=0; out="$("$CMD" "$T/repo-block" 2>&1)" || rc=$?
eq "H10 a docstring/block body does not block" "$rc" "0"

printf 'Q = open(".scheduler/FOCUS.md").read()\n' >> lib/outbox.py
git add -A && git commit -qm "a real read"
rc=0; out="$("$CMD" "$T/repo-block" 2>&1)" || rc=$?
eq "H11 a read after the docstring still blocks" "$rc" "1"

# --- J: extensionless executables are producers too ---
# Selecting code by extension reported hf7y/scheduler READY while bin/scheduler
# (3,659 lines, ~40 live sites) still wrote the retired paths.
note "J. Extensionless executables"
mkdir -p "$T/repo-noext/bin" && cd "$T/repo-noext"
git init -q . && git config user.email t@t && git config user.name t
mkdir -p .scheduler && echo "# retired" > .scheduler/FOCUS.md
printf '#!/usr/bin/env bash\necho x > .scheduler/FOCUS.md\n' > bin/tool
chmod +x bin/tool
printf 'plain text mentioning FOCUS.md\n' > notes
git add -A && git commit -qm init
rc=0; out="$("$CMD" "$T/repo-noext" 2>&1)" || rc=$?
eq "J1  an extensionless shebang producer blocks" "$rc" "1"
printf '%s' "$out" | grep -q 'bin/tool' && ok "J1b names it" || bad "J1b names it"
printf '%s' "$out" | grep -q ':notes:' && bad "J2  extensionless non-script scanned" || ok "J2  extensionless non-script ignored"

# --- Summary ---
printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
