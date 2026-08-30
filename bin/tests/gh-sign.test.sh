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
# Real gh's `@file`/`@-` magic is a `-F/--field` thing; `-f/--raw-field`
# takes the value LITERALLY, `@-` included. Mimic that split here, or this
# stub can't catch a caller that forgot to upgrade the flag.
prev=''
for a in "$@"; do
  case "$a" in
    body=@-)
      case "$prev" in
        -F|--field) cat > "$GH_LAST_BODY" ;;
        *) printf '%s' "$a" > "$GH_LAST_BODY" ;;
      esac ;;
    body=*) printf '%s' "${a#body=}" > "$GH_LAST_BODY" ;;
  esac
  prev="$a"
done
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
# `local TZ=UTC` shipped for months and is a no-op only when TZ is UNSET: with
# TZ exported, bash's `local` inherits the export and the value does reach
# libc, so SETTING TZ here would test nothing. Unset is the ordinary state of
# a login shell and of cron. Case 2 above pinned the SHAPE, always right.
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
printf 'NO-DECISION: @zach nothing to weigh\nline\n\n<!-- DEFERRED -->\n- none\n<!-- /DEFERRED -->\n\n<!-- DELIVERS -->\n- none\n<!-- /DELIVERS -->\n\n\n' > "$TMP/body.txt"
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

# --- 9b. A SECOND COPY, NOT THE SAME INODE, IS STILL NOT "real gh" ---------
# The production shape: a checkout run as `bash bin/gh-sign.sh` while
# /usr/local/bin/gh is a DISTINCT installed copy of the same script. `-ef`
# says "different file" for two copies, so without the content check this
# shim picked the installed copy as "real gh" -- a double hop whose second
# layer `cat`s an already-drained stdin and posts a blank body.
mkdir -p "$TMP/installed"
cp "$GS" "$TMP/installed/gh"; chmod +x "$TMP/installed/gh"
reset
out="$(GH_LOG="$TMP/gh.log" GH_LAST_BODY="$TMP/gh.body" \
       PATH="$TMP/installed:$TMP/stub:$PATH" "$BASH_BIN" "$GS" \
       issue comment 7 --repo hf7y/widget --body-file - <<<'two copies on PATH' 2>&1)"
contains "a second on-disk copy of the shim is never mistaken for real gh" \
      "$(cat "$TMP/gh.body")" "two copies on PATH"
check "...and the real gh is invoked exactly once, not looped through both copies" \
      "$(grep -c . "$TMP/gh.log")" "1"

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

# A MONTH-OLD BUILD IS NOT STALE UNDER A MONTHLY CUT (#603). At STALE_DAYS=14
# this stamped STALE into every signed body for ~16 of every 30 days and exited
# 1 from --self-check the whole time -- so the marker meant "it is the 15th",
# not "the channel stopped". 30 days is a healthy build mid-interval.
MONTHOLD="$(mkbuild "$(date -u -d '-30 days' +%Y-%m-%dT%H%MZ)")"
out="$(GH_SIGN_BUILD_ROOTS="$TMP/builds" PATH="$TMP/stub:$PATH" "$BASH_BIN" "$MONTHOLD" --stamp)"
hasnt "a 30-day build under a monthly cadence is not marked stale" "$out" "STALE"
GH_SIGN_BUILD_ROOTS="$TMP/builds" PATH="$TMP/stub:$PATH" "$BASH_BIN" "$MONTHOLD" --self-check >/dev/null 2>&1
check "...and --self-check does not page for it" "$?" "0"

# The seam is an env override, because the number has to track a cadence this
# script deliberately does not read at runtime.
out="$(GH_SIGN_STALE_DAYS=7 GH_SIGN_BUILD_ROOTS="$TMP/builds" PATH="$TMP/stub:$PATH" "$BASH_BIN" "$MONTHOLD" --stamp)"
contains "GH_SIGN_STALE_DAYS moves the threshold" "$out" "STALE"

reset
out="$(GH_SIGN_BUILD_ROOTS="$TMP/builds" GH_LOG="$TMP/gh.log" GH_LAST_BODY="$TMP/gh.body" \
       PATH="$TMP/stub:$PATH" "$BASH_BIN" "$STALE" issue comment 7 --repo hf7y/w --body hi 2>&1 >/dev/null)"
contains "a stale shim announces itself at the write" "$out" "STALE"
check "...and still writes: fail open outlives the expiry" \
      "$(grep -c 'issue comment 7' "$TMP/gh.log")" "1"

out="$(GH_SIGN_BUILD_ROOTS="$TMP/builds" PATH="$TMP/stub:$PATH" "$BASH_BIN" "$GS" --stamp)"
contains "a copy that is in no build says so rather than claiming freshness" "$out" "unbuilt"

