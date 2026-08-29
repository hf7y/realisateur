#!/usr/bin/env bash
set -uo pipefail  # bin/tests/pretooluse-memory-budget.test.sh: witness for hooks/pretooluse-memory-budget.sh (#715)
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/../hooks/pretooluse-memory-budget.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

harness_tmp

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not on PATH, this suite cannot run"; exit 0; }

write_payload() { jq -cn --arg p "$1" --arg c "$2" '{hook_event_name:"PreToolUse",tool_name:"Write",tool_input:{file_path:$p,content:$c}}'; }
edit_payload()  { jq -cn --arg p "$1" --arg o "$2" --arg n "$3" '{hook_event_name:"PreToolUse",tool_name:"Edit",tool_input:{file_path:$p,old_string:$o,new_string:$n}}'; }
other_payload() { jq -cn --arg t "$1" --arg p "$2" '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:{file_path:$p}}'; }

runw() { write_payload "$1" "$2" | MEMORY_BUDGET_BYTES="${3:-24400}" "$SCRIPT" 2>&1; }
rcw()  { write_payload "$1" "$2" | MEMORY_BUDGET_BYTES="${3:-24400}" "$SCRIPT" >/dev/null 2>&1; printf '%s' "$?"; }
rce()  { edit_payload "$1" "$2" "$3" | MEMORY_BUDGET_BYTES="${4:-24400}" "$SCRIPT" >/dev/null 2>&1; printf '%s' "$?"; }
rco()  { other_payload "$1" "$2" | MEMORY_BUDGET_BYTES="${3:-24400}" "$SCRIPT" >/dev/null 2>&1; printf '%s' "$?"; }

section "A. only Write/Edit into a memory/MEMORY.md path is this guard's business"

RC="$(rco Read "$T/x/memory/MEMORY.md")"
rc "A1 a non-Write/Edit tool is not this guard's business" 0 "$RC"

RC="$(rcw "$T/x/memory/some_topic.md" "$(head -c 100000 /dev/zero | tr '\0' 'a')" 100)"
rc "A2 a per-topic memory file (not MEMORY.md) has no budget here" 0 "$RC"

RC="$(rcw "$T/x/notes/MEMORY.md" small 100)"
rc "A3 a MEMORY.md outside a memory/ dir is not this guard's business" 0 "$RC"

section "B. Write: content under budget is allowed, over budget is blocked"

RC="$(rcw "$T/a/memory/MEMORY.md" "short" 100)"
rc "B1 small content, small budget -- allowed" 0 "$RC"

BIG="$(head -c 200 /dev/zero | tr '\0' 'x')"
RC="$(rcw "$T/a/memory/MEMORY.md" "$BIG" 100)"
rc "B2 content past a 100-byte budget -- BLOCKED" 2 "$RC"
O="$(runw "$T/a/memory/MEMORY.md" "$BIG" 100)"
has "B2 names the budget" "$O" "100-byte load budget"
has "B2 says what to do" "$O" "Compress or delete"

section "C. Edit: the resulting size is old size minus old_string plus new_string"

mkdir -p "$T/b/memory"
head -c 90 /dev/zero | tr '\0' 'y' > "$T/b/memory/MEMORY.md"

RC="$(rce "$T/b/memory/MEMORY.md" "" "" 100)"
rc "C1 a no-op edit at 90/100 bytes -- allowed" 0 "$RC"

RC="$(rce "$T/b/memory/MEMORY.md" "" "$(head -c 50 /dev/zero | tr '\0' 'z')" 100)"
rc "C2 appending 50 bytes onto 90/100 -- BLOCKED" 2 "$RC"

RC="$(rce "$T/b/memory/MEMORY.md" "$(head -c 80 /dev/zero | tr '\0' 'y')" "" 100)"
rc "C3 deleting 80 of the 90 bytes -- allowed" 0 "$RC"

section "D. Edit against a MEMORY.md that does not exist yet is sized from zero"

RC="$(rce "$T/c/memory/MEMORY.md" "" "short" 100)"
rc "D1 creating a small index via Edit -- allowed" 0 "$RC"

summary
