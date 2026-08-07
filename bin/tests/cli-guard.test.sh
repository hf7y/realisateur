#!/usr/bin/env bash
# HERMETICITY: it runs the argument guard and nothing else. Every case either
# invokes a throwaway script written into `mktemp -d` that sources
# bin/lib/cli-guard.sh and then prints its own argv, or invokes a real bin/
# script in a mode that stops at the parser (`--dry-run`, `--help`, a refusal).
# Nothing here reaches the network, no verdict is published, no file outside
# the temp dir is written, and $HOME is redirected into the sandbox so a real
# ~/.config on the machine running this cannot leak in.
#
# cli-guard.test.sh -- the argument contract, tested at the place it broke.
#
# ============================================================================
# WHY THIS SUITE EXISTS
# ============================================================================
#
# bin/lib/cli-guard.sh is sourced by most of bin/ and had no suite of its own.
# It was covered only incidentally -- each caller's suite asserts "an unknown
# flag exits 2", which is the case the library gets right. The case it got
# WRONG was invisible to all of them, because none of them ever passed a VALUE
# that begins with a dash.
#
# THE FAILURE, measured 2026-08-07 on the first real gated cut:
#
#   $ publish-release-verdict.sh --decision NO_CHANGE --reason x --build-id -
#   publish-release-verdict.sh: unknown flag: -
#   exit 2
#
# cli_guard walks every element of argv, values included. `-` is the
# publisher's OWN documented sentinel for "no build id" and its own default
# for that field, and build-verbs.yml passes exactly that on every night that
# does not cut: `--build-id "${CUT_BUILD:--}"`. Those are precisely the
# BLOCKED / ERROR / NO_CHANGE nights the verdict channel was built to make
# visible. So the channel published NOTHING on the one night it mattered, the
# endpoint kept serving the previous CUT verdict, and the consumer
# (release-ledger.sh, via selfdev-release-tick.sh) graded a broken release
# gate as "release channel healthy (verdict fresh, no blocked streak)".
#
# A library used by fourteen scripts with no suite of its own is how one arm
# of one `case` takes down a channel. This file is that suite.
#
# Usage: bin/tests/cli-guard.test.sh   (exit 0 = all pass)
set -uo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
GUARD="$REPO/bin/lib/cli-guard.sh"
PUB="$REPO/bin/publish-release-verdict.sh"
LED="$REPO/bin/release-ledger.sh"
[ -f "$GUARD" ] || { echo "FAIL: $GUARD is missing"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/home"
pass=0; fail=0
ok()  { echo "  ok   $1"; pass=$((pass+1)); }
bad() { echo "  FAIL $1"; fail=$((fail+1)); }
has()   { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1 (missing: $3)" ;; esac; }
hasnt() { case "$2" in *"$3"*) bad "$1 (unexpectedly present: $3)" ;; *) ok "$1" ;; esac; }
rc()    { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected exit $2, got $3)"; fi; }

# A throwaway caller. It declares the same four CLI_* variables every real
# caller does, guards its argv, and then prints it back -- so an assertion can
# say both "the guard let this through" and "it did not consume anything".
mkcaller() { # mkcaller <file> <CLI_FLAGS> <CLI_POSITIONAL>
  cat > "$1" <<EOF
#!/usr/bin/env bash
set -uo pipefail
CLI_NAME='fixture.sh'
CLI_SUMMARY='a fixture that only parses'
CLI_USAGE='  fixture.sh [flags]'
CLI_FLAGS='$2'
CLI_POSITIONAL=$3
. "$GUARD"
cli_guard "\$@"
printf 'ARGV:'; printf ' [%s]' "\$@"; printf '\n'
EOF
  chmod +x "$1"
}
mkcaller "$T/any.sh"  '--decision --build-id' any
mkcaller "$T/none.sh" '--verbose'             none

run() { env HOME="$T/home" "$@" 2>&1; }

echo "cli-guard.test.sh"

# ===========================================================================
echo
echo "-- THE REGRESSION: A BARE '-' IS A VALUE, NOT A FLAG -------------------"
# ===========================================================================
# This is the case that silenced the release channel. It fails on the code as
# it stood at b3fef3d with `unknown flag: -`, exit 2.
O="$(run bash "$T/any.sh" --decision NO_CHANGE --build-id -)"; R=$?
rc   "a bare '-' as a flag VALUE is accepted (CLI_POSITIONAL=any)" 0 "$R"
hasnt "it is not reported as an unknown flag" "$O" "unknown flag: -"
has  "the guard consumes nothing: argv still carries the '-'" "$O" "[-]"

