#!/usr/bin/env bash
# install-shims.sh -- install this repo's .claude/commands/*.md as USER-level
# slash commands, and its hooks/, so every repo gets them.
#
# IT INSTALLS NO SHIMS; the name is historical (#264, #385, #389).
#
# What survives is the half a verb cannot be: a slash command is a FILE Claude
# Code reads. Installed VERBATIM -- no rendering, no $REPO in the output -- so
# the SAME bytes ride onto `bashified` (carry-drift.sh) and install from the
# verb build with no checkout at all (install-verb-build.sh --link).
#
# Idempotent. Rerun after editing .claude/commands/*.md.
set -uo pipefail

CLI_NAME='install-shims.sh'
CLI_SUMMARY='install/refresh user-level slash commands and hooks from this repo'
CLI_USAGE='  install-shims.sh           install or refresh every command and hook
  install-shims.sh --check   report drift only, write nothing'
CLI_FLAGS='--check'
CLI_POSITIONAL=none
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

# DELIBERATELY NOT self-locating, unlike bin/blockers-freshness-check.sh and
# bin/token-usage.sh. Those answer "where am I"; this one answers "what should
# the INSTALLED shim point at", and the answer must be a stable checkout
# rather than whatever tree the installer happened to be invoked from.
REPO="${REPO:-${INSTALLE_PROJECTS:-$HOME/Documents/Projects}/realisateur}"

# A SOURCE OF TRUTH THAT IS NOT THERE IS A HARD FAILURE, NOT A FLAG.
#
# Found 2026-08-02 while bootstrapping dexter, and it is the reason the
if [ ! -d "$REPO/bin" ] || [ ! -e "$REPO/.git" ]; then
  printf '%s: REPO does not name a realisateur checkout: %s\n' \
    "${0##*/}" "$REPO" >&2
  printf '%s: (need both %s/bin and %s/.git)\n' "${0##*/}" "$REPO" "$REPO" >&2
  printf '%s: on a second host, set it explicitly and once:\n' "${0##*/}" >&2
  printf '%s:   REPO=$HOME/realisateur %s\n' "${0##*/}" "$0" >&2
  exit 5
fi
# EVERY destination is env-overridable, and that is a test-safety property, not
# a convenience. bin/tests/install-shims.test.sh redirects them to a scratch
# dir; without the override the test silently ran against the REAL
CMD_SRC="$REPO/.claude/commands"
CMD_DEST="${CMD_DEST:-$HOME/.claude/commands}"
HOOK_SRC="$REPO/hooks"
HOOK_DEST="${HOOK_DEST:-$HOME/.claude/hooks}"
CLAUDE_SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"

# DERIVED, not typed: a typed list produced the 2026-07-27 gap.
mapfile -t GLOBAL_COMMANDS < <(
  for f in "$CMD_SRC"/*.md; do
    [ -f "$f" ] || continue
    awk 'NR==1 && $0!="---"{exit} NR==1{fm=1;next} fm && $0=="---"{exit}
         fm && /^scope:[[:space:]]*user[[:space:]]*$/{print "y";exit}' "$f" \
      | grep -q y && basename "$f" .md
  done
)

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

fail=0
note() { printf '%s\n' "$*"; }
flag() { printf 'FLAG: %s\n' "$*" >&2; fail=1; }

install_file() {
  local path="$1" content="$2" mode="$3" label="$4"
  # A symlink at an install target is never something this installer made -- it
  # only ever writes regular files. Left in place it is actively destructive,
  # because both checks below follow it: `-f`/`cat` read through to the TARGET
  #   [rest: vault:realisateur/guard-archaeology-20260817.md]
  if [ -L "$path" ]; then
    local target; target="$(readlink "$path")"
    if [ "$CHECK_ONLY" = 1 ]; then
      flag "$label is a symlink -> $target; installing would write THROUGH it and clobber that file (rerun without --check to replace it)"
      return
    fi
    note "  WARN    $label was a symlink -> $target; replaced with a regular file"
    rm -f "$path" || { flag "could not remove symlink $path"; return; }
  fi
  if [ -f "$path" ] && [ "$(cat "$path")" = "$content" ]; then
    note "  ok      $label"
    return
  fi
  if [ "$CHECK_ONLY" = 1 ]; then
    flag "$label is missing or drifted from source (rerun without --check)"
    return
  fi
  printf '%s' "$content" > "$path" || { flag "could not write $path"; return; }
  chmod "$mode" "$path"
  note "  written $label"
}

note "install-shims -- source of truth: $REPO"
mkdir -p "$CMD_DEST" "$HOOK_DEST"

note "user-level slash commands -> $CMD_DEST"
for name in "${GLOBAL_COMMANDS[@]}"; do
  if [ ! -f "$CMD_SRC/$name.md" ]; then
    flag "$CMD_SRC/$name.md missing -- cannot render /$name"
    continue
  fi
  install_file "$CMD_DEST/$name.md" "$(cat "$CMD_SRC/$name.md")" 644 "/$name"
done

# Claude Code hooks. Added 2026-08-02: subagent-closeout.sh was installed by
# hand on 2026-08-01 and tracked in NO repo, which is the same defect that
# broke the dexter bootstrap in July -- `usage-paced-runner.sh` was a symlink
# hand-made once that nothing in any repo created, so a bare host could not
note "Claude Code hooks -> $HOOK_DEST"
shopt -s nullglob
hook_files=("$HOOK_SRC"/*.sh)
shopt -u nullglob
if [ "${#hook_files[@]}" -eq 0 ]; then
  flag "$HOOK_SRC holds no *.sh -- refusing to report clean about hooks that should exist"
else
  for f in "${hook_files[@]}"; do
    hname="$(basename "$f")"
    install_file "$HOOK_DEST/$hname" "$(cat "$f")" 755 "$hname"
    # Installed is not wired. settings.json is Zach's file and this script
    # does not edit it -- but an installed-and-unreferenced hook is the
    # build-but-do-not-wire failure, and silence about it would be the
    # exit-0 no-op this whole script exists to prevent.
    if [ -f "$CLAUDE_SETTINGS" ] && ! grep -q "$hname" "$CLAUDE_SETTINGS"; then
      flag "$hname is installed but NOT referenced in ~/.claude/settings.json -- it will never fire"
    fi
  done
fi

# The lists above are derived from the command files, so a coverage check
# against those same files would only confirm the derivation. The check that
# means something is the independent one: does every command the INSTALLED
# files name actually resolve from a neutral cwd? That is reach-lint check B,
# and it reads ~/.claude/commands rather than this repo's sources.
note "reach check (bin/reach-lint.sh)"
if [ -x "$REPO/bin/reach-lint.sh" ]; then
  reach_out="$("$REPO/bin/reach-lint.sh" --strict-reach 2>&1)"
  if [ $? -eq 0 ]; then
    note "  ok      every command named by an installed file resolves from cwd /"
  else
    printf '%s\n' "$reach_out" | grep '^  FLAG \[unreachable\]'
    flag "reach-lint reported FLAGs (run bin/reach-lint.sh for the full report)"
  fi
else
  flag "bin/reach-lint.sh missing or not executable -- reach unverified"
fi

if [ "$fail" = 0 ]; then
  note "OK -- all shims and user-level commands in sync with $REPO"
else
  note "FLAGs above -- see stderr"
fi
exit "$fail"
