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

# ---- gate 4: callers, and the owner-CLONE fix for #115 --------------------
# #115: the owner-skip used to compare only git-common-dir, which recognises a
# WORKTREE of the owning project but not a CLONE -- a `git clone` gets its own
# .git by construction, so the owner's own self-references (its impl, its
# test, its own page) scored as downstream invocations of itself. Fixture
# below builds three UNRELATED repos (separate `git init`, no shared history,
# because the bug and the fix are both about the REMOTE URL, not ancestry):
#   fixowner  -- registered as the verb's own project. Contains a
#                self-reference invocation, same shape as bashify's old
#                CONTRACT.md/README.md/man page hits.
#   amendfrom -- what amend.sh is invoked against. Different git dir than
#                fixowner, SAME origin slug -- the clone-of-the-owner case.
#   fixcaller -- a genuinely different project (different slug) with a real
#                invocation -- must still be caught, or the fix went too far.
CTMP="$(mktemp -d)"; trap 'rm -rf "$TMP" "$CTMP"' EXIT
mkfixrepo() {  # mkfixrepo <dir> <origin-url>
  local d="$1" url="$2"
  git -C "$d" init -q
  git -C "$d" -c user.email=t@t -c user.name=t commit -q --allow-empty -m base >/dev/null 2>&1
  git -C "$d" branch -q bashified
  # A fake, unfetchable origin is fine: the gate only reads `remote get-url`
  # and greps the local `origin/bashified` ref, never fetches.
  git -C "$d" remote add origin "$url"
  git -C "$d" update-ref refs/remotes/origin/bashified refs/heads/bashified
}
FIXOWNER="$CTMP/fixowner"; AMENDFROM="$CTMP/amendfrom"; FIXCALLER="$CTMP/fixcaller"
mkdir -p "$FIXOWNER" "$AMENDFROM" "$FIXCALLER"
mkfixrepo "$FIXOWNER"  "https://github.com/fixtest/fixverb.git"
mkfixrepo "$AMENDFROM" "https://github.com/fixtest/fixverb.git"   # same slug, different .git
mkfixrepo "$FIXCALLER" "https://github.com/fixtest/other.git"     # different project entirely

mkdir -p "$FIXOWNER/bin" "$AMENDFROM/man" "$FIXCALLER/bin"
printf '#!/usr/bin/env bash\nfixverb --self-check\n' > "$FIXOWNER/bin/run-fixverb.sh"
git -C "$FIXOWNER" add -A
git -C "$FIXOWNER" -c user.email=t@t -c user.name=t commit -qm "self-reference" >/dev/null 2>&1
git -C "$FIXOWNER" branch -qf bashified
git -C "$FIXOWNER" update-ref refs/remotes/origin/bashified refs/heads/bashified

printf '#!/usr/bin/env bash\nfixverb --now\n' > "$FIXCALLER/bin/wrapper.sh"
git -C "$FIXCALLER" add -A
git -C "$FIXCALLER" -c user.email=t@t -c user.name=t commit -qm "real caller" >/dev/null 2>&1
git -C "$FIXCALLER" branch -qf bashified
git -C "$FIXCALLER" update-ref refs/remotes/origin/bashified refs/heads/bashified

printf '.TH FIXVERB 1\n.SH NAME\nfixverb \\- a test fixture verb\n' > "$AMENDFROM/man/fixverb.1"
git -C "$AMENDFROM" add -A
git -C "$AMENDFROM" -c user.email=t@t -c user.name=t commit -qm base2 >/dev/null 2>&1
git -C "$AMENDFROM" branch -qf bashified
git -C "$AMENDFROM" update-ref refs/remotes/origin/bashified refs/heads/bashified
printf '.TH FIXVERB 1\n.SH NAME\nfixverb \\- a test fixture verb, amended\n' > "$AMENDFROM/man/fixverb.1"

FIXSCHED="$CTMP/sched"; mkdir -p "$FIXSCHED/schedule"
printf 'PROJECT_REPO_PATH="%s"\n' "$FIXOWNER"  > "$FIXSCHED/schedule/fixowner.conf"
printf 'PROJECT_REPO_PATH="%s"\n' "$FIXCALLER" > "$FIXSCHED/schedule/fixcaller.conf"

CALLERS_OUT="$(BASHIFY_SCHED="$FIXSCHED" "$AMEND" "$AMENDFROM/man/fixverb.1" "$GOOD_REASON" 2>&1)"
if printf '%s' "$CALLERS_OUT" | grep -q 'INVOCATION fixowner'; then
  bad "a clone of the owning project is skipped, not scored as a caller (#115)"
else
  ok "a clone of the owning project is skipped, not scored as a caller (#115)"
fi
if printf '%s' "$CALLERS_OUT" | grep -q "1 invocation(s) of 'fixverb'" \
   && printf '%s' "$CALLERS_OUT" | grep -q 'INVOCATION fixcaller'; then
  ok "a genuinely different project's real invocation is still caught"
else
  bad "a genuinely different project's real invocation is still caught"
fi
if printf '%s' "$CALLERS_OUT" | grep -q "1 branch(es) skipped as the verb's own project"; then
  ok "self-skip count reflects exactly the one owner clone"
else
  bad "self-skip count reflects exactly the one owner clone"
fi

# ---- the allowing case -----------------------------------------------------
# Not asserted here: allowing requires a real uncommitted edit to the live page,
# which this test must not create. It is exercised in the session record and by
# `verify-check.sh` scoring the same page. Named so the omission is visible
# rather than mistaken for coverage.
printf 'note: the ALLOW path is not covered here (it needs a live uncommitted edit)\n'

printf -- '\n--- verify-amend: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ] || exit 1
