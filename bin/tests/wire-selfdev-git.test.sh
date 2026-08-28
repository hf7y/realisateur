#!/usr/bin/env bash
# wire-selfdev-git.test.sh -- bin/tests/wire-selfdev-git.test.sh (exit 0 = pass)
set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
BIN="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$BIN/wire-selfdev-git.sh"

[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }
harness_tmp

section "A. the argument contract"
rc=0; O="$(bash "$SCRIPT" 2>&1)" || rc=$?
rc "A1 no repo is a usage error, not a default" 2 "$rc"
rc=0; O="$(bash "$SCRIPT" --nonsense 2>&1)" || rc=$?
rc "A2 an unknown flag exits 2" 2 "$rc"
rc=0; O="$(bash "$SCRIPT" a b 2>&1)" || rc=$?
rc "A3 two repos is a usage error, it does not silently take the first" 2 "$rc"

section "B. the witness runs, rather than aborting on the TARGET #473 unassigned"
HOME="$T" ; export HOME
mkdir -p "$T/.ssh"
: > "$T/.ssh/deploy_probe-repo"
rc=0; O="$(bash "$SCRIPT" probe-repo --check 2>&1)" || rc=$?
hasnt "B1 does not abort with an unbound variable" "$O" "unbound variable"
hasnt "B2 and names no empty remote" "$O" "git ls-remote:"
has   "B3 reaches the witness and reports it honestly" "$O" "read not proven yet"
rc "B4 --check with an unreachable alias is a gap, not a crash" 0 "$rc"

section "C. --check changes nothing"
hasnt "C1 no key is generated in --check" "$O" "keypair created"
hasnt "C2 no deploy key is registered in --check" "$O" "deploy key registered"
[ -f "$T/.ssh/deploy_probe-repo" ] && ok "C3 the probe key file is left as it was" \
                                   || bad "C3 the probe key file is left as it was"

summary
