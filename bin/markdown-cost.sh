#!/usr/bin/env bash
# markdown-cost.sh -- give prose a price.
#
# WHY THIS EXISTS. On 2026-08-06 this ecosystem merged 26 pull requests and
# filed 42 issues, and a large share of the output was prose describing its own
# condition rather than mechanism that does anything. Zach, the same day:
# "Description needs a cost. Markdown needs a cost." Nothing measured that, so
# nothing resisted it -- a branch could be 90% new .md and pass every gate in
# bin/, because every gate in bin/ was built to catch a script that lies, not a
# document that merely exists.
#
# WHAT IT PRICES. Two things, both over ADDED lines only (deletions are free --
# reaping prose is the behaviour we want, not the one we tax):
#
#   1. THE RATIO. markdown-added / total-added. Over the threshold (default
#      30%, MARKDOWN_COST_MAX_PCT) the run exits 1 and names the ratio and
#      every file that contributed to the numerator. This is not a style
#      opinion; it is the one number that separates "a change, documented"
#      from "a document, with a change attached".
#
#   2. A NEW TOP-LEVEL *.md FILE. Editing an existing document is how a
#      record stays current. ADDING another one at the repository root is how
#      this repository got 40-odd of them, most written once and read never
#      (see PROSE-REAPING.md, which is itself one of them). Any new root .md
#      outside the allowlist exits 1 on its own, whatever the ratio says.
#
# THE ONE BUG IT MUST NOT HAVE. In this ecosystem "found nothing" has
# repeatedly been reported as "nothing is wrong" -- a survey that reached zero
# projects printing a tidy summary and exiting 0 (see bin/lib/conf.sh's header
# for the propagation case that reached NOBODY). So every path here that cannot
# resolve the range, cannot read the diff, or cannot classify a file exits 2 and
# says which. Exit 0 from this script means one specific thing: the diff was
# read, the added lines were counted, and the count came in under the price.
# It never means the script could not tell.
#
# Usage:
#   markdown-cost.sh                 price $(git merge-base HEAD origin/main)..HEAD
#   markdown-cost.sh <range>         price an explicit range, e.g. main..HEAD
#   MARKDOWN_COST_MAX_PCT=50 markdown-cost.sh
set -uo pipefail

CLI_NAME='markdown-cost.sh'
CLI_SUMMARY='what fraction of this branch is prose, and did it add another root document?'
CLI_USAGE='  markdown-cost.sh            price $(git merge-base HEAD origin/main)..HEAD
  markdown-cost.sh <range>    price an explicit range, e.g. main..HEAD'
CLI_FLAGS=''
CLI_EXITS='  0  the diff was read and priced, and it came in under the threshold
  1  over the markdown ratio, or it adds a new top-level *.md file
  2  the range could not be resolved, the diff could not be read, or a file
     could not be classified -- NEVER "I looked and found nothing"'
CLI_POSITIONAL=any
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

# --- the allowlist, in ONE place ---------------------------------------------
# Read from here by both call sites (the ratio's numerator and the new-root-
# document check). Retyping it per call site is how the two checks drift apart
# and one of them starts taxing CLAUDE.md while the other does not.
# Patterns are glob patterns matched against the repo-relative path.
MD_ALLOW=( 'README.md' 'CLAUDE.md' 'man/*' )

md_allowlisted() { # <path> -> 0 if the allowlist covers it
  local pat
  for pat in "${MD_ALLOW[@]}"; do
    # shellcheck disable=SC2254 -- the pattern is meant to glob
    case "$1" in $pat) return 0 ;; esac
  done
  return 1
}

md_is_markdown() { # <path> -> 0 if this file is prose we price
  case "$1" in *.md|*.markdown) return 0 ;; esac
  return 1
}

