#!/usr/bin/env bash
# gh-sign.sh -- sign every agent-written GitHub comment/issue AUTOMATICALLY,
# by standing in front of `gh` on PATH.
#
# WHY THIS SHAPE AND NOT A WRAPPER
# --------------------------------
# The previous answer was bin/gh-comment.sh: a wrapper you had to remember to
# call. Measured 2026-08-15, issue comments since 2026-08-08:
#
#   vim-arcade  16/36 stamped (44%)   -- the only repo whose command file mandates it
#   realisateur  3/111 (2%)   scheduler 1/73 (1%)   senechal 0/143   chezz 0/13
#
# The wrapper never omitted the stamp. 97% of comments went out over a bare
# `gh issue comment` that never reached it. An opt-in signature is not a
# signature; it is a convention with a compliance rate, and the compliance
# rate was 2%.
#
# So the signature moves to the only place an agent cannot route around: the
# name `gh` itself, earlier on PATH than the real binary. Nothing to call,
# nothing to mandate in a command file, nothing to remember. Everything else
# is passed through untouched.
#
# WHY NOT THE GITHUB APP. bin/selfdev-gh-app.sh gives the fleet a real GitHub
# actor -- `unattended-monkey[bot]` -- and GitHub, not the committer, asserts
# it. That is strictly better than a comment marker, and it is why the App
# owns the PUSHER half of git attribution. It cannot own this half, for two
# reasons measured here:
#   1. It is ONE App across all accounts (the same fleet-identity bug
#      selfdev-gh-app.sh --wire already corrects for git authorship): every
#      account would file as the same bot, so cross-repo agent-to-agent
#      writes still could not say WHICH agent wrote.
#   2. Nothing wired `gh` to it. Whatever stood the accounts up authenticated
#      them with the plain shared `hf7y` credential, which is exactly why all
#      403 comments above are authored `hf7y` and indistinguishable from
#      Zach's own.
# This signs with the ACCOUNT, which is the thing the App flattens away.
#
# WHAT THE STAMP SAYS, AND WHY THE CALLER CANNOT SAY IT
#   <!-- agent: <account>@<host> <ISO8601> -->
# Both fields are read from the running process (`id -un`, `hostname`), never
# passed in. gh-comment.sh took a <job> argument, so a caller could pass the
# wrong one, and every call site had to know one. There is no argument here to
# get wrong and none to forget.
#
# THE READ SIDE IS A MARKER, NOT A GRAMMAR. Three repos reimplemented the old
# strict format (realisateur bash, vim-arcade vim_arcade/provenance.py, ecosim
# lib/provenance.py) because cross-repo imports run the wrong direction here.
# Three copies of a field grammar is a drift surface. Three copies of "the
# last non-blank line starts with <!-- agent:" is not -- it is one regex with
# nothing inside it to disagree about. The fields are for a human reading the
# thread; the predicate reads only the marker.
#
# FAIL OPEN, ALWAYS. A signature is not worth a lost write. Every failure path
# -- no real gh, an unreadable --body-file, an unrecognised subcommand --
# execs the real gh with the ORIGINAL argv. The worst case is an unsigned
# comment, which is the status quo, not a dropped one.
#
# USAGE
#   gh-sign.sh <any gh argv>     sign if it is a body-carrying write, then exec gh
#   gh-sign.sh --self-check      prove the shim resolves a real gh that is not itself
#   gh-sign.sh --stamp           print the stamp this host/account would append
#
# INSTALL: linked host-wide as /usr/local/bin/gh by bin/wire-release-channel.sh,
# ahead of /usr/bin/gh. Deliberately NOT installed on mandark -- that is Zach's
# machine, and an unsigned comment there is the correct signal that a human
# wrote it. `is this comment an agent's?` is then answerable without asking
# anyone to remember anything.
set -uo pipefail

MARKER='<!-- agent:'

# BUILT-INS ONLY, on purpose. This runs in front of every `gh` call on the
# host, including ones made from cron with a minimal PATH. An early version
# shelled out to id/hostname/date/readlink; under a stripped PATH all four
# were "command not found", which degraded the stamp to `?@?` AND -- because
# the readlink compare silently returned empty -- made the shim fail to
# recognise ITSELF as the gh it had found. `-ef` and `printf %(...)T` are
# bash built-ins: no subprocess, nothing to be missing, and three fewer forks
# on a path that every write now goes through.
# `id -un` first and $USER only as the fallback: $USER is inherited and can be
# wrong (or set) by the caller, `id` reads the process's real uid. Neither is
# tamper-PROOF -- an agent that wants to can call /usr/bin/gh directly -- but
# a signature that is quietly WRONG is worse than one that is absent, so the
# authoritative source goes first.
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
    --body-file|-F)         kind=file;   bi=$((i + 1)); idx=$i; found=1 ;;
  esac
done
[ "$found" -eq 1 ] && [ "$bi" -lt "${#args[@]}" ] || exec "$GH" "$@"

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
