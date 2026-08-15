#!/usr/bin/env bash
# suite-docs-lint.test.sh -- the witness for the guard that stops the ledger
# growing back.
#
# THE LOAD-BEARING ASSERTION IS B2: a workflow that names one suite FAILS.
# That is the mechanism -- everything else is scaffolding. A version of this
# suite without B2 would pass against a guard that had check B deleted, which
# is precisely the removal it exists to catch. B2 is mutation-verified: with
# check B commented out of the guard, B2 (and only B2) goes red.
#
# usage: ./bin/tests/suite-docs-lint.test.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LINT="$REPO/bin/suite-docs-lint.sh"
pass=0; fail=0
ok()   { printf '  ok   %s\n' "$*"; pass=$((pass+1)); }
bad()  { printf '  FAIL %s\n' "$*"; fail=$((fail+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (output lacked '$3')" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1 (output contained '$3')" ;; *) ok "$1" ;; esac; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# run <fixture-dir> -> sets $out and $rc
run() {
  out="$(SUITE_DOCS_ROOT="$1" SUITE_DIR="$1/bin/tests" \
         SUITE_WORKFLOW="$1/.github/workflows/tests.yml" \
         bash "$LINT" 2>&1)"
  rc=$?
}

# A GLOBBING runner, verbatim in shape to the real one, so the fixture workflow
# is a fair stand-in: it mentions bin/tests/*.sh and no individual suite.
globbing_workflow() {
  cat <<'YML'
name: tests
on: [pull_request]
jobs:
  suites:
    runs-on: ubuntu-latest
    steps:
      - run: |
          for t in bin/tests/*.sh; do bash "$t"; done
YML
}

mkfixture() { # <name>
  local d="$WORK/$1"
  mkdir -p "$d/bin/tests" "$d/.github/workflows"
  globbing_workflow > "$d/.github/workflows/tests.yml"
  printf '%s' "$d"
}

echo "== A. every suite documents its own hermeticity =="

# The A cases -- one per shape of a missing/empty/buried '# HERMETICITY:'
# marker -- were retired with the requirement itself on 2026-08-15 (#321). It
# was 56 hand-written paragraphs asserting a property no test could check.
# Check B, the load-bearing one, is untouched and so are its cases.

# B1: a globbing workflow is clean.
d="$(mkfixture b1)"
printf '#!/usr/bin/env bash\n# HERMETICITY: temp repo.\ntrue\n' > "$d/bin/tests/alpha.test.sh"
run "$d"
check "B1 globbing workflow -> exit 0" "$rc" 0
has   "B1 says nothing to contend for" "$out" "nothing to contend for"

# B2: THE LOAD-BEARING CASE. A workflow that names ONE suite -- exactly the
# shape of the ledger entry that produced three merge conflicts on 2026-08-07
# -- must FAIL. If this case ever goes green while the guard still exits 0,
# the ledger can grow back and the conflicts return.
d="$(mkfixture b2)"
printf '#!/usr/bin/env bash\n# HERMETICITY: temp repo.\ntrue\n' > "$d/bin/tests/alpha.test.sh"
{ globbing_workflow
  echo '# alpha.test.sh  builds a temp repo per case.'; } > "$d/.github/workflows/tests.yml"
run "$d"
check "B2 workflow names a suite -> exit 1"   "$rc" 1
has   "B2 explains it is an append point"     "$out" "append"
has   "B2 quotes the offending line"          "$out" "alpha.test.sh  builds a temp repo"

# B3: a bin/tests/<name>.sh path is the same defect wearing a path, and is
# caught too -- otherwise the ledger comes back one directory deeper.
d="$(mkfixture b3)"
printf '#!/usr/bin/env bash\n# HERMETICITY: temp repo.\ntrue\n' > "$d/bin/tests/alpha.test.sh"
{ globbing_workflow
  echo '#   bin/tests/conf.sh   overrides HOME.'; } > "$d/.github/workflows/tests.yml"
run "$d"
check "B3 workflow names a suite by path -> exit 1" "$rc" 1

# B4: the GLOB ITSELF is not a name. A guard that flagged `bin/tests/*.sh`
# would flag the correct runner, which is how a guard gets deleted.
d="$(mkfixture b4)"
printf '#!/usr/bin/env bash\n# HERMETICITY: temp repo.\ntrue\n' > "$d/bin/tests/alpha.test.sh"
run "$d"
hasnt "B4 does not flag the glob itself" "$out" "FAIL"

echo
echo "== C. BLIND is never 0 =="

# C1: no suites at all is BLIND, not clean. "Found nothing" and "nothing is
# wrong" are different answers -- the most repeated fault in this ecosystem.
d="$(mkfixture c1)"
run "$d"
check "C1 no suites -> exit 2 (BLIND)" "$rc" 2
has   "C1 says BLIND"                  "$out" "BLIND"

# C2: no workflow is BLIND, not clean -- a deleted workflow must not read as
# "the workflow names no suite".
d="$(mkfixture c2)"
printf '#!/usr/bin/env bash\n# HERMETICITY: temp repo.\ntrue\n' > "$d/bin/tests/alpha.test.sh"
rm -f "$d/.github/workflows/tests.yml"
run "$d"
check "C2 no workflow -> exit 2 (BLIND)" "$rc" 2

# C3: a non-directory root is BLIND.
out="$(SUITE_DOCS_ROOT="$WORK/does-not-exist" bash "$LINT" 2>&1)"; rc=$?
check "C3 missing root -> exit 2 (BLIND)" "$rc" 2

echo
echo "== L. THIS repository satisfies its own guard =="

# L1/L2 are the difference between a guard that exists and a guard that holds.
# They run over the checkout under test, so a PR that adds a suite without a
# HERMETICITY note, or re-adds a ledger entry, goes red in CI on its own diff.
out="$(cd "$REPO" && bash "$LINT" "$REPO" 2>&1)"; rc=$?
check "L1 realisateur passes suite-docs-lint" "$rc" 0
hasnt "L2 no suite in this repo is undocumented" "$out" "FAIL"

echo
echo "  passed: $pass  failed: $fail"
[ "$fail" -eq 0 ]
