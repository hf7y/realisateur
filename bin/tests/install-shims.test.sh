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

# REPO IS PASSED, AND THAT IS THE WHOLE POINT OF THIS FUNCTION.
#
# Until 2026-08-07 this passed only BIN_DEST and CMD_DEST. install-shims.sh
# does not self-locate on purpose (see its header), so with REPO unset it fell
# back to bin/install-shims.sh:40 --
#     REPO="${REPO:-${INSTALLE_PROJECTS:-$HOME/Documents/Projects}/realisateur}"
# -- the LIVE SHARED CHECKOUT. On a developer machine that path exists, so
# section D passed by auditing whatever was checked out at ~/Documents/
# Projects/realisateur rather than the branch this file lives on. A green D
# was never evidence about this branch's code, and could not go red for a
# defect introduced on it. In a container the path is absent and the script
# exits 5 -- which is how the workflow surfaced it (D2, D3, D5).
# HOOK_DEST and CLAUDE_SETTINGS are redirected too, and they are not optional.
# Passing REPO is what makes this run reach install-shims.sh's hook section at
# all; before that it died at the checkout check, so the two missing overrides
# were inert. With REPO passed and them unset, a test asserting things about a
# temp directory would install into the REAL ~/.claude/hooks and read the real
# settings.json -- the exact live-machine write install-shims.sh:72 says these
# overrides exist to prevent, reintroduced by fixing a different line.
run_shims() {
  REPO="$REPO" BIN_DEST="$WORK/bin" CMD_DEST="$WORK/cmds" \
    HOOK_DEST="$WORK/hooks" CLAUDE_SETTINGS="$WORK/settings.json" \
    bash "$SHIMS" "$@" >"$WORK/out" 2>"$WORK/err"
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

printf -- '\n-- E. a REPO that is not a checkout (2026-08-02 dexter bootstrap)\n'

# On dexter, `bash ~/realisateur/bin/install-shims.sh` with no REPO set
# defaulted to mandark's path, which does not exist there. It printed FLAGs
# about hooks it could not find, installed nothing, and EXITED 0 -- while
# ~/.local/bin was still exactly `claude node npm npx`. The installer whose
# job is making guards exist was itself an exit-0 no-op.
#
# E1 is the load-bearing one. E2 and E3 exist because "exits nonzero" alone
# would also pass if it failed for some unrelated reason, and because the
# whole point is that it must not have written anything on the way out.
mkdir -p "$WORK/notarepo"
rc="$(BIN_DEST="$WORK/ebin" CMD_DEST="$WORK/ecmds" REPO="$WORK/notarepo" \
      bash "$SHIMS" >"$WORK/eout" 2>"$WORK/eerr"; printf '%s' "$?")"
check "E1 a REPO with no bin/ and no .git exits nonzero, not 0" \
  "$([ "$rc" != 0 ] && echo yes || echo no)" "yes"
grep -q 'does not name a realisateur checkout' "$WORK/eerr" \
  && ok "E2 it says WHY on stderr, naming the path it rejected" \
  || bad "E2 it says WHY on stderr, naming the path it rejected"
check "E3 it wrote no shims before bailing" \
  "$([ -e "$WORK/ebin" ] && echo wrote || echo clean)" "clean"

# E4 is the OTHER side of E1/E2, and without it the checkout test passes
# vacuously by refusing everything. In a linked worktree `.git` is a FILE, not
# a directory, so the `-d` test this check used until 2026-08-07 called every
# worktree "not a realisateur checkout". Every agent in this repo works in
# .claude/worktrees/*, and run_shims above now passes its own tree, so the
# wrong predicate broke the suite from the only place it runs.
git init -q "$WORK/wtsrc"
git -C "$WORK/wtsrc" config user.email t@test; git -C "$WORK/wtsrc" config user.name T
mkdir -p "$WORK/wtsrc/bin"; printf '#!/bin/sh\necho x\n' > "$WORK/wtsrc/bin/x.sh"
git -C "$WORK/wtsrc" add -A; git -C "$WORK/wtsrc" commit -qm init
git -C "$WORK/wtsrc" worktree add -q "$WORK/wtlinked" -b linked >/dev/null 2>&1
BIN_DEST="$WORK/wbin" CMD_DEST="$WORK/wcmds" REPO="$WORK/wtlinked" \
  HOOK_DEST="$WORK/whooks" CLAUDE_SETTINGS="$WORK/wsettings.json" \
  bash "$SHIMS" >"$WORK/wout" 2>"$WORK/werr"
check "E4 a linked worktree (.git is a file) is a checkout, not a rejection" \
  "$([ -f "$WORK/wtlinked/.git" ] && echo file || echo notfile)" "file"
grep -q 'does not name a realisateur checkout' "$WORK/werr" \
  && bad "E5 it did not refuse the worktree as 'not a checkout'" \
  || ok  "E5 it did not refuse the worktree as 'not a checkout'"

printf -- '\n--- install-shims symlink guard: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
