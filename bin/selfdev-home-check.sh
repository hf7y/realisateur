#!/usr/bin/env bash
# RUNNER: bin/tests/selfdev-home-check.test.sh
# GUARD-TEST: bin/tests/selfdev-home-check.test.sh
# GATE: strict
set -uo pipefail  # selfdev-home-check.sh -- a self-dev account's home should hold a declared set and nothing else (#967, Zach: "realistically there shouldn't be any files in a user's account outside a whitelist. That's something we can just check."). REPORTS ONLY -- a stray copy of a host tool is its own finding (#886's shape), never quietly cleared.

CLI_NAME='selfdev-home-check.sh'
CLI_SUMMARY="does a self-dev account's home hold anything outside the declared set?"
CLI_USAGE='  selfdev-home-check.sh                report every self-dev account, change nothing
  selfdev-home-check.sh <account>...   report named account(s) only
  selfdev-home-check.sh --strict       exit 1 if any account holds anything outside the set'
CLI_FLAGS='--strict'
CLI_POSITIONAL=any
CLI_EXITS='  0  every checked account holds only the declared set (or no --strict was given)
  1  --strict was given and at least one account holds something outside it
  6  BLIND -- no self-dev account was found under HOME_ROOT, or a named
     account has no home at all, or a home could not be listed. NEVER 0.'
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

HOME_ROOT="${HOME_ROOT:-/home}"
SUDO="${SUDO-sudo}"
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

DECLARED=(Documents tmp reports)   # near enough already per the 2026-09-03 sweep; tmp is the account's own TMPDIR (#620) and is never flagged. Non-hidden, top level only -- dotfiles are the account's own infrastructure, out of scope.

host_tool_names() {   # a name matching a script this checkout carries is an unmanaged copy of a host tool, not ordinary residue -- reported on its own line per #967
  find "$HERE" -maxdepth 1 -type f \( -name '*.sh' -o -perm -u+x \) -printf '%f\n' 2>/dev/null | sort -u
}
HOST_TOOLS="$(host_tool_names)"

STRICT=0
ACCOUNTS_WANT=()
for a in "$@"; do
  case "$a" in
    --strict) STRICT=1 ;;
    *) ACCOUNTS_WANT+=("$a") ;;
  esac
done

ACCOUNTS=()
if [ "${#ACCOUNTS_WANT[@]}" -gt 0 ]; then
  ACCOUNTS=("${ACCOUNTS_WANT[@]}")
else
  for d in "$HOME_ROOT"/*/; do   # DERIVED from which homes carry a .claude dir, same rule selfdev-permissions-provision.sh uses -- a typed list is what produced the 2026-07-27 shim gap
    u="$(basename "$d")"
    [ "$u" = "zach" ] && continue   # the human's own account is not a self-dev account
    $SUDO test -d "$d/.claude" 2>/dev/null || continue
    ACCOUNTS+=("$u")
  done
fi

[ "${#ACCOUNTS[@]}" -gt 0 ] || {
  echo "$CLI_NAME: BLIND -- no self-dev account found under $HOME_ROOT" >&2
  exit 6
}

declared_has() { local n="$1" want; for want in "${DECLARED[@]}"; do [ "$want" = "$n" ] && return 0; done; return 1; }
is_host_tool()  { printf '%s\n' "$HOST_TOOLS" | grep -qxF "$1"; }

echo "selfdev-home-check -- $(date '+%Y-%m-%d %H:%M'), declared set: ${DECLARED[*]}"
echo

blind=0; findings=0; okc=0
for u in "${ACCOUNTS[@]}"; do
  d="$HOME_ROOT/$u"
  if ! $SUDO test -d "$d" 2>/dev/null; then
    echo "  BLIND $u: no home at $d"; blind=$((blind + 1)); continue
  fi
  if ! listing="$($SUDO ls "$d" 2>&1)"; then
    echo "  BLIND $u: home not readable ($listing)"; blind=$((blind + 1)); continue
  fi

  toolrows=(); residuerows=()
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    declared_has "$n" && continue
    if is_host_tool "$n"; then toolrows+=("$n"); else residuerows+=("$n"); fi
  done <<<"$listing"

  if [ "${#toolrows[@]}" -eq 0 ] && [ "${#residuerows[@]}" -eq 0 ]; then
    echo "  ok    $u"; okc=$((okc + 1)); continue
  fi
  findings=$((findings + 1))
  [ "${#toolrows[@]}" -gt 0 ] && \
    echo "  TOOL  $u: unmanaged copy of a host tool, not the pinned build: ${toolrows[*]}"
  [ "${#residuerows[@]}" -gt 0 ] && \
    echo "  DRIFT $u: outside the declared set: ${residuerows[*]}"
done

echo
echo "== $okc clean, $findings with something outside the declared set, $blind BLIND, out of ${#ACCOUNTS[@]} account(s) =="

[ "$blind" -eq 0 ] || { echo "$CLI_NAME: $blind account(s) unreadable -- counts above are NOT trustworthy."; exit 6; }
[ "$STRICT" = 1 ] && [ "$findings" -gt 0 ] && exit 1
exit 0
