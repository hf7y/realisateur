#!/usr/bin/env bash
# subagent-closeout.sh -- SubagentStop guard: a dirty tree at exit is a failed run.
#
# Installed 2026-08-01, Zach-directed, as THE FLOOR gate 3.2 (realisateur
# vault:realisateur/THE-FLOOR.md). Owner: realisateur. senechal notified.
#
# 2026-08-02, Zach-directed: this now CALLS `closeout-lint --strict --repo`
# instead of reimplementing a subset of it. It previously did its own inline
# `git status --porcelain`, which sees a dirty tree and nothing else. The
# 2026-07-25 incident it was built for (76 uncommitted lines in
# sync-crontab.sh) is caught either way -- but the 2026-07-27 incident, where
# a subagent woke after reporting "completed" and wrote outside its mandate,
# leaves UNPUSHED COMMITS, which the inline check cannot see. So does a
# host-only branch, which is a blocker under the settled definition of
# "pushed" and which `fauche`/`transplante` refuse a repo for.
#
# WHY THIS EXISTS. On 2026-07-25 a subagent left 76 uncommitted lines in
# sync-crontab.sh -- the script that writes crontabs -- without mentioning it,
# and the next autocommit watcher was positioned to adopt them under a human's
# name. CLAUDE.md has said "a dirty tree at exit is a failed run" ever since.
# That sentence was prose for six days and prose does not stop anything. This
# is the same rule as an exit code.
#
# CONTRACT. Reads the hook payload as JSON on stdin. Exit 0 lets the subagent
# stop. Exit 2 BLOCKS the stop and feeds stderr back to the subagent, which is
# what makes it go clean up rather than hand off a dirty tree.
#
# FAILS LOUD, NOT OPEN. If git is missing, the payload is unreadable, or
# closeout-lint exits a code this does not understand, it exits 1 (visible
# error, non-blocking) rather than 0 -- silently passing is BUILD-DISCIPLINE
# pattern 1, the failure this whole file is an instance of guarding against.
#
# WHY --allow-blind, given that BLIND now gates by default. Measured, not
# assumed: from inside a linked worktree, `git worktree list` always reports
# the main checkout, so BLIND is >= 1 BY CONSTRUCTION for any worktree-based
# session -- and worktree isolation is the standard pattern here. On
# 2026-08-02 every repo probed (realisateur, its worktree, senechal) returned
# exactly 1 BLIND. A hook that blocked on that would block every subagent on
# every run, and would be switched off within a day; a guard nobody can live
# with protects nothing. Watching the BLIND population over time is ecosim's
# job instead (filed 2026-08-02), which is the right instrument for a signal
# that is normal in ones and alarming in tens.
#
# WHY IT DEGRADES INSTEAD OF HARD-DEPENDING. `closeout-lint --repo` ships in
# realisateur and reaches this hook through the ~/.local/bin shim, so there is
# a window where the installed copy predates the flag. Probing for it and
# falling back to the original inline check keeps the 2026-07-25 protection
# intact during that window, and says loudly on stderr what is not being
# checked. Hard-depending would turn "the shim is one commit behind" into
# "every subagent stop errors".
set -uo pipefail

log() { printf 'subagent-closeout: %s\n' "$*" >&2; }

payload="$(cat 2>/dev/null)" || { log "could not read hook payload from stdin"; exit 1; }

# Loop guard: if we already blocked once this stop, do not block forever.
# The subagent has been told; a second identical block would spin.
#
# Herestring, not a pipe. `producer | grep -q` is unsafe under `set -o
# pipefail`: grep -q exits on the first match and closes the pipe, the
# producer takes SIGPIPE and returns 141, and pipefail promotes that to the
# pipeline's status -- so the test reads FALSE precisely when it matched.
# This is BUILD-DISCIPLINE's "pipefail+SIGPIPE guarded" row, and it bit the
# capability probe below for real on 2026-08-02 before being caught.
if grep -qE '"stop_hook_active"[[:space:]]*:[[:space:]]*true' <<<"$payload"; then
  exit 0
fi

# cwd is the SESSION's cwd, not necessarily the tree a subagent worked in --
# a worktree-isolated or freshly-cloned subagent writes elsewhere entirely.
# Fall back to $PWD if the payload lacks it.
cwd="$(sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p;q' <<<"$payload")"
[ -n "$cwd" ] || cwd="$PWD"
[ -d "$cwd" ] || { log "cwd from payload is not a directory: $cwd"; exit 1; }

# agent_transcript_path (SubagentStop payload field) is the SUBAGENT's own
# transcript -- distinct from the session's. Used below to find trees it
# actually wrote to, when they are not cwd (#363).
agent_transcript="$(sed -n 's/.*"agent_transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p;q' <<<"$payload")"

command -v git >/dev/null 2>&1 || { log "git not on PATH -- cannot check tree state"; exit 1; }

