#!/usr/bin/env bash
# gh-sign.sh -- sign every agent-written GitHub comment/issue AUTOMATICALLY,
# by standing in front of `gh` on PATH.
#
# It appends `<!-- agent: <account>@<host> <ISO8601> -->` to the bodies of
# `issue comment|create|close` and `pr comment|create`, and passes everything
# else through untouched. Both fields are read from the running process, so
# there is no argument for a caller to get wrong or forget. It replaced
# bin/gh-comment.sh, a wrapper that had to be called and never was: 20 of 403
# comments across five repos were stamped. Why the GitHub App cannot own this
# half of attribution, and the measurement: hf7y/realisateur#327.
#
# FAIL OPEN, ALWAYS. Every failure path -- no real gh, an unreadable
# --body-file, an unrecognised subcommand -- execs the real gh with the
# ORIGINAL argv. An unsigned comment is the status quo; a dropped one is not.
#
#   gh-sign.sh <any gh argv>     sign if it is a body-carrying write, then exec gh
#   gh-sign.sh --self-check      prove the shim resolves a real gh that is not itself
#   gh-sign.sh --stamp           print the stamp this host/account would append
#
# NOT INSTALLED ANYWHERE YET: it does nothing until something links it ahead of
# the real gh on PATH, which is #327's open decision. Mandark is excluded
# either way -- an unsigned comment from Zach's own machine is the signal
# decision-rot.sh reads.
set -uo pipefail

MARKER='<!-- agent:'

# BUILT-INS ONLY (`-ef`, `printf %(...)T`): this runs in front of every gh call
# including cron's, with a minimal PATH. An early version shelled out to
# id/hostname/date/readlink; under a stripped PATH all four were "command not
# found", which degraded the stamp to `?@?` AND made the shim fail to recognise
# ITSELF as the gh it had found. `id -un` first and $USER only as fallback:
# $USER is inherited and can be set by the caller.
stamp() {
  local TZ=UTC who
  who="$(id -un 2>/dev/null)" || who="${USER:-${LOGNAME:-?}}"
  printf '%s %s@%s %(%Y-%m-%dT%H:%M:%SZ)T -->\n' "$MARKER" "$who" "${HOSTNAME%%.*}" -1
}

# The real gh: the first one on PATH that is not this file. `-ef` compares
# device+inode THROUGH symlinks, so /usr/local/bin/gh -> .../gh-sign.sh is
# recognised as this script and skipped rather than re-executed forever.
real_gh() {
  local d c
  IFS=: read -ra _p <<< "$PATH"
  for d in "${_p[@]}"; do
    c="$d/gh"
    [ -x "$c" ] || continue
    [ "$c" -ef "${BASH_SOURCE[0]}" ] && continue
    printf '%s\n' "$c"
    return 0
  done
  return 1
}

case "${1:-}" in
  --stamp)      stamp; exit 0 ;;
  --self-check)
    if gh_bin="$(real_gh)"; then
      printf 'gh-sign: real gh -> %s\ngh-sign: stamp   -> %s' "$gh_bin" "$(stamp)"
      exit 0
    fi
    echo 'gh-sign: BLIND -- no gh on PATH other than this shim. Every call falls through unsigned.' >&2
    exit 6 ;;
esac

GH="$(real_gh)" || {
  echo 'gh-sign: no real gh on PATH' >&2
  exit 127
}

# Only these carry a body an agent writes for another agent to read. `pr
# create` is included: a PR body is where a cross-repo handoff usually lands.
signable=0
case "${1:-} ${2:-}" in
  'issue comment'|'issue create'|'issue close'|'pr comment'|'pr create') signable=1 ;;
esac
[ "$signable" -eq 1 ] || exec "$GH" "$@"

# Read the body out of argv, whichever spelling was used. An argv with no body
# at all opens $EDITOR interactively -- a human path, left alone.
body=''; found=0; idx=0; bi=0; kind=''
args=("$@")
# `issue close` spells it --comment; everything else spells it --body. Both
# are the same thing to a reader of the thread, so both get signed.
for ((i = 0; i < ${#args[@]}; i++)); do
  case "${args[$i]}" in
    --body|-b|--comment|-c) kind=inline; bi=$((i + 1)); idx=$i; found=1 ;;
    --body-file|-F)         kind=path;   bi=$((i + 1)); idx=$i; found=1 ;;
  esac
done
if [ "$found" -ne 1 ] || [ "$bi" -ge "${#args[@]}" ]; then exec "$GH" "$@"; fi

if [ "$kind" = inline ]; then
  body="${args[$bi]}"
elif [ "${args[$bi]}" = '-' ]; then
  body="$(cat)"
else
  body="$(cat -- "${args[$bi]}" 2>/dev/null)" || exec "$GH" "$@"
fi

# Already signed -- by a re-run, or by a body composed from one. Signing twice
# would push the first stamp off the last line and make the marker read as
# body text.
last="$(printf '%s\n' "$body" | grep -v '^[[:space:]]*$' | tail -1)"
case "$last" in
  "$MARKER"*) exec "$GH" "$@" ;;
esac

signed="$(printf '%s\n\n%s' "$body" "$(stamp)")"

# `issue close` has no --comment-file spelling, so that one stays in argv.
# Everything else is handed back on STDIN: a body can exceed ARG_MAX and can
# contain anything, and `--body-file -` is the one spelling with neither
# limit. It also normalises -b/-F/--body/--body-file to a single shape.
case "${args[$idx]}" in
  --comment|-c)
    args[$bi]="$signed"
    exec "$GH" "${args[@]}" ;;
esac
args[$idx]='--body-file'
args[$bi]='-'
printf '%s' "$signed" | "$GH" "${args[@]}"
