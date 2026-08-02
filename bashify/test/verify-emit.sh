#!/usr/bin/env bash
# verify-emit.sh -- does `bashify emit` actually produce a branch?
#
# THE LOAD-BEARING ASSERTION IS E1, AND IT IS EMBARRASSINGLY SIMPLE:
# emit must exit 0 on a clean project. Nothing asserted that until now, and
# emit has been totally broken TWICE for the same reason:
#
#   1. (recorded in bashify.sh's own header) the purge guard was unsatisfiable
#      against lib/verb.sh's documentation of --summon. emit exited 5 for every
#      project, on every run, FOR TWO DAYS, while `bashify list` reported emit
#      MECHANIZED -- because `_state` only asks whether the file is executable.
#
#   2. (2026-08-02, found by this file's first run) the de-fork added
#      "It calls `claude -p` directly" to the skeleton. The exemption was
#      bounded to the word `agent` and never covered a vendor name, so the
#      vendor grep matched the skeleton and emit exited 5 for every project
#      again.
#
# Twice is a pattern, and the pattern is that emit's health was inferred from
# a file mode rather than from running it. This file runs it.
#
# WHY IT IS SAFE TO RUN. emit opens with `git rm -r .` and `git branch -D
# bashified` against the project's REAL repo, which is why it was untestable
# until BASHIFY_SCHED and BASHIFY_WORK were made overridable. This test builds
# throwaway repos and points both at them; it never reads the live registry.
#
# A TRAP THIS FILE ENCODES: the fixture must NOT live under a path containing
# `.claude`. The generated verb bakes its source repo path into LEGACY_ROOT, so
# a fixture under ~/.claude/... injects the token `claude` into the emitted
# tree and the purge guard fails for a reason that has nothing to do with the
# code under test. That cost a false attribution once already; E0 asserts it.
set -uo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"   # bashify/
EMIT="$ROOT/bashify.sh"

pass=0; fail=0
ok()   { printf '  ok   %s\n' "$*"; pass=$((pass+1)); }
bad()  { printf '  FAIL %s\n' "$*"; fail=$((fail+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
export BASHIFY_SCHED="$WORK/sched"
mkdir -p "$BASHIFY_SCHED/schedule"
G() { git -c user.email=t@t -c user.name=t -C "$1" "${@:2}"; }

# E0 -- the trap, asserted before anything depends on it.
case "$WORK" in
  *.claude*) bad "E0 fixture path contains .claude ($WORK) -- results would be bogus" ;;
  *)         ok  "E0 fixture path is free of the token the guard looks for" ;;
esac

# mkproj <name> [extra-script-basename]
mkproj() {
  local d="$WORK/repos/$1"
  rm -rf "$d"; mkdir -p "$d/bin"; G "$d" init -q -b main
  printf '#!/usr/bin/env bash\necho hello\n' > "$d/bin/hello.sh"; chmod +x "$d/bin/hello.sh"
  if [ -n "${2:-}" ]; then
    printf '#!/usr/bin/env bash\necho x\n' > "$d/bin/$2"; chmod +x "$d/bin/$2"
  fi
  printf 'x\n' > "$d/README.md"
  G "$d" add -A; G "$d" commit -qm init
  printf 'PROJECT_REPO_PATH=%s\n' "$d" > "$BASHIFY_SCHED/schedule/$1.conf"
  printf '%s' "$d"
}

echo "== E. emit produces a branch =="

# E1 -- THE REGRESSION. A clean project must emit at exit 0.
r="$(mkproj projclean)"
out="$(BASHIFY_WORK="$WORK/wt1" "$EMIT" projclean testverb "a throwaway" 2>&1)"; rc=$?
check "E1 emit exits 0 on a clean project" "$rc" "0"
[ "$rc" = 0 ] || printf '       emit said: %s\n' "$(printf '%s' "$out" | tail -3 | tr '\n' ' ')"

# E2 -- and the branch is real, not merely a zero exit.
check "E2 the bashified branch exists" \
  "$(G "$r" rev-parse --verify -q bashified >/dev/null 2>&1 && echo yes || echo no)" "yes"
tree="$(G "$r" ls-tree -r --name-only bashified 2>/dev/null)"
for f in bin/testverb man/testverb.1 lib/verb.sh test/contract-test.sh; do
  check "E2 branch carries $f" "$(printf '%s\n' "$tree" | grep -cx "$f")" "1"
done

echo
echo "== F. the guard still guards =="

# F1 -- the exemption is for the skeleton, so the skeleton must be on the
# branch AND byte-identical to it. If it were not, E1 passing would mean the
# guard had simply been switched off.
check "F1 the emitted lib/verb.sh is byte-identical to the skeleton" \
  "$(G "$r" show bashified:lib/verb.sh 2>/dev/null | md5sum | cut -d' ' -f1)" \
  "$(md5sum < "$ROOT/skel/lib/verb.sh" | cut -d' ' -f1)"

# F2 -- and the skeleton really does contain a vendor token, which is the whole
# reason this exemption has to cover the vendor half. If someone rewords the
# skeleton later this assertion goes stale LOUDLY rather than silently.
check "F2 the skeleton names a vendor (so the exemption is load-bearing)" \
  "$([ "$(grep -ciE '\b(claude|anthropic|openai|gpt|llm|assistant)' "$ROOT/skel/lib/verb.sh")" -gt 0 ] && echo yes || echo no)" "yes"

# F3 -- a script whose NAME names a vendor is not exposed as a subcommand, and
# is recorded rather than silently dropped.
r2="$(mkproj projvendor 'claude-helper.sh')"
BASHIFY_WORK="$WORK/wt2" "$EMIT" projvendor othervrb "a throwaway" >/dev/null 2>&1
check "F3 a vendor-named script is not exposed as a subcommand" \
  "$(G "$r2" show bashified:bin/othervrb 2>/dev/null | grep -c 'claude-helper')" "0"
check "F3 and the branch still emitted (the purge is recorded, not fatal)" \
  "$(G "$r2" rev-parse --verify -q bashified >/dev/null 2>&1 && echo yes || echo no)" "yes"

echo
printf 'passed %d, failed %d\n' "$pass" "$fail"
exit $(( fail > 0 ? 1 : 0 ))
