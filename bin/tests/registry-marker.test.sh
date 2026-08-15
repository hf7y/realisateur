#!/usr/bin/env bash
# registry-marker.test.sh -- the manifest's registry block.
#
#
# WHAT THE REGISTRY IS FOR. realisateur's lints ask "what projects exist" and
# the only answer was scheduler/schedule/*.conf -- a CHECKOUT. That one data
# dependency is what still forces a scheduler clone onto hosts that need none.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
C="$ROOT/bin/cut-verb-build.sh"
pass=0; fail=0
ok()  { printf '  PASS: %s\n' "$*"; pass=$((pass+1)); }
bad() { printf '  FAIL: %s\n' "$*"; fail=$((fail+1)); }
echo "registry-marker.test"

# --- 1. one query, not one per repo --------------------------------------
grep -q 'gh api graphql' "$C" && ok "the registry is read with a single GraphQL query" \
  || bad "no graphql call -- a contents call per repo is ~46 requests per nightly build"
grep -q 'first:100' "$C" && ok "it asks for repositories in one page" || bad "no page size given"

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
  q='query($owner:String!){ user(login:$owner){ repositories(first:100, isFork:false, ownerAffiliations:OWNER){
       nodes{ name isArchived marker: object(expression:"HEAD:.agent-project"){ __typename } } } } }'
  n="$(gh api graphql -F owner=hf7y -f query="$q" --jq '[.data.user.repositories.nodes[]|select(.marker!=null and .isArchived==false)]|length' 2>/dev/null)"
  [ -n "$n" ] && ok "the live query resolves ($n repo(s) currently carry the marker)" \
    || bad "the live query failed -- the mechanism does not work against the real account"
else
  echo "  SKIP: no gh auth here; the live query was not exercised"
fi

printf '\nregistry-marker.test: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