# A bare `-` on its own, with no flag in front of it, is the same value class.
run bash "$T/any.sh" - >/dev/null; rc "a bare '-' alone is accepted where positionals are" 0 $?

# ...and it is NOT waved through where the script takes no arguments. A guard
# that gets laxer to fix a bug has traded one silent misparse for another.
O="$(run bash "$T/none.sh" -)"; R=$?
rc  "a bare '-' still exits 2 when CLI_POSITIONAL=none" 2 "$R"
has "the refusal names '-' itself rather than calling it an unknown flag" "$O" "unexpected argument: '-'"

# Everything else that starts with a dash is unchanged. These are the cases
# the `-*)` arm exists for and none of them may be softened by the fix above.
O="$(run bash "$T/any.sh" --nope)"; R=$?
rc  "an unknown long flag still exits 2" 2 "$R"
has "and still names itself" "$O" "unknown flag: --nope"
run bash "$T/any.sh" -x  >/dev/null; rc "an unknown short flag still exits 2" 2 $?
run bash "$T/any.sh" --  >/dev/null; rc "'--' is still refused"              2 $?
run bash "$T/any.sh" -s  >/dev/null; rc "the --summon near-miss still exits 2" 2 $?
run bash "$T/any.sh" --summon >/dev/null; rc "--summon is still refused"     2 $?
O="$(run bash "$T/any.sh" --help)"; R=$?
rc  "--help still exits 0" 0 "$R"
has "--help still prints the flag list" "$O" "--build-id"

# ===========================================================================
echo
echo "-- THE REAL INVOCATION, BUILT THE WAY build-verbs.yml BUILDS IT --------"
# ===========================================================================
# Not a paraphrase. `--build-id "${CUT_BUILD:--}"` with CUT_BUILD unset is
# literally `--build-id -`, and this is the line the nightly workflow runs on
# every night that cuts nothing. Testing the paraphrase is how the original
# bug survived: the publisher HAD a suite and the suite never passed a `-`.
WF="$REPO/provision/verbs-meta/build-verbs.yml"
has "the workflow still passes the no-build sentinel this way" \
    "$(cat "$WF" 2>/dev/null || true)" '${CUT_BUILD:--}'

CUT_BUILD=''
O="$(run bash "$PUB" --dry-run --decision NO_CHANGE \
      --reason "gate green, no project moved" \
      --main-sha abc1234 --ci-run 99 --build-id "${CUT_BUILD:--}")"; R=$?
rc   "the publisher accepts a BLOCKED/NO_CHANGE night's argv" 0 "$R"
hasnt "it does not die on the sentinel" "$O" "unknown flag"
has  "it renders the verdict it was asked for" "$O" "NO_CHANGE"

for d in BLOCKED ERROR; do
  run bash "$PUB" --dry-run --decision "$d" --reason "the gate refused" \
      --main-sha abc1234 --ci-run 99 --build-id "${CUT_BUILD:--}" >/dev/null
  rc "the publisher accepts a $d night's argv (build id is the sentinel)" 0 $?
done

# The consumer's emitter half takes the same sentinel on the same field.
run bash "$LED" --ledger "$T/l.tsv" --append --decision BLOCKED \
    --reason "main RED" --build-id "${CUT_BUILD:--}" >/dev/null
rc "release-ledger --append accepts the same sentinel" 0 $?

# ===========================================================================
echo
echo "-- THE CONTRACT THE LIBRARY EXISTS TO ENFORCE, STILL ENFORCED ----------"
# ===========================================================================
# bin/lib/cli-guard.sh's header states these as the shapes it closes. They are
# asserted here so a future fix to the parser cannot quietly reopen one.
O="$(run bash "$T/none.sh" hello)"; R=$?
rc  "an unexpected positional exits 2 where none are accepted" 2 "$R"
has "and says the tool takes no positional arguments" "$O" "no positional arguments"
O="$(run bash "$T/any.sh" --help)"
has "--help states the tool cannot spend" "$O" "cannot spend"

echo
echo "cli-guard.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
