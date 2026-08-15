#!/usr/bin/env bash
#
# bin/tests/shellcheck-lint.test.sh -- witness for bin/shellcheck-lint.sh.
#
# THE LOAD-BEARING ASSERTIONS ARE C, D AND E.
#
# A ratchet whose regression path does not fire is a green light wired to
# nothing, and this estate has shipped that exact thing more than once: three
# guards tested a literal unexpanded `$HOME` so `silence-audit --strict` was
# never once passable, and a propagation pass that reached zero projects
# exited 0. So the cases that matter are not "it runs" -- they are:
#
#   C  a NEW (file, code) pair exits 1, and names the pair
#   D  shellcheck missing exits 2 (BLIND), NOT 0
#   E  matching zero shell files exits 2 (BLIND), NOT 0
#
# E is the one that looks like paranoia and is not. `bin/tests/*.sh matched
# nothing` was a live defect in this repository's own CI, found only because
# someone added the guard for it; a lint that lints nothing reports success in
# exactly the voice of a lint that found nothing wrong.
#
# SKIPS RATHER THAN FAILS when shellcheck is absent from the host -- except
# for case D, which needs it absent and is therefore the one case that always
# runs. A suite that goes red on a developer laptop for lacking a linter is a
# suite that gets commented out.
set -uo pipefail

GUARD="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)/shellcheck-lint.sh"
pass=0; fail=0; skipped=0
T="$(mktemp -d)"; trap 'rm -rf "${T:?}"' EXIT

ok()   { echo "  ok   $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL $1 -- $2"; fail=$((fail+1)); }
skip() { echo "  skip $1 -- $2"; skipped=$((skipped+1)); }
check() { # <name> <expected-exit> <actual-exit>
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected exit $2, got $3"; fi
}

# Build a fixture repo with one shell file, and the guard copied inside it so
# the guard's own ROOT resolves to the fixture rather than to this repository.
mkfixture() { # <dir> <script-content>
  local d="$1" content="$2"
  mkdir -p "$d/bin/tests"
  cp "$GUARD" "$d/bin/shellcheck-lint.sh"
  printf '%s' "$content" > "$d/bin/subject.sh"
  git -C "$d" init -q 2>/dev/null
  git -C "$d" config user.email t@test; git -C "$d" config user.name T
  git -C "$d" add -A 2>/dev/null
  git -C "$d" commit -qm fixture 2>/dev/null
}

HAVE_SC=0
command -v shellcheck >/dev/null 2>&1 && HAVE_SC=1

echo "--- shellcheck-lint guard ---"

# --- A: a clean tree with no ratchet is exit 0, not a crash ------------------
if [ "$HAVE_SC" -eq 1 ]; then
  mkfixture "$T/a" '#!/usr/bin/env bash
echo "nothing wrong here"
'
  rc=0; bash "$T/a/bin/shellcheck-lint.sh" --quiet >/dev/null 2>&1 || rc=$?
  check "A clean tree, no ratchet: exit 0" 0 "$rc"
else
  skip "A clean tree" "shellcheck absent"
fi

# --- B: --accept writes a ratchet recording the pair ------------------------
if [ "$HAVE_SC" -eq 1 ]; then
  mkfixture "$T/b" '#!/usr/bin/env bash
cd /tmp
echo hi
'
  bash "$T/b/bin/shellcheck-lint.sh" --accept --quiet >/dev/null 2>&1
  if grep -q 'SC2164' "$T/b/bin/shellcheck-lint.ratchet" 2>/dev/null; then
    ok "B --accept records the (file, code) pair"
  else
    bad "B --accept records the pair" "no SC2164 in the written ratchet"
  fi
  # and the accepted finding no longer counts as new
  rc=0; bash "$T/b/bin/shellcheck-lint.sh" --quiet >/dev/null 2>&1 || rc=$?
  check "B2 an accepted finding is not a regression" 0 "$rc"
else
  skip "B --accept" "shellcheck absent"
fi

