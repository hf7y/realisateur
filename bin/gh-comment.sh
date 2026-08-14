#!/usr/bin/env bash
# gh-comment.sh -- post a GitHub issue comment as this project's own
# automation, with the provenance stamp appended automatically.
#
# hf7y/realisateur#238: hf7y/ecosim#40 found that this project's automation
# has never once stamped a comment it posted as `hf7y`. lib/sensors/blocked.py
# (ecosim) can't tell an agent's own reply apart from a genuine answer from
# Zach in the same shared-token comment history without one, and reports
# BLIND_NO_STAMP_DISCIPLINE for a project instead of a real ratio.
#
# The predicate that reads the stamp (`is_stamped`, last non-blank line
# only, so a stamp quoted mid-body from another comment does not count) is
# hf7y/vim-arcade#77's; ecosim's `bin/gh-comment` / `lib/provenance.py`
# (commit 32fd897) is a working reimplementation this script mirrors --
# reused as a CONVENTION, not a shared library, since cross-repo imports run
# the wrong direction here.
#
# Route every comment this project's code posts through this instead of a
# bare `gh issue comment` / `gh issue close --comment`, and the stamp stops
# being optional.
#
# USAGE
#   gh-comment.sh <owner/repo> <issue> <job> --body TEXT
#   gh-comment.sh <owner/repo> <issue> <job> --body-file FILE
#   <producer> | gh-comment.sh <owner/repo> <issue> <job> -
#   add --close to close the issue with this comment, in one call
#
#   <job> is the second half of the stamp (<project>/<job>): the run or
#   script doing the posting, e.g. `queue-triage`, `tick`. <project> is
#   taken from <owner/repo>'s repo name, not passed separately.
#
# EXIT CODES
#   0  posted (and closed, if --close)
#   1  gh refused -- bad repo/issue, or the post/close failed
#   2  usage error
#   6  BLIND -- gh is not on PATH; nothing was posted
set -uo pipefail

CLI_NAME='gh-comment.sh'
CLI_SUMMARY='post a GitHub issue comment as this project, stamped with agent provenance'
CLI_USAGE='  gh-comment.sh <owner/repo> <issue> <job> --body TEXT
  gh-comment.sh <owner/repo> <issue> <job> --body-file FILE
  <producer> | gh-comment.sh <owner/repo> <issue> <job> -
  add --close to close the issue with this comment'
CLI_FLAGS='--body --body-file --close'
CLI_POSITIONAL=any
CLI_EXITS='  0  posted (and closed, if --close)
  1  gh refused -- bad repo/issue, or the post/close failed
  2  usage error
  6  BLIND -- gh is not on PATH; nothing was posted'
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/cli-guard.sh"
cli_guard "$@"

have() { command -v "$1" >/dev/null 2>&1; }

BODY=''; BODY_SET=0; CLOSE=0
declare -a POS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --body)      BODY="${2:-}"; BODY_SET=1; shift 2 ;;
    --body-file) [ -n "${2:-}" ] && [ -f "$2" ] || cli_die "--body-file: no such file: ${2:-<none>}"
                 BODY="$(cat "$2")"; BODY_SET=1; shift 2 ;;
    --close)     CLOSE=1; shift ;;
    -)           BODY="$(cat)"; BODY_SET=1; shift ;;
    -*)          cli_die "unknown flag: $1" ;;
    *)           POS+=("$1"); shift ;;
  esac
done

[ "${#POS[@]}" -eq 3 ] || cli_die "need exactly <owner/repo> <issue> <job>, got ${#POS[@]} positional argument(s)"
REPO="${POS[0]}"; ISSUE="${POS[1]}"; JOB="${POS[2]}"

case "$REPO" in
  */*) ;;
  *) cli_die "<owner/repo> must contain a '/', got '$REPO'" ;;
esac
PROJECT="${REPO#*/}"

[ "$BODY_SET" -eq 1 ] || cli_die "need --body TEXT, --body-file FILE, or - (stdin)"
[ -n "$(printf '%s' "$BODY" | tr -d '[:space:]')" ] || cli_die "empty body, refusing to post"

# Trim trailing blank lines so the stamp -- appended as its own trailing
# paragraph -- is genuinely the LAST non-blank line, which is the only
# thing is_stamped() (vim-arcade#77 / ecosim's provenance.py) checks.
while [ -n "$BODY" ] && [ "${BODY: -1}" = "$(printf '\n')" ]; do BODY="${BODY%?}"; done

STAMP="<!-- agent: ${PROJECT}/${JOB} $(date -u +%Y-%m-%dT%H:%M:%SZ) -->"
STAMPED="$(printf '%s\n\n%s' "$BODY" "$STAMP")"

if ! have gh; then
  echo "gh-comment.sh: BLIND -- gh is not on PATH. Nothing was posted." >&2
  exit 6
fi

if [ "$CLOSE" -eq 1 ]; then
  OUT="$(gh issue close "$ISSUE" --repo "$REPO" --comment "$STAMPED" 2>&1)" || {
    printf 'gh-comment.sh: gh refused to close %s#%s with a comment:\n%s\n' "$REPO" "$ISSUE" "$OUT" >&2
    exit 1
  }
else
  OUT="$(printf '%s' "$STAMPED" | gh issue comment "$ISSUE" --repo "$REPO" --body-file - 2>&1)" || {
    printf 'gh-comment.sh: gh refused to comment on %s#%s:\n%s\n' "$REPO" "$ISSUE" "$OUT" >&2
    exit 1
  }
fi
printf '%s\n' "$OUT"
exit 0