md_is_top_level() { # <path> -> 0 if the path has no directory component
  case "$1" in */*) return 1 ;; *) return 0 ;; esac
}

die2() { printf '%s: %s\n' "$CLI_NAME" "$*" >&2; exit 2; }

MAX_PCT="${MARKDOWN_COST_MAX_PCT:-30}"
case "$MAX_PCT" in
  ''|*[!0-9]*) die2 "MARKDOWN_COST_MAX_PCT must be a whole number of percent, got '$MAX_PCT'" ;;
esac

# --- resolve the range -------------------------------------------------------
[ $# -le 1 ] || die2 "takes at most one argument (a ref range), got $#"
git rev-parse --git-dir >/dev/null 2>&1 || die2 "not inside a git repository"

RANGE="${1:-}"
if [ -z "$RANGE" ]; then
  # The default is deliberately merge-base and not `origin/main..HEAD`: the
  # latter also prices whatever landed on main since this branch was cut, which
  # is somebody else's prose and not this branch's bill.
  git rev-parse --verify -q origin/main >/dev/null 2>&1 || \
    die2 "no origin/main to compare against -- fetch it, or pass a range explicitly"
  BASE="$(git merge-base HEAD origin/main 2>/dev/null)" || BASE=''
  [ -n "$BASE" ] || die2 "HEAD and origin/main have no merge base -- pass a range explicitly"
  RANGE="$BASE..HEAD"
fi

ERR="$(mktemp)"; trap 'rm -f "$ERR"' EXIT

NUMSTAT="$(git diff --numstat "$RANGE" -- 2>"$ERR")" || \
  die2 "cannot read the diff for '$RANGE': $(tr '\n' ' ' < "$ERR")"
NAMESTATUS="$(git diff --name-status --diff-filter=A "$RANGE" -- 2>"$ERR")" || \
  die2 "cannot list added files for '$RANGE': $(tr '\n' ' ' < "$ERR")"

# --- count -------------------------------------------------------------------
total_added=0
md_added=0
md_files=''
binary_files=''

while IFS=$'\t' read -r added _deleted path; do
  [ -n "${path:-}" ] || continue
  case "$added" in
    -)  # A binary file has no line count. It is classifiable (not markdown)
        # but not countable, so it contributes nothing and is reported by name
        # rather than silently folded into the denominator.
        binary_files="$binary_files $path"
        continue ;;
    ''|*[!0-9]*)
        die2 "cannot classify the diff: unparseable numstat added-count '$added' for '$path'" ;;
  esac
  total_added=$((total_added + added))
  if md_is_markdown "$path" && ! md_allowlisted "$path"; then
    md_added=$((md_added + added))
    md_files="$md_files $path:$added"
  fi
done <<EOF
$NUMSTAT
EOF

# --- report ------------------------------------------------------------------
printf 'markdown-cost -- %s\n' "$RANGE"
[ -z "$binary_files" ] || printf '  note: binary file(s) not line-counted:%s\n' "$binary_files"

rc=0

# 1. new top-level documents
new_root_md=''
while IFS=$'\t' read -r _status path; do
  [ -n "${path:-}" ] || continue
  md_is_markdown "$path" || continue
  md_is_top_level "$path" || continue
  md_allowlisted "$path" && continue
  new_root_md="$new_root_md $path"
done <<EOF
$NAMESTATUS
EOF

if [ -n "$new_root_md" ]; then
  printf '  FLAG [new-root-document] this diff adds a new top-level *.md file:%s\n' "$new_root_md"
  printf '        Editing an existing document is free. Adding another root document\n'
  printf '        is not -- put it under a directory, or fold it into one that exists.\n'
  printf '        allowlist: %s\n' "${MD_ALLOW[*]}"
  rc=1
fi

# 2. the ratio
if [ "$total_added" -eq 0 ]; then
  # NOT a pass-by-silence: say plainly that there was nothing to price, so this
  # line can never be read as "the prose was checked and was fine".
  printf '  0 added line(s) in this range -- nothing to price.\n'
else
  pct=$(( md_added * 100 / total_added ))
  printf '  %d of %d added line(s) are markdown -- %d%% (threshold %d%%)\n' \
    "$md_added" "$total_added" "$pct" "$MAX_PCT"
  if [ $(( md_added * 100 )) -gt $(( MAX_PCT * total_added )) ]; then
    printf '  FLAG [markdown-ratio] %d%% of the added lines are prose, over the %d%% threshold.\n' \
      "$pct" "$MAX_PCT"
    printf '        contributing file(s) (path:added-lines):\n'
    for f in $md_files; do printf '          %s\n' "$f"; done
    printf '        Prose that describes mechanism is cheaper than the mechanism.\n'
    printf '        Either the mechanism is missing, or the description outran it.\n'
    rc=1
  fi
fi

[ "$rc" -eq 0 ] && printf '  ok -- priced, and under the threshold.\n'
exit "$rc"
