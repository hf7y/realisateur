#!/usr/bin/env bash
# verify-amend.sh -- provoke each of the four gates into failing on purpose.
#
# A gate that has only ever been seen to PASS is indistinguishable from a gate
# that cannot fail. Each case below makes exactly one gate fail and asserts the
# refusal, so "the gate works" is a measurement rather than a recollection.

set -uo pipefail
SELF="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
AMEND="$SELF/lib/amend.sh"
PASS=0; FAIL=0
ok()   { printf 'PASS  %s\n' "$*"; PASS=$((PASS+1)); }
bad()  { printf 'FAIL  %s\n' "$*"; FAIL=$((FAIL+1)); }

# assert <label> <expected-rc> <expected-substring> -- <cmd...>
assert() {
  local label="$1" want_rc="$2" want_txt="$3"; shift 4
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [ "$rc" != "$want_rc" ]; then
    bad "$label (exit $rc, wanted $want_rc)"; return
  fi
  if [ -n "$want_txt" ] && ! printf '%s' "$out" | grep -q -- "$want_txt"; then
    bad "$label (exit $want_rc but did not say: $want_txt)"; return
  fi
  ok "$label"
}

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
GOOD_REASON="a genuine reason of ample length describing what the tooling learned"

# ---- usage and blindness ---------------------------------------------------
assert "no arguments is a usage error"        2 'usage: amend' -- "$AMEND"
assert "a missing reason is a usage error"    2 'STATED REASON' -- "$AMEND" "$SELF/man/bashify.1"
assert "a nonexistent page is BLIND, not a pass" 6 'BLIND' -- "$AMEND" "$TMP/nope.1" "$GOOD_REASON"

# ---- gate 1: the stated reason --------------------------------------------
assert "a too-short reason is refused" 7 'FAIL  REASON' -- \
  "$AMEND" "$SELF/man/bashify.1" "too short"
assert "'the tool cannot do it' is refused as a reason" 7 'GAPS.md line, not a page edit' -- \
  "$AMEND" "$SELF/man/bashify.1" "we could not implement the thing the page promised, so the page changes"

# ---- gate 2: the previous page preserved ----------------------------------
# An untracked page has no previous text, so the promise cannot be seen to move.
git -C "$TMP" init -q 2>/dev/null
mkdir -p "$TMP/man" "$TMP/bin"
cp "$SELF/man/bashify.1" "$TMP/man/bashify.1"
cp "$SELF/bin/bashify"   "$TMP/bin/bashify"
assert "an untracked page is refused: nothing to compare against" 7 'not in version control' -- \
  "$AMEND" "$TMP/man/bashify.1" "$GOOD_REASON"

# A tracked but unmodified page is not an amendment at all.
git -C "$TMP" add man/bashify.1 bin/bashify >/dev/null 2>&1
git -C "$TMP" -c user.email=t@t -c user.name=t commit -qm base >/dev/null 2>&1
assert "an unmodified page is refused: there is no amendment" 7 'no amendment to gate' -- \
  "$AMEND" "$TMP/man/bashify.1" "$GOOD_REASON"

# ---- gate 3: the rows re-run against the NEW text -------------------------
# The failure this gate exists to catch: changing the promise to match a tool
# that cannot keep it. Break the page and confirm the gate refuses.
printf '.SH INVENTED\nA section promising a flag that does not exist: \\-\\-nonesuch.\n' \
  >> "$TMP/man/bashify.1"
sed -i 's/^\.B bashify \\- .*/.B bashify \\- do one thing and also another thing/' "$TMP/man/bashify.1" 2>/dev/null
assert "a page the tool cannot satisfy is refused" 7 'FAIL  ROWS' -- \
  "$AMEND" "$TMP/man/bashify.1" "$GOOD_REASON"

# ---- the allowing case -----------------------------------------------------
# Not asserted here: allowing requires a real uncommitted edit to the live page,
# which this test must not create. It is exercised in the session record and by
# `verify-check.sh` scoring the same page. Named so the omission is visible
# rather than mistaken for coverage.
printf 'note: the ALLOW path is not covered here (it needs a live uncommitted edit)\n'

printf -- '\n--- verify-amend: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ] || exit 1
