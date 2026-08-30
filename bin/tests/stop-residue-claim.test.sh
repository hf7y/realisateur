#!/usr/bin/env bash
set -uo pipefail  # bin/tests/stop-residue-claim.test.sh: witness for completion_claims() in hooks/stop-residue-gate.sh -- #681's unfiled-finding half, refiled as #752
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/../hooks/stop-residue-gate.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

harness_tmp

newrepo() { # a clean tree with an upstream, so only the claim check can speak
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

user_turn() { jq -nc --arg t "$1" '{"type":"user","message":{"content":[{"type":"text","text":$t}]}}'; }
asst_turn() { jq -nc --arg t "$1" '{"type":"assistant","message":{"content":[{"type":"text","text":$t}]}}'; }
bash_act()  { jq -nc --arg c "$1" '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":$c}}]}}'; }
edit_act()  { jq -nc --arg f "$1" '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Edit","input":{"file_path":$f}}]}}'; }
tool_out()  { jq -nc --arg o "$1" '{"type":"user","message":{"content":[{"type":"tool_result","content":[]}]},"toolUseResult":{"stdout":$o}}'; }

run()  { printf '{"cwd":"%s","transcript_path":"%s","stop_hook_active":false}' "$1" "$2" | "$SCRIPT" 2>&1; }
rcof() { printf '{"cwd":"%s","transcript_path":"%s","stop_hook_active":false}' "$1" "$2" | "$SCRIPT" >/dev/null 2>&1; printf '%s' "$?"; }

R="$T/repo"; newrepo "$R"

section "A. a completion claim is graded against this turn's tool calls (#752)"

{ user_turn "file the guard gap"
  asst_turn "Reading the hook now."
  bash_act "gh issue create -R hf7y/realisateur -F /tmp/body"
  tool_out "https://github.com/hf7y/realisateur/issues/900"
  asst_turn "I filed the gap as an issue."; } > "$T/a1.jsonl"
rc "A1 claims to have filed, and did -> exit 0" 0 "$(rcof "$R" "$T/a1.jsonl")"

{ user_turn "file the guard gap"
  asst_turn "I filed the gap as an issue."; } > "$T/a2.jsonl"
A2_OUT="$(run "$R" "$T/a2.jsonl")"
rc  "A2 claims to have filed, and did not -> BLOCKED (2)" 2 "$(rcof "$R" "$T/a2.jsonl")"
has "A2 quotes the claim it could not verify" "$A2_OUT" "I filed the gap as an issue."
has "A2 names the rule, not a policy file"    "$A2_OUT" "Fix it in the turn you found it"

{ user_turn "what does the gate do?"
  asst_turn "It blocks an open non-draft PR and a dirty tree. The unfiled-finding half was never attempted, which is what hooks/stop-residue-gate.sh:2 records."; } > "$T/a3.jsonl"
rc "A3 an ordinary conversational answer, no claim -> exit 0" 0 "$(rcof "$R" "$T/a3.jsonl")"

printf 'not json at all\n{{{\n' > "$T/a4.jsonl"
rc "A4 an unparseable transcript fails OPEN -> exit 0" 0 "$(rcof "$R" "$T/a4.jsonl")"

{ user_turn "fix the unquoted variable"
  edit_act "$R/bin/thing.sh"
  asst_turn "Done."; } > "$T/a5.jsonl"
rc "A5 acted without claiming anything -> exit 0" 0 "$(rcof "$R" "$T/a5.jsonl")"

section "B. citation, promise, and turn scope"

{ user_turn "did you file it?"
  tool_out "https://github.com/hf7y/realisateur/issues/684"
  user_turn "so what happened"
  asst_turn "I filed #684. This is the cleanup."; } > "$T/b1.jsonl"
rc "B1 a recap citing an artifact this transcript has seen -> exit 0" 0 "$(rcof "$R" "$T/b1.jsonl")"

{ user_turn "so what happened"
  asst_turn "I filed it as #781, so that is handled."; } > "$T/b2.jsonl"
B2_OUT="$(run "$R" "$T/b2.jsonl")"
rc  "B2 a cited number the transcript has never seen -> BLOCKED (2)" 2 "$(rcof "$R" "$T/b2.jsonl")"
has "B2 quotes the fabricated citation" "$B2_OUT" "#781"

{ user_turn "anything else broken?"
  asst_turn "The guard scrapes an unexpanded \$HOME. I'll file that as an issue."; } > "$T/b3.jsonl"
B3_OUT="$(run "$R" "$T/b3.jsonl")"
rc  "B3 a promise the ending turn never kept -> BLOCKED (2)" 2 "$(rcof "$R" "$T/b3.jsonl")"
has "B3 quotes the promise" "$B3_OUT" "I'll file that as an issue."

{ user_turn "file it"
  asst_turn "I filed the gap as an issue."
  user_turn "now explain it"
  asst_turn "It refuses a turn whose text outruns its tool calls."; } > "$T/b4.jsonl"
rc "B4 a claim from a PRIOR turn does not block THIS turn" 0 "$(rcof "$R" "$T/b4.jsonl")"

{ user_turn "was it deleted?"
  asst_turn "install-shims.sh was deleted by #511, and the decision landed with it. The remedy parked rather than deleted."; } > "$T/b5.jsonl"
rc "B5 third-person history using the same verbs -> exit 0" 0 "$(rcof "$R" "$T/b5.jsonl")"

NOJQ="$T/nojq"; mkdir -p "$NOJQ"
for c in bash cat dirname git grep sed awk; do ln -s "$(command -v "$c")" "$NOJQ/$c"; done
rc "B6 no jq on PATH -- the claim check is skipped, not an error" 0 \
   "$(printf '{"cwd":"%s","transcript_path":"%s","stop_hook_active":false}' "$R" "$T/a2.jsonl" | PATH="$NOJQ" "$SCRIPT" >/dev/null 2>&1; printf '%s' "$?")"

summary || exit 1
