#!/usr/bin/env bash
# carried-lints-witness.sh -- the lints carried onto this branch actually work
# here, with no realisateur checkout.
#
# HERMETICITY: full. Runs the carried scripts from a directory that is not a
# checkout and asserts only on their argument handling, never on findings --
# what they report depends on the estate, whether they can be INVOKED does not.
#
# THE FAILURE THIS EXISTS FOR, made while writing the carry: the libs were
# copied to lib/ when every script sources bin/lib/. `. missing-file` does not
# abort under `set -uo pipefail`, so cli_guard was simply never defined,
# execution fell through the guard, and `--help` exited 3 (BLIND) instead of 0
# while printing a registry error. A silently ungated script that still looks
# like it ran is the exact shape a carry can introduce and a reader cannot see.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="$HERE/../bin"
pass=0; fail=0
ok()  { printf '  PASS: %s\n' "$*"; pass=$((pass+1)); }
bad() { printf '  FAIL: %s\n' "$*"; fail=$((fail+1)); }
echo "carried-lints-witness"

CARRIED="precipitation-scan hygiene-lint reach-lint closeout-lint"
OUT="$(mktemp -d)"; trap 'rm -rf "$OUT"' EXIT

# --- 1. the libs are where the scripts look for them ----------------------
for l in cli-guard.sh conf.sh; do
  [ -r "$BIN/lib/$l" ] && ok "bin/lib/$l is present" \
    || bad "bin/lib/$l missing -- sourcing it fails SILENTLY and every guard goes undefined"
done

# --- 2. --help works from somewhere that is not a checkout ----------------
# Run from a temp dir so nothing resolves by accident of cwd.
for s in $CARRIED; do
  [ -x "$BIN/$s.sh" ] || { bad "$s.sh is not carried or not executable"; continue; }
  ( cd "$OUT" && timeout 30 bash "$BIN/$s.sh" --help >/dev/null 2>&1 )
  rc=$?
  [ "$rc" -eq 0 ] && ok "$s --help exits 0 with no checkout" \
    || bad "$s --help exited $rc -- help must never depend on the estate"
done

# --- 3. THE GUARD IS LIVE, not merely quiet -------------------------------
# The load-bearing case. If cli_guard were undefined again, --help would still
# reach the usage text by luck in some scripts, but a bad flag would sail
# through. Rejecting one proves the guard actually ran.
for s in $CARRIED; do
  ( cd "$OUT" && timeout 30 bash "$BIN/$s.sh" --nonsense-flag >/dev/null 2>&1 )
  rc=$?
  [ "$rc" -eq 2 ] && ok "$s rejects an unknown flag (exit 2) -- cli_guard is defined" \
    || bad "$s returned $rc for a bad flag, want 2 -- the guard is not running"
done

printf '\ncarried-lints-witness: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
