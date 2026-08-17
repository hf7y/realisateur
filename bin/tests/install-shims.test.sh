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

printf -- '-- D. symlink at install target (2026-08-01 regression)\n'

# A stand-in for a real repo source file. If install-shims writes through a
# symlink, this is what gets destroyed.
CANARY="$WORK/canary-source.sh"
printf '#!/usr/bin/env bash\n# CANARY -- must survive verbatim\necho canary\n' > "$CANARY"
CANARY_SUM="$(md5sum < "$CANARY")"

# REPO IS PASSED, AND THAT IS THE WHOLE POINT OF THIS FUNCTION.
#
# Until 2026-08-07 this passed only BIN_DEST and CMD_DEST. install-shims.sh
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
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
rm -rf "${WORK:?}/bin" "${WORK:?}/cmds"; mkdir -p "$WORK/bin" "$WORK/cmds"
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
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
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
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
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

# --- F: ORPHAN PRUNE ----------------------------------------------------------
# Installing was only half the job. Nothing removed a shim whose source had
# been retired, so `hygiene-lint` stayed live on all 13 monkey accounts after
#   [rest: vault:realisateur/guard-archaeology-20260817.md]
printf '#!/usr/bin/env bash\n# >>> realisateur-owned shim -- generated by bin/install-shims.sh.\n# <<< realisateur-owned\nexec /nonexistent "$@"\n' > "$WORK/bin/gone-away"
chmod 755 "$WORK/bin/gone-away"
printf '#!/usr/bin/env bash\necho not ours\n' > "$WORK/bin/hand-written"
chmod 755 "$WORK/bin/hand-written"
HW_SUM="$(md5sum < "$WORK/bin/hand-written")"

rc="$(run_shims --check)"
grep -q 'gone-away is an ORPHAN shim' "$WORK/out" "$WORK/err" 2>/dev/null \
  && ok  "F0 --check FLAGs the orphan instead of silently removing it" \
  || bad "F0 --check FLAGs the orphan instead of silently removing it"
[ -f "$WORK/bin/gone-away" ] && ok "F0b --check wrote nothing" || bad "F0b --check wrote nothing"

rc="$(run_shims)"
[ -f "$WORK/bin/gone-away" ] && bad "F1 an orphan shim is removed" \
                            || ok  "F1 an orphan shim is removed"
[ -f "$WORK/bin/hand-written" ] && ok "F2 a file this installer did not write is left alone" \
                                || bad "F2 a file this installer did not write is left alone"
check "F2b and is byte-identical" "$(md5sum < "$WORK/bin/hand-written")" "$HW_SUM"
[ -f "$WORK/bin/silence-audit" ] && ok "F3 a LIVE shim survives the prune" \
                                 || bad "F3 a LIVE shim survives the prune"

summary
