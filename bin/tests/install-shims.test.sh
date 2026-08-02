#!/usr/bin/env bash
# install-shims.test.sh -- the symlink-at-install-target case.
#
# Regression test for the 2026-08-01 incident: a hand-made symlink at an
# install target made install_file() write THROUGH it and destroy this repo's
# own bin/silence-audit.sh, replacing it with a shim that exec'd itself.
# The run printed "written silence-audit" and exited 0.
#
# The load-bearing assertion is D1: THE CANARY IS UNCHANGED. Everything else
# is scaffolding. A version of this file that only checked "the target is a
# regular file afterwards" would have passed against the broken code, because
# the broken code did leave a regular file there -- it just wrote it to the
# wrong inode first.
#
# usage: ./bin/tests/install-shims.test.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SHIMS="$REPO/bin/install-shims.sh"
pass=0; fail=0
ok()   { printf '  ok   %s\n' "$*"; pass=$((pass+1)); }
bad()  { printf '  FAIL %s\n' "$*"; fail=$((fail+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

printf -- '-- D. symlink at install target (2026-08-01 regression)\n'

# A stand-in for a real repo source file. If install-shims writes through a
# symlink, this is what gets destroyed.
CANARY="$WORK/canary-source.sh"
printf '#!/usr/bin/env bash\n# CANARY -- must survive verbatim\necho canary\n' > "$CANARY"
CANARY_SUM="$(md5sum < "$CANARY")"

run_shims() {
  BIN_DEST="$WORK/bin" CMD_DEST="$WORK/cmds" bash "$SHIMS" "$@" >"$WORK/out" 2>"$WORK/err"
  printf '%s' "$?"
}

# --- D1/D2: install mode replaces the symlink and leaves the canary alone ---
mkdir -p "$WORK/bin" "$WORK/cmds"
ln -sfn "$CANARY" "$WORK/bin/silence-audit"
rc="$(run_shims)"

check "D1 canary file is byte-identical after install" "$(md5sum < "$CANARY")" "$CANARY_SUM"
if [ -L "$WORK/bin/silence-audit" ]; then
  bad "D2 install target is no longer a symlink"
else
  [ -f "$WORK/bin/silence-audit" ] && ok "D2 install target is a regular file" \
                                   || bad "D2 install target is a regular file (missing)"
fi

if grep -q 'was a symlink' "$WORK/out" "$WORK/err" 2>/dev/null; then
  ok "D3 the replacement was announced, not silent"
else
  bad "D3 the replacement was announced, not silent"
fi

# The canary is not a shim, so the installed file must not exec it.
if grep -q "$CANARY" "$WORK/bin/silence-audit" 2>/dev/null; then
  bad "D4 installed shim does not point back at the symlink's old target"
else
  ok "D4 installed shim does not point back at the symlink's old target"
fi

check "D5 install exits 0 once healed" "$rc" "0"

# --- D6/D7: --check must REFUSE rather than heal, and must not write ---
rm -rf "$WORK/bin" "$WORK/cmds"; mkdir -p "$WORK/bin" "$WORK/cmds"
ln -sfn "$CANARY" "$WORK/bin/silence-audit"
rc="$(run_shims --check)"

check "D6 --check exits nonzero on a symlinked target" "$([ "$rc" != 0 ] && echo yes || echo no)" "yes"
if [ -L "$WORK/bin/silence-audit" ]; then
  ok "D7 --check left the symlink in place (did not heal)"
else
  bad "D7 --check left the symlink in place (did not heal)"
fi
check "D8 --check did not touch the canary" "$(md5sum < "$CANARY")" "$CANARY_SUM"

printf -- '\n--- install-shims symlink guard: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
