#!/usr/bin/env bash
# amend.sh -- the four-step contract-change gate.
#
# Changing a promise is a different act from keeping one. This mechanises the
# four steps that were previously run by hand, and could therefore be skipped
# by hand. Written 2026-07-30 at its own exit-4 call site, the same way
# `check` was.
#
# It does NOT perform the edit. The caller edits the page; this decides
# whether that edit is allowed to stand. The distinction matters: a gate that
# also writes is a gate that can be satisfied by its own output.
#
# usage: amend.sh <page> <reason>
# exit:  0 all four gates passed   2 usage   5 broken   6 blind
#        7 a gate failed -- the amendment failed, which is not this tool failing

set -uo pipefail

SELF="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"   # bashify/
# ONE reader for PROJECT_REPO_PATH, shared with bin/'s scripts (#143).
. "$(cd "$SELF/.." && pwd)/bin/lib/conf.sh"
CHECK_IMPL="$SELF/lib/check.sh"
SCHED="${BASHIFY_SCHED:-${SCHED_ROOT:-${INSTALLE_PROJECTS:-$HOME/Documents/Projects}/scheduler}}"

PAGE="${1:-}"
REASON="${2:-}"

die()   { printf 'amend: %s\n' "$*" >&2; exit 2; }
blind() { printf 'amend: BLIND: %s\n' "$*" >&2
          printf 'amend: this is "I cannot see", NOT "nothing to report".\n' >&2
          exit 6; }
broke() { printf 'amend: BROKEN: %s\n' "$*" >&2; exit 5; }

# amend_repo_slug <path> -- "owner/repo", normalised off `origin`'s URL.
# Same shape as scheduler's lib/run-record.sh:run_record_repo_slug (#158),
# reimplemented here rather than sourced because that lib lives in a
# different project's repo. Matches github.com and the self-dev SSH host
# aliases (github-<account>), so a plain https clone and an aliased ssh clone
# of the same GitHub repo resolve to the same slug. Prints nothing and
# returns 1 for a remote this can't place -- callers must treat empty as
# "unknown", not as a slug that matches nothing.
amend_repo_slug() {
  local url; url="$(git -C "$1" remote get-url origin 2>/dev/null)" || return 1
  case "$url" in
    *github.com*|*github-*) ;;
    *) return 1 ;;
  esac
  printf '%s' "$url" | sed -E 's#^.*[:/]([^/:]+/[^/]+)$#\1#; s#\.git$##'
}

[ -n "$PAGE" ]   || die "usage: amend <page> <reason>"
[ -n "$REASON" ] || die "the first gate is a STATED REASON. Pass it as the second argument."
[ -f "$PAGE" ]   || blind "no such page: $PAGE"

VERB="$(basename "$PAGE" .1)"
PAGEDIR="$(cd "$(dirname "$PAGE")" && pwd)"
REPO="$(git -C "$PAGEDIR" rev-parse --show-toplevel 2>/dev/null)" \
  || blind "$PAGE is not inside a git repository, so no previous page can exist"
REL="${PAGEDIR#"$REPO"/}/$(basename "$PAGE")"

FAILED=0
gate_pass() { printf 'PASS  %-10s %s\n' "$1" "$2"; }
gate_fail() { printf 'FAIL  %-10s %s\n' "$1" "$2"; FAILED=1; }

printf '=== amendment gate: %s\n' "$REL"
printf '    verb: %s\n\n' "$VERB"

# ---- gate 1: a stated reason ----------------------------------------------
# What the tool learned that the page did not know. A reason that merely says
# the tool cannot do the thing is the failure this whole gate exists to catch:
# that case is exit 4 and a GAPS.md line, never a page edit.
if [ "${#REASON}" -lt 24 ]; then
  gate_fail 'REASON' "too short to be a reason (${#REASON} chars); say what the tool learned"
