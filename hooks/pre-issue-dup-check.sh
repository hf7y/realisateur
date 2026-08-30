#!/usr/bin/env bash
# pre-issue-dup-check.sh -- PreToolUse guard: search before you file.
#
# WHY. 2026-08-30, one session, three duplicates -- each filed while explaining
# why duplicates happen. #762 landed beside an open three-act plan (#740/#741/
# #742) that `gh issue list --search vault` returns in its top four. #792 landed
# FIVE MINUTES after #790, same finding. A supersession probe was built beside
# #754's merged floor. The search costs one second and was never run, so the
# fix is not to remember it -- it is to make `gh issue create` do it.
#
# CONTRACT. PreToolUse/Bash. Denies ONCE with the candidates listed; re-issue
# the same command with `# dup-checked` appended to proceed. A toll booth, not
# a wall: the override is documented here and in the refusal itself.
#
# FAILS OPEN, ALWAYS. No jq, no gh, no network, a search that errors or times
# out -> exit 0. A guard that blocks filing because it could not check is worse
# than the duplicate it was preventing.
set -uo pipefail

input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0
cmd="$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null)"
[ -n "$cmd" ] || exit 0

case "$cmd" in *"gh issue create"*) ;; *) exit 0 ;; esac
case "$cmd" in *"# dup-checked"*) exit 0 ;; esac        # the documented override

title="$(sed -n 's/.*--title[= ]\{1,\}\("\([^"]*\)"\|'"'"'\([^'"'"']*\)'"'"'\).*/\2\3/p' <<<"$cmd" | head -1)"
[ -n "$title" ] || exit 0

repo=""
case "$cmd" in *"--repo "*) repo="$(sed -n 's/.*--repo[= ]\{1,\}\([^ ]*\).*/\1/p' <<<"$cmd" | head -1)" ;; esac
[ -n "$repo" ] && repo="--repo $repo"

# Strip punctuation; the 6 longest words carry the signal. GitHub search ORs them.
terms="$(tr -cs '[:alnum:]' ' ' <<<"$title" | tr 'A-Z' 'a-z' | tr ' ' '\n' \
        | awk 'length($0)>4' | sort -u | head -6 | tr '\n' ' ')"
[ -n "${terms// }" ] || exit 0

hits="$(timeout 12 gh issue list $repo --state all --limit 6 --search "$terms" \
        --json number,state,title --jq '.[]|"  #\(.number) \(.state)  \(.title[0:72])"' 2>/dev/null)" || exit 0

# SHARED CITATIONS, not just shared words. #792 duplicated #790 and their titles
# had no word in common -- but both cited #754. An OPEN issue citing the same
# issue you are about to cite is the strongest duplicate signal there is.
bf="$(sed -n 's/.*--body-file[= ]\{1,\}\([^ ]*\).*/\1/p' <<<"$cmd" | head -1)"
cites=""
if [ -n "$bf" ] && [ -r "$bf" ]; then
  for n in $(grep -oE '#[0-9]{2,5}' "$bf" 2>/dev/null | tr -d '#' | sort -u | head -4); do
    m="$(timeout 8 gh issue list $repo --state open --limit 3 --search "$n in:body" \
         --json number,title --jq ".[]|\"  #\(.number) also cites #$n: \(.title[0:60])\"" 2>/dev/null \
         | grep -v "^  #$n " )"
    [ -n "$m" ] && cites="$cites$m
"
  done
fi
[ -n "$hits$cites" ] || exit 0
[ -n "$cites" ] && hits="$hits
$cites"

jq -n --arg h "$hits" --arg t "$terms" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: ("SEARCH BEFORE YOU FILE. Existing issues matching this title:\n\n" + $h +
      "\n\nsearched: " + $t +
      "\n\nIf one of these is the same finding, comment on it instead -- moving your unique content there and NOT filing a second issue. If yours is genuinely new, or adds a decision the existing one lacks, re-run the identical command with `# dup-checked` appended and it will proceed.")
  }
}'
