#!/usr/bin/env bash
set -uo pipefail  # bin/tests/session-start-memory-budget.test.sh: witness for hooks/session-start-memory-budget.sh (#715)
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/../hooks/session-start-memory-budget.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

harness_tmp

payload() { printf '{"cwd":"%s"}' "$1"; }
run() { payload "$1" | MEMORY_ROOT="$2" MEMORY_BUDGET_BYTES="${3:-24400}" "$SCRIPT" 2>&1; }

seedmem() { # seedmem <memory-root> <cwd> <bytes> -- writes an N-byte MEMORY.md at the slug this cwd maps to
  local root="$1" cwd="$2" n="$3" slug
  slug="$(printf '%s' "$cwd" | tr '/' '-')"
  mkdir -p "$root/$slug/memory"
  head -c "$n" /dev/zero | tr '\0' 'm' > "$root/$slug/memory/MEMORY.md"
}

section "A. no MEMORY.md at all -- silent"

A_OUT="$(run "$T/proj-a" "$T/root-a")"; A_RC=$?
rc "A1 no memory dir -> exit 0" 0 "$A_RC"
eq "A2 no memory dir -> no output" "$A_OUT" ""

section "B. well under budget -- silent"

seedmem "$T/root-b" "$T/proj-b" 100
B_OUT="$(run "$T/proj-b" "$T/root-b" 1000)"; B_RC=$?
rc "B1 10% of budget -> exit 0" 0 "$B_RC"
eq "B2 10% of budget -> no output (boring, silent)" "$B_OUT" ""

section "C. inside ~10% of budget -- warns, still exit 0"

seedmem "$T/root-c" "$T/proj-c" 950
C_OUT="$(run "$T/proj-c" "$T/root-c" 1000)"; C_RC=$?
rc  "C1 95% of budget -> exit 0 (context, not a gate)" 0 "$C_RC"
has "C2 states the size" "$C_OUT" "950"
has "C3 states the budget" "$C_OUT" "1000"
has "C4 says headroom is running out" "$C_OUT" "headroom"

section "D. past budget -- says so plainly"

seedmem "$T/root-d" "$T/proj-d" 1200
D_OUT="$(run "$T/proj-d" "$T/root-d" 1000)"; D_RC=$?
rc  "D1 over budget -> exit 0 (context, not a gate)" 0 "$D_RC"
has "D2 says OVER" "$D_OUT" "OVER"
has "D3 says the tail is not loading" "$D_OUT" "not loading"

section "E. a different cwd's memory file does not leak into this one's report"

seedmem "$T/root-e" "$T/proj-e-other" 1200
E_OUT="$(run "$T/proj-e" "$T/root-e" 1000)"; E_RC=$?
rc "E1 no memory file at THIS cwd's slug -> exit 0" 0 "$E_RC"
eq "E2 no memory file at THIS cwd's slug -> no output" "$E_OUT" ""

summary