elif printf '%s' "$REASON" | grep -qiE "(could|can)( ?n[o']?t|not) (do|implement|build|manage)|too hard|not feasible|gave up"; then
  gate_fail 'REASON' 'reads as "the tool cannot do it" -- that is exit 4 and a GAPS.md line, not a page edit'
else
  gate_pass 'REASON' "stated (${#REASON} chars)"
fi

# ---- gate 2: the previous page preserved ----------------------------------
# Preserved means "in version control", not "in a .bak file". If the page is
# untracked, there is no previous promise to compare against and the change is
# invisible to a reader.
if ! git -C "$REPO" ls-files --error-unmatch -- "$REL" >/dev/null 2>&1; then
  gate_fail 'PRESERVED' "$REL is untracked; the previous page is not in version control"
elif git -C "$REPO" diff --quiet -- "$REL" && git -C "$REPO" diff --cached --quiet -- "$REL"; then
  gate_fail 'PRESERVED' "$REL is unmodified; there is no amendment to gate"
else
  PREV="$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null)"
  gate_pass 'PRESERVED' "previous page is at $PREV; this edit is uncommitted, so both texts exist"
fi

# ---- gate 3: a full re-run of the nine rows -------------------------------
# Against the NEW text. Amending a contract to match a broken implementation
# is the specific failure this catches, so the rows are re-run rather than
# assumed to still hold.
CMD="$REPO/bin/$VERB"
[ -x "$CMD" ] || CMD="$PAGEDIR/../bin/$VERB"
if [ ! -x "$CMD" ]; then
  gate_fail 'ROWS' "cannot find an executable for '$VERB' to score the new page against"
elif [ ! -x "$CHECK_IMPL" ]; then
  broke "the page test is missing at $CHECK_IMPL; the rows cannot be re-run"
else
  ROWS_OUT="$("$CHECK_IMPL" "$PAGE" "$CMD" 2>&1)"; ROWS_RC=$?
  ROWS_LINE="$(printf '%s\n' "$ROWS_OUT" | grep -E '^--- .*rows passed' | head -1)"
  if [ "$ROWS_RC" = 0 ]; then
    gate_pass 'ROWS' "${ROWS_LINE:-nine rows re-run against the new text}"
  else
    gate_fail 'ROWS' "the new text does not pass its own page test (check exit $ROWS_RC)"
    printf '%s\n' "$ROWS_OUT" | grep -E '^FAIL' | sed 's/^/        /'
  fi
fi

# ---- gate 4: callers checked ----------------------------------------------
# A changed promise breaks a downstream pipeline silently, and nothing
# currently looks. This is the half of the gate that most needed a machine.
# Prose mentioning the verb is not a caller; an invocation is.
INVOCATIONS=0; PROSE=0; SCANNED=0; UNREADABLE=0; SELFSKIP=0
OWNER_GITDIR="$(cd "$REPO" && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
OWNER_SLUG="$(amend_repo_slug "$REPO" || true)"
if [ ! -d "$SCHED/schedule" ]; then
  gate_fail 'CALLERS' "cannot read the project registry at $SCHED/schedule"
