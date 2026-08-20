#!/usr/bin/env bash
#
# TRAPS (the rest of this header is in the vault):
# WAS RED WHEN CI FIRST RAN IT (8/3, run 31217552355); CLOSED 2026-08-07, and
# the one-line fix uncovered two more defects behind it. `run_shims` passed only
# BIN_DEST and CMD_DEST, so REPO fell back to $HOME/Documents/Projects/
# realisateur and section D audited the LIVE SHARED CHECKOUT instead of the
# branch. Passing REPO then exposed: (1) install-shims.sh tested `-d "$REPO/
# .git"`, but in a linked worktree .git is a FILE, so it refused every worktree
# as "not a realisateur checkout" -- and every agent in this repo works in
# .claude/worktrees/*. Now `-e`, with E4/E5 pinning it. (2) With REPO passed,
# the run reaches the hook section, and HOOK_DEST/CLAUDE_SETTINGS were NOT
# redirected -- so this suite would have written into the real ~/.claude/hooks.
# Both overrides added. No assertion changed.
#
# usage: ./bin/tests/install-shims.test.sh

set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SHIMS="$REPO/bin/install-shims.sh"
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT


# A stand-in for a real repo source file. If install-shims writes through a
# symlink, this is what gets destroyed.

# REPO IS PASSED, AND THAT IS THE WHOLE POINT OF THIS FUNCTION.
#
# Until 2026-08-07 this passed only BIN_DEST and CMD_DEST. install-shims.sh
run_shims() {
  REPO="$REPO" BIN_DEST="$WORK/bin" CMD_DEST="$WORK/cmds" \
    HOOK_DEST="$WORK/hooks" CLAUDE_SETTINGS="$WORK/settings.json" \
    bash "$SHIMS" "$@" >"$WORK/out" 2>"$WORK/err"
  printf '%s' "$?"
}

printf -- '\n-- E. a REPO that is not a checkout (2026-08-02 dexter bootstrap)\n'

# On dexter, `bash ~/realisateur/bin/install-shims.sh` with no REPO set
# defaulted to mandark's path, which does not exist there. It printed FLAGs
# about hooks it could not find, installed nothing, and EXITED 0 -- while
# ~/.local/bin was still exactly `claude node npm npx`. The installer whose
mkdir -p "$WORK/notarepo"
rc="$(CMD_DEST="$WORK/ecmds" REPO="$WORK/notarepo" \
      bash "$SHIMS" >"$WORK/eout" 2>"$WORK/eerr"; printf '%s' "$?")"
check "E1 a REPO with no bin/ and no .git exits nonzero, not 0" \
  "$([ "$rc" != 0 ] && echo yes || echo no)" "yes"
grep -q 'does not name a realisateur checkout' "$WORK/eerr" \
  && ok "E2 it says WHY on stderr, naming the path it rejected" \
  || bad "E2 it says WHY on stderr, naming the path it rejected"

# E4 is the OTHER side of E1/E2, and without it the checkout test passes
# vacuously by refusing everything. In a linked worktree `.git` is a FILE, not
# a directory, so the `-d` test this check used until 2026-08-07 called every
git init -q "$WORK/wtsrc"
git -C "$WORK/wtsrc" config user.email t@test; git -C "$WORK/wtsrc" config user.name T
mkdir -p "$WORK/wtsrc/bin"; printf '#!/bin/sh\necho x\n' > "$WORK/wtsrc/bin/x.sh"
git -C "$WORK/wtsrc" add -A; git -C "$WORK/wtsrc" commit -qm init
git -C "$WORK/wtsrc" worktree add -q "$WORK/wtlinked" -b linked >/dev/null 2>&1
CMD_DEST="$WORK/wcmds" REPO="$WORK/wtlinked" \
  HOOK_DEST="$WORK/whooks" CLAUDE_SETTINGS="$WORK/wsettings.json" \
  bash "$SHIMS" >"$WORK/wout" 2>"$WORK/werr"
check "E4 a linked worktree (.git is a file) is a checkout, not a rejection" \
  "$([ -f "$WORK/wtlinked/.git" ] && echo file || echo notfile)" "file"
grep -q 'does not name a realisateur checkout' "$WORK/werr" \
  && bad "E5 it did not refuse the worktree as 'not a checkout'" \
  || ok  "E5 it did not refuse the worktree as 'not a checkout'"

summary
