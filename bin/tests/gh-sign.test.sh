#!/usr/bin/env bash
#
# Contract test for gh-sign.sh: an agent gets signed WITHOUT calling anything
# special, and a shim standing in front of `gh` never costs a write.
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected [$3] got [$2]"; fi; }
contains(){ case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected to contain [$3], got [$2]" ;; esac; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GS="$HERE/../gh-sign.sh"
BASH_BIN="$(command -v bash)"      # resolved BEFORE any test narrows PATH
TIMEOUT_BIN="$(command -v timeout)" # same reason: the recursion tests run on an empty PATH
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- the fake gh -----------------------------------------------------------
# Logs argv and captures the body whichever way it arrives.
mkdir -p "$TMP/stub"
cat > "$TMP/stub/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
: > "$GH_LAST_BODY"
prev=''
for a in "$@"; do
  case "$prev" in --comment|--body) printf '%s' "$a" > "$GH_LAST_BODY" ;; esac
  prev="$a"
done
printf '%s\n' "$*" | grep -q -- '--body-file -' && cat > "$GH_LAST_BODY"
exit "${GH_EXIT:-0}"
STUB
chmod +x "$TMP/stub/gh"

run() {
  GH_LOG="$TMP/gh.log" GH_LAST_BODY="$TMP/gh.body" GH_EXIT="${GH_EXIT:-0}" \
  PATH="$TMP/stub:$PATH" "$BASH_BIN" "$GS" "$@"
}
lastline() { grep -v '^[[:space:]]*$' "$TMP/gh.body" | tail -1; }
reset() { : > "$TMP/gh.log"; : > "$TMP/gh.body"; }

echo "gh-sign contract"

# --- 1. the ordinary agent call is signed with no wrapper and no argument ---
reset
run issue comment 7 --repo hf7y/widget --body 'landed in abc123' >/dev/null 2>&1
check "an unmodified \`gh issue comment\` exits 0" "$?" "0"
contains "...the original body survives" "$(cat "$TMP/gh.body")" "landed in abc123"
case "$(lastline)" in
  '<!-- agent: '*'@'*' -->') ok "...and it is signed, with no --job/--project argument to forget" ;;
  *) bad "signed" "last non-blank line: $(lastline)" ;;
esac

# --- 2. the identity is READ, not accepted from the caller -----------------
contains "the stamp names this account" "$(lastline)" "$(id -un)@"
stamp_date="$(lastline | sed -E 's/.*@[^ ]+ ([0-9TZ:-]+) .*/\1/')"
case "$stamp_date" in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z)
    ok "the stamp is dated ISO8601 UTC, second precision" ;;
  *) bad "ISO8601 UTC" "got: $stamp_date" ;;
esac

# --- 2b. the Z must be TRUE, not just present ------------------------------
# `local TZ=UTC` shipped here for months and was a no-op IN THE ONE CASE THAT
# MATTERS. `local` creates a shell variable; `printf %(...)T` formats through
# libc, which reads TZ from the ENVIRONMENT. When TZ is already exported the
# local inherits the export attribute and the value did reach libc -- so
# setting TZ here would test nothing. With TZ ABSENT, which is the ordinary
# state of a login shell and of cron, nothing exported it and every stamp
# carried /etc/localtime wearing a `Z`. Case 2 above could not see it: the
# SHAPE was always right.
utc_hour="$(date -u +%H)"
if [ "$utc_hour" = "$(date +%H)" ]; then
  echo "  SKIP  Z-is-true: this host's localtime IS UTC, so the bug cannot show here" >&2
else
  nz_hour="$(env -u TZ "$BASH_BIN" "$GS" --stamp | sed -E 's/.*T([0-9]{2}):.*/\1/')"
  if [ "$nz_hour" = "$utc_hour" ]; then
    ok "with TZ unset the stamp is still UTC, so the Z is a fact and not a suffix"
  else
    bad "hour $utc_hour (UTC)" "hour $nz_hour -- localtime wearing a Z"
  fi
fi

reset
# `issue create` is grammar-gated (lib/body-grammar.sh), so the fixture is
# well-formed. The case is about the TRAILING BLANK LINES, not the grammar:
# bin/tests/body-grammar.test.sh owns the refusal itself.
printf 'NO-DECISION: @zach nothing to weigh\nline\n\n<!-- DEFERRED -->\n- none\n<!-- /DEFERRED -->\n\n\n' > "$TMP/body.txt"
run issue create --repo hf7y/widget --title t --body-file "$TMP/body.txt" >/dev/null 2>&1
case "$(lastline)" in
  '<!-- agent: '*) ok "trailing blank lines do not push the marker off the end" ;;
  *) bad "marker last" "got: $(lastline)" ;;
