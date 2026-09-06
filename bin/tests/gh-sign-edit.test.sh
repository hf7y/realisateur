#!/usr/bin/env bash
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
harness_tmp

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GS="$HERE/../gh-sign.sh"
BASH_BIN="$(command -v bash)"

mkdir -p "$T/stub"
cat > "$T/stub/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
: > "$GH_LAST_BODY"
prev=''
for a in "$@"; do
  case "$prev" in --body|--comment) printf '%s' "$a" > "$GH_LAST_BODY" ;; esac
  prev="$a"
done
printf '%s\n' "$*" | grep -q -- '--body-file -' && cat > "$GH_LAST_BODY"
prev=''
for a in "$@"; do
  case "$a" in
    body=@-)
      case "$prev" in
        -F|--field) cat > "$GH_LAST_BODY" ;;
        *) printf '%s' "$a" > "$GH_LAST_BODY" ;;
      esac ;;
    body=*) printf '%s' "${a#body=}" > "$GH_LAST_BODY" ;;
  esac
  prev="$a"
done
exit "${GH_EXIT:-0}"
STUB
chmod +x "$T/stub/gh"

run() {
  : > "$T/gh.log"; : > "$T/gh.body"
  GH_LOG="$T/gh.log" GH_LAST_BODY="$T/gh.body" \
  CLAUDECODE=1 PATH="$T/stub:$PATH" "$BASH_BIN" "$GS" "$@" >/dev/null 2>"$T/err"
  echo $?
}
lastline() { grep -v '^[[:space:]]*$' "$T/gh.body" | tail -1; }

GOOD='NO-DECISION: nothing to weigh

<!-- DEFERRED -->
- none
<!-- /DEFERRED -->

<!-- DELIVERS -->
- none
<!-- /DELIVERS -->'

echo "gh-sign issue/pr edit gate"

section "A. the CLI verb: issue edit / pr edit"

rcv="$(run issue edit 7 --repo hf7y/widget --body "$GOOD")"
rc "A1 a well-formed issue edit passes" 0 "$rcv"
case "$(lastline)" in
  '<!-- agent: '*'@'*' -->') ok "A2 ...and is signed, same as create" ;;
  *) bad "A2 ...and is signed, same as create" "last line: $(lastline)" ;;
esac

rcv="$(run issue edit 7 --repo hf7y/widget --body 'no declaration line at all')"
rc "A3 a malformed issue edit is REFUSED (7)" 7 "$rcv"
case "$(cat "$T/gh.log")" in
  '') ok "A4 ...and nothing reached gh" ;;
  *) bad "A4 ...and nothing reached gh" "got: $(cat "$T/gh.log")" ;;
esac

rcv="$(run pr edit 3 --repo hf7y/widget --body "$GOOD")"
rc "A5 a well-formed pr edit passes" 0 "$rcv"
case "$(lastline)" in
  '<!-- agent: '*) ok "A6 ...and is signed" ;;
  *) bad "A6 ...and is signed" "last line: $(lastline)" ;;
esac

rcv="$(run pr edit 3 --repo hf7y/widget --body 'no declaration line at all')"
rc "A7 a malformed pr edit is REFUSED (7)" 7 "$rcv"

rcv="$(run issue edit 7 --repo hf7y/widget --title 'just a retitle')"
rc "A8 an edit that touches no body at all still reaches gh (nothing to grade)" 0 "$rcv"
case "$(cat "$T/gh.log")" in
  *'issue edit 7'*) ok "A9 ...unmodified" ;;
  *) bad "A9 ...unmodified" "got: $(cat "$T/gh.log")" ;;
esac

section "B. the API route: gh api PATCH .../issues/<n> and .../pulls/<n>"

rcv="$(run api -X PATCH repos/hf7y/widget/issues/7 -f body="$GOOD")"
rc "B1 an api PATCH to the issue itself is graded, and passes when well-formed" 0 "$rcv"
case "$(lastline)" in
  '<!-- agent: '*) ok "B2 ...and is signed" ;;
  *) bad "B2 ...and is signed" "last line: $(lastline)" ;;
esac

rcv="$(run api -X PATCH repos/hf7y/widget/issues/7 -f body='no declaration line at all')"
rc "B3 the same route REFUSES a malformed body (7)" 7 "$rcv"
case "$(cat "$T/gh.log")" in
  '') ok "B4 ...and nothing reached gh" ;;
  *) bad "B4 ...and nothing reached gh" "got: $(cat "$T/gh.log")" ;;
esac

rcv="$(run api -X PATCH repos/hf7y/widget/pulls/3 -f body="$GOOD")"
rc "B5 a pull request PATCH is graded the same way" 0 "$rcv"
case "$(lastline)" in
  '<!-- agent: '*) ok "B6 ...and is signed" ;;
  *) bad "B6 ...and is signed" "last line: $(lastline)" ;;
esac

section "C. a plain read of the same path is untouched"

rcv="$(run api repos/hf7y/widget/issues/7 --jq .number)"
rc "C1 a GET to the issue path (no body field) reaches gh unrefused" 0 "$rcv"
case "$(cat "$T/gh.body" 2>/dev/null)" in
  '') ok "C2 ...and nothing was signed into it -- it carried no body to sign" ;;
  *) bad "C2 ...and nothing was signed into it" "got: $(cat "$T/gh.body")" ;;
esac

rcv="$(run api repos/hf7y/widget/issues/7/comments --jq '.[0]')"
rc "C3 listing comments (a read on the /comments path) still reaches gh" 0 "$rcv"

section "D. a human's edit passes through whole, unsigned"

: > "$T/gh.log"; : > "$T/gh.body"
env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT \
  GH_LOG="$T/gh.log" GH_LAST_BODY="$T/gh.body" PATH="$T/stub:$PATH" \
  script -qec "'$BASH_BIN' '$GS' issue edit 7 --repo hf7y/widget --body 'typed by hand, no grammar'" /dev/null \
  >/dev/null 2>&1
rc2=$?
if command -v script >/dev/null 2>&1; then
  rc "D1 a human at a TTY editing a malformed body is not refused" 0 "$rc2"
else
  echo "  SKIP  D1 human-at-keyboard: no \`script\` to allocate a pty" >&2
fi

summary
