#!/usr/bin/env bash
set -uo pipefail  # bin/tests/stop-residue-gate.test.sh: witness for hooks/stop-residue-gate.sh, subagent-closeout.sh's sibling one scope up (#681)
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/../hooks/stop-residue-gate.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

harness_tmp

newrepo() { # newrepo <path> -- pushed to a bare remote, so no host-only-branch flag.
  local bare="$1.git"
  git init -q --bare "$bare"
  git clone -q "$bare" "$1" 2>/dev/null
  git -C "$1" config user.email t@test
  git -C "$1" config user.name T
  git -C "$1" checkout -q -B main
  git -C "$1" commit -q --allow-empty -m init
  git -C "$1" push -q origin main
  git -C "$1" branch -q --set-upstream-to=origin/main
}

transcript_writing() { # transcript_writing <path> <file...>
  local out="$1"; shift
  : > "$out"
  for f in "$@"; do
    printf '{"message":{"content":[{"type":"tool_use","name":"Write","input":{"file_path":"%s"}}]}}\n' "$f" >> "$out"
  done
}

payload() { # payload <cwd> [<transcript>]
  local cwd="$1" transcript="${2:-}"
  printf '{"cwd":"%s","transcript_path":"%s","stop_hook_active":false}' "$cwd" "$transcript"
}

run() { payload "$1" "${2:-}" | "$SCRIPT" 2>&1; }

user_turn()   { jq -nc --arg t "$1" '{"type":"user","message":{"content":[{"type":"text","text":$t}]}}'; } # a real prompt, no toolUseResult
tool_result() { jq -nc '{"type":"user","message":{"content":[{"type":"tool_result","content":[]}]},"toolUseResult":{"stdout":""}}'; } # NOT a turn boundary
asst_turn()   { jq -nc --arg t "$1" '{"type":"assistant","message":{"content":[{"type":"text","text":$t}]}}'; }

mkdir -p "$T/bin"
cat > "$T/bin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *pulls/*) cat "$STUB_PR" 2>/dev/null || exit 1 ;;
esac
EOF
chmod +x "$T/bin/gh"
runpr() { payload "$1" "${2:-}" | STUB_PR="$T/pr-state" PATH="$T/bin:$PATH" "$SCRIPT" 2>&1; }
rcof()  { payload "$1" "${2:-}" | STUB_PR="$T/pr-state" PATH="$T/bin:$PATH" "$SCRIPT" >/dev/null 2>&1; printf '%s' "$?"; }
transcript_pr() { printf 'opened https://github.com/hf7y/widget/pull/7 today\n' > "$1"; }

section "A. baseline behavior"

newrepo "$T/clean"
A1_OUT="$(run "$T/clean")"; A1_RC=$?
rc "A1 clean cwd, no transcript -> exit 0" 0 "$A1_RC"

newrepo "$T/dirty"
echo scratch > "$T/dirty/f.txt"
A2_OUT="$(run "$T/dirty")"; A2_RC=$?
rc  "A2 dirty cwd, no transcript -> BLOCKED (2)" 2 "$A2_RC"
has "A2 names cwd as the offending tree" "$A2_OUT" "$T/dirty"

A3_OUT="$(printf '{"cwd":"%s","stop_hook_active":true}' "$T/dirty" | "$SCRIPT" 2>&1)"; A3_RC=$?
rc "A3 stop_hook_active loop guard still exits 0 on a dirty tree" 0 "$A3_RC"

section "B. a turn that wrote outside cwd (worktree isolation)"

newrepo "$T/cwdrepo"
newrepo "$T/writtenrepo"
echo scratch > "$T/writtenrepo/w.txt"
transcript_writing "$T/t1.jsonl" "$T/writtenrepo/w.txt"
B1_OUT="$(run "$T/cwdrepo" "$T/t1.jsonl")"; B1_RC=$?
rc  "B1 clean cwd, transcript wrote elsewhere -> BLOCKED (2)" 2 "$B1_RC"
has "B1 names the WRITTEN tree, not just cwd"   "$B1_OUT" "$T/writtenrepo"

newrepo "$T/cwdrepo2"
newrepo "$T/cleanwritten"
transcript_writing "$T/t2.jsonl" "$T/cleanwritten/nope.txt"
B2_OUT="$(run "$T/cwdrepo2" "$T/t2.jsonl")"; B2_RC=$?
rc "B2 clean cwd, transcript wrote to a tree that is ALSO clean -> exit 0" 0 "$B2_RC"

: > "$T/empty.jsonl"
newrepo "$T/cwdrepo3"
B3_OUT="$(run "$T/cwdrepo3" "$T/empty.jsonl")"; B3_RC=$?
rc "B3 empty transcript behaves like no transcript -> exit 0" 0 "$B3_RC"

B4_OUT="$(run "$T/cwdrepo3" "$T/does-not-exist.jsonl")"; B4_RC=$?
rc "B4 unreadable transcript path does not error -- falls back to cwd only" 0 "$B4_RC"

