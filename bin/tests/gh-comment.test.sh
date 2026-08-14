#!/usr/bin/env bash
# HERMETICITY: a fake `gh` earlier on PATH records every invocation to a log
# file instead of reaching GitHub. No network, no real `gh`, no live issue.
#
# Contract test for gh-comment.sh (hf7y/realisateur#238): the wrapper this
# project's own code is supposed to route every issue comment through, so
# the provenance stamp `<!-- agent: <project>/<job> <ISO8601> -->` (last
# non-blank line, per vim-arcade#77's is_stamped()) is never optional.
set -uo pipefail

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %s\n     %s\n' "$1" "${2:-}"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected [$3] got [$2]"; fi; }
contains(){ case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected to contain [$3], got [$2]" ;; esac; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GC="$HERE/../gh-comment.sh"
BASH_BIN="$(command -v bash)"   # resolved BEFORE any test narrows PATH
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- the fake gh -----------------------------------------------------------
# Logs argv (one call per line, tab-separated) and, for `issue comment` /
# `issue close --comment`, also captures stdin / the --comment value so a
# test can assert on the stamped body it was actually given.
mkdir -p "$TMP/stub"
cat > "$TMP/stub/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
if [ "$1 $2" = "issue comment" ] && printf '%s\n' "$*" | grep -q -- '--body-file -'; then
  cat > "$GH_LAST_BODY"
fi
if [ "$1 $2" = "issue close" ]; then
  # --comment VALUE is somewhere in argv; find it and write it out.
  prev=''
  for a in "$@"; do
    if [ "$prev" = "--comment" ]; then printf '%s' "$a" > "$GH_LAST_BODY"; fi
    prev="$a"
  done
fi
if [ -n "${GH_FAIL:-}" ]; then echo "gh: fixture-forced failure" >&2; exit 1; fi
echo "https://github.com/fixture/repo/issues/1#issuecomment-1"
exit 0
STUB
chmod +x "$TMP/stub/gh"

run() {
  GH_LOG="$TMP/gh.log" GH_LAST_BODY="$TMP/gh.lastbody" GH_FAIL="${GH_FAIL:-}" \
  PATH="$TMP/stub:$PATH" "$BASH_BIN" "$GC" "$@"
}

echo "gh-comment contract"

# --- 1. --body posts a stamped comment -------------------------------------
: > "$TMP/gh.log"; rm -f "$TMP/gh.lastbody"
run hf7y/widget 7 tick --body 'landed in abc123' >"$TMP/out1" 2>"$TMP/err1"
check "posts exit 0" "$?" "0"
check "...calls gh issue comment on the right repo/issue" \
      "$(grep -c '^issue comment 7 --repo hf7y/widget' "$TMP/gh.log")" "1"
contains "...the posted body carries the original text" "$(cat "$TMP/gh.lastbody")" "landed in abc123"
last="$(tail -1 "$TMP/gh.lastbody")"
case "$last" in
  '<!-- agent: widget/tick '*'-->') ok "...the stamp names the PROJECT (from owner/repo) and the JOB" ;;
  *) bad "stamp format" "got: $last" ;;
esac

# --- 2. the stamp is dated in ISO8601 UTC, second precision -----------------
stamp_date="$(tail -1 "$TMP/gh.lastbody" | sed -E 's/.*agent: [^ ]+ ([0-9TZ:-]+) -->/\1/')"
case "$stamp_date" in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z)
    ok "stamp timestamp is ISO8601 UTC" ;;
  *) bad "stamp timestamp is ISO8601 UTC" "got: $stamp_date" ;;
esac

# --- 3. the stamp is the LAST non-blank line, even with trailing blanks ----
: > "$TMP/gh.log"; rm -f "$TMP/gh.lastbody"
printf 'multi\nline\nbody\n\n\n' | run hf7y/widget 7 tick - >/dev/null 2>&1
lastline="$(grep -v '^$' "$TMP/gh.lastbody" | tail -1)"
case "$lastline" in
  '<!-- agent: widget/tick '*'-->') ok "trailing blank lines in the body do not push the stamp off the end" ;;
  *) bad "stamp survives trailing blanks" "last non-blank line: $lastline" ;;
esac

# --- 4. --body-file reads a file -------------------------------------------
: > "$TMP/gh.log"; rm -f "$TMP/gh.lastbody"
printf 'from a file\n' > "$TMP/body.txt"
run hf7y/widget 7 tick --body-file "$TMP/body.txt" >/dev/null 2>&1
contains "--body-file reads the named file" "$(cat "$TMP/gh.lastbody")" "from a file"

check "--body-file on a missing file is a usage error (exit 2)" \
      "$(run hf7y/widget 7 tick --body-file "$TMP/no-such-file" >/dev/null 2>&1; echo $?)" "2"

# --- 5. stdin via a bare - ---------------------------------------------------
: > "$TMP/gh.log"; rm -f "$TMP/gh.lastbody"
printf 'piped in' | run hf7y/widget 7 tick - >/dev/null 2>&1
contains "a bare - reads the body from stdin" "$(cat "$TMP/gh.lastbody")" "piped in"

# --- 6. --close closes with the stamped comment, not a separate post -------
: > "$TMP/gh.log"; rm -f "$TMP/gh.lastbody"
run hf7y/widget 7 tick --close --body 'closing this out' >/dev/null 2>&1
check "--close calls issue close, not issue comment" \
      "$(grep -c '^issue close' "$TMP/gh.log")" "1"
check "...and does not ALSO post a separate comment" \
      "$(grep -c '^issue comment' "$TMP/gh.log")" "0"
contains "...the close comment carries the stamped body" "$(cat "$TMP/gh.lastbody")" "closing this out"

# --- 7. an empty body is refused, nothing posted ----------------------------
: > "$TMP/gh.log"
check "an empty --body is a usage error (exit 2)" \
      "$(run hf7y/widget 7 tick --body '' >/dev/null 2>&1; echo $?)" "2"
check "...and gh was never invoked" "$(wc -l < "$TMP/gh.log" | tr -d ' ')" "0"

# --- 8. owner/repo must contain a slash -------------------------------------
check "a repo with no '/' is a usage error (exit 2)" \
      "$(run widget 7 tick --body hi >/dev/null 2>&1; echo $?)" "2"

# --- 9. wrong positional count is a usage error, not a silent misparse -----
check "two positional args (missing job) is a usage error (exit 2)" \
      "$(run hf7y/widget 7 --body hi >/dev/null 2>&1; echo $?)" "2"

# --- 10. gh failure surfaces as exit 1, not swallowed -----------------------
check "a gh refusal surfaces as exit 1" \
      "$(GH_FAIL=1 run hf7y/widget 7 tick --body hi >/dev/null 2>&1; echo $?)" "1"

# --- 11. no gh on PATH is BLIND (exit 6), not a silent no-op ---------------
mkdir -p "$TMP/empty"
check "gh missing from PATH is BLIND (exit 6)" \
      "$(GH_LOG="$TMP/gh.log" GH_LAST_BODY="$TMP/gh.lastbody" PATH="$TMP/empty" \
         "$BASH_BIN" "$GC" hf7y/widget 7 tick --body hi >/dev/null 2>&1; echo $?)" "6"

echo
printf 'gh-comment: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