# --- 11. WHO IS AT THE KEYBOARD, not which host (scheduler#147) ------------
# Host was a proxy for actor, so an agent comment from mandark was read as
# Zach ANSWERING. Cron signs, an agent signs, a human does not.
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

# The human path needs a pty. The skip is said out loud: an assertion that
# quietly does not run is worse than none.
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

# --- `gh api` is the same write by another route (decision-rot's KNOWN GAP)
reset
printf 'a reply body\n' > "$TMP/reply.md"
run api -X POST repos/hf7y/widget/issues/7/comments -F body=@"$TMP/reply.md" >/dev/null 2>&1
case "$(lastline)" in
  '<!-- agent: '*) ok "an api comment posted from a file is stamped" ;;
  *) bad "api comment (file) unstamped" "got: $(lastline)" ;;
esac
check "...and the real gh is invoked exactly once" "$(grep -c . "$TMP/gh.log")" "1"
contains "...as a stdin field, so a long body cannot hit ARG_MAX" "$(cat "$TMP/gh.log")" "body=@-"

reset
run api -X POST repos/hf7y/widget/issues/7/comments -f body="inline reply" >/dev/null 2>&1
case "$(lastline)" in
  '<!-- agent: '*) ok "an api comment passed inline is stamped" ;;
  *) bad "api comment (inline) unstamped" "got: $(lastline)" ;;
esac
contains "...the original text survives, not the literal @- placeholder" "$(cat "$TMP/gh.body")" "inline reply"
# `-f` has no `@` magic; a body written back as `-f body=@-` would arrive as
# the four literal characters `@-`. The shim must upgrade the flag to `-F`.
contains "...and the flag was upgraded from -f to -F for the write-back" "$(cat "$TMP/gh.log")" " -F body=@-"

reset
run api -X POST repos/hf7y/widget/pulls/7/comments -f body="pr reply" >/dev/null 2>&1
case "$(lastline)" in
  '<!-- agent: '*) ok "a pull-request api comment is stamped too" ;;
  *) bad "pr api comment unstamped" "got: $(lastline)" ;;
esac
contains "...with the pr reply text intact" "$(cat "$TMP/gh.body")" "pr reply"

reset
run api repos/hf7y/widget --jq .name >/dev/null 2>&1
contains "a non-comment api call reaches gh unchanged" "$(cat "$TMP/gh.log")" "repos/hf7y/widget"
case "$(cat "$TMP/gh.body" 2>/dev/null)" in
  '') ok "...and nothing was signed into it" ;;
  *) bad "a read was given a body" "got: $(cat "$TMP/gh.body")" ;;
esac

GOOD='NO-DECISION: nothing to weigh

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->

<!-- DELIVERS -->
- none
<!-- /DELIVERS -->'

reset
printf '%s\n' "$GOOD" > "$TMP/good.txt"
run --check-body "$TMP/good.txt" >/dev/null 2>&1
check "a well-formed body checks clean (0)" "$?" "0"

reset
printf 'no declaration line at all\n' > "$TMP/bad.txt"
run --check-body "$TMP/bad.txt" >/dev/null 2>&1
check "--check-body FOUND something (1); it was asked to look, not to write" "$?" "1"
case "$(cat "$TMP/gh.log")" in
  '') ok "...and it created nothing to refuse" ;;
  *) bad "--check-body reached gh" "got: $(cat "$TMP/gh.log")" ;;
esac
DELIVERS_NO_RETIRES='NO-DECISION: nothing to weigh

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->

<!-- DELIVERS -->
- path:bin/new.sh -- the replacement
<!-- /DELIVERS -->'

reset
run pr create --title t --body "$DELIVERS_NO_RETIRES" >/dev/null 2>&1
check "a PR that delivers and declares no retirement is REFUSED (7) (#754)" "$?" "7"
reset
run issue create --title t --body "$DELIVERS_NO_RETIRES" >/dev/null 2>&1
check "the same body as an ISSUE is fine -- an issue retires nothing" "$?" "0"

reset
run pr create --title t --body 'no declaration line at all' >/dev/null 2>&1
check "a write the shim DECLINES to make is REFUSED (7)" "$?" "7"
case "$(cat "$TMP/gh.log")" in
  '') ok "...and nothing reached gh, so the refusal cost no write" ;;
  *) bad "the refused write reached gh" "got: $(cat "$TMP/gh.log")" ;;
esac

