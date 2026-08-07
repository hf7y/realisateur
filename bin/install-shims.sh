#!/usr/bin/env bash
# install-shims.sh -- make realisateur's ecosystem commands reachable from
# EVERY repo, not just this one. Two halves, one source of truth each:
#
#   1. PATH shims in ~/.local/bin for every bin/*.sh a command file names,
#      so `hygiene-lint` / `closeout-lint` / `focus-commit` work from
#      any cwd, any clone, any host with this checkout.
#   2. User-level slash commands in ~/.claude/commands/, rendered from this
#      repo's own .claude/commands/*.md with `bin/foo.sh` rewritten to the
#      PATH name `foo`. User-level = available in every repo.
#
# What it retires: hand-copied shims (focus-commit, check-project-busy,
# notify-senechal were each written by hand, which is exactly why the six
# SURVEY scripts never got one) and hand-copied command files.
#
# Idempotent. Rerun after editing .claude/commands/*.md or adding a bin/
# script a command file calls -- drift between repo and installed copy is
# reported loudly (see --check).
set -uo pipefail

CLI_NAME='install-shims.sh'
CLI_SUMMARY='install/refresh the ~/.local/bin shims that put realisateur bin/ on PATH'
CLI_USAGE='  install-shims.sh           install or refresh every shim
  install-shims.sh --check   report drift only, write nothing'
CLI_FLAGS='--check'
CLI_POSITIONAL=none
. "$(dirname "${BASH_SOURCE[0]}")/lib/cli-guard.sh"
cli_guard "$@"

# DELIBERATELY NOT self-locating, unlike bin/blockers-freshness-check.sh and
# bin/token-usage.sh. Those answer "where am I"; this one answers "what should
# the INSTALLED shim point at", and the answer must be a stable checkout
# rather than whatever tree the installer happened to be invoked from.
# Deriving it from BASH_SOURCE would let a run inside .claude/worktrees/*
# silently repoint every shim on PATH at a temporary worktree.
#
# Overridable by environment for tests only (bin/tests/*, which also override
# HOME so nothing real is written). Not a migration hook: a second host wants
# its own stable path here, set once, not inherited from a caller's cwd.
REPO="${REPO:-${INSTALLE_PROJECTS:-$HOME/Documents/Projects}/realisateur}"

# A SOURCE OF TRUTH THAT IS NOT THERE IS A HARD FAILURE, NOT A FLAG.
#
# Found 2026-08-02 while bootstrapping dexter, and it is the reason the
# 2026-08-02 snapshot could say "nothing in the ecosystem knows how to install
# itself onto a bare machine" while realisateur was the one project that
# shipped an installer. Run on dexter as `bash ~/realisateur/bin/
# install-shims.sh`, with no REPO set, this defaulted to mandark's path -- a
# directory that does not exist on that host -- printed two FLAGs about the
# hooks it could not find, installed NOTHING, and **exited 0**.
#
# ~/.local/bin was still exactly `claude node npm npx` afterwards and
# ~/.claude/{commands,hooks} were empty, while the caller was told the run
# succeeded. That is an exit-0 no-op on the installer itself: the single
# failure mode this ecosystem's doctrine names as worse than a crash, in the
# script whose whole job is making the guards exist.
#
# The comment above is right that REPO must not be derived from BASH_SOURCE --
# that would let a run inside .claude/worktrees/* repoint every shim on PATH at
# a temporary worktree. The override is the migration path, exactly as line 38
# says ("a second host wants its own stable path here, set once"). What was
# missing is that choosing a path nobody ever validated is indistinguishable
# from choosing the right one, right up until nothing is installed.
# `-e "$REPO/.git"`, NOT `-d`. In a linked worktree (and in a submodule)
# `.git` is a FILE containing `gitdir: ...`, so the `-d` form this line used
# until 2026-08-07 refused every worktree with "does not name a realisateur
# checkout" -- which is false: a worktree is a checkout. That is not a
# hypothetical: every agent in this repo works in .claude/worktrees/*, and
# bin/tests/install-shims.test.sh now passes its own tree as REPO, so the
# wrong predicate made the suite fail from the only place it is ever run.
#
# This does NOT reopen the worktree hazard the header above names. That hazard
# is about DERIVING REPO from BASH_SOURCE, which this script still refuses to
# do; reaching here at all means someone set REPO explicitly. E1/E2 still
# refuse a directory that is no checkout at all.
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
# ~/.local/bin, ~/.claude/commands and ~/.claude/hooks -- writing to live
# machine config to assert something about a temp directory, and failing three
# assertions because the files it examined were never the files it wrote.
#
# It regressed exactly that way on 2026-08-02: `4eb0caf` added the overrides
# for BIN_DEST/CMD_DEST together with the test that needs them, `f990f87`
# edited the same block from the pre-4eb0caf base, and git merged both with no
# textual conflict -- so the hardcoded lines won and the overrides vanished
# while every test still "passed" on each branch alone. A semantic collision
# no conflict marker would have shown. Keep these as `${VAR:-...}`.
BIN_DEST="${BIN_DEST:-$HOME/.local/bin}"
CMD_SRC="$REPO/.claude/commands"
CMD_DEST="${CMD_DEST:-$HOME/.claude/commands}"
HOOK_SRC="$REPO/hooks"
HOOK_DEST="${HOOK_DEST:-$HOME/.claude/hooks}"
CLAUDE_SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"

