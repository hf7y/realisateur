#!/usr/bin/env bash
# directive-prose.sh -- a decision written in prose must cite an issue.
#
# RUNNER: .github/workflows/tests.yml
# GUARD-TEST: bin/tests/directive-prose.test.sh
# GATE: none -- cli-guard.sh exits 2 under guard-estate's stripped sandbox
#
# TRAPS (the rest of this header is in the vault):
# THE PATTERNS ARE THE WHOLE DESIGN, and they are narrow on purpose. Derived
# 2026-08-15 by grepping the estate (baudin crt realisateur senechal wtul
# maitre) for every candidate and reading the hits. Rejected, with counts,
# because a guard nobody can satisfy gets bypassed:
#   deliberately 559, DO NOT 241, on purpose 128, decided 112 -- ordinary
#   explanatory prose; "for now" 35 -- hedging ("fine for now"), never a
#   decision; "was wrong" 35 -- usually a lesson about a bug, not a directive;
#   TODO 28 / FIXME 0 -- a deferral marker, and bin/lib/body-grammar.sh's
#   NO-DESTINATION rule already says plainly that it does not count as one.
# Kept: Zach-directed 82, an attributed date 63, SUPERSEDED 38, CORRECTED 35,
#   "stopped being true" 5, "not acted on" 3, un-pause 2.
#
# usage:  directive-prose.sh [<range>]
# exit:   0  no uncited decision prose was added

set -uo pipefail

CLI_NAME='directive-prose.sh'
CLI_SUMMARY='does this diff record a decision in prose without citing an issue?'
CLI_USAGE='  directive-prose.sh          check $(git merge-base HEAD origin/main)..HEAD
  directive-prose.sh <range>  check an explicit range, e.g. main..HEAD'
CLI_FLAGS=''
CLI_EXITS='  0  no uncited decision prose was added
  1  an added line records a decision and cites no issue
  3  the range or the diff could not be read -- NEVER "I looked and found nothing"'
CLI_POSITIONAL=any
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

die3() { printf '%s: %s\n' "$CLI_NAME" "$*" >&2; exit 3; }

[ $# -le 1 ] || die3 "takes at most one argument (a ref range), got $#"
git rev-parse --git-dir >/dev/null 2>&1 || die3 "BLIND -- not inside a git repository. Nothing was scanned."

RANGE="${1:-}"
if [ -z "$RANGE" ]; then
  git rev-parse --verify -q origin/main >/dev/null 2>&1 || \
    die3 "BLIND -- no origin/main to compare against; fetch it, or pass a range explicitly. Nothing was scanned."
  BASE="$(git merge-base HEAD origin/main 2>/dev/null)" || BASE=''
  [ -n "$BASE" ] || die3 "BLIND -- HEAD and origin/main have no merge base; pass a range explicitly. Nothing was scanned."
  RANGE="$BASE..HEAD"
fi

ERR="$(mktemp)"; trap 'rm -f "$ERR"' EXIT
DIFF="$(git diff -U3 "$RANGE" -- 2>"$ERR")" || \
  die3 "BLIND -- cannot read the diff for '$RANGE': $(tr '\n' ' ' < "$ERR"). Nothing was scanned."

# One pattern list, one citation pattern, read by the awk program below.
PATTERNS='recorded rather than acted|not acted on|left to rot|Zach-directed|Zach[ ,-]+(said|answered|directed|20[0-9][0-9]-[0-9]{2}-[0-9]{2})|per Zach|SUPERSEDED|CORRECTED|stopped being true|un-?pause|UN-PAUSE|resume (on|after)[ :]|RESUME:'
CITE='(^|[^A-Za-z0-9_/])([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)?#[0-9]+'

printf 'directive-prose -- %s\n' "$RANGE"

hits="$(printf '%s\n' "$DIFF" | awk -v pat="$PATTERNS" -v cite="$CITE" '
  # Buffer each hunk with its context so "adjacent" means adjacent in the
  # file, not merely adjacent among added lines.
  function flush(   i, j, lo, hi, ok) {
    # The file that DEFINES the patterns cannot be its own violation.
    if (file ~ /directive-prose/) { n = 0; return }
    for (i = 1; i <= n; i++) {
      if (kind[i] != "+") continue
      if (text[i] !~ pat) continue
      lo = i - 3; hi = i + 3; ok = 0
      if (lo < 1) lo = 1
      if (hi > n) hi = n
      for (j = lo; j <= hi; j++) if (text[j] ~ cite) { ok = 1; break }
      if (!ok) printf "%s\t%d\t%s\n", file, lineno[i], text[i]
    }
    n = 0
  }
  /^diff --git /  { flush(); file = $NF; sub(/^b\//, "", file); next }
  /^@@ /          { flush(); split($3, a, ","); cur = a[1] + 0; next }
  /^(\+\+\+|---)/ { next }
  /^[+ -]/ {
    k = substr($0, 1, 1); t = substr($0, 2)
    if (k == "-") next                       # deletions are free
    n++; kind[n] = (k == "+" ? "+" : " "); text[n] = t; lineno[n] = cur; cur++
    next
  }
  END { flush() }
')"

if [ -z "$hits" ]; then
  # Never a pass-by-silence: say what was read.
  printf '  no added line records a decision without citing an issue.\n'
  exit 0
fi

printf '%s\n' "$hits" | while IFS=$'\t' read -r f l t; do
  printf '  FLAG %s:%s\n        %s\n' "$f" "$l" "$t"
done
printf '  A decision recorded only in prose has no consumer (hf7y/crt#39).\n'
printf '  Cite the issue it lives in -- `#123` or `owner/repo#123`, on the line\n'
printf '  or within three lines of it -- or delete the prose.\n'
exit 1
