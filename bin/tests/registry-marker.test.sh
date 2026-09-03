#!/usr/bin/env bash
# registry-marker.test.sh -- the manifest's registry block.
#
#
# WHAT THE REGISTRY IS FOR. realisateur's lints ask "what projects exist" and
# the only answer was scheduler/schedule/*.conf -- a CHECKOUT. That one data
# dependency is what still forces a scheduler clone onto hosts that need none.
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
C="$ROOT/bin/cut-verb-build.sh"
L="$ROOT/bin/lib/registry-set.sh"   # the marker query's one home
echo "registry-marker.test"

# --- 1. one query, not one per repo, and ONE COPY of it -------------------
grep -q 'api graphql' "$L" && ok "the registry is read with a single GraphQL query" \
  || bad "no graphql call -- a contents call per repo is ~46 requests per nightly build"
grep -q 'first:100' "$L" && ok "it asks for repositories in one page" || bad "no page size given"
grep -q 'registry_repos' "$C" && ok "cut-verb-build reads the registry through the lib" \
  || bad "cut-verb-build re-types the marker query -- that is the four-copy defect again"

# A fifth copy would be added by someone who never read this test.
copies="$(grep -rlE 'HEAD:\.agent-project|expression:"HEAD:\$REGISTRY_MARKER"' \
            "$ROOT/bin" 2>/dev/null | grep -v '/lib/registry-set.sh$' | grep -v '/tests/' || true)"
[ -z "$copies" ] && ok "no script under bin/ re-types the marker query" \
  || bad "the marker query is typed again outside the lib" "$copies"

# --- 2. BLIND MUST NOT LOOK LIKE EMPTY -----------------------------------
# The load-bearing property. An empty registry in the manifest tells every
# consumer the estate has no projects, which is an instruction to scan nothing
# and report clean -- the exact failure hygiene-lint's own BLIND check exists
# to catch, one whole estate wide.
grep -q 'registry: BLIND' "$C" && ok "a failed query says BLIND" || bad "no BLIND path for the query"
grep -qE 'if \[ -n "\$registry" \]; then' "$C" \
  && ok "no registry rows are written when the query failed (absence, not zero)" \
  || bad "the block is emitted unconditionally -- BLIND would be recorded as an empty registry"
grep -q "could not look" "$C" && ok "it says absence means could-not-look" || bad "the distinction is not stated"

# --- 3. comment rows, so no consumer has to learn a second row type -------
grep -q "sed 's/\^/# registry" "$C" && ok "registry rows are comments" \
  || bad "registry rows are data rows -- every consumer's grep -v '^#' would now yield two shapes"

# --- 4. the marker is self-declared and retirable -------------------------
[ -f "$ROOT/.agent-project" ] && ok "this repo carries the marker it defines" \
  || bad "realisateur does not carry .agent-project -- it would be absent from its own registry"
grep -qi 'to retire' "$ROOT/.agent-project" && ok "the marker says how to retire it" \
  || bad "the marker does not say how to remove a project"

# --- 5. live, if gh is here ----------------------------------------------
if gh auth status >/dev/null 2>&1; then
  # Through the lib: this asserts the shipped path works.
  # shellcheck source=bin/lib/registry-set.sh
  . "$L"
  n="$(registry_repos | grep -c .)"
  [ "${n:-0}" -gt 0 ] && ok "the live query resolves ($n repo(s) currently carry the marker)" \
    || bad "the live query failed -- the mechanism does not work against the real account"
  if u="$(frame_unenrolled)"; then
    [ -z "$u" ] && ok "every rostered project is registry-enrolled" \
      || echo "  note: rostered and unenrolled, so marker-derived sweeps cannot see it: $(printf '%s' "$u" | tr '\n' ' ')"
  else
    echo "  SKIP: the roster would not resolve, so enrolment was not graded"
  fi
else
  echo "  SKIP: no gh auth here; the live query was not exercised"
fi

summary
