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
# It also REFUSES an `issue create` / `pr create` whose body breaks the body
# grammar in lib/body-grammar.sh -- admission control, not an audit. The two
# workflows that graded that same text after the fact (claim-drift.yml,
# deferral-ledger.yml) are not required checks on main, so nothing they found
# could ever block anything; the write is the only place the rule bites.
#
# FAIL OPEN ON MACHINERY, CLOSED ON GRAMMAR. Every MECHANICAL failure -- no
# real gh, an unreadable --body-file, an unrecognised subcommand, a missing
# grammar library -- execs the real gh with the ORIGINAL argv. An unsigned
# comment is the status quo; a dropped one is not. A body that violates a rule
# the shim COULD read is the one case it stops, because a malformed body that
# reaches GitHub is what every deleted auditor existed to chase afterwards.
#
#   gh-sign.sh <any gh argv>        sign if it is a body-carrying write, then exec gh
#   gh-sign.sh --self-check         prove the shim resolves a real gh that is not itself
#   gh-sign.sh --stamp              print the stamp this host/account would append
#   gh-sign.sh --check-body <path>  grade a body against the grammar; `-` reads stdin
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

# The grammar lives next to this file. When the shim is reached through a
# symlink (/usr/local/bin/gh) ${BASH_SOURCE[0]} is the LINK, so lib/ is not
# beside it -- hence GH_SIGN_LIB, set by whatever installs the link. A missing
# library is announced and then fallen through: BLIND, loudly, never silently
# clean. `%/*` rather than dirname: no external commands here, see stamp().
GRAMMAR="${GH_SIGN_LIB:-${BASH_SOURCE[0]%/*}/lib}/body-grammar.sh"
grammar_ok=0
# shellcheck source=lib/body-grammar.sh
[ -r "$GRAMMAR" ] && . "$GRAMMAR" && grammar_ok=1

case "${1:-}" in
  --stamp)      stamp; exit 0 ;;
  --check-body)
    [ "$grammar_ok" -eq 1 ] || { printf 'gh-sign: BLIND -- no grammar library at %s\n' "$GRAMMAR" >&2; exit 6; }
    if [ "${2:--}" = - ]; then _b="$(cat)"; else _b="$(cat -- "$2")" || exit 6; fi
    grammar_check "$_b"; _n=$?
    [ "$_n" -eq 0 ] && { echo 'gh-sign: body is well-formed'; exit 0; }
    exit 3 ;;
  --self-check)
    if gh_bin="$(real_gh)"; then
      printf 'gh-sign: real gh -> %s\ngh-sign: stamp   -> %s' "$gh_bin" "$(stamp)"
      [ "$grammar_ok" -eq 1 ] \
        && printf 'gh-sign: grammar -> %s\n' "$GRAMMAR" \
        || printf 'gh-sign: grammar -> BLIND, none at %s -- creates go unchecked\n' "$GRAMMAR"
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

# ADMISSION CONTROL. A create is the one write whose body is a contract with
# whoever reads the tracker next, and the only one that can still be corrected
# for free -- it does not exist yet. Comments are exempt: a thread reply is not
# where a DEFERRED block belongs, and refusing one would lose the reply.
#
# There is no bypass flag on purpose. A documented override turns a guard into
# a toll booth: everyone pays it once and then always. Fix the body.
case "${1:-} ${2:-}" in
  'issue create'|'pr create')
    if [ "$grammar_ok" -eq 1 ]; then
      if findings="$(grammar_check "$body")"; then :; else
        printf 'gh-sign: REFUSED -- this %s body breaks the grammar in %s:\n' "$1 $2" "$GRAMMAR" >&2
        while IFS= read -r _f; do printf '  %s\n' "$_f" >&2; done <<<"$findings"
        printf 'gh-sign: nothing was created. `gh-sign.sh --check-body <file>` re-runs this check.\n\n' >&2
        grammar_template >&2
        exit 3
      fi
    else
      printf 'gh-sign: BLIND -- no grammar library at %s; body not checked.\n' "$GRAMMAR" >&2
    fi ;;
esac

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