esac

reset
run issue comment 7 --repo hf7y/widget --body "$(printf 'already done\n\n<!-- agent: someone@somewhere 2026-08-15T00:00:00Z -->')" >/dev/null 2>&1
check "an already-signed body is passed through untouched" \
      "$(grep -c 'someone@somewhere' "$TMP/gh.body")" "1"

reset
run issue close 7 --repo hf7y/widget --comment 'closing this out' >/dev/null 2>&1
contains "\`issue close --comment\` keeps its body" "$(cat "$TMP/gh.body")" "closing this out"
case "$(lastline)" in
  '<!-- agent: '*) ok "...and is signed, without being rewritten to --body-file" ;;
  *) bad "close signed" "got: $(lastline)" ;;
esac

reset
run issue list --repo hf7y/widget --state open >/dev/null 2>&1
check "a read passes through with argv intact" \
      "$(cat "$TMP/gh.log")" "issue list --repo hf7y/widget --state open"

reset
run pr merge 3 --repo hf7y/widget --squash >/dev/null 2>&1
check "a non-body write passes through with argv intact" \
      "$(cat "$TMP/gh.log")" "pr merge 3 --repo hf7y/widget --squash"

# --- 7. FAIL OPEN: a signature is never worth a lost write ----------------
reset
run issue comment 7 --repo hf7y/widget --body-file "$TMP/no-such-file" >/dev/null 2>&1
check "an unreadable --body-file still reaches gh (unsigned beats dropped)" \
      "$(grep -c 'no-such-file' "$TMP/gh.log")" "1"

reset
run issue comment 7 --repo hf7y/widget >/dev/null 2>&1
check "a body-less (interactive) call is left alone" \
      "$(cat "$TMP/gh.log")" "issue comment 7 --repo hf7y/widget"

check "a gh refusal surfaces, not swallowed" \
      "$(GH_EXIT=1 run issue comment 7 --repo hf7y/widget --body hi >/dev/null 2>&1; echo $?)" "1"

# --- 9. the shim must never resolve to ITSELF ------------------------------
mkdir -p "$TMP/loop"
ln -sf "$GS" "$TMP/loop/gh"
out="$(PATH="$TMP/loop" "$TIMEOUT_BIN" 10 "$BASH_BIN" "$GS" --self-check 2>&1)"; rc=$?
check "a shim that is the only gh on PATH reports BLIND (exit 6), never recurses" "$rc" "6"
contains "...and says so out loud" "$out" "BLIND"

out="$(PATH="$TMP/loop:$TMP/stub" "$TIMEOUT_BIN" 10 "$BASH_BIN" "$GS" --self-check 2>&1)"
contains "--self-check resolves past the shim to the real gh" "$out" "$TMP/stub/gh"

# --- 10. WHICH COPY OF THE POLICY IS THIS, AND HOW OLD? (#330) -------------
# The shim ships as one link per host into a dated build. It recognises itself
# among the builds by inode -- the same `-ef` test that stops it re-executing
# itself -- because resolving /usr/local/bin/gh would need readlink, which is
# one of the externals it may not have.
mkbuild() {   # mkbuild <build-id> -> path to bin/gh inside a fake build
  mkdir -p "$TMP/builds/$1/realisateur/bin/lib"
  cp "$GS" "$TMP/builds/$1/realisateur/bin/gh"
  cp "$(dirname "$GS")/lib/body-grammar.sh" "$TMP/builds/$1/realisateur/bin/lib/"
  chmod +x "$TMP/builds/$1/realisateur/bin/gh"
  printf '%s' "$TMP/builds/$1/realisateur/bin/gh"
}
FRESH="$(mkbuild "$(date -u +%Y-%m-%dT%H%MZ)")"
STALE="$(mkbuild 2020-01-01T0000Z)"
mkdir -p "$TMP/hostbin"; ln -sf "$FRESH" "$TMP/hostbin/gh"

out="$(GH_SIGN_BUILD_ROOTS="$TMP/builds" PATH="$TMP/stub:$PATH" "$BASH_BIN" "$FRESH" --stamp)"
contains "a copy inside a build names the build in its stamp" "$out" "build $(date -u +%Y-%m-%d)"
hasnt    "...and a fresh one is not marked stale" "$out" "STALE"

