#!/usr/bin/env bash
# session-marker.sh -- declare that a HUMAN is interactively working in a
# registered project, so that project's unattended jobs can defer instead of
# editing files out from under a live session.
#
# TRAPS (the rest of this header is in the vault):
# EIGHT DAYS OF NO-OP, 2026-08-03 -> 2026-08-11 (#73). resolve_project read
# the conf with `grep -oP`, which does not expand shell variables, so `repo`
# was the LITERAL `$HOME/Documents/Projects/<name>` and the `case` below could
# not match any real cwd. Dated precisely because the CONFS moved, not the
# code: scheduler 8bca07b (2026-08-03 12:23) rewrote nine confs from
# `/home/zach/...` to `"$HOME/..."`, and the last marker this script ever
# wrote is realisateur.interactive at 2026-08-03T10:45 -- 98 minutes earlier.
# Cost: the marker's consumer, scheduler lib/sweep-loop-common.sh, defers a
# project's unattended run when a human is in the repo, and no marker reads as
# no human. Eight days of dispatch with that deferral off, in the direction
# this file's own header calls "the dangerous one" -- silently, because "not a
# registered project" is ALSO the normal answer. Hence the counters below.
#
# Usage (from hooks; reads the hook's JSON on stdin):

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/conf.sh
. "$SELF_DIR/lib/conf.sh"

SCHED_ROOT="${SCHED_ROOT:-${INSTALLE_PROJECTS:-$HOME/Documents/Projects}/scheduler}"
REGISTRY_DIR="${SCHEDULER_REGISTRY_DIR:-$HOME/.local/share/scheduler-registry}"

action="${1:-}"

