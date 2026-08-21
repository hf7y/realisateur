#!/usr/bin/env bash
# RUNNER: operator -- needs passwordless root; no self-dev account has that
# GUARD-TEST: bin/tests/selfdev-containment-audit.test.sh
# GATE: none -- same reason
set -uo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"

CLI_NAME='selfdev-containment-audit.sh'
CLI_SUMMARY='does any self-dev account (uid 3000-3099) own a file outside its own home, or appear in /etc/sudoers.d?'
CLI_USAGE='  selfdev-containment-audit.sh            probe, report, exit on the worst finding
  selfdev-containment-audit.sh --quiet    only the summary line'
CLI_FLAGS='--quiet'
CLI_POSITIONAL=none
CLI_EXITS='  0  contained -- no self-dev account owns a file outside its own home, and
     none appears in /etc/sudoers.d
  1  FINDING -- at least one account has broken containment
  6  BLIND -- root was not available, or the passwd database could not be
     read. NEVER 0: a scan that could not enter another account'"'"'s home is
     not evidence the home is clean.'
. "$ROOT/bin/lib/cli-guard.sh"
cli_guard "$@"

QUIET=0
for a in "$@"; do
  case "$a" in
    --quiet) QUIET=1 ;;
    *) echo "$CLI_NAME: unknown flag $a" >&2; exit 2 ;;
  esac
done

CA_SUDO="${CA_SUDO:-sudo}"
CA_GETENT="${CA_GETENT:-getent passwd}"
CA_SCAN_ROOT="${CA_SCAN_ROOT:-/home}"
CA_SUDOERS_DIR="${CA_SUDOERS_DIR:-/etc/sudoers.d}"
CA_UID_MIN="${CA_UID_MIN:-3000}"
CA_UID_MAX="${CA_UID_MAX:-3099}"

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

say "selfdev-containment-audit -- $(date -u +%Y-%m-%d 2>/dev/null || echo unknown)"

if ! $CA_SUDO -n true 2>/dev/null; then
  say "  BLIND  no passwordless root -- cannot enumerate other accounts' files or read $CA_SUDOERS_DIR"
  echo "selfdev-containment-audit: BLIND -- run as an operator with passwordless sudo, or not at all." >&2
  exit 6
fi

passwd_out="$($CA_GETENT 2>/dev/null)"
if [ -z "$passwd_out" ]; then
  say "  BLIND  $CA_GETENT returned nothing -- no account database to read"
  echo "selfdev-containment-audit: BLIND -- passwd database unreadable." >&2
  exit 6
fi

accounts="$(awk -F: -v lo="$CA_UID_MIN" -v hi="$CA_UID_MAX" \
  '$3 >= lo && $3 <= hi { print $1"\t"$3"\t"$6 }' <<<"$passwd_out")"
if [ -z "$accounts" ]; then
  say "  BLIND  no account in uid $CA_UID_MIN-$CA_UID_MAX -- the self-dev band is empty or unreadable"
  echo "selfdev-containment-audit: BLIND -- no self-dev accounts found to audit." >&2
  exit 6
fi

findings=0

say "  homebound: scanning $CA_SCAN_ROOT for cross-account file ownership..."
while IFS=$'\t' read -r name uid home; do
  [ -n "$name" ] || continue
  out="$($CA_SUDO -n find "$CA_SCAN_ROOT" -xdev -uid "$uid" -not -path "${home}/*" -not -path "${home}" 2>/dev/null)"
  if [ -n "$out" ]; then
    n="$(printf '%s\n' "$out" | grep -c .)"
    say "    FAIL  $name (uid $uid) owns $n file(s) outside $home:"
    printf '%s\n' "$out" | head -10 | sed 's/^/      /'
    [ "$n" -gt 10 ] && say "      ... and $((n - 10)) more"
    findings=$((findings + 1))
  fi
done <<<"$accounts"
[ "$findings" -eq 0 ] && say "    PASS  no self-dev account owns a file outside its own home"

say "  nosudoers: reading $CA_SUDOERS_DIR for self-dev account references..."
sudoers_files="$($CA_SUDO -n sh -c "ls -1 '$CA_SUDOERS_DIR' 2>/dev/null" 2>/dev/null)"
sudoers_hit=0
if [ -n "$sudoers_files" ]; then
  while IFS=$'\t' read -r name uid home; do
    [ -n "$name" ] || continue
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      if $CA_SUDO -n sh -c "grep -qE '(^|[^A-Za-z0-9_-])$(printf '%s' "$name" | sed 's/[.[\*^$]/\\&/g')([^A-Za-z0-9_-]|\$)' '$CA_SUDOERS_DIR/$f'" 2>/dev/null; then
        say "    FAIL  $name (uid $uid) referenced in $CA_SUDOERS_DIR/$f"
        findings=$((findings + 1))
        sudoers_hit=$((sudoers_hit + 1))
      fi
    done <<<"$sudoers_files"
  done <<<"$accounts"
fi
[ "$sudoers_hit" -eq 0 ] && say "    PASS  no self-dev account referenced in $CA_SUDOERS_DIR"

say
if [ "$findings" -gt 0 ]; then
  say "selfdev-containment-audit: $findings finding(s) -- containment is broken."
  exit 1
fi
say "selfdev-containment-audit: contained -- no self-dev account reaches outside itself."
exit 0
