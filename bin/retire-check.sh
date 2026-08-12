#!/usr/bin/env bash
# retire-check.sh -- mechanizes /cloture step 3's "retire check" (#166):
# does the closing text name a problem it did not attach a URL to?
#
# realisateur#165, 2026-08-11: a `/cloture` close named a real defect with
# "Not something I fixed -- flagging it" and stopped there, with no issue/PR
# URL. cloture.md's step 3 already tells a session to grep its own closing
# text for exactly this shape by hand; this is that grep, as a script that
# actually runs instead of an instruction that can be skipped.
#
# FLOOR, NOT THE RULE -- same caveat cloture.md states about itself. This
# catches the common phrasings (deferred, BUSY, left undone, next session
# should, not fixed, flagging, didn't get to, out of scope for now, worth
# doing), not every paraphrase of "I found something and did not route it".
# realisateur#165's own sentence contained none of those words, so a text
# this shape would still slip past -- the human read at /cloture step 4
# stays the actual backstop.
#
# Usage: bin/retire-check.sh [<file>]   reads stdin if <file> is omitted
#   0  no problem-shaped line lacked a URL/"documented exception" on the
#      same line
#   1  at least one did -- each printed to stdout, one per line
set -uo pipefail

CLI_NAME='retire-check.sh'
CLI_SUMMARY='does the closing text name a problem without a URL next to it?'
CLI_USAGE='  retire-check.sh [<file>]   scan stdin (or <file>) for a problem-shaped
                              line with no URL/"documented exception" on it'
CLI_FLAGS=''
CLI_POSITIONAL=any
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

[ "$#" -le 1 ] || { echo "retire-check.sh: takes at most one file, got $#" >&2; exit 2; }
input="${1:-/dev/stdin}"
if [ "$#" -eq 1 ] && [ ! -r "$input" ]; then
  echo "retire-check.sh: cannot read '$input'" >&2
  exit 2
fi

# Same floor cloture.md names in its own "Retire check" paragraph.
PROBLEM_RE='deferred|BUSY|left undone|next session should|not fixed|flagging|didn.t get to|out of scope for now|worth doing'
URL_RE='https?://|documented exception'

found=0
while IFS= read -r line || [ -n "$line" ]; do
  printf '%s\n' "$line" | grep -qiE "$PROBLEM_RE" || continue
  printf '%s\n' "$line" | grep -qiE "$URL_RE" && continue
  echo "$line"
  found=1
done < "$input"

exit "$found"
