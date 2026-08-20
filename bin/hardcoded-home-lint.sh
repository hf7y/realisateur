#!/usr/bin/env bash
# hardcoded-home-lint.sh -- refuse an absolute path into a named user's home
# in executable code.
#
# RUNNER: bin/tests/hardcoded-home-lint.test.sh
# GUARD-TEST: bin/tests/hardcoded-home-lint.test.sh
# GATE: default
#
# THE FAILURE THIS EXISTS FOR. An absolute path into a named user's home reads
# as "you did not register it" on every other account, instead of "I looked in
# another user's home" -- the account looks empty rather than misconfigured,
# and the exit code that exists to say I-cannot-see is bypassed. Dispatch runs
# under uid 3000-3099, where $HOME is /home/<project>.
#
# COMMENTS ARE EXEMPT, deliberately. Every fix for this defect documents the
# old path in a comment above the new line, and flagging those would make the
# check fire loudest on exactly the files that already fixed it -- the guard
# crying wolf on its own successes, which is how guards get disabled.
#
# exit 0  no hardcoded home in code
# exit 1  at least one found -- named, with file and line
# exit 2  BLIND: could not scan (not a repo, no files matched). NEVER 0.
#         "Found nothing" and "nothing is wrong" are different answers, and
#         conflating them is the single most repeated fault in this ecosystem.
set -uo pipefail

ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$ROOT" ] && [ -d "$ROOT" ] || {
  echo "hardcoded-home-lint: BLIND: not a git repository and no path given" >&2
  exit 2
}

# WHAT COUNTS AS EXECUTABLE CODE IS THE SHEBANG, NOT THE FILENAME.
#
# This selected `'*.sh' 'bin/*'` until 2026-08-07, and that missed an entire
files=()
while IFS= read -r f; do
  case "$f" in archive/*) continue ;; esac
  [ -f "$ROOT/$f" ] || continue
  case "$f" in
    *.sh) files+=("$f"); continue ;;
  esac
  # `head -c2` and not `read`: a binary blob must not be slurped as a line.
  [ "$(head -c 2 -- "$ROOT/$f" 2>/dev/null)" = '#!' ] && files+=("$f")
done < <(git -C "$ROOT" ls-files 2>/dev/null | sort -u)
if [ "${#files[@]}" -eq 0 ]; then
  echo "hardcoded-home-lint: BLIND: matched zero tracked files under $ROOT" >&2
  echo "hardcoded-home-lint: this is 'I cannot see', NOT 'nothing to report'." >&2
  exit 2
fi

found=0
for f in "${files[@]}"; do
  p="$ROOT/$f"
  [ -f "$p" ] || continue
  # Strip full-line comments before matching. An inline trailing comment is
  # rare enough here that treating it as code is the safe direction: a false
  # positive costs a glance, a false negative costs another silent account.
  while IFS=: read -r n line; do
    [ -n "$n" ] || continue
    printf '%s:%s: %s\n' "$f" "$n" "$(printf '%s' "$line" | sed 's/^[[:space:]]*//')"
    found=1
  # An explicit opt-out must state a reason, so it cannot be pasted around as
  # a silencer: `# hardcoded-home-ok: <why>` on the same line.
  done < <(grep -nE '/home/[a-z][a-z0-9_-]*/' "$p" 2>/dev/null \
           | grep -vE '^[0-9]+:[[:space:]]*#' \
           | grep -vE '# *hardcoded-home-ok: *[^ ]')
done

if [ "$found" = 1 ]; then
  echo >&2
  echo "hardcoded-home-lint: absolute path into a named user's home, in code." >&2
  echo "  Resolve it instead, the way six scripts in this repo already do:" >&2
  echo '    "${SCHED_ROOT:-${INSTALLE_PROJECTS:-$HOME/Documents/Projects}/scheduler}"' >&2
  echo "  A path under one user's home is not a default; it is a machine that" >&2
  echo "  happens to be yours." >&2
  exit 1
fi
echo "hardcoded-home-lint: ${#files[@]} tracked files, no hardcoded home in code."