echo
section "C. a PR this turn opened, still open, is not a finished run"
G="$T/g"; newrepo "$G"
TR="$T/g-transcript"; transcript_pr "$TR"

printf 'open\tfalse\tfalse\tNO-DECISION: x\n\n<!-- DELIVERS -->\n- none\n<!-- /DELIVERS -->' > "$T/pr-state"
OUT="$(runpr "$G" "$TR")"; RC="$(rcof "$G" "$TR")"
rc  "C1 an open non-draft PR blocks the stop" 2 "$RC"
has "C2 and names the PR" "$OUT" "pull/7"

printf 'open\ttrue\tfalse\tNO-DECISION: x\n\n<!-- DELIVERS -->\n- none\n<!-- /DELIVERS -->' > "$T/pr-state"
RC="$(rcof "$G" "$TR")"
rc "C3 a DRAFT claims nothing, so it does not block" 0 "$RC"

printf 'closed\tfalse\tfalse\tNO-DECISION: x' > "$T/pr-state"
RC="$(rcof "$G" "$TR")"
rc "C4 a merged or closed PR does not block" 0 "$RC"

printf 'open\tfalse\ttrue\tNO-DECISION: x\n\n<!-- DELIVERS -->\n- none\n<!-- /DELIVERS -->' > "$T/pr-state"
OUT="$(runpr "$G" "$TR")"; RC="$(rcof "$G" "$TR")"
rc  "C5 an open PR with AUTO-MERGE ARMED does not block" 0 "$RC"
has "C6 and says so, rather than passing silently" "$OUT" "AUTO-MERGE ARMED"

printf 'open\tfalse\tfalse\tNO-DECISION: x\n\n<!-- DELIVERS -->\n- none\n<!-- /DELIVERS -->' > "$T/pr-state"
OUT="$(runpr "$G" "$TR")"
has "C7 the refusal names arming auto-merge as the preferred exit" "$OUT" "--auto"

echo
section "D. a HUMAN-STEP block this turn asked a human to run, without verified: (#714 Rule 2)"

newrepo "$T/d"

BAD_STEP='before the ask.

HUMAN-STEP
  what:     add a CNAME head.dcpgateway.com -> dcpgateway-head.netlify.app
  where:    Namecheap, dcpgateway.com, Advanced DNS
  verified:
  undo:     delete the record

after the ask.'

GOOD_STEP='before the ask.

HUMAN-STEP
  what:     add a CNAME head.dcpgateway.com -> dcpgateway-head.netlify.app
  where:    Namecheap, dcpgateway.com, Advanced DNS
  verified: dig'"'"'d dcpgateway-head.netlify.app, target CNAME resolves
  undo:     delete the record

after the ask.'

{ user_turn "set up the netlify subdomain"; asst_turn "$BAD_STEP"; } > "$T/d1.jsonl"
D1_OUT="$(run "$T/d" "$T/d1.jsonl")"; D1_RC=$?
rc  "D1 empty verified: -> BLOCKED (2)" 2 "$D1_RC"
has "D1 names the missing field" "$D1_OUT" "verified:"
has "D1 names which step, from its what:" "$D1_OUT" "add a CNAME"

{ user_turn "set up the netlify subdomain"; asst_turn "$GOOD_STEP"; } > "$T/d2.jsonl"
D2_OUT="$(run "$T/d" "$T/d2.jsonl")"; D2_RC=$?
rc "D2 a filled verified: does not block" 0 "$D2_RC"

{ asst_turn "$BAD_STEP"; user_turn "ok now do the next thing"; asst_turn "no HUMAN-STEP here, all done."; } > "$T/d3.jsonl"  # the bad block is from a PRIOR turn -- must not block THIS turn
D3_RC=$(run "$T/d" "$T/d3.jsonl" >/dev/null 2>&1; echo $?)
rc "D3 an unverified block from a PRIOR turn does not block THIS turn" 0 "$D3_RC"

{ user_turn "set up the netlify subdomain"; tool_result; asst_turn "$BAD_STEP"; } > "$T/d4.jsonl"  # tool_result is type=user too, but not a turn boundary
D4_RC=$(run "$T/d" "$T/d4.jsonl" >/dev/null 2>&1; echo $?)
rc "D4 a tool_result in between is not mistaken for a new turn" 2 "$D4_RC"

{ user_turn "just chatting"; asst_turn "no manual steps needed here."; } > "$T/d5.jsonl"
D5_RC=$(run "$T/d" "$T/d5.jsonl" >/dev/null 2>&1; echo $?)
rc "D5 no HUMAN-STEP block at all -> exit 0" 0 "$D5_RC"

D6DIR="$T/nojq"; mkdir -p "$D6DIR"
for c in bash cat dirname git grep sed; do ln -s "$(command -v "$c")" "$D6DIR/$c"; done
D6_RC=$(payload "$T/d" "$T/d1.jsonl" | PATH="$D6DIR" "$SCRIPT" >/dev/null 2>&1; echo $?)
rc "D6 no jq on PATH -- Rule 2 check is skipped, not an error" 0 "$D6_RC"

summary
[ "$fail" -eq 0 ] || exit 1
