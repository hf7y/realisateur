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

payload() { # payload <cwd> [<transcript>] [<session_id>]
  local cwd="$1" transcript="${2:-}" sid="${3:-}"
  printf '{"cwd":"%s","transcript_path":"%s","session_id":"%s","stop_hook_active":false}' "$cwd" "$transcript" "$sid"
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
rc    "A2 dirty cwd, no baseline -> warns, does not block (#773)" 0 "$A2_RC"
has   "A2 still names cwd as the dirty tree" "$A2_OUT" "$T/dirty"
has   "A2 names the ambiguity instead"       "$A2_OUT" "UNATTRIBUTED"
hasnt "A2 does not accuse"                   "$A2_OUT" "BLOCKED"

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

echo
section "E. scoped to THIS session's changes (#773; the twin's #764 fix, at Stop scope)"

JOB="$T/job"; mkdir -p "$JOB/tmp"   # SessionStart is the same script, --baseline
markb() { payload "$1" "" "$2" | CLAUDE_JOB_DIR="$JOB" "$SCRIPT" --baseline >/dev/null 2>&1; printf '%s' "$?"; }
runb()  { payload "$1" "${3:-}" "$2" | CLAUDE_JOB_DIR="$JOB" "$SCRIPT" 2>&1; }
rcb()   { payload "$1" "${3:-}" "$2" | CLAUDE_JOB_DIR="$JOB" "$SCRIPT" >/dev/null 2>&1; printf '%s' "$?"; }

newrepo "$T/e-own"
RC="$(markb "$T/e-own" sess-a)"
rc "E0 --baseline exits 0" 0 "$RC"
echo mine > "$T/e-own/mine.txt"
E1="$(runb "$T/e-own" sess-a)"; E1_RC="$(rcb "$T/e-own" sess-a)"
rc  "E1 own change after the baseline -> BLOCKED (2)" 2 "$E1_RC"
has "E1 names it as YOURS" "$E1" "YOURS"
has "E1 names the file"    "$E1" "mine.txt"

newrepo "$T/e-foreign"
echo theirs > "$T/e-foreign/vmhost.sh"
echo theirs > "$T/e-foreign/repose.sh"
markb "$T/e-foreign" sess-b >/dev/null
E2="$(runb "$T/e-foreign" sess-b)"; E2_RC="$(rcb "$T/e-foreign" sess-b)"
rc    "E2 pre-existing foreign dirt alone -> does NOT block (0)" 0 "$E2_RC"
has   "E2 reports it as context"         "$E2" "NOT YOURS"
has   "E2 names the foreign file"        "$E2" "vmhost.sh"
hasnt "E2 does not accuse"               "$E2" "BLOCKED"
hasnt "E2 never tells it to revert them" "$E2" "git restore"
hasnt "E2 never tells it to commit them" "$E2" "git commit"

newrepo "$T/e-both"
echo theirs > "$T/e-both/theirs.txt"
markb "$T/e-both" sess-c >/dev/null
echo mine > "$T/e-both/mine.txt"
E3="$(runb "$T/e-both" sess-c)"; E3_RC="$(rcb "$T/e-both" sess-c)"
rc  "E3 own + foreign -> BLOCKED (2)" 2 "$E3_RC"
has "E3 counts ONLY the session's own change" "$E3" "leaving 1 uncommitted change(s) of your own"
E3_YOURS="$(printf '%s\n' "$E3" | sed -n '/^YOURS/,/^$/p')"
has   "E3 YOURS lists the session's file"       "$E3_YOURS" "mine.txt"
hasnt "E3 YOURS does not list the foreign file" "$E3_YOURS" "theirs.txt"
has   "E3 the foreign file is context"          "$E3" "NOT YOURS"
has   "E3 says to leave the foreign work alone" "$E3" "Leave these exactly as they are"

newrepo "$T/e-nobase"
echo whoever > "$T/e-nobase/x.txt"
E4="$(runb "$T/e-nobase" sess-d)"; E4_RC="$(rcb "$T/e-nobase" sess-d)"
rc    "E4 no baseline -> warns, does not block (0)" 0 "$E4_RC"
has   "E4 names the ambiguity" "$E4" "UNATTRIBUTED"
hasnt "E4 does not accuse"     "$E4" "YOURS -- new since"

newrepo "$T/e-resume"  # Stop fires EVERY turn and SessionStart re-fires on resume/compact: a second mark mid-session would relabel the session's own work as pre-existing
markb "$T/e-resume" sess-e >/dev/null
echo mine > "$T/e-resume/mine.txt"
markb "$T/e-resume" sess-e >/dev/null
E5_RC="$(rcb "$T/e-resume" sess-e)"
rc "E5 a re-fired SessionStart does not re-baseline mid-session" 2 "$E5_RC"

newrepo "$T/e-stale"
markb "$T/e-stale" sess-f >/dev/null
echo whoever > "$T/e-stale/x.txt"
touch -d '2 days ago' "$JOB/tmp/stop-residue-baselines/sess-f"
E6_RC="$(rcb "$T/e-stale" sess-f)"
rc "E6 a baseline older than the max age is treated as no baseline" 0 "$E6_RC"

RC="$(markb "$T/dirty" sess-g)"
rc "E7 --baseline on a dirty tree still exits 0" 0 "$RC"
RC="$(markb "$T" sess-h)"
rc "E8 --baseline outside a repo still exits 0" 0 "$RC"

summary
[ "$fail" -eq 0 ] || exit 1