# #363: cwd alone misses a subagent that cloned or was worktree-isolated
# somewhere else -- the observed failure went both directions: cwd's
# pre-existing, unrelated branches got reported as this run's findings
# (false positive), and a tree the subagent actually dirtied went unchecked
# entirely (false negative, the one that loses work). Write/Edit/NotebookEdit
# tool calls in the subagent's OWN transcript carry an unambiguous absolute
# file_path -- far more reliable than trying to parse `git clone`/`cd` out of
# free-form Bash commands, which this deliberately does not attempt.
discover_written_trees() {
  local transcript="$1" exclude="$2"
  [ -n "$transcript" ] && [ -r "$transcript" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  jq -r '
    select(.message.content != null) |
    .message.content[]? |
    select(.type == "tool_use") |
    select(.name == "Write" or .name == "Edit" or .name == "NotebookEdit") |
    .input.file_path // empty
  ' "$transcript" 2>/dev/null |
  while IFS= read -r fp; do
    [ -n "$fp" ] || continue
    d="$(dirname -- "$fp" 2>/dev/null)" || continue
    root="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null)" || continue
    [ -n "$root" ] && [ "$root" != "$exclude" ] && printf '%s\n' "$root"
  done | sort -u
}

trees=("$cwd")
while IFS= read -r extra; do
  [ -n "$extra" ] && trees+=("$extra")
done < <(discover_written_trees "$agent_transcript" "$cwd")

# Not a git repo is not a violation; there is simply nothing to check. Only
# collapses to a no-op when EVERY discovered tree is a non-repo -- one real
# repo among them still needs auditing.
any_repo=0
for t in "${trees[@]}"; do
  git -C "$t" rev-parse --is-inside-work-tree >/dev/null 2>&1 && any_repo=1
done
[ "$any_repo" -eq 1 ] || exit 0

advice() {
  echo
  echo "A dirty tree at exit is a failed run, not a handoff -- an uncommitted change"
  echo "to a live script is indistinguishable from an abandoned one, and the next"
  echo "autocommit may adopt it under a human's name. An unpushed commit is the same"
  echo "failure one step later: the nightly clones the REF, not this working tree."
  echo
  echo "Before stopping, do ONE of these:"
  echo "  1. Commit the work you meant to keep, to a BRANCH (never main):"
  echo "       git add <specific paths>   # never 'git add -A'"
  echo "       git commit -F <msgfile>"
  echo "  2. Push it, so the branch exists on origin and not only on this host:"
  echo "       git push -u origin <branch>"
  echo "  3. Revert what you did not mean to keep:  git restore <paths>"
  echo "  4. If a file is deliberately untracked, add it to .gitignore and commit that."
  echo
  echo "Then report every file you touched, including the ones you reverted."
}

# --- preferred path: reuse the tool, do not reimplement it ------------------
LINT="$(command -v closeout-lint 2>/dev/null || true)"
# Capture then match, rather than `"$LINT" --help | grep -q`. See the SIGPIPE
# note on the loop guard above: that pipeline returned 141 under pipefail and
# silently sent every invocation down the fallback path, which reported
# "--repo is not installed" about a closeout-lint that had it.
lint_help=""
[ -n "$LINT" ] && lint_help="$("$LINT" --help 2>/dev/null || true)"
if [ -n "$LINT" ] && [[ "$lint_help" == *"--repo"* ]]; then
  blocked=0
  report=""
  for t in "${trees[@]}"; do
    git -C "$t" rev-parse --is-inside-work-tree >/dev/null 2>&1 || continue
    out="$("$LINT" --strict --allow-blind --repo "$t" 2>&1)"
    rc=$?
    case "$rc" in
      0) continue ;;
      1) blocked=1
         report+="  tree: $t"$'\n'
         report+="$(printf '%s\n' "$out" | grep -E '^\s*(FLAG|BLIND) \[' || printf '%s\n' "$out")"
         report+=$'\n\n'
         ;;
      *)
        log "closeout-lint exited $rc on $t, which this hook does not interpret."
        log "Refusing to report clean on a result it cannot read."
        printf '%s\n' "$out" >&2
        exit 1
        ;;
    esac
  done
  [ "$blocked" -eq 0 ] && exit 0
  {
    echo "BLOCKED: closeout-lint --strict found work this run did not make durable."
    if [ "${#trees[@]}" -gt 1 ]; then
      echo "  (${#trees[@]} trees checked -- cwd plus trees this agent's own"
      echo "  transcript shows it wrote to, per #363)"
    fi
    echo
    printf '%s' "$report"
    advice
  } >&2
  exit 2
fi

# --- fallback: the original inline dirty-tree check -------------------------
log "closeout-lint --repo is not installed; checking the working tree only."
log "  UNPUSHED COMMITS AND HOST-ONLY BRANCHES ARE NOT BEING CHECKED."
log "  Fix: run realisateur/bin/install-shims.sh once its --repo support is on main."

dirty_report=""
dirty_total=0
for t in "${trees[@]}"; do
  git -C "$t" rev-parse --is-inside-work-tree >/dev/null 2>&1 || continue
  dirty="$(git -C "$t" status --porcelain 2>/dev/null)"
  rc=$?
  if [ $rc -ne 0 ]; then
    log "git status failed in $t (rc=$rc) -- refusing to report clean on a failed probe"
    exit 1
  fi
  [ -z "$dirty" ] && continue
  count="$(printf '%s\n' "$dirty" | grep -c .)"
  dirty_total=$((dirty_total + count))
  dirty_report+="  tree: $t ($count uncommitted change(s))"$'\n'
  dirty_report+="$(printf '%s\n' "$dirty" | head -20)"
  [ "$count" -gt 20 ] && dirty_report+=$'\n'"  ... and $((count - 20)) more"
  dirty_report+=$'\n\n'
done

[ "$dirty_total" -eq 0 ] && exit 0

{
  echo "BLOCKED: you are leaving $dirty_total uncommitted change(s)."
  echo
  printf '%s' "$dirty_report"
  advice
} >&2

exit 2