# Resolve a directory to a registered PROJECT_KEY by matching PROJECT_REPO_PATH
# in schedule/*.conf -- the one source, same resolution the surveys use. A cwd
# that matches nothing is the common case (unrelated work on this machine) and
# must be a fast, silent no-op: this hook runs on EVERY session start.
#
# Reads through lib/conf.sh, which expands $HOME BY NAME, never by eval: a
# conf is a file this repo does not own. The counters are the guard, and the
# reason this no longer returns early: one lookup cannot tell "your cwd is not
# a registered project" from "no conf here can EVER match", and those were the
# same silent `return 1` for eight days. ~20 small reads buys that distinction.
# Sets RESOLVE_HIT as well as printing it -- `x=$(resolve_project ...)` is a
# SUBSHELL and the counters would not survive it.
RESOLVE_CONFS=0   # confs that carry a PROJECT_REPO_PATH at all
RESOLVE_LIVE=0    # ...of those, how many name a directory that exists
RESOLVE_HIT=""    # the matched PROJECT_KEY, empty when nothing matched
resolve_project() {
  local dir="$1" conf name repo hit=""
  RESOLVE_CONFS=0; RESOLVE_LIVE=0; RESOLVE_HIT=""
  [ -n "$dir" ] || return 1
  for conf in "$SCHED_ROOT"/schedule/*.conf; do
    [ -f "$conf" ] || continue
    name="$(basename "$conf" .conf)"
    case "$name" in _*) continue ;; esac
    repo="$(conf_repo_path "$conf")" || continue
    RESOLVE_CONFS=$((RESOLVE_CONFS + 1))
    [ -d "$repo" ] && RESOLVE_LIVE=$((RESOLVE_LIVE + 1))
    [ -n "$hit" ] && continue
    # match the repo root itself or anything beneath it
    case "$dir/" in "$repo"/*) hit="$name" ;; esac
  done
  [ -n "$hit" ] || return 1
  RESOLVE_HIT="$hit"
  printf '%s\n' "$hit"
}

# BLIND: confs exist and carry paths, and NOT ONE of them resolves to a
# directory on this host. That is not "nothing to mark", it is "I cannot
# look", and it is the shape #73 was. Must be called after resolve_project.
resolve_blind() { [ "$RESOLVE_CONFS" -gt 0 ] && [ "$RESOLVE_LIVE" -eq 0 ]; }
resolve_blind_say() {
  echo "session-marker: BLIND -- $RESOLVE_CONFS conf(s) under $SCHED_ROOT/schedule/ carry a PROJECT_REPO_PATH and NOT ONE resolves to a directory that exists." >&2
  echo "session-marker: no marker can be written for any project, so every unattended job reads every repo as free even with a human in it. This is the #73 shape; check the confs and this script's resolution together." >&2
}

# The hook contract: JSON on stdin with a `cwd` field. $CLAUDE_PROJECT_DIR is
# preferred when present (it names the project root rather than wherever the
# session happens to be). No jq dependency -- this must not fail because a
# tool is missing on some host.
read_cwd() {
  local json cwd=""
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then printf '%s\n' "$CLAUDE_PROJECT_DIR"; return 0; fi
  json="$(cat 2>/dev/null || true)"
  cwd="$(printf '%s' "$json" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  [ -n "$cwd" ] || cwd="$PWD"
  printf '%s\n' "$cwd"
}

case "$action" in
  acquire|release)
    cwd="$(read_cwd)"
    resolve_project "$cwd" >/dev/null || true
    project="$RESOLVE_HIT"
    # Loud even here. Exit stays 0 (a hook must not block a session; `resolve`
    # carries the honest code) but silence is what let eight days pass.
    resolve_blind && resolve_blind_say
    [ -n "$project" ] || exit 0                       # not a registered project
    mkdir -p "$REGISTRY_DIR" 2>/dev/null || exit 0
    marker="$REGISTRY_DIR/$project.interactive"
    if [ "$action" = "acquire" ]; then
      # RETIRES the bare `pid=${PPID}` this used to write. That comment said
      # "the parent is the session process that actually persists" -- measured
      # 2026-07-27, it is not. The hook runs under a short-lived intermediate
      # shell, so PPID dies seconds after acquire while the session runs on.
      # Observed live: marker held pid=429191 (dead) while the session process
      # was 429162 (alive), and `check-project-busy scheduler` therefore said
      # "free" with a human actively editing the repo.
      #
      # That direction of failure is the dangerous one. This marker exists so
      # unattended jobs DEFER to a person; reading "free" while someone is
      # working is the exact race it was built to prevent, and it was silent
      # -- the probe's own "stale marker ... SessionEnd never fired" wording
      # made a structural bug look like an ordinary crashed session.
      #
      # $$ is still wrong (this script exits immediately). Walk up instead and
      # record the nearest ancestor that IS the session. Bounded depth, and
      # falls back to PPID rather than writing nothing: a marker with a
      # short-lived pid is still strictly better than no marker at all.
      session_pid() {
        local p="${PPID}" d=0 comm
        while [ -n "$p" ] && [ "$p" -gt 1 ] 2>/dev/null && [ "$d" -lt 12 ]; do
          comm="$(ps -p "$p" -o comm= 2>/dev/null | tr -d ' ')"
          case "$comm" in
            claude|claude.exe) printf '%s\n' "$p"; return 0 ;;
          esac
          p="$(ps -p "$p" -o ppid= 2>/dev/null | tr -d ' ')"
          d=$((d + 1))
        done
        printf '%s\n' "${PPID}"
      }
      {
        echo "pid=$(session_pid)"
        echo "started_at=$(date -Is)"
        echo "cwd=$cwd"
        echo "owner=realisateur/bin/session-marker.sh"
      } > "$marker" 2>/dev/null || true
    else
      rm -f "$marker" 2>/dev/null || true
    fi
    exit 0
    ;;
  resolve)
    # 3 for BLIND, matching hygiene-lint.sh and silence-audit.sh. Not 1: "this
    # directory is not a registered project" is a real answer about ONE
    # directory; "no directory here could ever match" is a broken registry.
    # Collapsing the two is how #73 stayed invisible.
    dir="${2:-$PWD}"
    resolve_project "$dir" || true
    if resolve_blind; then
      resolve_blind_say
      exit 3
    fi
    if [ -n "$RESOLVE_HIT" ]; then exit 0; fi
    echo "session-marker: $dir is under no registered project ($RESOLVE_LIVE of $RESOLVE_CONFS conf(s) resolve)" >&2
    exit 1
    ;;
  probe)
    project="${2:?usage: session-marker.sh probe <project>}"
    marker="$REGISTRY_DIR/$project.interactive"
    if [ -f "$marker" ]; then
      mpid="$(awk -F= '$1=="pid"{print $2}' "$marker" 2>/dev/null)"
      if [ -n "$mpid" ] && kill -0 "$mpid" 2>/dev/null; then
        echo "BUSY: interactive session (pid $mpid, since $(awk -F= '$1=="started_at"{print $2}' "$marker" 2>/dev/null))"
        exit 1
      fi
      echo "free (stale marker: pid ${mpid:-?} is gone -- SessionEnd never fired)"
      exit 0
    fi
    echo "free"
    exit 0
    ;;
  -h|--help)
    printf 'session-marker.sh -- record/probe a live interactive session for a project\n\n'
    printf 'usage:\n'
    printf '  session-marker.sh acquire < hook-json   from a Claude SessionStart hook\n'
    printf '  session-marker.sh release < hook-json   from a Claude SessionEnd hook\n'
    printf '  session-marker.sh probe <project>       print "free" or a live-session line\n'
    printf '  session-marker.sh resolve [dir]         which project owns dir (default $PWD)\n\n'
    printf 'flags: none -- the first argument is a subcommand\n\n'
    printf 'exit codes:\n'
    printf '  0  the subcommand completed (probe prints its answer on stdout)\n'
    printf '  1  resolve: dir is under no registered project\n'
    printf '  2  usage error: unknown subcommand or missing argument\n'
    printf '  3  resolve: BLIND -- no conf resolves to a directory that exists,\n'
    printf '     so no marker can ever be written for any project\n\n'
    printf 'this tool makes no AI calls and cannot spend: --summon is rejected.\n'
    exit 0 ;;
  *)
    echo "usage: session-marker.sh {acquire|release} < hook-json" >&2
    echo "       session-marker.sh probe <project>" >&2
    echo "       session-marker.sh resolve [dir]" >&2
    exit 2
    ;;
esac
