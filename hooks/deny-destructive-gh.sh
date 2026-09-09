#!/usr/bin/env bash
set -uo pipefail  # hooks/deny-destructive-gh.sh: PreToolUse guard on Bash (#1128) -- refuse repository deletion and auth-scope widening wherever the flag sits in the command line, and do not refuse PROSE that merely quotes one
#
# WHY A HOOK AND NOT ONLY A DENY RULE: a permission rule matches a PREFIX, so
# `gh api -X DELETE repos/x` is caught and `gh api repos/x -X DELETE` is not.
# This reads the whole command. 2026-09-01: an agent issued the second shape
# against a live repository to prove it lacked the scope to.
#
# WHY IT NO LONGER READS THE WHOLE STRING (#1128): matching raw text made the
# guard's own false-positive surface "writing about destructive commands" --
# which is what an issue, a runbook or a test about this guard has to do. It
# fired three times on 2026-09-01/02 and twice more while #1128 was being
# filed. Each refusal killed the entire tool call, so a `--body-file` whose
# file was written by a heredoc in the same command lost the heredoc too: the
# cost of a false positive was the whole payload, not a re-run.
#
# The pattern is still DELIBERATELY BROAD. What narrowed is the INPUT: a
# single-quoted heredoc body (`<<'EOF'`) is literal data by shell grammar --
# no expansion, no substitution -- so it is excised before matching, but only
# when nothing in the surviving command line could feed it to an interpreter.
# Every other quoting form still matches in full, because `bash -c '...'` is
# the bypass a narrower match would open. If the excision cannot be made
# safely, the whole string is matched, exactly as before.
#
# NOT A SANDBOX: prose written to a file here and executed by a LATER call is
# not caught, and never was -- the Write tool is not gated at all. This guard
# catches the verb in a command line, which is where it has actually appeared.
#
# RUNNER: ~/.claude/settings.json (PreToolUse|Bash), wired by
# bin/selfdev-hooks-provision.sh
# GUARD-TEST: bin/tests/deny-destructive-gh.test.sh

payload="$(cat 2>/dev/null)" || exit 0

command -v jq >/dev/null 2>&1 || {
  # LOUD, NOT SILENT: a `|| exit 0` here is the estate's signature defect --
  # the guard that could not look reports the same as the guard that passed.
  echo "deny-destructive-gh: jq is not installed -- this command was NOT checked" >&2
  exit 1
}

cmd="$(jq -r '.tool_input.command // ""' <<<"$payload" 2>/dev/null)" || exit 0
[ -n "$cmd" ] || exit 0

deny() {
  jq -cn --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",
    permissionDecision:"deny", permissionDecisionReason:$r}}'
  exit 0
}

# ---- what gets matched -------------------------------------------------
# Split the command into CODE (everything the shell will run) and literal
# heredoc bodies. Only a body whose delimiter is quoted -- `<<'EOF'` or
# `<<\EOF` -- is dropped; an unquoted or double-quoted delimiter still
# expands, so those bodies stay in CODE. A mis-parse therefore fails toward
# keeping text, never toward dropping it.
code="$(awk '
  n > 0 {
    line = $0
    if (T[1]) sub(/^\t+/, "", line)
    if (line == D[1]) {
      for (i = 1; i < n; i++) { D[i] = D[i+1]; L[i] = L[i+1]; T[i] = T[i+1] }
      n--; next
    }
    if (!L[1]) print
    next
  }
  {
    print
    s = $0
    while (match(s, /<<-?[[:space:]]*('"'"'[^'"'"']+'"'"'|"[^"]+"|\\[A-Za-z_][A-Za-z0-9_]*|[A-Za-z_][A-Za-z0-9_]*)/)) {
      tok = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
      dash = (tok ~ /^<<-/)
      d = tok; sub(/^<<-?[[:space:]]*/, "", d)
      lit = (substr(d, 1, 1) == "'"'"'" || substr(d, 1, 1) == "\\")
      gsub(/^['"'"'"\\]|['"'"'"]$/, "", d)
      n++; D[n] = d; L[n] = lit; T[n] = dash
    }
  }
' <<<"$cmd")"

# An interpreter in the surviving code can run the body it was handed
# (`cat <<'"'"'EOF'"'"' | bash`, `ssh host <<'"'"'EOF'"'"'`), so the excision is off.
if [ "$code" != "$cmd" ] &&
   grep -qE '(^|[^[:alnum:]_./-])(bash|sh|zsh|ksh|dash|eval|source|\.|python[0-9.]*|perl|ruby|node|xargs|env|ssh|sudo|su|nohup|timeout|watch|script|docker|kubectl)([^[:alnum:]_-]|$)' <<<"$code"; then
  code="$cmd"
fi

SPLIT_HINT='If the phrase was PROSE, put it in a single-quoted heredoc (<<'"'"'EOF'"'"') with no interpreter in the same command line, or write the file with the Write tool -- either keeps the payload instead of losing it to this refusal.'

case "$code" in
  *gh*repo*delete*)  deny "Refused: repository deletion is not an agent action -- do it in the web UI Danger Zone. $SPLIT_HINT" ;;
  *gh*auth*refresh*) deny "gh auth refresh is refused. Widening a token scope is not an agent action. $SPLIT_HINT" ;;
esac

# `gh api` with a DELETE method, in any argument order.
case "$code" in
  *gh*api*)
    case "$code" in
      *-X\ DELETE*|*-X\ delete*|*--method\ DELETE*|*--method\ delete*|*-XDELETE*)
        deny "gh api with a DELETE method is refused. A destructive API call is never a probe; read the resource instead. $SPLIT_HINT" ;;
    esac ;;
esac
exit 0
