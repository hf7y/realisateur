#!/usr/bin/env bash
# session-marker.sh -- declare that a HUMAN is interactively working in a
# registered project, so that project's unattended jobs can defer instead of
# editing files out from under a live session.
#
# REALISATEUR-OWNED entry in a machine-wide config surface, same convention as
# the `# >>> realisateur-owned` block in Zach's crontab. senechal owns
# *knowing* this exists (its 2026-07-24 mission widening: shared-host
# script/autostart ownership -- no unattributable leftovers); realisateur owns
# what it does. Wired from ~/.claude/settings.json SessionStart/SessionEnd.
#
# WHY A MARKER AND NOT flock
# --------------------------
# scheduler's lib/sweep-loop-common.sh holds a real flock for a job's
# duration, which is correct there: the holder is one long-running process.
# A session hook is NOT that -- it fires, exits, and the session outlives it,
# so there is no process to hold an fd. The alternative (spawn a detached
# flock holder) reintroduces the exact problem it solves: SessionEnd is NOT
# guaranteed to fire on crash or SIGKILL (confirmed against the hooks
# reference, 2026-07-26), so a held lock would orphan and wedge that
# project's batch permanently and SILENTLY.
#
# So: a marker file whose LIVENESS IS A PID PROBE. `release` is the fast
# path, not the correctness guarantee -- a crashed session's marker is dead
# the moment its pid is, and every reader checks `kill -0` rather than the
# file's existence. Self-healing by construction; nothing to clean up.
#
# Deliberately mirrors the `<PROJECT_KEY>.active` marker sweep-loop-common.sh
# already writes next to its lock, and lands in the SAME directory, so one
# place answers "is anything writing to this project right now."
#
# Usage (from hooks; reads the hook's JSON on stdin):
#   session-marker.sh acquire      < hook JSON
#   session-marker.sh release      < hook JSON
#   session-marker.sh probe <project>     -- for humans/scripts
#
# Exit status is always 0 on the hook paths: a hook that fails must never
# block a session from starting. Problems are reported to stderr only.
set -uo pipefail

SCHED_ROOT="/home/zach/Documents/Projects/scheduler"
REGISTRY_DIR="$HOME/.local/share/scheduler-registry"

action="${1:-}"

# Resolve a directory to a registered PROJECT_KEY by matching PROJECT_REPO_PATH
# in schedule/*.conf -- the one source, same resolution the surveys use. A cwd
# that matches nothing is the common case (unrelated work on this machine) and
# must be a fast, silent no-op: this hook runs on EVERY session start.
resolve_project() {
  local dir="$1" conf name repo
  [ -n "$dir" ] || return 1
  for conf in "$SCHED_ROOT"/schedule/*.conf; do
    name="$(basename "$conf" .conf)"
    case "$name" in _*) continue ;; esac
    repo="$(grep -oP '(?<=PROJECT_REPO_PATH=")[^"]*' "$conf" 2>/dev/null | head -1)"
    [ -n "$repo" ] || continue
    # match the repo root itself or anything beneath it
    case "$dir/" in "$repo"/*) printf '%s\n' "$name"; return 0 ;; esac
  done
  return 1
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
    project="$(resolve_project "$cwd")" || exit 0     # not a registered project
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
    printf '  session-marker.sh probe <project>       print "free" or a live-session line\n\n'
    printf 'flags: none -- the first argument is a subcommand\n\n'
    printf 'exit codes:\n'
    printf '  0  the subcommand completed (probe prints its answer on stdout)\n'
    printf '  2  usage error: unknown subcommand or missing argument\n\n'
    printf 'this tool makes no AI calls and cannot spend: --summon is rejected.\n'
    exit 0 ;;
  *)
    echo "usage: session-marker.sh {acquire|release} < hook-json" >&2
    echo "       session-marker.sh probe <project>" >&2
    exit 2
    ;;
esac
