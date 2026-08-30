#!/usr/bin/env bash
#   exit 2
#
# Usage: bin/tests/cli-guard.test.sh   (exit 0 = all pass)

set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
GUARD="$REPO/bin/lib/cli-guard.sh"
PUB="$REPO/bin/publish-release-verdict.sh"
LED="$REPO/bin/release-ledger.sh"
[ -f "$GUARD" ] || { echo "FAIL: $GUARD is missing"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/home"

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
run bash "$T/any.sh" -s  >/dev/null; rc "-s is an unknown short flag, exit 2" 2 $?
run bash "$T/any.sh" --summon >/dev/null; rc "--summon is an unknown flag now, exit 2" 2 $?
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
has "--help states the usage exit without a retired cost flag" "$O" "unknown flag or unexpected argument"

echo
summary
