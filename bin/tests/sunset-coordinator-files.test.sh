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
#
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CMD="$REPO/bin/sunset-coordinator-files.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

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

cd "$T/test-repo" || exit 1
git init && git config user.email test@test && git config user.name Test
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
cd "$T/test-repo2" || exit 1
git init && git config user.email test@test && git config user.name Test
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
# happens to sit under one: a comment block explaining the bootstrap
# FOCUS.md, then the line that WRITES it. That shape was bin/stamp-agent.sh
# until #278 deleted it; the fixture below keeps the shape so the write is
# still caught if it reappears.
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
note "L. Extensionless executables"
mkdir -p "$T/repo-noext/bin" && cd "$T/repo-noext" || exit 1
git init -q . && git config user.email t@t && git config user.name t
mkdir -p .scheduler && echo "# retired" > .scheduler/FOCUS.md
printf '#!/usr/bin/env bash\necho x > .scheduler/FOCUS.md\n' > bin/tool
chmod +x bin/tool
printf 'plain text mentioning FOCUS.md\n' > notes
git add -A && git commit -qm init
rc=0; out="$("$CMD" "$T/repo-noext" 2>&1)" || rc=$?
eq "L1  an extensionless shebang producer blocks" "$rc" "1"
printf '%s' "$out" | grep -q 'bin/tool' && ok "L1b names it" || bad "L1b names it"
printf '%s' "$out" | grep -q ':notes:' && bad "L2  extensionless non-script scanned" || ok "L2  extensionless non-script ignored"

# --- J: one hop out of an instruction file ---
# baudin: .claude/commands/nightly-batch.md said "read README.md in full and
# trust it", and README.md said "see .claude/FOCUS.md for current priority".
# The scan saw nothing and the agent was still sent to the dead path.
note "J. One-hop producer chain"
mkdir -p "$T/repo-hop/.claude/commands" && cd "$T/repo-hop" || exit 1
git init -q . && git config user.email t@t && git config user.name t
touch .claude/FOCUS.md
printf 'Read `README.md` in full and trust it over your own assumptions.\n' \
  > .claude/commands/nightly-batch.md
printf 'See `.claude/FOCUS.md` for current priority.\n' > README.md
git add -A && git commit -qm init
rc=0; out="$("$CMD" "$T/repo-hop" 2>/dev/null)" || rc=$?
eq "J1  a hop through a named file blocks" "$rc" "1"
printf '%s' "$out" | grep -q "README.md" && \
  ok "J2  names the hopped-to file" || bad "J2  names the hopped-to file" "$out"

# ...and it stops at one hop. Past one, "a file that mentions a file" is the
# whole repo, and the guard goes back to being unsatisfiable.
printf 'Read `README.md` in full.\n' > .claude/commands/nightly-batch.md
printf 'See `HISTORY.md`.\n' > README.md
printf 'We used to keep it in `.claude/FOCUS.md`.\n' > HISTORY.md
git add -A && git commit -qm "two hops"
rc=0; "$CMD" "$T/repo-hop" >/dev/null 2>&1 || rc=$?
eq "J3  the hop stops at one" "$rc" "0"

# --- K: the python verdict is DETERMINISTIC ---
# The awk parity heuristic desynced on a stray quote and every line after it
# flipped, so ecosim's bin/migration-watch.py:196/:257/:1165 stopped blocking
# after unrelated edits elsewhere in the file. A guard over a destructive
# operation whose verdict depends on distant content is not reproducible.
note "K. Python: docstring vs code, and stable under unrelated edits"
mkdir -p "$T/repo-py" && cd "$T/repo-py" || exit 1
git init -q . && git config user.email t@t && git config user.name t
mkdir -p .scheduler lib
echo "# retired" > .scheduler/FOCUS.md
cat > lib/both.py <<'PYFIX'
"""Module docstring whose prose can't spell things right.

It cites .scheduler/FOCUS.md as the source of the bar, and it's got an
apostrophe plus a stray " quote to desync a parity counter.
"""


def read_it():
    """One-line docstring mentioning .scheduler/FOCUS.md."""
    return open(".scheduler/FOCUS.md").read()
PYFIX
git add -A && git commit -qm init
rc=0; out="$("$CMD" "$T/repo-py" 2>/dev/null)" || rc=$?
eq "K1  the file blocks -- it really does read the path" "$rc" "1"
n=$(printf '%s\n' "$out" | grep -c 'both\.py:')
eq "K2  exactly one line named: the open(), not the two docstrings" "$n" "1"
printf '%s' "$out" | grep -q 'both\.py:10' && \
  ok "K3  and it is the open() line" || bad "K3  and it is the open() line" "$out"

# The same file, with unrelated prose added ABOVE. The verdict must not move.
before="$out"
python3 - <<'PYEDIT'
p = "lib/both.py"
s = open(p).read()
s = s.replace("def read_it():",
              "X = 1  # an unrelated addition, with a lone ' apostrophe\n\n\ndef read_it():")
open(p, "w").write(s)
PYEDIT
git add -A && git commit -qm "unrelated edit above"
rc=0; out2="$("$CMD" "$T/repo-py" 2>/dev/null)" || rc=$?
eq "K4  still blocks after an unrelated edit" "$rc" "1"
n2=$(printf '%s\n' "$out2" | grep -c 'both\.py:')
eq "K5  and still names exactly one line" "$n2" "1"
[ -n "$before" ] && ok "K6  the first verdict was recorded" || bad "K6  the first verdict was recorded"
# --- K: symlinked targets must not survive as dangling links ---
# chezz's .claude/FOCUS.md linked into .scheduler/. .scheduler was removed
# first, the link then dangled, `[ -e ]` read false, and the tool reported
# "removal complete" with both links still on disk.
note "M. Symlinked targets"
mkdir -p "$T/repo-link/.claude" && cd "$T/repo-link" || exit 1
git init -q . && git config user.email t@t && git config user.name t
mkdir -p .scheduler && echo "# retired" > .scheduler/FOCUS.md
ln -s ../.scheduler/FOCUS.md .claude/FOCUS.md
git add -A && git commit -qm init
rc=0; "$CMD" "$T/repo-link" --apply >/dev/null 2>&1 || rc=$?
eq "M1  --apply exits 2" "$rc" "2"
cd "$T/repo-link" || exit 1
[ -L .claude/FOCUS.md ] && bad "M2  dangling symlink survived" || ok "M2  symlink removed too"
[ -d .scheduler ] && bad "M3  .scheduler survived" || ok "M3  .scheduler removed"

# --- Summary ---
summary
