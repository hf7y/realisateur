#!/usr/bin/env bash
#
# Usage: bin/tests/subagent-closeout.test.sh   (exit 0 = all pass)
# Witness for hooks/subagent-closeout.sh, including #363's tree discovery.

set -uo pipefail
# shellcheck source=bin/tests/lib/harness.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/../hooks/subagent-closeout.sh"
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
  printf '{"cwd":"%s","agent_transcript_path":"%s","stop_hook_active":false}' "$cwd" "$transcript"
}

run() { payload "$1" "${2:-}" | "$SCRIPT" 2>&1; }

# Hermetic PR half: $T/pr-state is what the tracker says.
mkdir -p "$T/bin"
cat > "$T/bin/gh" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *pulls/*) cat "$STUB_PR" 2>/dev/null || exit 1 ;;
esac
EOF
chmod +x "$T/bin/gh"
# The env prefixes bind to the SCRIPT, not `payload`: it is across the pipe.
runpr() { payload "$1" "${2:-}" | STUB_PR="$T/pr-state" PATH="$T/bin:$PATH" "$SCRIPT" 2>&1; }
rcof()  { payload "$1" "${2:-}" | STUB_PR="$T/pr-state" PATH="$T/bin:$PATH" "$SCRIPT" >/dev/null 2>&1; printf '%s' "$?"; }
transcript_pr() { printf 'opened https://github.com/hf7y/widget/pull/7 today\n' > "$1"; }

section "A. baseline behavior is unchanged"

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

section "B. #363 -- trees the subagent actually wrote to"

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

newrepo "$T/cwdrepo4"
echo scratch > "$T/cwdrepo4/dirty.txt"
transcript_writing "$T/t5.jsonl" "$T/cwdrepo4/dirty.txt"
B5_OUT="$(run "$T/cwdrepo4" "$T/t5.jsonl")"; B5_RC=$?
rc "B5 transcript re-naming cwd itself does not double-report" 2 "$B5_RC"
# space-or-EOL, not EOL alone: the fallback path (no closeout-lint on PATH,
# CI's case) appends " (N uncommitted change(s))" after the tree.
B5_COUNT="$(printf '%s\n' "$B5_OUT" | grep -cE "tree: $T/cwdrepo4( |\$)")"
eq "B5 cwd listed exactly once" "$B5_COUNT" "1"

echo
section "G. a PR this run opened, still open, is not a finished run"
G="$T/g"; newrepo "$G"
TR="$T/g-transcript"; transcript_pr "$TR"

printf 'open\tfalse\tNO-DECISION: x\n\n<!-- DELIVERS -->\n- none\n<!-- /DELIVERS -->' > "$T/pr-state"
OUT="$(runpr "$G" "$TR")"; RC="$(rcof "$G" "$TR")"
rc  "G1 an open non-draft PR blocks the stop" 2 "$RC"
has "G2 and names the PR" "$OUT" "pull/7"
has "G3 and says a draft is the honest way to stop" "$OUT" "convert it to a DRAFT"

printf 'open\ttrue\tNO-DECISION: x\n\n<!-- DELIVERS -->\n- none\n<!-- /DELIVERS -->' > "$T/pr-state"
RC="$(rcof "$G" "$TR")"
rc "G4 a DRAFT claims nothing, so it does not block" 0 "$RC"

printf 'closed\tfalse\tNO-DECISION: x' > "$T/pr-state"
RC="$(rcof "$G" "$TR")"
rc "G5 a merged or closed PR does not block" 0 "$RC"

printf 'open\tfalse\tNO-DECISION: no ledger here' > "$T/pr-state"
OUT="$(runpr "$G" "$TR")"
has "G6 an open PR with no DELIVERS block says nothing can check it" "$OUT" "no DELIVERS block"

: > "$T/pr-state"
RC="$(rcof "$G" "$TR")"
rc "G7 an unreadable tracker reports but does not block" 0 "$RC"

summary
[ "$fail" -eq 0 ] || exit 1
