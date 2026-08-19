#!/usr/bin/env bash
# selfdev-claude-token.sh -- WHERE THE SHARED CLAUDE CODE OAUTH TOKEN LIVES.
# One answer, one host-wide location, sourced by every reader. Same shape as
# selfdev-app-key.sh, for the same reason and after the same cost.
#
# THE COST (realisateur#409, estate-wide secrets audit 2026-08-19): one
# sk-ant-oat01 value was stored raw in ~/.claude/settings.json on all 13
# self-dev accounts, plus ~/.claude-token beside it. Thirteen copies is
# thirteen chances to leak and one rotation that has to land in thirteen
# places. It had already escaped into four session transcripts, several
# .bak-2026* files and a compiled .pyc -- and transcripts are exactly what
# this ecosystem reaps, quotes into issues, and now publishes.
#
# The token is a credential of Zach's ANTHROPIC account, not of any unix
# account, so there was never a reason for it to be per-account. It is one
# fact; this file is its one reader.
#
# NOT a settings.json key. Claude Code reads CLAUDE_CODE_OAUTH_TOKEN from the
# environment, which is why this exports rather than writes: an exported value
# leaves no file behind for a transcript to quote.

[ -n "${SELFDEV_CLAUDE_TOKEN_LIB:-}" ] && return 0
SELFDEV_CLAUDE_TOKEN_LIB=1

SELFDEV_TOKEN_DIR="${SELFDEV_TOKEN_DIR:-/etc/selfdev}"
SELFDEV_TOKEN_PATH_DEFAULT="$SELFDEV_TOKEN_DIR/claude-token"
SELFDEV_TOKEN_GROUP="${SELFDEV_TOKEN_GROUP:-selfdev}"

# selfdev_token_path -- the path this host should read. Prints it; says nothing
# about whether it exists, which is the caller's business to report.
selfdev_token_path() {
  printf '%s' "${SELFDEV_TOKEN_FILE:-$SELFDEV_TOKEN_PATH_DEFAULT}"
}

# selfdev_token_readable -- can THIS process actually read it? The witness is a
# read, not a stat: group membership not yet picked up by the current session
# (a `usermod -aG` before the next login) stats fine and reads EACCES, and that
# difference is the whole failure mode of a group-readable secret.
selfdev_token_readable() {
  local p="${1:-$(selfdev_token_path)}"
  head -c 1 -- "$p" >/dev/null 2>&1
}

# selfdev_token_export -- put the token in the environment for a `claude` child.
# rc 0 exported, 1 no file, 2 present but unreadable by this process, 3 empty
# or not shaped like an oat01 token. Never prints the value, on any path.
selfdev_token_export() {
  local p; p="$(selfdev_token_path)"
  [ -e "$p" ] || return 1
  selfdev_token_readable "$p" || return 2
  local tok; tok="$(tr -d '\r\n' < "$p")"
  case "$tok" in sk-ant-oat*) ;; *) return 3 ;; esac
  export CLAUDE_CODE_OAUTH_TOKEN="$tok"
  return 0
}