# --- 12. --delivers: WHERE a change lands, derived, not asserted -----------
# #521 shipped this actuator with no test at all, which is how it went on
# answering `- none` for three files that deploy to every provisioned host.
# The contract has TWO readers -- prop_channel for the class, prop_host_tools
# for what rides to libexec by name -- and reading only the first is the bug.
R="$TMP/deliv"; mkdir -p "$R/bin"
git -C "$R" init -q
git -C "$R" -c user.email=t@t -c user.name=t commit -q --allow-empty -m base
deliv() { # <path-that-changed> -- graded against the commit before it alone
  local base; base="$(git -C "$R" rev-parse HEAD)"
  mkdir -p "$R/$(dirname "$1")"; : > "$R/$1"
  git -C "$R" add -A >/dev/null 2>&1
  git -C "$R" -c user.email=t@t -c user.name=t commit -q -m "change $1" >/dev/null 2>&1
  ( cd "$R" && GH_SIGN_BASE="$base" "$BASH_BIN" "$GS" --delivers 2>&1 )
}
contains "a LOCAL-class probe names its libexec path, not '- none'" \
  "$(deliv bin/ausculte-cadence.sh)" "- path:/usr/local/libexec/selfdev/ausculte-cadence.sh on monkey"
contains "a payload script names its VERB, not its basename" \
  "$(deliv bin/gh-sign.sh)" "- path:/usr/local/bin/gh on monkey"
contains "a file that leaves the repo nowhere still says '- none'" \
  "$(deliv README.md)" "- none"

# --- 13. --default-after: one home for the grammar, on every account's PATH --
# scheduler must read DEFAULT-AFTER at dispatch. It must not reach into a
# realisateur build path for lib/body-grammar.sh, and it must not carry a
# second copy of the parser. The shim already owns the body grammar and is
# already on PATH everywhere, so it answers.
reset
printf 'DECISION: @zach -- q\nDEFAULT-AFTER 14d: close it as declined\n' > "$TMP/da.txt"
out="$(run --default-after "$TMP/da.txt" 2>&1)"; rc=$?
check "a well-formed default exits 0" "$rc" "0"
check "...and prints days TAB action, for a caller to read" "$out" "$(printf '14\tclose it as declined')"

printf 'DECISION: @zach -- an irreversible call\n' > "$TMP/none.txt"
run --default-after "$TMP/none.txt" >/dev/null 2>&1
check "no default exits 1 -- BLOCKS FOREVER is an answer, not an error" "$?" "1"

# 1 and 6 must never be confused: "this blocks on purpose" vs "I could not read
# the grammar". Folding them is how a BLIND probe gets reported as a verdict.
GH_SIGN_LIB="$TMP/nolib" run --default-after "$TMP/da.txt" >/dev/null 2>&1
check "an unreadable grammar is BLIND (6), never 1" "$?" "6"

case "$(cat "$TMP/gh.log")" in
  '') ok "...and none of it reached gh -- reading a body costs no write" ;;
  *) bad "--default-after reached gh" "got: $(cat "$TMP/gh.log")" ;;
esac

# --- the refusal teaches at BOTH ends (#627) --------------------------------
: > "$TMP/gh.log"
printf 'DECISION: @zach -- no blocks at all\n' > "$TMP/bad.txt"
out="$(run issue create --title t --body "$(cat "$TMP/bad.txt")" -R o/r 2>&1)"; rc=$?
check "a body breaking the grammar is REFUSED (7)" "$rc" "7"

head3="$(printf '%s\n' "$out" | head -3)"
case "$head3" in
  *defere*) ok "the FIRST lines name the door -- \`defere\` composes a valid body" ;;
  *) bad "the head names the door" "got: $head3" ;;
esac
case "$head3" in
  *--check-body*) ok "...and how to check one by hand" ;;
  *) bad "the head names --check-body" "got: $head3" ;;
esac

tail3="$(printf '%s\n' "$out" | tail -3)"
case "$tail3" in
  *UNLEDGERED*|*UNSHIPPED*) ok "the LAST lines are the finding, so \`tail\` sees what is wrong" ;;
  *) bad "the tail is the finding" "got: $tail3" ;;
esac
case "$tail3" in
  *'hf7y/'*'#'*) bad "the tail carries no issue reference" "an example ref is back at the tail: $tail3" ;;
  *) ok "...and no issue reference, which is what read as another repo's state" ;;
esac

case "$out" in
  *"an illustration, NOT state of any repo"*) ok "the example says outright that it is one" ;;
  *) bad "the example is labelled" "no fence header in the refusal" ;;
esac
_egrep="$(printf '%s\n' "$out" | grep -c 'hf7y/chezz#12\|hf7y/realisateur#330' || true)"
[ "${_egrep:-0}" -eq 0 ] \
  && ok "the example carries placeholders, not real issue numbers" \
  || bad "the example uses placeholders" "real refs are back in it"

case "$(cat "$TMP/gh.log")" in
  '') ok "...and nothing reached gh -- a refusal creates nothing" ;;
  *) bad "the refusal reached gh" "got: $(cat "$TMP/gh.log")" ;;
esac

echo
summary
