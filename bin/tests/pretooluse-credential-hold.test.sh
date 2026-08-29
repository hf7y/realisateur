#!/usr/bin/env bash
set -uo pipefail  # bin/tests/pretooluse-credential-hold.test.sh: witness for hooks/pretooluse-credential-hold.sh (#714 Rule 3)
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/../hooks/pretooluse-credential-hold.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

harness_tmp
HOLD_DIR="$T/holds"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not on PATH, this suite cannot run"; exit 0; }

prompt_payload() { jq -cn --arg s "$1" '{hook_event_name:"UserPromptSubmit",session_id:$s,prompt:"x"}'; }
bash_payload()   { jq -cn --arg t "$1" --arg c "$2" --arg s "$3" '{hook_event_name:"PreToolUse",session_id:$s,tool_name:$t,tool_input:{command:$c}}'; }
tool_payload()   { jq -cn --arg t "$1" --arg s "$2" '{hook_event_name:"PreToolUse",session_id:$s,tool_name:$t,tool_input:{}}'; }

runp() { prompt_payload "$1" | CREDENTIAL_HOLD_DIR="$HOLD_DIR" "$SCRIPT" 2>&1; }
runb() { bash_payload "$1" "$2" "$3" | CREDENTIAL_HOLD_DIR="$HOLD_DIR" "$SCRIPT" 2>&1; }
rcb()  { bash_payload "$1" "$2" "$3" | CREDENTIAL_HOLD_DIR="$HOLD_DIR" "$SCRIPT" >/dev/null 2>&1; printf '%s' "$?"; }
rct()  { tool_payload "$1" "$2" | CREDENTIAL_HOLD_DIR="$HOLD_DIR" "$SCRIPT" >/dev/null 2>&1; printf '%s' "$?"; }

section "A. only PreToolUse/Bash and UserPromptSubmit are this hook's business"

RC="$(rct Read s1)"
rc "A1 a non-Bash PreToolUse tool is not this guard's business" 0 "$RC"

O="$(printf '{"hook_event_name":"Stop","session_id":"s1"}' | CREDENTIAL_HOLD_DIR="$HOLD_DIR" "$SCRIPT" >/dev/null 2>&1; echo $?)"
rc "A2 an unrelated hook event is not this guard's business" 0 "$O"

section "B. plain read-only commands never block"

RC="$(rcb Bash 'ls -la' s2)"
rc "B1 an ordinary command is allowed" 0 "$RC"

RC="$(rcb Bash 'cat ~/.claude-token' s2)"
rc "B2 reading a credential file, alone, is allowed (only the HOLD begins)" 0 "$RC"

section "C. the hold: a credential read blocks a subsequent external state-changing curl"

S=cred-session-1
RC="$(rcb Bash 'cat ~/.claude-token' "$S")"
rc "C1 reading the token starts the hold, but does not itself block" 0 "$RC"

RC="$(rcb Bash 'curl -X POST https://api.netlify.com/api/v1/sites -d "{}"' "$S")"
rc "C2 a POST to an external host, in the same turn, is BLOCKED" 2 "$RC"
O="$(runb Bash 'curl -X POST https://api.netlify.com/api/v1/sites -d "{}"' "$S")"
has "C2 names the reason" "$O" "credential just entered"

RC="$(rcb Bash 'curl -X PATCH https://api.netlify.com/api/v1/sites/x -d "{}"' "$S")"
rc "C3 PATCH is blocked too" 2 "$RC"

RC="$(rcb Bash 'curl -X DELETE https://api.netlify.com/api/v1/sites/x' "$S")"
rc "C4 DELETE is blocked too" 2 "$RC"

RC="$(rcb Bash 'curl --data "{}" https://api.netlify.com/api/v1/sites' "$S")"
rc "C5 a bare --data curl (implicit POST) is blocked too" 2 "$RC"

section "D. a combined command -- credential AND write in one line -- is blocked too"

RC="$(rcb Bash 'curl -X POST -H "Authorization: Bearer $TOK" https://api.netlify.com/api/v1/sites -d "{}"' cred-session-2)"
rc "D1 a single command carrying both is blocked, not held for a future call" 2 "$RC"

section "E. what the hold does NOT block"

S=cred-session-3
runb Bash 'cat ~/.claude-token' "$S" >/dev/null

RC="$(rcb Bash 'curl https://api.netlify.com/api/v1/sites' "$S")"
rc "E1 a read-only GET curl (no verb, no --data) is still allowed" 0 "$RC"

RC="$(rcb Bash 'curl -X POST http://localhost:8080/hook -d "{}"' "$S")"
rc "E2 a POST to localhost is allowed even while held" 0 "$RC"

RC="$(rcb Bash 'git push origin main' "$S")"
rc "E3 a state-changing command that is not curl is not this guard's business" 0 "$RC"

section "F. UserPromptSubmit clears the hold -- scoped to ONE turn, per session"

S=cred-session-4
runb Bash 'cat ~/.claude-token' "$S" >/dev/null
RC="$(rcb Bash 'curl -X POST https://api.netlify.com/api/v1/sites -d "{}"' "$S")"
rc "F1 sanity: still held before the prompt boundary" 2 "$RC"

runp "$S" >/dev/null
RC="$(rcb Bash 'curl -X POST https://api.netlify.com/api/v1/sites -d "{}"' "$S")"
rc "F2 a fresh UserPromptSubmit for the SAME session clears the hold" 0 "$RC"

section "G. the hold is per-session, not global"

S1=cred-session-5a; S2=cred-session-5b
runb Bash 'cat ~/.claude-token' "$S1" >/dev/null
RC="$(rcb Bash 'curl -X POST https://api.netlify.com/api/v1/sites -d "{}"' "$S2")"
rc "G1 a DIFFERENT session's credential read does not hold this one" 0 "$RC"

section "H. no session_id in the payload is not this guard's business"

O="$(printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"curl -X POST https://x -d 1"}}' | CREDENTIAL_HOLD_DIR="$HOLD_DIR" "$SCRIPT" >/dev/null 2>&1; echo $?)"
rc "H1 a payload with no session_id cannot be keyed, so it is let through" 0 "$O"

summary
