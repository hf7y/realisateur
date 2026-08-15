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
"$CMD" 2>&1 >/dev/null || rc=$?
eq "F3  no args exits 3" "$rc" "3"

rc=0
"$CMD" /nonexistent 2>&1 >/dev/null || rc=$?
eq "F4  nonexistent repo exits 3" "$rc" "3"

# --- G: the two defects that would have caused real damage ---
# G1: chezz's live producer is test/answer-channel.spec.mjs, which resolves
# .scheduler/QUESTIONS.md at runtime. A scan limited to *.sh/*.yml reports
# chezz clean and deletes the files the suite reads.
# G2: --apply used to commit onto whatever branch was checked out, so running
# it on main committed the removal to a protected branch.
note "G. Regressions"
mkdir -p "$T/repo-mjs" && cd "$T/repo-mjs"
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
cd "$T/repo-mjs"
[ "$(git symbolic-ref --short HEAD)" != "$start_branch" ] && \
  ok "G2b --apply commits on a new branch, not $start_branch" || \
  bad "G2b --apply commits on a new branch, not $start_branch"
[ -z "$(git show "$start_branch" --stat --format= 2>/dev/null | grep -c '^$' )" ] || true
git ls-tree -r --name-only "$start_branch" | grep -q '.scheduler/FOCUS.md' && \
  ok "G2c starting branch still has the files (untouched)" || \
  bad "G2c starting branch still has the files (untouched)"

# --- Summary ---
printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
