#!/usr/bin/env bash
# verify-check.sh -- the page test's own test.
#
# `check` scoring its own page is the primary witness, but a scorer that
# passes everything is indistinguishable from a scorer that does nothing.
# So this also runs it against a fixture built to fail every row, and
# against a page it cannot read. Named assertions, not exit codes alone.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
B="$HERE/bin/bashify"

# bin/bashify's own page documents `bashify list` showing `page` as SUMMON,
# which is only true when $BASHEUR_BIN resolves to something executable.
# Without a basheur checkout as a sibling project (true on most hosts and
# in CI), `page` reports GAP instead and the EXAMPLES row fails -- not
# because the tool is broken, but because this test was reading host state
# instead of testing the page. Stub it, same as guard-estate stubs gh/ssh.
STUB_STORE="$(mktemp -d)/basheur"
printf '#!/bin/sh\nexit 0\n' > "$STUB_STORE"
chmod +x "$STUB_STORE"
export BASHEUR_BIN="$STUB_STORE"
trap 'rm -rf "$(dirname "$STUB_STORE")"' EXIT

pass=0; fail=0
t() { # t <name> <want-rc> <args...>
  local name="$1" want="$2"; shift 2
  local out rc; out="$(cd "$HERE" && timeout 60 "$B" "$@" 2>&1)"; rc=$?
  if [ "$rc" = "$want" ]; then pass=$((pass+1)); printf 'PASS  %s\n' "$name"
  else fail=$((fail+1)); printf 'FAIL  %s: exit %s, wanted %s\n%s\n' "$name" "$rc" "$want" "$(printf '%s' "$out" | tail -3)"; fi
}
t 'its own page scores 9 of 9 (exit 0)'        0 check man/bashify.1 bin/bashify
t 'a page built to fail every row exits 7'     7 check test/fixtures/bad-page.1 bin/bashify
t 'an unreadable page is BLIND, not passing'   6 check test/fixtures/no-such-page.1 bin/bashify
t 'a non-executable subject is BLIND'          6 check man/bashify.1 test/fixtures/bad-page.1
t 'wrong arity is a usage error'               2 check man/bashify.1
printf '\n--- verify-check: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
