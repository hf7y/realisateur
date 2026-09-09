#!/usr/bin/env bash
set -uo pipefail  # bin/tests/deny-destructive-gh.test.sh: witness for hooks/deny-destructive-gh.sh (#1128)
#
# This suite is itself the false positive the guard used to have: every case
# below quotes a destructive command as DATA. It is written with printf and
# single-quoted heredocs so the file can be authored under the guard it tests.
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
SCRIPT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)/hooks/deny-destructive-gh.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

harness_tmp

# The command under test goes in a file, so no destructive phrase is ever
# typed on a command line this suite runs.
run() { # run <file-holding-the-command>  -> the hook's stdout
  jq -Rs '{tool_name:"Bash",tool_input:{command:.}}' <"$1" | "$SCRIPT" 2>&1
}
verdict() { # verdict <file> -> deny|allow
  local out; out="$(run "$1")"
  case "$out" in *'"deny"'*) printf 'deny' ;; *) printf 'allow' ;; esac
}

DEL='delete'; REPO='repo'; REFRESH='refresh'   # split so this suite is not its own subject

section "A. the destructive shapes are still refused"

printf 'gh %s %s hf7y/realisateur --yes\n' "$REPO" "$DEL" > "$T/a1"
eq "A1 gh repo delete is refused" "$(verdict "$T/a1")" deny

printf 'gh api repos/hf7y/realisateur -X DELETE\n' > "$T/a2"
eq "A2 -X DELETE AFTER the path is refused -- the shape a prefix rule misses" "$(verdict "$T/a2")" deny

printf 'gh api -XDELETE repos/hf7y/realisateur\n' > "$T/a3"
eq "A3 -XDELETE, no space" "$(verdict "$T/a3")" deny

printf 'gh api repos/x --method delete\n' > "$T/a4"
eq "A4 --method delete, lowercase" "$(verdict "$T/a4")" deny

printf 'gh auth %s --scopes %s_%s\n' "$REFRESH" "$DEL" "$REPO" > "$T/a5"
eq "A5 gh auth refresh is refused" "$(verdict "$T/a5")" deny

section "B. quoting does not buy a bypass"

printf "bash -c 'gh %s %s hf7y/realisateur'\\n" "$REPO" "$DEL" > "$T/b1"
eq "B1 the verb inside bash -c is still seen" "$(verdict "$T/b1")" deny

printf 'gh api "repos/x" \x27-X DELETE\x27\n' > "$T/b2"
eq "B2 a quoted flag is still seen" "$(verdict "$T/b2")" deny

cat > "$T/b3" <<'EOF'
cat <<EOT > /tmp/x
gh repo delete hf7y/realisateur
EOT
EOF
eq "B3 an UNQUOTED heredoc delimiter still expands, so its body is still matched" "$(verdict "$T/b3")" deny

cat > "$T/b4" <<'EOF'
cat <<"EOT" > /tmp/x
gh repo delete hf7y/realisateur
EOT
EOF
eq "B4 a double-quoted delimiter expands too" "$(verdict "$T/b4")" deny

cat > "$T/b5" <<'EOF'
cat <<'EOT' | bash
gh repo delete hf7y/realisateur
EOT
EOF
eq "B5 a literal body PIPED TO AN INTERPRETER is matched in full" "$(verdict "$T/b5")" deny

cat > "$T/b6" <<'EOF'
ssh dexter <<'EOT'
gh repo delete hf7y/realisateur
EOT
EOF
eq "B6 same when the interpreter is remote" "$(verdict "$T/b6")" deny

section "C. prose about the guard is NOT refused -- #1128's cost"

cat > "$T/c1" <<'EOF'
cat > /tmp/body.md <<'BODY'
deny-destructive-gh.sh refuses `gh repo delete` and `gh api -X DELETE`.
BODY
gh issue create --title x --body-file /tmp/body.md
EOF
eq "C1 the exact shape that lost #1128's heredoc twice" "$(verdict "$T/c1")" allow

cat > "$T/c2" <<'EOF'
tee -a notes.txt <<-'BODY'
	gh repo delete is not an agent action
	BODY
EOF
eq "C2 <<-'D' with tab-stripped delimiter" "$(verdict "$T/c2")" allow

cat > "$T/c3" <<'EOF'
cat > a <<'ONE'
gh repo delete x
ONE
cat > b <<'TWO'
gh api -X DELETE repos/x
TWO
EOF
eq "C3 two literal heredocs in one command" "$(verdict "$T/c3")" allow

printf 'grep -rn "gh %s %s" hooks/\n' "$REPO" "$DEL" > "$T/c4"
eq "C4 KNOWN AND ACCEPTED: grepping for the phrase is still refused -- a bare quoted argument is indistinguishable from bash -c" "$(verdict "$T/c4")" deny

section "D. the refusal names a recovery that keeps the payload"

OUT="$(run "$T/a1")"
has "D1 the deny reason points at the quoted heredoc" "$OUT" "single-quoted heredoc"
has "D2 and at the Write tool, which this hook does not gate" "$OUT" "Write tool"

section "E. harmless input"

printf 'gh issue list --state open\n' > "$T/e1"
eq "E1 an ordinary gh read" "$(verdict "$T/e1")" allow

printf 'gh api repos/hf7y/realisateur/branches/main/protection\n' > "$T/e2"
eq "E2 gh api with no method flag" "$(verdict "$T/e2")" allow

printf 'git branch -D %s-old\n' "$REPO" > "$T/e3"
eq "E3 this guard is about gh, not git" "$(verdict "$T/e3")" allow

printf 'echo $(( 1 << 4 ))\n' > "$T/e4"
eq "E4 a left shift is not a heredoc" "$(verdict "$T/e4")" allow

printf '' > "$T/e5"
eq "E5 an empty command" "$(verdict "$T/e5")" allow

section "F. it cannot report clean when it could not look"

# A PATH with the tools the hook needs and no jq -- `env`, `bash` and the rest
# have to be reachable or the shebang itself would be the thing that failed.
FAKEBIN="$T/nojq"; mkdir -p "$FAKEBIN"
for t in env bash cat grep awk sed; do ln -sf "$(command -v "$t")" "$FAKEBIN/$t"; done
printf '{"tool_name":"Bash","tool_input":{"command":"gh issue list"}}' > "$T/f-payload"
OUT="$(PATH="$FAKEBIN" "$SCRIPT" <"$T/f-payload" 2>&1)"; RC=$?
rc "F1 no jq is a NON-ZERO exit, not a silent pass" 1 "$RC"
has "F2 and it says the command was not checked" "$OUT" "NOT checked"

summary
