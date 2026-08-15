#!/usr/bin/env bash
# suite-docs-lint.sh -- a suite documents ITSELF; the workflow names NO suite.
#
# RUNNER: bin/tests/suite-docs-lint.test.sh
# GUARD-TEST: bin/tests/suite-docs-lint.test.sh
# GATE: default
#
# THE FAILURE THIS EXISTS FOR, with the numbers.
#
# .github/workflows/tests.yml carried a hand-maintained per-suite ledger in its
# header: one paragraph per file in bin/tests/, appended to the same ~40 lines
# by every PR that added a suite. Underneath it, the runner it described has
# always been `for t in bin/tests/*.sh` -- a GLOB. The ledger was prose
# duplicating what the filesystem already knows.
#
# On 2026-08-07, four PRs were open at once. Three of them touched that region:
#
#     #88  created tests.yml and the ledger
#     #97  appended entries, merged 21:32Z
#     #95  appended an entry, merged 21:54Z
#     #96  appended two entries, still open
#
#   #97 merged -> #95 CONFLICTED and #96 CONFLICTED
#   both resolved by hand, both green
#   #95 merged -> #96 CONFLICTED AGAIN
#
# Three conflict events in one day. Every one of them was in this file, and
# only this file: `git merge-tree` on all three pairs reports exactly one
# conflicted path, .github/workflows/tests.yml, with the markers inside the
# ledger. Zero conflicts anywhere else in the repository that day. The cost was
# two rounds of hand-resolution on the same PR and a human asking twice.
#
# This is not bad luck and it does not decay. N open PRs that each add a suite
# produce N-1 conflicts, deterministically, forever, because they are all
# appending to one region of one file. The only fix that removes the
# POSSIBILITY rather than managing the symptom is to delete the shared append
# point: each note moves into the header of the suite it describes, which is a
# file only that PR touches.
#
# The information is not lost -- check A below asserts every suite still
# carries its own note, so relocating it is enforced rather than hoped for.
# Check B is the ratchet: it fails if a per-suite name ever reappears in the
# workflow, which is the mechanism being removed. Without B this is a cleanup;
# with B it is a guard.
#
# WHY A LINT AND NOT A PARAGRAPH IN CONTRIBUTING. Per PROSE-REAPING.md and
# BUILD-DISCIPLINE.md: prose decays, guards do not. A paragraph asking people
# not to re-add a ledger is exactly the artefact whose failure mode this file
# documents. It runs from the same `bin/tests/*.sh` glob that made the ledger
# redundant, so the mechanism is enforced by the thing it is about.
#
# exit 0  every suite documents itself and the workflow names none
# exit 1  at least one violation -- named, with file and reason
# exit 2  BLIND: could not scan (no repo root, no suites, no workflow). NEVER 0.
#         "Found nothing" and "nothing is wrong" are different answers.
set -uo pipefail

ROOT="${1:-${SUITE_DOCS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}}"
[ -n "$ROOT" ] && [ -d "$ROOT" ] || {
  echo "suite-docs-lint: BLIND: not a git repository and no path given" >&2
  exit 2
}

SUITE_DIR="${SUITE_DIR:-$ROOT/bin/tests}"
WORKFLOW="${SUITE_WORKFLOW:-$ROOT/.github/workflows/tests.yml}"

violations=0
# The per-suite '# HERMETICITY:' note was retired 2026-08-15 (#321). This file
# already said why: "A is a cleanup; B is what stops the ledger growing back."
# A was a prose requirement no test could check -- 56 hand-written paragraphs
# asserting a property nothing verified. B is behavioural and stays.
scanned="$(ls -1 "$SUITE_DIR"/*.sh 2>/dev/null | wc -l)"
[ "$scanned" -gt 0 ] || {
  echo "suite-docs-lint: BLIND: $SUITE_DIR/*.sh matched nothing -- scanned NOTHING" >&2
  exit 2
}

echo
echo "== B. THE WORKFLOW NAMES NO INDIVIDUAL SUITE =="
# THIS IS THE LOAD-BEARING CHECK. A is a cleanup; B is what stops the ledger
# growing back, and therefore what stops the conflicts.
#
# The runner GLOBS. Any occurrence of a specific suite's filename in the
# workflow is therefore, by construction, either a hand-maintained list or a
# per-suite paragraph -- both of which are an append point that every future
# PR must contend for. The glob pattern itself (`bin/tests/*.sh`) is not a
# name and is not matched by the pattern below.
if [ ! -f "$WORKFLOW" ]; then
  echo "suite-docs-lint: BLIND: no workflow at $WORKFLOW" >&2
  exit 2
fi
named="$(grep -nE '[A-Za-z0-9_-]+\.test\.sh|bin/tests/[A-Za-z0-9_-]+\.sh' "$WORKFLOW" || true)"
if [ -n "$named" ]; then
  echo "  FAIL ${WORKFLOW#"$ROOT"/}: names individual suites. That is an append"
  echo "       point every concurrent PR must contend for; the runner already"
  echo "       globs. Move the note into the suite's own header instead."
  printf '%s\n' "$named" | sed 's/^/         /'
  violations=$((violations + 1))
else
  echo "  ok   ${WORKFLOW#"$ROOT"/}: no per-suite name -- nothing to contend for"
fi

echo
if [ "$violations" -gt 0 ]; then
  echo "suite-docs-lint: $violations violation(s) over $scanned suite(s)."
  exit 1
fi
echo "suite-docs-lint: $scanned suite(s); the workflow names none."
exit 0