else
  for conf in "$SCHED"/schedule/*.conf; do
    [ -e "$conf" ] || continue
    proj="$(basename "$conf" .conf)"
    case "$proj" in _*) continue ;; esac
    path="$(conf_repo_path "$conf" || true)"
    [ -n "$path" ] && [ -d "$path/.git" ] || { UNREADABLE=$((UNREADABLE+1)); continue; }
    git -C "$path" rev-parse --verify -q origin/bashified >/dev/null 2>&1 || continue
    # Skip the project that OWNS the verb. Its own implementation, its own
    # test and its own GAPS.md all name it, and counting those as downstream
    # callers made every amendment to a real verb unpassable: `installe`
    # scored 6 invocations, all of them itself. Two independent tests, either
    # one enough (#115): common git dir catches a WORKTREE of the owner;
    # matching normalised `origin` slugs catches a CLONE of it, which a
    # common-git-dir test cannot -- a fresh `git clone` has its own git dir by
    # construction. Neither subsumes the other: a worktree can have no remote
    # of its own (falls through to the gitdir test), and a clone has no common
    # git dir with its origin (falls through to the slug test).
    if { [ -n "$OWNER_GITDIR" ] \
         && [ "$(cd "$path" && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" = "$OWNER_GITDIR" ]; } \
       || { [ -n "$OWNER_SLUG" ] && [ "$(amend_repo_slug "$path" || true)" = "$OWNER_SLUG" ]; }; then
      SELFSKIP=$((SELFSKIP+1)); continue
    fi
    SCANNED=$((SCANNED+1))
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      # hit is "<ref>:<file>:<lineno>:<content>". Take the file, because the
      # separator alphabet is NOT the same in a script and in prose, and strip
      # the line number, because leaving it on means the ^ anchor can never
      # match -- a bare invocation at the start of a line was invisible.
      file="${hit#*:}"; file="${file%%:*}"
      line="${hit#*:}"; line="${line#*:}"; line="${line#*:}"
      # An invocation is the verb in command position. Anything else is prose.
      # A backtick opens a command substitution in shell -- and quotes a NAME
      # in markdown. Counting the markdown case made the gate unsatisfiable:
      # documenting why a verb moved raised its caller count, so the only way
      # to pass was to delete the explanation. Prose gets the shell-free
      # separator alphabet.
      case "$file" in
        *.md|*.markdown|*.txt|*.1|*.rst) seps='[|;&(]' ;;
        *)                               seps='[|;&(`]' ;;
      esac
      # A COMMENT LINE IS PROSE, wherever it lives. Added 2026-08-01: the
      # backtick belongs to the shell alphabet above, so a script explaining
      # itself -- "# `bashify check` rules code 1 a reserve" -- scored as an
      # invocation of bashify. That is the same defect already fixed for
      # markdown two lines up, in the one place it was not looked for: prose
      # inside code. It made this gate unsatisfiable in the same way, since
      # the only way to pass was for another project to delete its comment.
      # A comment executes nothing; classifying it as a caller is a claim
      # about the file that reading the file refutes.
      case "$(printf '%s' "$line" | sed 's/^[[:space:]]*//')" in
        '#'*) PROSE=$((PROSE+1)); continue ;;
      esac
      if printf '%s' "$line" | grep -qE "(^|$seps|\\\$\()[[:space:]]*(\./)?(bin/)?$VERB([[:space:]]|$)"; then
        INVOCATIONS=$((INVOCATIONS+1))
        printf '        INVOCATION %s: %s\n' "$proj" "$(printf '%s' "$hit" | cut -c1-100)"
      else
        PROSE=$((PROSE+1))
      fi
    done <<<"$(git -C "$path" grep -w -n "$VERB" origin/bashified 2>/dev/null)"
  done
  if [ "$SCANNED" = 0 ]; then
    gate_fail 'CALLERS' 'no bashified branch could be searched; the caller question is UNANSWERED, which is not the same as "no callers"'
  elif [ "$INVOCATIONS" -gt 0 ]; then
    gate_fail 'CALLERS' "$INVOCATIONS invocation(s) of '$VERB' across $SCANNED branch(es) -- a changed promise breaks them silently"
  else
    gate_pass 'CALLERS' "$SCANNED branch(es) searched; $PROSE prose mention(s), 0 invocations"
  fi
fi
[ "$SELFSKIP" -gt 0 ] && printf "      note: %d branch(es) skipped as the verb's own project (self-reference is not a caller)\n" "$SELFSKIP"
[ "$UNREADABLE" -gt 0 ] && printf '      note: %d registered project(s) had no readable repository\n' "$UNREADABLE"

# ---- verdict ---------------------------------------------------------------
printf '\n'
if [ "$FAILED" = 0 ]; then
  printf -- '--- amendment ALLOWED: all four gates passed\n'
  printf '    state the reason in the commit message; git holds the previous page.\n'
  exit 0
fi
printf -- '--- amendment REFUSED: at least one gate failed\n'
exit 7