# Through the LINK, which is how every account will actually invoke it.
out="$(GH_SIGN_BUILD_ROOTS="$TMP/builds" PATH="$TMP/stub:$PATH" "$TMP/hostbin/gh" --stamp)"
contains "invoked through the host link, it still finds its own build" "$out" "build $(date -u +%Y-%m-%d)"

out="$(GH_SIGN_BUILD_ROOTS="$TMP/builds" PATH="$TMP/stub:$PATH" "$BASH_BIN" "$STALE" --stamp)"
contains "a build past the age limit marks the ARTIFACT, not just a log" "$out" "STALE"
case "$out" in
  *'STALE '[0-9]*d*) ok "...with the age in days, so the reader need not compute it" ;;
  *) bad "STALE <n>d" "got: $out" ;;
esac

out="$(GH_SIGN_BUILD_ROOTS="$TMP/builds" PATH="$TMP/stub:$PATH" "$BASH_BIN" "$STALE" --self-check 2>&1)"; rc=$?
check "--self-check exits 1 on a stale build, so a clock can ask" "$rc" "1"
contains "...and demands the refresh by name" "$out" "selfdev-release-tick.sh --apply"

reset
out="$(GH_SIGN_BUILD_ROOTS="$TMP/builds" GH_LOG="$TMP/gh.log" GH_LAST_BODY="$TMP/gh.body" \
       PATH="$TMP/stub:$PATH" "$BASH_BIN" "$STALE" issue comment 7 --repo hf7y/w --body hi 2>&1 >/dev/null)"
contains "a stale shim announces itself at the write" "$out" "STALE"
check "...and still writes: fail open outlives the expiry" \
      "$(grep -c 'issue comment 7' "$TMP/gh.log")" "1"

out="$(GH_SIGN_BUILD_ROOTS="$TMP/builds" PATH="$TMP/stub:$PATH" "$BASH_BIN" "$GS" --stamp)"
contains "a copy that is in no build says so rather than claiming freshness" "$out" "unbuilt"

# --- 11. WHO IS AT THE KEYBOARD, not which host (scheduler#147) ------------
# The shim was kept off mandark so Zach's own comments stayed unsigned, which
# is the signal decision-rot.sh reads. Host was a proxy for actor and agents
# run on mandark, so an agent comment from there was read as Zach ANSWERING.
# These pin the replacement: cron signs, an agent signs, a human does not.
reset
env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT \
  GH_LOG="$TMP/gh.log" GH_LAST_BODY="$TMP/gh.body" \
  PATH="$TMP/stub:$PATH" "$BASH_BIN" "$GS" \
  issue comment 7 --repo hf7y/widget --body 'from cron' </dev/null >/dev/null 2>&1
case "$(lastline)" in
  '<!-- agent: '*) ok "no agent env and no TTY is CRON, and cron is still signed" ;;
  *) bad "signed" "last non-blank line: $(lastline)" ;;
esac

reset
CLAUDECODE=1 run issue comment 7 --repo hf7y/widget --body 'from an agent' >/dev/null 2>&1
case "$(lastline)" in
  '<!-- agent: '*) ok "a declared agent session is signed" ;;
  *) bad "signed" "last non-blank line: $(lastline)" ;;
esac

# The human path needs a real terminal, so it needs a pty. Skipping is said
# out loud: an assertion that quietly does not run is worse than none.
if command -v script >/dev/null 2>&1; then
  reset
  script -qec "env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT \
    GH_LOG='$TMP/gh.log' GH_LAST_BODY='$TMP/gh.body' \
    PATH='$TMP/stub:$PATH' '$BASH_BIN' '$GS' \
    issue comment 7 --repo hf7y/widget --body 'typed by hand'" /dev/null >/dev/null 2>&1
  case "$(lastline)" in
    '<!-- agent: '*) bad "a human's comment left unsigned" "it was signed: $(lastline)" ;;
    *) ok "a TTY with no agent session is a human, and is NOT signed" ;;
  esac
else
  echo "  SKIP  human-at-keyboard: no \`script\` to allocate a pty" >&2
fi

# cut-verb-build.sh probes `--help` on every command in a build and refuses
# the whole cut on a bad exit. Without this the shim would fail 33 verbs on
# any runner that has no gh installed.
out="$(PATH="$TMP/empty-path" "$TIMEOUT_BIN" 10 "$BASH_BIN" "$GS" --help 2>&1)"; rc=$?
check "--help exits 0 where there is no real gh at all" "$rc" "0"
contains "...and introduces the shim" "$out" "gh-sign"

echo
summary