# --- C: a NEW pair is a regression, exit 1, and is NAMED --------------------
# THE LOAD-BEARING CASE. Accept a baseline, then add a second file with a
# different defect, and require both the exit code and the report.
if [ "$HAVE_SC" -eq 1 ]; then
  mkfixture "$T/c" '#!/usr/bin/env bash
cd /tmp
echo hi
'
  bash "$T/c/bin/shellcheck-lint.sh" --accept --quiet >/dev/null 2>&1
  # The SAME code (SC2164) in a DIFFERENT file. That is the sharper test: the
  # ratchet keys on the PAIR, so this must be caught even though the code is
  # already baselined for subject.sh. A count-based baseline would also catch
  # it, but a code-only baseline would not, and this asserts which one is
  # implemented.
  printf '#!/usr/bin/env bash\ncd /var\necho second\n' > "$T/c/bin/second.sh"
  git -C "$T/c" add -A 2>/dev/null
  rc=0; out="$(bash "$T/c/bin/shellcheck-lint.sh" 2>&1)" || rc=$?
  check "C a new file/code pair: exit 1" 1 "$rc"
  if printf '%s' "$out" | grep -q 'second.sh'; then
    ok "C2 the regression report NAMES the new file"
  else
    bad "C2 regression names the file" "report did not mention second.sh"
  fi
  # the pre-existing baselined finding must NOT be re-reported as new
  if printf '%s' "$out" | grep -q '^  + .*subject.sh'; then
    bad "C3 baselined finding stays quiet" "subject.sh reported as new"
  else
    ok "C3 the baselined finding is not re-reported as new"
  fi
else
  skip "C regression path" "shellcheck absent"
fi

# --- D: shellcheck absent is BLIND (exit 2), never success -------------------
# ALWAYS RUNS. Needs shellcheck gone, so it builds a PATH holding the guard's
# other dependencies and nothing else. Clearing PATH entirely would remove git
# too and the guard would exit 2 for the wrong reason -- which would pass this
# assertion while proving nothing.
mkfixture "$T/d" '#!/usr/bin/env bash
echo fine
'
mkdir -p "$T/pathdir"
for b in git bash head grep sed sort comm mktemp date cat printf readlink dirname; do
  p="$(command -v "$b" 2>/dev/null)" && ln -sf "$p" "$T/pathdir/$b" 2>/dev/null
done
rc=0
PATH="$T/pathdir" bash "$T/d/bin/shellcheck-lint.sh" >/dev/null 2>&1 || rc=$?
check "D shellcheck absent: BLIND (exit 2), not 0" 2 "$rc"

# --- E: zero shell files is BLIND (exit 2), never success -------------------
if [ "$HAVE_SC" -eq 1 ]; then
  mkdir -p "$T/e/bin"
  cp "$GUARD" "$T/e/bin/shellcheck-lint.sh"
  git -C "$T/e" init -q 2>/dev/null
  git -C "$T/e" config user.email t@test; git -C "$T/e" config user.name T
  # A repo whose ONLY tracked file is a non-shell one. The guard's own copy is
  # left untracked on purpose: selection is tracked-only, so it must not count
  # itself and must therefore find nothing.
  printf 'not shell\n' > "$T/e/README.md"
  git -C "$T/e" add README.md 2>/dev/null
  git -C "$T/e" commit -qm fixture 2>/dev/null
  rc=0; bash "$T/e/bin/shellcheck-lint.sh" >/dev/null 2>&1 || rc=$?
  check "E zero shell files: BLIND (exit 2), not 0" 2 "$rc"
else
  skip "E zero files" "shellcheck absent"
fi

# --- F: --strict fails while findings remain baselined ----------------------
if [ "$HAVE_SC" -eq 1 ]; then
  rc=0; bash "$T/b/bin/shellcheck-lint.sh" --strict --quiet >/dev/null 2>&1 || rc=$?
  check "F --strict with a non-empty baseline: exit 3" 3 "$rc"
else
  skip "F --strict" "shellcheck absent"
fi

echo "shellcheck-lint: $pass passed, $fail failed, $skipped skipped"
[ "$fail" -eq 0 ]
