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

SCHED_ROOT="/home/zach/Documents/Project Archive/scheduler"
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
      # PPID, not $$: this script exits immediately: its own pid would be dead
      # instantly and every liveness probe would read the marker as stale. The
      # parent is the session process that actually persists.
      {
        echo "pid=${PPID}"
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
  *)
    echo "usage: session-marker.sh {acquire|release} < hook-json" >&2
    echo "       session-marker.sh probe <project>" >&2
    exit 2
    ;;
esac