# Both lists below are DERIVED, not typed. A hand-maintained list is what
# produced the 2026-07-27 gap: three shims existed because three were typed,
# and the six survey scripts the command files also name were never noticed.
#
# GLOBAL_COMMANDS = every command file declaring `scope: user` in frontmatter
# (see bin/reach-lint.sh check A). Adding that line is the whole opt-in.
mapfile -t GLOBAL_COMMANDS < <(
  for f in "$CMD_SRC"/*.md; do
    [ -f "$f" ] || continue
    awk 'NR==1 && $0!="---"{exit} NR==1{fm=1;next} fm && $0=="---"{exit}
         fm && /^scope:[[:space:]]*user[[:space:]]*$/{print "y";exit}' "$f" \
      | grep -q y && basename "$f" .md
  done
)

# SHIMMED = every bin/<name>.sh those files name, plus every bare token in
# CLAUDE.md's propagated "Ecosystem protocols" block that matches one of our
# own bin scripts. Anything a global command tells a session to run must be
# reachable from a repo that has no realisateur checkout.
mapfile -t SHIMMED < <(
  {
    for n in "${GLOBAL_COMMANDS[@]:-}"; do
      [ -n "${n:-}" ] && grep -o 'bin/[a-z0-9-]*\.sh' "$CMD_SRC/$n.md" 2>/dev/null
    done | sed 's|bin/||; s|\.sh||'
    # FIRST TOKEN of each backticked span, not the whole span. Every command
    # in the propagated block is written with its arguments -- `focus-commit
    # <repo> ...`, `notify-senechal '<what>'`, `silence-audit --strict` --
    # so a pattern anchored to a closing backtick matched NOTHING, and this
    # entire half of the derivation had been dead since it was written. It
    # looked like coverage: the three shims it was supposed to produce
    # existed anyway because ideate.md/cloture.md name them, so the silence
    # was indistinguishable from success. silence-audit is the first command
    # named ONLY here, and it is what exposed this -- it had to be
    # hand-copied to ~/.local/bin, which is the failure install-shims exists
    # to retire. Existence of bin/<token>.sh is still the filter, so a prose
    # word can never become a shim.
    grep -oP '`\K[a-z][a-z0-9-]*(?=[`[:space:]])' "$REPO/CLAUDE.md" 2>/dev/null \
      | while read -r t; do [ -f "$REPO/bin/$t.sh" ] && echo "$t"; done
  } | sort -u
)

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

fail=0
note() { printf '%s\n' "$*"; }
flag() { printf 'FLAG: %s\n' "$*" >&2; fail=1; }

render_shim() {
  local name="$1" real="$REPO/bin/$1.sh"
  cat <<EOF
#!/usr/bin/env bash
# >>> realisateur-owned shim -- generated by bin/install-shims.sh.
# DO NOT EDIT HERE. Edit $real and rerun the installer.
# Puts realisateur's ecosystem commands on PATH so EVERY project (and every
# dedicated clone the scheduler makes) can call them by name, exactly as the
# propagated "Ecosystem protocols" baseline instructs.
# Rationale: the baseline is propagated as plain text to repos that may be
# cloned on a host without realisateur checked out. A shim that is MISSING
# fails loudly at call time; a symlinked doc that dangles fails silently.
# <<< realisateur-owned
set -uo pipefail
real="$real"
[ -x "\$real" ] || { echo "$name: FAIL: realisateur command not found/executable at \$real" >&2; exit 127; }
exec "\$real" "\$@"
EOF
}

render_command() {
  # Rewrite in-repo script paths to their PATH names, and prepend a header
  # saying which repo "this repo"/"bin/" used to mean -- the file is now
  # read from inside arbitrary repos, where those words would mislead.
  local name="$1"
  cat <<EOF
<!-- GENERATED by realisateur bin/install-shims.sh from
     $CMD_SRC/$name.md -- do not edit here; edit there and rerun.
     Installed at user level, so it is available in EVERY repo. -->
EOF
  # Two forms appear in the source: `bin/foo.sh` (the in-repo path) and a
  # bare `foo.sh` in prose. Both must become the PATH name, or the rendered
  # command names something that does not exist outside this checkout.
  local sed_args=(-e 's|bin/\([a-z0-9-]*\)\.sh|\1|g')
  local s
  for s in "${SHIMMED[@]}"; do
    sed_args+=(-e "s|\\b$s\\.sh\\b|$s|g")
  done
  sed "${sed_args[@]}" "$CMD_SRC/$name.md"
  cat <<'EOF'

## Note added at install time: what "this repo" means here

This command is installed at USER level and runs from whatever repo you
happen to be in. Wherever the text above says "this repo", "this repo's
own `.scheduler/FOCUS.md`", or "realisateur's own", it means the
realisateur checkout at:
EOF
  printf '  `%s`\n' "$REPO"
  cat <<'EOF'
not your current working directory. Every command it tells you to run
(`hygiene-lint`, `closeout-lint`, `focus-commit`, ...) is on PATH and
is cwd-independent; `focus-commit` takes the target repo as its first
argument, so pass it explicitly rather than assuming the current one.

If the current repo is itself a scheduler-registered project, it is a
normal cross-write target under the rules above (`check-project-busy` it
first) -- being cwd does not make it exempt.
EOF
}

install_file() {
  local path="$1" content="$2" mode="$3" label="$4"
  # A symlink at an install target is never something this installer made -- it
  # only ever writes regular files. Left in place it is actively destructive,
  # because both checks below follow it: `-f`/`cat` read through to the TARGET
  # (so a symlink pointing at this repo's own source compares source-vs-shim,
  # always differs, and never short-circuits), and then `> "$path"` writes
  # through to that same target.
  #
  # Hit for real on 2026-08-01: a hand-made
  #   ln -s $REPO/bin/silence-audit.sh ~/.local/bin/silence-audit
  # made this function overwrite bin/silence-audit.sh with a shim that exec'd
  # itself. Infinite recursion, source destroyed -- and the run printed
  # "written silence-audit" and exited 0, so nothing anywhere reported a fault.
  # That silent-success-on-destruction is BUILD-DISCIPLINE's first row.
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
mkdir -p "$BIN_DEST" "$CMD_DEST" "$HOOK_DEST"

note "PATH shims -> $BIN_DEST"
for name in "${SHIMMED[@]}"; do
  if [ ! -x "$REPO/bin/$name.sh" ]; then
    flag "bin/$name.sh missing or not executable -- refusing to shim a broken target"
    continue
  fi
  install_file "$BIN_DEST/$name" "$(render_shim "$name")" 755 "$name"
done

note "user-level slash commands -> $CMD_DEST"
for name in "${GLOBAL_COMMANDS[@]}"; do
  if [ ! -f "$CMD_SRC/$name.md" ]; then
    flag "$CMD_SRC/$name.md missing -- cannot render /$name"
    continue
  fi
  install_file "$CMD_DEST/$name.md" "$(render_command "$name")" 644 "/$name"
done

# Claude Code hooks. Added 2026-08-02: subagent-closeout.sh was installed by
# hand on 2026-08-01 and tracked in NO repo, which is the same defect that
# broke the dexter bootstrap in July -- `usage-paced-runner.sh` was a symlink
# hand-made once that nothing in any repo created, so a bare host could not
# receive it and deleting it was a total outage. A guard that only exists in
# ~/.claude cannot be reproduced on a second host and cannot be reviewed.
#
# Derived by glob, not typed: the comment on SHIMMED above records that a
# hand-maintained list is exactly what produced the 2026-07-27 coverage gap.
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
